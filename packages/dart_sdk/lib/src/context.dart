import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'variable_parser.dart';
import 'package:collection/collection.dart';

import 'audience_matcher.dart';
import 'context_config.dart';
import 'context_data_provider.dart';
import 'context_publisher.dart';
import 'context_event_logger.dart';
import 'internal/context_counters.dart';
import 'internal/hashing/hashing.dart';
import 'internal/switchback_assigner.dart';
import 'internal/switchback_attribute_path.dart';
import 'internal/switchback_serving.dart';
import 'internal/variant_assigner.dart';
import 'java/time/clock.dart';
import 'json/attribute.dart';
import 'json/context_data.dart';
import 'json/context_holdout.dart';
import 'json/experiment.dart';
import 'json/experiment_variant.dart';
import 'json/exposure.dart';
import 'json/goal_achievement.dart';
import 'json/publish_event.dart';
import 'json/unit.dart';

class Context {
  factory Context.create(
      Clock clock,
      final ContextConfig config,
      final Completer<ContextData> dataFuture,
      final ContextDataProvider dataProvider,
      final ContextPublisher eventHandler,
      final VariableParser variableParser,
      AudienceMatcher audienceMatcher,
      ContextEventLogger? eventLogger,
      {String? application,
      String? environment}) {
    return Context(clock, config, dataFuture, dataProvider, eventHandler,
        variableParser, audienceMatcher, eventLogger,
        application: application, environment: environment);
  }

  Context(
      Clock clock,
      ContextConfig config,
      Completer<ContextData> dataFuture,
      ContextDataProvider dataProvider,
      ContextPublisher eventHandler,
      VariableParser variableParser,
      AudienceMatcher audienceMatcher,
      ContextEventLogger? eventLogger,
      {String? application,
      String? environment}) {
    clock_ = clock;

    publishDelay_ = config.getPublishDelay();
    refreshInterval_ = config.getRefreshInterval();
    eventHandler_ = eventHandler;
    dataProvider_ = dataProvider;
    variableParser_ = variableParser;
    audienceMatcher_ = audienceMatcher;
    eventLogger_ = eventLogger;

    // System attributes (the application and environment names configured on
    // the client) are always evaluated by audiences, no opt-in. The collector
    // attaches the same values to every exposure server-side, so nothing extra
    // is published. Skip null/empty values so a missing config leaves the key
    // out of the evaluation map.
    if ((application != null) && application.isNotEmpty) {
      _systemAttributes["application"] = application;
    }
    if ((environment != null) && environment.isNotEmpty) {
      _systemAttributes["environment"] = environment;
      _environmentName = environment;
    }

    setUnits(config.getUnits());
    setAttributes(config.getAttributes());
    setOverrides(config.getOverrides());
    setCustomAssignments(config.getCustomAssignments());

    readyFuture_ = Completer<void>();
    dataFuture.future.then((data) {
      setData(data);
      readyFuture_!.complete();
      readyFuture_ = null;

      logEvent(EventType.ready, data);

      if (getPendingCount() > 0) {
        setTimeout();
      }
    }).catchError((exception) {
      setDataFailed(exception);
      readyFuture_!.complete();
      readyFuture_ = null;
      logError(exception);
    });
  }

  bool isReady() {
    return data_ != null;
  }

  bool isFailed() {
    return failed_;
  }

  dynamic readyError() {
    return failedError_;
  }

  bool isClosed() {
    return closed_;
  }

  bool isClosing() {
    return !closed_ && closing_;
  }

  bool isFinalized() {
    return isClosed();
  }

  bool isFinalizing() {
    return isClosing();
  }

  Future<void> finalize() {
    return close();
  }

  Future<Context> waitUntilReady() async {
    if (isReady()) {
      return Future.value(this);
    }

    return readyFuture_!.future.then((_) {
      return this;
    });
  }

  List<String> getExperiments() {
    checkReady(false);

    return List.generate(
        data_!.experiments.length, (index) => data_!.experiments[index].name);
  }

  ContextData getData() {
    checkReady(false);

    return data_!;
  }

  void setOverride(final String experimentName, final int variant) {
    overrides_[experimentName] = variant;
  }

  int? getOverride(final String experimentName) {
    return overrides_[experimentName];
  }

  void setOverrides(Map<String, int> overrides) {
    for (final entry in overrides.entries) {
      setOverride(entry.key, entry.value);
    }
  }

  void setCustomAssignment(String experimentName, int variant) {
    checkNotClosed();

    cassignments_[experimentName] = variant;
  }

  int? getCustomAssignment(String experimentName) {
    return cassignments_[experimentName];
  }

  void setCustomAssignments(Map<String, int> customAssignments) {
    for (final entry in customAssignments.entries) {
      setCustomAssignment(entry.key, entry.value);
    }
  }

  /// Returns the UID as it was set: a [String] or a [num].
  Object? getUnit(final String unitType) {
    return units_[unitType];
  }

  /// Sets the UID of [unitType]. [uid] must be a [String] or a [num]; a
  /// number keeps its type (JS context.ts unit()).
  void setUnit(final String unitType, final Object uid) {
    checkNotClosed();

    Object value;
    if (uid is String) {
      value = uid.trim();
      if ((value as String).isEmpty) {
        throw Exception("Unit '$unitType' UID must not be blank.");
      }
    } else if (uid is num) {
      value = uid;
    } else {
      throw Exception("Unit '$unitType' must be a string or a number.");
    }

    final Object? previous = units_[unitType];
    if ((previous != null) && !(previous == value)) {
      throw Exception("Unit '$unitType' UID already set.");
    }

    units_[unitType] = value;

    _invalidateAssignmentsPinnedWithMissingUnit(unitType);
  }

  // A split rule resolved without its unit gave the experiment's no-unit
  // result, and a null holdout entry means a holdout could not be resolved
  // without it. Evict those so getAssignment() hashes the unit now; an exposed
  // one is kept, since re-resolving would queue a second, conflicting exposure
  // (JS context.ts _invalidateAssignmentsPinnedWithMissingUnit).
  //
  // A switchback resolved before any linked unit was set is re-resolved now
  // that one may be. A non-overridden one never published anything, so it is
  // dropped even if exposed (java-sdk Context.setUnit).
  void _invalidateAssignmentsPinnedWithMissingUnit(final String unitType) {
    assignmentCache_.removeWhere((_, assignment) {
      if (assignment._switchbackServing?.status == SwitchbackStatus.absent) {
        return !assignment.overridden || !assignment.exposed;
      }
      return assignment.unitType == unitType &&
          !assignment.exposed &&
          (assignment._isRuleMissingUnit ||
              (assignment._holdoutAssignments?.contains(null) ?? false));
    });
  }

  Map<String, Object> getUnits() {
    return Map.unmodifiable(units_);
  }

  void setUnits(Map<String, Object> units) {
    for (final entry in units.entries) {
      setUnit(entry.key, entry.value);
    }
  }

  dynamic getAttribute(final String name) {
    for (int i = attributes_.length; i-- > 0;) {
      final Attribute attr = attributes_[i];
      if (name == attr.name) {
        return attr.value;
      }
    }

    return null;
  }

  void setAttribute(String name, dynamic value) {
    checkNotClosed();

    attributes_
        .add(Attribute(name: name, value: value, setAt: clock_.millis()));
    attrsSeq_++;
  }

  Map<String, dynamic> getAttributes() {
    final Map<String, dynamic> result = {};

    for (final Attribute attr in attributes_) {
      result[attr.name] = attr.value;
    }
    return result;
  }

  void setAttributes(final Map<String, dynamic> attributes) {
    for (final entry in attributes.entries) {
      setAttribute(entry.key, entry.value);
    }
  }

  int getTreatment(final String experimentName) {
    checkReady(true);

    final Assignment assignment = getAssignment(experimentName);

    if (!assignment.exposed) {
      _triggerExposures(assignment);
    }

    return assignment.variant;
  }

  // A suppressed experiment publishes no exposure of its own; the holdouts
  // that cover it publish theirs (JS context.ts _triggerExposures). A
  // switchback the Collector records nothing for publishes nothing.
  void _triggerExposures(final Assignment assignment) {
    if (assignment._switchbackSilent) {
      assignment.exposed = true;
    } else if (!assignment._suppressed ||
        assignment.overridden ||
        assignment._ruleOverride) {
      queueExposure(assignment);
    } else {
      assignment.exposed = true;
    }

    final List<_HoldoutAssignment?>? holdoutAssignments =
        assignment._holdoutAssignments;
    if (holdoutAssignments != null) {
      _triggerHoldoutExposures(assignment._holdouts!, holdoutAssignments);
    }
  }

