import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'package:absmartly_sdk/helper/mutex/mutex.dart';
import 'package:absmartly_sdk/variable_parser.dart';
import 'package:mockito/annotations.dart';

import 'audience_matcher.dart';
import 'context_config.dart';
import 'context_data_provider.dart';
import 'context_event_handler.dart';
import 'context_event_logger.dart';
import 'helper/mutex/read_write_mutex.dart';
import 'internal/concurrency.dart';
import 'internal/hashing/hashing.dart';
import 'internal/variant_assigner.dart';
import 'java/time/clock.dart';
import 'java_system_classes/closeable.dart';
import 'json/attribute.dart';
import 'json/context_data.dart';
import 'json/experiment.dart';
import 'json/experiment_varient.dart';
import 'json/exposure.dart';
import 'json/goal_achievement.dart';
import 'json/publish_event.dart';
import 'json/unit.dart';

@GenerateNiceMocks([MockSpec<Context>()])
class Context implements Closeable {
  bool dataFutureCheck = false;

  factory Context.create(
      Clock clock,
      final ContextConfig config,
      final Timer? scheduler,
      final Future<ContextData?> dataFuture,
      final ContextDataProvider dataProvider,
      final ContextEventHandler eventHandler,
      final VariableParser variableParser,
      AudienceMatcher audienceMatcher) {
    return Context(clock, config, dataFuture, scheduler, dataProvider,
        eventHandler, variableParser, audienceMatcher);
  }

  Context(
      Clock clock,
      ContextConfig config,
      Future<ContextData?> dataFuture,
      Timer? scheduler,
      ContextDataProvider dataProvider,
      ContextEventHandler eventHandler,
      VariableParser variableParser,
      AudienceMatcher audienceMatcher) {
    clock_ = clock;

    publishDelay_ = config.getPublishDelay();
    refreshInterval_ = config.getRefreshInterval();
    eventHandler_ = eventHandler;
    dataProvider_ = dataProvider;
    variableParser_ = variableParser;
    audienceMatcher_ = audienceMatcher;
    scheduler_ = scheduler;

    units_ = <String, String>{};

    final Map<String, String> units = config.getUnits() ?? {};
    setUnits(units);

    assigners_ = <String, VariantAssigner>{};
    hashedUnits_ = <String, Uint8List>{};

    final Map<String, dynamic>? attributes = config.getAttributes();
    if (attributes != null) {
      setAttributes(attributes);
    }

    final Map<String, int> overrides = config.getOverrides();
    overrides_ = <String, int>{};

    final Map<String, int>? cassignments = config.getCustomAssignments();
    cassignments_ = <String, int>{};

    dataFuture.whenComplete(() {
      dataFutureCheck = true;
    });

    if (dataFutureCheck) {
      dataFuture.then((data) {
        if (data == null) {
          setDataFailed(Exception("No data found"));

          logError(Exception("No data found"));
        }
        setData(data!);
        logEvent(EventType.Ready, data);
      }).catchError((exception) {
        setDataFailed(exception);

        logError(exception);
      });
    } else {
      readyFuture_ = Completer<Future<void>?>();
      dataFuture.then((data) {
        if (data == null) {
          setDataFailed(Exception("No data found"));
          readyFuture_?.complete();
          logError(Exception("No data found"));
          return;
        }
        setData(data);
        readyFuture_?.complete();
        // readyFuture_ = null;
        logEvent(EventType.Ready, data);
        if (getPendingCount() > 0) {
          setTimeout();
        }
      }).catchError((exception) {
        // setDataFailed(exception);
        // readyFuture_?.complete();
        // logError(exception);
        // return null;
      });
    }
  }

  bool isReady() {
    return data_ != null;
  }

  bool isFailed() {
    return failed_ ?? false;
  }

  bool isClosed() {
    return closed_;
  }

  bool isClosing() {
    return !closed_ && closing_;
  }

  Future<Context> waitUntilReadyAsync() {
    if (data_ != null) {
      return Future.value(this);
    } else {
      return readyFuture_!.future.then((value) {
        return Future.value(this);
      });
    }
  }

  Future<Context> waitUntilReady() async {
    if (data_ == null) {
      final Future<void>? future =
          readyFuture_?.future; // cache here to avoid locking
      if (future != null) {
        await future;
      }
    }
    return this;
  }

