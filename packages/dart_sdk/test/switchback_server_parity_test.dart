// Port of java-sdk SwitchbackServerParityTest: replays the Collector's R33
// switchback serving rules through the public Context API. Each case states,
// independently of SDK code, the serving unit type and the raw cluster key the
// Collector picks, or that it records nothing; the expected variant is
// SwitchbackAssigner over that raw key, pinned by the golden vectors, and a
// few schedules are also pinned to an independent murmur3 reference.
import 'dart:io';

import 'package:absmartly_dart/src/internal/switchback_assigner.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:absmartly_dart/src/json/experiment_application.dart';
import 'package:absmartly_dart/src/json/experiment_variant.dart';
import 'package:absmartly_dart/src/json/exposure.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import 'internal/fixture_loader.dart';
import 'switchback_test_support.dart' hide seed, seedHi, seedLo, unitType;

const int periods = 4;
const int arms = 3;
const int parityseed = 1234567890123;
const String storeType = 'store_id';
const String device = 'device_id';
const String user = 'user_id';

Experiment experiment(Map<String, String?> clusters,
    {List<String>? values, int seedValue = parityseed}) {
  return Experiment(
    id: 1,
    name: 'exp_sb',
    // R33 payloads may still carry unitType; it is never used for switchback
    // assignment.
    unitType: user,
    iteration: 1,
    seedHi: (seedValue >> 32).toSigned(32),
    seedLo: seedValue.toSigned(32),
    split: List<double>.filled(arms, 1.0 / arms),
    trafficSeedHi: 0,
    trafficSeedLo: 0,
    trafficSplit: [0.0, 1.0],
    fullOnVariant: 0,
    applications: [ExperimentApplication(name: 'website')],
    variants: [
      for (int i = 0; i < arms; ++i) ExperimentVariant(name: '$i', config: null)
    ],
    audienceStrict: false,
    audience: null,
    randomizationType: 'switchback',
    switchbackClusters: clusters,
    switchbackClusterValues: values,
    switchbackStartAt: anchor,
    switchbackPeriodMs: hour,
    switchbackDesignType: 'balanced_block',
  );
}

int collectorVariant(String rawKey, int periodIndex) =>
    SwitchbackAssigner.assign(
        rawKey, BigInt.from(periodIndex), BigInt.from(parityseed), arms);

class Served {
  final List<int> variants = [];
  late List<Exposure> exposures;
}

// Serves `periods` periods with getTreatment, one call per period.
Future<Served> serve(Experiment e, Map<String, Object> units,
    Map<String, dynamic>? attributes) async {
  final harness = Harness();
  final context = await harness.create(dataOf([e]),
      units: units, attributes: attributes, clusterAttribute: false);
  final served = Served();
  for (int p = 0; p < periods; ++p) {
    harness.clock.now = anchor + p * hour + 1;
    served.variants.add(context.getTreatment('exp_sb'));
  }
  served.exposures = harness.capture.exposures;
  return served;
}

// The Collector served `key` under a unit of `servingType`: one eligible
// exposure per period under that unit, variant from the raw key.
void expectEligible(Served served, String servingType, String key, String m) {
  expect(served.exposures, hasLength(periods), reason: m);
  for (int p = 0; p < periods; ++p) {
    final int expected = collectorVariant(key, p);
    expect(served.variants[p], expected, reason: '$m period $p');
    final e = served.exposures[p];
    expect(e.unit, servingType, reason: m);
    expect(e.variant, expected, reason: m);
    expect(e.assigned, isTrue, reason: m);
    expect(e.eligible, isTrue, reason: m);
    expect(e.exposedAt, anchor + p * hour + 1, reason: m);
  }
}

// The Collector records nothing: control in every period, no exposure.
void expectSilentControl(Served served, String m) {
  expect(served.variants, List.filled(periods, 0), reason: m);
  expect(served.exposures, isEmpty, reason: m);
}

