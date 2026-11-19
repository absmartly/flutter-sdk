import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/internal/context_counters.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:test/test.dart';

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

class LegacyExperiment implements Experiment {
  LegacyExperiment(this._delegate);

  final Experiment _delegate;

  @override
  int get id => _delegate.id;
  @override
  set id(int value) => _delegate.id = value;
  @override
  String get name => _delegate.name;
  @override
  set name(String value) => _delegate.name = value;
  @override
  String get unitType => _delegate.unitType;
  @override
  set unitType(String value) => _delegate.unitType = value;
  @override
  int get iteration => _delegate.iteration;
  @override
  set iteration(int value) => _delegate.iteration = value;
  @override
  int get seedHi => _delegate.seedHi;
  @override
  set seedHi(int value) => _delegate.seedHi = value;
  @override
  int get seedLo => _delegate.seedLo;
  @override
  set seedLo(int value) => _delegate.seedLo = value;
  @override
  List<double> get split => _delegate.split;
  @override
  set split(List<double> value) => _delegate.split = value;
  @override
  int get trafficSeedHi => _delegate.trafficSeedHi;
  @override
  set trafficSeedHi(int value) => _delegate.trafficSeedHi = value;
  @override
  int get trafficSeedLo => _delegate.trafficSeedLo;
  @override
  set trafficSeedLo(int value) => _delegate.trafficSeedLo = value;
  @override
  List<double> get trafficSplit => _delegate.trafficSplit;
  @override
  set trafficSplit(List<double> value) => _delegate.trafficSplit = value;
  @override
  int get fullOnVariant => _delegate.fullOnVariant;
  @override
  set fullOnVariant(int value) => _delegate.fullOnVariant = value;
  @override
  List<ExperimentApplication> get applications => _delegate.applications;
  @override
  set applications(List<ExperimentApplication> value) =>
      _delegate.applications = value;
  @override
  List<ExperimentVariant> get variants => _delegate.variants;
  @override
  set variants(List<ExperimentVariant> value) => _delegate.variants = value;
  @override
  bool get audienceStrict => _delegate.audienceStrict;
  @override
  set audienceStrict(bool value) => _delegate.audienceStrict = value;
  @override
  String? get audience => _delegate.audience;
  @override
  set audience(String? value) => _delegate.audience = value;
  @override
  String? get assignmentRules => _delegate.assignmentRules;
  @override
  set assignmentRules(String? value) => _delegate.assignmentRules = value;
  @override
  List<CustomFieldValue>? get customFieldValues => _delegate.customFieldValues;
  @override
  set customFieldValues(List<CustomFieldValue>? value) =>
      _delegate.customFieldValues = value;
  @override
  Map<String, dynamic> toMap() => _delegate.toMap();
}

Map<String, dynamic> experimentMap() => {
      'id': 1,
      'name': 'exp',
      'unitType': 'session_id',
      'iteration': 1,
      'seedHi': 0,
      'seedLo': 0,
      'split': [0.5, 0.5],
      'trafficSeedHi': 0,
      'trafficSeedLo': 0,
      'trafficSplit': [0.0, 1.0],
      'fullOnVariant': 0,
      'applications': [],
      'variants': [
        {'name': 'A', 'config': null},
        {'name': 'B', 'config': null}
      ],
    };

class LenientContextData implements ContextData {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class LenientExperiment implements Experiment {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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

  test('holdout fields of a lenient customer implementation are kept', () {
    final data = LenientContextData();
    final holdout = ContextHoldout(
        id: 1, name: 'h', iteration: 1, seedHi: 0, seedLo: 0, split: [1.0]);
    data.holdouts = [holdout];
    expect(data.holdouts, [holdout]);

    final experiment = LenientExperiment();
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
