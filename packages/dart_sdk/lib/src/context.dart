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
  // result. Evict it so getAssignment() hashes the unit now; an exposed one is
  // kept, since re-resolving would queue a second, conflicting exposure.
  void _invalidateAssignmentsPinnedWithMissingUnit(final String unitType) {
    assignmentCache_.removeWhere((_, assignment) =>
        assignment.unitType == unitType &&
        !assignment.exposed &&
        assignment._isRuleMissingUnit);
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
  // a refresh that changes any of it re-resolves the rules. Built at most once
  // per installed experiment (see _entryRuleKey), never per read.
  String _ruleKey(final Experiment experiment) {
    final String? rules = experiment.assignmentRules;
    if (rules == null || rules.isEmpty) {
      return "";
    }
    ContextCounters.ruleKeyBuilds++;
    return "$rules:$_environmentName:${experiment.variants.length}:"
        "${experiment.seedHi}:${experiment.seedLo}";
  }

  // The rule key of [entry], built on its first use after setData installed it.
  String _entryRuleKey(final ExperimentVariables entry) {
    return entry._ruleKey ??= _ruleKey(entry.data);
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
    final Object? uid = unitPinnedMissing ? null : units_[unitType];
    if (uid == null) {
      return _RuleResult(experiment.fullOnVariant, true);
    }

    final VariantAssigner assigner =
        getVariantAssigner(unitType, getUnitHash(unitType, uid));
    return _RuleResult(
        assigner.assign(split, experiment.seedHi, experiment.seedLo), false);
  }

  bool audienceMatches(
      final Experiment experiment, final Assignment assignment) {
    final ExperimentVariables? entry = index_[experiment.name];
    return _audienceMatches(
        entry != null && identical(entry.data, experiment)
            ? entry
            : (ExperimentVariables()..data = experiment),
        assignment);
  }

  bool _audienceMatches(
      final ExperimentVariables entry, final Assignment assignment) {
    final Experiment experiment = entry.data;
    final String key = _entryRuleKey(entry);
    final String cachedKey = assignment._ruleKey ?? "";
    bool ruleKeyChanged = false;
    if (!identical(key, cachedKey)) {
      if (key == cachedKey) {
        // Same rules from a refresh: adopt the new key so later reads compare
        // by identity instead of by content.
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
      assignment.attrsSeq = attrsSeq_;
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

        final String key = _entryRuleKey(experiment);
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

    for (Experiment experiment in data.experiments) {
      final ExperimentVariables experimentVariables = ExperimentVariables();
      experimentVariables.data = experiment;
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
  // Rule key and parsed rules of [data], built on first use; setData installs
  // new entries, so they never outlive the rules they came from.
  String? _ruleKey;
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
  int attrsSeq = 0;
}

class _RuleResult {
  _RuleResult(this.variant, this.isMissingUnit);

  final int variant;
  final bool isMissingUnit;
}
