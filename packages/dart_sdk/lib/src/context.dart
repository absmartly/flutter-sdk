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
import 'internal/unit_values.dart';
import 'internal/hashing/hashing.dart';
import 'internal/variant_assigner.dart';
import 'java/time/clock.dart';
import 'json/attribute.dart';
import 'json/context_data.dart';
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

    final Map<String, String> configUnits = config.getUnits();
    setUnits(configUnits);
    // Numeric UIDs reach setUnits() in their string form, as in 2.1, so a
    // subclass overriding setUnits(Map<String, String>) still works; keep the
    // numbers they were set as for hashing.
    for (final unitType in configUnits.keys) {
      final Object? uid = unitValue(configUnits, unitType);
      if (uid is num && units_[unitType] == uid.toString()) {
        _setUnitValue(unitType, uid);
      }
    }
    setAttributes(config.getAttributes());
    setOverrides(config.getOverrides());
    setCustomAssignments(config.getCustomAssignments());

    readyFuture_ = Completer<void>();
    dataFuture.future.then((data) {
      if (!_refreshInstalled) {
        setData(data);
      }
      _completeReady();

      logEvent(EventType.ready, data_);

      if (!_refreshInstalled && getPendingCount() > 0) {
        setTimeout();
      }
    }).catchError((exception) {
      if (!_refreshInstalled) {
        setDataFailed(exception);
      }
      _completeReady();
      logError(exception);
    });
  }

  void _completeReady() {
    final Completer<void>? ready = readyFuture_;
    readyFuture_ = null;
    if (ready != null && !ready.isCompleted) {
      ready.complete();
    }
  }

  bool isReady() {
    return data_ != null;
  }

  bool isFailed() {
    return failed_;
  }

  bool isClosed() {
    return closed_;
  }

  bool isClosing() {
    return !closed_ && closing_;
  }

  Future<Context> waitUntilReady() async {
    final Completer<void>? ready = readyFuture_;
    if (isReady() || ready == null) {
      return Future.value(this);
    }

    return ready.future.then((_) {
      return this;
    });
  }

  List<String> getExperiments() {
    checkReady(true);

    return List.generate(
        data_!.experiments.length, (index) => data_!.experiments[index].name);
  }

  ContextData getData() {
    checkReady(true);

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

  /// The UID of [unitType] as a string. A numeric UID is returned in its
  /// `toString()` form; [ContextExtensions.getUnitValue] returns it as set.
  String? getUnit(final String unitType) {
    return units_[unitType];
  }

  /// Sets the UID of [unitType]. [uid] is a [String] or a [num]; a number
  /// keeps its type for hashing (JS context.ts unit()).
  void setUnit(final String unitType, covariant final Object uid) {
    checkNotClosed();

    if (uid is! String && uid is! num) {
      throw Exception("Unit '$unitType' must be a string or a number.");
    }
    final Object? previous = _unitValue(unitType);
    // Compared with the UID as passed, before trimming, as in 2.1.
    if ((previous != null) && !(previous == uid)) {
      throw Exception("Unit $unitType already set.");
    }

    final Object value = uid is String ? uid.trim() : uid;

    if (value is String && value.isEmpty) {
      throw Exception("Unit $unitType UID must not be blank.");
    }

    _setUnitValue(unitType, value);

    _invalidateAssignmentsPinnedWithMissingUnit(unitType);
  }

  // A split rule resolved without its unit gave the experiment's no-unit
  // result. Evict it so getAssignment() hashes the unit now; an exposed one is
  // kept, since re-resolving would queue a second, conflicting exposure.
  void _invalidateAssignmentsPinnedWithMissingUnit(final String unitType) {
    assignmentCache_.removeWhere((_, assignment) =>
        assignment.unitType == unitType &&
        !assignment.exposed &&
        assignment._isRuleMissingUnit);
  }

  /// A copy of the units, numeric UIDs in their `toString()` form.
  Map<String, String> getUnits() {
    return Map<String, String>.of(units_);
  }

  Object? _unitValue(final String unitType) => unitValue(units_, unitType);

  void _setUnitValue(final String unitType, final Object uid) =>
      setUnitValue(units_, unitType, uid);

  void setUnits(Map<String, String> units) {
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
    _attrsSeq++;
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
      queueExposure(assignment);
    }

    return assignment.variant;
  }

  void queueExposure(final Assignment assignment) {
    if (!assignment.exposed) {
      assignment.exposed = true;
      final Exposure exposure = Exposure(
          id: assignment.id,
          name: assignment.name,
          unit: assignment.unitType,
          variant: assignment.variant,
          exposedAt: clock_.millis(),
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

  dynamic getVariableValue(final String key, final dynamic defaultValue) {
    checkReady(true);

    final Assignment? assignment = getVariableAssignment(key);
    if (assignment != null) {
      // Queue exposure when assignment exists, regardless of whether key is in variables
      // This matches JavaScript SDK behavior - exposure is logged even when user
      // is not in traffic (eligible=false) to record that the variable was accessed
      if (!assignment.exposed) {
        queueExposure(assignment);
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
    checkNotClosed();

    return flush();
  }

  int getPendingCount() {
    return pendingCount_;
  }

  Future<void> refresh() async {
    checkNotClosed();

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
          // The initial load failed while this refresh was in flight: a
          // failed context stays failed, as a refresh started after the
          // failure would (2.1 kept it failed too).
          if (failed_) {
            refreshing_ = false;
            refreshing.complete();
            return;
          }
          final bool wasReady = isReady();
          try {
            setData(data);
            _refreshInstalled = true;
          } catch (error) {
            fail(error);
            return;
          }
          refreshing_ = false;
          refreshing.complete();
          logEvent(EventType.refresh, data);
          // This refresh made the context ready before the initial fetch
          // settled: events queued before ready are due now. The ready future
          // still completes when the initial fetch settles, so the ready and
          // error events keep their 2.1 order.
          if (!wasReady && getPendingCount() > 0) {
            setTimeout();
          }
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
    if (pendingCount_ == 0 && _flushFuture == null) {
      closed_ = true;
      logEvent(EventType.close, null);
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
      logEvent(EventType.close, null);
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
    final Future<void>? inFlight = _flushFuture;
    if (inFlight != null) {
      return inFlight.then((_) => flush(), onError: (_) => flush());
    }

    if (pendingCount_ == 0) {
      return Future.value();
    }

    // A context whose data failed to load has nothing to publish the events
    // against, so they are dropped (as in 2.1).
    if (failed_) {
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
            uid: utf8.decode(getUnitHash(
                entry.key, Hashing.hashInput(_unitValue(entry.key)!)))));
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
    _flushFuture = future;
    future.then((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_flushFuture, future)) {
        _flushFuture = null;
      }
    });
    return future;
  }

  void checkNotClosed() {
    if (closed_) {
      throw Exception("ABSmartly Context is closed");
    } else if (closing_) {
      throw Exception("ABSmartly Context is closing");
    }
  }

  void checkReady(final bool expectNotClosed) {
    if (!isReady()) {
      throw Exception("ABSmartly Context is not yet ready");
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

  // System attributes (application, environment) first, then user attributes
  // overlaid on top, so a user-set value always wins, even one set after an
  // assignment was cached (the attrsSeq_ bump invalidates it). This map is what
  // audience filters and rule conditions evaluate against. Built only when one
  // of them needs it, and once per attrsSeq_ (JS _getAttributesMap). Readers
  // must not modify it.
  Map<String, dynamic> _getAttributesMap() {
    final Map<String, dynamic>? cached = _attrsMapCache;
    if (cached != null && _attrsMapCacheSeq == _attrsSeq) {
      return cached;
    }
    ContextCounters.attributesMapBuilds++;
    final Map<String, dynamic> attrs = {};
    attrs.addAll(_systemAttributes);
    for (final Attribute attr in attributes_) {
      attrs[attr.name] = attr.value;
    }
    _attrsMapCache = attrs;
    _attrsMapCacheSeq = _attrsSeq;
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
  _RuleResult? _resolveRule(final ExperimentVariables entry,
      final Map<String, dynamic> attrs, final bool unitPinnedMissing) {
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

    final String unitType = experiment.unitType;
    final Object? uid = unitPinnedMissing ? null : _unitValue(unitType);
    if (uid == null) {
      return _RuleResult(experiment.fullOnVariant, true);
    }

    final VariantAssigner assigner = getVariantAssigner(
        unitType, getUnitHash(unitType, Hashing.hashInput(uid)));
    return _RuleResult(
        assigner.assign(split, experiment.seedHi, experiment.seedLo), false);
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

    if (_attrsSeq > assignment._attrsSeq || ruleKeyChanged) {
      final bool hasAudience = !assignment._ruleOverride &&
          experiment.audience != null &&
          experiment.audience!.isNotEmpty;

      if (key.isNotEmpty) {
        // An exposed split resolved without its unit keeps resolving as if the
        // unit were still missing, so a unit set afterwards cannot switch the
        // variant the user already saw.
        final bool unitPinnedMissing =
            assignment.exposed && assignment._isRuleMissingUnit;
        final _RuleResult? rule =
            _resolveRule(entry, _getAttributesMap(), unitPinnedMissing);
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
      assignment._attrsSeq = _attrsSeq;
    }
    return true;
  }

  Assignment getAssignment(final String experimentName) {
    Assignment? assignment = assignmentCache_[experimentName];
    final int? custom = cassignments_[experimentName];
    final int? override = overrides_[experimentName];
    final ExperimentVariables? experiment = getExperiment(experimentName);

    if (assignment != null) {
      if (override != null) {
        if (assignment.overridden && assignment.variant == override) {
          // override up-to-date
          return assignment;
        }
      } else if (experiment == null) {
        if (!assignment.assigned && !assignment._ruleOverride) {
          // previously not-running experiment
          return assignment;
        }
      } else if (assignment._ruleOverride ||
          (custom == null) ||
          custom == assignment.variant) {
        // A matching rule wins over a custom assignment, so a custom mismatch
        // is not staleness.
        if (experimentMatches(experiment.data, assignment) &&
            _audienceMatches(experiment, assignment)) {
          // assignment up-to-date
          return assignment;
        }
      }
    }

    // cache miss or out-dated
    assignment = Assignment();
    assignment.name = experimentName;
    assignment.eligible = true;

    if (override != null) {
      if (experiment != null) {
        assignment.id = experiment.data.id;
        assignment.unitType = experiment.data.unitType;
      }

      assignment.overridden = true;
      assignment.variant = override;
    } else {
      if (experiment != null) {
        final String unitType = experiment.data.unitType;

        final String key = experiment._ruleKey;
        assignment._ruleKey = key;
        final _RuleResult? rule = key.isNotEmpty
            ? _resolveRule(experiment, _getAttributesMap(), false)
            : null;
        assignment._ruleVariant = rule?.variant;
        assignment._isRuleMissingUnit = rule?.isMissingUnit ?? false;

        if (rule == null &&
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
        } else if (experiment.data.audienceStrict &&
            assignment.audienceMismatch) {
          assignment.variant = 0;
        } else if (experiment.data.fullOnVariant == 0) {
          final Object? uid = _unitValue(experiment.data.unitType);
          if (uid != null) {
            // A String, so a 2.1 getUnitHash(String, String) override works.
            final Uint8List unitHash =
                getUnitHash(unitType, Hashing.hashInput(uid));

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

    assignment._attrsSeq = _attrsSeq;
    assignmentCache_[experimentName] = assignment;

    return assignment;
  }

  Assignment? getVariableAssignment(final String key) {
    final List<ExperimentVariables>? keyExperimentVariables =
        getVariableExperiments(key);

    if (keyExperimentVariables != null) {
      for (ExperimentVariables experimentVariables in keyExperimentVariables) {
        final Assignment assignment =
            getAssignment(experimentVariables.data.name);
        if (assignment.assigned ||
            assignment.overridden ||
            assignment._ruleOverride) {
          return assignment;
        }
      }
    }
    return null;
  }

  ExperimentVariables? getExperiment(final String experimentName) {
    return index_[experimentName];
  }

  List<ExperimentVariables>? getVariableExperiments(final String key) {
    return indexVariables_[key];
  }

  // The hash is computed once per unit type and kept, as in 2.1: every
  // assignment and every publish of a context uses the same unit identity,
  // even if the UID is later rewritten through units_.
  Uint8List getUnitHash(final String unitType, covariant final Object unitUID) {
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

    for (Experiment experiment in data.experiments) {
      final ExperimentVariables experimentVariables = ExperimentVariables();
      experimentVariables.data = experiment;
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

    index_ = index;
    indexVariables_ = indexVariables;
    data_ = data;

    assignmentCache_.removeWhere((experimentName, assignment) {
      if (assignment.overridden) {
        return false;
      }
      final ExperimentVariables? experiment = index[experimentName];
      if (experiment == null) {
        return assignment.assigned || assignment._ruleOverride;
      }
      return !experimentMatches(experiment.data, assignment);
    });

    setRefreshTimer();
  }

  void setDataFailed(exception) {
    index_ = {};
    indexVariables_ = {};
    data_ = ContextData();
    failed_ = true;
    _failedErrors[this] = exception;
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

  /// The units, numeric UIDs in their `toString()` form. A UID written
  /// directly to this map replaces the value it was set as.
  final Map<String, String> units_ = UnitsMap();
  bool failed_ = false;
  ContextData? data_;
  Map<String, ExperimentVariables> index_ = {};
  Map<String, List<ExperimentVariables>> indexVariables_ = {};

  final Map<String, Uint8List> hashedUnits_ = {};
  final Map<String, VariantAssigner> assigners_ = {};
  final Map<String, Assignment> assignmentCache_ = {};

  final List<Exposure> exposures_ = [];
  final List<GoalAchievement> achievements_ = [];
  final List<Attribute> attributes_ = [];
  final Map<String, dynamic> _systemAttributes = {};
  Map<String, dynamic>? _attrsMapCache;
  int _attrsMapCacheSeq = 0;
  final Map<String, int> overrides_ = {};
  final Map<String, int> cassignments_ = {};
  int pendingCount_ = 0;
  int _attrsSeq = 0;
  bool closing_ = false;
  bool closed_ = false;
  bool refreshing_ = false;
  bool _refreshInstalled = false;
  Completer<void>? readyFuture_;
  Completer<void>? closingFuture_;
  Completer<void>? refreshFuture_;
  Future<void>? _flushFuture;
  Timer? timeout_;
  Timer? refreshTimer_;
}

// Context is a public class that customers may implement or mock, so the
// error a failed load completed with is kept outside it: a new member would
// break `implements Context`.
final Expando<Object> _failedErrors = Expando<Object>();

/// Lifecycle aliases with the JavaScript SDK's names, and custom field values.
/// Extension methods rather than members of [Context], so classes that
/// implement [Context] keep compiling.
extension ContextExtensions on Context {
  /// Sets several units at once, each a [String] or a [num].
  /// [Context.setUnits] keeps its 2.1 `Map<String, String>` parameter.
  void setUnitValues(final Map<String, Object> units) {
    for (final entry in units.entries) {
      setUnit(entry.key, entry.value);
    }
  }

  /// The error the context data failed to load with, or null.
  dynamic readyError() {
    return _failedErrors[this];
  }

  /// Same as [Context.isClosed].
  bool isFinalized() {
    return isClosed();
  }

  /// Same as [Context.isClosing].
  bool isFinalizing() {
    return isClosing();
  }

  /// Same as [Context.close].
  Future<void> finalize() {
    return close();
  }

  /// The UID of [unitType] as set: a [String] or a [num]. The unit comes
  /// from [Context.getUnit], so a subclass that overrides it is honoured; a
  /// number is restored only while it matches that UID.
  Object? getUnitValue(final String unitType) {
    final Context self = this;
    final Object? value = unitValue(self.units_, unitType);
    final String? uid = getUnit(unitType);
    if (uid == null) {
      return null;
    }
    return (value is num && value.toString() == uid) ? value : uid;
  }

  /// Every unit from [Context.getUnits], numbers included.
  Map<String, Object> getUnitValues() {
    final Context self = this;
    final Map<String, String> units = self.units_;
    return getUnits().map((unitType, uid) {
      final Object? value = unitValue(units, unitType);
      return MapEntry(
          unitType, (value is num && value.toString() == uid) ? value : uid);
    });
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

    final field = _customField(experimentName, key);
    if (field == null) {
      return null;
    }
    switch (field.type) {
      case 'text':
      case 'string':
        return field.value;
      case 'number':
        return num.tryParse(field.value);
      case 'json':
        try {
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

  String? getCustomFieldValueType(
      final String experimentName, final String key) {
    checkReady(true);

    return _customField(experimentName, key)?.type;
  }

  // The first custom field of the experiment named [key], if any.
  CustomFieldValue? _customField(
      final String experimentName, final String key) {
    final fields = index_[experimentName]?.data.customFieldValues;
    if (fields == null) {
      return null;
    }
    for (final field in fields) {
      if (field.name == key) {
        return field;
      }
    }
    return null;
  }

  Set<String> customFieldKeys() => getCustomFieldKeys();

  dynamic customFieldValue(final String experimentName, final String key) =>
      getCustomFieldValue(experimentName, key);

  String? customFieldValueType(final String experimentName, final String key) =>
      getCustomFieldValueType(experimentName, key);
}

class ExperimentVariables {
  late Experiment data;
  List<Map<String, dynamic>?> variables = [];
  // Rule key of [data], set when installed, and its rules, parsed on first
  // use. setData installs new entries, so neither outlives its rules.
  String _ruleKey = "";
  List? _rules;
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
  Map<String, dynamic> variables = {};
  bool exposed = false;
  int _attrsSeq = 0;
}

class _RuleResult {
  _RuleResult(this.variant, this.isMissingUnit);

  final int variant;
  final bool isMissingUnit;
}