  Future<List<String>> getExperiments() async {
    checkReady(true);

    try {
      await dataLock_.acquireRead();
      final List<String> experimentNames = List.generate(
          data_!.experiments.length, (index) => data_!.experiments[index].name);

      return experimentNames;
    } finally {
      dataLock_.release();
    }
  }

  ContextData getData() {
    checkReady(true);

    try {
      dataLock_.acquireRead();
      return data_!;
    } finally {
      dataLock_.release();
    }
  }

  void setOverride(final String experimentName, final int variant) {
    checkNotClosed();
    Concurrency.putRW(contextLock_, overrides_, experimentName, variant);
  }

  int getOverride(final String experimentName) {
    return Concurrency.getRW(contextLock_, overrides_, experimentName);
  }

  void setOverrides(Map<String, int> overrides) {
    overrides.forEach((key, value) {
      setOverride(key, value);
    });
  }

  void setCustomAssignment(String experimentName, int variant) {
    checkNotClosed();
    Concurrency.putRW(contextLock_, cassignments_, experimentName, variant);
  }

  int getCustomAssignment(String experimentName) {
    return Concurrency.getRW(contextLock_, cassignments_, experimentName);
  }

  void setCustomAssignments(Map<String, int> customAssignments) {
    customAssignments.forEach((key, value) {
      setCustomAssignment(key, value);
    });
  }

  String? getUnit(final String unitType) {
    try {
      contextLock_.acquireRead();
      return units_![unitType];
    } finally {
      contextLock_.release();
    }
  }

  void setUnit(final String unitType, final String uid) {
    checkNotClosed();

    try {
      contextLock_.acquireWrite();

      final String? previous = units_![unitType];
      if ((previous != null) && !(previous == uid)) {
        throw Exception("Unit $unitType already set.");
      }

      final String trimmed = uid.trim();
      if (trimmed.isEmpty) {
        throw Exception("Unit $unitType UID must not be blank.");
      }

      units_![unitType] = trimmed;
    } finally {
      contextLock_.release();
    }
  }

  Map<String, String> getUnits() {
    try {
      contextLock_.acquireRead();

      return <String, String>{};
    } finally {
      contextLock_.release();
    }
  }

  void setUnits(Map<String, String> units) {
    units.forEach((key, value) {
      setUnit(key, value);
    });
  }

  dynamic getAttribute(final String name) {
    try {
      contextLock_.acquireRead();
      for (int i = attributes_.length; i-- > 0;) {
        final Attribute attr = attributes_[i];
        if (name == attr.name) {
          return attr.value;
        }
      }

      return null;
    } finally {
      contextLock_.release();
    }
  }

  void setAttribute(String name, dynamic value) {
    checkNotClosed();

    Concurrency.addRW(contextLock_, attributes_,
        Attribute(name: name, value: value, setAt: clock_.millis()));
  }

  Map<String, dynamic> getAttributes() {
    final Map<String, dynamic> result = <String, dynamic>{};

    try {
      contextLock_.acquireRead();
      for (final Attribute attr in attributes_) {
        result[attr.name] = attr.value;
      }
      return result;
    } finally {
      contextLock_.release();
    }
  }

  void setAttributes(final Map<String, dynamic> attributes) {
    attributes.forEach((key, value) {
      setAttribute(key, value);
    });
  }

  Future<int> getTreatment(final String experimentName) async {
    checkReady(true);

    final Assignment assignment = await getAssignment(experimentName);

    if (!assignment.exposed) {
      queueExposure(assignment);
    }

    return assignment.variant ?? 0;
  }

  void queueExposure(final Assignment assignment) {
    if (!assignment.exposed) {
      assignment.exposed = true;
      final Exposure exposure = Exposure(
          id: assignment.id ?? 0,
          name: assignment.name,
          unit: assignment.unitType,
          variant: assignment.variant ?? 0,
          exposedAt: clock_.millis(),
          assigned: assignment.assigned,
          eligible: assignment.eligible,
          overridden: assignment.overridden,
          fullOn: assignment.fullOn,
          custom: assignment.custom,
          audienceMismatch: assignment.audienceMismatch);

      try {
        eventLock_.acquire();
        pendingCount_++;
        exposures_.add(exposure);
      } finally {
        eventLock_.release();
      }

      logEvent(EventType.Exposure, exposure);

      setTimeout();
    }
  }

