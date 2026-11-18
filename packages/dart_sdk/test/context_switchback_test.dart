// Port of java-sdk ContextSwitchbackTest (core-api, java-sdk#15). Java test
// names are kept so each case can be traced back. The concurrency and
// lock-deadlock cases have no Dart counterpart: a Context is used from one
// isolate and resolves synchronously.
import 'package:absmartly_dart/src/context.dart';
import 'package:absmartly_dart/src/internal/context_counters.dart';
import 'package:absmartly_dart/src/internal/hashing/hashing.dart';
import 'package:absmartly_dart/src/internal/variant_assigner.dart';
import 'package:absmartly_dart/src/json/context_data.dart';
import 'package:absmartly_dart/src/json/context_holdout.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:absmartly_dart/src/json/experiment_variant.dart';
import 'package:absmartly_dart/src/json/exposure.dart';
import 'package:test/test.dart';

import 'switchback_test_support.dart';

// Periods 0..11 of the raw cluster key "store-42" under seed (seedHi, seedLo),
// from java-sdk's independent Python reference (murmur3 over the platform
// formulas) that reproduces every golden-vectors.json case.
const List<int> expected2Arms = [0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1];
const List<int> expected3Arms = [0, 2, 1, 2, 1, 0, 1, 2, 0, 1, 0, 2];
const List<int> expected10Arms = [8, 3, 7, 4, 2, 0, 5, 1, 9, 6, 3, 7];
// Same reference fed uidHash and the raw uid: what keying by the unit
// instead of the cluster value would serve.
const List<int> uidHash3Arms = [1, 2, 0, 2, 1, 0, 2, 0, 1, 1, 2, 0];
const List<int> uid3Arms = [2, 0, 1, 0, 1, 2, 1, 2, 0, 0, 1, 2];

const String assignVariant1 =
    '{"rules":[{"type":"assign","environments":[],"variant":1}]}';
const String assignVariant2 =
    '{"rules":[{"type":"assign","environments":[],"variant":2}]}';
// An audience the default context never matches (no "tier" attribute).
const String strictGoldAudience =
    '{"filter":[{"eq":[{"var":"tier"},{"value":"gold"}]}]}';

// Holdout 11 for uid under seed (13, 111); split decides whether uid is
// held out.
ContextHoldout holdout(List<double> split) => ContextHoldout(
    id: 11,
    name: 'holdout_a',
    unitType: unitType,
    iteration: 1,
    seedHi: 13,
    seedLo: 111,
    split: split);

// A rule win is published exactly like a unit experiment's: ruleOverride
// set, assigned false.
Exposure ruleExposure(String name, int variant, int exposedAt) =>
    exposure(1, name, variant, exposedAt, assigned: false, ruleOverride: true);

Exposure strictMismatchExposure(int exposedAt) =>
    exposure(1, 'exp_sb', 0, exposedAt,
        assigned: false, audienceMismatch: true);

// The branches of the java-sdk SWITCHBACK.md "Exposure flags" table: every
// branch an eligible-cluster switchback shares with a unit experiment.
enum ParityBranch {
  override,
  overrideOverStrictMismatch,
  rule,
  ruleOverStrictMismatch,
  strictMismatch,
  strictMismatchOverFullOn,
  strictMismatchOverTrafficMiss,
  nonStrictMismatch,
  fullOn,
  trafficMiss,
  custom,
  draw;

  void configureExperiment(Experiment experiment) {
    switch (this) {
      case overrideOverStrictMismatch:
      case ruleOverStrictMismatch:
      case strictMismatch:
        experiment.audience = strictGoldAudience;
        experiment.audienceStrict = true;
      case strictMismatchOverFullOn:
        experiment.audience = strictGoldAudience;
        experiment.audienceStrict = true;
        experiment.fullOnVariant = 2;
      case strictMismatchOverTrafficMiss:
        experiment.audience = strictGoldAudience;
        experiment.audienceStrict = true;
        experiment.trafficSplit = [1.0, 0.0];
      case nonStrictMismatch:
        experiment.audience = strictGoldAudience;
      case fullOn:
        experiment.fullOnVariant = 2;
      case trafficMiss:
        experiment.trafficSplit = [1.0, 0.0];
      default:
        break;
    }
    if (this == rule || this == ruleOverStrictMismatch) {
      experiment.assignmentRules = assignVariant2;
    }
  }

  void configureContext(Context context) {
    if (this == override || this == overrideOverStrictMismatch) {
      context.setOverride('exp_parity', 2);
    } else if (this == custom) {
      context.setCustomAssignment('exp_parity', 2);
    }
  }
}

// Columns: assigned, eligible, overridden, fullOn, custom, audienceMismatch,
// ruleOverride.
const Map<ParityBranch, List<bool>> exposureFlags = {
  ParityBranch.override: [false, true, true, false, false, false, false],
  ParityBranch.overrideOverStrictMismatch: [
    false,
    true,
    true,
    false,
    false,
    false,
    false
  ],
  ParityBranch.rule: [false, true, false, false, false, false, true],
  ParityBranch.ruleOverStrictMismatch: [
    false,
    true,
    false,
    false,
    false,
    false,
    true
  ],
  ParityBranch.strictMismatch: [false, true, false, false, false, true, false],
  ParityBranch.strictMismatchOverFullOn: [
    false,
    true,
    false,
    false,
    false,
    true,
    false
  ],
  ParityBranch.strictMismatchOverTrafficMiss: [
    false,
    true,
    false,
    false,
    false,
    true,
    false
  ],
  ParityBranch.nonStrictMismatch: [
    true,
    true,
    false,
    false,
    false,
    true,
    false
  ],
  ParityBranch.fullOn: [true, true, false, true, false, false, false],
  ParityBranch.trafficMiss: [true, false, false, false, false, false, false],
  ParityBranch.custom: [true, true, false, false, true, false, false],
  ParityBranch.draw: [true, true, false, false, false, false, false],
};

// The variant each branch serves at anchor + 2 * hour + 3 (period 2, whose
// 3-arm draw is 1). Override, rule, full-on and custom all force arm 2, which
// differs from both control and the draw.
final Map<ParityBranch, int> expectedVariant = {
  ParityBranch.override: 2,
  ParityBranch.overrideOverStrictMismatch: 2,
  ParityBranch.rule: 2,
  ParityBranch.ruleOverStrictMismatch: 2,
  ParityBranch.strictMismatch: 0,
  ParityBranch.strictMismatchOverFullOn: 0,
  ParityBranch.strictMismatchOverTrafficMiss: 0,
  ParityBranch.nonStrictMismatch: expected3Arms[2],
  ParityBranch.fullOn: 2,
  ParityBranch.trafficMiss: 0,
  ParityBranch.custom: 2,
  ParityBranch.draw: expected3Arms[2],
};

List<bool> flagsOf(Exposure e) => [
      e.assigned,
      e.eligible,
      e.overridden,
      e.fullOn,
      e.custom,
      e.audienceMismatch,
      e.ruleOverride
    ];