  // Fires the holdout decisions pinned when the assignment was resolved, not
  // a live re-resolution, so a refresh in between cannot publish a holdout
  // exposure from another epoch. Each holdout is exposed once per unit type
  // and iteration, in holdout id order.
  void _triggerHoldoutExposures(final List<ContextHoldout> holdouts,
      final List<_HoldoutAssignment?> holdoutAssignments) {
    for (int i = 0; i < holdoutAssignments.length; i++) {
      final _HoldoutAssignment? holdoutAssignment = holdoutAssignments[i];
      if (holdoutAssignment == null || holdoutAssignment.exposed) {
        continue;
      }
      holdoutAssignment.exposed = true;

      final Exposure exposure = Exposure(
          id: holdoutAssignment.id,
          name: holdouts[i].name,
          unit: holdoutAssignment.unitType,
          variant: holdoutAssignment.variant,
          exposedAt: clock_.millis(),
          assigned: true,
          eligible: true,
          overridden: false,
          fullOn: false,
          custom: false,
          audienceMismatch: false,
          ruleOverride: false);

      pendingCount_++;
      exposures_.add(exposure);

      logEvent(EventType.exposure, exposure);

      setTimeout();
    }
  }

  // A switchback exposure is stamped with the clock reading that selected its
  // period: analysis derives the period from exposedAt, so a later reading
  // could attribute this variant to the next period. Unit experiments read the
  // clock at enqueue time.
  void queueExposure(final Assignment assignment) {
    if (!assignment.exposed) {
      assignment.exposed = true;
      final Exposure exposure = Exposure(
          id: assignment.id,
          name: assignment.name,
          unit: assignment.unitType,
          variant: assignment.variant,
          exposedAt:
              assignment._switchback ? assignment._resolvedAt : clock_.millis(),
          assigned: assignment.assigned,
          eligible: assignment.eligible,
          overridden: assignment.overridden,
          fullOn: assignment.fullOn,
          custom: assignment.custom,
          audienceMismatch: assignment.audienceMismatch,
          ruleOverride: assignment._ruleOverride);

      pendingCount_++;
      exposures_.add(exposure);

      logEvent(EventType.exposure, exposure);

      setTimeout();
    }
  }

  int peekTreatment(final String experimentName) {
    checkReady(true);

    return getAssignment(experimentName).variant;
  }

  Map<String, List<String>> getVariableKeys() {
    checkReady(true);

    final Map<String, List<String>> variableKeys = <String, List<String>>{};

    indexVariables_.forEach((key, value) {
      final List<ExperimentVariables> keyExperimentVariables = value;
      final List<String> values = List.generate(keyExperimentVariables.length,
          (index) => keyExperimentVariables[index].data.name);
      variableKeys[key] = values;
    });
    return variableKeys;
  }

  Set<String> getCustomFieldKeys() {
    checkReady(true);

    final keys = <String>{};
    for (final experiment in data_!.experiments) {
      final fields = experiment.customFieldValues;
      if (fields != null) {
        for (final field in fields) {
          keys.add(field.name);
        }
      }
    }
    return keys;
  }

  dynamic getCustomFieldValue(final String experimentName, final String key) {
    checkReady(true);

    final experiment = index_[experimentName];
    if (experiment != null) {
      final fields = experiment.data.customFieldValues;
      if (fields != null) {
        for (final field in fields) {
          if (field.name == key) {
            switch (field.type) {
              case 'text':
              case 'string':
                return field.value;
              case 'number':
                return num.tryParse(field.value);
              case 'json':
                try {
                  if (field.value == 'null') return null;
                  if (field.value == '') return '';
                  return jsonDecode(field.value);
                } catch (e) {
                  logError(e);
                  return null;
                }
              case 'boolean':
                return field.value == 'true';
              default:
                logError(Exception(
                    "Unknown custom field type '${field.type}' for experiment '$experimentName' and key '$key' - you may need to upgrade to the latest SDK version"));
                return null;
            }
          }
        }
      }
    }
    return null;
  }

  String? getCustomFieldValueType(
      final String experimentName, final String key) {
    checkReady(true);

    final experiment = index_[experimentName];
    if (experiment != null) {
      final fields = experiment.data.customFieldValues;
      if (fields != null) {
        for (final field in fields) {
          if (field.name == key) {
            return field.type;
          }
        }
      }
    }
    return null;
  }

  Set<String> customFieldKeys() => getCustomFieldKeys();

  dynamic customFieldValue(final String experimentName, final String key) =>
      getCustomFieldValue(experimentName, key);

  String? customFieldValueType(final String experimentName, final String key) =>
      getCustomFieldValueType(experimentName, key);

  dynamic getVariableValue(final String key, final dynamic defaultValue) {
    checkReady(true);

    final Assignment? assignment = _getVariableAssignment(key, false);
    if (assignment != null) {
      // Queue exposure when assignment exists, regardless of whether key is in variables
      // This matches JavaScript SDK behavior - exposure is logged even when user
      // is not in traffic (eligible=false) to record that the variable was accessed
      if (!assignment.exposed) {
        _triggerExposures(assignment);
      }
      if (assignment.variables.containsKey(key)) {
        return assignment.variables[key];
      }
    }
    return defaultValue;
  }

  dynamic peekVariableValue(final String key, final dynamic defaultValue) {
    checkReady(true);

    final Assignment? assignment = getVariableAssignment(key);
    if (assignment != null) {
      if (assignment.variables.containsKey(key)) {
        return assignment.variables[key];
      }
    }
    return defaultValue;
  }

  void track(final String goalName, final Map<String, dynamic>? properties) {
    checkNotClosed();

    final GoalAchievement achievement = GoalAchievement(
      name: goalName,
      achievedAt: clock_.millis(),
      properties: properties == null ? null : Map.of(properties),
    );

    pendingCount_++;
    achievements_.add(achievement);

    logEvent(EventType.goal, achievement);

    setTimeout();
  }

  Future<void> publish() {
    checkReady(true);

    return flush();
  }

  int getPendingCount() {
    return pendingCount_;
  }

  Future<void> refresh() async {
    checkReady(true);

    // A failed context is not recovered by a refresh (JS context.ts _refresh).
    if (failed_) {
      return;
    }

    if (!refreshing_) {
      refreshing_ = true;
      final Completer<void> refreshing = Completer<void>();
      refreshFuture_ = refreshing;

      void fail(dynamic error) {
        refreshing_ = false;
        refreshing.completeError(error);
        logError(error);
      }

      try {
        dataProvider_.getContextData().future.then((data) {
          try {
            setData(data);
          } catch (error) {
            fail(error);
            return;
          }
          refreshing_ = false;
          refreshing.complete();
          logEvent(EventType.refresh, data);
        }, onError: fail);
      } catch (error) {
        fail(error);
      }
    }

    if (refreshFuture_ != null) {
      return refreshFuture_!.future;
    }

    return Future.value();
  }

  Future<void> close() {
    if (closed_) {
      return Future.value();
    }

    final Completer<void>? inProgress = closingFuture_;
    if (inProgress != null) {
      return inProgress.future;
    }

    clearRefreshTimer();

    // A flush may be in flight with the queue already drained, so only take
    // the fast path when nothing is pending and nothing is being published.
    if (pendingCount_ == 0 && flushFuture_ == null) {
      closed_ = true;
      logEvent(EventType.finalize, null);
      return Future.value();
    }

    final Completer<void> closing = Completer<void>();
    closingFuture_ = closing;
    closing_ = true;

    flush().then((_) {
      closing_ = false;
      closingFuture_ = null;
      closed_ = true;
      closing.complete();
      logEvent(EventType.finalize, null);
    }).catchError((exception) {
      // A failed final publish leaves the context open with its events
      // queued, so close() can be retried (JS context.ts _finalize).
      closing_ = false;
      closingFuture_ = null;
      setRefreshTimer();
      closing.completeError(exception);
    });

    return closing.future;
  }

