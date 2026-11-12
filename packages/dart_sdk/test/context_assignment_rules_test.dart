import 'dart:async';
import 'dart:convert';

import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/context.dart';
import 'package:absmartly_dart/src/context_config.dart';
import 'package:absmartly_dart/src/default_audience_deserializer.dart';
import 'package:absmartly_dart/src/default_context_data_serializer.dart';
import 'package:absmartly_dart/src/default_variable_parser.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:absmartly_dart/src/json/context_data.dart';
import 'package:absmartly_dart/src/json/exposure.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'context_test.mocks.dart';
import 'test_utils.dart';

const String exp = 'exp_test_abc';
const int normalVariant = 2;
const String sessionId = 'e791e240fcd3df7d238cfc285f475e8152fcc0ec';
const String userId = '123456789';

const Map<String, dynamic> us = {
  'and': [
    {
      'eq': [
        {'var': 'country'},
        {'value': 'US'}
      ]
    }
  ]
};
const Map<String, dynamic> gb = {
  'and': [
    {
      'eq': [
        {'var': 'country'},
        {'value': 'GB'}
      ]
    }
  ]
};

Map<String, dynamic> assign(String name, dynamic conditions, int variant,
        [List<String> environments = const []]) =>
    {
      'name': name,
      'type': 'assign',
      'conditions': conditions,
      'environments': environments,
      'variant': variant,
    };

Map<String, dynamic> split(dynamic conditions, String percentages) => {
      'name': 'split',
      'type': 'split',
      'conditions': conditions,
      'environments': [],
      'percentages': percentages,
    };

String rules(List<Map<String, dynamic>> rules) => jsonEncode({'rules': rules});