void main() {
  late Harness h;

  setUp(() {
    h = Harness();
  });

  // The cluster identity is the raw attribute value, neither hashed nor the
  // unit uid.
  test('clusterIdentityIsTheRawClusterValue', () async {
    expect(String.fromCharCodes(Hashing.hashUnit(uid)), uidHash);

    final context = await h.create(dataOf([sb(3, hour)]));
    final served = h.peekSchedule(context, 'exp_sb', hour, 12);

    expect(served, expected3Arms);
    expect(served, isNot(uidHash3Arms));
    expect(served, isNot(uid3Arms));
    final String hashedKey = String.fromCharCodes(Hashing.hashUnit(clusterKey));
    bool hashedDiffers = false;
    for (int i = 0; i < 12; ++i) {
      expect(served[i], draw(clusterKey, i, 3));
      hashedDiffers |= draw(hashedKey, i, 3) != served[i];
    }
    expect(hashedDiffers, isTrue);
  });

  test('servesTwoThreeAndTenArmPermutations', () async {
    final context = await h.create(dataOf([
      switchback(1, 'exp_2', 2, hour),
      switchback(2, 'exp_3', 3, hour),
      switchback(3, 'exp_10', 10, hour),
    ]));

    expect(h.peekSchedule(context, 'exp_2', hour, 12), expected2Arms);
    expect(h.peekSchedule(context, 'exp_3', hour, 12), expected3Arms);
    expect(h.peekSchedule(context, 'exp_10', hour, 12), expected10Arms);
  });

  test('oneHourBoundaryAtExactEdgeMilliseconds', () async {
    final context = await h.create(dataOf([sb(2, hour)]));

    final cases = {
      anchor - 1: 0,
      anchor: expected2Arms[0],
      anchor + hour - 1: expected2Arms[0],
      anchor + hour: expected2Arms[1],
      anchor + 3 * hour - 1: expected2Arms[2],
      anchor + 3 * hour: expected2Arms[3],
    };
    cases.forEach((now, variant) {
      h.clock.now = now;
      expect(context.peekTreatment('exp_sb'), variant, reason: '$now');
    });
  });

  test('twentyFourHourBoundaryAtExactEdgeMilliseconds', () async {
    final context = await h.create(dataOf([sb(2, day)]));

    final cases = {
      anchor - 1: 0,
      anchor: expected2Arms[0],
      anchor + hour: expected2Arms[0],
      anchor + day - 1: expected2Arms[0],
      anchor + day: expected2Arms[1],
      anchor + 4 * day - 1: expected2Arms[3],
      anchor + 4 * day: expected2Arms[4],
    };
    cases.forEach((now, variant) {
      h.clock.now = now;
      expect(context.peekTreatment('exp_sb'), variant, reason: '$now');
    });
  });

  // switchbackStartAt is the anchor, never rounded; before it the experiment
  // is an ineligible control that records no exposure. An anchor that is not
  // hour aligned is unservable: ineligible control in every period.
  test('unalignedStartIsUnservableAndPreAnchorIsIneligible', () async {
    final aligned = switchback(1, 'exp_aligned', 2, hour)
      ..switchbackStartAt = anchor + hour;
    const int start = anchor + 1234567;
    final unaligned = switchback(2, 'exp_unaligned', 2, hour)
      ..switchbackStartAt = start;
    final context = await h.create(dataOf([aligned, unaligned]));

    for (final now in [anchor, start - 1, start, anchor + hour - 1]) {
      h.clock.now = now;
      expect(context.getTreatment('exp_aligned'), 0);
      expect(context.getTreatment('exp_unaligned'), 0);
    }
    expect(context.getPendingCount(), 0);
    for (int i = 1; i < 4; ++i) {
      h.clock.now = anchor + i * hour;
      expect(context.getTreatment('exp_aligned'), expected2Arms[i - 1]);
      expect(context.getTreatment('exp_unaligned'), 0);
      h.clock.now = start + i * hour;
      expect(context.getTreatment('exp_unaligned'), 0);
    }

    expect(await h.publishExposures(context), [
      exposure(1, 'exp_aligned', expected2Arms[0], anchor + hour),
      exposure(1, 'exp_aligned', expected2Arms[1], anchor + 2 * hour),
      exposure(1, 'exp_aligned', expected2Arms[2], anchor + 3 * hour),
    ]);
  });

  test('anchorNotOnAnHourBoundaryIsUnservableOnGetAndPost', () async {
    const int maxAnchor = 253402300800000;
    // Long.MAX_VALUE - (Long.MAX_VALUE % HOUR), written so it compiles to JS.
    final int maxAligned = int.parse('9223372036853600000');
    for (final startAt in [
      anchor + 1,
      anchor - 1,
      anchor + 30 * 60000,
      anchor + hour - 1,
      -hour,
      -1,
      maxAnchor,
      maxAnchor + hour,
      maxAligned,
    ]) {
      final harness = Harness(now: 0);
      final experiment = sb(2, hour)..switchbackStartAt = startAt;
      final context = await harness.create(dataOf([experiment]));
      for (final now in [
        0,
        anchor,
        anchor + 2 * hour + 1,
        startAt,
        startAt + hour,
        maxAnchor + day
      ]) {
        harness.clock.now = now;
        expect(context.getTreatment('exp_sb'), 0, reason: '$startAt $now');
        expect(context.getVariableValue('sb.arm', -1), 0);
      }
      expect(context.getPendingCount(), 0, reason: '$startAt');
      await context.publish();
      expect(harness.publisher.events, isEmpty);
    }

    // In-range hour-aligned anchors, including 0 and the last hour before the
    // bound, serve.
    for (final startAt in [0, anchor, maxAnchor - hour]) {
      final harness = Harness(now: startAt + hour);
      final experiment = sb(2, hour)..switchbackStartAt = startAt;
      final context = await harness.create(dataOf([experiment]));
      expect(context.getTreatment('exp_sb'), expected2Arms[1],
          reason: '$startAt');
      expect(context.getPendingCount(), 1);
    }
  });

  test('nullStartAtIsIneligibleAndNeverFallsBackToUnitAssignment', () async {
    final context =
        await h.create(dataOf([sb(2, hour)..switchbackStartAt = null]));

    for (int i = 0; i < 4; ++i) {
      h.clock.now = anchor + i * hour;
      expect(context.getTreatment('exp_sb'), 0);
      // Variant 0's own config, like any ineligible assignment.
      expect(context.getVariableValue('sb.arm', -1), 0);
    }
    expect(context.getPendingCount(), 0);
  });

  test('samePeriodIsCachedAndNextPeriodRollsOverWithOneExposureEach', () async {
    final context = await h.create(dataOf([sb(2, hour)]));

    h.clock.now = anchor + 10;
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 1);
    h.clock.now = anchor + hour - 1;
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.peekTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 1);

    h.clock.now = anchor + hour;
    expect(context.peekTreatment('exp_sb'), expected2Arms[1]);
    expect(context.getPendingCount(), 1);
    expect(context.getTreatment('exp_sb'), expected2Arms[1]);
    expect(context.getPendingCount(), 2);
    h.clock.now = anchor + hour + 30 * 60000;
    expect(context.getTreatment('exp_sb'), expected2Arms[1]);
    expect(context.getPendingCount(), 2);

    expect(await h.publishExposures(context), [
      exposure(1, 'exp_sb', expected2Arms[0], anchor + 10),
      exposure(1, 'exp_sb', expected2Arms[1], anchor + hour),
    ]);
  });

  test('variableLookupsFollowThePeriodAndExposeOncePerPeriod', () async {
    final context = await h.create(dataOf([sb(3, hour)]));

    expect(context.getVariableKeys(), {
      'sb.arm': ['exp_sb']
    });
    expect(context.getExperiments(), ['exp_sb']);

    for (int i = 0; i < 3; ++i) {
      h.clock.now = anchor + i * hour;
      expect(context.peekVariableValue('sb.arm', -1), expected3Arms[i]);
      expect(context.getVariableValue('sb.arm', -1), expected3Arms[i]);
      expect(context.getVariableValue('sb.arm', -1), expected3Arms[i]);
      expect(context.getTreatment('exp_sb'), expected3Arms[i]);
    }
    expect(context.getPendingCount(), 3);
  });

  // No unit of a linked type: the experiment does not apply and records
  // nothing. unitType is never a fallback.
  test('missingClusterUnitIsUnassignedWithoutFallback', () async {
    final context = await h.create(dataOf([sb(2, hour)..unitType = 'user_id']),
        units: {'user_id': uid});

    for (int i = 0; i < 3; ++i) {
      h.clock.now = anchor + i * hour;
      expect(context.peekTreatment('exp_sb'), 0);
      expect(context.getTreatment('exp_sb'), 0);
      expect(context.getVariableValue('sb.arm', -1), -1);
    }
    expect(context.getPendingCount(), 0);

    // Setting a linked unit later makes the experiment apply.
    context.setUnit(unitType, uid);
    expect(context.getTreatment('exp_sb'), expected2Arms[2]);
    expect(await h.publishExposures(context),
        [exposure(1, 'exp_sb', expected2Arms[2], anchor + 2 * hour)]);
  });

  // An override on a switchback with no linked unit is kept by setUnit until
  // exposed, and an exposed one is kept for good, as for a unit experiment.
  test('setUnitKeepsAnExposedOverrideOfANotApplyingSwitchback', () async {
    final context = await h.create(dataOf([sb(2, hour)..unitType = 'user_id']),
        units: {'user_id': uid});
    context.setOverride('exp_sb', 1);
    expect(context.getTreatment('exp_sb'), 1);
    final exposed = context.getAssignment('exp_sb');
    context.setUnit(unitType, uid);
    expect(context.getAssignment('exp_sb'), same(exposed));
    expect(await h.publishExposures(context), [
      exposure(1, 'exp_sb', 1, anchor, assigned: false, overridden: true),
    ]);
  });

  test('fullOnServesTheFullOnVariantInEveryPeriod', () async {
    final context = await h.create(dataOf([sb(3, hour)..fullOnVariant = 2]));

    for (int i = 0; i < 4; ++i) {
      h.clock.now = anchor + i * hour;
      expect(context.getTreatment('exp_sb'), 2);
    }
    final exposures = await h.publishExposures(context);
    expect(exposures, hasLength(4));
    for (final e in exposures) {
      expect(e.variant, 2);
      expect(e.fullOn, isTrue);
    }
  });

  test('overrideAndCustomAssignmentWinInEveryPeriod', () async {
    final context = await h.create(dataOf([
      switchback(1, 'exp_override', 3, hour),
      switchback(2, 'exp_custom', 3, hour),
    ]));
    context.setOverride('exp_override', 7);
    context.setCustomAssignment('exp_custom', 2);

    for (int i = 0; i < 3; ++i) {
      h.clock.now = anchor + i * hour;
      expect(context.getTreatment('exp_override'), 7);
      expect(context.getTreatment('exp_custom'), 2);
    }
    final exposures = await h.publishExposures(context);
    // Each period has its own slot, so each exposes once.
    expect(exposures, hasLength(6));
    for (final e in exposures) {
      if (e.name == 'exp_override') {
        expect(e.overridden, isTrue);
        expect(e.variant, 7);
      } else {
        expect(e.custom, isTrue);
        expect(e.variant, 2);
      }
    }
  });

  // Traffic eligibility uses the per-unit traffic hash, so it matches a
  // unit-randomized twin with the same traffic seed and stays fixed across
  // periods.
  test('trafficEligibilityIsClusterSticky', () async {
    int eligibleCount = 0;
    int ineligibleCount = 0;
    for (int u = 0; u < 24; ++u) {
      final harness = Harness();
      final sbExperiment = switchback(1, 'exp_sb', 2, hour)
        ..trafficSplit = [0.5, 0.5];
      final twin = asUnit(switchback(2, 'exp_unit', 2, hour))
        ..trafficSplit = [0.5, 0.5];
      final context = await harness
          .create(dataOf([sbExperiment, twin]), units: {unitType: 'store_$u'});
      context.getTreatment('exp_unit');
      for (int i = 0; i < 4; ++i) {
        harness.clock.now = anchor + i * hour;
        context.getTreatment('exp_sb');
      }

      final exposures = await harness.publishExposures(context);
      expect(exposures, hasLength(5));
      final bool twinEligible = exposures[0].eligible;
      for (int i = 1; i < exposures.length; ++i) {
        expect(exposures[i].name, 'exp_sb');
        expect(exposures[i].eligible, twinEligible);
        if (!twinEligible) {
          expect(exposures[i].variant, 0);
        }
      }
      twinEligible ? ++eligibleCount : ++ineligibleCount;
    }
    expect(eligibleCount, greaterThan(0));
    expect(ineligibleCount, greaterThan(0));
  });

  test('unitExperimentsAreUnaffected', () async {
    final unit = sb(2, hour)..randomizationType = 'unit';
    final absent = switchback(1, 'exp_absent', 2, hour)
      ..randomizationType = null;
    final context = await h.create(dataOf([unit, absent]));
    final variant = context.getTreatment('exp_sb');
    final absentVariant = context.getTreatment('exp_absent');
    for (int i = 1; i < 6; ++i) {
      h.clock.now = anchor + i * hour;
      expect(context.getTreatment('exp_sb'), variant);
      expect(context.getTreatment('exp_absent'), absentVariant);
    }
    expect(context.getPendingCount(), 2);
  });

  test('refreshInvalidatesWhenGridFieldsChangeButNotForAnalysisOnlyFields',
      () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor + 10;
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 1);

    await h.refreshTo(context, [
      sb(2, hour)
        ..switchbackBurnInDurationMs = 600000
        ..switchbackBurnOutDurationMs = 300000
        ..switchbackCarryoverDurationMs = 900000
        ..switchbackEstimand = 'other'
    ]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 1);

    // Same period index 0 under both grids, so only the config comparison
    // can invalidate.
    await h.refreshTo(context, [sb(2, 2 * hour)]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 2);

    await h.refreshTo(
        context, [sb(2, 2 * hour)..switchbackDesignType = 'other_design']);
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 3);

    await h.refreshTo(context, [sb(2, 2 * hour)..randomizationType = 'unit']);
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 4);

    await h.refreshTo(context, [sb(2, 2 * hour)]);
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 5);

    // The cluster map (types, paths and their order) and the allow-list are
    // identity.
    await h.refreshTo(context, [
      sb(2, 2 * hour)..switchbackClusters = {unitType: "'store_key'"}
    ]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 6);

    await h.refreshTo(context, [
      sb(2, 2 * hour)
        ..switchbackClusters = {unitType: "'store_key'", 'device_id': 'city'}
    ]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 7);

    final reordered = {'device_id': 'city', unitType: "'store_key'"};
    await h
        .refreshTo(context, [sb(2, 2 * hour)..switchbackClusters = reordered]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 8);

    await h.refreshTo(context, [
      sb(2, 2 * hour)
        ..switchbackClusters = reordered
        ..switchbackClusterValues = [clusterKey]
    ]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 9);

    // An unrelated unitType edit is not identity: switchbacks never read it.
    await h.refreshTo(context, [
      sb(2, 2 * hour)
        ..switchbackClusters = reordered
        ..switchbackClusterValues = [clusterKey]
        ..unitType = 'anything'
    ]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 9);
  });

  test('refreshSettingStartAtStartsTheGrid', () async {
    final context =
        await h.create(dataOf([sb(2, hour)..switchbackStartAt = null]));
    h.clock.now = anchor + 10;
    expect(context.getTreatment('exp_sb'), 0);

    await h.refreshTo(context, [sb(2, hour)]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 1);
  });

  // Holdouts never apply to a switchback: a holdout that would hold the unit
  // out neither suppresses the switchback nor records its own exposure
  // through it.
  test('holdoutSuppressionAndExposureSpanPeriods', () async {
    final context = await h.create(ContextData(experiments: [
      sb(2, hour)..holdoutIds = [11]
    ], holdouts: [
      holdout(const [0.1, 0.9])
    ]));
    for (int i = 0; i < 3; ++i) {
      h.clock.now = anchor + i * hour;
      expect(context.getTreatment('exp_sb'), expected2Arms[i]);
      expect(context.getVariableValue('sb.arm', -1), expected2Arms[i]);
    }

    expect(await h.publishExposures(context), [
      exposure(1, 'exp_sb', expected2Arms[0], anchor),
      exposure(1, 'exp_sb', expected2Arms[1], anchor + hour),
      exposure(1, 'exp_sb', expected2Arms[2], anchor + 2 * hour),
    ]);
    // The covered unit experiment twin is held out by the same holdout, so
    // the fixture does hold uid out.
    final twin = await Harness().create(ContextData(experiments: [
      asUnit(sb(2, hour))..holdoutIds = [11]
    ], holdouts: [
      holdout(const [0.1, 0.9])
    ]));
    expect(twin.getTreatment('exp_sb'), 0);
    expect(twin.getAssignment('exp_sb').variant, 0);
  });

  // A rule matches for every experiment, switchbacks included, so it assigns
  // its variant even before the anchor, with ruleOverride set and recorded.
  test('assignmentRuleOverridesTheSchedule', () async {
    for (int u = 0; u < 10; ++u) {
      final harness = Harness(now: anchor - 1);
      final context = await harness.create(
          dataOf([sb(2, hour)..assignmentRules = assignVariant1]),
          units: {unitType: 'user-$u'});
      expect(context.getTreatment('exp_sb'), 1);
      expect(context.getVariableValue('sb.arm', -1), 1);
      // The rule also beats every period's schedule draw.
      for (int i = 0; i < 4; ++i) {
        harness.clock.now = anchor + i * hour;
        expect(context.getTreatment('exp_sb'), 1);
      }
      expect(await harness.publishExposures(context), [
        ruleExposure('exp_sb', 1, anchor - 1),
        for (int i = 0; i < 4; ++i) ruleExposure('exp_sb', 1, anchor + i * hour)
      ]);
    }
  });

  // An unservable schedule only replaces the draw: full-on and a matching
  // rule still apply and are recorded.
  test('unservableOnlyReplacesTheVariantDrawNotFullOnOrRules', () async {
    final fullOn = switchback(1, 'sb_full_on', 2, hour)
      ..switchbackStartAt = null
      ..fullOnVariant = 1;
    final rules = switchback(2, 'sb_rules', 2, hour)
      ..switchbackPeriodMs = 0
      ..assignmentRules = assignVariant1;
    final unalignedRules = switchback(3, 'sb_unaligned_rules', 2, hour)
      ..switchbackStartAt = anchor + 1
      ..assignmentRules = assignVariant1;
    final context = await h.create(dataOf([fullOn, rules, unalignedRules]),
        units: {unitType: '15'});

    expect(context.getTreatment('sb_full_on'), 1);
    expect(context.getTreatment('sb_rules'), 1);
    expect(context.getTreatment('sb_unaligned_rules'), 1);
    expect(await h.publishExposures(context), [
      exposure(1, 'sb_full_on', 1, anchor, fullOn: true),
      exposure(2, 'sb_rules', 1, anchor, assigned: false, ruleOverride: true),
      exposure(3, 'sb_unaligned_rules', 1, anchor,
          assigned: false, ruleOverride: true),
    ]);
  });

  // Rules are evaluated only for an eligible cluster.
  test('assignmentRulesDoNotApplyToAnIneligibleCluster', () async {
    final context = await h.create(dataOf([
      sb(2, hour)
        ..assignmentRules = assignVariant1
        ..switchbackClusterValues = ['other-store']
    ]));
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getPendingCount(), 0);
  });

  // A split rule randomizes over the serving unit, not over the payload's
  // unitType.
  test('splitRuleRandomizesOverTheServingUnit', () async {
    int ones = 0;
    for (int u = 0; u < 32; ++u) {
      final harness = Harness();
      final String storeUid = 'store-$u';
      final int expected = VariantAssigner(Hashing.hashUnit(storeUid))
          .assign([0.5, 0.5], seedHi, seedLo);
      final context = await harness.create(
          dataOf([
            sb(2, hour)
              ..unitType = 'user_id'
              ..assignmentRules =
                  '{"rules":[{"type":"split","environments":[],"percentages":"50/50"}]}'
          ]),
          units: {unitType: storeUid, 'user_id': 'fixed-user'});
      expect(context.getTreatment('exp_sb'), expected, reason: storeUid);
      expect(await harness.publishExposures(context),
          [ruleExposure('exp_sb', expected, anchor)],
          reason: storeUid);
      ones += expected;
    }
    expect(ones, inExclusiveRange(0, 32));
  });

  test('audienceStrictMismatchIsRecordedAsControl', () async {
    final context = await h.create(dataOf([
      sb(2, hour)
        ..audience = strictGoldAudience
        ..audienceStrict = true
    ]));
    h.clock.now = anchor + hour;
    expect(context.getTreatment('exp_sb'), 0);
    expect(await h.publishExposures(context),
        [strictMismatchExposure(anchor + hour)]);
  });

  // Exact wire form of a switchback strict audience mismatch. Runs in period
  // 1, whose draw is 1, so variant 0 is the strict mismatch's control.
  test('audienceStrictMismatchExposureSerializesExactly', () async {
    final context = await h.create(dataOf([
      sb(2, hour)
        ..audience = strictGoldAudience
        ..audienceStrict = true
    ]));
    expect(expected2Arms[1], 1);
    h.clock.now = anchor + hour + 5;
    context.getTreatment('exp_sb');
    h.clock.now = anchor + hour + 9;
    await context.publish();

    expect(
        serialize(h.publisher.events.single),
        '{"hashed":true,"units":[{"type":"store_id","uid":"$uidHash"}],'
        '"publishedAt":${anchor + hour + 9},'
        '"exposures":['
        '{"id":1,"name":"exp_sb","unit":"store_id","variant":0,"exposedAt":${anchor + hour + 5},'
        '"assigned":false,"eligible":true,"overridden":false,"fullOn":false,"custom":false,'
        '"audienceMismatch":true,"ruleOverride":false}'
        '],"goals":[],'
        '"attributes":[{"name":"$clusterPath","value":"$clusterKey","setAt":$anchor}]}');
  });

  // The audience check comes before the period check, so a strict mismatch
  // before the anchor is recorded.
  test('audienceStrictMismatchBeforeTheAnchorIsRecorded', () async {
    final harness = Harness(now: anchor - 1);
    final context = await harness.create(dataOf([
      sb(2, hour)
        ..audience = strictGoldAudience
        ..audienceStrict = true
    ]));
    expect(context.getTreatment('exp_sb'), 0);
    expect(await harness.publishExposures(context),
        [strictMismatchExposure(anchor - 1)]);
  });

  test('audienceStrictMismatchWithAnUnservableScheduleIsRecorded', () async {
    final harness = Harness(now: anchor + hour + 3);
    final context = await harness.create(dataOf([
      sb(2, hour)
        ..audience = strictGoldAudience
        ..audienceStrict = true
        ..switchbackStartAt = null
    ]));
    expect(context.getTreatment('exp_sb'), 0);
    expect(await harness.publishExposures(context),
        [strictMismatchExposure(anchor + hour + 3)]);
  });

  // A missing or unreadable cluster map takes the legacy path, which returns
  // an ineligible control before the audience is evaluated.
  test('audienceStrictMismatchWithAMissingOrUnreadableClusterMapRecordsNothing',
      () async {
    for (final clusters in [
      null,
      {unitType: "'geo"}
    ]) {
      final harness = Harness(now: anchor + hour + 3);
      final context = await harness.create(dataOf([
        sb(2, hour)
          ..audience = strictGoldAudience
          ..audienceStrict = true
          ..switchbackClusters = clusters
      ]));
      expect(context.getTreatment('exp_sb'), 0, reason: '$clusters');
      expect(context.getPendingCount(), 0, reason: '$clusters');
    }
  });

  // A strict-mismatched switchback is not assigned, so on a shared variable
  // key it gives way to the next experiment that declares the key.
  test('strictMismatchedSwitchbackGivesWayOnASharedVariableKey', () async {
    final sbExperiment = sb(2, hour)
      ..audience = strictGoldAudience
      ..audienceStrict = true;
    final unit = asUnit(switchback(2, 'exp_unit', 2, hour))
      ..variants = [
        ExperimentVariant(name: 'A', config: '{"sb.arm":10}'),
        ExperimentVariant(name: 'B', config: '{"sb.arm":11}'),
      ]
      ..fullOnVariant = 1;
    h.clock.now = anchor + hour + 3;
    final context = await h.create(dataOf([sbExperiment, unit]));
    expect(context.getVariableKeys(), {
      'sb.arm': ['exp_sb', 'exp_unit']
    });

    expect(context.peekVariableValue('sb.arm', -1), 11);
    expect(context.getPendingCount(), 0);
    expect(context.getVariableValue('sb.arm', -1), 11);
    expect(await h.publishExposures(context),
        [exposure(2, 'exp_unit', 1, anchor + hour + 3, fullOn: true)]);
  });

  test('strictMismatchedSwitchbackAloneOnAVariableKeyReturnsTheDefault',
      () async {
    h.clock.now = anchor + hour + 3;
    final context = await h.create(dataOf([
      sb(2, hour)
        ..audience = strictGoldAudience
        ..audienceStrict = true
    ]));
    expect(context.peekVariableValue('sb.arm', -1), -1);
    expect(context.getVariableValue('sb.arm', -1), -1);
    expect(context.getPendingCount(), 0);
  });

  // The same branch run on a unit experiment and on an eligible-cluster
  // switchback publishes the same exposure, apart from the unit and the
  // variant, and both match the table.
  group('exposureFlagsMatchAUnitExperimentForEveryBranch', () {
    Future<Exposure> exposeOnce(Experiment experiment, ParityBranch b) async {
      final harness = Harness(now: anchor + 2 * hour + 3);
      b.configureExperiment(experiment);
      final context = await harness.create(dataOf([experiment]));
      b.configureContext(context);
      context.getTreatment('exp_parity');
      final exposures = await harness.publishExposures(context);
      expect(exposures, hasLength(1), reason: b.name);
      return exposures.single;
    }

    for (final branch in ParityBranch.values) {
      test(branch.name, () async {
        expect(expected3Arms[2], 1);
        final unitExposure = await exposeOnce(
            asUnit(switchback(1, 'exp_parity', 3, hour)), branch);
        final sbExposure =
            await exposeOnce(switchback(1, 'exp_parity', 3, hour), branch);

        expect(flagsOf(unitExposure), exposureFlags[branch], reason: 'unit');
        expect(flagsOf(sbExposure), exposureFlags[branch],
            reason: 'switchback');
        expect(sbExposure.variant, expectedVariant[branch]);
        if (branch != ParityBranch.draw &&
            branch != ParityBranch.nonStrictMismatch) {
          expect(unitExposure.variant, expectedVariant[branch]);
        }
        expect(sbExposure.id, unitExposure.id);
        expect(sbExposure.name, unitExposure.name);
        expect(sbExposure.exposedAt, unitExposure.exposedAt);
      });
    }
  });

  // A traffic miss on an eligible cluster is recorded: eligible=false,
  // variant 0, under the serving unit. An ineligible cluster records nothing.
  test('trafficMissOnAnEligibleClusterPublishesAnIneligibleExposure', () async {
    final miss = switchback(1, 'exp_miss', 2, hour)..trafficSplit = [1.0, 0.0];
    final ineligibleCluster = switchback(2, 'exp_cluster_ineligible', 2, hour)
      ..trafficSplit = [1.0, 0.0]
      ..switchbackClusterValues = ['other-store'];
    final context = await h.create(dataOf([miss, ineligibleCluster]));
    h.clock.now = anchor + 2 * hour + 3;
    expect(context.getTreatment('exp_miss'), 0);
    expect(context.getTreatment('exp_cluster_ineligible'), 0);
    expect(await h.publishExposures(context), [
      exposure(1, 'exp_miss', 0, anchor + 2 * hour + 3, eligible: false),
    ]);
  });

  test('customFieldValuesAndUnitLookupsWork', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    expect(context.getUnit(unitType), uid);
    expect(context.getCustomFieldKeys(), isEmpty);
    expect(context.getCustomFieldValue('exp_sb', 'missing'), isNull);
  });

  // Each experiment keeps entries for at most its two most recent periods.
  test('perPeriodCacheIsBounded', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    for (int i = 0; i < 50; ++i) {
      h.clock.now = anchor + i * hour;
      context.getTreatment('exp_sb');
    }
    expect(context.assignmentCache_, hasLength(2));
    expect(context.getPendingCount(), 50);
  });

  test('unitTypeIsNotUsedForSwitchbackAssignment', () async {
    final context = await h.create(dataOf([sb(2, hour)..unitType = 'user_id']),
        units: {unitType: uid, 'user_id': 'u1'});
    for (int i = 0; i < 3; ++i) {
      h.clock.now = anchor + i * hour;
      expect(context.getTreatment('exp_sb'), expected2Arms[i]);
    }
    final exposures = await h.publishExposures(context);
    expect(exposures, hasLength(3));
    for (final e in exposures) {
      expect(e.unit, unitType);
    }
  });

  // The publish payload carries no switchback-specific exposure or publish
  // fields.
  test('publishPayloadHasNoNewFields', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor + 5;
    context.getTreatment('exp_sb');
    h.clock.now = anchor + hour + 7;
    context.getTreatment('exp_sb');
    h.clock.now = anchor + hour + 9;
    await context.publish();

    expect(
        serialize(h.publisher.events.single),
        '{"hashed":true,"units":[{"type":"store_id","uid":"$uidHash"}],'
        '"publishedAt":${anchor + hour + 9},'
        '"exposures":['
        '{"id":1,"name":"exp_sb","unit":"store_id","variant":${expected2Arms[0]},"exposedAt":${anchor + 5},'
        '"assigned":true,"eligible":true,"overridden":false,"fullOn":false,"custom":false,'
        '"audienceMismatch":false,"ruleOverride":false},'
        '{"id":1,"name":"exp_sb","unit":"store_id","variant":${expected2Arms[1]},"exposedAt":${anchor + hour + 7},'
        '"assigned":true,"eligible":true,"overridden":false,"fullOn":false,"custom":false,'
        '"audienceMismatch":false,"ruleOverride":false}'
        '],"goals":[],'
        // The cluster attribute is published timestamped, as before: the
        // Collector re-resolves the cluster at exposedAt from it.
        '"attributes":[{"name":"$clusterPath","value":"$clusterKey","setAt":$anchor}]}');
    expect(expected2Arms[0], isNot(expected2Arms[1]));
  });

  test('periodsPublishedAcrossFlushesStayOnePerPeriod', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor;
    context.getTreatment('exp_sb');
    await context.publish();
    h.clock.now = anchor + 1;
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 0);
    h.clock.now = anchor + hour;
    context.getTreatment('exp_sb');
    await context.publish();

    expect(h.publisher.events, hasLength(2));
    expect([
      for (final event in h.publisher.events)
        for (final e in event.exposures) e.variant
    ], [
      expected2Arms[0],
      expected2Arms[1]
    ]);
  });

  // The clock crosses into period 1 between resolution (first read) and any
  // later read; the exposure must still carry the instant that selected
  // period 0.
  test('treatmentExposureIsStampedWithTheResolutionInstant', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor + hour;
    h.clock.nextRead = anchor + hour - 1;

    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(await h.publishExposures(context),
        [exposure(1, 'exp_sb', expected2Arms[0], anchor + hour - 1)]);
  });

  test('variableExposureIsStampedWithTheResolutionInstant', () async {
    // Two arms, all traffic in arm 1; holdouts never fire through a
    // switchback.
    final context = await h.create(ContextData(experiments: [
      sb(2, hour)..holdoutIds = [11]
    ], holdouts: [
      holdout(const [0.0, 1.0])
    ]));
    h.clock.now = anchor + hour;
    h.clock.nextRead = anchor + hour - 1;

    expect(context.getVariableValue('sb.arm', -1), expected2Arms[0]);
    expect(await h.publishExposures(context),
        [exposure(1, 'exp_sb', expected2Arms[0], anchor + hour - 1)]);
  });

  // A peek caches the period's assignment without exposing; the later
  // getTreatment exposes at its own resolution instant, not the peek's.
  test('exposureAfterPeekUsesTheExposingCallsInstant', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor + 10;
    expect(context.peekTreatment('exp_sb'), expected2Arms[0]);
    h.clock.now = anchor + 20 * 60000;
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(await h.publishExposures(context),
        [exposure(1, 'exp_sb', expected2Arms[0], anchor + 20 * 60000)]);
  });

  // Unit experiments keep stamping at enqueue time, and a payload without
  // switchbacks reads the clock exactly as before: once per exposure.
  test('unitExposureTimingIsUnchanged', () async {
    final context =
        await h.create(dataOf([sb(2, hour)..randomizationType = 'unit']));
    h.clock.now = anchor + hour;
    final int reads = h.clock.reads;

    final variant = context.getTreatment('exp_sb');
    context.getTreatment('exp_sb');
    context.peekTreatment('exp_sb');
    context.getVariableValue('sb.arm', -1);
    expect(h.clock.reads - reads, 1);
    expect(await h.publishExposures(context),
        [exposure(1, 'exp_sb', variant, anchor + hour)]);
  });

  // A grid change that lowers the current index below the retained ones must
  // not evict the entry it just installed.
  test('gridRefreshToALowerIndexExposesOnce', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor + 99 * hour;
    context.getTreatment('exp_sb');
    h.clock.now = anchor + 100 * hour;
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 2);

    await h.refreshTo(
        context, [sb(2, hour)..switchbackStartAt = anchor + 100 * hour]);
    for (int i = 0; i < 3; ++i) {
      expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    }
    expect(context.getPendingCount(), 3);
  });

  test('periodLengthRefreshToALowerIndexExposesOnce', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor + 100 * hour;
    context.getTreatment('exp_sb');
    h.clock.now = anchor + 101 * hour;
    context.getTreatment('exp_sb');

    await h.refreshTo(context, [sb(2, 200 * hour)]);
    context.getTreatment('exp_sb');
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 3);
  });

  // Rewinding the clock across retained periods re-exposes each re-entered
  // evicted period at most once, never once per call.
  test('clockRewindReexposesAnEvictedPeriodAtMostOnce', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    for (int i = 0; i < 3; ++i) {
      h.clock.now = anchor + i * hour;
      context.getTreatment('exp_sb');
    }
    expect(context.getPendingCount(), 3);

    h.clock.now = anchor;
    for (int i = 0; i < 3; ++i) {
      expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    }
    expect(context.getPendingCount(), 4);

    // Retained {0, 2}: period 2 is still deduplicated, period 1 was evicted.
    h.clock.now = anchor + 2 * hour;
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 4);
    h.clock.now = anchor + hour;
    for (int i = 0; i < 3; ++i) {
      expect(context.getTreatment('exp_sb'), expected2Arms[1]);
    }
    expect(context.getPendingCount(), 5);

    final exposures = await h.publishExposures(context);
    expect(exposures[3], exposure(1, 'exp_sb', expected2Arms[0], anchor));
    expect(
        exposures[4], exposure(1, 'exp_sb', expected2Arms[1], anchor + hour));
  });

  // An overridden switchback slot is re-resolved on a grid change like a
  // normal one; the override still wins and the holdout never fires.
  test('overrideIsReresolvedWhenTheGridChanges', () async {
    final context = await h.create(ContextData(experiments: [
      sb(3, hour)..holdoutIds = [11]
    ], holdouts: [
      holdout(const [0.0, 1.0])
    ]));
    context.setOverride('exp_sb', 2);

    h.clock.now = anchor + 10;
    expect(context.getTreatment('exp_sb'), 2);
    expect(context.getVariableValue('sb.arm', -1), 2);
    expect(context.getPendingCount(), 1);

    // Same index 0 under the new period length; variant 2 now carries a
    // different value.
    final regridded = sb(3, 2 * hour)..holdoutIds = [11];
    regridded.variants[2] =
        ExperimentVariant(name: 'C', config: '{"sb.arm":22}');
    h.dataProvider.next = ContextData(experiments: [
      regridded
    ], holdouts: [
      holdout(const [0.0, 1.0])
    ]);
    await context.refresh();

    expect(context.getTreatment('exp_sb'), 2);
    expect(context.getVariableValue('sb.arm', -1), 22);
    expect(context.getPendingCount(), 2);

    final exposures = await h.publishExposures(context);
    expect(exposures, [
      for (int i = 0; i < 2; ++i)
        exposure(1, 'exp_sb', 2, anchor + 10, assigned: false, overridden: true)
    ]);
  });

  // Each identity transition is a new epoch: returning to an identical grid
  // re-resolves instead of resurrecting the slot from before the transition.
  test('switchbackToUnitToIdenticalSwitchbackReresolves', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor + 10;
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 1);

    await h.refreshTo(context, [sb(2, hour)..randomizationType = 'unit']);
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 2);

    await h.refreshTo(context, [sb(2, hour)]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 3);
  });

  test('removedAndRestoredSwitchbackReresolves', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor + 10;
    context.getTreatment('exp_sb');

    await h.refreshTo(context, []);
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getPendingCount(), 2);

    await h.refreshTo(context, [sb(2, hour)]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 3);
  });

  // The pre-anchor bare-name slot shares the lifecycle of the period slots.
  test('preAnchorSlotIsDroppedWhenTheGridChanges', () async {
    final gridA = sb(2, hour)..switchbackStartAt = anchor + 10 * hour;
    final context = await h.create(dataOf([gridA]));
    h.clock.now = anchor + 10;
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getPendingCount(), 0);

    await h.refreshTo(context, [sb(2, hour)]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 1);

    await h.refreshTo(context, [gridA]);
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getPendingCount(), 1);
    expect(context.getVariableValue('sb.arm', -1), 0);
    expect(context.getPendingCount(), 1);
  });

  // Epochs are reconciled lazily; an intermediate state that is never looked
  // up must still end the epoch.
  test('transitionsWithoutAnInterveningLookupStillReresolve', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor + 10;
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 1);

    await h.refreshTo(context, [sb(2, hour)..randomizationType = 'unit']);
    await h.refreshTo(context, [sb(2, hour)]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 2);

    await h.refreshTo(context, []);
    await h.refreshTo(context, [sb(2, hour)]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 3);

    await h.refreshTo(context, [sb(2, hour)..switchbackDesignType = 'other']);
    await h.refreshTo(context, [sb(2, hour)]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getTreatment('exp_sb'), expected2Arms[0]);
    expect(context.getPendingCount(), 4);

    // An unchanged identity keeps the epoch.
    await h.refreshTo(context, [sb(2, hour)]);
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 4);
  });

  // A legacy (missing or unreadable cluster map) switchback serves under its
  // declared unitType, so a unitType change on refresh is identity for it.
  test('legacySwitchbackUnitTypeChangeIsIdentity', () async {
    final context = await h.create(
        dataOf([sb(2, hour)..switchbackClusters = null]),
        units: {unitType: uid, 'user_id': 'u1'});
    h.clock.now = anchor + 10;
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getVariableValue('sb.arm', -1), 0);
    expect(switchbackResolutionForTest(context, 'exp_sb')!.unitType, unitType);

    await h.refreshTo(context, [
      sb(2, hour)
        ..switchbackClusters = null
        ..unitType = 'other'
    ]);
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getVariableValue('sb.arm', -1), -1);

    await h.refreshTo(context, [
      sb(2, hour)
        ..switchbackClusters = null
        ..unitType = 'user_id'
    ]);
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getVariableValue('sb.arm', -1), 0);
    final resolution = switchbackResolutionForTest(context, 'exp_sb')!;
    expect(resolution.unitType, 'user_id');
    expect(resolution.eligible, isFalse);
    expect(resolution.silent, isTrue);
    expect(context.getPendingCount(), 0);
  });

  // An ineligible or absent switchback slot never consulted its rules, so
  // neither a set attribute nor a rules refresh re-evaluates them.
  test('rulesAreNotReevaluatedForAnIneligibleOrAbsentSlot', () async {
    final matcher = CountingAudienceMatcher();
    final ineligible = switchback(1, 'exp_ineligible', 2, hour)
      ..assignmentRules = assignVariant1
      ..switchbackClusterValues = ['other-store'];
    final absent = switchback(2, 'exp_absent', 2, hour)
      ..assignmentRules = assignVariant1
      ..switchbackClusters = {'device_id': clusterPath};
    final context =
        await h.create(dataOf([ineligible, absent]), audienceMatcher: matcher);
    h.clock.now = anchor + 10;
    expect(context.getTreatment('exp_ineligible'), 0);
    expect(context.getTreatment('exp_absent'), 0);
    expect(matcher.ruleEvaluations, 0);

    context.setAttribute('x', 1);
    const changed =
        '{"rules":[{"type":"assign","environments":[],"variant":1,"name":"changed"}]}';
    await h.refreshTo(context, [
      switchback(1, 'exp_ineligible', 2, hour)
        ..assignmentRules = changed
        ..switchbackClusterValues = ['other-store'],
      switchback(2, 'exp_absent', 2, hour)
        ..assignmentRules = changed
        ..switchbackClusters = {'device_id': clusterPath},
    ]);

    expect(context.getTreatment('exp_ineligible'), 0);
    expect(context.getTreatment('exp_absent'), 0);
    expect(matcher.ruleEvaluations, 0);
    expect(context.getPendingCount(), 0);
  });

  // A rule-won switchback re-resolved in the same period keeps its variant
  // and is exposed once.
  test('inPeriodRuleRefreshKeepsTheVariantAndExposesOnce', () async {
    final context =
        await h.create(dataOf([sb(2, hour)..assignmentRules = assignVariant1]));
    h.clock.now = anchor + 5;
    expect(context.getTreatment('exp_sb'), 1);

    context.setAttribute('tier', 'x');
    await h.refreshTo(context, [
      sb(2, hour)
        ..assignmentRules =
            '{"rules":[{"type":"assign","environments":[],"variant":1,'
                '"conditions":{"and":[{"eq":[{"var":"tier"},{"value":"x"}]}]}}]}'
    ]);
    h.clock.now = anchor + 6;
    expect(context.getTreatment('exp_sb'), 1);
    expect(await h.publishExposures(context),
        [ruleExposure('exp_sb', 1, anchor + 5)]);
  });

  // Before the anchor nothing is recorded, a traffic miss included, because
  // the pre-period check precedes traffic. From the anchor the same miss is
  // recorded.
  test('preAnchorTrafficMissIsSilent', () async {
    final harness = Harness(now: anchor - 1);
    final context = await harness.create(dataOf([
      sb(2, hour)..trafficSplit = [1.0, 0.0]
    ]));
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getPendingCount(), 0);

    harness.clock.now = anchor;
    expect(context.getTreatment('exp_sb'), 0);
    expect(await harness.publishExposures(context),
        [exposure(1, 'exp_sb', 0, anchor, eligible: false)]);
  });

  // An override on a switchback with no serving unit is exposed under the
  // declared unitType when the cluster map is missing or unreadable.
  test('overrideWithoutAServingUnitOnALegacySwitchbackUsesTheDeclaredUnitType',
      () async {
    final missing = switchback(1, 'exp_missing_map', 2, hour)
      ..unitType = 'user_id'
      ..switchbackClusters = null;
    final unreadable = switchback(2, 'exp_unreadable_map', 2, hour)
      ..unitType = 'user_id'
      ..switchbackClusters = {unitType: "'unterminated"};
    final context = await h.create(dataOf([missing, unreadable]));
    context.setOverride('exp_missing_map', 1);
    context.setOverride('exp_unreadable_map', 1);
    h.clock.now = anchor + 5;
    expect(context.getTreatment('exp_missing_map'), 1);
    expect(context.getTreatment('exp_unreadable_map'), 1);

    expect(await h.publishExposures(context), [
      exposure(1, 'exp_missing_map', 1, anchor + 5,
          unit: 'user_id', assigned: false, overridden: true),
      exposure(2, 'exp_unreadable_map', 1, anchor + 5,
          unit: 'user_id', assigned: false, overridden: true),
    ]);
  });

  test('ruleWonAndTrafficMissExposuresSerializeExactly', () async {
    final rule = switchback(1, 'exp_rule', 2, hour)
      ..assignmentRules = assignVariant1;
    final miss = switchback(2, 'exp_miss', 2, hour)..trafficSplit = [1.0, 0.0];
    final context = await h.create(dataOf([rule, miss]));
    h.clock.now = anchor + 5;
    context.getTreatment('exp_rule');
    context.getTreatment('exp_miss');
    h.clock.now = anchor + 9;
    await context.publish();

    expect(
        serialize(h.publisher.events.single),
        '{"hashed":true,"units":[{"type":"store_id","uid":"$uidHash"}],'
        '"publishedAt":${anchor + 9},'
        '"exposures":['
        '{"id":1,"name":"exp_rule","unit":"store_id","variant":1,"exposedAt":${anchor + 5},'
        '"assigned":false,"eligible":true,"overridden":false,"fullOn":false,"custom":false,'
        '"audienceMismatch":false,"ruleOverride":true},'
        '{"id":2,"name":"exp_miss","unit":"store_id","variant":0,"exposedAt":${anchor + 5},'
        '"assigned":true,"eligible":false,"overridden":false,"fullOn":false,"custom":false,'
        '"audienceMismatch":false,"ruleOverride":false}'
        '],"goals":[],'
        '"attributes":[{"name":"$clusterPath","value":"$clusterKey","setAt":$anchor}]}');
  });

  // Every switchback a variable-key lookup resolves uses one clock reading.
  test('aVariableKeyReadsTheClockOncePerLookup', () async {
    final context = await h.create(dataOf([
      switchback(1, 'exp_a', 2, hour)
        ..audienceStrict = true
        ..audience = strictGoldAudience,
      switchback(2, 'exp_b', 2, hour),
    ]));
    h.clock.now = anchor + hour;
    final int reads = h.clock.reads;
    expect(context.peekVariableValue('sb.arm', -1), expected2Arms[1]);
    expect(h.clock.reads - reads, 1);
  });

  // A cached switchback read costs one clock reading and no cluster read.
  test('cachedReadsDoNotReResolveTheCluster', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor + 5;
    ContextCounters.reset();
    context.getTreatment('exp_sb');
    expect(ContextCounters.switchbackServingResolutions, 1);
    for (int i = 0; i < 10; ++i) {
      context.getTreatment('exp_sb');
      context.peekTreatment('exp_sb');
      context.getVariableValue('sb.arm', -1);
    }
    expect(ContextCounters.switchbackServingResolutions, 1);
  });

  // Burn and carryover windows are analysis-only: they neither move the grid
  // nor silence exposures inside them.
  test('burnAndCarryoverWindowsDoNotChangeServing', () async {
    final context = await h.create(dataOf([
      sb(2, hour)
        ..switchbackBurnInDurationMs = 20 * 60000
        ..switchbackBurnOutDurationMs = 20 * 60000
        ..switchbackCarryoverDurationMs = 30 * 60000
    ]));
    for (int i = 0; i < 4; ++i) {
      for (final offset in [0, 10 * 60000, 50 * 60000, hour - 1]) {
        h.clock.now = anchor + i * hour + offset;
        expect(context.getTreatment('exp_sb'), expected2Arms[i],
            reason: '$i $offset');
      }
    }
    expect(await h.publishExposures(context), [
      for (int i = 0; i < 4; ++i)
        exposure(1, 'exp_sb', expected2Arms[i], anchor + i * hour)
    ]);
  });

  // Custom assignment comes after traffic: a traffic miss is control even
  // with a custom assignment set.
  test('aTrafficMissWinsOverACustomAssignment', () async {
    final context = await h.create(dataOf([
      sb(3, hour)..trafficSplit = [1.0, 0.0]
    ]));
    context.setCustomAssignment('exp_sb', 2);
    h.clock.now = anchor + 2 * hour;
    expect(context.getTreatment('exp_sb'), 0);
    expect(await h.publishExposures(context),
        [exposure(1, 'exp_sb', 0, anchor + 2 * hour, eligible: false)]);
  });

  // System attributes are evaluated by audiences but are not attributes set
  // on the context, so a cluster path never reads them.
  test('systemAttributesAreNotClusterSources', () async {
    final context = await h.create(
        dataOf([
          sb(2, hour)
            ..switchbackClusters = {unitType: 'environment'}
            ..audience =
                '{"filter":[{"eq":[{"var":"environment"},{"value":"prod"}]}]}'
            ..audienceStrict = true,
          switchback(2, 'exp_app', 2, hour)
            ..switchbackClusters = {unitType: 'application'},
        ]),
        application: 'website',
        environment: 'prod');
    h.clock.now = anchor + hour;
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getTreatment('exp_app'), 0);
    expect(context.getPendingCount(), 0);
    // The same name set on the context is read.
    context.setAttribute('environment', 'prod');
    h.clock.now = anchor + 2 * hour;
    expect(context.getTreatment('exp_sb'), draw('prod', 2, 2));
  });

  // An unexposed overridden slot is re-resolved on a grid change too: the
  // refreshed variant config is served.
  test('anUnexposedOverrideFollowsAGridChange', () async {
    final context = await h.create(dataOf([sb(3, hour)]));
    context.setOverride('exp_sb', 2);
    h.clock.now = anchor + 10;
    expect(context.peekTreatment('exp_sb'), 2);
    expect(context.peekVariableValue('sb.arm', -1), 2);

    final regridded = sb(3, 2 * hour);
    regridded.variants[2] =
        ExperimentVariant(name: 'C', config: '{"sb.arm":22}');
    await h.refreshTo(context, [regridded]);
    expect(context.peekVariableValue('sb.arm', -1), 22);
  });

  // A switchback slot is current for the custom assignment it was resolved
  // with, even when it serves another variant (control, full-on, a rule), so
  // re-reading it does not re-expose it.
  test('aCustomAssignmentOnAControlSlotDoesNotReexpose', () async {
    final context = await h.create(dataOf([
      sb(3, hour)..fullOnVariant = 1,
      switchback(2, 'exp_miss', 3, hour)..trafficSplit = [1.0, 0.0],
    ]));
    context.setCustomAssignment('exp_sb', 2);
    context.setCustomAssignment('exp_miss', 2);
    h.clock.now = anchor + 2 * hour;
    for (int i = 0; i < 3; ++i) {
      expect(context.getTreatment('exp_sb'), 1);
      expect(context.getTreatment('exp_miss'), 0);
    }
    expect(context.getPendingCount(), 2);
    // Clearing the custom assignment is a change too.
    context.cassignments_.remove('exp_sb');
    expect(context.getTreatment('exp_sb'), 1);
    expect(context.getPendingCount(), 3);
  });

  // The arm count is the split length, not the number of variants.
  test('theArmCountIsTheSplitLength', () async {
    final experiment = sb(2, hour);
    experiment.variants = [
      ...experiment.variants,
      ExperimentVariant(name: 'C', config: '{"sb.arm":2}')
    ];
    final context = await h.create(dataOf([experiment]));
    expect(h.peekSchedule(context, 'exp_sb', hour, 12), expected2Arms);
  });

  // An overridden unit experiment that becomes a switchback sharing its slot
  // (no anchor yet) is re-resolved: the override is exposed again under the
  // switchback's linked unit.
  test('anOverriddenUnitExperimentTurnedSwitchbackIsReresolved', () async {
    final context = await h.create(
        dataOf([asUnit(sb(2, hour))..unitType = 'user_id']),
        units: {unitType: uid, 'user_id': 'u1'});
    context.setOverride('exp_sb', 1);
    expect(context.getTreatment('exp_sb'), 1);

    await h.refreshTo(context, [sb(2, hour)..switchbackStartAt = null]);
    expect(context.getTreatment('exp_sb'), 1);
    final exposures = await h.publishExposures(context);
    expect(exposures.map((e) => e.unit), ['user_id', unitType]);
  });

  // A unit experiment whose rule outcome changes after setAttribute: the read
  // path evaluates the rules and rejects the slot, and the rebuild evaluates
  // them once more. Two evaluations, not three; current again, none.
  test('staleRuleTransitionEvaluatesTheRulesTwice', () async {
    final matcher = CountingAudienceMatcher();
    final context = await h.create(
        dataOf([
          sb(2, hour)
            ..randomizationType = 'unit'
            ..assignmentRules =
                '{"rules":[{"type":"assign","environments":[],"conditions":{"and":[{"eq":[{"var":"country"},{"value":"US"}]}]},"variant":1}]}'
        ]),
        audienceMatcher: matcher);
    context.peekTreatment('exp_sb');
    expect(matcher.ruleEvaluations, 1);

    context.setAttribute('country', 'US');
    matcher.ruleEvaluations = 0;
    expect(context.peekTreatment('exp_sb'), 1);
    expect(matcher.ruleEvaluations, 2);
    expect(context.peekTreatment('exp_sb'), 1);
    expect(matcher.ruleEvaluations, 2);
  });

  // A pre-anchor switchback slot under the bare name is never served once a
  // refresh turns the experiment into a unit experiment with the same grid
  // fields.
  test('aPreAnchorSlotIsNotReusedByTheUnitExperimentThatReplacesIt', () async {
    h = Harness(now: anchor - 1);
    final context = await h.create(dataOf([sb(2, hour)..fullOnVariant = 1]));
    expect(context.getTreatment('exp_sb'), 1);
    expect(context.getPendingCount(), 1);

    await h.refreshTo(context, [
      sb(2, hour)
        ..fullOnVariant = 1
        ..randomizationType = 'unit'
    ]);
    expect(context.getTreatment('exp_sb'), 1);
    expect(context.getPendingCount(), 2);
  });

  // A matching assignment rule wins over a custom assignment on a
  // switchback too.
  test('anAssignmentRuleWinsOverACustomAssignment', () async {
    final context =
        await h.create(dataOf([sb(3, hour)..assignmentRules = assignVariant1]));
    context.setCustomAssignment('exp_sb', 2);
    h.clock.now = anchor + 2 * hour;
    expect(context.getTreatment('exp_sb'), 1);
    expect(await h.publishExposures(context),
        [ruleExposure('exp_sb', 1, anchor + 2 * hour)]);
  });

  // The period length is switchback identity: 1h -> 2h -> 1h is three
  // epochs. The 1h period-1 slot from the first epoch is dropped, so the third
  // epoch exposes it again rather than resurrecting it.
  test('aPeriodLengthChangeAndBackIsANewEpochEachTime', () async {
    final context = await h.create(dataOf([sb(2, hour)]));
    h.clock.now = anchor + hour + 10;
    context.getTreatment('exp_sb');
    await h.refreshTo(context, [sb(2, 2 * hour)]);
    context.getTreatment('exp_sb');
    await h.refreshTo(context, [sb(2, hour)]);
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 3);
  });

  // An unexposed override of a switchback with no linked unit is re-resolved
  // by setUnit, so it is exposed under the unit that now serves.
  test('setUnitReresolvesAnUnexposedOverrideOfANotApplyingSwitchback',
      () async {
    final context = await h.create(
        dataOf([
          sb(2, hour)
            ..switchbackClusters = {'user_id': 'nothing', unitType: clusterPath}
        ]),
        units: {});
    context.setOverride('exp_sb', 1);
    expect(context.peekTreatment('exp_sb'), 1);
    context.setUnit(unitType, uid);
    expect(context.getTreatment('exp_sb'), 1);
    expect(await h.publishExposures(context),
        [exposure(1, 'exp_sb', 1, anchor, assigned: false, overridden: true)]);
  });

  // A split rule revalidated after setAttribute hashes the serving unit
  // again, so the slot stays current and is not exposed twice.
  test('aSplitRuleIsRevalidatedOverTheServingUnit', () async {
    for (int u = 0; u < 8; ++u) {
      final harness = Harness();
      final context = await harness.create(
          dataOf([
            sb(2, hour)
              ..unitType = 'user_id'
              ..assignmentRules =
                  '{"rules":[{"type":"split","environments":[],"percentages":"50/50"}]}'
          ]),
          units: {unitType: 'store-$u', 'user_id': 'fixed-user'});
      final int first = context.getTreatment('exp_sb');
      context.setAttribute('unrelated', 1);
      expect(context.getTreatment('exp_sb'), first);
      expect(context.getPendingCount(), 1, reason: 'store-$u');
    }
  });

  // An override is exposed under the unit that serves, which need not be the
  // first linked type.
  test('anOverrideIsExposedUnderTheServingUnit', () async {
    final context = await h.create(
        dataOf([
          sb(2, hour)
            ..switchbackClusters = {'user_id': 'nothing', unitType: clusterPath}
        ]),
        units: {'user_id': 'u1', unitType: uid});
    context.setOverride('exp_sb', 1);
    expect(context.getTreatment('exp_sb'), 1);
    expect(await h.publishExposures(context),
        [exposure(1, 'exp_sb', 1, anchor, assigned: false, overridden: true)]);
  });

  // The allow-list is switchback identity: A -> B -> A without a read in
  // between still ends the first epoch.
  test('anAllowListChangeAndBackIsANewEpoch', () async {
    final context = await h.create(dataOf([
      sb(2, hour)..switchbackClusterValues = [clusterKey]
    ]));
    h.clock.now = anchor + 10;
    context.getTreatment('exp_sb');
    await h.refreshTo(context, [
      sb(2, hour)..switchbackClusterValues = [clusterKey, 'other']
    ]);
    await h.refreshTo(context, [
      sb(2, hour)..switchbackClusterValues = [clusterKey]
    ]);
    context.getTreatment('exp_sb');
    expect(context.getPendingCount(), 2);
  });
}
