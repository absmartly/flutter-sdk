// Switchback model fields (java-sdk ExperimentSwitchbackFieldsTest) and
// customer `implements` compatibility. No dart:io, so it also runs compiled
// to JavaScript.
import 'dart:convert';

import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:collection/collection.dart';
import 'package:test/test.dart';

import 'legacy_models.dart';

Experiment switchbackExperiment() => Experiment.fromMap(experimentMap())
  ..randomizationType = 'switchback'
  ..switchbackClusters = {'store_id': 'store/key', 'device_id': 'geo/city'}
  ..switchbackClusterValues = ['porto', 'lisbon']
  ..switchbackStartAt = 1767225600000
  ..switchbackPeriodMs = 3600000
  ..switchbackCarryoverDurationMs = 900000
  ..switchbackBurnInDurationMs = 600000
  ..switchbackBurnOutDurationMs = 0
  ..switchbackDesignType = 'balanced_block'
  ..switchbackEstimand = 'global_average_treatment_effect';

void main() {
  test('deserializeSwitchbackClusterOrderIsPreserved', () {
    const json = '{"experiments":[{"id":1,"name":"exp","unitType":"u",'
        '"iteration":1,"seedHi":0,"seedLo":0,"split":[0.5,0.5],'
        '"trafficSeedHi":0,"trafficSeedLo":0,"trafficSplit":[0,1],'
        '"fullOnVariant":0,"variants":[],"randomizationType":"switchback",'
        '"switchbackClusters":{"z_type":"a","a_type":"b","m_type":"c"}}]}';
    final bytes = utf8.encode(json);
    final data =
        DefaultContextDataDeserializer().deserialize(bytes, 0, bytes.length)!;
    expect(data.experiments.single.switchbackClusters!.keys,
        ['z_type', 'a_type', 'm_type']);
    expect(data.experiments.single.switchbackClusterValues, isNull);
  });

  test('malformedSwitchbackFieldsReadAsAbsent', () {
    final map = experimentMap()
      ..addAll({
        'randomizationType': 7,
        'switchbackClusters': ['not', 'a', 'map'],
        'switchbackClusterValues': 'porto',
        'switchbackStartAt': '1767225600000',
        'switchbackPeriodMs': 3600000.0,
        'switchbackCarryoverDurationMs': 1.5,
        'switchbackBurnInDurationMs': {'a': 1},
        'switchbackBurnOutDurationMs': true,
        'switchbackDesignType': 1,
        'switchbackEstimand': null,
      });
    final e = Experiment.fromMap(map);
    expect(e.randomizationType, isNull);
    expect(e.switchbackClusters, isNull);
    expect(e.switchbackClusterValues, isNull);
    expect(e.switchbackStartAt, isNull);
    expect(e.switchbackPeriodMs, 3600000);
    expect(e.switchbackCarryoverDurationMs, isNull);
    expect(e.switchbackBurnInDurationMs, isNull);
    expect(e.switchbackBurnOutDurationMs, isNull);
    expect(e.switchbackDesignType, isNull);

    // A non-string path is kept in its text form when it is a scalar (as
    // Java's decoder reads it) and makes the map unreadable otherwise; a
    // non-string allow-list entry is kept in its text form, so it never
    // widens to "every value".
    final paths = Experiment.fromMap(experimentMap()
      ..addAll({
        'switchbackClusters': {'a': 1, 'b': null, 'c': {}},
        'switchbackClusterValues': ['x', 3, null]
      }));
    expect(paths.switchbackClusters, {'a': '1', 'b': null, 'c': null});
    expect(paths.switchbackClusterValues, ['x', '3', 'null']);
  });

  test('equalsAndHashCodeCoverEverySwitchbackField', () {
    expect(switchbackExperiment(), switchbackExperiment());
    expect(switchbackExperiment().hashCode, switchbackExperiment().hashCode);

    final mutations = <void Function(Experiment)>[
      (e) => e.randomizationType = 'unit',
      (e) => e.switchbackClusters = null,
      (e) => e.switchbackClusters = {'store_id': 'store/key'},
      (e) => e.switchbackClusters = {
            'store_id': 'store/key',
            'device_id': 'geo/country'
          },
      // Same entries, other order: the order is semantic.
      (e) => e.switchbackClusters = {
            'device_id': 'geo/city',
            'store_id': 'store/key'
          },
      (e) => e.switchbackClusterValues = null,
      (e) => e.switchbackClusterValues = ['lisbon', 'porto'],
      (e) => e.switchbackStartAt = 1767229200000,
      (e) => e.switchbackPeriodMs = 86400000,
      (e) => e.switchbackCarryoverDurationMs = null,
      (e) => e.switchbackBurnInDurationMs = 1,
      (e) => e.switchbackBurnOutDurationMs = 1,
      (e) => e.switchbackDesignType = 'other',
      (e) => e.switchbackEstimand = 'other',
    ];
    for (final mutation in mutations) {
      final changed = switchbackExperiment();
      mutation(changed);
      expect(changed, isNot(switchbackExperiment()));
      expect(switchbackExperiment(), isNot(changed));
      expect(changed.hashCode, isNot(switchbackExperiment().hashCode));
    }
  });

  test('hashCodeOfAUnitExperimentIsUnchanged', () {
    final e = Experiment.fromMap(experimentMap());
    expect(
        e.hashCode,
        Object.hash(
            e.id,
            e.name,
            e.unitType,
            e.iteration,
            e.seedHi,
            e.seedLo,
            e.trafficSeedHi,
            e.trafficSeedLo,
            e.fullOnVariant,
            e.audienceStrict,
            e.audience,
            e.assignmentRules,
            const ListEquality().hash(e.split),
            const ListEquality().hash(e.trafficSplit),
            const ListEquality().hash(e.applications),
            const ListEquality().hash(e.variants)));
  });

  test('toStringIncludesSwitchbackFields', () {
    final s = switchbackExperiment().toString();
    expect(s, contains("randomizationType='switchback'"));
    expect(
        s,
        contains(
            'switchbackClusters={store_id: store/key, device_id: geo/city}'));
    expect(s, contains('switchbackClusterValues=[porto, lisbon]'));
    expect(s, contains('switchbackStartAt=1767225600000'));
    expect(s, contains("switchbackEstimand='global_average_treatment_effect'"));
    expect(Experiment.fromMap(experimentMap()).toString(),
        isNot(contains('switchback')));
  });

  test('theConstructorTakesTheSwitchbackFields', () {
    final e = Experiment(
      id: 1,
      name: 'exp',
      unitType: 'u',
      iteration: 1,
      seedHi: 0,
      seedLo: 0,
      split: [0.5, 0.5],
      trafficSeedHi: 0,
      trafficSeedLo: 0,
      trafficSplit: [0.0, 1.0],
      fullOnVariant: 0,
      applications: [],
      variants: [],
      audienceStrict: false,
      audience: null,
      randomizationType: 'switchback',
      switchbackClusters: {'u': 'city'},
      switchbackPeriodMs: 1,
    );
    expect(e.randomizationType, 'switchback');
    expect(e.switchbackClusters, {'u': 'city'});
    expect(e.switchbackPeriodMs, 1);
    expect(e.switchbackStartAt, isNull);
  });

  test('switchback fields of a customer implementation are kept', () {
    final experiment = LegacyExperiment(Experiment.fromMap(experimentMap()));
    expect(experiment.randomizationType, isNull);
    expect(experiment.switchbackClusters, isNull);
    experiment.randomizationType = 'switchback';
    experiment.switchbackClusters = {'u': 'city'};
    experiment.switchbackStartAt = 0;
    expect(experiment.randomizationType, 'switchback');
    expect(experiment.switchbackClusters, {'u': 'city'});
    expect(experiment.switchbackStartAt, 0);
    expect(experiment.switchbackPeriodMs, isNull);
  });

  // A malformed switchback field reads as absent, so the experiment equals
  // and hashes like one without it, as does one whose fields were cleared.
  test('equalExperimentsHashEquallyWhateverTheirAbsentFields', () {
    final plain = Experiment.fromMap(experimentMap());
    final malformed =
        Experiment.fromMap(experimentMap()..['randomizationType'] = 7);
    final cleared = Experiment.fromMap(experimentMap())
      ..switchbackPeriodMs = 1
      ..switchbackPeriodMs = null;
    for (final other in [malformed, cleared]) {
      expect(other, plain);
      expect(other.hashCode, plain.hashCode);
      expect({plain}.contains(other), isTrue);
      expect(other.toString(), plain.toString());
    }
  });
}
