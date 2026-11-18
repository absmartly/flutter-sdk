// Port of java-sdk ContextSwitchbackClusterRuleTest, itself a port of the
// Collector's ContextAPISwitchbackTest ClusterRule section (absmartly/abs
// 9bd2b5ca35), through the public Context API. Each test keeps the
// Collector's name and fixture: switchback "sbc" (id 900, "34/33/33", 1h)
// linked to user_id (unit type id 2) at "profile/store" and to session_id
// (unit type id 1) at "session_store", declared in unit type id order, so
// session_id comes first although the user_id link was inserted first.
//
// The SDK has no request order: a context holds one uid per unit type, so the
// declared source order alone decides which unit serves.
//
// An ineligible Collector response (eligible=false, variant 0, config 0,
// under the first linked request unit in declared order, no exposure) is
// checked through the switchbackResolutionForTest seam: its unit and
// eligibility are not otherwise observable when nothing is published.
import 'package:absmartly_dart/src/context.dart';
import 'package:absmartly_dart/src/internal/hashing/hashing.dart';
import 'package:absmartly_dart/src/internal/switchback_assigner.dart';
import 'package:absmartly_dart/src/internal/variant_assigner.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:absmartly_dart/src/json/experiment_application.dart';
import 'package:absmartly_dart/src/json/experiment_variant.dart';
import 'package:absmartly_dart/src/json/exposure.dart';
import 'package:test/test.dart';

import 'switchback_test_support.dart' hide seedHi, seedLo, seed, unitType;

const int period = 5;
const int now = anchor + period * hour + 17 * 60000;
const int sbcSeedHi = 0x1234;
const int sbcSeedLo = 0x5678abcd;
final BigInt sbcSeed = (BigInt.from(sbcSeedHi) << 32) | BigInt.from(sbcSeedLo);
const int trafficSeedHi = 7;
const int trafficSeedLo = 11;

const String session = 'session_id';
const String user = 'user_id';

Experiment switchbackExperiment(
    String name, int id, String unitType, String split) {
  final List<String> parts = split.split('/');
  return Experiment(
    id: id,
    name: name,
    unitType: unitType,
    iteration: 1,
    seedHi: sbcSeedHi,
    seedLo: sbcSeedLo,
    split: [for (final p in parts) int.parse(p) / 100.0],
    trafficSeedHi: trafficSeedHi,
    trafficSeedLo: trafficSeedLo,
    trafficSplit: [0.0, 1.0],
    fullOnVariant: 0,
    applications: [ExperimentApplication(name: 'website')],
    variants: [
      for (int i = 0; i < parts.length; ++i)
        ExperimentVariant(name: '$i', config: '{"sbc.config":"test config $i"}')
    ],
    audienceStrict: false,
    audience: null,
    randomizationType: 'switchback',
    switchbackStartAt: anchor,
    switchbackPeriodMs: hour,
    switchbackDesignType: 'balanced_block',
  );
}

Experiment unitExperiment(String name, int id, String unitType) =>
    switchbackExperiment(name, id, unitType, '50/50')
      ..randomizationType = null
      ..switchbackStartAt = null
      ..switchbackPeriodMs = null
      ..switchbackDesignType = null
      ..variants = [
        ExperimentVariant(name: '0', config: null),
        ExperimentVariant(name: '1', config: null)
      ];

int scheduled(String clusterKey) =>
    SwitchbackAssigner.assign(clusterKey, BigInt.from(period), sbcSeed, 3);

// The Collector's ExperimentAssignment for "sbc", or null when it lists none
// (not applicable).
class Assigned {
  late String? unit;
  late bool eligible;
  late int variant;
  late bool fullOn;
  late bool ruleOverride;
  late bool silent;
  late String? config;
  late List<Exposure> exposures;
}

Map<String, dynamic> store(dynamic value) => {'store': value};

