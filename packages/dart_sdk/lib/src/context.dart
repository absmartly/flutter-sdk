import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'variable_parser.dart';
import 'package:collection/collection.dart';

import 'audience_matcher.dart';
import 'context_config.dart';
import 'context_data_provider.dart';
import 'context_event_handler.dart';
import 'context_event_logger.dart';
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
      final ContextEventHandler eventHandler,
      final VariableParser variableParser,
      AudienceMatcher audienceMatcher,
      ContextEventLogger? eventLogger) {
    return Context(clock, config, dataFuture, dataProvider, eventHandler,
        variableParser, audienceMatcher, eventLogger);
  }

  Context(
      Clock clock,
      ContextConfig config,
      Completer<ContextData> dataFuture,
      ContextDataProvider dataProvider,
      ContextEventHandler eventHandler,
      VariableParser variableParser,
      AudienceMatcher audienceMatcher,
      ContextEventLogger? eventLogger) {
    clock_ = clock;

    publishDelay_ = config.getPublishDelay();
    refreshInterval_ = config.getRefreshInterval();
    eventHandler_ = eventHandler;
    dataProvider_ = dataProvider;
    variableParser_ = variableParser;
    audienceMatcher_ = audienceMatcher;
    eventLogger_ = eventLogger;

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
    if (!isReady() || isClosed()) {
      return [];
    }

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

  String? getUnit(final String unitType) {
    return units_[unitType];
  }

  void setUnit(final String unitType, final String uid) {
    checkNotClosed();

    final String? previous = units_[unitType];
    if ((previous != null) && !(previous == uid)) {
      throw Exception("Unit $unitType already set.");
    }

    final String trimmed = uid.trim();
    if (trimmed.isEmpty) {
      throw Exception("Unit $unitType UID must not be blank.");
    }

    units_[unitType] = trimmed;
  }

  Map<String, String> getUnits() {
    return Map.unmodifiable(units_);
  }

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
    if (!isReady() || isClosed()) {
      return 0;
    }

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
          audienceMismatch: assignment.audienceMismatch);

      pendingCount_++;
      exposures_.add(exposure);

      logEvent(EventType.exposure, exposure);

      setTimeout();
    }
  }

  int peekTreatment(final String experimentName) {
    if (!isReady() || isClosed()) {
      return 0;
    }

    return getAssignment(experimentName).variant;
  }

  Map<String, List<String>> getVariableKeys() {
    if (!isReady() || isClosed()) {
      return {};
    }

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
    if (!isReady() || isClosed()) {
      return {};
    }

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
    if (!isReady() || isClosed()) {
      return null;
    }

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
                return num.parse(field.value);
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
    if (!isReady() || isClosed()) {
      return null;
    }

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
    if (!isReady() || isClosed()) {
      return defaultValue;
    }

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
    if (!isReady() || isClosed()) {
      return defaultValue;
    }

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
      properties: properties ?? {},
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

    if (!refreshing_) {
      refreshing_ = true;
      refreshFuture_ = Completer<void>();

      dataProvider_.getContextData().future.then((data) {
        setData(data);
        refreshing_ = false;
        refreshFuture_!.complete();
        logEvent(EventType.refresh, data);
      }).catchError((error) {
        refreshing_ = false;
        refreshFuture_!.completeError(error);
        logError(error);
      });
    }

    if (refreshFuture_ != null) {
      return refreshFuture_!.future;
    }

    return Future.value();
  }

  Future<void> close() async {
    if (!closed_) {
      if (closing_ == false) {
        closing_ = true;
        clearRefreshTimer();

        if (pendingCount_ > 0) {
          closingFuture_ = Completer<void>();

          flush().then((_) {
            closed_ = true;
            closing_ = false;
            closingFuture_!.complete();
            logEvent(EventType.close, null);
          }).catchError((exception) {
            closed_ = true;
            closing_ = false;
            closingFuture_!.completeError(exception);
            // event logger gets this error during publish
          });

          return closingFuture_!.future;
        } else {
          closed_ = true;
          closing_ = false;
          logEvent(EventType.close, null);
        }
      }

      if (closingFuture_ != null) {
        return closingFuture_!.future;
      }
    }

    return Future.value();
  }

  Future<void> flush() async {
    clearTimeout();

    if (!failed_) {
      if (pendingCount_ > 0) {
        final List<Exposure> exposures = List.of(exposures_);
        final List<GoalAchievement> achievements = List.of(achievements_);
        final int eventCount = pendingCount_;

        List<Unit> units = [];

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

        final Completer<void> result = Completer<void>();

        eventHandler_.publish(this, event).future.then((_) {
          exposures_.removeRange(0, exposures.length);
          achievements_.removeRange(0, achievements.length);
          pendingCount_ -= eventCount;
          logEvent(EventType.publish, event);
          result.complete();
        }).catchError((error) {
          logError(error);
          result.completeError(error);
        });

        return result.future;
      }
    } else {
      exposures_.clear();
      achievements_.clear();
      pendingCount_ = 0;
    }

    return Future.value();
  }

  void checkNotClosed() {
    if (closed_) {
      throw Exception("ABSmartly Context is finalized.");
    } else if (closing_) {
      throw Exception("ABSmartly Context is finalizing.");
    }
  }

  void checkReady(final bool expectNotClosed) {
    if (!isReady()) {
      throw Exception("ABSmartly Context is not yet ready.");
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

  bool audienceMatches(
      final Experiment experiment, final Assignment assignment) {
    if (experiment.audience != null && experiment.audience!.isNotEmpty) {
      if (attrsSeq_ > assignment.attrsSeq) {
        final Map<String, dynamic> attrs = {};
        for (final Attribute attr in attributes_) {
          attrs[attr.name] = attr.value;
        }
        final Result? match = audienceMatcher_.evaluate(experiment.audience!, attrs);
        final bool newAudienceMismatch = match != null ? !match.get() : false;
        if (newAudienceMismatch != assignment.audienceMismatch) {
          return false;
        }
        assignment.attrsSeq = attrsSeq_;
      }
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
        if (!assignment.assigned) {
          // previously not-running experiment
          return assignment;
        }
      } else if ((custom == null) || custom == assignment.variant) {
        if (experimentMatches(experiment.data, assignment) &&
            audienceMatches(experiment.data, assignment)) {
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

        if (experiment.data.audience != null &&
            experiment.data.audience!.isNotEmpty) {
          final Map<String, dynamic> attrs = {};
          for (final Attribute attr in attributes_) {
            attrs[attr.name] = attr.value;
          }

          final Result? match =
              audienceMatcher_.evaluate(experiment.data.audience!, attrs);
          if (match != null) {
            assignment.audienceMismatch = !match.get();
          }
        }

        if (experiment.data.audienceStrict && assignment.audienceMismatch) {
          assignment.variant = 0;
        } else if (experiment.data.fullOnVariant == 0) {
          final String? uid = units_[experiment.data.unitType];
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
        if (assignment.assigned || assignment.overridden) {
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

  Uint8List getUnitHash(final String unitType, final String unitUID) {
    return hashedUnits_[unitType] ??
        (hashedUnits_[unitType] = Hashing.hashUnit(unitUID));
  }

  VariantAssigner getVariantAssigner(
      final String unitType, final Uint8List unitHash) {
    return assigners_[unitType] ??
        (assigners_[unitType] = VariantAssigner(unitHash));
  }

  void setTimeout() {
    if (isReady()) {
      timeout_ ??= Timer(Duration(milliseconds: publishDelay_), () {
        flush();
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
    if ((refreshInterval_ > 0) && (refreshTimer_ == null)) {
      refreshTimer_ =
          Timer.periodic(Duration(milliseconds: refreshInterval_), (timer) {
        refresh();
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
                if (keyExperimentVariables[i].data.id < experimentVariables.data.id) {
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
        return assignment.assigned;
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

  void logEvent(EventType event, dynamic data) {
    eventLogger_?.handleEvent(this, event, data);
  }

  void logError(error) {
    eventLogger_?.handleEvent(this, EventType.error, error);
  }

  late Clock clock_;
  int publishDelay_ = 100;
  int refreshInterval_ = 0;
  late ContextEventHandler eventHandler_;
  late ContextDataProvider dataProvider_;
  late VariableParser variableParser_;
  late AudienceMatcher audienceMatcher_;
  late ContextEventLogger? eventLogger_;
  final Map<String, String> units_ = {};
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
  Timer? timeout_;
  Timer? refreshTimer_;
}

class ExperimentVariables {
  late Experiment data;
  List<Map<String, dynamic>?> variables = [];
}

class Assignment {
  int id = 0;
  late int iteration;
  late int fullOnVariant;
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
  Map<String, dynamic> variables = {};
  bool exposed = false;
  int attrsSeq = 0;
}