  Future<void> flush() {
    clearTimeout();

    // One publish at a time: a second caller waits for the in-flight one and
    // then flushes whatever was queued meanwhile (JS context.ts _flushPromise).
    final Future<void>? inFlight = flushFuture_;
    if (inFlight != null) {
      return inFlight.then((_) => flush(), onError: (_) => flush());
    }

    if (pendingCount_ == 0) {
      return Future.value();
    }

    if (failed_) {
      logError(Exception(
          "Discarding ${exposures_.length} exposures and ${achievements_.length} goals because context failed to initialize"));
      exposures_.clear();
      achievements_.clear();
      pendingCount_ = 0;
      return Future.value();
    }

    // Snapshot and drain the queue before the async publish, so events
    // queued while it is in flight are not resent and a failed batch can be
    // put back in front of them.
    final List<Exposure> exposures = List.of(exposures_);
    final List<GoalAchievement> achievements = List.of(achievements_);
    final int eventCount = pendingCount_;
    exposures_.clear();
    achievements_.clear();
    pendingCount_ = 0;

    final Completer<void> result = Completer<void>();

    void restore(dynamic error) {
      exposures_.insertAll(0, exposures);
      achievements_.insertAll(0, achievements);
      pendingCount_ += eventCount;
      logError(error);
      result.completeError(error);
    }

    try {
      final List<Unit> units = [];
      for (var entry in units_.entries) {
        units.add(Unit(
            type: entry.key,
            uid: utf8.decode(getUnitHash(entry.key, entry.value))));
      }

      final PublishEvent event = PublishEvent(
        hashed: true,
        units: units,
        publishedAt: clock_.millis(),
        exposures: exposures,
        goals: achievements,
        attributes: attributes_.toList(),
      );

      eventHandler_.publish(this, event).future.then((_) {
        result.complete();
        logEvent(EventType.publish, event);
      }, onError: restore);
    } catch (error) {
      restore(error);
    }

    final Future<void> future = result.future;
    flushFuture_ = future;
    future.then((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(flushFuture_, future)) {
        flushFuture_ = null;
      }
    });
    return future;
  }

  void checkNotClosed() {
    if (closed_) {
      throw Exception("ABsmartly Context is finalized.");
    } else if (closing_) {
      throw Exception("ABsmartly Context is finalizing.");
    }
  }

  void checkReady(final bool expectNotClosed) {
    if (!isReady()) {
      throw Exception("ABsmartly Context is not yet ready.");
    } else if (expectNotClosed) {
      checkNotClosed();
    }
  }

  bool experimentMatches(
      final Experiment experiment, final Assignment assignment) {
    return experiment.id == assignment.id &&
        experiment.unitType == assignment.unitType &&
        experiment.iteration == assignment.iteration &&
        experiment.fullOnVariant == assignment.fullOnVariant &&
        const ListEquality()
            .equals(experiment.trafficSplit, assignment.trafficSplit);
  }

  // experimentMatches plus the switchback grid. A switchback serves under the
  // unit its clusters select, so its unit identity is the cluster map
  // compared by _switchbackConfigMatches. On the legacy path a unitType change
  // is part of the switchback identity, so it starts a new generation and the
  // stale epoch's slots are dropped before they get here.
  bool _experimentMatches(
      final ExperimentVariables entry, final Assignment assignment) {
    if (!entry._switchback) {
      return experimentMatches(entry.data, assignment) &&
          !assignment._switchback;
    }
    final Experiment experiment = entry.data;
    return experiment.id == assignment.id &&
        experiment.iteration == assignment.iteration &&
        experiment.fullOnVariant == assignment.fullOnVariant &&
        const ListEquality()
            .equals(experiment.trafficSplit, assignment.trafficSplit) &&
        _switchbackConfigMatches(entry, assignment);
  }

  // Grid identity: a change to any of these re-maps periods or clusters to
  // variants. Carryover and burn windows are analysis-only and deliberately
  // excluded, as are seed and split, which do not invalidate unit assignments
  // either.
  static bool _switchbackConfigMatches(
      final ExperimentVariables entry, final Assignment assignment) {
    if (entry._switchback != assignment._switchback) {
      return false;
    }
    if (!assignment._switchback) {
      return true;
    }
    final Experiment experiment = entry.data;
    return Experiment.switchbackClustersEqual(
            experiment.switchbackClusters, assignment._switchbackClusters) &&
        const ListEquality().equals(experiment.switchbackClusterValues,
            assignment._switchbackClusterValues) &&
        experiment.switchbackStartAt == assignment._switchbackStartAt &&
        experiment.switchbackPeriodMs == assignment._switchbackPeriodMs &&
        experiment.switchbackDesignType == assignment._switchbackDesignType;
  }

  static void _pinSwitchbackConfig(
      final Assignment assignment, final ExperimentVariables entry) {
    assignment._switchback = entry._switchback;
    if (entry._switchback) {
      final Experiment experiment = entry.data;
      assignment._switchbackClusters = experiment.switchbackClusters;
      assignment._switchbackClusterValues = experiment.switchbackClusterValues;
      assignment._switchbackStartAt = experiment.switchbackStartAt;
      assignment._switchbackPeriodMs = experiment.switchbackPeriodMs;
      assignment._switchbackDesignType = experiment.switchbackDesignType;
    }
  }

  // Whether the Collector's Registry can serve this switchback's schedule: a
  // start that is set, hour aligned and in [0, 10000-01-01) (it is used as
  // served, never rounded), a period > 0 and at least two arms. An unservable
  // schedule only replaces the draw: assignment rules and full-on still apply.
  static bool _switchbackScheduleServable(final Experiment experiment) {
    final int? startAt = experiment.switchbackStartAt;
    final int? periodMs = experiment.switchbackPeriodMs;
    if (startAt == null ||
        startAt < 0 ||
        startAt >= _switchbackMaxAnchorMs ||
        startAt % _switchbackAnchorAlignmentMs != 0) {
      return false;
    }
    if (periodMs == null || periodMs <= 0) {
      return false;
    }
    return experiment.split.length >= 2;
  }

  // periodIndex = floorDiv(now - switchbackStartAt, switchbackPeriodMs), as
  // the Collector computes it. Null before the start, for an unservable
  // schedule and for a cluster map taking the legacy path. now - startAt is
  // non-negative and below 2^53 for any real clock, so the division is exact
  // on the web too.
  static int? _currentSwitchbackPeriod(
      final ExperimentVariables entry, final int now) {
    ContextCounters.switchbackPeriodLookups++;
    if (!entry._switchbackServable || entry._switchbackSourcePaths == null) {
      return null;
    }
    final int startAt = entry.data.switchbackStartAt!;
    if (now < startAt) {
      return null;
    }
    return (now - startAt) ~/ entry.data.switchbackPeriodMs!;
  }

  // Port of the Collector's ContextAPI.switchbackServing at `now` (see
  // SwitchbackServing). The cluster is resolved whether or not the schedule
  // can be drawn now (pre-start or an unservable schedule), as the Collector
  // does, so assignment rules and full-on still see the serving unit. A
  // missing, empty or unreadable cluster map takes the Collector's legacy
  // path: an ineligible control under a unit of the declared unitType, if set.
  SwitchbackServing _resolveSwitchbackServing(
      final ExperimentVariables entry, final int now) {
    ContextCounters.switchbackServingResolutions++;
    final List<SwitchbackUnit> units = [
      for (final MapEntry<String, Object> unit in units_.entries)
        SwitchbackUnit(unit.key, unit.value)
    ];
    final List<SwitchbackAttributePath>? paths = entry._switchbackSourcePaths;
    if (paths == null) {
      return SwitchbackServing.legacy(entry.data.unitType, units);
    }
    return SwitchbackServing.resolve(
        entry._switchbackSourceTypes!,
        paths,
        entry.data.switchbackClusterValues,
        units, (SwitchbackAttributePath path) {
      final Attribute? attribute = _latestAttribute(path.rootKey, now);
      return attribute != null ? path.resolveAttribute(attribute.value) : null;
    });
  }

  // The slot's serving resolution: reused when this slot already read it
  // (unless no linked unit was set then), otherwise read now.
  SwitchbackServing _switchbackServing(final ExperimentVariables entry,
      final SwitchbackServing? cached, final int now) {
    if (cached != null && cached.status != SwitchbackStatus.absent) {
      return cached;
    }
    return _resolveSwitchbackServing(entry, now);
  }

  // The unit type a switchback with no serving unit is recorded under (an
  // override is still exposed): the first linked type of a readable cluster
  // map, otherwise the declared unitType the legacy path reads.
  static String _switchbackFallbackUnitType(final ExperimentVariables entry) {
    return entry._switchbackSourcePaths != null
        ? entry._switchbackSourceTypes!.first
        : entry.data.unitType;
  }

  // The attribute the Collector records with an exposure at `now`
  // (ContextAPI.extractAttributes): among attributes set at or before now
  // whose trimmed name matches, the greatest setAt wins and a tie goes to the
  // one set last. System attributes are not attributes set on the context, so
  // a path never reads them.
  Attribute? _latestAttribute(final String name, final int now) {
    Attribute? selected;
    for (final Attribute attribute in attributes_) {
      if (attribute.setAt <= now &&
          name == attribute.name.trim() &&
          (selected == null || attribute.setAt >= selected.setAt)) {
        selected = attribute;
      }
    }
    return selected;
  }

  // The seed of the switchback draw: (seedHi << 32) | (seedLo & 0xffffffff),
  // as a signed 64-bit value.
  static BigInt _switchbackSeed(final Experiment experiment) {
    return (BigInt.from(experiment.seedHi).toSigned(32) << 32) |
        (BigInt.from(experiment.seedLo) & _uint32Mask);
  }

  // Switchback identity: id, iteration, the ordered cluster map, the cluster
  // value allow-list, startAt, periodMs and design, i.e. every input to the
  // period grid and the cluster key, plus unitType when either side takes the
  // legacy path. Seed, split and analysis-only fields are excluded. installed
  // is always a switchback; an absent or unit-experiment previous definition
  // has no identity to keep.
  static bool _sameSwitchbackIdentity(final ExperimentVariables? previous,
      final ExperimentVariables installed) {
    if (previous == null || !previous._switchback) {
      return false;
    }
    final Experiment a = previous.data;
    final Experiment b = installed.data;
    return a.id == b.id &&
        a.iteration == b.iteration &&
        Experiment.switchbackClustersEqual(
            a.switchbackClusters, b.switchbackClusters) &&
        const ListEquality()
            .equals(a.switchbackClusterValues, b.switchbackClusterValues) &&
        a.switchbackStartAt == b.switchbackStartAt &&
        a.switchbackPeriodMs == b.switchbackPeriodMs &&
        a.switchbackDesignType == b.switchbackDesignType &&
        ((previous._switchbackSourcePaths != null &&
                installed._switchbackSourcePaths != null) ||
            a.unitType == b.unitType);
  }

  // An epoch is stale once the installed definition is absent, not
  // switchback, or carries a different generation. Every identity transition,
  // including an intermediate unit or removed state that was never looked up,
  // assigns a fresh generation, so a stale epoch never matches a later
  // identical definition.
  bool _isSwitchbackEpochStale(
      final String experimentName, final ExperimentVariables? entry) {
    if (_switchbackEpochs.isEmpty) {
      return false;
    }
    final _SwitchbackEpoch? epoch = _switchbackEpochs[experimentName];
    return epoch != null &&
        (entry == null ||
            !entry._switchback ||
            epoch.generation != entry._switchbackGeneration);
  }

  // Drops every slot of the epoch, the bare-name slot included.
  void _dropSwitchbackEpoch(final String experimentName) {
    final _SwitchbackEpoch? epoch = _switchbackEpochs.remove(experimentName);
    if (epoch != null) {
      for (final int period in epoch.periods) {
        assignmentCache_.remove(_switchbackCacheKey(experimentName, period));
      }
      assignmentCache_.remove(experimentName);
    }
  }

  static String _switchbackCacheKey(
          final String experimentName, final int periodIndex) =>
      '$experimentName$_switchbackKeySeparator$periodIndex';

  // Records a switchback resolution under the current epoch. At most
  // _switchbackRetainedPeriods period indices are kept; the lowest index other
  // than periodIndex is evicted, so the entry just installed always survives.
  // Exposure dedup therefore holds only within the retained window:
  // re-entering an evicted period (clock rewind) creates one new assignment
  // for it, which then stays cached like any other.
  void _retainSwitchbackPeriod(final String experimentName,
      final ExperimentVariables entry, final int? periodIndex) {
    final _SwitchbackEpoch epoch = _switchbackEpochs[experimentName] ??=
        _SwitchbackEpoch(entry._switchbackGeneration);
    if (periodIndex == null) {
      return;
    }
    if (!epoch.periods.contains(periodIndex)) {
      epoch.periods.add(periodIndex);
      epoch.periods.sort();
    }
    while (epoch.periods.length > _switchbackRetainedPeriods) {
      int evicted = epoch.periods.first;
      if (evicted == periodIndex) {
        evicted = epoch.periods[1];
      }
      epoch.periods.remove(evicted);
      assignmentCache_.remove(_switchbackCacheKey(experimentName, evicted));
    }
  }

  // Port of the Collector's switchback branch of ContextAPI (R33), as in
  // java-sdk Context.resolveSwitchbackAssignment: the serving resolution
  // decides whether the experiment applies and under which unit. For an
  // eligible cluster the Collector's assignExperiment order follows:
  // assignment rules (a split rule randomizes over the serving unit),
  // audience, full-on, traffic (sticky on the serving unit's hash), then
  // custom assignment and the switchback draw over the raw cluster key.
  // Holdouts never apply to a switchback. Only the draw needs a current
  // period: pre-start or with an unservable schedule the result is an
  // ineligible control that records nothing, while rules, audience and
  // full-on are unaffected.
  void _resolveSwitchbackAssignment(
      final Assignment assignment,
      final ExperimentVariables entry,
      final SwitchbackServing? cachedServing,
      final int? custom,
      final int? periodIndex,
      final int now) {
    final Experiment data = entry.data;
    _pinSwitchbackConfig(assignment, entry);
    assignment._ruleKey = entry._ruleKey;
    assignment._customAssignment = custom;
    assignment.id = data.id;
    assignment.iteration = data.iteration;
    assignment.trafficSplit = data.trafficSplit;
    assignment.fullOnVariant = data.fullOnVariant;

    final SwitchbackServing serving =
        _switchbackServing(entry, cachedServing, now);
    assignment._switchbackServing = serving;
    assignment.variant = 0;
    if (serving.status == SwitchbackStatus.absent) {
      // No linked unit: the experiment does not apply, like an unset unit
      // type.
      assignment.unitType = _switchbackFallbackUnitType(entry);
      assignment.eligible = false;
      assignment._switchbackSilent = true;
      return;
    }

    final SwitchbackUnit unit = serving.unit!;
    assignment.unitType = unit.type;
    assignment.assigned = true;
    if (serving.status == SwitchbackStatus.ineligible) {
      assignment.eligible = false;
      assignment._switchbackSilent = true;
      return;
    }

    final _RuleResult? rule = entry._ruleKey.isNotEmpty
        ? _resolveRule(entry, _getAttributesMap(), false, unitType: unit.type)
        : null;
    assignment._ruleVariant = rule?.variant;
    assignment._isRuleMissingUnit = rule?.isMissingUnit ?? false;
    if (rule != null) {
      // Recorded like a unit experiment's rule win: ruleOverride set, not
      // "assigned".
      assignment.assigned = false;
      assignment._ruleOverride = true;
      assignment.variant = rule.variant;
      return;
    }

    if (data.audience != null && data.audience!.isNotEmpty) {
      final Result? match =
          audienceMatcher_.evaluate(data.audience!, _getAttributesMap());
      if (match != null) {
        assignment.audienceMismatch = !match.get();
      }
    }
    if (data.audienceStrict && assignment.audienceMismatch) {
      // Recorded like a unit experiment's strict mismatch: control,
      // audienceMismatch, not "assigned".
      assignment.assigned = false;
      return;
    }
    if (data.fullOnVariant != 0) {
      assignment.variant = data.fullOnVariant;
      assignment.fullOn = true;
      return;
    }
    if (periodIndex == null) {
      // Pre-start or an unservable schedule: no draw, so control and no
      // exposure.
      assignment.eligible = false;
      assignment._switchbackSilent = true;
      return;
    }

    final VariantAssigner assigner =
        getVariantAssigner(unit.type, getUnitHash(unit.type, unit.uid));
    if (assigner.assign(
            data.trafficSplit, data.trafficSeedHi, data.trafficSeedLo) !=
        1) {
      // A traffic miss on an eligible cluster is recorded, as for a unit
      // experiment.
      assignment.eligible = false;
      return;
    }
    if (custom != null) {
      assignment.variant = custom;
      assignment.custom = true;
      return;
    }
    assignment.variant = SwitchbackAssigner.assign(serving.clusterKey!,
        BigInt.from(periodIndex), _switchbackSeed(data), data.split.length);
  }

  // System attributes (application, environment) first, then user attributes
  // overlaid on top, so a user-set value always wins, even one set after an
  // assignment was cached (the attrsSeq_ bump invalidates it). This map is what
  // audience filters and rule conditions evaluate against. Built only when one
  // of them needs it, and once per attrsSeq_ (JS _getAttributesMap). Readers
  // must not modify it.
  Map<String, dynamic> _getAttributesMap() {
    final Map<String, dynamic>? cached = _attrsMapCache;
    if (cached != null && _attrsMapCacheSeq == attrsSeq_) {
      return cached;
    }
    ContextCounters.attributesMapBuilds++;
    final Map<String, dynamic> attrs = {};
    attrs.addAll(_systemAttributes);
    for (final Attribute attr in attributes_) {
      attrs[attr.name] = attr.value;
    }
    _attrsMapCache = attrs;
    _attrsMapCacheSeq = attrsSeq_;
    return attrs;
  }

  // Everything a rule's outcome depends on besides the attributes and units:
  // a refresh that changes any of it re-resolves the rules. Built once per
  // experiment when its data is installed, never per read.
  String _ruleKey(final Experiment experiment) {
    final String? rules = experiment.assignmentRules;
    if (rules == null || rules.isEmpty) {
      return "";
    }
    ContextCounters.ruleKeyBuilds++;
    return "$rules:$_environmentName:${experiment.variants.length}:"
        "${experiment.seedHi}:${experiment.seedLo}";
  }

  // The variant of the first assignment rule that matches, or null when none
  // does or the matched rule cannot be applied: an assign variant out of
  // bounds, or a split whose value count differs from the variant count. A
  // split rule matched while the experiment's unit is missing gives the
  // experiment's own no-unit result (its full-on variant, otherwise 0).
  // A switchback's split rule randomizes over its serving unit [unitType]
  // (the Collector resets its assigner to the serving unit).
  _RuleResult? _resolveRule(final ExperimentVariables entry,
      final Map<String, dynamic> attrs, final bool unitPinnedMissing,
      {String? unitType}) {
    final Experiment experiment = entry.data;
    final int variantCount = experiment.variants.length;
    // Parsed once per installed experiment; invalid rules are cached as an
    // empty list so they are not parsed again until the next refresh.
    final List rules = entry._rules ??=
        audienceMatcher_.parseRules(experiment.assignmentRules ?? "") ??
            const [];
    final RuleAction? action =
        audienceMatcher_.evaluateParsedRules(rules, _environmentName, attrs);
    if (action == null) {
      return null;
    }

    final int? variant = action.variant;
    if (variant != null) {
      return (variant >= 0 && variant < variantCount)
          ? _RuleResult(variant, false)
          : null;
    }

    final List<double> split = action.split!;
    if (split.length != variantCount) {
      return null;
    }

    final String ruleUnitType = unitType ?? experiment.unitType;
    final Object? uid = unitPinnedMissing ? null : units_[ruleUnitType];
    if (uid == null) {
      return _RuleResult(experiment.fullOnVariant, true);
    }

    final VariantAssigner assigner =
        getVariantAssigner(ruleUnitType, getUnitHash(ruleUnitType, uid));
    return _RuleResult(
        assigner.assign(split, experiment.seedHi, experiment.seedLo), false);
  }

  // Only the (id, iteration) of each holdout, in order: a same-iteration seed
  // or split edit must not force a duplicate exposure (JS context.ts
  // holdoutSetMatches). Compared against the values recorded when the
  // assignment was resolved, so a holdout instance edited and installed again
  // is still seen as changed.
  static bool _holdoutSetMatches(
      final ExperimentVariables experiment, final Assignment assignment) {
    final List<ContextHoldout>? fresh = experiment._holdouts;
    final List<int>? pinned = assignment._holdoutIdentity;
    if (fresh == null || pinned == null || fresh.length * 2 != pinned.length) {
      return false;
    }
    for (int i = 0; i < fresh.length; i++) {
      if (fresh[i].id != pinned[2 * i] ||
          fresh[i].iteration != pinned[2 * i + 1]) {
        return false;
      }
    }
    return true;
  }

  // Arm 0 always holds the experiment out; in a 3-arm holdout, arm 1 holds out
  // experiments that are not full-on. The arm count is the holdout's split
  // length (JS context.ts isHeldOutBy).
  static bool _isHeldOutBy(
      final int holdoutVariant, final int armCount, final int fullOnVariant) {
    if (holdoutVariant == 0) {
      return true;
    }
    if (armCount == 3 && holdoutVariant == 1) {
      return fullOnVariant == 0;
    }
    return false;
  }

  // A holdout's arm is hashed with the covered experiment's unit type, cached
  // per (holdout, unit type) and kept while the holdout's iteration is
  // unchanged, so a same-iteration seed or split edit neither re-randomizes
  // nor re-exposes. Null while the unit is not set (JS context.ts
  // _getHoldoutAssignment).
  _HoldoutAssignment? _getHoldoutAssignment(
      final ContextHoldout live, final String unitType) {
    ContextCounters.holdoutAssignmentLookups++;
    // `live` is always the installed definition: setData rebuilds every
    // experiment's holdout list, so no stale reference reaches here.
    final (int, String) cacheKey = (live.id, unitType);
    final _HoldoutAssignment? cached = _holdoutAssignmentCache[cacheKey];
    if (cached != null && cached.iteration == live.iteration) {
      return cached;
    }

    final Object? uid = units_[unitType];
    if (uid == null) {
      return null;
    }

    final VariantAssigner assigner =
        getVariantAssigner(unitType, getUnitHash(unitType, uid));
    final _HoldoutAssignment assignment = _HoldoutAssignment(
        live.id,
        live.iteration,
        unitType,
        assigner.assign(live.split, live.seedHi, live.seedLo),
        live.split.length);
    _holdoutAssignmentCache[cacheKey] = assignment;
    return assignment;
  }

  bool audienceMatches(
      final Experiment experiment, final Assignment assignment) {
    final ExperimentVariables? entry = index_[experiment.name];
    return _audienceMatches(
        entry != null && identical(entry.data, experiment)
            ? entry
            : (ExperimentVariables()
              ..data = experiment
              .._ruleKey = _ruleKey(experiment)),
        assignment);
  }

  bool _audienceMatches(
      final ExperimentVariables entry, final Assignment assignment) {
    final Experiment experiment = entry.data;
    final String key = entry._ruleKey;
    final String cachedKey = assignment._ruleKey ?? "";
    bool ruleKeyChanged = false;
    if (!identical(key, cachedKey)) {
      ContextCounters.ruleKeyComparisons++;
      if (key == cachedKey) {
        assignment._ruleKey = key;
      } else {
        ruleKeyChanged = true;
      }
    }

    if (ruleKeyChanged &&
        key.isEmpty &&
        (assignment._ruleVariant != null || assignment._ruleOverride)) {
      return false;
    }

    if (attrsSeq_ > assignment.attrsSeq || ruleKeyChanged) {
      final bool hasAudience = !assignment._ruleOverride &&
          experiment.audience != null &&
          experiment.audience!.isNotEmpty;

      if (key.isNotEmpty) {
        // An exposed split resolved without its unit keeps resolving as if the
        // unit were still missing, so a unit set afterwards cannot switch the
        // variant the user already saw.
        final bool unitPinnedMissing =
            assignment.exposed && assignment._isRuleMissingUnit;
        final _RuleResult? rule = _resolveRule(
            entry, _getAttributesMap(), unitPinnedMissing,
            unitType: assignment._switchback ? assignment.unitType : null);
        if (rule?.variant != assignment._ruleVariant) {
          return false;
        }
        assignment._isRuleMissingUnit = rule?.isMissingUnit ?? false;
      }

      if (hasAudience) {
        final Result? match = audienceMatcher_.evaluate(
            experiment.audience!, _getAttributesMap());
        // An indeterminate (null) result keeps the cached flag.
        final bool newAudienceMismatch =
            match != null ? !match.get() : assignment.audienceMismatch;
        if (newAudienceMismatch != assignment.audienceMismatch) {
          return false;
        }
      }
      assignment._ruleKey = key;
      assignment.attrsSeq = attrsSeq_;
    }
    return true;
  }

  Assignment getAssignment(final String experimentName) {
    // A unit experiment's cached slot is checked as it was before
    // switchbacks, so a payload without switchbacks costs nothing extra per
    // read. A unit slot never belongs to a switchback epoch.
    // The slot it rejects is not checked again.
    final ExperimentVariables? experiment = index_[experimentName];
    Assignment? rejected;
    if (experiment == null || !experiment._switchback) {
      final Assignment? cached = assignmentCache_[experimentName];
      if (cached != null && !cached._switchback) {
        if (_isUnitAssignmentCurrent(cached, cassignments_[experimentName],
            overrides_[experimentName], experiment)) {
          return cached;
        }
        rejected = cached;
      }
    }
    return _getAssignment(experimentName, null, rejected: rejected);
  }

  // [now] is the caller's clock reading, shared by every switchback a
  // variable-key lookup resolves; read here when null.
  Assignment _getAssignment(final String experimentName, int? now,
      {Assignment? rejected}) {
    ContextCounters.slowAssignmentLookups++;
    final int? custom = cassignments_[experimentName];
    final int? override = overrides_[experimentName];
    final ExperimentVariables? experiment = getExperiment(experimentName);

    // A switchback reads the clock once per resolution: the reading selects
    // the period slot and stamps the exposure (see queueExposure). Each
    // period has its own slot, keyed by name + U+001F + period index; the
    // bare name holds a unit experiment, or a switchback before its anchor or
    // with an unservable schedule.
    int? periodIndex;
    String cacheKey = experimentName;
    if (experiment != null && experiment._switchback) {
      now ??= clock_.millis();
      periodIndex = _currentSwitchbackPeriod(experiment, now);
      if (periodIndex != null) {
        cacheKey = _switchbackCacheKey(experimentName, periodIndex);
      }
    }
    if (_isSwitchbackEpochStale(experimentName, experiment)) {
      _dropSwitchbackEpoch(experimentName);
    }

    final Assignment? cached = assignmentCache_[cacheKey];
    if (cached != null && !identical(cached, rejected)) {
      if (_isAssignmentCurrent(cached, custom, override, experiment)) {
        cached._resolvedAt = now ?? 0;
        return cached;
      }
    }

    // cache miss or out-dated
    final Assignment assignment = Assignment();
    assignment.name = experimentName;
    assignment.eligible = true;
    assignment._resolvedAt = now ?? 0;
    // Within one period slot the serving unit and cluster key are read once:
    // a slot replaced in the same epoch, e.g. after setAttribute changed the
    // audience, keeps its cluster.
    final SwitchbackServing? cachedServing = cached?._switchbackServing;

    // Resolved for overrides too: the holdouts still publish their exposures.
    final List<ContextHoldout>? holdouts = experiment?._holdouts;
    if (holdouts != null) {
      ContextCounters.coveredAssignmentResolutions++;
      final ExperimentVariables covered = experiment!;
      final String unitType = covered.data.unitType;
      final List<_HoldoutAssignment?> holdoutAssignments =
          List<_HoldoutAssignment?>.generate(holdouts.length,
              (index) => _getHoldoutAssignment(holdouts[index], unitType),
              growable: false);
      assignment._holdouts = holdouts;
      assignment._holdoutIdentity = [
        for (final ContextHoldout holdout in holdouts) ...[
          holdout.id,
          holdout.iteration
        ]
      ];
      assignment._holdoutAssignments = holdoutAssignments;
      for (final _HoldoutAssignment? holdoutAssignment in holdoutAssignments) {
        if (holdoutAssignment != null &&
            _isHeldOutBy(holdoutAssignment.variant, holdoutAssignment.armCount,
                covered.data.fullOnVariant)) {
          assignment._suppressed = true;
          break;
        }
      }
    }

    if (override != null) {
      if (experiment != null && experiment._switchback) {
        assignment.id = experiment.data.id;
        _pinSwitchbackConfig(assignment, experiment);
        final SwitchbackServing serving =
            _switchbackServing(experiment, cachedServing, now!);
        assignment._switchbackServing = serving;
        assignment.unitType =
            serving.unit?.type ?? _switchbackFallbackUnitType(experiment);
      } else if (experiment != null) {
        assignment.id = experiment.data.id;
        assignment.unitType = experiment.data.unitType;
      }

      assignment.overridden = true;
      assignment.variant = override;
    } else {
      if (experiment != null && experiment._switchback) {
        _resolveSwitchbackAssignment(
            assignment, experiment, cachedServing, custom, periodIndex, now!);
      } else if (experiment != null) {
        final String unitType = experiment.data.unitType;

        final String key = experiment._ruleKey;
        assignment._ruleKey = key;
        final _RuleResult? rule = key.isNotEmpty
            ? _resolveRule(experiment, _getAttributesMap(), false)
            : null;
        assignment._ruleVariant = rule?.variant;
        assignment._isRuleMissingUnit = rule?.isMissingUnit ?? false;

        if (rule == null &&
            !assignment._suppressed &&
            experiment.data.audience != null &&
            experiment.data.audience!.isNotEmpty) {
          final Result? match = audienceMatcher_.evaluate(
              experiment.data.audience!, _getAttributesMap());
          if (match != null) {
            assignment.audienceMismatch = !match.get();
          }
        }

        if (rule != null) {
          // A matching assignment rule is an explicit, author-specified
          // assignment: it wins over audience, traffic, full-on and custom
          // assignments, and is flagged ruleOverride (excluded from analysis).
          assignment.variant = rule.variant;
          assignment._ruleOverride = true;
        } else if (assignment._suppressed) {
          // A holdout wins over audience, traffic, full-on and custom
          // assignments; only an override or a matching rule beats it.
          assignment.variant = 0;
        } else if (experiment.data.audienceStrict &&
            assignment.audienceMismatch) {
          assignment.variant = 0;
        } else if (experiment.data.fullOnVariant == 0) {
          final Object? uid = units_[experiment.data.unitType];
          if (uid != null) {
            final Uint8List unitHash = getUnitHash(unitType, uid);

            final VariantAssigner assigner =
                getVariantAssigner(unitType, unitHash);

            final bool eligible = assigner.assign(
                    experiment.data.trafficSplit,
                    experiment.data.trafficSeedHi,
                    experiment.data.trafficSeedLo) ==
                1;
            if (eligible) {
              if (custom != null) {
                assignment.variant = custom;
                assignment.custom = true;
              } else {
                assignment.variant = assigner.assign(experiment.data.split,
                    experiment.data.seedHi, experiment.data.seedLo);
              }
            } else {
              assignment.eligible = false;
              assignment.variant = 0;
            }
            assignment.assigned = true;
          }
        } else {
          assignment.assigned = true;
          assignment.variant = experiment.data.fullOnVariant;
          assignment.fullOn = true;
        }

        assignment.unitType = unitType;
        assignment.id = experiment.data.id;
        assignment.iteration = experiment.data.iteration;
        assignment.trafficSplit = experiment.data.trafficSplit;
        assignment.fullOnVariant = experiment.data.fullOnVariant;
      }
    }

    if ((experiment != null) &&
        assignment.variant >= 0 &&
        (assignment.variant < experiment.data.variants.length)) {
      assignment.variables = experiment.variables[assignment.variant] ?? {};
    }

    assignment.attrsSeq = attrsSeq_;
    assignmentCache_[cacheKey] = assignment;
    if (experiment != null && experiment._switchback) {
      _retainSwitchbackPeriod(experimentName, experiment, periodIndex);
    }

    return assignment;
  }

  // The pre-switchback cache-hit check, for a unit experiment's slot.
  bool _isUnitAssignmentCurrent(final Assignment assignment, final int? custom,
      final int? override, final ExperimentVariables? experiment) {
    if (override != null) {
      return assignment.overridden &&
          assignment.variant == override &&
          (experiment == null ||
              identical(experiment._holdouts, assignment._holdouts) ||
              _holdoutSetMatches(experiment, assignment));
    } else if (experiment == null) {
      return !assignment.assigned && !assignment._ruleOverride;
    } else if ((custom == null) ||
        assignment._ruleOverride ||
        assignment._suppressed ||
        custom == assignment.variant) {
      return experimentMatches(experiment.data, assignment) &&
          _audienceMatches(experiment, assignment) &&
          (identical(experiment._holdouts, assignment._holdouts) ||
              _holdoutSetMatches(experiment, assignment));
    }
    return false;
  }

  bool _isAssignmentCurrent(final Assignment assignment, final int? custom,
      final int? override, final ExperimentVariables? experiment) {
    if (override != null) {
      // The switchback identity is revalidated too, so a grid change
      // re-resolves an overridden slot like any other.
      return assignment.overridden &&
          assignment.variant == override &&
          (experiment == null
              ? !assignment._switchback
              : _switchbackConfigMatches(experiment, assignment) &&
                  (identical(experiment._holdouts, assignment._holdouts) ||
                      _holdoutSetMatches(experiment, assignment)));
    } else if (experiment == null) {
      // previously not-running experiment
      return !assignment.assigned && !assignment._ruleOverride;
    } else if (assignment._switchback
        // A switchback slot is current for the custom assignment it was
        // resolved with (java-sdk): its variant is often not the custom one
        // (control, full-on, a rule), and must not be re-exposed for it.
        ? (assignment._ruleOverride || custom == assignment._customAssignment)
        : ((custom == null) ||
            assignment._ruleOverride ||
            assignment._suppressed ||
            custom == assignment.variant)) {
      // A suppressed assignment is forced to variant 0 and a matching rule
      // wins over a custom assignment, so a custom mismatch is not
      // staleness.
      // A switchback that did not resolve an eligible cluster never
      // consulted its rules or audience (the Collector evaluates them only
      // for a cluster key), so a change to either cannot make it stale.
      return _experimentMatches(experiment, assignment) &&
          ((assignment._switchback &&
                  assignment._switchbackServing?.status !=
                      SwitchbackStatus.eligible) ||
              _audienceMatches(experiment, assignment)) &&
          (identical(experiment._holdouts, assignment._holdouts) ||
              _holdoutSetMatches(experiment, assignment));
    }
    return false;
  }

  Assignment? getVariableAssignment(final String key) {
    return _getVariableAssignment(key, true);
  }

  // The first candidate the unit is assigned to, overridden into or given by a
  // rule. A suppressed candidate never wins over one of those, but the first
  // one is the fallback (its control values) when nothing else wins. Unless
  // peeking, every holdout-covered candidate passed over is exposed (JS
  // context.ts _resolveVariableValue).
  Assignment? _getVariableAssignment(final String key, final bool peek) {
    final List<ExperimentVariables>? keyExperimentVariables =
        getVariableExperiments(key);

    if (keyExperimentVariables != null) {
      Assignment? suppressedFallback;
      // Every switchback on the key resolves at one clock reading.
      final int? now = _hasSwitchbacks ? clock_.millis() : null;
      for (ExperimentVariables experimentVariables in keyExperimentVariables) {
        final Assignment assignment =
            now != null && experimentVariables._switchback
                ? _getAssignment(experimentVariables.data.name, now)
                : getAssignment(experimentVariables.data.name);
        if (assignment.assigned ||
            assignment.overridden ||
            assignment._ruleOverride) {
          // The caller exposes the winner and then its holdouts.
          return assignment;
        }
        // A covered candidate passed over is exposed like JS does it: its
        // own exposure (unless suppressed) and its holdouts'. Marking it
        // exposed also keeps a later setUnit from re-randomizing it.
        if (!peek &&
            assignment._holdoutAssignments != null &&
            !assignment.exposed) {
          _triggerExposures(assignment);
        }
        if (assignment._suppressed) {
          suppressedFallback ??= assignment;
        }
      }
      return suppressedFallback;
    }
    return null;
  }

  ExperimentVariables? getExperiment(final String experimentName) {
    return index_[experimentName];
  }

  List<ExperimentVariables>? getVariableExperiments(final String key) {
    return indexVariables_[key];
  }

  Uint8List getUnitHash(final String unitType, final Object unitUID) {
    return hashedUnits_[unitType] ??
        (hashedUnits_[unitType] = Hashing.hashUnitValue(unitUID));
  }

  VariantAssigner getVariantAssigner(
      final String unitType, final Uint8List unitHash) {
    return assigners_[unitType] ??
        (assigners_[unitType] = VariantAssigner(unitHash));
  }

  void setTimeout() {
    // A negative publish delay disables the automatic publish.
    if (isReady() && publishDelay_ >= 0) {
      timeout_ ??= Timer(Duration(milliseconds: publishDelay_), () {
        // The failure is already reported through the event logger and the
        // events stay queued for the next publish.
        flush().catchError((_) {});
      });
    }
  }

  void clearTimeout() {
    if (timeout_ != null) {
      timeout_!.cancel();
      timeout_ = null;
    }
  }

  void setRefreshTimer() {
    if ((refreshInterval_ > 0) &&
        (refreshTimer_ == null) &&
        !closing_ &&
        !closed_) {
      refreshTimer_ =
          Timer.periodic(Duration(milliseconds: refreshInterval_), (timer) {
        // Refresh failures are reported through the event logger.
        refresh().catchError((_) {});
      });
    }
  }

  void clearRefreshTimer() {
    if (refreshTimer_ != null) {
      refreshTimer_!.cancel();
      refreshTimer_ = null;
    }
  }

  void setData(final ContextData data) {
    final Map<String, ExperimentVariables> index = {};
    final Map<String, List<ExperimentVariables>> indexVariables = {};

    // Only holdouts with a split can be served (JS context.ts _init).
    final Map<int, ContextHoldout> holdoutsById = {};
    for (final ContextHoldout holdout in data.holdouts) {
      if (holdout.split.isNotEmpty) {
        holdoutsById[holdout.id] = holdout;
      }
    }

    for (Experiment experiment in data.experiments) {
      final ExperimentVariables experimentVariables = ExperimentVariables();
      experimentVariables.data = experiment;
      if (experiment.randomizationType == _randomizationSwitchback) {
        // Holdouts never apply to a switchback.
        experimentVariables._switchback = true;
        final Map<String, String?>? clusters = experiment.switchbackClusters;
        experimentVariables._switchbackSourcePaths =
            SwitchbackServing.sourcePaths(clusters);
        experimentVariables._switchbackSourceTypes =
            clusters == null ? null : List.unmodifiable(clusters.keys);
        experimentVariables._switchbackServable =
            _switchbackScheduleServable(experiment);
      } else if (holdoutsById.isNotEmpty) {
        experimentVariables._holdouts =
            _resolveHoldouts(experiment.holdoutIds, holdoutsById);
      }
      // An unchanged key keeps the previous String, so cached assignments
      // still match it by identity and reads never compare rule contents.
      final String ruleKey = _ruleKey(experiment);
      final String? previousKey = index_[experiment.name]?._ruleKey;
      experimentVariables._ruleKey =
          (previousKey != null && previousKey == ruleKey)
              ? previousKey
              : ruleKey;
      for (ExperimentVariant variant in experiment.variants) {
        if ((variant.config != null) && variant.config!.isNotEmpty) {
          final Map<String, dynamic>? variables = variableParser_.parse(
              this, experiment.name, variant.name, variant.config!);

          variables?.forEach((key, value) {
            List<ExperimentVariables>? keyExperimentVariables =
                indexVariables[key];
            if (keyExperimentVariables == null) {
              keyExperimentVariables = [];
              indexVariables[key] = keyExperimentVariables;
            }

            if (!keyExperimentVariables.contains(experimentVariables)) {
              int insertAt = 0;
              for (int i = 0; i < keyExperimentVariables.length; i++) {
                if (keyExperimentVariables[i].data.id <
                    experimentVariables.data.id) {
                  insertAt = i + 1;
                } else {
                  break;
                }
              }
              keyExperimentVariables.insert(insertAt, experimentVariables);
            }
          });

          experimentVariables.variables.add(variables);
        } else {
          experimentVariables.variables.add({});
        }
      }

      index[experiment.name] = experimentVariables;
    }

    // A switchback keeps its previous generation only while its identity is
    // unchanged; otherwise it gets a fresh one, which drops its cached slots
    // lazily on its next resolution.
    for (final ExperimentVariables installed in index.values) {
      if (installed._switchback) {
        final ExperimentVariables? previous = index_[installed.data.name];
        installed._switchbackGeneration =
            _sameSwitchbackIdentity(previous, installed)
                ? previous!._switchbackGeneration
                : ++_switchbackGenerationCounter;
      }
    }

    index_ = index;
    indexVariables_ = indexVariables;
    data_ = data;
    _hasSwitchbacks = index.values.any((entry) => entry._switchback);

    assignmentCache_.removeWhere((experimentName, assignment) {
      // Switchback slots are revalidated on their next resolution, which
      // keeps a slot's cluster key when only its traffic or rules changed.
      if (assignment.overridden || assignment._switchback) {
        return false;
      }
      final ExperimentVariables? experiment = index[experimentName];
      if (experiment == null) {
        return assignment.assigned || assignment._ruleOverride;
      }
      return !_experimentMatches(experiment, assignment);
    });

    setRefreshTimer();
  }

  // The holdouts covering an experiment, sorted by id without duplicates;
  // unknown ids are ignored. Null when none applies.
  static List<ContextHoldout>? _resolveHoldouts(final List<int>? holdoutIds,
      final Map<int, ContextHoldout> holdoutsById) {
    if (holdoutIds == null || holdoutIds.isEmpty) {
      return null;
    }
    final List<ContextHoldout> resolved = [];
    for (final int holdoutId in holdoutIds) {
      final ContextHoldout? holdout = holdoutsById[holdoutId];
      if (holdout == null) {
        continue;
      }
      int insertAt = resolved.length;
      bool duplicate = false;
      for (int i = 0; i < resolved.length; i++) {
        if (resolved[i].id == holdoutId) {
          duplicate = true;
          break;
        }
        if (resolved[i].id > holdoutId) {
          insertAt = i;
          break;
        }
      }
      if (!duplicate) {
        resolved.insert(insertAt, holdout);
      }
    }
    return resolved.isEmpty ? null : List.unmodifiable(resolved);
  }

  void setDataFailed(exception) {
    index_ = {};
    indexVariables_ = {};
    data_ = ContextData();
    failed_ = true;
    failedError_ = exception;
  }

  // A throwing event logger must not change control flow (JS context.ts
  // _logEvent/_logError swallow observer exceptions).
  void logEvent(EventType event, dynamic data) {
    try {
      eventLogger_?.handleEvent(this, event, data);
    } catch (_) {}
  }

  void logError(error) {
    logEvent(EventType.error, error);
  }

  late Clock clock_;
  int publishDelay_ = 100;
  int refreshInterval_ = 0;
  late ContextPublisher eventHandler_;
  late ContextDataProvider dataProvider_;
  late VariableParser variableParser_;
  late AudienceMatcher audienceMatcher_;
  late ContextEventLogger? eventLogger_;
  String? _environmentName;
  final Map<String, Object> units_ = {};
  bool failed_ = false;
  dynamic failedError_;
  ContextData? data_;
  Map<String, ExperimentVariables> index_ = {};
  Map<String, List<ExperimentVariables>> indexVariables_ = {};

  final Map<String, Uint8List> hashedUnits_ = {};
  final Map<String, VariantAssigner> assigners_ = {};
  final Map<String, Assignment> assignmentCache_ = {};
  final Map<(int, String), _HoldoutAssignment> _holdoutAssignmentCache = {};
  final Map<String, _SwitchbackEpoch> _switchbackEpochs = {};
  int _switchbackGenerationCounter = 0;
  // Whether the installed data has a switchback experiment.
  bool _hasSwitchbacks = false;

  static const String _randomizationSwitchback = 'switchback';
  static const String _switchbackKeySeparator = '\u001f';
  static const int _switchbackRetainedPeriods = 2;
  // The Collector's switchback anchor bounds (Registry): an anchor must be
  // hour aligned and in [0, 10000-01-01T00:00:00Z).
  static const int _switchbackAnchorAlignmentMs = 3600000;
  static const int _switchbackMaxAnchorMs = 253402300800000;
  static final BigInt _uint32Mask = BigInt.from(0xffffffff);

  final List<Exposure> exposures_ = [];
  final List<GoalAchievement> achievements_ = [];
  final List<Attribute> attributes_ = [];
  final Map<String, dynamic> _systemAttributes = {};
  Map<String, dynamic>? _attrsMapCache;
  int _attrsMapCacheSeq = 0;
  final Map<String, int> overrides_ = {};
  final Map<String, int> cassignments_ = {};
  int pendingCount_ = 0;
  int attrsSeq_ = 0;
  bool closing_ = false;
  bool closed_ = false;
  bool refreshing_ = false;
  Completer<void>? readyFuture_;
  Completer<void>? closingFuture_;
  Completer<void>? refreshFuture_;
  Future<void>? flushFuture_;
  Timer? timeout_;
  Timer? refreshTimer_;
}

