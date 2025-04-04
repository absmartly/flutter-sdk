import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'package:absmartly_sdk/variable_parser.dart';
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
import 'json/experiment_varient.dart';
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
      ContextEventLogger eventLogger) {
    return Context(clock, config, dataFuture, dataProvider,
        eventHandler, variableParser, audienceMatcher, eventLogger);
  }

  Context(
      Clock clock,
      ContextConfig config,
      Completer<ContextData> dataFuture,
      ContextDataProvider dataProvider,
      ContextEventHandler eventHandler,
      VariableParser variableParser,
      AudienceMatcher audienceMatcher,
      ContextEventLogger eventLogger) {
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

      logEvent(EventType.Ready, data);

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

  bool isFinalized() {
    return closed_;
  }

  bool isFinalizing() {
    return !closed_ && closing_;
  }

  Future<Context> ready() async {
    if (isReady()) {
      return Future.value(this);
    }

    return readyFuture_!.future.then((_) {
      return this;
    });
  }

  List<String> getExperiments() {
    checkReady(true);

    return List.generate(data_!.experiments.length, (index) => data_!.experiments[index].name);
  }

  ContextData getData() {
    checkReady(true);

    return data_!;
  }

  void setOverride(final String experimentName, final int variant) {
    checkNotClosed();

    overrides_[experimentName] = variant;
  }

  int? getOverride(final String experimentName) {
    return overrides_[experimentName];
  }

  void setOverrides(Map<String, int> overrides) {
    overrides.forEach((key, value) {
      setOverride(key, value);
    });
  }

  void setCustomAssignment(String experimentName, int variant) {
    checkNotClosed();

    cassignments_[experimentName] = variant;
  }

  int? getCustomAssignment(String experimentName) {
    return cassignments_[experimentName];
  }

  void setCustomAssignments(Map<String, int> customAssignments) {
    customAssignments.forEach((key, value) {
      setCustomAssignment(key, value);
    });
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
    return <String, String>{};
  }

  void setUnits(Map<String, String> units) {
    units.forEach((key, value) {
      setUnit(key, value);
    });
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

    attributes_.add(Attribute(name: name, value: value, setAt: clock_.millis()));
  }

  Map<String, dynamic> getAttributes() {
    final Map<String, dynamic> result = {};

      for (final Attribute attr in attributes_) {
        result[attr.name] = attr.value;
      }
      return result;
  }

  void setAttributes(final Map<String, dynamic> attributes) {
    attributes.forEach((key, value) {
      setAttribute(key, value);
    });
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
          audienceMismatch: assignment.audienceMismatch);

        pendingCount_++;
        exposures_.add(exposure);

      logEvent(EventType.Exposure, exposure);

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
        if (!assignment.exposed) {
          queueExposure(assignment);
        }
        if (assignment.variables.containsKey(key)) {
          return assignment.variables[key];
        }
    }
    return defaultValue;
  }

  dynamic peekVariableValue(
      final String key, final dynamic defaultValue) {
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
      properties: {},
    );
    achievement.achievedAt = clock_.millis();
    achievement.name = goalName;
    achievement.properties = properties;

      pendingCount_++;
      achievements_.add(achievement);

    logEvent(EventType.Goal, achievement);

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
        logEvent(EventType.Refresh, data);
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

  Future<void> finalize() async {
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
            logEvent(EventType.Close, null);
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
          logEvent(EventType.Close, null);
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
        List<Exposure>? exposures;
        List<GoalAchievement>? achievements;
        int eventCount;

          eventCount = pendingCount_;

          if (eventCount > 0) {
            if (exposures_.isNotEmpty) {
              exposures = exposures_.toList();
              exposures_.clear();
            }

            if (achievements_.isNotEmpty) {
              achievements = achievements_.toList();
              achievements_.clear();
            }

            pendingCount_ = 0;
          }

        if (eventCount > 0) {
          List<Unit> units = [];

          for (var entry in units_.entries) {
            units.add(Unit(
                type: entry.key,
                uid: utf8.decode(getUnitHash(entry.key, entry.value))));
          }

          units_.forEach((key, value) {
            units.add(Unit(
                type: key, uid: utf8.decode(getUnitHash(key, value))));
          });

          final PublishEvent event = PublishEvent(
            hashed: true,
            units: units,
            publishedAt: clock_.millis(),
            exposures: exposures ?? [],
            goals: achievements ?? [],
            attributes: attributes_.toList(),
          );
          event.hashed = true;
          event.publishedAt = clock_.millis();

          final Completer<void> result = Completer<void>();

          eventHandler_.publish(this, event).future.then((_) {
            logEvent(EventType.Publish, event);
            result.complete();
          }).catchError((error) {
            logError(error);
            result.completeError(error);
          });

          return result.future;
        }
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
      throw Exception("ABSmartly Context is finalized");
    } else if (closing_) {
      throw Exception("ABSmartly Context is finalized");
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
        const ListEquality().equals(experiment.trafficSplit, assignment.trafficSplit);
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
          if (experimentMatches(experiment.data, assignment)) {
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

          if (experiment.data.audience != null && experiment.data.audience!.isNotEmpty) {
            final Map<String, dynamic> attrs = {};
            for (final Attribute attr in attributes_) {
              attrs[attr.name] = attr.value;
            }

            final Result? match = audienceMatcher_.evaluate(experiment.data.audience!, attrs);
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

              final VariantAssigner assigner = getVariantAssigner(unitType, unitHash);

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
          (assignment.variant < experiment.data.variants.length)) {
        assignment.variables = experiment.variables[assignment.variant] ?? {};
      }

      assignmentCache_[experimentName] = assignment;

      return assignment;
  }

  Assignment? getVariableAssignment(final String key) {
    final List<ExperimentVariables>? keyExperimentVariables = getVariableExperiments(key);

    if (keyExperimentVariables != null) {
      for (ExperimentVariables experimentVariables in keyExperimentVariables) {
        final Assignment assignment = getAssignment(experimentVariables.data.name);
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
    return hashedUnits_[unitType] ?? (hashedUnits_[unitType] = Hashing.hashUnit(unitUID));
  }

  VariantAssigner getVariantAssigner(final String unitType, final Uint8List unitHash) {
    return assigners_[unitType] ?? (assigners_[unitType] = VariantAssigner(unitHash));
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
      refreshTimer_ = Timer.periodic(
          Duration(milliseconds: refreshInterval_), (timer) {
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
            final Map<String, dynamic>? variables = variableParser_.parse(this, experiment.name, variant.name, variant.config!);

            variables?.forEach((key, value) {
              List<ExperimentVariables>? keyExperimentVariables = indexVariables[key];
              if (keyExperimentVariables == null) {
                keyExperimentVariables = [];
                indexVariables[key] = keyExperimentVariables;
              }

              int at = keyExperimentVariables.indexOf(experimentVariables);

              if (at < 0) {
                at = -at - 1;
                keyExperimentVariables.insert(at, experimentVariables);
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
    setRefreshTimer();
  }

  void setDataFailed(exception) {
      index_ = {};
      indexVariables_ = {};
      data_ = ContextData();
      failed_ = true;
  }

  void logEvent(EventType event, dynamic data) {
    eventLogger_.handleEvent(this, event, data);
  }

  void logError(error) {
    eventLogger_.handleEvent(this, EventType.Error, error);
  }

  late Clock clock_;
  int publishDelay_ = 100;
  int refreshInterval_ = 0;
  late ContextEventHandler eventHandler_;
  late ContextDataProvider dataProvider_;
  late VariableParser variableParser_;
  late AudienceMatcher audienceMatcher_;
  late ContextEventLogger eventLogger_;
  final Map<String, String> units_ = {};
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
  final Map<String, int> overrides_ = {};
  final Map<String, int> cassignments_ = {};
  int pendingCount_ = 0;
  bool closing_ = false;
  bool closed_ = false;
  bool refreshing_ = false;
  Completer<void>? readyFuture_;
  Completer<void>? closingFuture_;
  Completer<void>? refreshFuture_;
  Timer? timeout_;
  Timer? refreshTimer_;
  Timer? scheduler_;
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
}
