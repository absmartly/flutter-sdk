// Switchback model fields: deserialization (java-sdk
// DefaultContextDataDeserializerTest and ExperimentSwitchbackFieldsTest),
// forward compatibility, customer `implements` compatibility and the publish
// bytes of payloads without switchbacks.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:absmartly_dart/src/internal/context_counters.dart';
import 'package:test/test.dart';

import 'legacy_models.dart';
import 'publish_probe.dart';
import 'test_utils.dart';

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
  test('deserializeSwitchback', () async {
    final bytes = await getResourceBytes('switchback_context.json');
    final data =
        DefaultContextDataDeserializer().deserialize(bytes, 0, bytes.length)!;

    final sb = data.experiments[0];
    expect(sb.name, 'exp_test_switchback');
    expect(sb.randomizationType, 'switchback');
    expect(sb.switchbackClusters,
        {'store_id': 'store/key', 'device_id': 'geo/city'});
    // The declared order (unit_type_id ascending) survives deserialization;
    // it is not sorted.
    expect(sb.switchbackClusters!.keys, ['store_id', 'device_id']);
    expect(sb.switchbackClusterValues, ['porto', 'lisbon']);
    expect(sb.switchbackStartAt, 1767225600000);
    expect(sb.switchbackPeriodMs, 3600000);
    expect(sb.switchbackCarryoverDurationMs, 900000);
    expect(sb.switchbackBurnInDurationMs, 600000);
    expect(sb.switchbackBurnOutDurationMs, 0);
    expect(sb.switchbackDesignType, 'balanced_block');
    expect(sb.switchbackEstimand, 'global_average_treatment_effect');
    // Phase 1E fields and unknown fields are ignored.
    expect(
        sb.toMap().keys,
        isNot(anyOf(contains('switchbackClusterCount'),
            contains('switchbackFutureField'))));

    final unit = data.experiments[1];
    expect(unit.randomizationType, 'unit');
    expect(unit.switchbackClusters, isNull);
    expect(unit.switchbackStartAt, isNull);

    // A round trip through toMap keeps every field and the cluster order.
    final again = ContextData.fromMap(jsonDecode(jsonEncode(data.toMap())));
    expect(again, data);
    expect(again.experiments[0].switchbackClusters!.keys,
        ['store_id', 'device_id']);
  });

  test('deserializeWithoutSwitchbackFieldsLeavesThemNull', () async {
    final bytes = await getResourceBytes('context.json');
    final data =
        DefaultContextDataDeserializer().deserialize(bytes, 0, bytes.length)!;
    for (final e in data.experiments) {
      expect(e.randomizationType, isNull);
      expect(e.switchbackClusters, isNull);
      expect(e.switchbackClusterValues, isNull);
      expect(e.switchbackStartAt, isNull);
      expect(e.switchbackPeriodMs, isNull);
      expect(e.switchbackCarryoverDurationMs, isNull);
      expect(e.switchbackBurnInDurationMs, isNull);
      expect(e.switchbackBurnOutDurationMs, isNull);
      expect(e.switchbackDesignType, isNull);
      expect(e.switchbackEstimand, isNull);
      expect(e.toMap().keys.where((k) => k.startsWith('switchback')), isEmpty);
      expect(e.toMap().containsKey('randomizationType'), isFalse);
    }
  });

  // A switchback field of the wrong type reads as absent and never fails the
  // context; an integral double is a whole number of milliseconds.
  // An experiment without switchback fields keeps the hash it had before
  // they existed.
  test('switchback fields survive an isolate copy of the context data',
      () async {
    final json = jsonDecode(
            utf8.decode(await getResourceBytes('switchback_context.json')))
        as Map<String, dynamic>;
    final copied = await Isolate.run(() => ContextData.fromMap(json));
    expect(copied.experiments.first.switchbackClusters!.keys,
        ['store_id', 'device_id']);
    expect(copied.experiments.first.switchbackPeriodMs, 3600000);
  });

  // Unit experiments carrying every switchback field, unknown future fields
  // and Phase 1E fields publish the same bytes as the released probe, and
  // the switchback path is never taken.
  group('publish bytes without switchbacks are unchanged', () {
    for (final fixture in const [
      'context',
      'audience_context',
      'audience_strict_context',
      'custom_fields_context',
    ]) {
      test(fixture, () async {
        final golden = File('test/resources/publish_golden/$fixture.txt')
            .readAsStringSync();
        final payload = await getResourceBytes('$fixture.json');

        ContextCounters.reset();
        expect(await publishProbe(payload), golden);
        expect(ContextCounters.switchbackPeriodLookups, 0);

        for (final type in ['unit', null, 'future_type']) {
          final json = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
          json['switchbackFutureRoot'] = {'a': 1};
          for (final experiment in json['experiments'] as List) {
            experiment
              ..['randomizationType'] = type
              ..['switchbackClusters'] = {'session_id': 'city'}
              ..['switchbackClusterValues'] = []
              ..['switchbackStartAt'] = 0
              ..['switchbackPeriodMs'] = 3600000
              ..['switchbackClusterCount'] = 50
              ..['switchbackClusterAttribute'] = 'city'
              ..['switchbackFutureField'] = {
                'nested': [1, 2, 3]
              };
          }
          ContextCounters.reset();
          expect(await publishProbe(utf8.encode(jsonEncode(json))), golden,
              reason: '$type');
          expect(ContextCounters.switchbackPeriodLookups, 0);
          expect(ContextCounters.switchbackServingResolutions, 0);
        }
      });
    }
  });
}