class ExperimentVariables {
  late Experiment data;
  List<Map<String, dynamic>?> variables = [];
  // Rule key of [data], set when installed, and its rules, parsed on first
  // use. setData installs new entries, so neither outlives its rules.
  String _ruleKey = "";
  List? _rules;
  // The holdouts covering [data], sorted by id; null when none applies.
  List<ContextHoldout>? _holdouts;
  // Set for a switchback experiment (randomizationType "switchback").
  bool _switchback = false;
  // switchbackClusters split in declared order: the linked unit types and
  // their parsed paths. Paths are null when the map is missing, empty or
  // unreadable: the legacy path.
  List<String>? _switchbackSourceTypes;
  List<SwitchbackAttributePath>? _switchbackSourcePaths;
  bool _switchbackServable = false;
  // Carried over from the previous install while the switchback identity is
  // unchanged, otherwise a fresh value.
  int _switchbackGeneration = 0;
}

// Lifecycle of one switchback experiment's cache slots: the bare-name slot
// (pre-anchor or an unservable grid) and its period slots, all created under
// one switchback generation. Indices from different generations are never
// compared: a changed start or period length re-maps them.
class _SwitchbackEpoch {
  _SwitchbackEpoch(this.generation);

  final int generation;
  // Sorted ascending; at most _switchbackRetainedPeriods entries.
  final List<int> periods = [];
}