void main() {
  late Experiment experiment;
  late List<List<String>> links;
  late Harness harness;

  // switchbackClusters in declared (unit type id ascending) order:
  // session_id (1) before user_id (2).
  void refreshLinks() {
    final Map<String, String?> clusters = {};
    for (final type in [session, user, 'device_id']) {
      for (final link in links) {
        if (link[0] == type) {
          clusters[link[0]] = link[1];
        }
      }
    }
    experiment.switchbackClusters = links.isEmpty ? null : clusters;
  }

  void unlinkAll() {
    links.clear();
    refreshLinks();
  }

  void link(String unitType, String path) {
    links.add([unitType, path]);
    refreshLinks();
  }

  setUp(() {
    experiment = switchbackExperiment('sbc', 900, user, '34/33/33');
    links = [];
    unlinkAll();
    link(user, 'profile/store');
    link(session, 'session_store');
  });

  Future<Context> createContext(Map<String, dynamic>? attributes,
      List<Experiment> experiments, Map<String, Object> units,
      {int at = now}) async {
    harness = Harness(now: at);
    return harness.create(dataOf(experiments),
        units: units, attributes: attributes, clusterAttribute: false);
  }

  List<Exposure> sbcExposures() => [
        for (final e in harness.capture.exposures)
          if (e.name == 'sbc') e
      ];

  // Every other experiment is resolved (and exposed) before "sbc". Only
  // "sbc" exposures are returned.
  Future<Assigned?> sbcWith(Map<String, dynamic>? attributes,
      List<Experiment> experiments, Map<String, Object> units) async {
    final context = await createContext(attributes, experiments, units);
    for (final other in experiments) {
      if (other.name != 'sbc') {
        context.getTreatment(other.name);
      }
    }
    final int variant = context.getTreatment('sbc');
    final resolution = switchbackResolutionForTest(context, 'sbc');
    expect(resolution, isNotNull);
    final config = context.getVariableValue('sbc.config', null) as String?;
    final exposures = sbcExposures();
    // Keyed on the serving status, not on assigned: a strict audience
    // mismatch is not assigned yet is still an assignment the Collector
    // lists.
    if (!resolution!.applies) {
      expect(variant, 0);
      expect(config, isNull);
      expect(exposures, isEmpty);
      return null;
    }
    return Assigned()
      ..unit = resolution.unitType
      ..eligible = resolution.eligible
      ..silent = resolution.silent
      ..variant = variant
      ..fullOn = resolution.fullOn
      ..ruleOverride = resolution.ruleOverride
      ..config = config
      ..exposures = exposures;
  }

  Future<Assigned?> sbc(
          Map<String, dynamic>? attributes, Map<String, Object> units) =>
      sbcWith(attributes, [experiment], units);

  // R33-5: an ineligible cluster resolution is still an assignment, as
  // control, under the first linked-type request unit in declared order, and
  // no exposure is recorded for it.
  Future<void> expectIneligible(Map<String, dynamic> attributes,
      String expectedUnit, Map<String, Object> units) async {
    final assignment = await sbc(attributes, units);
    expect(assignment, isNotNull, reason: '$attributes');
    expect(assignment!.unit, expectedUnit);
    expect(assignment.eligible, isFalse);
    expect(assignment.silent, isTrue);
    expect(assignment.variant, 0);
    expect(assignment.fullOn, isFalse);
    expect(assignment.ruleOverride, isFalse);
    expect(assignment.config, 'test config 0');
    expect(assignment.exposures, isEmpty, reason: '$attributes');
  }

  test(
      'missingOrUnreadableClusterConfigurationReturnsOnlyLegacyIneligibleControl',
      () async {
    for (final broken in [
      'null-cluster',
      'missing-links',
      'unreadable-path',
      'geo.city',
      "'geo.city'",
      '"geo.city"',
      'unknown-unit'
    ]) {
      unlinkAll();
      if (broken == 'unreadable-path') {
        link(session, "'geo");
      } else if (broken == 'unknown-unit') {
        // A readable map whose only linked type (device_id) is absent from
        // the request.
        link('device_id', 'session_store');
        expect(await sbc({'session_store': 's-1'}, {session: 'x1', user: 'u1'}),
            isNull,
            reason: broken);
        continue;
      } else if (broken == 'missing-links') {
        experiment.switchbackClusters = {};
      } else if (broken != 'null-cluster') {
        link(session, broken);
      }
      final attributes = {
        'geo': {'city': 'Porto'},
        'geo.city': 'Faro',
        'session_store': 's-1'
      };
      // The declared unit (user_id) only identifies an ineligible control.
      await expectIneligible(attributes, user, {session: 'x1', user: 'u1'});
      // Without a unit of the declared type, there is no response at all.
      expect(await sbc(attributes, {session: 'x1'}), isNull, reason: broken);
    }
  });

  test('trafficUsesServingUidNotExperimentUidInBothRequestOrders', () async {
    // percentageOfTraffic = 40.
    experiment.trafficSplit = [0.6, 0.4];
    final ordinary = unitExperiment('ordinary', 901, user);
    final List<String?> witnesses = [null, null];
    for (int i = 0;
        i < 1000 && (witnesses[0] == null || witnesses[1] == null);
        ++i) {
      final String id = 'traffic-$i';
      final int bucket = VariantAssigner(Hashing.hashUnit(id))
          .assign([0.6, 0.4], trafficSeedHi, trafficSeedLo);
      witnesses[bucket == 0 ? 0 : 1] = id;
    }
    expect(witnesses, everyElement(isNotNull));
    const key = 's-18';
    // The eligible draw must be distinguishable from control.
    expect(scheduled(key), isNot(0));
    for (final servingEligible in [false, true]) {
      final assignment = (await sbcWith({
        'session_store': key,
        'profile': store(key)
      }, [
        experiment,
        ordinary
      ], {
        session: witnesses[servingEligible ? 1 : 0]!,
        user: witnesses[servingEligible ? 0 : 1]!
      }))!;
      expect(assignment.unit, session);
      expect(assignment.eligible, servingEligible);
      expect(assignment.variant, servingEligible ? scheduled(key) : 0);
      // A traffic miss on an eligible cluster is still recorded, under the
      // serving unit.
      expect(assignment.exposures, hasLength(1));
      expect(assignment.exposures.single.unit, session);
      expect(assignment.exposures.single.eligible, servingEligible);
    }
  });

  test('oneMatchingUnitServesItsValue', () async {
    final assignment = (await sbc({'profile': store('s-17')}, {user: 'u1'}))!;
    expect(assignment.eligible, isTrue);
    expect(assignment.unit, user);
    expect(assignment.variant, scheduled('s-17'));
  });

  test('strictAudienceMismatchOnAnEligibleClusterIsListedAsControlAndRecorded',
      () async {
    experiment.audience =
        '{"filter":[{"eq":[{"var":"tier"},{"value":"gold"}]}]}';
    experiment.audienceStrict = true;
    final assignment = (await sbc({'session_store': 's-17'}, {session: 'x1'}))!;
    expect(assignment.unit, session);
    expect(assignment.eligible, isTrue);
    expect(assignment.silent, isFalse);
    expect(assignment.variant, 0);
    expect(assignment.exposures, hasLength(1));
    expect(assignment.exposures.single.audienceMismatch, isTrue);
    expect(assignment.exposures.single.assigned, isFalse);
  });

  test('twoAgreeingUnitsServeTheValue', () async {
    final assignment = (await sbc(
        {'profile': store('s-17'), 'session_store': 's-17'},
        {user: 'u1', session: 'x1'}))!;
    expect(assignment.eligible, isTrue);
    expect(assignment.variant, scheduled('s-17'));
  });

  test('twoDisagreeingUnitsAreIneligible', () async {
    // session_id (type id 1) is first in declared order whatever the request
    // order.
    await expectIneligible({'profile': store('s-17'), 'session_store': 's-18'},
        session, {user: 'u1', session: 'x1'});
  });

  // A context holds one uid per unit type, so a second session_id uid is
  // rejected and only the single-unit path is reproducible.
  test('twoUnitsOfOneTypeWithOnePathAgreeOnTheSameValue', () async {
    const key = 's-17';
    expect(scheduled(key), isNot(0));
    final context = await createContext(
        {'session_store': key}, [experiment], {session: 'x1'});
    expect(() => context.setUnit(session, 'x2'), throwsException);

    final assignment = (await sbc({'session_store': key}, {session: 'x1'}))!;
    expect(assignment.eligible, isTrue);
    expect(assignment.variant, scheduled(key));
  });

  test('noMatchingUnitIsIneligible', () async {
    // A value at the path, but no unit of a linked type.
    expect(await sbc({'session_store': 's-1'}, {'device_id': 'd1'}), isNull);
    expect(await sbc({'session_store': 's-1'}, {}), isNull);
  });

  test('matchingUnitWithoutAValueIsIneligible', () async {
    await expectIneligible({'other': 's-1'}, user, {user: 'u1'});
    await expectIneligible(
        {'other': 's-1'}, session, {user: 'u1', session: 'x1'});
  });

  test('nonStringNonIntegerValuesAreIneligible', () async {
    const bool isWeb = identical(0, 0.0);
    for (final value in [
      1.5,
      // The web cannot tell 3.0 from 3: there it keys "3".
      if (!isWeb) 3.0,
      true,
      {'a': 1},
      ['a'],
      ''
    ]) {
      await expectIneligible(
          {'session_store': value}, session, {session: 'x1'});
    }
  });

  test('wholeNumbersAreKeyedByTheirDecimalText', () async {
    expect(scheduled('17'), isNot(0));
    final assignment = (await sbc({'session_store': 17}, {session: 'x1'}))!;
    expect(assignment.eligible, isTrue);
    expect(assignment.variant, scheduled('17'));
    // Equal to the string "17" from another unit type, so the two agree.
    expect(
        (await sbc({'session_store': 17, 'profile': store('17')},
                {session: 'x1', user: 'u1'}))!
            .eligible,
        isTrue);
  });

  test('nestedAndArrayPathsAreRead', () async {
    unlinkAll();
    link(session, 'items/1/store');
    final assignment = (await sbc({
      'items': [store('a'), store('b')]
    }, {
      session: 'x1'
    }))!;
    expect(assignment.variant, scheduled('b'));
    expect(scheduled('a'), isNot(scheduled('b')));
  });

  test(
      'exposureUnitIsTheFirstMatchingUnitInDeclaredOrderWhateverTheRequestOrder',
      () async {
    const key = 's-18';
    expect(scheduled(key), isNot(0));
    final assignment = (await sbc({'profile': store(key), 'session_store': key},
        {user: 'u1', session: 'x1'}))!;
    expect(assignment.unit, session);
    expect(assignment.exposures.single.unit, session);
    expect(assignment.variant, scheduled(key));
  });

  test('ineligibleClusterNeverPublishesAnExposure', () async {
    final context = await createContext(
        {'session_store': 'a', 'profile': store('b')},
        [experiment],
        {user: 'u1', session: 'x1'});
    expect(context.getTreatment('sbc'), 0);
    expect(context.getPendingCount(), 0);
    await context.publish();
    expect(harness.publisher.events, isEmpty);
    expect(harness.capture.exposures, isEmpty);
  });

  test('aUnitWithoutAValueDoesNotServeEvenIfFirstInDeclaredOrder', () async {
    const key = 's-17';
    expect(scheduled(key), isNot(0));
    final assignment =
        (await sbc({'profile': store(key)}, {session: 'x1', user: 'u1'}))!;
    expect(assignment.unit, user);
    expect(assignment.exposures.single.unit, user);
    expect(assignment.variant, scheduled(key));
  });

  test('valueNotInTheFilterIsIneligible', () async {
    experiment.switchbackClusterValues = ['s-1', 's-2'];
    await expectIneligible({'session_store': 's-3'}, session, {session: 'x1'});
    final allowed = (await sbc({'session_store': 's-2'}, {session: 'x1'}))!;
    expect(allowed.eligible, isTrue);
    expect(allowed.variant, scheduled('s-2'));
  });

  test('nullFilterAssignsEveryValue', () async {
    experiment.switchbackClusterValues = null;
    for (int i = 0; i < 20; ++i) {
      final assignment =
          (await sbc({'session_store': 's-$i'}, {session: 'x1'}))!;
      expect(assignment.eligible, isTrue);
      expect(assignment.variant, scheduled('s-$i'));
    }
  });

  // A valid cluster map whose linked types are all absent from the request
  // does not fall back to the experiment's declared unitType.
  test('validClusterWithoutLinkedRequestUnitDoesNotFallBackToExperimentUnit',
      () async {
    unlinkAll();
    link(session, 'session_store');
    const key = 's-17';
    expect(scheduled(key), isNot(0));

    expect(
        await sbc({'session_store': key, 'profile': store(key)}, {user: 'u1'}),
        isNull);
    final linked =
        (await sbc({'session_store': key}, {user: 'u1', session: 'x1'}))!;
    expect(linked.unit, session);
    expect(linked.variant, scheduled(key));
  });

  // The Collector's wire-rule oracle SdkSwitchbackRule, transcribed: period
  // index from the anchor re-ceiled to the hour, traffic on the serving uid's
  // hash, then the schedule draw over the cluster key. A null cluster key has
  // no draw. It shares SwitchbackAssigner, VariantAssigner and Hashing with
  // the SDK, so it is a wire-rule parity check, not an independent oracle.
  int? oraclePeriodIndex(Experiment e, int nowMs) {
    final int? startAt = e.switchbackStartAt;
    final int? periodMs = e.switchbackPeriodMs;
    if (startAt == null || periodMs == null || periodMs <= 0) {
      return null;
    }
    if (e.split.length < 2) {
      return null;
    }
    // -floorDiv(-startAt, HOUR) * HOUR: the anchor ceiled to the hour.
    final int start = -((-startAt) / hour).floor() * hour;
    if (nowMs < start) {
      return null;
    }
    return (nowMs - start) ~/ periodMs;
  }

  // (variant, eligible)
  (int, bool) oracle(Experiment e, String uid, String? key, int nowMs) {
    final int? periodIndex = oraclePeriodIndex(e, nowMs);
    if (key == null || periodIndex == null) {
      return (0, false);
    }
    final bool eligible = VariantAssigner(Hashing.hashUnit(uid))
            .assign(e.trafficSplit, e.trafficSeedHi, e.trafficSeedLo) ==
        1;
    if (!eligible) {
      return (0, false);
    }
    return (
      SwitchbackAssigner.assign(
          key, BigInt.from(periodIndex), sbcSeed, e.split.length),
      true
    );
  }

  Future<Context> gridContext(
      String cluster, String uid, String key, int at) async {
    unlinkAll();
    link(session, 'session_store');
    experiment.switchbackClusterValues = null;
    switch (cluster) {
      case 'disagreeing':
        link(user, 'profile/store');
        return createContext({
          'session_store': key,
          'profile': store('$key-other')
        }, [
          experiment
        ], {
          session: uid,
          user: 'u-$uid'
        }, at: at);
      case 'missing':
        return createContext({'other': key}, [experiment], {session: uid},
            at: at);
      case 'filtered':
        experiment.switchbackClusterValues = ['$key-allowed'];
        return createContext(
            {'session_store': key}, [experiment], {session: uid},
            at: at);
      default:
        return createContext(
            {'session_store': key}, [experiment], {session: uid},
            at: at);
    }
  }

  test('contextMatchesTheSdkSwitchbackWireRuleParityGrid', () async {
    int eligible = 0;
    int ineligible = 0;
    int trafficMisses = 0;
    for (final cluster in ['single', 'disagreeing', 'missing', 'filtered']) {
      for (final a in [anchor, anchor + 7 * hour]) {
        for (final periodMs in [hour, 2 * hour, 24 * hour]) {
          experiment.trafficSplit = [0.3, 0.7];
          experiment.switchbackStartAt = a;
          experiment.switchbackPeriodMs = periodMs;
          for (int u = 0; u < 6; ++u) {
            final String uid = 'uid-$u';
            for (final key in ['s-1', 's-2', '42', 'Lisboa']) {
              for (final at in [
                a - hour,
                a - 1,
                a,
                a + periodMs - 1,
                a + periodMs,
                a + 3 * periodMs + 5,
                a + 11 * periodMs
              ]) {
                final String? oracleKey = cluster == 'single' ? key : null;
                final (variant, isEligible) =
                    oracle(experiment, uid, oracleKey, at);
                final context = await gridContext(cluster, uid, key, at);
                final message = '$cluster/$a/$periodMs/$uid/$key/$at';
                expect(context.getTreatment('sbc'), variant, reason: message);
                expect(switchbackResolutionForTest(context, 'sbc')!.eligible,
                    isEligible,
                    reason: message);
                // Before the anchor nothing is recorded; from it, a keyed
                // cluster records one exposure whose eligibility is the
                // oracle's (a traffic miss included).
                final int expectedExposures =
                    (oracleKey != null && at >= a) ? 1 : 0;
                expect(harness.capture.exposures, hasLength(expectedExposures),
                    reason: message);
                if (expectedExposures == 1) {
                  expect(harness.capture.exposures.single.eligible, isEligible,
                      reason: message);
                }
                if (cluster == 'single') {
                  if (isEligible) {
                    ++eligible;
                  } else {
                    ++ineligible;
                    if (at >= a) {
                      ++trafficMisses;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    expect(eligible, greaterThan(100));
    expect(ineligible, greaterThan(100));
    expect(trafficMisses, greaterThan(0));

    // The deliberate divergence: an anchor off the hour is unservable in the
    // SDK (as in the Collector's Registry), while the transcribed oracle
    // would re-ceil it and draw.
    const int unaligned = anchor + 7 * hour + 1;
    experiment.trafficSplit = [0.0, 1.0];
    experiment.switchbackStartAt = unaligned;
    experiment.switchbackPeriodMs = hour;
    const int at = anchor + 8 * hour + 5;
    expect(oraclePeriodIndex(experiment, at), isNotNull);
    expect(oracle(experiment, 'uid-0', 's-1', at).$2, isTrue);
    final context = await gridContext('single', 'uid-0', 's-1', at);
    expect(context.getTreatment('sbc'), 0);
    expect(switchbackResolutionForTest(context, 'sbc')!.eligible, isFalse);
    expect(harness.capture.exposures, isEmpty);
  });
}
