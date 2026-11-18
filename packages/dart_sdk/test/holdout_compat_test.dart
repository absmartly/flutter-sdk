import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/internal/context_counters.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:test/test.dart';

import 'legacy_models.dart';
import 'publish_probe.dart';
import 'test_utils.dart';

// The members of ContextData and Experiment in the latest release
// (absmartly_sdk 2.1.2) and on main before holdouts. These classes stop
// compiling if either model gains a public member, which would break
// customer code that implements it.
class LegacyContextData implements ContextData {
  LegacyContextData(this.experiments);

  @override
  List<Experiment> experiments;

  @override
  Map<String, dynamic> toMap() => {
        'experiments': [for (final e in experiments) e.toMap()]
      };
}

class NullPublisher implements ContextPublisher {
  @override
  Completer<void> publish(Context context, PublishEvent event) =>
      Completer<void>()..complete();
}

void main() {
  const fixtures = [
    'context',
    'audience_context',
    'audience_strict_context',
    'custom_fields_context',
  ];

  // test/resources/publish_golden holds the publish bodies that main
  // (86b7911, before holdouts) produced for the same probe.
  group('publish bytes without holdouts are unchanged', () {
    for (final fixture in fixtures) {
      test(fixture, () async {
        final golden = File('test/resources/publish_golden/$fixture.txt')
            .readAsStringSync();
        final payload = await getResourceBytes('$fixture.json');

        expect(await publishProbe(payload), golden);

        // An empty holdouts array, or holdoutIds that name no served holdout,
        // publish the same bytes.
        final json = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
        json['holdouts'] = [];
        for (final experiment in json['experiments'] as List) {
          experiment['holdoutIds'] = [404];
        }
        expect(await publishProbe(utf8.encode(jsonEncode(json))), golden);

        json['holdouts'] = [
          {'id': 404, 'name': 'unservable', 'split': []}
        ];
        expect(await publishProbe(utf8.encode(jsonEncode(json))), golden);
      });
    }
  });

  test('a payload without holdouts never takes the holdout path', () async {
    for (final fixture in fixtures) {
      final payload = await getResourceBytes('$fixture.json');
      final json = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      json['holdouts'] = [
        {'id': 404, 'name': 'unservable', 'split': []}
      ];
      for (final experiment in json['experiments'] as List) {
        experiment['holdoutIds'] = [404, 405];
      }
      // A servable holdout that no experiment references.
      final unreferenced =
          jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      unreferenced['holdouts'] = [
        {
          'id': 7,
          'name': 'unreferenced',
          'split': [0.5, 0.5]
        }
      ];
      final unreferencedBytes = utf8.encode(jsonEncode(unreferenced));
      // ... referenced by no id at all, and only through dangling ids.
      for (final experiment in unreferenced['experiments'] as List) {
        experiment['holdoutIds'] = [404];
      }
      for (final bytes in [
        payload,
        utf8.encode(jsonEncode(json)),
        unreferencedBytes,
        utf8.encode(jsonEncode(unreferenced)),
      ]) {
        ContextCounters.reset();
        await publishProbe(bytes);
        expect(ContextCounters.coveredAssignmentResolutions, 0,
            reason: fixture);
        expect(ContextCounters.holdoutAssignmentLookups, 0, reason: fixture);
      }
    }
  });

  test('holdouts survive an isolate copy of the context data', () async {
    final json =
        jsonDecode(utf8.decode(await getResourceBytes('holdouts_context.json')))
            as Map<String, dynamic>;
    final copied = await Isolate.run(() => ContextData.fromMap(json));

    expect(copied.holdouts.map((h) => h.id), [11, 12]);
    expect(copied.experiments.single.holdoutIds, [11]);
    expect(copied.holdouts.first.holdoutType, 'full');
  });

  test('holdout fields of a customer implementation are kept', () {
    final legacy = LegacyContextData([]);
    final holdout = ContextHoldout(
        id: 1, name: 'h', iteration: 1, seedHi: 0, seedLo: 0, split: [1.0]);
    legacy.holdouts = [holdout];
    expect(legacy.holdouts, [holdout]);

    final experiment = LegacyExperiment(Experiment.fromMap(experimentMap()));
    experiment.holdoutIds = [1];
    experiment.holdoutType = 'full';
    expect(experiment.holdoutIds, [1]);
    expect(experiment.holdoutType, 'full');
  });

  test('cached reads of a covered experiment do not re-resolve its holdouts',
      () async {
    final bytes = await getResourceBytes('holdouts_context.json');
    final data =
        DefaultContextDataDeserializer().deserialize(bytes, 0, bytes.length)!;
    final context = Context.create(
        Clock.fixed(1620000000000),
        ContextConfig.create()
          ..setUnit('session_id', 'e791e240fcd3df7d238cfc285f475e8152fcc0ec')
          ..setPublishDelay(-1),
        Completer<ContextData>()..complete(data),
        NoDataProvider(),
        NullPublisher(),
        DefaultVariableParser(),
        AudienceMatcher(DefaultAudienceDeserializer()),
        null);
    await context.waitUntilReady();

    ContextCounters.reset();
    expect(context.getTreatment('exp_test_holdout'), 0);
    expect(ContextCounters.holdoutAssignmentLookups, 1);
    for (int i = 0; i < 10; i++) {
      context.getTreatment('exp_test_holdout');
      context.peekTreatment('exp_test_holdout');
      context.getVariableValue('banner.size', 'default');
    }
    expect(ContextCounters.holdoutAssignmentLookups, 1);
    expect(context.getPendingCount(), 1);
  });

  test('customer implementations of the released models keep working',
      () async {
    final bytes = await getResourceBytes('context.json');
    final released =
        DefaultContextDataDeserializer().deserialize(bytes, 0, bytes.length)!;
    final legacy = LegacyContextData(
        [for (final e in released.experiments) LegacyExperiment(e)]);

    expect(legacy.holdouts, isEmpty);
    expect(legacy.experiments.first.holdoutIds, isNull);

    final context = Context.create(
        Clock.fixed(1620000000000),
        ContextConfig.create()
          ..setUnit('session_id', 'e791e240fcd3df7d238cfc285f475e8152fcc0ec')
          ..setPublishDelay(-1),
        Completer<ContextData>()..complete(legacy),
        NoDataProvider(),
        NullPublisher(),
        DefaultVariableParser(),
        AudienceMatcher(DefaultAudienceDeserializer()),
        null);
    await context.waitUntilReady();
    expect(context.getTreatment('exp_test_ab'), 1);
  });

  test('the released constructors still build the models', () {
    final data = ContextData();
    expect(data.experiments, isEmpty);
    expect(data.holdouts, isEmpty);
    expect(ContextData(experiments: const []).toMap(), {'experiments': []});
  });
}