class Assignment {
  int id = 0;
  int iteration = 0;
  int fullOnVariant = 0;
  late String name;
  String? unitType;
  List<double> trafficSplit = [];
  int variant = 0;
  bool assigned = false;
  bool overridden = false;
  bool eligible = false;
  bool fullOn = false;
  bool custom = false;
  bool audienceMismatch = false;
  bool _ruleOverride = false;
  int? _ruleVariant;
  String? _ruleKey;
  bool _isRuleMissingUnit = false;
  // Held out by a covering holdout: variant 0, no exposure of its own.
  bool _suppressed = false;
  // The covering holdouts and their arms when this was resolved; an arm is
  // null when the unit was not set.
  List<ContextHoldout>? _holdouts;
  // The (id, iteration) pairs of [_holdouts] when this was resolved.
  List<int>? _holdoutIdentity;
  List<_HoldoutAssignment?>? _holdoutAssignments;
  Map<String, dynamic> variables = {};
  bool exposed = false;
  int attrsSeq = 0;
  // Switchback grid this assignment was resolved under; compared by
  // _switchbackConfigMatches.
  bool _switchback = false;
  Map<String, String?>? _switchbackClusters;
  List<String>? _switchbackClusterValues;
  int? _switchbackStartAt;
  int? _switchbackPeriodMs;
  String? _switchbackDesignType;
  // The serving resolution read for this slot (cluster key and serving
  // unit); read once per slot.
  SwitchbackServing? _switchbackServing;
  // Set for a switchback resolution the Collector records nothing for: no
  // linked unit, or an ineligible cluster (no value, disagreement, filtered
  // value, unservable or pre-start).
  bool _switchbackSilent = false;
  // The custom assignment a switchback slot was resolved with.
  int? _customAssignment;
  // The clock reading of the latest resolution that returned this switchback
  // slot; its exposure is stamped with it.
  int _resolvedAt = 0;
}

