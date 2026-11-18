import 'dart:async';

import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/context.dart';
import 'package:absmartly_dart/src/context_config.dart';
import 'package:absmartly_dart/src/context_data_provider.dart';
import 'package:absmartly_dart/src/context_event_logger.dart';
import 'package:absmartly_dart/src/context_publisher.dart';
import 'package:absmartly_dart/src/default_audience_deserializer.dart';
import 'package:absmartly_dart/src/default_variable_parser.dart';
import 'package:absmartly_dart/src/internal/context_counters.dart';
import 'package:absmartly_dart/src/internal/hashing/hashing.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:absmartly_dart/src/json/attribute.dart';
import 'package:absmartly_dart/src/json/context_data.dart';
import 'package:absmartly_dart/src/json/context_holdout.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:absmartly_dart/src/json/experiment_application.dart';
import 'package:absmartly_dart/src/json/experiment_variant.dart';
import 'package:absmartly_dart/src/json/exposure.dart';
import 'package:absmartly_dart/src/json/publish_event.dart';
import 'package:absmartly_dart/src/json/unit.dart';
import 'package:absmartly_dart/src/jsonexpr/json_expr.dart';
import 'package:test/test.dart';

const String unitType = 'session_id';
const String uid = 'e791e240fcd3df7d238cfc285f475e8152fcc0ec';
const String uidNotHeldOut = 'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';

// split[0.5,0.5], seedHi=100, seedLo=200 -> variant 1 for uid, variant 0 for
// uidNotHeldOut.
const int normalSeedHi = 100;
const int normalSeedLo = 200;
const int normalVariant = 1;

// split[0.1,0.9], seedHi=13, seedLo=111 -> variant 0 (held out) for uid,
// variant 1 for uidNotHeldOut.
const int holdoutASeedHi = 13;
const int holdoutASeedLo = 111;

// split[0.1,0.9], seedHi=1, seedLo=222 -> variant 1 (not held out) for both.
const int holdoutBSeedHi = 1;
const int holdoutBSeedLo = 222;

// A 3-arm holdout is selected by split length, never by holdoutType. For uid:
// seedLo=1 -> arm 0, seedLo=3 -> arm 1, seedLo=0 -> arm 2.
const List<double> threeArmSplit = [0.3, 0.3, 0.4];
const int threeArm0SeedLo = 1;
const int threeArm1SeedLo = 3;
const int threeArm2SeedLo = 0;

const int now = 1620000000000;

class RecordingPublisher implements ContextPublisher {
  final List<PublishEvent> events = [];
  void Function()? onPublish;

  @override
  Completer<void> publish(Context context, PublishEvent event) {
    events.add(event);
    onPublish?.call();
    return Completer<void>()..complete();
  }
}

// Holds the first publish open until [release]; later ones complete at once.
class HeldPublisher extends RecordingPublisher {
  final Completer<void> held = Completer<void>();
  void Function()? onFirstPublish;

  void release() => held.complete();

  @override
  Completer<void> publish(Context context, PublishEvent event) {
    events.add(event);
    if (events.length == 1) {
      onFirstPublish?.call();
      return held;
    }
    return Completer<void>()..complete();
  }
}

class QueuedDataProvider implements ContextDataProvider {
  ContextData? next;

  @override
  Completer<ContextData> getContextData() =>
      Completer<ContextData>()..complete(next!);
}

class RecordingLogger implements ContextEventLogger {
  final List<Exposure> exposures = [];
  bool Function(Exposure exposure)? throwOn;
  void Function(Exposure exposure)? onExposure;

  @override
  void handleEvent(Context context, EventType type, dynamic data) {
    if (type == EventType.exposure && data is Exposure) {
      exposures.add(data);
      onExposure?.call(data);
      if (throwOn?.call(data) ?? false) {
        throw Exception('boom');
      }
    }
  }
}

Experiment newExperiment(int id, String name,
    {String unit = unitType, int fullOnVariant = 0, List<int>? holdoutIds}) {
  return Experiment(
    id: id,
    name: name,
    unitType: unit,
    iteration: 1,
    seedHi: normalSeedHi,
    seedLo: normalSeedLo,
    split: [0.5, 0.5],
    trafficSeedHi: 1,
    trafficSeedLo: 2,
    trafficSplit: [0.0, 1.0],
    fullOnVariant: fullOnVariant,
    applications: [ExperimentApplication(name: 'website')],
    variants: [
      ExperimentVariant(name: 'A', config: null),
      ExperimentVariant(name: 'B', config: null),
    ],
    audienceStrict: false,
    audience: null,
    holdoutIds: holdoutIds,
  );
}

ContextHoldout newHoldout(int id, String name, int seedHi, int seedLo,
    {String unit = unitType,
    List<double> split = const [0.1, 0.9],
    int iteration = 1,
    String holdoutType = 'full'}) {
  return ContextHoldout(
    id: id,
    name: name,
    unitType: unit,
    iteration: iteration,
    seedHi: seedHi,
    seedLo: seedLo,
    split: split,
    holdoutType: holdoutType,
  );
}

ContextHoldout newThreeArmHoldout(int id, String name, int seedLo,
        {int iteration = 1}) =>
    newHoldout(id, name, 0, seedLo,
        split: threeArmSplit, iteration: iteration, holdoutType: 'all_full_on');

Experiment withVariables(Experiment experiment, String key) {
  experiment.variants = [
    ExperimentVariant(name: 'A', config: '{"$key":"control"}'),
    ExperimentVariant(name: 'B', config: '{"$key":"treatment"}'),
  ];
  return experiment;
}

ContextData contextDataOf(
        List<ContextHoldout>? holdouts, List<Experiment> experiments) =>
    ContextData(experiments: experiments, holdouts: holdouts);

Exposure exposure(int id, String name, int variant,
        {String unit = unitType,
        bool assigned = true,
        bool eligible = true,
        bool overridden = false,
        bool fullOn = false,
        bool custom = false,
        bool audienceMismatch = false,
        bool ruleOverride = false}) =>
    Exposure(
        id: id,
        name: name,
        unit: unit,
        variant: variant,
        exposedAt: now,
        assigned: assigned,
        eligible: eligible,
        overridden: overridden,
        fullOn: fullOn,
        custom: custom,
        audienceMismatch: audienceMismatch,
        ruleOverride: ruleOverride);

Exposure holdoutExposure(int id, String name, int variant,
        {String unit = unitType}) =>
    exposure(id, name, variant, unit: unit);

class CountingJsonExpr extends JsonExpr {
  int evaluations = 0;

  @override
  bool evaluateBooleanExpr(dynamic expr, Map<String?, dynamic> vars) {
    evaluations++;
    return super.evaluateBooleanExpr(expr, vars);
  }
}

const String usRule =
    '{"rules":[{"name":"US Internal Users","type":"assign","conditions":{"and":[{"eq":[{"var":"country"},{"value":"US"}]}]},"environments":[],"variant":1}]}';
const String ageAudience = '{"filter":[{"gte":[{"var":"age"},{"value":20}]}]}';

