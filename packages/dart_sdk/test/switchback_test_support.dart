// Helpers shared by the switchback Context tests (java-sdk
// SwitchbackTestSupport and the fixtures of ContextSwitchbackTest).
import 'dart:async';
import 'dart:convert';

import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/context.dart';
import 'package:absmartly_dart/src/context_config.dart';
import 'package:absmartly_dart/src/context_data_provider.dart';
import 'package:absmartly_dart/src/context_event_logger.dart';
import 'package:absmartly_dart/src/context_publisher.dart';
import 'package:absmartly_dart/src/default_audience_deserializer.dart';
import 'package:absmartly_dart/src/default_context_event_serializer.dart';
import 'package:absmartly_dart/src/default_variable_parser.dart';
import 'package:absmartly_dart/src/internal/switchback_assigner.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:absmartly_dart/src/json/context_data.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:absmartly_dart/src/json/experiment_application.dart';
import 'package:absmartly_dart/src/json/experiment_variant.dart';
import 'package:absmartly_dart/src/json/exposure.dart';
import 'package:absmartly_dart/src/json/publish_event.dart';
import 'package:absmartly_dart/src/jsonexpr/json_expr.dart';

const String unitType = 'store_id';
const String uid = 'e791e240fcd3df7d238cfc285f475e8152fcc0ec';
// Hashing.hashUnit(uid): the MD5/base64url string the Collector's UnitHasher
// also produces.
const String uidHash = 'pAE3a1i5Drs5mKRNq56adA';

const int hour = 3600000;
const int day = 24 * hour;
// 2026-01-01T00:00:00Z, hour aligned.
const int anchor = 1767225600000;

const int seedHi = -5;
const int seedLo = -7;
final BigInt seed = (BigInt.from(seedHi) << 32) |
    (BigInt.from(seedLo) & BigInt.from(0xffffffff));

// The store unit's cluster value: attribute clusterPath, set on every default
// context.
const String clusterPath = 'store_key';
const String clusterKey = 'store-42';

int draw(String key, int periodIndex, int arms, {BigInt? withSeed}) =>
    SwitchbackAssigner.assign(
        key, BigInt.from(periodIndex), withSeed ?? seed, arms);

class MutableClock extends Clock {
  MutableClock(this.now);

  int now;
  // When set, the next read returns this value once, then reads fall back to
  // `now`.
  int? nextRead;
  int reads = 0;

  @override
  int millis() {
    ++reads;
    final int? value = nextRead;
    if (value != null) {
      nextRead = null;
      return value;
    }
    return now;
  }
}

class RecordingPublisher implements ContextPublisher {
  final List<PublishEvent> events = [];

  @override
  Completer<void> publish(Context context, PublishEvent event) {
    events.add(event);
    return Completer<void>()..complete();
  }
}

class QueuedDataProvider implements ContextDataProvider {
  ContextData? next;
  int calls = 0;

  @override
  Completer<ContextData> getContextData() {
    ++calls;
    return Completer<ContextData>()..complete(next!);
  }
}

class ExposureCapture implements ContextEventLogger {
  final List<Exposure> exposures = [];

