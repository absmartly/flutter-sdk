import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/context.dart';
import 'package:absmartly_dart/src/context_config.dart';
import 'package:absmartly_dart/src/default_audience_deserializer.dart';
import 'package:absmartly_dart/src/default_context_data_serializer.dart';
import 'package:absmartly_dart/src/default_variable_parser.dart';
import 'package:absmartly_dart/src/internal/context_counters.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:absmartly_dart/src/json/context_data.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:absmartly_dart/src/json/exposure.dart';
import 'package:absmartly_dart/src/jsonexpr/json_expr.dart';
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

class CountingAudienceDeserializer extends DefaultAudienceDeserializer {
  int ruleParses = 0;

  @override
  Map<String, dynamic>? deserialize(
      List<int> bytes, final int offset, final int length) {
    if (utf8.decode(bytes.sublist(offset, offset + length)).contains('rules')) {
      ruleParses++;
    }
    return super.deserialize(bytes, offset, length);
  }
}

class CountingJsonExpr extends JsonExpr {
  int evaluations = 0;

  @override
  bool evaluateBooleanExpr(dynamic expr, Map<String?, dynamic> vars) {
    evaluations++;
    return super.evaluateBooleanExpr(expr, vars);
  }
}

void main() {
  late List<int> contextBytes;
  late MockContextDataProvider dataProvider;
  late MockContextEventHandler eventHandler;
  final clock = Clock.fixed(1620000000000);
  String? environment;
  String? application;
  late CountingAudienceDeserializer audienceDeserializer;
  late CountingJsonExpr jsonExpr;

  setUpAll(() async {
    contextBytes = await getResourceBytes('context.json');
  });

  setUp(() {
    dataProvider = MockContextDataProvider();
    eventHandler = MockContextEventHandler();
    environment = 'production';
    application = 'website';
    audienceDeserializer = CountingAudienceDeserializer();
    jsonExpr = CountingJsonExpr();
    ContextCounters.reset();
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
        AudienceMatcher(audienceDeserializer, jsonExpr: jsonExpr),
        null,
        application: application,
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

  // Isolate.spawn rather than Isolate.run, which needs Dart 2.19.
  Future<T> inIsolate<T>(T Function() compute) async {
    final port = ReceivePort();
    await Isolate.spawn(
        (SendPort reply) => reply.send(compute()), port.sendPort);
    return await port.first as T;
  }

  group('data from another isolate', () {
    test('keeps assignment rules and custom fields', () async {
      final bytes = contextBytes;
      const fieldsJson = '[{"name":"region","value":"EU","type":"string"}]';
      final ContextData local = rulesData();
      final ContextData copied = await inIsolate(() {
        final data = DefaultContextDataDeserializer()
            .deserialize(bytes, 0, bytes.length)!;
        for (final experiment in data.experiments) {
          if (experiment.name == exp) {
            experiment.assignmentRules =
                rules([assign('US Internal Users', us, 1)]);
            experiment.customFieldValues = [
              for (final field in jsonDecode(fieldsJson) as List)
                CustomFieldValue.fromMap(field as Map<String, dynamic>)
            ];
          }
        }
        return data;
      });

      final experiment = copied.experiments.firstWhere((e) => e.name == exp);
      expect(experiment.assignmentRules,
          local.experiments.firstWhere((e) => e.name == exp).assignmentRules);
      expect(experiment.customFieldValues!.single.name, 'region');

      final context = await ready(copied);
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
      expect(context.getCustomFieldValue(exp, 'region'), 'EU');
    });

    test('keeps the exposure ruleOverride flag', () async {
      final Exposure exposure = await inIsolate(() => Exposure(
          id: 1,
          name: exp,
          unit: 'session_id',
          variant: 1,
          exposedAt: 1,
          assigned: false,
          eligible: true,
          overridden: false,
          fullOn: false,
          custom: false,
          audienceMismatch: false,
          ruleOverride: true));
      expect(exposure.ruleOverride, isTrue);
    });
  });

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

    test('a rule variant removed by a refresh falls back', () async {
      final context = await ready(data(rules([assign('Third', us, 2)])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 2);

      final fewer = data(rules([assign('Third', us, 2)]));
      final experiment = fewer.experiments.firstWhere((e) => e.name == exp);
      experiment.variants = experiment.variants.sublist(0, 2);
      experiment.split = [0.5, 0.5];
      await refreshWith(context, fewer);

      final variant = context.getTreatment(exp);
      expect(variant, lessThan(2));
      expect(exposures(context).last.ruleOverride, isFalse);
    });

    test('a changed seed re-resolves a split rule', () async {
      final context = await ready(data(rules([split(us, '50/0/50')])));
      context.setAttribute('country', 'US');
      final before = context.getTreatment(exp);

      // Find a seed whose split hashes this unit to the other variant.
      for (int seed = 0; seed < 64; seed++) {
        final next = data(rules([split(us, '50/0/50')]));
        final experiment = next.experiments.firstWhere((e) => e.name == exp);
        experiment.seedHi = seed;
        experiment.seedLo = seed * 7919;
        await refreshWith(context, next);
        if (context.getTreatment(exp) != before) {
          expect(exposures(context).last.ruleOverride, isTrue);
          return;
        }
      }
      fail('no seed moved the unit to the other variant');
    });

    test('a refresh that keeps the rule outcome is not re-exposed', () async {
      final context = await ready(data(rules([split(us, '0/100/0')])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      final next = data(rules([split(us, '0/100/0')]));
      next.experiments.firstWhere((e) => e.name == exp).seedHi = 42;
      await refreshWith(context, next);
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

  group('rule scope', () {
    Map<String, dynamic> always() => {
          'and': [
            {'value': true}
          ]
        };

    test('uses the configured environment, not a user environment attribute',
        () async {
      final context = await ready(data(rules([
        assign('Staging', always(), 1, ['staging'])
      ])));
      context.setAttribute('environment', 'staging');
      expect(context.getTreatment(exp), normalVariant);
      expect(exposures(context).single.ruleOverride, isFalse);
    });

    test('a user environment attribute does not unscope a production rule',
        () async {
      final context = await ready(data(rules([
        assign('Production', always(), 1, ['production'])
      ])));
      context.setAttribute('environment', 'staging');
      expect(context.getTreatment(exp), 1);
      expect(exposures(context).single.ruleOverride, isTrue);
    });

    test('a user environment attribute is what conditions read', () async {
      final context = await ready(data(rules([
        assign(
            'Staging users',
            {
              'eq': [
                {'var': 'environment'},
                {'value': 'staging'}
              ]
            },
            1)
      ])));
      expect(context.peekTreatment(exp), normalVariant);
      context.setAttribute('environment', 'staging');
      expect(context.peekTreatment(exp), 1);
    });
  });

  group('rules and traffic', () {
    ContextData excluded(String? assignmentRules) {
      final d = data(assignmentRules);
      d.experiments.firstWhere((e) => e.name == exp).trafficSplit = [1.0, 0.0];
      return d;
    }

    test('a matching rule wins over zero traffic', () async {
      final context = await ready(excluded(rules([assign('US', us, 1)])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      final exposure = exposures(context).single;
      expect(exposure.ruleOverride, isTrue);
      expect(exposure.eligible, isTrue);
      expect(exposure.assigned, isFalse);
    });

    test('zero traffic applies when no rule matches', () async {
      final context = await ready(excluded(rules([assign('US', us, 1)])));
      context.setAttribute('country', 'GB');
      expect(context.getTreatment(exp), 0);
      expect(exposures(context).single.eligible, isFalse);
    });
  });

  group('empty system names', () {
    String nullAudience(String name) => jsonEncode({
          'filter': [
            {
              'null': {'var': name}
            }
          ]
        });

    for (final name in ['application', 'environment']) {
      test('an empty $name is absent from the evaluation map', () async {
        if (name == 'application') {
          application = '';
        } else {
          environment = '';
        }
        final context = await ready(
            data(null, audience: nullAudience(name), audienceStrict: true));
        // A present "" is not null, so this strict audience only matches
        // when the key is left out.
        expect(context.getTreatment(exp), normalVariant);
        expect(exposures(context).single.audienceMismatch, isFalse);
      });

      test('a configured $name is present in the evaluation map', () async {
        final context = await ready(
            data(null, audience: nullAudience(name), audienceStrict: true));
        expect(context.getTreatment(exp), 0);
        expect(exposures(context).single.audienceMismatch, isTrue);
      });
    }
  });

  group('revalidation cost', () {
    test('reads without rules or audience build no attribute map', () async {
      final context = await ready(data(null, audience: ''));
      for (int i = 0; i < 1000; i++) {
        context.setAttribute('attr$i', i);
      }
      expect(context.getTreatment(exp), normalVariant);
      context.setAttribute('late', true);
      expect(context.getTreatment(exp), normalVariant);
      expect(context.getTreatment('exp_test_ab'), isNotNull);
      expect(ContextCounters.attributesMapBuilds, 0);
    });

    test('one attribute map per attribute change, shared by experiments',
        () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
      expect(ContextCounters.attributesMapBuilds, 1);

      context.setAttribute('unrelated', true);
      context.getTreatment(exp);
      for (final name in context.getExperiments()) {
        context.peekTreatment(name);
      }
      expect(ContextCounters.attributesMapBuilds, 2);
    });

    test('cached reads build no rule key and evaluate no rule', () async {
      final big = List.generate(200, (i) => assign('GB $i', gb, 2));
      final context = await ready(data(rules([...big, assign('US', us, 1)])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);
      final keys = ContextCounters.ruleKeyBuilds;
      final evaluations = jsonExpr.evaluations;

      for (int i = 0; i < 1000; i++) {
        expect(context.getTreatment(exp), 1);
      }
      expect(ContextCounters.ruleKeyBuilds, keys);
      expect(jsonExpr.evaluations, evaluations);
    });

    test('a same-outcome refresh revalidates once, not on every read',
        () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      await refreshWith(context, data(rules([assign('US renamed', us, 1)])));
      expect(context.getTreatment(exp), 1);
      final evaluations = jsonExpr.evaluations;
      for (int i = 0; i < 100; i++) {
        expect(context.getTreatment(exp), 1);
      }
      expect(jsonExpr.evaluations, evaluations);
      expect(context.getPendingCount(), 1);
    });

    test('reads after an unchanged-rules refresh do not compare rule text',
        () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      await refreshWith(context, rulesData());
      for (int i = 0; i < 100; i++) {
        expect(context.getTreatment(exp), 1);
      }
      context.setAttribute('unrelated', true);
      for (int i = 0; i < 100; i++) {
        expect(context.getTreatment(exp), 1);
      }
      expect(ContextCounters.ruleKeyComparisons, 0);
      expect(context.getPendingCount(), 1);
    });

    test('an experiment back after a refresh compares rule text once',
        () async {
      // Without its unit the assignment is unassigned, so it stays cached
      // while the experiment is missing from the data.
      final context = await ready(rulesData(), withSession: false);
      context.setAttribute('country', 'GB');
      expect(context.getTreatment(exp), 0);

      final without = rulesData();
      without.experiments =
          without.experiments.where((e) => e.name != exp).toList();
      await refreshWith(context, without);
      await refreshWith(context, rulesData());
      for (int i = 0; i < 100; i++) {
        expect(context.getTreatment(exp), 0);
      }
      expect(ContextCounters.ruleKeyComparisons, 1);
      expect(context.getPendingCount(), 1);
    });

    test('a same-outcome attribute change revalidates once', () async {
      final context = await ready(rulesData());
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 1);

      context.setAttribute('unrelated', true);
      expect(context.getTreatment(exp), 1);
      final evaluations = jsonExpr.evaluations;
      for (int i = 0; i < 100; i++) {
        expect(context.getTreatment(exp), 1);
      }
      expect(jsonExpr.evaluations, evaluations);
    });

    test('rules are parsed once per data install', () async {
      final context = await ready(rulesData());
      for (final country in ['US', 'GB', 'US', 'FR']) {
        context.setAttribute('country', country);
        context.getTreatment(exp);
      }
      expect(audienceDeserializer.ruleParses, 1);

      await refreshWith(context, data(rules([assign('US', us, 2)])));
      context.setAttribute('country', 'US');
      expect(context.getTreatment(exp), 2);
      context.setAttribute('country', 'GB');
      context.getTreatment(exp);
      expect(audienceDeserializer.ruleParses, 2);
    });

    test('invalid rules are parsed once and stay inert', () async {
      final context = await ready(data('{"rules": not json'));
      for (final country in ['US', 'GB', 'US']) {
        context.setAttribute('country', country);
        expect(context.getTreatment(exp), normalVariant);
      }
      expect(audienceDeserializer.ruleParses, 1);
    });
  });

  test(
      'an integral variant beyond the int range falls back, not to later rules',
      () async {
    final context = await ready(data(rules([
      assign('Huge', null, 0)..['variant'] = 1e20,
      assign('One', null, 1)
    ])));
    expect(context.getTreatment(exp), normalVariant);
    expect(exposures(context).single.ruleOverride, isFalse);
  });

  test('unknown fields at every level and a malformed rule stay isolated',
      () async {
    final json = jsonDecode(utf8.decode(contextBytes)) as Map<String, dynamic>;
    json['someFutureRoot'] = {
      'nested': [1, 'two', null]
    };
    json['holdouts'] = [
      {'id': 1, 'future': true}
    ];
    for (final experiment in json['experiments'] as List) {
      experiment['someFutureField'] = {
        'a': [
          {'b': 1}
        ]
      };
      experiment['switchback'] = {'periodMinutes': 30, 'unknown': []};
      for (final application in experiment['applications'] as List) {
        application['futureFlag'] = 7;
      }
      for (final variant in experiment['variants'] as List) {
        variant['futureVariantField'] = {'x': null};
      }
    }
    final experiments = json['experiments'] as List;
    experiments.firstWhere((e) => e['name'] == exp)['assignmentRules'] =
        jsonEncode({
      'rules': [
        {'type': 'assign', 'variant': 'one', 'future': {}},
        {
          'type': 'futureType',
          'variant': 1,
          'conditions': {
            'futureOperator': [1]
          }
        },
        {
          'name': 'unknown operator',
          'type': 'assign',
          'variant': 2,
          'conditions': {
            'futureOperator': [1]
          }
        },
        {
          'name': 'ok',
          'type': 'assign',
          'variant': 1,
          'environments': [],
          'futureRuleField': [1, 2],
          'conditions': {
            'and': [
              {'value': true}
            ]
          }
        },
      ],
      'futureRoot': true,
    });
    experiments
        .firstWhere((e) => e['name'] == 'exp_test_ab')['assignmentRules'] = {
      'rules': 'not a string'
    };

    final bytes = utf8.encode(jsonEncode(json));
    final parsed =
        DefaultContextDataDeserializer().deserialize(bytes, 0, bytes.length);
    expect(parsed, isNotNull);

    final context = await ready(parsed!);
    final baseline = await ready(data(null));
    expect(context.isFailed(), isFalse);
    expect(context.getTreatment('exp_test_ab'),
        baseline.getTreatment('exp_test_ab'));
    expect(context.getTreatment('exp_test_fullon'),
        baseline.getTreatment('exp_test_fullon'));
    expect(context.getTreatment(exp), 1);
    expect(exposures(context).single.ruleOverride, isTrue);
  });
}