void main() {
  late RecordingPublisher publisher;
  late QueuedDataProvider dataProvider;
  late RecordingLogger logger;
  late CountingJsonExpr jsonExpr;
  final clock = Clock.fixed(now);

  setUp(() {
    publisher = RecordingPublisher();
    dataProvider = QueuedDataProvider();
    logger = RecordingLogger();
    jsonExpr = CountingJsonExpr();
  });

  Context create(ContextConfig config, ContextData data) {
    return Context.create(
        clock,
        config..setPublishDelay(-1),
        Completer<ContextData>()..complete(data),
        dataProvider,
        publisher,
        DefaultVariableParser(),
        AudienceMatcher(DefaultAudienceDeserializer(), jsonExpr: jsonExpr),
        logger);
  }

  Future<Context> ready(ContextData data, {String unitId = uid}) async {
    final context =
        create(ContextConfig.create()..setUnit(unitType, unitId), data);
    await context.waitUntilReady();
    return context;
  }

  Future<Context> readyWith(ContextConfig config, ContextData data) async {
    final context = create(config, data);
    await context.waitUntilReady();
    return context;
  }

  Future<Context> readyWithoutUnits(ContextData data) =>
      readyWith(ContextConfig.create(), data);

  Future<void> refreshWith(Context context, ContextData next) async {
    dataProvider.next = next;
    await context.refresh();
  }

  Future<PublishEvent> publish(Context context) async {
    await context.publish();
    expect(publisher.events, hasLength(1));
    return publisher.events.single;
  }

  Future<void> expectPublished(Context context, List<Exposure> exposures,
      {String unit = unitType,
      String unitId = uid,
      List<Attribute> attributes = const []}) async {
    final event = await publish(context);
    expect(event.exposures, exposures);
    expect(event.units, [
      Unit(type: unit, uid: String.fromCharCodes(Hashing.hashUnit(unitId)))
    ]);
    expect(event.attributes, attributes);
  }

  test('heldOutUnitGetsControlValuesAndEmitsNoExposureForCoveredExperiment',
      () async {
    final context = await ready(contextDataOf([
      newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
    ], [
      newExperiment(1, 'exp_holdout_in', holdoutIds: [11])
    ]));

    expect(context.peekTreatment('exp_holdout_in'), 0);
    expect(context.getAssignment('exp_holdout_in').exposed, isFalse);
    context.getTreatment('exp_holdout_in');
    expect(context.getAssignment('exp_holdout_in').exposed, isTrue);

    await expectPublished(context, [holdoutExposure(11, 'holdout_a', 0)]);
  });

  test('notHeldOutUnitEmitsHoldoutExposureVariantOneAndNormalExposure',
      () async {
    final context = await ready(
        contextDataOf([
          newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
        ], [
          newExperiment(1, 'exp_holdout_out', holdoutIds: [11])
        ]),
        unitId: uidNotHeldOut);

    expect(context.getTreatment('exp_holdout_out'), 0);

    await expectPublished(
        context,
        [
          exposure(1, 'exp_holdout_out', 0),
          holdoutExposure(11, 'holdout_a', 1),
        ],
        unitId: uidNotHeldOut);
  });

  test('experimentWithoutHoldoutIdsEmitsNormallyEvenForHeldOutUnit', () async {
    final context = await ready(contextDataOf([
      newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
    ], [
      newExperiment(1, 'exp_holdout_in', holdoutIds: [11]),
      newExperiment(2, 'exp_not_covered'),
    ]));

    expect(context.getTreatment('exp_holdout_in'), 0);
    expect(context.getTreatment('exp_not_covered'), normalVariant);

    await expectPublished(context, [
      holdoutExposure(11, 'holdout_a', 0),
      exposure(2, 'exp_not_covered', normalVariant),
    ]);
  });

  test('unionOfApplicableHoldoutsSuppressesExperimentAndBothEmitOwnExposure',
      () async {
    final context = await ready(contextDataOf([
      newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo),
      newHoldout(12, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo),
    ], [
      newExperiment(1, 'exp_multi_holdout', holdoutIds: [11, 12])
    ]));

    expect(context.getTreatment('exp_multi_holdout'), 0);

    await expectPublished(context, [
      holdoutExposure(11, 'holdout_a', 0),
      holdoutExposure(12, 'holdout_b', 1),
    ]);
  });

  test('unionRuleAppliesWhenTheHigherIdHoldoutIsTheOnlyOneHoldingUnitOut',
      () async {
    final context = await ready(contextDataOf([
      newHoldout(11, 'holdout_low_id', holdoutBSeedHi, holdoutBSeedLo),
      newHoldout(12, 'holdout_high_id', holdoutASeedHi, holdoutASeedLo),
    ], [
      newExperiment(1, 'exp_union_high_id_decides', holdoutIds: [11, 12])
    ]));

    expect(context.getTreatment('exp_union_high_id_decides'), 0);

    await expectPublished(context, [
      holdoutExposure(11, 'holdout_low_id', 1),
      holdoutExposure(12, 'holdout_high_id', 0),
    ]);
  });

  test('unitNotHeldOutByEitherHoldoutIsNotSuppressed', () async {
    final context = await ready(
        contextDataOf([
          newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo),
          newHoldout(12, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo),
        ], [
          newExperiment(1, 'exp_multi_holdout_miss', holdoutIds: [11, 12])
        ]),
        unitId: uidNotHeldOut);

    expect(context.getTreatment('exp_multi_holdout_miss'), 0);

    await expectPublished(
        context,
        [
          exposure(1, 'exp_multi_holdout_miss', 0),
          holdoutExposure(11, 'holdout_a', 1),
          holdoutExposure(12, 'holdout_b', 1),
        ],
        unitId: uidNotHeldOut);
  });

  test('holdoutSuppressesFullOnExperimentRegardlessOfFullOnVariant', () async {
    final context = await ready(contextDataOf([
      newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
    ], [
      newExperiment(1, 'exp_fullon_holdout', fullOnVariant: 2, holdoutIds: [11])
    ]));

    expect(context.getTreatment('exp_fullon_holdout'), 0);
  });

  group('three-arm holdouts', () {
    test('threeArmVariantZeroHoldsOutBothFullOnAndNonFullOnExperiments',
        () async {
      final context = await ready(contextDataOf([
        newThreeArmHoldout(21, 'holdout_three_arm', threeArm0SeedLo)
      ], [
        newExperiment(1, 'exp_three_arm_0_non_fullon', holdoutIds: [21]),
        newExperiment(2, 'exp_three_arm_0_fullon',
            fullOnVariant: 2, holdoutIds: [21]),
      ]));

      expect(context.getTreatment('exp_three_arm_0_non_fullon'), 0);
      expect(context.getTreatment('exp_three_arm_0_fullon'), 0);

      await expectPublished(
          context, [holdoutExposure(21, 'holdout_three_arm', 0)]);
    });

    test(
        'threeArmVariantOneForcesNonFullOnExperimentToControlButAssignsFullOnExperimentNormally',
        () async {
      final context = await ready(contextDataOf([
        newThreeArmHoldout(21, 'holdout_three_arm', threeArm1SeedLo)
      ], [
        newExperiment(1, 'exp_three_arm_1_non_fullon', holdoutIds: [21]),
        newExperiment(2, 'exp_three_arm_1_fullon',
            fullOnVariant: 2, holdoutIds: [21]),
      ]));

      expect(context.getTreatment('exp_three_arm_1_non_fullon'), 0);
      expect(context.getTreatment('exp_three_arm_1_fullon'), 2);

      await expectPublished(context, [
        holdoutExposure(21, 'holdout_three_arm', 1),
        exposure(2, 'exp_three_arm_1_fullon', 2, fullOn: true),
      ]);
    });

    test('threeArmVariantTwoEvaluatesBothExperimentKindsNormally', () async {
      final context = await ready(contextDataOf([
        newThreeArmHoldout(21, 'holdout_three_arm', threeArm2SeedLo)
      ], [
        newExperiment(1, 'exp_three_arm_2_non_fullon', holdoutIds: [21]),
        newExperiment(2, 'exp_three_arm_2_fullon',
            fullOnVariant: 2, holdoutIds: [21]),
      ]));

      expect(context.getTreatment('exp_three_arm_2_non_fullon'), normalVariant);
      expect(context.getTreatment('exp_three_arm_2_fullon'), 2);

      await expectPublished(context, [
        exposure(1, 'exp_three_arm_2_non_fullon', normalVariant),
        holdoutExposure(21, 'holdout_three_arm', 2),
        exposure(2, 'exp_three_arm_2_fullon', 2, fullOn: true),
      ]);
    });

    test('twoArmHoldoutWinsUnionEvenWhenThreeArmWouldNotHoldOut', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_two_arm', holdoutASeedHi, holdoutASeedLo),
        newThreeArmHoldout(22, 'holdout_three_arm', threeArm2SeedLo),
      ], [
        newExperiment(1, 'exp_union_two_arm_wins', holdoutIds: [11, 22])
      ]));

      expect(context.getTreatment('exp_union_two_arm_wins'), 0);

      await expectPublished(context, [
        holdoutExposure(11, 'holdout_two_arm', 0),
        holdoutExposure(22, 'holdout_three_arm', 2),
      ]);
    });

    test('threeArmHoldoutWinsUnionEvenWhenTwoArmWouldNotHoldOut', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_two_arm', holdoutBSeedHi, holdoutBSeedLo),
        newThreeArmHoldout(22, 'holdout_three_arm', threeArm1SeedLo),
      ], [
        newExperiment(1, 'exp_union_three_arm_wins', holdoutIds: [11, 22])
      ]));

      expect(context.getTreatment('exp_union_three_arm_wins'), 0);

      await expectPublished(context, [
        holdoutExposure(11, 'holdout_two_arm', 1),
        holdoutExposure(22, 'holdout_three_arm', 1),
      ]);
    });

    test(
        'threeArmArmOneDefersToNormalPathSoAudienceMismatchStillWinsForFullOnExperiment',
        () async {
      Experiment strict(String name) =>
          newExperiment(1, name, fullOnVariant: 2, holdoutIds: [21])
            ..audienceStrict = true
            ..audience = ageAudience;

      final arm1 = await ready(contextDataOf(
          [newThreeArmHoldout(21, 'holdout_three_arm', threeArm1SeedLo)],
          [strict('exp_three_arm_1_audience_fullon')]));
      arm1.setAttribute('age', 5);
      final arm2 = await ready(contextDataOf(
          [newThreeArmHoldout(21, 'holdout_three_arm', threeArm2SeedLo)],
          [strict('exp_three_arm_2_audience_fullon')]));
      arm2.setAttribute('age', 5);

      expect(arm1.getTreatment('exp_three_arm_1_audience_fullon'), 0);
      expect(arm2.getTreatment('exp_three_arm_2_audience_fullon'), 0);

      final attributes = [Attribute(name: 'age', value: 5, setAt: now)];
      await expectPublished(
          arm1,
          [
            exposure(1, 'exp_three_arm_1_audience_fullon', 0,
                assigned: false, audienceMismatch: true),
            holdoutExposure(21, 'holdout_three_arm', 1),
          ],
          attributes: attributes);
      publisher.events.clear();
      await expectPublished(
          arm2,
          [
            exposure(1, 'exp_three_arm_2_audience_fullon', 0,
                assigned: false, audienceMismatch: true),
            holdoutExposure(21, 'holdout_three_arm', 2),
          ],
          attributes: attributes);
    });
  });

  test('unconfiguredUnitTypeGetsControlValuesAndEmitsNoExposureAtAll',
      () async {
    final context = await ready(contextDataOf([
      newHoldout(11, 'holdout_user', holdoutASeedHi, holdoutASeedLo,
          unit: 'user_id')
    ], [
      newExperiment(1, 'exp_user_holdout', unit: 'user_id', holdoutIds: [11])
    ]));

    expect(context.peekTreatment('exp_user_holdout'), 0);
    expect(context.getTreatment('exp_user_holdout'), 0);

    // Java's assertion (pending count after publish) cannot fail. As in JS,
    // the unresolvable holdout neither suppresses nor fires; the experiment's
    // own unassigned exposure is published as without holdouts.
    await expectPublished(context,
        [exposure(1, 'exp_user_holdout', 0, unit: 'user_id', assigned: false)]);
  });

  test('assignsNormallyWhenHoldoutsKeyIsAbsent', () async {
    final context = await ready(
        ContextData(experiments: [newExperiment(1, 'exp_no_holdouts_key')]));

    expect(context.peekTreatment('exp_no_holdouts_key'), normalVariant);
  });

  test('holdoutIdAbsentFromHoldoutsArrayIsIgnoredAndExperimentAssignsNormally',
      () async {
    final context = await ready(ContextData(experiments: [
      newExperiment(1, 'exp_dangling_holdout_id', holdoutIds: [999])
    ]));

    expect(context.peekTreatment('exp_dangling_holdout_id'), normalVariant);
  });

  test('customAssignmentCannotOverrideHeldOutVariant', () async {
    final context = await readyWith(
        ContextConfig.create()
          ..setUnit(unitType, uid)
          ..setCustomAssignment('exp_holdout_custom', 3),
        contextDataOf([
          newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
        ], [
          newExperiment(1, 'exp_holdout_custom', holdoutIds: [11])
        ]));

    expect(context.peekTreatment('exp_holdout_custom'), 0);
  });

  test('reusesCachedHeldOutAssignmentWithCustomAssignment', () async {
    final context = await readyWith(
        ContextConfig.create()
          ..setUnit(unitType, uid)
          ..setCustomAssignment('exp_holdout_custom_cache', 3),
        contextDataOf([
          newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
        ], [
          newExperiment(1, 'exp_holdout_custom_cache', holdoutIds: [11])
        ]));

    expect(context.getTreatment('exp_holdout_custom_cache'), 0);
    final first = context.getAssignment('exp_holdout_custom_cache');
    expect(context.getTreatment('exp_holdout_custom_cache'), 0);
    expect(context.getAssignment('exp_holdout_custom_cache'), same(first));
    expect(context.getPendingCount(), 1);
  });

  test('overrideTakesPrecedenceOverHoldout', () async {
    final context = await readyWith(
        ContextConfig.create()
          ..setUnit(unitType, uid)
          ..setOverride('exp_holdout_override', 3),
        contextDataOf([
          newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
        ], [
          newExperiment(1, 'exp_holdout_override', holdoutIds: [11])
        ]));

    expect(context.peekTreatment('exp_holdout_override'), 3);
  });

  test(
      'getTreatmentOnOverriddenExperimentTriggersApplicableHoldoutExposureBothArms',
      () async {
    for (final (unitId, name, arm) in [
      (uid, 'exp_holdout_override_held_out', 0),
      (uidNotHeldOut, 'exp_holdout_override_not_held_out', 1),
    ]) {
      publisher.events.clear();
      final context = await readyWith(
          ContextConfig.create()
            ..setUnit(unitType, unitId)
            ..setOverride(name, 3),
          contextDataOf([
            newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
          ], [
            newExperiment(1, name, holdoutIds: [11])
          ]));

      expect(context.getTreatment(name), 3);

      await expectPublished(
          context,
          [
            exposure(1, name, 3, assigned: false, overridden: true),
            holdoutExposure(11, 'holdout_a', arm),
          ],
          unitId: unitId);
    }
  });

  test('holdoutTakesPrecedenceOverAudienceMismatch', () async {
    final context = await ready(contextDataOf([
      newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
    ], [
      newExperiment(1, 'exp_holdout_audience', holdoutIds: [11])
        ..audienceStrict = true
        ..audience = ageAudience
    ]));
    context.setAttribute('age', 5);

    expect(context.peekTreatment('exp_holdout_audience'), 0);
  });

  test('holdoutExposureEmittedOncePerContextNotPerSuppressedExperiment',
      () async {
    final context = await ready(contextDataOf([
      newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
    ], [
      newExperiment(1, 'exp_shared_a', holdoutIds: [11]),
      newExperiment(2, 'exp_shared_b', holdoutIds: [11]),
    ]));

    expect(context.getTreatment('exp_shared_a'), 0);
    expect(context.getTreatment('exp_shared_b'), 0);

    await expectPublished(context, [holdoutExposure(11, 'holdout_a', 0)]);
  });

  test('holdoutExposureFiresOnceEvenWhenTriggeringExperimentIsNotSuppressed',
      () async {
    final context = await ready(
        contextDataOf([
          newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
        ], [
          newExperiment(1, 'exp_shared_a', holdoutIds: [11]),
          newExperiment(2, 'exp_shared_b', holdoutIds: [11]),
        ]),
        unitId: uidNotHeldOut);

    context.getTreatment('exp_shared_a');
    context.getTreatment('exp_shared_b');

    await expectPublished(
        context,
        [
          exposure(1, 'exp_shared_a', 0),
          holdoutExposure(11, 'holdout_a', 1),
          exposure(2, 'exp_shared_b', 0),
        ],
        unitId: uidNotHeldOut);
  });

  test('reusesCachedSuppressedAssignmentAcrossRepeatedCalls', () async {
    final context = await ready(contextDataOf([
      newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
    ], [
      newExperiment(1, 'exp_holdout_cache', holdoutIds: [11])
    ]));

    expect(context.getTreatment('exp_holdout_cache'), 0);
    expect(context.getTreatment('exp_holdout_cache'), 0);
    expect(context.getPendingCount(), 1);
  });

  group('refresh', () {
    test(
        'refreshWithSeedChangeSameIterationKeepsUnitInOriginalArmAndDoesNotReExpose',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_holdout_seed_thrash', holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_holdout_seed_thrash'), 0);
      expect(context.getPendingCount(), 1);

      await refreshWith(
          context,
          contextDataOf([
            newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo)
          ], [
            newExperiment(1, 'exp_holdout_seed_thrash', holdoutIds: [11])
          ]));

      expect(context.getTreatment('exp_holdout_seed_thrash'), 0);
      expect(context.getPendingCount(), 1);
    });

    test('refreshWithCosmeticHoldoutEditDoesNotReExposeHeldOutUnit', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_holdout_cosmetic', holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_holdout_cosmetic'), 0);
      expect(context.getPendingCount(), 1);

      await refreshWith(
          context,
          contextDataOf([
            newHoldout(11, 'holdout_a_renamed', holdoutASeedHi, holdoutASeedLo,
                holdoutType: 'all_full_on')
          ], [
            newExperiment(1, 'exp_holdout_cosmetic', holdoutIds: [11])
          ]));

      expect(context.getTreatment('exp_holdout_cosmetic'), 0);
      expect(context.getPendingCount(), 1);
    });

    test(
        'refreshWithCosmeticHoldoutEditDoesNotDuplicateCoveredExperimentExposure',
        () async {
      final context = await ready(
          contextDataOf([
            newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
          ], [
            newExperiment(1, 'exp_holdout_cosmetic_covered', holdoutIds: [11])
          ]),
          unitId: uidNotHeldOut);

      expect(context.getTreatment('exp_holdout_cosmetic_covered'), 0);
      expect(context.getPendingCount(), 2);

      await refreshWith(
          context,
          contextDataOf([
            newHoldout(11, 'holdout_a_renamed', holdoutASeedHi, holdoutASeedLo)
          ], [
            newExperiment(1, 'exp_holdout_cosmetic_covered', holdoutIds: [11])
          ]));

      expect(context.getTreatment('exp_holdout_cosmetic_covered'), 0);
      expect(context.getPendingCount(), 2);
    });

    test('refreshWithIterationBumpReassignsToExactlyOneNewArm', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_holdout_iteration', holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_holdout_iteration'), normalVariant);
      expect(context.getPendingCount(), 2);

      await refreshWith(
          context,
          contextDataOf([
            newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo,
                iteration: 2)
          ], [
            newExperiment(1, 'exp_holdout_iteration', holdoutIds: [11])
          ]));

      expect(context.getTreatment('exp_holdout_iteration'), 0);
      expect(context.getPendingCount(), 3);
      expect(context.getTreatment('exp_holdout_iteration'), 0);
      expect(context.getPendingCount(), 3);
    });

    test(
        'refreshedSeedDoesNotDesyncSuppressionFromPinnedHoldoutArmForNewlyEvaluatedExperiment',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_holdout_desync_a', holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_holdout_desync_a'), 0);
      expect(context.getPendingCount(), 1);

      await refreshWith(
          context,
          contextDataOf([
            newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo)
          ], [
            newExperiment(1, 'exp_holdout_desync_a', holdoutIds: [11]),
            newExperiment(2, 'exp_holdout_desync_b', holdoutIds: [11]),
          ]));

      expect(context.getTreatment('exp_holdout_desync_b'), 0);
      expect(context.getTreatment('exp_holdout_desync_a'), 0);

      await expectPublished(context, [holdoutExposure(11, 'holdout_a', 0)]);
    });

    test(
        'refreshFromTwoArmToThreeArmSameIterationDoesNotReinterpretDeferringArmAsFullOnOnly',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(31, 'holdout_arity', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_arity_2to3_a', holdoutIds: [31])
      ]));

      expect(context.getTreatment('exp_arity_2to3_a'), normalVariant);

      await refreshWith(
          context,
          contextDataOf([
            newThreeArmHoldout(31, 'holdout_arity', threeArm1SeedLo)
          ], [
            newExperiment(1, 'exp_arity_2to3_a', holdoutIds: [31]),
            newExperiment(2, 'exp_arity_2to3_b', holdoutIds: [31]),
          ]));

      expect(context.getTreatment('exp_arity_2to3_b'), normalVariant);

      await expectPublished(context, [
        exposure(1, 'exp_arity_2to3_a', normalVariant),
        holdoutExposure(31, 'holdout_arity', 1),
        exposure(2, 'exp_arity_2to3_b', normalVariant),
      ]);
    });

    test(
        'refreshFromThreeArmToTwoArmSameIterationKeepsFullOnOnlyArmSuppressingNonFullOnExperiment',
        () async {
      final context = await ready(contextDataOf([
        newThreeArmHoldout(41, 'holdout_arity_rev', threeArm1SeedLo)
      ], [
        newExperiment(1, 'exp_arity_3to2_a', holdoutIds: [41])
      ]));

      expect(context.getTreatment('exp_arity_3to2_a'), 0);
      expect(context.getPendingCount(), 1);

      await refreshWith(
          context,
          contextDataOf([
            newHoldout(41, 'holdout_arity_rev', holdoutBSeedHi, holdoutBSeedLo)
          ], [
            newExperiment(1, 'exp_arity_3to2_a', holdoutIds: [41]),
            newExperiment(2, 'exp_arity_3to2_b', holdoutIds: [41]),
          ]));

      expect(context.getTreatment('exp_arity_3to2_b'), 0);

      await expectPublished(
          context, [holdoutExposure(41, 'holdout_arity_rev', 1)]);
    });

    test(
        'experimentsEvaluatedBeforeAndAfterSameIterationArityChangeAgreeOnSuppression',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(
            71, 'holdout_arity_consistency', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_arity_consistency_pre', holdoutIds: [71])
      ]));

      expect(context.getTreatment('exp_arity_consistency_pre'), normalVariant);

      await refreshWith(
          context,
          contextDataOf([
            newThreeArmHoldout(71, 'holdout_arity_consistency', threeArm1SeedLo)
          ], [
            newExperiment(1, 'exp_arity_consistency_pre', holdoutIds: [71]),
            newExperiment(2, 'exp_arity_consistency_post', holdoutIds: [71]),
          ]));

      expect(context.getTreatment('exp_arity_consistency_post'), normalVariant);
      expect(context.getTreatment('exp_arity_consistency_pre'), normalVariant);
    });

    test(
        'triggerFiresHoldoutExposureFromDecisionEpochDespiteRefreshRacingBetweenDecisionAndTrigger',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_h', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_epoch_race', holdoutIds: [11])
      ]));

      logger.onExposure = (exposure) {
        if (exposure.id == 1) {
          context.setData(contextDataOf([
            newHoldout(11, 'holdout_h', holdoutASeedHi, holdoutASeedLo,
                iteration: 2)
          ], [
            newExperiment(1, 'exp_epoch_race', holdoutIds: [11])
          ]));
        }
      };

      expect(context.getTreatment('exp_epoch_race'), normalVariant);

      await expectPublished(context, [
        exposure(1, 'exp_epoch_race', normalVariant),
        holdoutExposure(11, 'holdout_h', 1),
      ]);
    });

    test('staleHoldoutReferenceNeverOverwritesNewerPinnedCacheEntry', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_h', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_f', holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_f'), 0);
      expect(context.getPendingCount(), 1);

      await refreshWith(
          context,
          contextDataOf([
            newHoldout(11, 'holdout_h', holdoutBSeedHi, holdoutBSeedLo,
                iteration: 2)
          ], [
            newExperiment(1, 'exp_f', holdoutIds: [11]),
            newExperiment(2, 'exp_g', holdoutIds: [11]),
          ]));

      expect(context.getTreatment('exp_g'), normalVariant);
      expect(context.getPendingCount(), 3);

      expect(context.getTreatment('exp_f'), normalVariant);
      expect(context.getPendingCount(), 4);

      await expectPublished(context, [
        holdoutExposure(11, 'holdout_h', 0),
        exposure(2, 'exp_g', normalVariant),
        holdoutExposure(11, 'holdout_h', 1),
        exposure(1, 'exp_f', normalVariant),
      ]);
    });

    test(
        'holdoutBecomingApplicableAfterRefreshStillFiresForOverriddenExperiment',
        () async {
      final context = await readyWith(
          ContextConfig.create()
            ..setUnit(unitType, uid)
            ..setOverride('exp_override_late_holdout', 3),
          ContextData(
              experiments: [newExperiment(1, 'exp_override_late_holdout')]));

      expect(context.getTreatment('exp_override_late_holdout'), 3);
      expect(context.getPendingCount(), 1);

      await refreshWith(
          context,
          contextDataOf([
            newHoldout(11, 'holdout_late', holdoutASeedHi, holdoutASeedLo)
          ], [
            newExperiment(1, 'exp_override_late_holdout', holdoutIds: [11])
          ]));

      expect(context.getTreatment('exp_override_late_holdout'), 3);
      expect(context.getPendingCount(), 3);

      final own = exposure(1, 'exp_override_late_holdout', 3,
          assigned: false, overridden: true);
      await expectPublished(
          context, [own, own, holdoutExposure(11, 'holdout_late', 0)]);
    });
  });

  group('late unit', () {
    test(
        'setUnitInvalidatesNullHoldoutSnapshotSoTheHoldoutExposureIsNotLostForever',
        () async {
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(11, 'holdout_user_id', holdoutBSeedHi, holdoutBSeedLo,
            unit: 'user_id')
      ], [
        newExperiment(1, 'exp_null_snapshot_fullon',
            unit: 'user_id', fullOnVariant: 2, holdoutIds: [11])
      ]));

      expect(context.peekTreatment('exp_null_snapshot_fullon'), 2);

      context.setUnit('user_id', uid);

      expect(context.getTreatment('exp_null_snapshot_fullon'), 2);
      expect(context.getPendingCount(), 2);

      await expectPublished(
          context,
          [
            exposure(1, 'exp_null_snapshot_fullon', 2,
                unit: 'user_id', fullOn: true),
            holdoutExposure(11, 'holdout_user_id', 1, unit: 'user_id'),
          ],
          unit: 'user_id');
    });

    test('setUnitDoesNotEvictAlreadyExposedAssignmentSoNoDuplicateExposure',
        () async {
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(11, 'holdout_user_id', holdoutBSeedHi, holdoutBSeedLo,
            unit: 'user_id')
      ], [
        newExperiment(1, 'exp_exposed_before_unit',
            unit: 'user_id', fullOnVariant: 2, holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_exposed_before_unit'), 2);
      expect(context.getPendingCount(), 1);
      final exposed = context.getAssignment('exp_exposed_before_unit');

      context.setUnit('user_id', uid);

      expect(context.getTreatment('exp_exposed_before_unit'), 2);
      expect(context.getPendingCount(), 1);
      expect(context.getAssignment('exp_exposed_before_unit'), same(exposed));
    });

    test('setUnitForUnrelatedUnitTypeDoesNotEvictExposedAssignment', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_unrelated_unit', holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_unrelated_unit'), normalVariant);
      expect(context.getPendingCount(), 2);

      context.setUnit('other_unit_type', 'some-other-uid');

      expect(context.getTreatment('exp_unrelated_unit'), normalVariant);
      expect(context.getPendingCount(), 2);
    });

    test('setUnitEvictsOnlyTheAffectedEntryAndLeavesTheOtherUntouched',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_late', holdoutBSeedHi, holdoutBSeedLo,
            unit: 'user_id'),
        newHoldout(12, 'holdout_present', holdoutBSeedHi, holdoutBSeedLo),
      ], [
        newExperiment(1, 'exp_late_unit',
            unit: 'user_id', fullOnVariant: 2, holdoutIds: [11]),
        newExperiment(2, 'exp_present_unit', holdoutIds: [12]),
      ]));

      expect(context.peekTreatment('exp_late_unit'), 2);
      expect(context.getTreatment('exp_present_unit'), normalVariant);
      expect(context.getPendingCount(), 2);

      context.setUnit('user_id', uid);

      expect(context.getTreatment('exp_late_unit'), 2);
      expect(context.getPendingCount(), 4);
      expect(context.getTreatment('exp_present_unit'), normalVariant);
      expect(context.getPendingCount(), 4);
    });

    test(
        'setUnitEvictsUsingTheCoveredExperimentsUnitTypeNotTheHoldoutsDeclaredUnitType',
        () async {
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(11, 'holdout_declares_b', holdoutBSeedHi, holdoutBSeedLo,
            unit: 'B')
      ], [
        newExperiment(1, 'exp_mismatched_unit_type',
            unit: 'A', fullOnVariant: 2, holdoutIds: [11])
      ]));

      expect(context.peekTreatment('exp_mismatched_unit_type'), 2);

      context.setUnit('A', uid);

      expect(context.getTreatment('exp_mismatched_unit_type'), 2);
      expect(context.getPendingCount(), 2);
    });

    test(
        'setUnitRecomputesSuppressionCoherentlyWhenLateResolvedHoldoutSuppresses',
        () async {
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(
            11, 'holdout_user_id_suppress', holdoutASeedHi, holdoutASeedLo,
            unit: 'user_id')
      ], [
        newExperiment(1, 'exp_null_snapshot_suppresses',
            unit: 'user_id', fullOnVariant: 2, holdoutIds: [11])
      ]));

      expect(context.peekTreatment('exp_null_snapshot_suppresses'), 2);

      context.setUnit('user_id', uid);

      expect(context.getTreatment('exp_null_snapshot_suppresses'), 0);
      expect(context.getPendingCount(), 1);

      await expectPublished(context,
          [holdoutExposure(11, 'holdout_user_id_suppress', 0, unit: 'user_id')],
          unit: 'user_id');
    });

    // Java's detached-assignment and exposure-settlement cases guard a
    // concurrent thread holding an Assignment that setUnit or refresh
    // replaced. Dart has no such thread; the Dart equivalent is an
    // Assignment read before the eviction, and the guarantee is that the
    // context resolves and exposes the replacement, never the retained one.
    test('detachedTreatmentAssignmentCannotPublishBesideSuppressingReplacement',
        () async {
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(
            11, 'holdout_detached_suppressed', holdoutASeedHi, holdoutASeedLo,
            unit: 'user_id')
      ], [
        newExperiment(1, 'exp_detached_suppressed',
            unit: 'user_id', fullOnVariant: 2, holdoutIds: [11])
      ]));

      final retained = context.getAssignment('exp_detached_suppressed');
      context.setUnit('user_id', uid);
      expect(context.getTreatment('exp_detached_suppressed'), 0);
      expect(context.getAssignment('exp_detached_suppressed'),
          isNot(same(retained)));
      expect(context.getTreatment('exp_detached_suppressed'), 0);
      expect(context.getPendingCount(), 1);

      await expectPublished(
          context,
          [
            holdoutExposure(11, 'holdout_detached_suppressed', 0,
                unit: 'user_id')
          ],
          unit: 'user_id');
    });

    test('detachedTreatmentAssignmentRetriesCurrentEntryWithoutLosingExposure',
        () async {
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(11, 'holdout_detached_retry', holdoutBSeedHi, holdoutBSeedLo,
            unit: 'user_id')
      ], [
        newExperiment(1, 'exp_detached_retry',
            unit: 'user_id', fullOnVariant: 2, holdoutIds: [11])
      ]));

      context.getAssignment('exp_detached_retry');
      context.setUnit('user_id', uid);

      expect(context.getTreatment('exp_detached_retry'), 2);
      expect(context.getPendingCount(), 2);
      expect(context.getTreatment('exp_detached_retry'), 2);
      expect(context.getPendingCount(), 2);

      await expectPublished(
          context,
          [
            exposure(1, 'exp_detached_retry', 2, unit: 'user_id', fullOn: true),
            holdoutExposure(11, 'holdout_detached_retry', 1, unit: 'user_id'),
          ],
          unit: 'user_id');
    });

    test('detachedTreatmentReturnsTheReplacementVariant', () async {
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(
            11, 'holdout_detached_variant', holdoutASeedHi, holdoutASeedLo,
            unit: 'user_id')
      ], [
        newExperiment(1, 'exp_detached_variant',
            unit: 'user_id', fullOnVariant: 2, holdoutIds: [11])
      ]));

      expect(context.getAssignment('exp_detached_variant').variant, 2);
      context.setUnit('user_id', uid);

      expect(context.getTreatment('exp_detached_variant'), 0);
      expect(context.getPendingCount(), 1);
    });

    test('treatmentExposureSettlesAfterTwoConsecutiveRetirements', () async {
      final context = await ready(ContextData(experiments: [
        newExperiment(1, 'exp_first', fullOnVariant: 2),
        newExperiment(2, 'exp_second', fullOnVariant: 1),
        newExperiment(3, 'exp_settled', fullOnVariant: 1),
      ]));
      final retained = context.getAssignment('exp_settled');

      for (final iteration in [2, 3]) {
        await refreshWith(
            context,
            ContextData(experiments: [
              newExperiment(1, 'exp_first', fullOnVariant: 2),
              newExperiment(2, 'exp_second', fullOnVariant: 1),
              newExperiment(3, 'exp_settled', fullOnVariant: 1)
                ..iteration = iteration,
            ]));
      }

      expect(context.getTreatment('exp_settled'), 1);
      expect(context.getAssignment('exp_settled'), isNot(same(retained)));
      expect(context.getPendingCount(), 1);
    });

    test('exposureSettlementStopsAfterTheBoundedNumberOfRetirements', () async {
      final context = await ready(ContextData(experiments: [
        newExperiment(1, 'exp_bounded_retry', fullOnVariant: 1)
      ]));

      for (int i = 0; i < 3; i++) {
        expect(context.getTreatment('exp_bounded_retry'), 1);
      }
      expect(context.getPendingCount(), 1);
    });

    test('detachedVariableAssignmentReresolvesTheKeyToANewWinningExperiment',
        () async {
      final holdout = newHoldout(
          11, 'holdout_detached_variable', holdoutBSeedHi, holdoutBSeedLo,
          unit: 'user_id');
      Experiment original() => newExperiment(2, 'exp_detached_variable_old',
          unit: 'user_id', fullOnVariant: 1, holdoutIds: [11])
        ..variants[1].config = '{"detached_var":"old"}';
      final context =
          await readyWithoutUnits(contextDataOf([holdout], [original()]));

      context.getAssignment('exp_detached_variable_old');
      context.setUnit('user_id', uid);

      await refreshWith(
          context,
          contextDataOf([
            holdout
          ], [
            newExperiment(1, 'exp_detached_variable_winner',
                unit: 'user_id', fullOnVariant: 1, holdoutIds: [11])
              ..variants[1].config = '{"detached_var":"new winner"}',
            original(),
          ]));

      expect(context.getVariableValue('detached_var', 'default'), 'new winner');
      expect(context.getPendingCount(), 2);
      expect(context.getVariableValue('detached_var', 'default'), 'new winner');
      expect(context.getPendingCount(), 2);

      await expectPublished(
          context,
          [
            exposure(1, 'exp_detached_variable_winner', 1,
                unit: 'user_id', fullOn: true),
            holdoutExposure(11, 'holdout_detached_variable', 1,
                unit: 'user_id'),
          ],
          unit: 'user_id');
    });

    test(
        'triggerApplicableHoldoutExposuresNeverLiveResolvesAPinnedNullEntryForAnAlreadyExposedAssignment',
        () async {
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(
            11, 'holdout_a_mutant_pinned_null', holdoutASeedHi, holdoutASeedLo,
            unit: 'user_id')
      ], [
        newExperiment(1, 'exp_a_mutant_pinned_null',
            unit: 'user_id', fullOnVariant: 1, holdoutIds: [11])
          ..variants[1].config = '{"my_var":"value_from_variant"}'
      ]));

      expect(context.getTreatment('exp_a_mutant_pinned_null'), 1);
      expect(context.getPendingCount(), 1);

      context.setUnit('user_id', uid);

      expect(
          context.getVariableValue('my_var', 'default'), 'value_from_variant');
      expect(context.getPendingCount(), 1);
    });

    test(
        'setUnitEvictsAssignmentWithMultipleHoldoutsDeclaringDifferentUnitTypes',
        () async {
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(11, 'holdout_11', holdoutBSeedHi, holdoutBSeedLo,
            unit: 'type_x'),
        newHoldout(12, 'holdout_12', holdoutBSeedHi, holdoutBSeedLo,
            unit: 'type_y'),
        newHoldout(13, 'holdout_13', holdoutBSeedHi, holdoutBSeedLo,
            unit: 'user_id'),
      ], [
        newExperiment(1, 'exp_multi_holdout_unit_types',
            unit: 'user_id', fullOnVariant: 2, holdoutIds: [11, 12, 13])
      ]));

      expect(context.peekTreatment('exp_multi_holdout_unit_types'), 2);

      context.setUnit('user_id', uid);

      expect(context.getTreatment('exp_multi_holdout_unit_types'), 2);
      expect(context.getPendingCount(), 4);
    });

    test(
        'oneHoldoutCoveringTwoUnitTypesKeepsIndependentExposureStatePerUnitType',
        () async {
      final context = await readyWith(
          ContextConfig.create()
            ..setUnit('user_id', uid)
            ..setUnit('session_id', uid),
          contextDataOf([
            newHoldout(11, 'holdout_shared', holdoutBSeedHi, holdoutBSeedLo,
                unit: 'user_id')
          ], [
            newExperiment(1, 'exp_unit_a1', unit: 'user_id', holdoutIds: [11]),
            newExperiment(2, 'exp_unit_b',
                unit: 'session_id', holdoutIds: [11]),
            newExperiment(3, 'exp_unit_a2', unit: 'user_id', holdoutIds: [11]),
          ]));

      expect(context.getTreatment('exp_unit_a1'), normalVariant);
      expect(context.getTreatment('exp_unit_b'), normalVariant);
      expect(context.getTreatment('exp_unit_a2'), normalVariant);
      expect(context.getPendingCount(), 5);

      final event = await publish(context);
      expect(event.exposures, [
        exposure(1, 'exp_unit_a1', normalVariant, unit: 'user_id'),
        holdoutExposure(11, 'holdout_shared', 1, unit: 'user_id'),
        exposure(2, 'exp_unit_b', normalVariant, unit: 'session_id'),
        holdoutExposure(11, 'holdout_shared', 1, unit: 'session_id'),
        exposure(3, 'exp_unit_a2', normalVariant, unit: 'user_id'),
      ]);
    });

    test(
        'setUnitWithNoCachedAssignmentDoesNotThrowAndSubsequentAssignmentIsNormal',
        () async {
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_no_prior_assignment', holdoutIds: [11])
      ]));

      context.setUnit(unitType, uid);

      expect(context.getTreatment('exp_no_prior_assignment'), normalVariant);
    });

    test('setUnitCalledTwiceWithSameUidIsANoOpAndDoesNotThrow', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_set_unit_twice', holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_set_unit_twice'), normalVariant);
      expect(context.getPendingCount(), 2);

      context.setUnit(unitType, uid);

      expect(context.getTreatment('exp_set_unit_twice'), normalVariant);
      expect(context.getPendingCount(), 2);
    });

    test(
        'setUnitRedundantCallDoesNotEvictFullyResolvedUnexposedHoldoutSnapshot',
        () async {
      final holdout =
          newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo);
      final context = await ready(contextDataOf([
        holdout
      ], [
        newExperiment(1, 'exp_redundant_set_unit', holdoutIds: [11])
      ]));

      expect(context.peekTreatment('exp_redundant_set_unit'), normalVariant);
      expect(context.getPendingCount(), 0);

      await refreshWith(
          context,
          contextDataOf([
            holdout
          ], [
            newExperiment(1, 'exp_redundant_set_unit', holdoutIds: [11])
              ..split = [1.0, 0.0]
          ]));

      context.setUnit(unitType, uid);

      expect(context.getTreatment('exp_redundant_set_unit'), normalVariant);
      expect(context.getPendingCount(), 2);

      await expectPublished(context, [
        exposure(1, 'exp_redundant_set_unit', normalVariant),
        holdoutExposure(11, 'holdout_a', 1),
      ]);
    });

    test(
        'peekVariableValueThenSetUnitThenGetVariableValueRecomputesUnderLateSuppressingHoldout',
        () async {
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(11, 'holdout_var_late', holdoutASeedHi, holdoutASeedLo,
            unit: 'user_id')
      ], [
        newExperiment(1, 'exp_var_late_unit_suppress',
            unit: 'user_id', fullOnVariant: 1, holdoutIds: [11])
          ..variants[1].config = '{"my_var":"value_from_variant"}'
      ]));

      expect(
          context.peekVariableValue('my_var', 'default'), 'value_from_variant');
      expect(context.getPendingCount(), 0);

      context.setUnit('user_id', uid);

      expect(context.getVariableValue('my_var', 'default'), 'default');
      expect(context.getPendingCount(), 1);

      await expectPublished(context,
          [holdoutExposure(11, 'holdout_var_late', 0, unit: 'user_id')],
          unit: 'user_id');
    });

    // Java resolves an override's holdouts live at exposure time; JS (the
    // reference) pins them on the override path too and evicts a null entry
    // on setUnit. Both publish the same exposures here.
    test(
        'setUnitDoesNotEvictOverrideAssignmentAndHoldoutResolvesLiveAtExposureTime',
        () async {
      final context = await readyWith(
          ContextConfig.create()..setOverride('exp_override_late_unit', 3),
          contextDataOf([
            newHoldout(
                11, 'holdout_override_late', holdoutBSeedHi, holdoutBSeedLo,
                unit: 'user_id')
          ], [
            newExperiment(1, 'exp_override_late_unit',
                unit: 'user_id', holdoutIds: [11])
          ]));

      expect(context.peekTreatment('exp_override_late_unit'), 3);

      context.setUnit('user_id', uid);

      expect(context.getTreatment('exp_override_late_unit'), 3);
      expect(context.getPendingCount(), 2);

      await expectPublished(
          context,
          [
            exposure(1, 'exp_override_late_unit', 3,
                unit: 'user_id', assigned: false, overridden: true),
            holdoutExposure(11, 'holdout_override_late', 1, unit: 'user_id'),
          ],
          unit: 'user_id');
    });

    test(
        'setUnitEvictsNullSnapshotForCustomAssignmentAndCustomAppliesAfterRecompute',
        () async {
      final context = await readyWith(
          ContextConfig.create()
            ..setCustomAssignment('exp_custom_late_unit', 3),
          contextDataOf([
            newHoldout(
                11, 'holdout_custom_late', holdoutBSeedHi, holdoutBSeedLo,
                unit: 'user_id')
          ], [
            newExperiment(1, 'exp_custom_late_unit',
                unit: 'user_id', holdoutIds: [11])
          ]));

      expect(context.peekTreatment('exp_custom_late_unit'), 0);

      context.setUnit('user_id', uid);

      expect(context.getTreatment('exp_custom_late_unit'), 3);
      expect(context.getPendingCount(), 2);

      await expectPublished(
          context,
          [
            exposure(1, 'exp_custom_late_unit', 3,
                unit: 'user_id', custom: true),
            holdoutExposure(11, 'holdout_custom_late', 1, unit: 'user_id'),
          ],
          unit: 'user_id');
    });
  });

  group('cross-SDK verdict vectors', () {
    const verdictUnitType = 'verdict_unit_type';

    Future<Context> verdictContext(
        String unitId, List<ContextHoldout> holdouts) {
      return readyWith(
          ContextConfig.create()..setUnit(verdictUnitType, unitId),
          contextDataOf(holdouts, [
            newExperiment(9, 'verdict_vectors_experiment',
                unit: verdictUnitType,
                holdoutIds: [for (final h in holdouts) h.id])
          ]));
    }

    ContextHoldout verdictHoldout(
            int id, int seedHi, int seedLo, List<double> split) =>
        newHoldout(id, 'holdout_$id', seedHi, seedLo,
            unit: verdictUnitType, split: split);

    Future<void> expectHeldOutBy(Context context, int holdoutId) async {
      publisher.events.clear();
      expect(context.getTreatment('verdict_vectors_experiment'), 0);
      final event = await publish(context);
      expect(event.exposures, hasLength(1));
      expect(event.exposures.single.id, holdoutId);
      expect(event.exposures.single.name, 'holdout_$holdoutId');
      expect(event.exposures.single.variant, 0);
    }

    Future<void> expectNotHeldOut(Context context, int holdoutId) async {
      publisher.events.clear();
      context.getTreatment('verdict_vectors_experiment');
      final event = await publish(context);
      expect(
          event.exposures.where((e) =>
              e.id == holdoutId &&
              e.name == 'holdout_$holdoutId' &&
              e.variant == 1),
          hasLength(1));
    }

    test('unicodeUnitIds', () async {
      await expectHeldOutBy(
          await verdictContext('façade', [
            verdictHoldout(107, 0, 42, [0.1, 0.9])
          ]),
          107);
      await expectNotHeldOut(
          await verdictContext('unicode_emoji_\u{1F680}_0', [
            verdictHoldout(107, 0, 42, [0.1, 0.9])
          ]),
          107);
    });

    test('signedSeedHalves', () async {
      // 0x8000000080000000 as a signed int64: the sign bit is set in both
      // 32-bit halves.
      const int seedHi = -2147483648;
      const int seedLo = -2147483648;
      await expectHeldOutBy(
          await verdictContext('signed_unit_4', [
            verdictHoldout(106, seedHi, seedLo, [0.1, 0.9])
          ]),
          106);
      await expectNotHeldOut(
          await verdictContext('signed_unit_b_1', [
            verdictHoldout(106, seedHi, seedLo, [0.1, 0.9])
          ]),
          106);
    });

    test('percentageBoundaryAtOnePercent', () async {
      await expectHeldOutBy(
          await verdictContext('pct1_unit_188', [
            verdictHoldout(105, 0, 999999, [0.01, 0.99])
          ]),
          105);
      await expectNotHeldOut(
          await verdictContext('pct1_unit_0', [
            verdictHoldout(105, 0, 999999, [0.01, 0.99])
          ]),
          105);
    });

    test('assignmentProbabilityBoundaryAroundTenPercent', () async {
      await expectHeldOutBy(
          await verdictContext('boundary_unit_175653', [
            verdictHoldout(107, 0, 42, [0.1, 0.9])
          ]),
          107);
      await expectNotHeldOut(
          await verdictContext('boundary_unit_75792', [
            verdictHoldout(107, 0, 42, [0.1, 0.9])
          ]),
          107);
    });

    test('unitHeldOutByTwoHoldoutsSimultaneously', () async {
      final context = await verdictContext('dual_holdout_unit_5', [
        verdictHoldout(107, 0, 42, [0.1, 0.9]),
        verdictHoldout(108, 0, 55, [0.1, 0.9]),
      ]);

      expect(context.getTreatment('verdict_vectors_experiment'), 0);

      await expectPublished(
          context,
          [
            holdoutExposure(107, 'holdout_107', 0, unit: verdictUnitType),
            holdoutExposure(108, 'holdout_108', 0, unit: verdictUnitType),
          ],
          unit: verdictUnitType,
          unitId: 'dual_holdout_unit_5');
    });
  });

  group('variables', () {
    test('variableLookupFiresHoldoutExposureForBothHeldOutAndNonHeldOutUnits',
        () async {
      final heldOut = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_var_held_out', holdoutIds: [11])
          ..variants[1].config = '{"var_a":"value_a"}'
      ]));

      expect(heldOut.getVariableValue('var_a', 'default'), 'default');
      expect(heldOut.getPendingCount(), 1);

      final notHeldOut = await ready(
          contextDataOf([
            newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
          ], [
            newExperiment(1, 'exp_var_not_held_out', holdoutIds: [11])
              ..variants[1].config = '{"var_a":"value_a"}'
          ]),
          unitId: uidNotHeldOut);

      expect(notHeldOut.getVariableValue('var_a', 'default'), 'default');
      expect(notHeldOut.getPendingCount(), 2);
    });

    test('variableKeyResolutionSkipsSuppressedAssignmentInFavorOfAssignedOne',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_var_key_suppressed', holdoutIds: [11])
          ..variants[1].config = '{"shared":"from_suppressed"}',
        newExperiment(2, 'exp_var_key_assigned')
          ..variants[1].config = '{"shared":"from_assigned"}',
      ]));

      expect(context.getVariableValue('shared', 'default'), 'from_assigned');

      await expectPublished(context, [
        holdoutExposure(11, 'holdout_a', 0),
        exposure(2, 'exp_var_key_assigned', normalVariant),
      ]);
    });

    test('peekVariableValueNeverTriggersHoldoutExposureForEvaluatedCandidates',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_var_key_peek_suppressed', holdoutIds: [11])
          ..variants[1].config = '{"shared_peek":"from_suppressed"}',
        newExperiment(2, 'exp_var_key_peek_assigned')
          ..variants[1].config = '{"shared_peek":"from_assigned"}',
      ]));

      expect(
          context.peekVariableValue('shared_peek', 'default'), 'from_assigned');
      expect(context.getPendingCount(), 0);
    });

    test('variablePathHoldoutExposureSchedulesFlushWithoutAnyOtherEvent',
        () async {
      final context = await create(
          ContextConfig.create()..setUnit(unitType, uid),
          contextDataOf([
            newHoldout(11, 'holdout_flush', holdoutASeedHi, holdoutASeedLo)
          ], [
            newExperiment(1, 'exp_var_flush_suppressed', holdoutIds: [11])
              ..variants[1].config = '{"flush_key":"from_suppressed"}',
            newExperiment(2, 'exp_var_flush_assigned')
              ..variants[1].config = '{"flush_key":"from_assigned"}',
          ])).waitUntilReady();
      context.publishDelay_ = 100;
      expect(context.getTreatment('exp_var_flush_assigned'), normalVariant);
      context.clearTimeout();
      expect(context.timeout_, isNull);

      expect(context.getVariableValue('flush_key', 'default'), 'from_assigned');

      expect(context.getPendingCount(), 2);
      expect(context.timeout_, isNotNull);
      context.clearTimeout();
    });
    test('a held-out fallback beats an assigned candidate lacking the key',
        () async {
      final context = await ready(
          contextDataOf([
            newHoldout(11, 'holdout_all', holdoutASeedHi, holdoutASeedLo,
                split: const [1.0, 0.0])
          ], [
            withVariables(newExperiment(1, 'exp_held_banner', holdoutIds: [11]),
                'banner'),
            newExperiment(2, 'exp_sparse_banner')
              ..variants[1].config = '{"banner":"b1"}',
          ]),
          unitId: uidNotHeldOut);

      expect(context.peekTreatment('exp_sparse_banner'), 0);
      expect(context.peekVariableValue('banner', 'default'), 'control');
      expect(context.getPendingCount(), 0);
      expect(context.getVariableValue('banner', 'default'), 'control');

      await expectPublished(
          context,
          [
            holdoutExposure(11, 'holdout_all', 0),
            exposure(2, 'exp_sparse_banner', 0),
          ],
          unitId: uidNotHeldOut);
    });

    test('an assigned candidate lacking a covered key passes to the next one',
        () async {
      final context = await ready(
          contextDataOf([
            newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)
          ], [
            newExperiment(1, 'exp_sparse_first')
              ..variants[1].config = '{"banner":"first"}',
            withVariables(
                newExperiment(2, 'exp_dense_second', holdoutIds: [11]),
                'banner'),
          ]),
          unitId: uidNotHeldOut);

      expect(context.getVariableValue('banner', 'default'), 'control');

      await expectPublished(
          context,
          [
            exposure(1, 'exp_sparse_first', 0),
            exposure(2, 'exp_dense_second', 0),
            holdoutExposure(11, 'holdout_b', 1),
          ],
          unitId: uidNotHeldOut);
    });

    test('a key no holdout covers reads as without holdouts', () async {
      final experiments = [
        newExperiment(1, 'exp_sparse_first')
          ..variants[1].config = '{"banner":"first"}',
        withVariables(newExperiment(2, 'exp_dense_second'), 'banner'),
        newExperiment(3, 'exp_covered', holdoutIds: [11]),
      ];
      final withHoldout = await ready(
          contextDataOf(
              [newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)],
              experiments),
          unitId: uidNotHeldOut);
      final withoutHoldout =
          await ready(contextDataOf(null, experiments), unitId: uidNotHeldOut);

      for (final context in [withHoldout, withoutHoldout]) {
        expect(context.peekVariableValue('banner', 'default'), 'default');
        expect(context.getVariableValue('banner', 'default'), 'default');
        expect(context.getPendingCount(), 1);
      }
    });

    test('a key whose holdouts are not servable reads as without holdouts',
        () async {
      List<Experiment> experiments() => [
            newExperiment(1, 'exp_sparse_first', holdoutIds: [11])
              ..variants[1].config = '{"banner":"first"}',
            withVariables(newExperiment(2, 'exp_dense_second'), 'banner'),
          ];
      for (final holdouts in [
        [newHoldout(12, 'holdout_other', holdoutBSeedHi, holdoutBSeedLo)],
        [
          newHoldout(11, 'holdout_empty', holdoutBSeedHi, holdoutBSeedLo,
              split: const [])
        ],
      ]) {
        final context = await ready(contextDataOf(holdouts, experiments()),
            unitId: uidNotHeldOut);

        expect(context.peekVariableValue('banner', 'default'), 'default');
        expect(context.getVariableValue('banner', 'default'), 'default');
        expect(context.getPendingCount(), 1);
      }
    });

    test('an out-of-range override on a covered key is skipped', () async {
      for (final variant in [5, -1]) {
        publisher.events.clear();
        final context = await ready(contextDataOf([
          newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)
        ], [
          withVariables(
              newExperiment(1, 'exp_out_of_range', holdoutIds: [11]), 'color'),
          withVariables(newExperiment(2, 'exp_in_range'), 'color'),
        ]));
        context.setOverride('exp_out_of_range', variant);

        expect(context.peekVariableValue('color', 'default'), 'treatment');
        expect(context.getVariableValue('color', 'default'), 'treatment');

        await expectPublished(
            context, [exposure(2, 'exp_in_range', normalVariant)]);
      }
    });

    test('an override on a held-out covered candidate wins', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        withVariables(
            newExperiment(1, 'exp_held_overridden', holdoutIds: [11]), 'color'),
      ]));
      context.setOverride('exp_held_overridden', 1);

      expect(context.peekVariableValue('color', 'default'), 'treatment');
      expect(context.getVariableValue('color', 'default'), 'treatment');
    });

    test('a rule-won held-out candidate lacking the key is no fallback',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_held_rule', holdoutIds: [11])
          ..assignmentRules = usRule
          ..variants[0].config = '{"shared":"rule_control"}',
        newExperiment(2, 'exp_held_plain', holdoutIds: [11])
          ..variants[0].config = '{"shared":"plain_control"}',
      ]));
      context.setAttribute('country', 'US');

      expect(context.peekVariableValue('shared', 'default'), 'plain_control');
      expect(context.getVariableValue('shared', 'default'), 'plain_control');
    });

    test('the first held-out candidate is the fallback', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_held_first', holdoutIds: [11])
          ..variants[0].config = '{"shared":"first_control"}',
        newExperiment(2, 'exp_held_second', holdoutIds: [11])
          ..variants[0].config = '{"shared":"second_control"}',
      ]));

      expect(context.peekVariableValue('shared', 'default'), 'first_control');
      expect(context.getVariableValue('shared', 'default'), 'first_control');
    });

    test('an overridden held-out candidate lacking the key is no fallback',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_held_overridden', holdoutIds: [11])
          ..variants[0].config = '{"shared":"overridden_control"}',
        newExperiment(2, 'exp_held_plain', holdoutIds: [11])
          ..variants[0].config = '{"shared":"plain_control"}',
      ]));
      context.setOverride('exp_held_overridden', 1);

      expect(context.getVariableValue('shared', 'default'), 'plain_control');
    });
  });

  group('event logger', () {
    // A throwing logger never reaches the caller (JS context.ts _logEvent);
    // Java rethrows it. Either way, every exposure is queued once.
    test('throwingLoggerDoesNotPermanentlyLoseSiblingHoldoutExposure',
        () async {
      logger.throwOn = (exposure) => exposure.id == 11;
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo),
        newHoldout(12, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo),
      ], [
        newExperiment(1, 'exp_multi_holdout_throwing_logger',
            holdoutIds: [11, 12])
      ]));

      expect(context.getTreatment('exp_multi_holdout_throwing_logger'), 0);
      expect(context.getPendingCount(), 2);
    });

    test('throwingLoggerDoesNotMakeExperimentOrHoldoutExposureRetryable',
        () async {
      logger.throwOn = (exposure) => exposure.id == 1;
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_terminal', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_throwing_logger_terminal', holdoutIds: [11])
      ]));

      expect(
          context.getTreatment('exp_throwing_logger_terminal'), normalVariant);
      logger.throwOn = null;
      expect(
          context.getTreatment('exp_throwing_logger_terminal'), normalVariant);

      await expectPublished(context, [
        exposure(1, 'exp_throwing_logger_terminal', normalVariant),
        holdoutExposure(11, 'holdout_terminal', 1),
      ]);
    });

    test('throwingLoggerOnSuppressedExperimentsOnlyHoldoutStillSchedulesFlush',
        () async {
      logger.throwOn = (_) => true;
      final context = await create(
          ContextConfig.create()..setUnit(unitType, uid),
          contextDataOf([
            newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
          ], [
            newExperiment(1, 'exp_stranded_flush', holdoutIds: [11])
          ])).waitUntilReady();
      context.publishDelay_ = 100;

      expect(context.getTreatment('exp_stranded_flush'), 0);

      expect(context.getPendingCount(), 1);
      expect(context.timeout_, isNotNull);
      context.clearTimeout();
    });

    test('a holdout exposure is queued before the logger sees it', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_logged', holdoutIds: [11])
      ]));
      final List<int> pendingAtHoldout = [];
      logger.onExposure = (exposure) {
        if (exposure.id == 11) {
          pendingAtHoldout.add(context.getPendingCount());
        }
      };

      context.getTreatment('exp_logged');

      expect(pendingAtHoldout, [2]);
    });
  });

  test('cached covered reads use the holdout identity fast path', () async {
    final context = await ready(contextDataOf([
      newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)
    ], [
      newExperiment(1, 'exp_cached', holdoutIds: [11])
    ]));
    context.peekTreatment('exp_cached');
    ContextCounters.reset();
    for (int i = 0; i < 10; i++) {
      expect(context.peekTreatment('exp_cached'), normalVariant);
    }
    expect(ContextCounters.holdoutSetComparisons, 0);
  });

  test('close drains more than two batches queued by publish callbacks',
      () async {
    final context = await ready(contextDataOf([], [
      newExperiment(1, 'exp_one'),
      newExperiment(2, 'exp_two'),
      newExperiment(3, 'exp_three'),
    ]));
    context.getTreatment('exp_one');
    publisher.onPublish = () {
      if (publisher.events.length < 3) {
        context.queueExposure(context.getAssignment(
            publisher.events.length == 1 ? 'exp_two' : 'exp_three'));
      }
    };
    await context.close();
    expect(publisher.events, hasLength(3));
    expect(context.getPendingCount(), 0);
  });

  group('malformed holdouts', () {
    test('nullHoldoutArrayElementIsIgnoredAndExperimentAssignsNormally',
        () async {
      final data = ContextData.fromMap({
        'experiments': [newExperiment(1, 'exp_null_holdout_entry').toMap()],
        'holdouts': [null],
      });
      final context = await ready(data);

      expect(context.getTreatment('exp_null_holdout_entry'), normalVariant);
      await expectPublished(
          context, [exposure(1, 'exp_null_holdout_entry', normalVariant)]);
    });

    test('holdoutWithNullSplitIsIgnoredAndExperimentAssignsNormally', () async {
      final data = ContextData.fromMap({
        'experiments': [
          newExperiment(1, 'exp_null_split_holdout', holdoutIds: [11]).toMap()
        ],
        'holdouts': [
          newHoldout(11, 'holdout_null_split', holdoutASeedHi, holdoutASeedLo)
              .toMap()
            ..['split'] = null
        ],
      });
      final context = await ready(data);

      expect(context.getTreatment('exp_null_split_holdout'), normalVariant);
      await expectPublished(
          context, [exposure(1, 'exp_null_split_holdout', normalVariant)]);
    });

    test('holdoutWithEmptySplitIsIgnoredAndExperimentAssignsNormally',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_empty_split', holdoutASeedHi, holdoutASeedLo,
            split: const [])
      ], [
        newExperiment(1, 'exp_empty_split_holdout', holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_empty_split_holdout'), normalVariant);
      await expectPublished(
          context, [exposure(1, 'exp_empty_split_holdout', normalVariant)]);
    });

    test('whole-number doubles are accepted for holdout integers', () async {
      final holdout = ContextHoldout.fromMap({
        'id': 11.0,
        'name': 'holdout_doubles',
        'unitType': unitType,
        'iteration': 1.0,
        'seedHi': 13.0,
        'seedLo': 111.0,
        'split': [0.1, 0.9],
      });

      expect(
          holdout,
          newHoldout(11, 'holdout_doubles', holdoutASeedHi, holdoutASeedLo)
            ..holdoutType = null);
    });

    test('ContextData equality compares holdouts', () {
      final experiments = [
        newExperiment(1, 'exp_eq', holdoutIds: [11])
      ];

      expect(
          contextDataOf(
              [newHoldout(11, 'holdout_eq', holdoutASeedHi, holdoutASeedLo)],
              experiments),
          isNot(contextDataOf(
              [newHoldout(11, 'holdout_eq', holdoutBSeedHi, holdoutBSeedLo)],
              experiments)));
      expect(
          contextDataOf(null, experiments),
          isNot(contextDataOf(
              [newHoldout(11, 'holdout_eq', holdoutASeedHi, holdoutASeedLo)],
              experiments)));
    });

    test('ids beyond 2^53 - 1 are dropped', () {
      // Integer and decimal spellings alike, so the VM and the web agree.
      final Map<String, dynamic> holdout =
          newHoldout(11, 'holdout_huge', holdoutASeedHi, holdoutASeedLo)
              .toMap();
      for (final id in [
        9007199254740992,
        9007199254740992.0,
        -9007199254740992,
        // The VM's minimum int, whose abs() overflows to itself.
        int.parse('-9223372036854775808'),
      ]) {
        holdout['id'] = id;
        expect(() => ContextHoldout.fromMap(holdout), throwsFormatException);
      }
      for (final id in [
        9007199254740991,
        9007199254740991.0,
        -9007199254740991,
        -9007199254740991.0,
      ]) {
        holdout['id'] = id;
        expect(ContextHoldout.fromMap(holdout).id, id.toInt());
      }

      final experiment = Experiment.fromMap(newExperiment(1, 'exp_huge').toMap()
        ..['holdoutIds'] = [
          1e20,
          9007199254740992,
          9007199254740992.0,
          9007199254740991,
          11.0
        ]);
      expect(experiment.holdoutIds, [9007199254740991, 11]);
    });

    test('an infinite holdout id is dropped, not thrown', () {
      final data = ContextData.fromMap({
        'experiments': [
          newExperiment(1, 'exp_infinite').toMap()
            ..['holdoutIds'] = [double.infinity, double.nan, 2]
        ],
        'holdouts': [
          newHoldout(1, 'holdout_infinite', holdoutASeedHi, holdoutASeedLo)
              .toMap()
            ..['id'] = double.infinity,
          newHoldout(2, 'holdout_finite', holdoutASeedHi, holdoutASeedLo)
              .toMap(),
        ],
      });

      expect(data.holdouts.map((holdout) => holdout.id), [2]);
      expect(data.experiments.single.holdoutIds, [2]);
    });

    test('variable reads on holdout-free data never look up holdout keys',
        () async {
      ContextCounters.reset();
      final experiments = [
        withVariables(newExperiment(1, 'exp_free'), 'color')
      ];
      final free = await ready(contextDataOf(null, experiments));

      expect(free.peekVariableValue('color', 'default'), 'treatment');
      expect(free.getVariableValue('color', 'default'), 'treatment');
      expect(ContextCounters.holdoutKeyLookups, 0);

      final covered = await ready(contextDataOf([
        newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        withVariables(
            newExperiment(1, 'exp_covered', holdoutIds: [11]), 'color')
      ]));
      expect(covered.getVariableValue('color', 'default'), 'treatment');
      expect(ContextCounters.holdoutKeyLookups, 1);
    });

    test('an uncovered key keeps the released selection next to a covered key',
        () async {
      final partial = newExperiment(2, 'exp_free_partial')
        ..variants = [
          ExperimentVariant(name: 'A', config: '{"free":"control"}'),
          ExperimentVariant(name: 'B', config: '{}'),
        ];
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        withVariables(
            newExperiment(1, 'exp_covered', holdoutIds: [11]), 'covered'),
        partial,
        withVariables(newExperiment(3, 'exp_free'), 'free'),
      ]));

      expect(context.peekTreatment('exp_free_partial'), normalVariant);
      expect(context.peekVariableValue('free', 'default'), 'default');
      expect(context.getVariableValue('free', 'default'), 'default');
      expect(context.peekVariableValue('covered', 'default'), 'treatment');
    });

    test('close publishes exposures a variable read queues while closing',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_sparse', holdoutIds: [11])
          ..variants[0].config = '{"k":"a0"}',
        withVariables(newExperiment(2, 'exp_dense'), 'k'),
      ]));
      Future<void>? closing;
      logger.onExposure = (exposure) {
        if (exposure.id == 1) {
          closing ??= context.close();
        }
      };

      expect(context.getVariableValue('k', 'default'), 'treatment');
      await closing;

      expect(publisher.events.expand((event) => event.exposures).toList(), [
        exposure(1, 'exp_sparse', normalVariant),
        holdoutExposure(11, 'holdout_b', 1),
        exposure(2, 'exp_dense', normalVariant),
      ]);
      expect(context.getPendingCount(), 0);
      expect(context.isClosed(), isTrue);
    });

    test('close from inside a publish still drains the read in progress',
        () async {
      final held = HeldPublisher();
      publisher = held;
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        withVariables(newExperiment(1, 'exp_winner', holdoutIds: [11]), 'k'),
      ]));
      Future<void>? closing;
      held.onFirstPublish = () => closing = context.close();
      logger.onExposure = (exposure) {
        if (exposure.id == 1) {
          context.publish();
        }
      };

      expect(context.getVariableValue('k', 'default'), 'treatment');
      await Future<void>.delayed(Duration.zero);
      expect(context.isClosed(), isFalse);

      held.release();
      await closing;

      expect(held.events.map((event) => event.exposures), [
        [exposure(1, 'exp_winner', normalVariant)],
        [holdoutExposure(11, 'holdout_b', 1)],
      ]);
      expect(context.getPendingCount(), 0);
      expect(context.isClosed(), isTrue);
    });

    test('a candidate removed during a variable read is not exposed', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_sparse', holdoutIds: [11])
          ..variants[0].config = '{"k":"a0"}',
        withVariables(newExperiment(2, 'exp_removed'), 'k'),
      ]));
      logger.onExposure = (exposure) {
        if (exposure.id == 1) {
          context.setData(contextDataOf([], []));
        }
      };

      expect(context.getVariableValue('k', 'default'), 'default');

      await expectPublished(context, [
        exposure(1, 'exp_sparse', normalVariant),
        holdoutExposure(11, 'holdout_b', 1),
      ]);
    });

    test('a retained override keeps its variables after a refresh', () async {
      ContextData data(int variants) => contextDataOf([
            newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)
          ], [
            newExperiment(1, 'exp_override', holdoutIds: [11])
              ..variants = [
                for (final name in ['zero', 'one', 'two'].take(variants))
                  ExperimentVariant(name: name, config: '{"k":"$name"}')
              ],
          ]);
      final context = await ready(data(3));
      context.setOverride('exp_override', 2);

      expect(context.peekVariableValue('k', 'default'), 'two');
      await refreshWith(context, data(2));
      expect(context.peekTreatment('exp_override'), 2);
      expect(context.getVariableValue('k', 'default'), 'two');

      await expectPublished(context, [
        exposure(1, 'exp_override', 2, assigned: false, overridden: true),
        holdoutExposure(11, 'holdout_b', 1),
      ]);
    });

    test('a variable read walks its key\'s candidates once', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        withVariables(
            newExperiment(1, 'exp_covered', holdoutIds: [11]), 'covered'),
        withVariables(newExperiment(2, 'exp_free'), 'free'),
      ]));
      ContextCounters.reset();

      for (final key in ['covered', 'free']) {
        expect(context.peekVariableValue(key, 'default'), 'treatment');
        expect(context.getVariableValue(key, 'default'), 'treatment');
      }
      expect(ContextCounters.variableCandidateLookups, 4);
      expect(ContextCounters.assignmentLookups, 4);
    });

    test('holdoutIds with no servable holdout skip the holdout path', () async {
      ContextCounters.reset();
      final context = await ready(contextDataOf([], [
        newExperiment(1, 'exp_no_servable', holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_no_servable'), normalVariant);
      expect(ContextCounters.coveredAssignmentResolutions, 0);
    });

    test('setDataDoesNotMutateCallerSuppliedHoldoutIdsArray', () async {
      final callerIds = [12, 11];
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_no_mutate', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_holdout_no_mutate_in', holdoutIds: callerIds),
        newExperiment(2, 'exp_holdout_no_mutate_not_covered'),
      ]));

      expect(context.getTreatment('exp_holdout_no_mutate_in'), 0);
      expect(context.getTreatment('exp_holdout_no_mutate_not_covered'),
          normalVariant);
      expect(callerIds, [12, 11]);
    });
  });

  group('assignment rules', () {
    test('matchingAssignmentRuleWinsOverHoldoutSuppression', () async {
      final context = await ready(contextDataOf([
        newHoldout(
            11, 'holdout_rules_suppression', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_holdout_rules', holdoutIds: [11])
          ..assignmentRules = usRule
      ]));
      context.setAttribute('country', 'US');

      expect(context.getTreatment('exp_holdout_rules'), 1);

      await expectPublished(context, [
        exposure(1, 'exp_holdout_rules', 1,
            assigned: false, ruleOverride: true),
        holdoutExposure(11, 'holdout_rules_suppression', 0),
      ], attributes: [
        Attribute(name: 'country', value: 'US', setAt: now)
      ]);
    });

    test('matchingSplitRuleWinsOverHoldoutSuppression', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_holdout_split_rule', holdoutIds: [11])
          ..assignmentRules =
              '{"rules":[{"name":"Everyone","type":"split","conditions":null,"environments":[],"percentages":"0/100"}]}'
      ]));

      expect(context.peekTreatment('exp_holdout_split_rule'), 1);
      expect(context.getTreatment('exp_holdout_split_rule'), 1);
      expect(context.getPendingCount(), 2);
    });

    test('heldOutUnitIsSuppressedWhenRuleDoesNotMatch', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_holdout_rules', holdoutIds: [11])
          ..assignmentRules = usRule
      ]));
      context.setAttribute('country', 'GB');

      expect(context.getTreatment('exp_holdout_rules'), 0);
      expect(context.getPendingCount(), 1);

      context.setAttribute('country', 'US');
      expect(context.getTreatment('exp_holdout_rules'), 1);
      expect(context.getPendingCount(), 2);
    });

    test('heldOutUnitIsSuppressedAgainWhenRuleStopsMatching', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_holdout_rules', holdoutIds: [11])
          ..assignmentRules = usRule
      ]));
      context.setAttribute('country', 'US');

      expect(context.getTreatment('exp_holdout_rules'), 1);
      expect(context.getPendingCount(), 2);

      context.setAttribute('country', 'GB');
      expect(context.getTreatment('exp_holdout_rules'), 0);
      expect(context.peekTreatment('exp_holdout_rules'), 0);
      expect(context.getPendingCount(), 2);
    });

    test('variableValueOnHeldOutRuleWonExperiment', () async {
      final context = await ready(contextDataOf([
        newHoldout(
            11, 'holdout_rules_suppression', holdoutASeedHi, holdoutASeedLo)
      ], [
        withVariables(
            newExperiment(1, 'exp_holdout_rules', holdoutIds: [11]), 'color')
          ..assignmentRules = usRule
      ]));
      context.setAttribute('country', 'US');

      expect(context.getVariableValue('color', 'default'), 'treatment');

      await expectPublished(context, [
        exposure(1, 'exp_holdout_rules', 1,
            assigned: false, ruleOverride: true),
        holdoutExposure(11, 'holdout_rules_suppression', 0),
      ], attributes: [
        Attribute(name: 'country', value: 'US', setAt: now)
      ]);
    });

    test('sharedVariableKeyPrefersRuleWonOverSuppressedExperiment', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        withVariables(
            newExperiment(1, 'exp_held_out', holdoutIds: [11]), 'color'),
        withVariables(
            newExperiment(2, 'exp_rule_won', holdoutIds: [11]), 'color')
          ..assignmentRules = usRule,
      ]));

      context.setAttribute('country', 'GB');
      expect(context.peekVariableValue('color', 'default'), 'control');

      context.setAttribute('country', 'US');
      expect(context.peekVariableValue('color', 'default'), 'treatment');
    });

    test('sharedVariableKeyPrefersEarlierAssignedOverLaterRuleWonExperiment',
        () async {
      final context = await ready(contextDataOf([], [
        withVariables(newExperiment(1, 'exp_assigned'), 'color')
          ..split = [1.0, 0.0],
        withVariables(newExperiment(2, 'exp_rule_won'), 'color')
          ..assignmentRules = usRule,
      ]));
      context.setAttribute('country', 'US');

      expect(context.peekVariableValue('color', 'default'), 'control');
      expect(context.peekTreatment('exp_rule_won'), 1);
    });
  });

  group('javascript parity', () {
    test('a duplicate holdout id exposes and decides once (H1)', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_dup', holdoutIds: [11, 11])
      ]));

      expect(context.getTreatment('exp_dup'), normalVariant);
      await expectPublished(context, [
        exposure(1, 'exp_dup', normalVariant),
        holdoutExposure(11, 'holdout_a', 1),
      ]);
    });

    test('dropping a duplicate holdout id on refresh does not re-expose',
        () async {
      ContextData data(List<int> ids) => contextDataOf(
          [newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo)],
          [newExperiment(1, 'exp_dup_refresh', holdoutIds: ids)]);
      final context = await ready(data([11, 11]));

      expect(context.getTreatment('exp_dup_refresh'), normalVariant);
      expect(context.getPendingCount(), 2);

      await refreshWith(context, data([11]));

      expect(context.getTreatment('exp_dup_refresh'), normalVariant);
      expect(context.getPendingCount(), 2);
    });

    test('holdouts are exposed in id order whatever the payload order',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(12, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo),
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo),
        newHoldout(13, 'holdout_c', holdoutBSeedHi, holdoutBSeedLo),
      ], [
        newExperiment(1, 'exp_order', holdoutIds: [13, 12, 11, 12])
      ]));

      expect(context.getTreatment('exp_order'), 0);
      await expectPublished(context, [
        holdoutExposure(11, 'holdout_a', 0),
        holdoutExposure(12, 'holdout_b', 1),
        holdoutExposure(13, 'holdout_c', 1),
      ]);
    });

    test('a holding-out holdout before a not-holding-out one still suppresses',
        () async {
      // Lowest id holds out, the later ones do not: a union that lets the
      // last holdout decide would assign the experiment.
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo),
        newHoldout(12, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo),
        newHoldout(13, 'holdout_c', holdoutBSeedHi, holdoutBSeedLo),
      ], [
        newExperiment(1, 'exp_first_decides', holdoutIds: [11, 12, 13])
      ]));

      expect(context.peekTreatment('exp_first_decides'), 0);
    });

    test('a suppressed experiment does not evaluate its audience', () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_suppressed_audience', holdoutIds: [11])
          ..audience = ageAudience
      ]));
      context.setAttribute('age', 5);

      expect(context.getTreatment('exp_suppressed_audience'), 0);
      expect(context.getTreatment('exp_suppressed_audience'), 0);
      expect(jsonExpr.evaluations, 0);
      await expectPublished(context, [holdoutExposure(11, 'holdout_a', 0)],
          attributes: [Attribute(name: 'age', value: 5, setAt: now)]);
    });

    test('an entry without a split or with an empty one is not served (H2)',
        () async {
      final data = ContextData.fromMap({
        'experiments': [
          newExperiment(1, 'exp_no_split', holdoutIds: [11, 12]).toMap()
        ],
        'holdouts': [
          {'id': 11, 'name': 'no_split', 'seedHi': 13, 'seedLo': 111},
          newHoldout(12, 'empty_split', holdoutASeedHi, holdoutASeedLo,
              split: const []).toMap(),
        ],
      });
      final context = await ready(data);

      expect(context.getTreatment('exp_no_split'), normalVariant);
      await expectPublished(
          context, [exposure(1, 'exp_no_split', normalVariant)]);
    });

    test('peekTreatment and peekVariableValue queue no holdout exposure (H4)',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        withVariables(newExperiment(1, 'exp_peek', holdoutIds: [11]), 'color')
      ]));

      expect(context.peekTreatment('exp_peek'), 0);
      expect(context.peekVariableValue('color', 'default'), 'control');
      expect(context.getPendingCount(), 0);
    });

    test('unknown fields inside holdout entries are ignored (H5)', () async {
      final data = ContextData.fromMap({
        'experiments': [
          newExperiment(1, 'exp_future', holdoutIds: [11]).toMap()
            ..['futureExperimentField'] = {'x': 1},
          newExperiment(2, 'exp_uncovered').toMap(),
        ],
        'holdouts': [
          newHoldout(11, 'holdout_future', holdoutASeedHi, holdoutASeedLo)
              .toMap()
            ..['futureScalar'] = 'x'
            ..['futureObject'] = {
              'nested': [1, null]
            }
            ..['futureArray'] = [
              {'a': 1}
            ]
            ..['switchbackClusters'] = {'b': '1', 'a': '2'},
        ],
        'futureRoot': [1],
      });
      final context = await ready(data);

      expect(context.getTreatment('exp_future'), 0);
      expect(context.getTreatment('exp_uncovered'), normalVariant);
      await expectPublished(context, [
        holdoutExposure(11, 'holdout_future', 0),
        exposure(2, 'exp_uncovered', normalVariant),
      ]);
    });

    test('one holdout over two unit types exposes once per unit type (H6)',
        () async {
      final context = await readyWith(
          ContextConfig.create()
            ..setUnit('session_id', uid)
            ..setUnit('user_id', uid),
          contextDataOf([
            newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
          ], [
            newExperiment(1, 'exp_session', holdoutIds: [11]),
            newExperiment(2, 'exp_user', unit: 'user_id', holdoutIds: [11]),
          ]));

      expect(context.getTreatment('exp_session'), 0);
      expect(context.getTreatment('exp_user'), 0);
      expect(context.getTreatment('exp_session'), 0);
      final event = await publish(context);
      expect(event.exposures, [
        holdoutExposure(11, 'holdout_a', 0),
        holdoutExposure(11, 'holdout_a', 0, unit: 'user_id'),
      ]);
    });

    test('a strict audience mismatch on a not-held-out unit still fires (H7)',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo)
      ], [
        newExperiment(1, 'exp_strict', holdoutIds: [11])
          ..audienceStrict = true
          ..audience = ageAudience
      ]));
      context.setAttribute('age', 5);

      expect(context.getTreatment('exp_strict'), 0);
      await expectPublished(context, [
        exposure(1, 'exp_strict', 0, assigned: false, audienceMismatch: true),
        holdoutExposure(11, 'holdout_a', 1),
      ], attributes: [
        Attribute(name: 'age', value: 5, setAt: now)
      ]);
    });

    test(
        'a shared key skips a suppressed candidate and fires both holdouts (H8)',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo),
        newHoldout(12, 'holdout_b', holdoutBSeedHi, holdoutBSeedLo),
      ], [
        withVariables(
            newExperiment(1, 'exp_suppressed', holdoutIds: [11]), 'color'),
        withVariables(
            newExperiment(2, 'exp_assigned', holdoutIds: [12]), 'color'),
      ]));

      expect(context.getVariableValue('color', 'default'), 'treatment');
      await expectPublished(context, [
        holdoutExposure(11, 'holdout_a', 0),
        exposure(2, 'exp_assigned', normalVariant),
        holdoutExposure(12, 'holdout_b', 1),
      ]);
    });

    test('a covered candidate passed over before setUnit stays pinned',
        () async {
      // JS exposes every covered candidate a variable read passes over, so a
      // later setUnit does not re-randomize it.
      final context = await readyWithoutUnits(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo,
            unit: 'user_id')
      ], [
        withVariables(
            newExperiment(1, 'exp_var_late', unit: 'user_id', holdoutIds: [11]),
            'color')
      ]));

      expect(context.getVariableValue('color', 'default'), 'default');
      expect(context.getPendingCount(), 1);

      context.setUnit('user_id', uid);

      expect(context.getTreatment('exp_var_late'), 0);
      expect(context.getVariableValue('color', 'default'), 'default');
      await expectPublished(context,
          [exposure(1, 'exp_var_late', 0, unit: 'user_id', assigned: false)],
          unit: 'user_id');
    });

    test('a covered candidate passed over is exposed once with its holdouts',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo),
      ], [
        withVariables(
            newExperiment(1, 'exp_mismatch', holdoutIds: [11])
              ..audienceStrict = true
              ..audience = ageAudience,
            'color'),
        withVariables(newExperiment(2, 'exp_assigned'), 'color'),
      ]));
      context.setAttribute('age', 5);

      expect(context.getVariableValue('color', 'default'), 'treatment');
      expect(context.getVariableValue('color', 'default'), 'treatment');
      await expectPublished(context, [
        exposure(1, 'exp_mismatch', 0, assigned: false, audienceMismatch: true),
        holdoutExposure(11, 'holdout_a', 1),
        exposure(2, 'exp_assigned', normalVariant),
      ], attributes: [
        Attribute(name: 'age', value: 5, setAt: now)
      ]);
    });

    test('a reused holdout instance with a new iteration re-resolves',
        () async {
      final holdout =
          newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo);
      final context = await ready(contextDataOf([
        holdout
      ], [
        newExperiment(1, 'exp_reused', holdoutIds: [11])
      ]));

      expect(context.peekTreatment('exp_reused'), normalVariant);

      holdout
        ..iteration = 2
        ..seedHi = holdoutASeedHi
        ..seedLo = holdoutASeedLo;
      context.setData(contextDataOf([
        holdout
      ], [
        newExperiment(1, 'exp_reused', holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_reused'), 0);
      await expectPublished(context, [holdoutExposure(11, 'holdout_a', 0)]);
    });

    // JS keeps a cached override across a refresh that only changes the
    // experiment's unit type (holdoutSetMatches compares id and iteration),
    // so the holdout exposure already published is not repeated.
    test('an override keeps its holdouts when only the unit type changes',
        () async {
      final context = await readyWith(
          ContextConfig.create()
            ..setUnit('session_id', uid)
            ..setUnit('user_id', uidNotHeldOut)
            ..setOverride('exp_override_unit', 1),
          contextDataOf([
            newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
          ], [
            newExperiment(1, 'exp_override_unit', holdoutIds: [11])
          ]));

      expect(context.getTreatment('exp_override_unit'), 1);

      await refreshWith(
          context,
          contextDataOf([
            newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
          ], [
            newExperiment(1, 'exp_override_unit',
                unit: 'user_id', holdoutIds: [11])
          ]));

      expect(context.getTreatment('exp_override_unit'), 1);
      final event = await publish(context);
      expect(event.exposures, [
        exposure(1, 'exp_override_unit', 1, assigned: false, overridden: true),
        holdoutExposure(11, 'holdout_a', 0),
      ]);
    });

    // JS publishes the name from the covered assignment's pinned holdout
    // list (context.ts _triggerApplicableHoldoutExposures), so a rename that
    // keeps the iteration shows up on the next resolution.
    test('a holdout exposure carries the name of the pinned holdout', () async {
      final holdout =
          newHoldout(11, 'holdout_a', holdoutBSeedHi, holdoutBSeedLo);
      final context = await ready(contextDataOf([
        holdout
      ], [
        newExperiment(1, 'exp_rename', holdoutIds: [11])
      ]));
      logger.onExposure = (exposure) {
        if (exposure.id == 1) {
          holdout.name = 'renamed';
        }
      };

      expect(context.getTreatment('exp_rename'), normalVariant);
      await expectPublished(context, [
        exposure(1, 'exp_rename', normalVariant),
        holdoutExposure(11, 'renamed', 1),
      ]);
    });

    test('a same-iteration rename keeps the name the arm was resolved with',
        () async {
      ContextData data(String name) => contextDataOf([
            newHoldout(11, name, holdoutBSeedHi, holdoutBSeedLo)
          ], [
            newExperiment(1, 'exp_a', holdoutIds: [11]),
          ]);
      final context = await ready(data('h_old'));

      expect(context.peekTreatment('exp_a'), normalVariant);
      await refreshWith(context, data('h_new'));
      expect(context.getTreatment('exp_a'), normalVariant);

      await expectPublished(context, [
        exposure(1, 'exp_a', normalVariant),
        holdoutExposure(11, 'h_old', 1),
      ]);
    });

    test('a same-iteration rename reaches experiments resolved after it',
        () async {
      ContextData data(String name) => contextDataOf([
            newHoldout(11, name, holdoutBSeedHi, holdoutBSeedLo)
          ], [
            newExperiment(1, 'exp_a', holdoutIds: [11]),
            newExperiment(2, 'exp_b', holdoutIds: [11]),
          ]);
      final context = await ready(data('h_old'));

      expect(context.peekTreatment('exp_a'), normalVariant);
      await refreshWith(context, data('h_new'));
      expect(context.getTreatment('exp_b'), normalVariant);

      await expectPublished(context, [
        exposure(2, 'exp_b', normalVariant),
        holdoutExposure(11, 'h_new', 1),
      ]);
    });

    // JS keeps cached assignments across a refresh (_init(data, assignments))
    // and reuses an unassigned one for an experiment that is gone, so a
    // suppressed decision made while the experiment was live still publishes
    // its holdout exposure on the first exposing read.
    test(
        'a suppressed experiment removed by refresh keeps its holdout decision',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_removed', holdoutIds: [11])
      ]));

      expect(context.peekTreatment('exp_removed'), 0);
      await refreshWith(context, ContextData());

      expect(context.getTreatment('exp_removed'), 0);
      expect(context.getTreatment('exp_removed'), 0);
      await expectPublished(context, [holdoutExposure(11, 'holdout_a', 0)]);
    });

    test('a suppressed key with no other candidate reads the control value',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        withVariables(newExperiment(1, 'exp_only', holdoutIds: [11]), 'color')
      ]));

      expect(context.peekVariableValue('color', 'default'), 'control');
      expect(context.getVariableValue('color', 'default'), 'control');
      expect(context.getTreatment('exp_only'), 0);
      await expectPublished(context, [holdoutExposure(11, 'holdout_a', 0)]);
    });

    test('a refresh that removes coverage re-resolves the experiment',
        () async {
      final context = await ready(contextDataOf([
        newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
      ], [
        newExperiment(1, 'exp_coverage', holdoutIds: [11])
      ]));

      expect(context.getTreatment('exp_coverage'), 0);

      await refreshWith(context,
          ContextData(experiments: [newExperiment(1, 'exp_coverage')]));

      expect(context.getTreatment('exp_coverage'), normalVariant);
      await expectPublished(context, [
        holdoutExposure(11, 'holdout_a', 0),
        exposure(1, 'exp_coverage', normalVariant),
      ]);
    });

    test('a rule-won exposed assignment keeps one exposure across refreshes',
        () async {
      ContextData data() => contextDataOf([
            newHoldout(11, 'holdout_a', holdoutASeedHi, holdoutASeedLo)
          ], [
            newExperiment(1, 'exp_rule', holdoutIds: [11])
              ..assignmentRules = usRule
          ]);
      final context = await ready(data());
      context.setAttribute('country', 'US');

      expect(context.getTreatment('exp_rule'), 1);
      await refreshWith(context, data());
      expect(context.getTreatment('exp_rule'), 1);
      expect(context.getPendingCount(), 2);
    });
  });
}