/// Test seam: how the cached switchback slot for [experimentName] at the
/// clock's current reading resolved, or null when nothing is cached for it.
/// [applies] is whether the switchback has a linked unit, i.e. whether the
/// Collector lists an assignment. Not exported from the package.
({
  String? unitType,
  bool assigned,
  bool eligible,
  bool fullOn,
  bool ruleOverride,
  bool silent,
  bool applies,
})? switchbackResolutionForTest(
    final Context context, final String experimentName) {
  final ExperimentVariables? experiment = context.getExperiment(experimentName);
  final int? period = experiment != null && experiment._switchback
      ? Context._currentSwitchbackPeriod(experiment, context.clock_.millis())
      : null;
  final Assignment? assignment = context.assignmentCache_[period == null
      ? experimentName
      : Context._switchbackCacheKey(experimentName, period)];
  if (assignment == null) {
    return null;
  }
  return (
    unitType: assignment.unitType,
    assigned: assignment.assigned,
    eligible: assignment.eligible,
    fullOn: assignment.fullOn,
    ruleOverride: assignment._ruleOverride,
    silent: assignment._switchbackSilent,
    applies: assignment._switchbackServing != null &&
        assignment._switchbackServing!.status != SwitchbackStatus.absent,
  );
}

class _RuleResult {
  _RuleResult(this.variant, this.isMissingUnit);

  final int variant;
  final bool isMissingUnit;
}

class _HoldoutAssignment {
  _HoldoutAssignment(
      this.id, this.iteration, this.unitType, this.variant, this.armCount);

  final int id;
  final int iteration;
  final String unitType;
  final int variant;
  // The split length `variant` was hashed against: a same-iteration refresh
  // can change the live split without re-randomizing.
  final int armCount;
  bool exposed = false;
}