  @override
  void handleEvent(Context context, EventType type, dynamic data) {
    if (type == EventType.exposure && data is Exposure) {
      exposures.add(data);
    }
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

// Counts assignment-rule evaluations.
class CountingAudienceMatcher extends AudienceMatcher {
  CountingAudienceMatcher() : super(DefaultAudienceDeserializer());

  int ruleEvaluations = 0;

  @override
  RuleAction? evaluateParsedRules(
      List rules, String? environmentName, Map<String, dynamic>? attributes) {
    ruleEvaluations++;
    return super.evaluateParsedRules(rules, environmentName, attributes);
  }
}

Experiment switchback(int id, String name, int armCount, int periodMs) {
  return Experiment(
    id: id,
    name: name,
    unitType: unitType,
    iteration: 1,
    seedHi: seedHi,
    seedLo: seedLo,
    split: List<double>.filled(armCount, 1.0 / armCount),
    trafficSeedHi: 1,
    trafficSeedLo: 2,
    trafficSplit: [0.0, 1.0],
    fullOnVariant: 0,
    applications: [ExperimentApplication(name: 'website')],
    variants: [
      for (int i = 0; i < armCount; ++i)
        ExperimentVariant(
            name: String.fromCharCode(0x41 + i), config: '{"sb.arm":$i}')
    ],
    audienceStrict: false,
    audience: null,
    randomizationType: 'switchback',
    switchbackClusters: {unitType: clusterPath},
    switchbackStartAt: anchor,
    switchbackPeriodMs: periodMs,
    switchbackCarryoverDurationMs: 0,
    switchbackBurnInDurationMs: 0,
    switchbackBurnOutDurationMs: 0,
    switchbackDesignType: 'balanced_block',
    switchbackEstimand: 'global_average_treatment_effect',
  );
}

Experiment sb(int armCount, int periodMs) =>
    switchback(1, 'exp_sb', armCount, periodMs);

// The same experiment as a unit experiment, with no switchback fields.
Experiment asUnit(Experiment experiment) {
  experiment.randomizationType = null;
  experiment.switchbackClusters = null;
  experiment.switchbackStartAt = null;
  experiment.switchbackPeriodMs = null;
  return experiment;
}

ContextData dataOf(List<Experiment> experiments) =>
    ContextData(experiments: experiments);

Exposure exposure(int id, String name, int variant, int exposedAt,
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
        exposedAt: exposedAt,
        assigned: assigned,
        eligible: eligible,
        overridden: overridden,
        fullOn: fullOn,
        custom: custom,
        audienceMismatch: audienceMismatch,
        ruleOverride: ruleOverride);

String serialize(PublishEvent event) =>
    utf8.decode(DefaultContextEventSerializer().serialize(event)!);

// A context over [data] with [units], ready once its data future completes.
class Harness {
  Harness({int now = anchor}) : clock = MutableClock(now);

  final MutableClock clock;
  final RecordingPublisher publisher = RecordingPublisher();
  final QueuedDataProvider dataProvider = QueuedDataProvider();
  final ExposureCapture capture = ExposureCapture();

  Future<Context> create(ContextData data,
      {Map<String, Object>? units,
      Map<String, dynamic>? attributes,
      AudienceMatcher? audienceMatcher,
      bool clusterAttribute = true,
      String? application,
      String? environment}) async {
    final ContextConfig config = ContextConfig.create()..setPublishDelay(-1);
    config.setUnits(units ?? {unitType: uid});
    final Context context = Context.create(
        clock,
        config,
        Completer<ContextData>()..complete(data),
        dataProvider,
        publisher,
        DefaultVariableParser(),
        audienceMatcher ?? AudienceMatcher(DefaultAudienceDeserializer()),
        capture,
        application: application,
        environment: environment);
    if (clusterAttribute) {
      context.setAttribute(clusterPath, clusterKey);
    }
    if (attributes != null) {
      context.setAttributes(attributes);
    }
    await context.waitUntilReady();
    return context;
  }

  Future<void> refreshTo(Context context, List<Experiment> experiments) async {
    dataProvider.next = dataOf(experiments);
    await context.refresh();
  }

  Future<List<Exposure>> publishExposures(Context context) async {
    final int before = publisher.events.length;
    await context.publish();
    final List<Exposure> exposures = [];
    for (final event in publisher.events.sublist(before)) {
      exposures.addAll(event.exposures);
    }
    return exposures;
  }

  List<int> peekSchedule(Context context, String name, int periodMs, int n) {
    final List<int> result = [];
    for (int i = 0; i < n; ++i) {
      clock.now = anchor + i * periodMs;
      result.add(context.peekTreatment(name));
    }
    return result;
  }
}