  Future<int> peekTreatment(final String experimentName) async {
    checkReady(true);

    return (await getAssignment(experimentName)).variant ?? 0;
  }

  Map<String, List<String>> getVariableKeys() {
    checkReady(true);

    final Map<String, List<String>> variableKeys = <String, List<String>>{};

    try {
      dataLock_.acquireRead();

      // in
      indexVariables_!.forEach((key, value) {
        final List<ExperimentVariables> keyExperimentVariables = value;
        final List<String> values = List.generate(keyExperimentVariables.length,
            (index) => keyExperimentVariables[index].data.name);
        variableKeys[key] = values;
      });
    } finally {
      dataLock_.release();
    }
    return variableKeys;
  }

  dynamic getVariableValue(final String key, final dynamic defaultValue) async {
    checkReady(true);

    final Assignment? assignment = await getVariableAssignment(key);
    if (assignment != null) {
      if (assignment.variables != null) {
        if (!assignment.exposed) {
          queueExposure(assignment);
        }
        if (assignment.variables!.containsKey(key)) {
          return assignment.variables![key];
        }
      }
    }
    return defaultValue;
  }

  Future<dynamic> peekVariableValue(
      final String key, final dynamic defaultValue) async {
    checkReady(true);

    final Assignment? assignment = await getVariableAssignment(key);
    if (assignment != null) {
      if (assignment.variables != null) {
        if (assignment.variables!.containsKey(key)) {
          return assignment.variables![key];
        }
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

    try {
      eventLock_.acquire();
      pendingCount_++;
      achievements_.add(achievement);
    } finally {
      eventLock_.release();
    }

    logEvent(EventType.Goal, achievement);

    setTimeout();
  }

  Future<void> publishAsync() {
    checkNotClosed();

    return flush();
  }

  Future<void> publish() async {
    await publishAsync();
  }

  int getPendingCount() {
    return pendingCount_;
  }

  Future<void>? refreshAsync() {
    checkNotClosed();

    if (!refreshing_) {
      refreshing_ = true;
      refreshFuture_ = Completer<Future<void>>();

      dataProvider_!.getContextData().then((data) {
        setData(data!);
        refreshing_ = false;

        refreshFuture_!.complete(Future<void>.value());
        logEvent(EventType.Refresh, data);
      }).catchError((error) {
        refreshing_ = false;
        refreshFuture_!.completeError(error);
        logError(error);
        return null;
      });
    }

    final Future<void>? future = refreshFuture_?.future;
    if (future != null) {
      return future;
    }

    return Future.value(null);
  }

  Future<void> refresh() async {
    await refreshAsync();
  }

  Future<void> closeAsync() {
    if (!closed_) {
      if (closing_ == false) {
        closing_ = true;
        clearRefreshTimer();

        if (pendingCount_ > 0) {
          closingFuture_ = Completer<Future<void>?>();

          flush().then((x) {
            closed_ = true;
            closing_ = false;
            closingFuture_?.complete(null);
            logEvent(EventType.Close, null);
          }).catchError((exception) {
            closed_ = true;
            closing_ = false;
            closingFuture_!.completeError(exception);
            // event logger gets this error during publish
            return null;
          });

          return closingFuture_!.future;
        } else {
          closed_ = true;
          closing_ = false;
          logEvent(EventType.Close, null);
        }
      }

      final Future<void>? future = closingFuture_?.future;
      if (future != null) {
        return future;
      }
    }

    return Future.value(null);
  }

  @override
  Future<void> close() async {
    await closeAsync();
  }

  Future<Future<void>?> flush() async {
    clearTimeout();

    if (!(failed_ ?? false)) {
      if (pendingCount_ > 0) {
        List<Exposure>? exposures;
        List<GoalAchievement>? achievements;
        int eventCount;

        try {
          eventLock_.acquire();
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
        } finally {
          eventLock_.release();
        }

        if (eventCount > 0) {
          List<Unit> units = [];

          for (var entry in units_!.entries) {
            units.add(Unit(
                type: entry.key,
                uid: utf8.decode(await getUnitHash(entry.key, entry.value))));
          }

          units_?.forEach((key, value) async {
            units.add(Unit(
                type: key, uid: utf8.decode(await getUnitHash(key, value))));
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

          final Completer<Future<void>?> result = Completer<Future<void>?>();

          eventHandler_?.publish(this, event).then((value) {
            logEvent(EventType.Publish, event);
            result.complete(null);
          }).catchError((error) {
            logError(error);
            result.completeError(error);
          });

          return result.future;
        }
      }
    } else {
      try {
        eventLock_.acquire();
        exposures_.clear();
        achievements_.clear();
        pendingCount_ = 0;
      } finally {
        eventLock_.release();
      }
    }

    return Future.value(null);
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
        areListsEqual(experiment.trafficSplit, assignment.trafficSplit);
    // Arrays.equals(experiment.trafficSplit, assignment.trafficSplit);
  }

  Future<Assignment> getAssignment(final String experimentName) async {
    try {
      contextLock_.acquireRead();

      final Assignment? assignment = assignmentCache_[experimentName];

      if (assignment != null) {
        final int? custom = cassignments_[experimentName];
        final int? override = overrides_[experimentName];
        final ExperimentVariables? experiment = getExperiment(experimentName);

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
    } finally {
      contextLock_.release();
    }

    // cache miss or out-dated
    try {
      contextLock_.acquireWrite();

      final int? custom = cassignments_[experimentName];
      final int? override = overrides_[experimentName];
      final ExperimentVariables? experiment = getExperiment(experimentName);

      final Assignment assignment = Assignment();
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
            final Map<String, dynamic> attrs = <String, dynamic>{};
            for (final Attribute attr in attributes_) {
              attrs[attr.name] = attr.value;
            }

            final Result? match =
                audienceMatcher_!.evaluate(experiment.data.audience!, attrs);
            if (match != null) {
              assignment.audienceMismatch = !match.get();
            }
          }

          if (experiment.data.audienceStrict && assignment.audienceMismatch) {
            assignment.variant = 0;
          } else if (experiment.data.fullOnVariant == 0) {
            final String? uid = units_![experiment.data.unitType];
            if (uid != null) {
              final Uint8List unitHash = await getUnitHash(unitType, uid);

              final VariantAssigner assigner =
                  await getVariantAssigner(unitType, unitHash);

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
          ((assignment.variant ?? 0) < experiment.data.variants.length)) {
        assignment.variables = experiment.variables[assignment.variant ?? 0];
      }

      assignmentCache_[experimentName] = assignment;

      return assignment;
    } finally {
      contextLock_.release();
    }
  }

  Future<Assignment?> getVariableAssignment(final String key) async {
    final List<ExperimentVariables>? keyExperimentVariables =
        getVariableExperiments(key);

    if (keyExperimentVariables != null) {
      for (ExperimentVariables experimentVariables in keyExperimentVariables) {
        final Assignment assignment =
            await getAssignment(experimentVariables.data.name);
        if (assignment.assigned || assignment.overridden) {
          return assignment;
        }
      }
    }
    return null;
  }

  ExperimentVariables? getExperiment(final String experimentName) {
    try {
      dataLock_.acquireRead();
      return index_![experimentName];
    } finally {
      dataLock_.release();
    }
  }

  List<ExperimentVariables>? getVariableExperiments(final String key) {
    return Concurrency.getRW(dataLock_, indexVariables_!, key);
  }

  Future<Uint8List> getUnitHash(final String unitType, final String unitUID) {
    return Future.value(Hashing.hashUnit(unitUID));
    return Concurrency.computeIfAbsentRW(contextLock_, hashedUnits_, unitType,
        (key) {
      return Hashing.hashUnit(unitUID);
    });
  }

  Future<VariantAssigner> getVariantAssigner(
      final String unitType, final Uint8List unitHash) {
    return Concurrency.computeIfAbsentRW(
      contextLock_,
      assigners_,
      unitType,
      (key) {
        return VariantAssigner(unitHash);
      },
    );
  }

  void setTimeout() {
    if (isReady()) {
      if (timeout_ == null) {
        try {
          timeoutLock_.acquire();
          timeout_ ??= Timer(Duration(milliseconds: publishDelay_ ?? 0), () {
            flush();
          });
        } finally {
          timeoutLock_.release();
        }
      }
    }
  }

  void clearTimeout() {
    if (timeout_ != null) {
      try {
        timeoutLock_.acquire();
        if (timeout_ != null) {
          timeout_!.cancel();
          timeout_ = null;
        }
      } finally {
        timeoutLock_.release();
      }
    }
  }

  void setRefreshTimer() {
    if (((refreshInterval_ ?? 0) > 0) && (refreshTimer_ == null)) {
      refreshTimer_ = Timer.periodic(
          Duration(milliseconds: refreshInterval_ ?? 0), (timer) {
        refreshAsync();
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
    final Map<String, ExperimentVariables> index =
        <String, ExperimentVariables>{};
    final Map<String, List<ExperimentVariables>> indexVariables =
        <String, List<ExperimentVariables>>{};

    for (Experiment experiment in data.experiments) {
      final ExperimentVariables experimentVariables = ExperimentVariables();
      experimentVariables.data = experiment;
      experimentVariables.variables =
          List.generate(experiment.variants.length, (index) {
        for (ExperimentVariant variant in experiment.variants) {
          if ((variant.config != null) && variant.config!.isNotEmpty) {
            final Map<String, dynamic>? variables = variableParser_!
                .parse(this, experiment.name, variant.name, variant.config!);

            variables?.forEach((key, value) {
              List<ExperimentVariables>? keyExperimentVariables =
                  indexVariables[key];
              if (keyExperimentVariables == null) {
                keyExperimentVariables = <ExperimentVariables>[];
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
            experimentVariables.variables.add(<String, dynamic>{});
          }
        }
        return null;
      });

      index[experiment.name] = experimentVariables;
    }

    try {
      dataLock_.acquireWrite();

      index_ = index;
      indexVariables_ = indexVariables;
      data_ = data;
      setRefreshTimer();
    } finally {
      dataLock_.release();
    }
  }

  void setDataFailed(exception) {
    try {
      dataLock_.acquireWrite();
      index_ = <String, ExperimentVariables>{};
      indexVariables_ = <String, List<ExperimentVariables>>{};
      data_ = ContextData();
      failed_ = true;
    } finally {
      dataLock_.release();
    }
  }

  void logEvent(EventType event, dynamic data) {
    print("${event.toString()}: ${data.toString()}");
  }

  void logError(error) {
    print("${EventType.Error.toString()}: ${error.toString()}");
  }

  late Clock clock_;
  int? publishDelay_;
  int? refreshInterval_;
  ContextEventHandler? eventHandler_;
  ContextDataProvider? dataProvider_;
  VariableParser? variableParser_;
  AudienceMatcher? audienceMatcher_;
  Map<String, String>? units_;
  bool? failed_;
  final ReadWriteMutex dataLock_ = ReadWriteMutex();
  ContextData? data_;
  Map<String, ExperimentVariables>? index_;
  Map<String, List<ExperimentVariables>>? indexVariables_;
  final ReadWriteMutex contextLock_ = ReadWriteMutex();
  late Map<String, Uint8List> hashedUnits_;
  late Map<String, VariantAssigner> assigners_;
  final Map<String, Assignment> assignmentCache_ = <String, Assignment>{};

  // final ReentrantLock eventLock_ = new ReentrantLock();
  final Mutex eventLock_ = Mutex();
  final List<Exposure> exposures_ = [];
  final List<GoalAchievement> achievements_ = [];
  final List<Attribute> attributes_ = [];
  Map<String, int> overrides_ = {};
  Map<String, int> cassignments_ = {};
  int pendingCount_ = 0;
  bool closing_ = false;
  bool closed_ = false;
  bool refreshing_ = false;
  Completer<void>? readyFuture_;
  Completer<void>? closingFuture_;
  Completer<void>? refreshFuture_;
  final Mutex timeoutLock_ = Mutex();
  Timer? timeout_;
  Timer? refreshTimer_;
  Timer? scheduler_;

  bool areListsEqual(var list1, var list2) {
    // check if both are lists
    if (!(list1 is List && list2 is List)
        // check if both have same length
        ||
        list1.length != list2.length) {
      return false;
    }
    // check if elements are equal
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) {
        return false;
      }
    }
    return true;
  }
}

class ExperimentVariables {
  late Experiment data;
  List<Map<String, dynamic>?> variables = [];
}

class Assignment {
  int? id;
  late int iteration;
  late int fullOnVariant;
  late String name;
  String? unitType;
  List<double> trafficSplit = [];
  int? variant;
  bool assigned = false;
  bool overridden = false;
  bool eligible = false;
  bool fullOn = false;
  bool custom = false;
  bool audienceMismatch = false;
  Map<String, dynamic>? variables;
  bool exposed = false;
}