const Map<String, String?> twoSources = {
  storeType: 'store_city',
  device: 'geo/city'
};
const Map<String, Object> twoUnits = {storeType: 's1', device: 'd1'};

void main() {
  test('rawKeySchedulesMatchTheIndependentReference', () async {
    expectEligible(
        await serve(experiment({storeType: 'city'}), {storeType: 's1'},
            {'city': 'Lisboa'}),
        storeType,
        'Lisboa',
        'Lisboa');
    for (int p = 0; p < periods; ++p) {
      expect(collectorVariant('Lisboa', p), [0, 1, 2, 2][p]);
      expect(collectorVariant('Porto', p), [2, 1, 0, 1][p]);
      expect(collectorVariant('42', p), [0, 2, 1, 2][p]);
    }
  });

  test('agreementServesTheFirstSourceUnit', () async {
    expectEligible(
        await serve(experiment(twoSources), twoUnits, {
          'store_city': 'Lisboa',
          'geo': {'city': 'Lisboa'}
        }),
        storeType,
        'Lisboa',
        'agreement');
  });

  test('disagreementIsIneligibleAndRecordsNothing', () async {
    expectSilentControl(
        await serve(experiment(twoSources), twoUnits, {
          'store_city': 'Lisboa',
          'geo': {'city': 'Porto'}
        }),
        'disagreement');
  });

  test('missingValueIsSkippedAndTheNextValueServes', () async {
    expectEligible(
        await serve(experiment(twoSources), twoUnits, {
          'geo': {'city': 'Porto'}
        }),
        device,
        'Porto',
        'first source missing');
    expectEligible(
        await serve(experiment(twoSources), twoUnits, {'store_city': 'Porto'}),
        storeType,
        'Porto',
        'second source missing');
    expectSilentControl(
        await serve(experiment(twoSources), twoUnits, {'other': 'x'}),
        'no value at all');
    expectSilentControl(
        await serve(experiment(twoSources), twoUnits, null), 'no attributes');
  });

  test('onlyLinkedUnitsPresentInTheContextTakePart', () async {
    expectEligible(
        await serve(experiment(twoSources), {
          device: 'd1'
        }, {
          'store_city': 'Lisboa',
          'geo': {'city': 'Porto'}
        }),
        device,
        'Porto',
        'store unit absent');
  });

  test('filteredValueIsIneligibleAndAllowedValueServes', () async {
    const lisboa = {'store_city': 'Lisboa'};
    expectSilentControl(
        await serve(experiment(twoSources, values: ['Porto', 'Faro']), twoUnits,
            lisboa),
        'filtered');
    expectEligible(
        await serve(experiment(twoSources, values: ['Porto', 'Lisboa']),
            twoUnits, lisboa),
        storeType,
        'Lisboa',
        'allowed');
    // A null or empty allow-list admits every value.
    expectEligible(await serve(experiment(twoSources), twoUnits, lisboa),
        storeType, 'Lisboa', 'null filter');
    expectEligible(
        await serve(experiment(twoSources, values: []), twoUnits, lisboa),
        storeType,
        'Lisboa',
        'empty filter');
    // The filter compares the normalised text of numeric values.
    expectEligible(
        await serve(experiment(twoSources, values: ['42']), twoUnits,
            {'store_city': 42}),
        storeType,
        '42',
        'numeric filter');
    // A filtered first value is not replaced by a later allowed one: they
    // disagree.
    expectSilentControl(
        await serve(experiment(twoSources, values: ['Porto']), twoUnits, {
          'store_city': 'Lisboa',
          'geo': {'city': 'Porto'}
        }),
        'filtered first value');
  });

  test('sameTypeSecondUidIsRejected', () async {
    final context = await Harness()
        .create(dataOf([]), units: {storeType: 's1'}, clusterAttribute: false);
    expect(() => context.setUnit(storeType, 's2'), throwsException);
    expectEligible(
        await serve(experiment({storeType: 'city'}), {storeType: 's1'},
            {'city': 'Faro'}),
        storeType,
        'Faro',
        'single unit of the type');
  });

  // The declared order decides, not the order units were set or named.
  test('lowerUnitTypeIdSourceServesFirst', () async {
    const deviceFirst = {device: 'geo/city', storeType: 'store_city'};
    const agreeing = {
      'store_city': 'Lisboa',
      'geo': {'city': 'Lisboa'}
    };
    const units = {storeType: 's1', device: 'd1'};
    expectEligible(await serve(experiment(deviceFirst), units, agreeing),
        device, 'Lisboa', 'device declared first');
    expectEligible(await serve(experiment(twoSources), units, agreeing),
        storeType, 'Lisboa', 'store declared first');
  });

  // Booleans, floating-point numbers, objects, arrays, null and "" yield no
  // value: skipped, never a disagreement. On the web 2.0 is the integer 2.
  test('nonKeyValuesAreIgnored', () async {
    const bool isWeb = identical(0, 0.0);
    for (final value in [
      true,
      false,
      1.5,
      if (!isWeb) 2.0,
      {'a': 'b'},
      ['x'],
      [],
      null,
      ''
    ]) {
      final m = 'ignored $value';
      expectEligible(
          await serve(experiment(twoSources), twoUnits, {
            'store_city': value,
            'geo': {'city': 'Porto'}
          }),
          device,
          'Porto',
          m);
      expectSilentControl(
          await serve(experiment({storeType: 'store_city'}), {storeType: 's1'},
              {'store_city': value}),
          '$m alone');
    }
  });

  // Integral numbers are keyed by their base-10 text, so they agree with
  // that text.
  test('numericValuesAreKeyedAsText', () async {
    for (final store in [42, '42']) {
      for (final dev in [42, '42']) {
        expectEligible(
            await serve(experiment(twoSources), twoUnits, {
              'store_city': store,
              'geo': {'city': dev}
            }),
            storeType,
            '42',
            '$store/$dev');
      }
    }
    expectEligible(
        await serve(experiment({storeType: 'n'}), {storeType: 's1'}, {'n': -7}),
        storeType,
        '-7',
        'negative');
    expectSilentControl(
        await serve(experiment(twoSources), twoUnits, {
          'store_city': 42,
          'geo': {'city': '042'}
        }),
        '42 vs 042 disagree');
  });

  // A malformed path makes the whole experiment unservable: ineligible
  // control for any linked unit, even when another source is valid.
  test('malformedPathsAreUnservable', () async {
    const attributes = {
      'store_city': 'Lisboa',
      'geo': {'city': 'Porto'},
      'geo.city': 'Faro'
    };
    for (final path in [
      "'geo/city",
      '"geo',
      "geo/'city",
      'geo.city',
      'geo/a.b',
      "'geo.city'",
      '"geo.city"'
    ]) {
      expectSilentControl(
          await serve(experiment({storeType: 'store_city', device: path}),
              twoUnits, attributes),
          path);
      expectSilentControl(
          await serve(experiment({device: path}), twoUnits, attributes),
          '$path alone');
    }
  });

  // No context unit of any linked type: the experiment does not apply;
  // unitType is never used.
  test('noLinkedUnitIsAbsent', () async {
    expectSilentControl(
        await serve(
            experiment(twoSources), {user: 'u1'}, {'store_city': 'Lisboa'}),
        'no linked unit');
  });

  // Traffic eligibility is sticky on the serving unit's hash: it equals that
  // of a unit experiment on the serving unit's type with the same traffic
  // seed and split, in every period.
  test('trafficFollowsTheServingUnitHash', () async {
    int eligible = 0;
    int ineligible = 0;
    for (int u = 0; u < 24; ++u) {
      final sb = experiment(twoSources)
        ..trafficSplit = [0.5, 0.5]
        ..trafficSeedHi = 3
        ..trafficSeedLo = 4;
      final twin = experiment(twoSources)
        ..name = 'exp_unit'
        ..id = 2
        ..randomizationType = null
        ..unitType = device
        ..trafficSplit = [0.5, 0.5]
        ..trafficSeedHi = 3
        ..trafficSeedLo = 4;
      final harness = Harness();
      final context = await harness.create(dataOf([sb, twin]),
          units: {storeType: 's1', device: 'device-$u'},
          clusterAttribute: false);
      // Only the device unit has a value, so it serves.
      context.setAttribute('geo', {'city': 'Porto'});
      context.getTreatment('exp_unit');
      final bool twinEligible = harness.capture.exposures[0].eligible;
      for (int p = 0; p < periods; ++p) {
        harness.clock.now = anchor + p * hour;
        final int variant = context.getTreatment('exp_sb');
        final e = harness.capture.exposures[p + 1];
        expect(e.unit, device);
        expect(e.eligible, twinEligible);
        expect(variant, twinEligible ? collectorVariant('Porto', p) : 0);
      }
      twinEligible ? ++eligible : ++ineligible;
    }
    expect(eligible, greaterThan(0));
    expect(ineligible, greaterThan(0));
  });

  // Each attribute-path-cases.json case, served as a cluster path over the
  // fixture's attributes.
  test('attributePathCasesMatchTheCollector', () async {
    final fixture =
        await loadJsonResource('switchback/attribute-path-cases.json')
            as Map<String, dynamic>;
    final attributes = fixture['attributes'] as Map<String, dynamic>;
    int eligibleCases = 0;
    for (final c in fixture['cases'] as List) {
      final served = await serve(experiment({storeType: c['path'] as String}),
          {storeType: 's1'}, attributes);
      if (!(c['supported'] as bool) || c['value'] == null) {
        expectSilentControl(served, '$c');
        continue;
      }
      expectEligible(served, storeType, c['value'] as String, '$c');
      ++eligibleCases;
    }
    expect(eligibleCases, 3);
  });

  // The latest value of a repeated attribute name serves; names are matched
  // trimmed.
  test('repeatedAttributeNamesResolveToTheLatest', () async {
    expectEligible(
        await serve(experiment({storeType: 'cluster'}), {storeType: 's1'},
            {' cluster ': 'Porto'}),
        storeType,
        'Porto',
        'trimmed name');

    final harness = Harness();
    final context = await harness.create(
        dataOf([
          experiment({storeType: 'cluster'})
        ]),
        units: {storeType: 's1'},
        clusterAttribute: false);
    context.setAttribute('cluster', 'Lisboa');
    context.setAttribute('cluster', 'Porto');
    harness.clock.now = anchor + 1;
    expect(context.getTreatment('exp_sb'), collectorVariant('Porto', 0));
    expect(harness.capture.exposures.single.eligible, isTrue);
  });

  // The shared fixtures match the Collector's blobs at absmartly/abs
  // 9bd2b5ca35: lib/utils/src/test/resources/switchback/golden-vectors.json
  // (git blob b314abeb9e97) and
  // collector/src/test/resources/switchback/attribute-path-cases.json (git
  // blob 7b1d3fed5985). The hashes pin these copies to those blobs.
  test('sharedFixturesMatchCollectorBlobs', () {
    String sha(String name) => sha256
        .convert(File('test/resources/switchback/$name').readAsBytesSync())
        .toString();
    expect(sha('golden-vectors.json'),
        '66dda4bafddaa119b030beafff8dc56f5750a8387919ffbe0842c93525ef32b6');
    expect(sha('attribute-path-cases.json'),
        '2ee7eb0053997b48b8992980ffe11fe3accb2db01471aa9a617420e1609c6518');
    expect(
        File('test/resources/switchback/bucket-golden-vectors.json')
            .existsSync(),
        isFalse);
  });
}