void main() {
  late List<int> contextBytes;
  late MockContextDataProvider dataProvider;
  late MockContextEventHandler eventHandler;
  final clock = Clock.fixed(1620000000000);
  String? environment;

  setUpAll(() async {
    contextBytes = await getResourceBytes('context.json');
  });

  setUp(() {
    dataProvider = MockContextDataProvider();
    eventHandler = MockContextEventHandler();
    environment = 'production';
  });

  ContextData data(String? assignmentRules,
      {String audience = '{"filter":[{"value":true}]}',
      bool audienceStrict = false,
      int? fullOnVariant}) {
    final data = DefaultContextDataDeserializer()
        .deserialize(contextBytes, 0, contextBytes.length)!;
    for (final experiment in data.experiments) {
      if (experiment.name == exp) {
        experiment.assignmentRules = assignmentRules;
        experiment.audience = audience;
        experiment.audienceStrict = audienceStrict;
        if (fullOnVariant != null) {
          experiment.fullOnVariant = fullOnVariant;
        }
      }
    }
    return data;
  }

  Context create(ContextData data, {bool withSession = true}) {
    final config = ContextConfig.create()..setUnit('user_id', userId);
    if (withSession) {
      config.setUnit('session_id', sessionId);
    }
    return Context.create(
        clock,
        config,
        Completer<ContextData>()..complete(data),
        dataProvider,
        eventHandler,
        DefaultVariableParser(),
        AudienceMatcher(DefaultAudienceDeserializer()),
        null,
        application: 'website',
        environment: environment);
  }

  Future<Context> ready(ContextData data, {bool withSession = true}) async {
    final context = create(data, withSession: withSession);
    await context.waitUntilReady();
    return context;
  }

  Future<void> refreshWith(Context context, ContextData next) async {
    when(dataProvider.getContextData())
        .thenAnswer((_) => Completer<ContextData>()..complete(next));
    await context.refresh();
  }

  List<Exposure> exposures(Context context) =>
      context.exposures_.where((e) => e.name == exp).toList();

  final rulesData = () => data(rules([assign('US Internal Users', us, 1)]));
  final envScopedData = () => data(rules([
        assign('Production Only', us, 1, ['production'])
      ]));
  final strictData = () => data(rules([assign('US Users', us, 1)]),
      audience: '{"filter":[{"gte":[{"var":"age"},{"value":20}]}]}',
      audienceStrict: true);

  group('assign rules', () {
    test('rule variant when rule matches', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
    });

    test('rule wins over custom assignment and is exposed once', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      context.setCustomAssignment(exp, 2);
      expect(context.getTreatment(exp), 1);
      expect(context.getTreatment(exp), 1);
      expect(context.getPendingCount(), 1);

      context.setAttribute('country', 'GB');
      expect(context.getTreatment(exp), 2);
    });

    test('normal assignment when no rule matches', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'GB');
      expect(context.getTreatment(exp), normalVariant);
    });

    test('skips rule for another environment', () async {
      environment = 'staging';
      final context = await ready(envScopedData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), normalVariant);
    });

    test('skips environment-scoped rule without an environment', () async {
      environment = null;
      final context = await ready(envScopedData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), normalVariant);
    });

    test('unscoped rule applies without an environment', () async {
      environment = null;
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
    });

    test('matches rule for the environment', () async {
      final context = await ready(envScopedData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
    });

    test('override takes priority over rules', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      context.setOverride(exp, 0);
      expect(context.getTreatment(exp), 0);

      final exposure = exposures(context).single;
      expect(exposure.variant, 0);
      expect(exposure.overridden, isTrue);
      expect(exposure.ruleOverride, isFalse);
      expect(exposure.assigned, isFalse);
    });

    test('override flags when override matches the rule variant', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
      context.setOverride(exp, 1);
      expect(context.getTreatment(exp), 1);

      final last = exposures(context).last;
      expect(last.variant, 1);
      expect(last.overridden, isTrue);
      expect(last.ruleOverride, isFalse);
    });

    test('exposure flags when a rule matches', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      expect(
          exposures(context).single,
          Exposure(
              id: 2,
              name: exp,
              unit: 'session_id',
              variant: 1,
              exposedAt: clock.millis(),
              assigned: false,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: false,
              ruleOverride: true));
    });

    test('exposure flags when no rule matches', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'GB');
      expect(context.getTreatment(exp), normalVariant);

      expect(
          exposures(context).single,
          Exposure(
              id: 2,
              name: exp,
              unit: 'session_id',
              variant: normalVariant,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: false,
              ruleOverride: false));
    });

    test('rule skips audience and audienceStrict', () async {
      final context = await ready(strictData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      final exposure = exposures(context).single;
      expect(exposure.audienceMismatch, isFalse);
      expect(exposure.ruleOverride, isTrue);
      expect(exposure.assigned, isFalse);
    });

    test('audienceStrict applies when no rule matches', () async {
      final context = await ready(strictData());
      context.setAttribute('country', 'GB');
      expect(context.getTreatment(exp), 0);

      final exposure = exposures(context).single;
      expect(exposure.audienceMismatch, isTrue);
      expect(exposure.ruleOverride, isFalse);
    });

    test('rule-won assignment is not invalidated by audience changes',
        () async {
      final context = await ready(strictData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
      context.setAttribute('age', 30);
      expect(context.getTreatment(exp), 1);
      expect(context.getPendingCount(), 1);
    });

    test('invalidates when a rule starts matching', () async {
      final context = await ready(rulesData());
      expect(context.getTreatment(exp), normalVariant);
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
    });

    test('invalidates when a rule stops matching', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
      context.setAttribute('country', 'GB');
      expect(context.getTreatment(exp), normalVariant);
    });

    test('invalidates when the matching rule switches variant', () async {
      final context =
          await ready(data(rules([assign('US', us, 1), assign('GB', gb, 2)])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
      context.setAttribute('country', 'GB');
      expect(context.getTreatment(exp), 2);
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
    });

    test('keeps the cache when an unrelated attribute changes', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
      context.setAttribute('unrelated', true);
      expect(context.getTreatment(exp), 1);
      expect(context.getPendingCount(), 1);
    });

    test('variable value follows the rule variant', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
      expect(context.getVariableValue('button.color', 'default'), 'blue');
      expect(context.peekVariableValue('button.color', 'default'), 'blue');
    });

    test('variable value from a rule without a treatment call', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getVariableValue('button.color', 'default'), 'blue');
      expect(context.getPendingCount(), 1);

      final exposure = exposures(context).single;
      expect(exposure.variant, 1);
      expect(exposure.ruleOverride, isTrue);
      expect(exposure.assigned, isFalse);
    });

    test('multiple and conditions', () async {
      final conditions = {
        'and': [
          {
            'eq': [
              {'var': 'country'},
              {'value': 'US'}
            ]
          },
          {
            'eq': [
              {'var': 'plan'},
              {'value': 'pro'}
            ]
          }
        ]
      };
      final context =
          await ready(data(rules([assign('US Pro', conditions, 1)])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), normalVariant);
      context.setAttribute('plan', 'pro');
      expect(context.getTreatment(exp), 1);
    });

    test('out-of-range rule variants fall back', () async {
      expect(
          (await ready(data(rules([assign('OOB', null, 99)]))))
              .getTreatment(exp),
          normalVariant);
      expect(
          (await ready(data(rules([assign('Neg', null, -1)]))))
              .getTreatment(exp),
          normalVariant);
    });

    test('an out-of-range rule variant is not a rule override', () async {
      final context = await ready(data(rules([assign('OOB', null, 99)])));
      context.getTreatment(exp);
      expect(exposures(context).single.ruleOverride, isFalse);
    });

    test('out-of-range changes do not invalidate', () async {
      final context = await ready(
          data(rules([assign('US', us, 99), assign('GB', gb, 100)])));
      context.setAttribute('country', 'US');
      final first = context.getTreatment(exp);
      context.setAttribute('country', 'GB');
      expect(context.getTreatment(exp), first);
      expect(context.getPendingCount(), 1);
    });

    test('a rule forcing control sets ruleOverride', () async {
      final context =
          await ready(data(rules([assign('Force Control', us, 0)])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 0);

      final exposure = exposures(context).single;
      expect(exposure.variant, 0);
      expect(exposure.ruleOverride, isTrue);
    });

    test('invalid rules JSON falls back', () async {
      expect((await ready(data('not json'))).getTreatment(exp), normalVariant);
      expect((await ready(data(''))).getTreatment(exp), normalVariant);
    });

    test('system attributes are available to rule conditions', () async {
      final appRule = rules([
        assign(
            'Website',
            {
              'eq': [
                {'var': 'application'},
                {'value': 'website'}
              ]
            },
            1)
      ]);
      final envRule = rules([
        assign(
            'Production',
            {
              'eq': [
                {'var': 'environment'},
                {'value': 'production'}
              ]
            },
            1)
      ]);
      expect((await ready(data(appRule))).getTreatment(exp), 1);
      expect((await ready(data(envRule))).getTreatment(exp), 1);
    });

    test('a rule with semver conditions', () async {
      final versionRule = rules([
        assign(
            'New app',
            {
              'semver_gte': [
                {'var': 'app_version'},
                {'value': '2.4.0'}
              ]
            },
            1)
      ]);
      final context = await ready(data(versionRule));
      expect(context.peekTreatment(exp), normalVariant);
      context.setAttribute('app_version', '2.10.1');
      expect(context.peekTreatment(exp), 1);
      context.setAttribute('app_version', '2.3.9');
      expect(context.peekTreatment(exp), normalVariant);
    });
  });

  group('refresh', () {
    test('adding rules to an exposed assignment re-exposes with the rule',
        () async {
      final context = await ready(data(null));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), normalVariant);

      await refreshWith(context, data(rules([assign('US', us, 1)])));
      expect(context.getTreatment(exp), 1);

      final list = exposures(context);
      expect(list.length, 2);
      expect(list[0].variant, normalVariant);
      expect(list[0].ruleOverride, isFalse);
      expect(list[1].variant, 1);
      expect(list[1].ruleOverride, isTrue);
    });

    test('changed rules invalidate', () async {
      final context = await ready(data(rules([assign('US', us, 1)])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      await refreshWith(context, data(rules([assign('US', us, 0)])));
      expect(context.getTreatment(exp), 0);
    });

    test('removing rules invalidates', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      await refreshWith(context, data(null));
      expect(context.getTreatment(exp), normalVariant);
    });

    test('unchanged rules keep the cache', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      await refreshWith(context, rulesData());
      expect(context.getTreatment(exp), 1);
      expect(context.getPendingCount(), 1);
    });

    test('equivalent rules text keeps the variant', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      await refreshWith(context, data(rules([assign('US renamed', us, 1)])));
      expect(context.getTreatment(exp), 1);
      expect(context.getPendingCount(), 1);
    });

    test('rule variant is dropped when the experiment is removed', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      final without = rulesData();
      without.experiments =
          without.experiments.where((e) => e.name != exp).toList();
      await refreshWith(context, without);

      expect(context.peekTreatment(exp), 0);
      expect(context.getTreatment(exp), 0);
    });
  });

  group('split rules', () {
    test('hash the unit with the experiment seed', () async {
      final context = await ready(data(rules([split(us, '70/10/20')])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
    });

    test('assign only the non-zero share', () async {
      final context = await ready(data(rules([split(us, '0/100/0')])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
    });

    test('exposure flags', () async {
      final context = await ready(data(rules([split(us, '0/100/0')])));
      context.setAttribute('country', 'US');
      context.getTreatment(exp);

      final exposure = exposures(context).single;
      expect(exposure.variant, 1);
      expect(exposure.assigned, isFalse);
      expect(exposure.eligible, isTrue);
      expect(exposure.ruleOverride, isTrue);
    });

    test('win over a custom assignment', () async {
      final context = await ready(data(rules([split(us, '0/100/0')])));
      context.setAttribute('country', 'US');
      context.setCustomAssignment(exp, 2);
      expect(context.getTreatment(exp), 1);
    });

    test('a split not covering every variant falls back without later rules',
        () async {
      final context = await ready(
          data(rules([split(us, '0/100'), assign('Everyone', null, 1)])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), normalVariant);
    });

    test('without a unit gives the no-unit result, then re-resolves', () async {
      final context = await ready(
          data(rules([split(us, '0/100/0'), assign('Everyone', null, 2)])),
          withSession: false);
      context.setAttribute('country', 'US');
      expect(context.peekTreatment(exp), 0);

      context.setUnit('session_id', sessionId);
      expect(context.peekTreatment(exp), 1);
    });

    test('assign rule cache survives a late unit', () async {
      final context = await ready(rulesData(), withSession: false);
      context.setAttribute('country', 'US');
      expect(context.peekTreatment(exp), 1);

      context.setUnit('session_id', sessionId);
      expect(context.getTreatment(exp), 1);
      expect(context.getPendingCount(), 1);
    });

    test('re-resolves when a split starts matching on the previous variant',
        () async {
      final context = await ready(
          data(rules([split(us, '0/100/0'), assign('Everyone', null, 0)])),
          withSession: false);
      expect(context.peekTreatment(exp), 0);

      context.setAttribute('country', 'US');
      expect(context.peekTreatment(exp), 0);

      context.setUnit('session_id', sessionId);
      expect(context.peekTreatment(exp), 1);
    });

    test('an exposed split without a unit stays pinned', () async {
      final context =
          await ready(data(rules([split(us, '0/100/0')])), withSession: false);
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 0);

      context.setUnit('session_id', sessionId);
      context.setAttribute('unrelated', true);
      expect(context.getTreatment(exp), 0);

      final list = exposures(context);
      expect(list.length, 1);
      expect(list[0].variant, 0);
    });

    test('an exposed assign then split without a unit stays pinned', () async {
      final context = await ready(
          data(rules([assign('GB', gb, 0), split(us, '0/100/0')])),
          withSession: false);
      context.setAttribute('country', 'GB');
      expect(context.getTreatment(exp), 0);

      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 0);

      context.setUnit('session_id', sessionId);
      expect(context.getTreatment(exp), 0);
      expect(context.getTreatment(exp), 0);

      final list = exposures(context);
      expect(list.length, 1);
      expect(list[0].variant, 0);
      expect(list[0].ruleOverride, isTrue);
    });

    test('an exposed split without a unit then assign is not re-exposed',
        () async {
      final context = await ready(
          data(rules([split(us, '0/100/0'), assign('GB', gb, 0)])),
          withSession: false);
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 0);

      context.setAttribute('country', 'GB');
      expect(context.getTreatment(exp), 0);

      context.setUnit('session_id', sessionId);
      expect(context.getTreatment(exp), 0);

      final list = exposures(context);
      expect(list.length, 1);
      expect(list[0].variant, 0);
    });

    test('an exposed split without a unit stays pinned without custom',
        () async {
      final context =
          await ready(data(rules([split(us, '0/100/0')])), withSession: false);
      context.setAttribute('country', 'US');
      context.setCustomAssignment(exp, 2);
      expect(context.getTreatment(exp), 0);

      context.setUnit('session_id', sessionId);
      expect(context.getTreatment(exp), 0);

      final list = exposures(context);
      expect(list.length, 1);
      expect(list[0].variant, 0);
    });

    test('without a unit on a full-on experiment', () async {
      final context = await ready(
          data(rules([split(null, '0/100/0')]), fullOnVariant: 2),
          withSession: false);
      expect(context.peekTreatment(exp), 2);

      context.setUnit('session_id', sessionId);
      expect(context.peekTreatment(exp), 1);
    });

    test('the read path hashes the unit itself', () async {
      final context = await ready(data(rules([split(us, '0/100/0')])));
      context.setAttribute('country', 'GB');
      expect(context.peekTreatment(exp), normalVariant);
      context.setAttribute('country', 'US');
      expect(context.peekTreatment(exp), 1);
    });

    test('re-resolution on the read path without a cached hash', () async {
      final context =
          await ready(data(rules([assign('GB', gb, 0), split(us, '0/100/0')])));
      context.setAttribute('country', 'GB');
      expect(context.peekTreatment(exp), 0);
      context.setAttribute('country', 'US');
      expect(context.peekTreatment(exp), 1);
    });

    test('a custom assignment change keeps the rule-won cache', () async {
      final context = await ready(data(rules([split(us, '0/100/0')])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
      context.setCustomAssignment(exp, 0);
      expect(context.getTreatment(exp), 1);
      expect(context.getPendingCount(), 1);
    });
  });

  test('custom field and variable keys are unaffected', () async {
    final context = await ready(rulesData());
    context.setAttribute('country', 'US');
    expect(context.getVariableKeys()['button.color'], [exp]);
  });
}
