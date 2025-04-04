import 'package:absmartly_sdk/context_event_logger.dart';

import 'test_utils.dart';

import 'dart:async';

import 'package:absmartly_sdk/audience_matcher.dart';
import 'package:absmartly_sdk/context.dart';
import 'package:absmartly_sdk/context_config.dart';
import 'package:absmartly_sdk/context_data_provider.mocks.dart';
import 'package:absmartly_sdk/context_event_handler.mocks.dart';
import 'package:absmartly_sdk/context_event_logger.mocks.dart';
import 'package:absmartly_sdk/default_audience_deserializer.dart';
import 'package:absmartly_sdk/default_context_data_serializer.dart';
import 'package:absmartly_sdk/default_variable_parser.dart';
import 'package:absmartly_sdk/java/time/clock.dart';
import 'package:absmartly_sdk/json/attribute.dart';
import 'package:absmartly_sdk/json/context_data.dart';
import 'package:absmartly_sdk/json/exposure.dart';
import 'package:absmartly_sdk/json/goal_achievement.dart';
import 'package:absmartly_sdk/json/publish_event.dart';
import 'package:absmartly_sdk/json/unit.dart';
import 'package:absmartly_sdk/variable_parser.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group("context", () {
    final Map<String, String> units = {
      "session_id": "e791e240fcd3df7d238cfc285f475e8152fcc0ec",
      "user_id": "123456789",
      "email": "bleh@absmartly.com",
    };

    final Map<String, dynamic> attributes = {
      "attr1": "value1",
      "attr2": "value2",
      "attr3": 5,
    };

    final Map<String, int> expectedVariants = {
      "exp_test_ab": 1,
      "exp_test_abc": 2,
      "exp_test_not_eligible": 0,
      "exp_test_fullon": 2,
      "exp_test_new": 1,
    };

    final Map<String, dynamic> expectedVariables = {
      "banner.border": 1,
      "banner.size": "large",
      "button.color": "red",
      "submit.color": "blue",
      "submit.shape": "rect",
      "show-modal": true,
    };

    final Map<String, List<String>> variableExperiments = {
      "banner.border": ["exp_test_ab"],
      "banner.size": ["exp_test_ab"],
      "button.color": ["exp_test_abc"],
      "card.width": ["exp_test_not_eligible"],
      "submit.color": ["exp_test_fullon"],
      "submit.shape": ["exp_test_fullon"],
      "show-modal": ["exp_test_new"],
    };

    final List<Unit> publishUnits = [
      Unit(type: "user_id", uid: "JfnnlDI7RTiF9RgfG2JNCw"),
      Unit(type: "session_id", uid: "pAE3a1i5Drs5mKRNq56adA"),
      Unit(type: "email", uid: "IuqYkNRfEx5yClel4j3NbA"),
    ];

    late ContextData data;
    late ContextData refreshData;
    late ContextData audienceData;
    late ContextData audienceStrictData;
    late Future<ContextData> dataFutureReady;
    late Future<ContextData> dataFutureFailed;
    late Completer<ContextData> dataFuture;
    late Future<ContextData> refreshDataFutureReady;
    late Completer<ContextData> refreshDataFuture;
    late Future<ContextData> audienceDataFutureReady;
    late Future<ContextData> audienceStrictDataFutureReady;
    late MockContextDataProvider dataProvider;
    late MockContextEventHandler eventHandler;
    late MockContextEventLogger eventLogger;
    late VariableParser variableParser;
    late AudienceMatcher audienceMatcher;
    late Timer scheduler;
    late DefaultContextDataDeserializer deser;
    late Clock clock;

    setUp(() async {
      WidgetsFlutterBinding.ensureInitialized();
      deser = DefaultContextDataDeserializer();
      clock = Clock.fixed(1620000000000);

      List<int> bytes = await getResourceBytes("context.json");
      data = deser.deserialize(bytes, 0, bytes.length)!;

      List<int> refreshBytes = await getResourceBytes("refreshed.json");
      refreshData = deser.deserialize(refreshBytes, 0, refreshBytes.length)!;

      List<int> audienceBytes = await getResourceBytes("audience_context.json");
      audienceData = deser.deserialize(audienceBytes, 0, audienceBytes.length)!;

      List<int> audienceStrictBytes =
          await getResourceBytes("audience_strict_context.json");
      audienceStrictData = deser.deserialize(
          audienceStrictBytes, 0, audienceStrictBytes.length)!;

      dataFutureReady = Future<ContextData>.value(data);
      dataFutureFailed = Future.error(Exception("FAILED"));
      dataFuture = Completer<ContextData>();
      refreshDataFutureReady = Future<ContextData>.value(refreshData);
      refreshDataFuture = Completer<ContextData>();
      audienceDataFutureReady = Future<ContextData>.value(audienceData);
      audienceStrictDataFutureReady =
          Future<ContextData>.value(audienceStrictData);

      dataProvider = MockContextDataProvider();
      eventHandler = MockContextEventHandler();
      eventLogger = MockContextEventLogger();
      variableParser = DefaultVariableParser();
      audienceMatcher = AudienceMatcher(DefaultAudienceDeserializer());
      scheduler = Timer(const Duration(seconds: 5), () {});
    });

    Context createContext(
        ContextConfig? config, Future<ContextData> dataFuture) {
      if (config == null) {
        final ContextConfig config = ContextConfig.create().setUnits(units);
        return Context.create(clock, config, scheduler, dataFuture,
            dataProvider, eventHandler, variableParser, audienceMatcher);
      }
      return Context.create(clock, config, scheduler, dataFuture, dataProvider,
          eventHandler, variableParser, audienceMatcher);
    }

    Future<Context> createReadyContext([ContextData? contextData]) async {
      final ContextConfig config = ContextConfig.create().setUnits(units);
      final context = Context.create(
          clock,
          config,
          scheduler,
          Future.value(data),
          dataProvider,
          eventHandler,
          variableParser,
          audienceMatcher);
        
        await context.waitUntilReady();

        return context;
    }

    test('constructorSetsOverrides', () {
      final Map<String, int> overrides = {"exp_test": 2, "exp_test_1": 1};

      final ContextConfig config =
          ContextConfig.create().setUnits(units).setOverrides(overrides);

      final Context context = createContext(config, dataFutureReady);
      overrides.forEach((experimentName, variant) =>
          expect(context.getOverride(experimentName), equals(variant)));
    });

    test('constructorSetsCustomAssignments', () {
      final Map<String, int> cassignments = {"exp_test": 2, "exp_test_1": 1};

      final ContextConfig config = ContextConfig.create()
          .setUnits(units)
          .setCustomAssignments(cassignments);

      final Context context = createContext(config, dataFutureReady);
      cassignments.forEach((experimentName, variant) =>
          expect(context.getCustomAssignment(experimentName), equals(variant)));
    });

    test('becomesReadyWithCompletedFuture', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);
      expect(context.getData(), same(data));
    });

    test('becomesReadyAndFailedWithCompletedExceptionallyFuture', () async {
      final context = createContext(null, dataFutureFailed);
      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isTrue);
    });

    test('becomesReadyAndFailedWithException', () async {
      final context = createContext(null, dataFuture.future);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      dataFuture.completeError(Exception("FAILED"));
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isTrue);
    });

    test('callsEventLoggerWhenReady', () async {
      final context = createContext(null, dataFuture.future);

      dataFuture.complete(data);
      await context.waitUntilReady();

      verify(eventLogger.handleEvent(context, EventType.Ready, data)).called(1);
    });

    test('callsEventLoggerWithCompletedFuture', () async {
      final context = createReadyContext();

      verify(eventLogger.handleEvent(context, EventType.Ready, data)).called(1);
    });

    test('callsEventLoggerWithException', () async {
      final context = createContext(null, dataFuture.future);

      final error = Exception("FAILED");
      dataFuture.completeError(error);

      await context.waitUntilReady();
      verify(eventLogger.handleEvent(context, EventType.Error, error))
          .called(1);
    });

    test('waitUntilReady', () async {
      final context = createContext(null, dataFuture.future);
      expect(context.isReady(), isFalse);

      // Use a microtask to complete the future after the waitUntilReady call
      scheduleMicrotask(() => dataFuture.complete(data));

      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.getData(), same(data));
    });

    test('waitUntilReadyWithCompletedFuture', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      await context.waitUntilReady();
      expect(context.getData(), same(data));
    });

    test('waitUntilReadyAsync', () async {
      final context = createContext(null, dataFuture.future);
      expect(context.isReady(), isFalse);

      final readyFuture = context.waitUntilReadyAsync();
      expect(context.isReady(), isFalse);

      dataFuture.complete(data);
      await readyFuture;

      expect(context.isReady(), isTrue);
      expect(await readyFuture, same(context));
      expect(context.getData(), same(data));
    });

    test('waitUntilReadyAsyncWithCompletedFuture', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      final readyFuture = context.waitUntilReadyAsync();
      await readyFuture;

      expect(context.isReady(), isTrue);
      expect(await readyFuture, same(context));
      expect(context.getData(), same(data));
    });

    test('throwsWhenNotReady', () {
      final context = createContext(null, dataFuture.future);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      const notReadyMessage = "ABSmartly Context is not yet ready";
      expect(
          () => context.peekTreatment("exp_test_ab"),
          throwsA(predicate(
              (e) => e is StateError && e.message == notReadyMessage)));
      expect(
          () => context.getTreatment("exp_test_ab"),
          throwsA(predicate(
              (e) => e is StateError && e.message == notReadyMessage)));
      expect(
          () => context.getData(),
          throwsA(predicate(
              (e) => e is StateError && e.message == notReadyMessage)));
      expect(
          () => context.getExperiments(),
          throwsA(predicate(
              (e) => e is StateError && e.message == notReadyMessage)));
      expect(
          () => context.getVariableValue("banner.border", 17),
          throwsA(predicate(
              (e) => e is StateError && e.message == notReadyMessage)));
      expect(
          () => context.peekVariableValue("banner.border", 17),
          throwsA(predicate(
              (e) => e is StateError && e.message == notReadyMessage)));
      expect(
          () => context.getVariableKeys(),
          throwsA(predicate(
              (e) => e is StateError && e.message == notReadyMessage)));
    });

    test('throwsWhenClosing', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      context.track("goal1", {"amount": 125, "hours": 245});

      final publishFuture = Completer<void>();
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => publishFuture.future);

      context.closeAsync();

      expect(context.isClosing(), isTrue);
      expect(context.isClosed(), isFalse);

      const closingMessage = "ABSmartly Context is closing";
      expect(
          () => context.setAttribute("attr1", "value1"),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.setAttributes({"attr1": "value1"}),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.setOverride("exp_test_ab", 2),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.setOverrides({"exp_test_ab": 2}),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.setUnit("test", "test"),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.setCustomAssignment("exp_test_ab", 2),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.setCustomAssignments({"exp_test_ab": 2}),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.peekTreatment("exp_test_ab"),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.getTreatment("exp_test_ab"),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.track("goal1", null),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.publish(),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.getData(),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.getExperiments(),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.getVariableValue("banner.border", 17),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.peekVariableValue("banner.border", 17),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
      expect(
          () => context.getVariableKeys(),
          throwsA(predicate(
              (e) => e is StateError && e.message == closingMessage)));
    });

    test('throwsWhenClosed', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      context.track("goal1", {"amount": 125, "hours": 245});

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.close();

      expect(context.isClosing(), isFalse);
      expect(context.isClosed(), isTrue);

      const closedMessage = "ABSmartly Context is closed";
      expect(
          () => context.setAttribute("attr1", "value1"),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.setAttributes({"attr1": "value1"}),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.setOverride("exp_test_ab", 2),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.setOverrides({"exp_test_ab": 2}),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.setUnit("test", "test"),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.setCustomAssignment("exp_test_ab", 2),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.setCustomAssignments({"exp_test_ab": 2}),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.peekTreatment("exp_test_ab"),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.getTreatment("exp_test_ab"),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.track("goal1", null),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.publish(),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.getData(),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.getExperiments(),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.getVariableValue("banner.border", 17),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.peekVariableValue("banner.border", 17),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
      expect(
          () => context.getVariableKeys(),
          throwsA(
              predicate((e) => e is StateError && e.message == closedMessage)));
    });

    test('getExperiments', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      final experiments = data.experiments.map((e) => e.name).toList();
      expect(context.getExperiments(), equals(experiments));
    });

    test('startsRefreshTimerWhenReady', () async {
      final config =
          ContextConfig.create().setUnits(units).setRefreshInterval(5000);

      final context = createContext(config, dataFuture.future);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      dataFuture.complete(data);
      await context.waitUntilReady();

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFutureReady);

      // Verify refresh timer was started
      // Note: In Dart we can't directly verify the timer, but we can check the behavior
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify data provider wasn't called yet
      verifyNever(dataProvider.getContextData());
    });

    test('doesNotStartRefreshTimerWhenFailed', () async {
      final config =
          ContextConfig.create().setUnits(units).setRefreshInterval(5000);

      final context = createContext(config, dataFuture.future);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      dataFuture.completeError(Exception("test"));
      await context.waitUntilReady();

      expect(context.isFailed(), isTrue);

      // Verify data provider wasn't called
      verifyNever(dataProvider.getContextData());
    });

    test('startsPublishTimeoutWhenReadyWithQueueNotEmpty', () async {
      final config =
          ContextConfig.create().setUnits(units).setPublishDelay(333);

      final context = createContext(config, dataFuture.future);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      context.track("goal1", {"amount": 125});

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      dataFuture.complete(data);
      await context.waitUntilReady();

      // Verify publish wasn't called immediately
      verifyNever(eventHandler.publish(any, any));

      // Wait for publish delay
      await Future.delayed(const Duration(milliseconds: 400));

      // Verify publish was called after delay
      verify(eventHandler.publish(any, any)).called(1);
    });

    test('setUnits', () async {
      final context = createContext(ContextConfig.create(), dataFuture.future);
      context.setUnits(units);

      for (final entry in units.entries) {
        expect(context.getUnit(entry.key), equals(entry.value));
      }
      expect(context.getUnits(), equals(units));
    });

    test('setUnitsBeforeReady', () async {
      final context = createContext(ContextConfig.create(), dataFuture.future);
      expect(context.isReady(), isFalse);

      context.setUnits(units);

      dataFuture.complete(data);
      await context.waitUntilReady();

      context.getTreatment("exp_test_ab");

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        exposures: [
          Exposure(
              id: 1,
              name: "exp_test_ab",
              unit: "session_id",
              variant: 1,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
        ],
        goals: [],
        attributes: [],
      );

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      verify(eventHandler.publish(context, expected)).called(1);
    });

    test('setUnitEmpty', () {
      final context = createContext(null, dataFutureReady);
      expect(() => context.setUnit("db_user_id", ""), throwsArgumentError);
    });

    test('setUnitThrowsOnAlreadySet', () {
      final context = createContext(null, dataFutureReady);
      expect(
          () => context.setUnit("session_id", "new_uid"), throwsArgumentError);
    });

    test('setAttributes', () {
      final context = createContext(null, dataFuture.future);

      context.setAttribute("attr1", "value1");
      context.setAttributes({"attr2": "value2", "attr3": 15});

      expect(context.getAttribute("attr1"), equals("value1"));
      expect(context.getAttributes(),
          equals({"attr1": "value1", "attr2": "value2", "attr3": 15}));
    });

    test('setAttributesBeforeReady', () async {
      final context = createContext(null, dataFuture.future);
      expect(context.isReady(), isFalse);

      context.setAttribute("attr1", "value1");
      context.setAttributes({"attr2": "value2"});

      expect(context.getAttribute("attr1"), equals("value1"));
      expect(context.getAttributes(),
          equals({"attr1": "value1", "attr2": "value2"}));

      dataFuture.complete(data);
      await context.waitUntilReady();
    });

    test('setOverride', () {
      final context = createReadyContext();

      context.setOverride("exp_test", 2);
      expect(context.getOverride("exp_test"), equals(2));

      context.setOverride("exp_test", 3);
      expect(context.getOverride("exp_test"), equals(3));

      context.setOverride("exp_test_2", 1);
      expect(context.getOverride("exp_test_2"), equals(1));

      final Map<String, int> overrides = {
        "exp_test_new": 3,
        "exp_test_new_2": 5
      };

      context.setOverrides(overrides);

      expect(context.getOverride("exp_test"), equals(3));
      expect(context.getOverride("exp_test_2"), equals(1));
      overrides.forEach((experimentName, variant) =>
          expect(context.getOverride(experimentName), equals(variant)));

      expect(context.getOverride("exp_test_not_found"), isNull);
    });

    test('setOverrideClearsAssignmentCache', () {
      final context = createReadyContext();

      final Map<String, int> overrides = {
        "exp_test_new": 3,
        "exp_test_new_2": 5
      };

      context.setOverrides(overrides);

      overrides.forEach((experimentName, variant) =>
          expect(context.getTreatment(experimentName), equals(variant)));
      expect(context.getPendingCount(), equals(overrides.length));

      // overriding again with the same variant shouldn't clear assignment cache
      overrides.forEach((experimentName, variant) {
        context.setOverride(experimentName, variant);
        expect(context.getTreatment(experimentName), equals(variant));
      });
      expect(context.getPendingCount(), equals(overrides.length));

      // overriding with the different variant should clear assignment cache
      overrides.forEach((experimentName, variant) {
        context.setOverride(experimentName, variant + 11);
        expect(context.getTreatment(experimentName), equals(variant + 11));
      });

      expect(context.getPendingCount(), equals(overrides.length * 2));

      // overriding a computed assignment should clear assignment cache
      expect(context.getTreatment("exp_test_ab"),
          equals(expectedVariants["exp_test_ab"]));
      expect(context.getPendingCount(), equals(1 + overrides.length * 2));

      context.setOverride("exp_test_ab", 9);
      expect(context.getTreatment("exp_test_ab"), equals(9));
      expect(context.getPendingCount(), equals(2 + overrides.length * 2));
    });

    test('setOverridesBeforeReady', () async {
      final context = createContext(null, dataFuture.future);
      expect(context.isReady(), isFalse);

      context.setOverride("exp_test", 2);
      context.setOverrides({"exp_test_new": 3, "exp_test_new_2": 5});

      dataFuture.complete(data);
      await context.waitUntilReady();

      expect(context.getOverride("exp_test"), equals(2));
      expect(context.getOverride("exp_test_new"), equals(3));
      expect(context.getOverride("exp_test_new_2"), equals(5));
    });

    test('setCustomAssignment', () {
      final context = createReadyContext();
      context.setCustomAssignment("exp_test", 2);

      expect(context.getCustomAssignment("exp_test"), equals(2));

      context.setCustomAssignment("exp_test", 3);
      expect(context.getCustomAssignment("exp_test"), equals(3));

      context.setCustomAssignment("exp_test_2", 1);
      expect(context.getCustomAssignment("exp_test_2"), equals(1));

      final Map<String, int> cassignments = {
        "exp_test_new": 3,
        "exp_test_new_2": 5
      };

      context.setCustomAssignments(cassignments);

      expect(context.getCustomAssignment("exp_test"), equals(3));
      expect(context.getCustomAssignment("exp_test_2"), equals(1));
      cassignments.forEach((experimentName, variant) =>
          expect(context.getCustomAssignment(experimentName), equals(variant)));

      expect(context.getCustomAssignment("exp_test_not_found"), isNull);
    });

    test('setCustomAssignmentDoesNotOverrideFullOnOrNotEligibleAssignments',
        () async {
      final context = createReadyContext();

      context.setCustomAssignment("exp_test_not_eligible", 3);
      context.setCustomAssignment("exp_test_fullon", 3);

      expect(context.getTreatment("exp_test_not_eligible"), equals(0));
      expect(context.getTreatment("exp_test_fullon"), equals(2));
    });

    test('setCustomAssignmentClearsAssignmentCache', () {
      final context = createReadyContext();

      final Map<String, int> cassignments = {
        "exp_test_ab": 2,
        "exp_test_abc": 3
      };

      cassignments.forEach((experimentName, variant) => expect(
          context.getTreatment(experimentName),
          equals(expectedVariants[experimentName])));
      expect(context.getPendingCount(), equals(cassignments.length));

      context.setCustomAssignments(cassignments);

      cassignments.forEach((experimentName, variant) =>
          expect(context.getTreatment(experimentName), equals(variant)));
      expect(context.getPendingCount(), equals(2 * cassignments.length));

      // overriding again with the same variant shouldn't clear assignment cache
      cassignments.forEach((experimentName, variant) {
        context.setCustomAssignment(experimentName, variant);
        expect(context.getTreatment(experimentName), equals(variant));
      });
      expect(context.getPendingCount(), equals(2 * cassignments.length));

      // overriding with the different variant should clear assignment cache
      cassignments.forEach((experimentName, variant) {
        context.setCustomAssignment(experimentName, variant + 11);
        expect(context.getTreatment(experimentName), equals(variant + 11));
      });

      expect(context.getPendingCount(), equals(cassignments.length * 3));
    });

    test('setCustomAssignmentsBeforeReady', () async {
      final context = createContext(null, dataFuture.future);
      expect(context.isReady(), isFalse);

      context.setCustomAssignment("exp_test", 2);
      context.setCustomAssignments({"exp_test_new": 3, "exp_test_new_2": 5});

      dataFuture.complete(data);
      await context.waitUntilReady();

      expect(context.getCustomAssignment("exp_test"), equals(2));
      expect(context.getCustomAssignment("exp_test_new"), equals(3));
      expect(context.getCustomAssignment("exp_test_new_2"), equals(5));
    });

    test('peekTreatment', () {
      final context = createReadyContext();

      for (var experiment in data.experiments) {
        expect(context.peekTreatment(experiment.name),
            equals(expectedVariants[experiment.name]));
      }
      expect(context.peekTreatment("not_found"), equals(0));

      // call again
      for (var experiment in data.experiments) {
        expect(context.peekTreatment(experiment.name),
            equals(expectedVariants[experiment.name]));
      }
      expect(context.peekTreatment("not_found"), equals(0));

      expect(context.getPendingCount(), equals(0));
    });

    test('peekVariableValue', () {
      final context = createReadyContext();

      final Set<String> experiments =
          data.experiments.map((x) => x.name).toSet();

      variableExperiments.forEach((variable, experimentNames) {
        final String experimentName = experimentNames[0];
        final actual = context.peekVariableValue(variable, 17);
        final bool eligible = experimentName != "exp_test_not_eligible";

        if (eligible && experiments.contains(experimentName)) {
          expect(actual, equals(expectedVariables[variable]));
        } else {
          expect(actual, equals(17));
        }
      });

      expect(context.getPendingCount(), equals(0));
    });

    test('peekVariableValueConflictingKeyDisjointAudiences', () {
      for (final experiment in data.experiments) {
        switch (experiment.name) {
          case "exp_test_ab":
            assert(expectedVariants[experiment.name] != 0);
            experiment.audienceStrict = true;
            experiment.audience =
                "{\"filter\":[{\"gte\":[{\"var\":\"age\"},{\"value\":20}]}]}";
            experiment.variants[expectedVariants[experiment.name]!].config =
                "{\"icon\":\"arrow\"}";
            break;
          case "exp_test_abc":
            assert(expectedVariants[experiment.name] != 0);
            experiment.audienceStrict = true;
            experiment.audience =
                "{\"filter\":[{\"lt\":[{\"var\":\"age\"},{\"value\":20}]}]}";
            experiment.variants[expectedVariants[experiment.name]!].config =
                "{\"icon\":\"circle\"}";
            break;
          default:
            break;
        }
      }

      {
        final context = createReadyContext(data);
        context.setAttribute("age", 20);
        expect(context.peekVariableValue("icon", "square"), equals("arrow"));
      }

      {
        final context = createReadyContext(data);
        context.setAttribute("age", 19);
        expect(context.peekVariableValue("icon", "square"), equals("circle"));
      }
    });

    test('peekVariableValuePicksLowestExperimentIdOnConflictingKey', () {
      for (final experiment in data.experiments) {
        switch (experiment.name) {
          case "exp_test_ab":
            assert(expectedVariants[experiment.name] != 0);
            experiment.id = 99;
            experiment.variants[expectedVariants[experiment.name]!].config =
                "{\"icon\":\"arrow\"}";
            break;
          case "exp_test_abc":
            assert(expectedVariants[experiment.name] != 0);
            experiment.id = 1;
            experiment.variants[expectedVariants[experiment.name]!].config =
                "{\"icon\":\"circle\"}";
            break;
          default:
            break;
        }
      }

      final context = createReadyContext(data);
      expect(context.peekVariableValue("icon", "square"), equals("circle"));
    });

    test(
        'peekVariableValueReturnsAssignedVariantOnAudienceMismatchNonStrictMode',
        () {
      final context = createContext(null, audienceDataFutureReady);
      expect(
          context.peekVariableValue("banner.size", "small"), equals("large"));
    });

    test('peekVariableValueReturnsControlVariantOnAudienceMismatchStrictMode',
        () {
      final context = createContext(null, audienceStrictDataFutureReady);
      expect(
          context.peekVariableValue("banner.size", "small"), equals("small"));
    });

    test('getVariableValue', () {
      final context = createReadyContext();

      final Set<String> experiments =
          data.experiments.map((x) => x.name).toSet();

      variableExperiments.forEach((variable, experimentNames) {
        final String experimentName = experimentNames[0];
        final actual = context.getVariableValue(variable, 17);
        final bool eligible = experimentName != "exp_test_not_eligible";

        if (eligible && experiments.contains(experimentName)) {
          expect(actual, equals(expectedVariables[variable]));
        } else {
          expect(actual, equals(17));
        }
      });

      expect(context.getPendingCount(), equals(experiments.length));
    });

    test('getVariableValueConflictingKeyDisjointAudiences', () {
      for (final experiment in data.experiments) {
        switch (experiment.name) {
          case "exp_test_ab":
            assert(expectedVariants[experiment.name] != 0);
            experiment.audienceStrict = true;
            experiment.audience =
                "{\"filter\":[{\"gte\":[{\"var\":\"age\"},{\"value\":20}]}]}";
            experiment.variants[expectedVariants[experiment.name]!].config =
                "{\"icon\":\"arrow\"}";
            break;
          case "exp_test_abc":
            assert(expectedVariants[experiment.name] != 0);
            experiment.audienceStrict = true;
            experiment.audience =
                "{\"filter\":[{\"lt\":[{\"var\":\"age\"},{\"value\":20}]}]}";
            experiment.variants[expectedVariants[experiment.name]!].config =
                "{\"icon\":\"circle\"}";
            break;
          default:
            break;
        }
      }

      {
        final context = createReadyContext(data);
        context.setAttribute("age", 20);
        expect(context.getVariableValue("icon", "square"), equals("arrow"));
        expect(context.getPendingCount(), equals(1));
      }

      {
        final context = createReadyContext(data);
        context.setAttribute("age", 19);
        expect(context.getVariableValue("icon", "square"), equals("circle"));
        expect(context.getPendingCount(), equals(1));
      }
    });

    test(
        'getVariableValueQueuesExposureWithAudienceMismatchFalseOnAudienceMatch',
        () async {
      final context = createContext(null, audienceDataFutureReady);
      context.setAttribute("age", 21);

      expect(context.getVariableValue("banner.size", "small"), equals("large"));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        attributes: [
          Attribute(name: "age", value: 21, setAt: clock.millis()),
        ],
        exposures: [
          Exposure(
              id: 1,
              name: "exp_test_ab",
              unit: "session_id",
              variant: 1,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
        ],
        goals: [],
      );

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      verify(eventHandler.publish(context, expected)).called(1);
    });

    test(
        'getVariableValueQueuesExposureWithAudienceMismatchTrueOnAudienceMismatch',
        () async {
      final context = createContext(null, audienceDataFutureReady);

      expect(context.getVariableValue("banner.size", "small"), equals("large"));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        exposures: [
          Exposure(
              id: 1,
              name: "exp_test_ab",
              unit: "session_id",
              variant: 1,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: true),
        ],
        goals: [],
        attributes: [],
      );

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      verify(eventHandler.publish(context, expected)).called(1);
    });

    test(
        'getVariableValueDoesNotQueuesExposureWithAudienceMismatchFalseAndControlVariantOnAudienceMismatchInStrictMode',
        () {
      final context = createContext(null, audienceStrictDataFutureReady);

      expect(context.getVariableValue("banner.size", "small"), equals("small"));
      expect(context.getPendingCount(), equals(0));
    });

    test('getVariableValueCallsEventLogger', () {
      final context = createReadyContext();

      clearInteractions(eventLogger);

      context.getVariableValue("banner.border", null);
      context.getVariableValue("banner.size", null);

      final exposures = [
        Exposure(
            id: 1,
            name: "exp_test_ab",
            unit: "session_id",
            variant: 1,
            exposedAt: clock.millis(),
            assigned: true,
            eligible: true,
            overridden: false,
            fullOn: false,
            custom: false,
            audienceMismatch: false),
      ];

      verify(eventLogger.handleEvent(any, any, any)).called(exposures.length);

      for (var expected in exposures) {
        verify(eventLogger.handleEvent(context, EventType.Exposure, expected))
            .called(1);
      }

      // verify not called again with the same exposure
      clearInteractions(eventLogger);
      context.getVariableValue("banner.border", null);
      context.getVariableValue("banner.size", null);

      verifyNever(eventLogger.handleEvent(any, any, any));
    });

    test('getVariableKeys', () async {
      final context = createContext(null, refreshDataFutureReady);
      expect(context.getVariableKeys(), equals(variableExperiments));
    });

    test('peekTreatmentReturnsOverrideVariant', () {
      final context = createReadyContext();

      for (var experiment in data.experiments) {
        context.setOverride(
            experiment.name, 11 + expectedVariants[experiment.name]!);
      }
      context.setOverride("not_found", 3);

      for (var experiment in data.experiments) {
        expect(context.peekTreatment(experiment.name),
            equals(expectedVariants[experiment.name]! + 11));
      }
      expect(context.peekTreatment("not_found"), equals(3));

      // call again
      for (var experiment in data.experiments) {
        expect(context.peekTreatment(experiment.name),
            equals(expectedVariants[experiment.name]! + 11));
      }
      expect(context.peekTreatment("not_found"), equals(3));

      expect(context.getPendingCount(), equals(0));
    });

    test('peekTreatmentReturnsAssignedVariantOnAudienceMismatchNonStrictMode',
        () {
      final context = createContext(null, audienceDataFutureReady);
      expect(context.peekTreatment("exp_test_ab"), equals(1));
    });

    test('peekTreatmentReturnsControlVariantOnAudienceMismatchStrictMode', () {
      final context = createContext(null, audienceStrictDataFutureReady);
      expect(context.peekTreatment("exp_test_ab"), equals(0));
    });

    test('getTreatment', () async {
      final context = createReadyContext();

      for (var experiment in data.experiments) {
        expect(context.getTreatment(experiment.name),
            equals(expectedVariants[experiment.name]));
      }
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(1 + data.experiments.length));

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        exposures: [
          Exposure(
              id: 1,
              name: "exp_test_ab",
              unit: "session_id",
              variant: 1,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
          Exposure(
              id: 2,
              name: "exp_test_abc",
              unit: "session_id",
              variant: 2,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
          Exposure(
              id: 3,
              name: "exp_test_not_eligible",
              unit: "user_id",
              variant: 0,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: false,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
          Exposure(
              id: 4,
              name: "exp_test_fullon",
              unit: "session_id",
              variant: 2,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: true,
              overridden: false,
              fullOn: true,
              custom: false,
              audienceMismatch: false),
          Exposure(
              id: 0,
              name: "not_found",
              unit: null,
              variant: 0,
              exposedAt: clock.millis(),
              assigned: false,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
        ],
        goals: [],
        attributes: [],
      );

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      verify(eventHandler.publish(context, expected)).called(1);

      await context.close();
    });

    test('getTreatmentStartsPublishTimeoutAfterExposure', () async {
      final config =
          ContextConfig.create().setUnits(units).setPublishDelay(333);

      final context = createContext(config, dataFutureReady);
      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      context.getTreatment("exp_test_ab");
      context.getTreatment("exp_test_abc");

      // Verify publish wasn't called immediately
      verifyNever(eventHandler.publish(any, any));

      // Wait for publish delay
      await Future.delayed(const Duration(milliseconds: 400));

      // Verify publish was called after delay
      verify(eventHandler.publish(any, any)).called(1);
    });

    test('getTreatmentReturnsOverrideVariant', () async {
      final context = createReadyContext();

      for (var experiment in data.experiments) {
        context.setOverride(
            experiment.name, 11 + expectedVariants[experiment.name]!);
      }
      context.setOverride("not_found", 3);

      for (var experiment in data.experiments) {
        expect(context.getTreatment(experiment.name),
            equals(expectedVariants[experiment.name]! + 11));
      }
      expect(context.getTreatment("not_found"), equals(3));
      expect(context.getPendingCount(), equals(1 + data.experiments.length));

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        exposures: [
          Exposure(
              id: 1,
              name: "exp_test_ab",
              unit: "session_id",
              variant: 12,
              exposedAt: clock.millis(),
              assigned: false,
              eligible: true,
              overridden: true,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
          Exposure(
              id: 2,
              name: "exp_test_abc",
              unit: "session_id",
              variant: 13,
              exposedAt: clock.millis(),
              assigned: false,
              eligible: true,
              overridden: true,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
          Exposure(
              id: 3,
              name: "exp_test_not_eligible",
              unit: "user_id",
              variant: 11,
              exposedAt: clock.millis(),
              assigned: false,
              eligible: true,
              overridden: true,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
          Exposure(
              id: 4,
              name: "exp_test_fullon",
              unit: "session_id",
              variant: 13,
              exposedAt: clock.millis(),
              assigned: false,
              eligible: true,
              overridden: true,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
          Exposure(
              id: 0,
              name: "not_found",
              unit: null,
              variant: 3,
              exposedAt: clock.millis(),
              assigned: false,
              eligible: true,
              overridden: true,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
        ],
        goals: [],
        attributes: [],
      );

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      verify(eventHandler.publish(context, expected)).called(1);

      await context.close();
    });

    test('getTreatmentQueuesExposureOnce', () async {
      final context = createReadyContext();

      for (var experiment in data.experiments) {
        context.getTreatment(experiment.name);
      }
      context.getTreatment("not_found");

      expect(context.getPendingCount(), equals(1 + data.experiments.length));

      // call again
      for (var experiment in data.experiments) {
        context.getTreatment(experiment.name);
      }
      context.getTreatment("not_found");

      expect(context.getPendingCount(), equals(1 + data.experiments.length));

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);

      expect(context.getPendingCount(), equals(0));

      for (var experiment in data.experiments) {
        context.getTreatment(experiment.name);
      }
      context.getTreatment("not_found");
      expect(context.getPendingCount(), equals(0));

      await context.close();
    });

    test('getTreatmentQueuesExposureWithAudienceMismatchFalseOnAudienceMatch',
        () async {
      final context = createContext(null, audienceDataFutureReady);
      context.setAttribute("age", 21);

      expect(context.getTreatment("exp_test_ab"), equals(1));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        attributes: [
          Attribute(name: "age", value: 21, setAt: clock.millis()),
        ],
        exposures: [
          Exposure(
              id: 1,
              name: "exp_test_ab",
              unit: "session_id",
              variant: 1,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
        ],
        goals: [],
      );

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      verify(eventHandler.publish(context, expected)).called(1);
    });

    test('getTreatmentQueuesExposureWithAudienceMismatchTrueOnAudienceMismatch',
        () async {
      final context = createContext(null, audienceDataFutureReady);

      expect(context.getTreatment("exp_test_ab"), equals(1));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        exposures: [
          Exposure(
              id: 1,
              name: "exp_test_ab",
              unit: "session_id",
              variant: 1,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: true),
        ],
        goals: [],
        attributes: [],
      );

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      verify(eventHandler.publish(context, expected)).called(1);
    });

    test(
        'getTreatmentQueuesExposureWithAudienceMismatchTrueAndControlVariantOnAudienceMismatchInStrictMode',
        () async {
      final context = createContext(null, audienceStrictDataFutureReady);

      expect(context.getTreatment("exp_test_ab"), equals(0));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        exposures: [
          Exposure(
              id: 1,
              name: "exp_test_ab",
              unit: "session_id",
              variant: 0,
              exposedAt: clock.millis(),
              assigned: false,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: true),
        ],
        goals: [],
        attributes: [],
      );

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      verify(eventHandler.publish(context, expected)).called(1);
    });

    test('getTreatmentCallsEventLogger', () {
      final context = createReadyContext();

      clearInteractions(eventLogger);

      context.getTreatment("exp_test_ab");
      context.getTreatment("not_found");

      final exposures = [
        Exposure(
            id: 1,
            name: "exp_test_ab",
            unit: "session_id",
            variant: 1,
            exposedAt: clock.millis(),
            assigned: true,
            eligible: true,
            overridden: false,
            fullOn: false,
            custom: false,
            audienceMismatch: false),
        Exposure(
            id: 0,
            name: "not_found",
            unit: null,
            variant: 0,
            exposedAt: clock.millis(),
            assigned: false,
            eligible: true,
            overridden: false,
            fullOn: false,
            custom: false,
            audienceMismatch: false),
      ];

      verify(eventLogger.handleEvent(any, any, any)).called(exposures.length);

      for (var expected in exposures) {
        verify(eventLogger.handleEvent(context, EventType.Exposure, expected))
            .called(1);
      }

      // verify not called again with the same exposure
      clearInteractions(eventLogger);
      context.getTreatment("exp_test_ab");
      context.getTreatment("not_found");

      verifyNever(eventLogger.handleEvent(any, any, any));
    });

    test('track', () async {
      final context = createReadyContext();
      context.track("goal1", {"amount": 125, "hours": 245});
      context.track("goal2", {"tries": 7});

      expect(context.getPendingCount(), equals(2));

      context.track("goal2", {"tests": 12});
      context.track("goal3", null);

      expect(context.getPendingCount(), equals(4));

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        goals: [
          GoalAchievement(
              name: "goal1",
              achievedAt: clock.millis(),
              properties: {"amount": 125, "hours": 245}),
          GoalAchievement(
              name: "goal2",
              achievedAt: clock.millis(),
              properties: {"tries": 7}),
          GoalAchievement(
              name: "goal2",
              achievedAt: clock.millis(),
              properties: {"tests": 12}),
          GoalAchievement(
              name: "goal3", achievedAt: clock.millis(), properties: null),
        ],
        exposures: [],
        attributes: [],
      );

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      verify(eventHandler.publish(context, expected)).called(1);

      await context.close();
    });

    test('trackCallsEventLogger', () {
      final context = createReadyContext();
      clearInteractions(eventLogger);

      final Map<String, dynamic> properties = {"amount": 125, "hours": 245};
      context.track("goal1", properties);

      final achievements = [
        GoalAchievement(
            name: "goal1", achievedAt: clock.millis(), properties: properties)
      ];

      verify(eventLogger.handleEvent(any, any, any))
          .called(achievements.length);

      for (var goal in achievements) {
        verify(eventLogger.handleEvent(context, EventType.Goal, goal))
            .called(1);
      }

      // verify called again with the same goal
      clearInteractions(eventLogger);
      context.track("goal1", properties);

      for (var goal in achievements) {
        verify(eventLogger.handleEvent(context, EventType.Goal, goal))
            .called(1);
      }
    });

    test('trackStartsPublishTimeoutAfterAchievement', () async {
      final config =
          ContextConfig.create().setUnits(units).setPublishDelay(333);

      final context = createContext(config, dataFutureReady);
      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      context.track("goal1", {"amount": 125});
      context.track("goal2", {"value": 999.0});

      // Verify publish wasn't called immediately
      verifyNever(eventHandler.publish(any, any));

      // Wait for publish delay
      await Future.delayed(const Duration(milliseconds: 400));

      // Verify publish was called after delay
      verify(eventHandler.publish(any, any)).called(1);
    });

    test('trackQueuesWhenNotReady', () {
      final context = createContext(null, dataFuture.future);

      context.track("goal1", {"amount": 125, "hours": 245});
      context.track("goal2", {"tries": 7});
      context.track("goal3", null);

      expect(context.getPendingCount(), equals(3));
    });

    test('publishDoesNotCallEventHandlerWhenQueueIsEmpty', () async {
      final context = createReadyContext();
      expect(context.getPendingCount(), equals(0));

      await context.publish();

      verifyNever(eventHandler.publish(any, any));
    });

    test('publishCallsEventLogger', () async {
      final context = createReadyContext();

      context.track("goal1", {"amount": 125, "hours": 245});

      clearInteractions(eventLogger);

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        goals: [
          GoalAchievement(
              name: "goal1",
              achievedAt: clock.millis(),
              properties: {"amount": 125, "hours": 245}),
        ],
        exposures: [],
        attributes: [],
      );

      when(eventHandler.publish(context, expected))
          .thenAnswer((_) => Future.value());

      await context.publish();

      verify(eventLogger.handleEvent(context, EventType.Publish, expected))
          .called(1);
    });

    test('publishCallsEventLoggerOnError', () async {
      final context = createReadyContext();

      context.track("goal1", {"amount": 125, "hours": 245});

      clearInteractions(eventLogger);

      final failure = Exception("ERROR");
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => Future.error(failure));

      expect(() => context.publish(), throwsA(isA<Exception>()));

      verify(eventLogger.handleEvent(context, EventType.Error, failure))
          .called(1);
    });

    test(
        'publishResetsInternalQueuesAndKeepsAttributesOverridesAndCustomAssignments',
        () async {
      final config = ContextConfig.create()
          .setUnits(units)
          .setAttributes({"attr1": "value1", "attr2": "value2"})
          .setCustomAssignment("exp_test_abc", 3)
          .setOverride("not_found", 3);

      final context = createContext(config, dataFutureReady);

      expect(context.getPendingCount(), equals(0));

      expect(context.getTreatment("exp_test_ab"), equals(1));
      expect(context.getTreatment("exp_test_abc"), equals(3));
      expect(context.getTreatment("not_found"), equals(3));
      context.track("goal1", {"amount": 125, "hours": 245});

      expect(context.getPendingCount(), equals(4));

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        exposures: [
          Exposure(
              id: 1,
              name: "exp_test_ab",
              unit: "session_id",
              variant: 1,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
          Exposure(
              id: 2,
              name: "exp_test_abc",
              unit: "session_id",
              variant: 3,
              exposedAt: clock.millis(),
              assigned: true,
              eligible: true,
              overridden: false,
              fullOn: false,
              custom: true,
              audienceMismatch: false),
          Exposure(
              id: 0,
              name: "not_found",
              unit: null,
              variant: 3,
              exposedAt: clock.millis(),
              assigned: false,
              eligible: true,
              overridden: true,
              fullOn: false,
              custom: false,
              audienceMismatch: false),
        ],
        goals: [
          GoalAchievement(
              name: "goal1",
              achievedAt: clock.millis(),
              properties: {"amount": 125, "hours": 245}),
        ],
        attributes: [
          Attribute(name: "attr2", value: "value2", setAt: clock.millis()),
          Attribute(name: "attr1", value: "value1", setAt: clock.millis()),
        ],
      );

      when(eventHandler.publish(context, expected))
          .thenAnswer((_) => Future.value());

      final future = context.publishAsync();
      expect(context.getPendingCount(), equals(0));
      expect(context.getCustomAssignment("exp_test_abc"), equals(3));
      expect(context.getOverride("not_found"), equals(3));

      await future;
      expect(context.getPendingCount(), equals(0));
      expect(context.getCustomAssignment("exp_test_abc"), equals(3));
      expect(context.getOverride("not_found"), equals(3));

      verify(eventHandler.publish(context, expected)).called(1);

      clearInteractions(eventHandler);

      // repeat
      expect(context.getTreatment("exp_test_ab"), equals(1));
      expect(context.getTreatment("exp_test_abc"), equals(3));
      expect(context.getTreatment("not_found"), equals(3));
      context.track("goal1", {"amount": 125, "hours": 245});

      expect(context.getPendingCount(), equals(1));

      final PublishEvent expectedNext = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        goals: [
          GoalAchievement(
              name: "goal1",
              achievedAt: clock.millis(),
              properties: {"amount": 125, "hours": 245}),
        ],
        attributes: [
          Attribute(name: "attr2", value: "value2", setAt: clock.millis()),
          Attribute(name: "attr1", value: "value1", setAt: clock.millis()),
        ],
        exposures: [],
      );

      when(eventHandler.publish(context, expectedNext))
          .thenAnswer((_) => Future.value());

      final futureNext = context.publishAsync();
      expect(context.getPendingCount(), equals(0));

      await futureNext;
      expect(context.getPendingCount(), equals(0));

      verify(eventHandler.publish(context, expectedNext)).called(1);
    });

    test('publishDoesNotCallEventHandlerWhenFailed', () async {
      final context = createContext(null, dataFutureFailed);
      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isTrue);

      context.getTreatment("exp_test_abc");
      context.track("goal1", {"amount": 125, "hours": 245});

      expect(context.getPendingCount(), equals(2));

      when(eventHandler.publish(any, any)).thenAnswer((_) => Future.value());

      await context.publish();

      verifyNever(eventHandler.publish(any, any));
    });

    test('publishExceptionally', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      context.track("goal1", {"amount": 125, "hours": 245});

      expect(context.getPendingCount(), equals(1));

      final failure = Exception("FAILED");
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => Future.error(failure));

      expect(() => context.publish(), throwsA(isA<Exception>()));

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('closeAsync', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      context.track("goal1", {"amount": 125, "hours": 245});

      final publishFuture = Completer<void>();
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => publishFuture.future);

      final closingFuture = context.closeAsync();
      final closingFutureNext = context.closeAsync();
      expect(closingFuture, same(closingFutureNext));

      expect(context.isClosing(), isTrue);
      expect(context.isClosed(), isFalse);

      publishFuture.complete();

      await closingFuture;

      expect(context.isClosing(), isFalse);
      expect(context.isClosed(), isTrue);

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('close', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      context.track("goal1", {"amount": 125, "hours": 245});

      final publishFuture = Completer<void>();
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => publishFuture.future);

      expect(context.isClosing(), isFalse);
      expect(context.isClosed(), isFalse);

      // Use a microtask to complete the future after the close call
      scheduleMicrotask(() => publishFuture.complete());

      await context.close();

      expect(context.isClosing(), isFalse);
      expect(context.isClosed(), isTrue);

      verify(eventHandler.publish(any, any)).called(1);

      await context.close();
    });

    test('closeCallsEventLogger', () async {
      final context = createReadyContext();

      clearInteractions(eventLogger);

      await context.close();

      verify(eventLogger.handleEvent(context, EventType.Close, null)).called(1);
    });

    test('closeCallsEventLoggerWithPendingEvents', () async {
      final context = createReadyContext();

      context.track("goal1", {"amount": 125, "hours": 245});

      clearInteractions(eventLogger);

      final PublishEvent expected = PublishEvent(
        hashed: true,
        publishedAt: clock.millis(),
        units: publishUnits,
        goals: [
          GoalAchievement(
              name: "goal1",
              achievedAt: clock.millis(),
              properties: {"amount": 125, "hours": 245}),
        ],
        exposures: [],
        attributes: [],
      );

      final publishFuture = Completer<void>();
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => publishFuture.future);

      // Use a microtask to complete the future after the close call
      scheduleMicrotask(() => publishFuture.complete());

      await context.close();

      verify(eventLogger.handleEvent(context, EventType.Publish, expected))
          .called(1);
      verify(eventLogger.handleEvent(context, EventType.Close, null)).called(1);
    });

    test('closeCallsEventLoggerOnError', () async {
      final context = createReadyContext();

      context.track("goal1", {"amount": 125, "hours": 245});

      clearInteractions(eventLogger);

      final publishFuture = Completer<void>();
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => publishFuture.future);

      final failure = Exception("FAILED");

      // Use a microtask to complete the future after the close call
      scheduleMicrotask(() => publishFuture.completeError(failure));

      expect(() => context.close(), throwsA(isA<Exception>()));

      verify(eventLogger.handleEvent(context, EventType.Error, failure))
          .called(1);
    });

    test('closeExceptionally', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      context.track("goal1", {"amount": 125, "hours": 245});

      final publishFuture = Completer<void>();
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => publishFuture.future);

      final failure = Exception("FAILED");

      // Use a microtask to complete the future after the close call
      scheduleMicrotask(() => publishFuture.completeError(failure));

      expect(() => context.close(), throwsA(isA<Exception>()));

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('refresh', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFuture.future);
      refreshDataFuture.complete(refreshData);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      final experiments = refreshData.experiments.map((x) => x.name).toList();
      expect(context.getExperiments(), equals(experiments));
    });

    test('refreshCallsEventLogger', () async {
      final context = createReadyContext();
      clearInteractions(eventLogger);

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFuture.future);
      refreshDataFuture.complete(refreshData);

      await context.refresh();

      verify(eventLogger.handleEvent(context, EventType.Refresh, refreshData))
          .called(1);
    });

    test('refreshCallsEventLoggerOnError', () async {
      final context = createReadyContext();
      clearInteractions(eventLogger);

      final failure = Exception("ERROR");
      when(dataProvider.getContextData())
          .thenAnswer((_) => Future.error(failure));
      refreshDataFuture.complete(refreshData);

      expect(() => context.refresh(), throwsA(isA<Exception>()));

      verify(eventLogger.handleEvent(context, EventType.Error, failure))
          .called(1);
    });

    test('refreshExceptionally', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      context.track("goal1", {"amount": 125, "hours": 245});

      expect(context.getPendingCount(), equals(1));

      final failure = Exception("FAILED");
      when(dataProvider.getContextData())
          .thenAnswer((_) => Future.error(failure));

      expect(() => context.refresh(), throwsA(isA<Exception>()));

      verify(dataProvider.getContextData()).called(1);
    });

    test('refreshAsync', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFuture.future);

      final refreshFuture = context.refreshAsync();
      final refreshFutureNext = context.refreshAsync();
      expect(refreshFuture, same(refreshFutureNext));

      refreshDataFuture.complete(refreshData);
      await refreshFuture;

      verify(dataProvider.getContextData()).called(1);

      final experiments = refreshData.experiments.map((x) => x.name).toList();
      expect(context.getExperiments(), equals(experiments));
    });

    test('refreshKeepsAssignmentCacheWhenNotChanged', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      for (var experiment in data.experiments) {
        context.getTreatment(experiment.name);
      }
      context.getTreatment("not_found");

      expect(context.getPendingCount(), equals(data.experiments.length + 1));

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFuture.future);

      final refreshFuture = context.refreshAsync();

      verify(dataProvider.getContextData()).called(1);

      refreshDataFuture.complete(refreshData);
      await refreshFuture;

      for (var experiment in refreshData.experiments) {
        context.getTreatment(experiment.name);
      }
      context.getTreatment("not_found");

      expect(context.getPendingCount(),
          equals(refreshData.experiments.length + 1));
    });

    test('refreshKeepsAssignmentCacheWhenNotChangedOnAudienceMismatch',
        () async {
      final context = createContext(null, audienceStrictDataFutureReady);

      expect(context.getTreatment("exp_test_ab"), equals(0));
      expect(context.getPendingCount(), equals(1));

      when(dataProvider.getContextData())
          .thenAnswer((_) => audienceStrictDataFutureReady);

      final refreshFuture = context.refreshAsync();

      verify(dataProvider.getContextData()).called(1);

      await refreshFuture;

      expect(context.getTreatment("exp_test_ab"), equals(0));
      expect(context.getPendingCount(), equals(1)); // no new exposure
    });

    test('refreshKeepsAssignmentCacheWhenNotChangedWithOverride', () async {
      final context = createReadyContext();

      context.setOverride("exp_test_ab", 3);
      expect(context.getTreatment("exp_test_ab"), equals(3));
      expect(context.getPendingCount(), equals(1));

      when(dataProvider.getContextData()).thenAnswer((_) => dataFutureReady);

      final refreshFuture = context.refreshAsync();

      verify(dataProvider.getContextData()).called(1);

      await refreshFuture;

      expect(context.getTreatment("exp_test_ab"), equals(3));
      expect(context.getPendingCount(), equals(1)); // no new exposure
    });

    test('refreshClearAssignmentCacheForStoppedExperiment', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_abc";
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFuture.future);

      final refreshFuture = context.refreshAsync();

      verify(dataProvider.getContextData()).called(1);

      // Filter out the experiment from refreshData
      refreshData.experiments = refreshData.experiments
          .where((x) => x.name != experimentName)
          .toList();

      refreshDataFuture.complete(refreshData);
      await refreshFuture;

      expect(context.getTreatment(experimentName), equals(0));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(),
          equals(3)); // stopped experiment triggered a new exposure
    });

    test('refreshClearAssignmentCacheForStartedExperiment', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_new";
      expect(context.getTreatment(experimentName), equals(0));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFuture.future);

      final refreshFuture = context.refreshAsync();

      verify(dataProvider.getContextData()).called(1);

      refreshDataFuture.complete(refreshData);
      await refreshFuture;

      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(),
          equals(3)); // started experiment triggered a new exposure
    });

    test('refreshClearAssignmentCacheForFullOnExperiment', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_abc";
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFuture.future);

      final refreshFuture = context.refreshAsync();

      verify(dataProvider.getContextData()).called(1);

      // Modify the fullOnVariant for the experiment in refreshData
      for (var experiment in refreshData.experiments) {
        if (experiment.name == experimentName) {
          expect(experiment.fullOnVariant, equals(0));
          experiment.fullOnVariant = 1;
          expect(experiment.fullOnVariant != expectedVariants[experimentName],
              isTrue);
        }
      }

      refreshDataFuture.complete(refreshData);
      await refreshFuture;

      expect(context.getTreatment(experimentName), equals(1));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(),
          equals(3)); // full-on experiment triggered a new exposure
    });

    test('refreshClearAssignmentCacheForTrafficSplitChange', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_not_eligible";
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFuture.future);

      final refreshFuture = context.refreshAsync();

      verify(dataProvider.getContextData()).called(1);

      // Modify the trafficSplit for the experiment in refreshData
      for (var experiment in refreshData.experiments) {
        if (experiment.name == experimentName) {
          experiment.trafficSplit = [0.0, 1.0];
        }
      }

      refreshDataFuture.complete(refreshData);
      await refreshFuture;

      expect(context.getTreatment(experimentName), equals(2));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(),
          equals(3)); // newly eligible experiment triggered a new exposure
    });

    test('refreshClearAssignmentCacheForIterationChange', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_abc";
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFuture.future);

      final refreshFuture = context.refreshAsync();

      verify(dataProvider.getContextData()).called(1);

      // Modify the iteration and seeds for the experiment in refreshData
      for (var experiment in refreshData.experiments) {
        if (experiment.name == experimentName) {
          experiment.iteration = 2;
          experiment.trafficSeedHi = 54870830;
          experiment.trafficSeedLo = 398724581;
          experiment.seedHi = 77498863;
          experiment.seedLo = 34737352;
        }
      }

      refreshDataFuture.complete(refreshData);
      await refreshFuture;

      expect(context.getTreatment(experimentName), equals(2));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(),
          equals(3)); // iteration change triggered a new exposure
    });

    test('refreshClearAssignmentCacheForExperimentIdChange', () async {
      final context = createReadyContext();
      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_abc";
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFuture.future);

      final refreshFuture = context.refreshAsync();

      verify(dataProvider.getContextData()).called(1);

      // Modify the id and seeds for the experiment in refreshData
      for (var experiment in refreshData.experiments) {
        if (experiment.name == experimentName) {
          experiment.id = 11;
          experiment.trafficSeedHi = 54870830;
          experiment.trafficSeedLo = 398724581;
          experiment.seedHi = 77498863;
          experiment.seedLo = 34737352;
        }
      }

      refreshDataFuture.complete(refreshData);
      await refreshFuture;

      expect(context.getTreatment(experimentName), equals(2));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(),
          equals(3)); // id change triggered a new exposure
    });

    //   test('getCustomFieldKeys', () async {
    //     final List<int> customFieldsContextBytes =
    //         await getResourceBytes("custom_fields_context.json");
    //     final customFieldsContextData = deser.deserialize(
    //         customFieldsContextBytes, 0, customFieldsContextBytes.length)!;
    //     final context = createReadyContext(customFieldsContextData);
    //     expect(context.isReady(), isTrue);

    //     expect(context.getCustomFieldKeys(),
    //         equals(["country", "languages", "overrides"]));
    //   });

    //   test('getCustomFieldValue', () async {
    //     final List<int> customFieldsContextBytes =
    //         await getResourceBytes("custom_fields_context.json");
    //     final customFieldsContextData = deser.deserialize(
    //         customFieldsContextBytes, 0, customFieldsContextBytes.length)!;
    //     final context = createReadyContext(customFieldsContextData);
    //     expect(context.isReady(), isTrue);

    //     expect(context.getCustomFieldValue("not_found", "not_found"), isNull);
    //     expect(context.getCustomFieldValue("exp_test_ab", "not_found"), isNull);
    //     expect(context.getCustomFieldValue("exp_test_ab", "country"),
    //         equals("US,PT,ES,DE,FR"));
    //     expect(context.getCustomFieldValueType("exp_test_ab", "country"),
    //         equals("string"));
    //     expect(context.getCustomFieldValue("exp_test_ab", "overrides"),
    //         equals({"123": 1, "456": 0}));
    //     expect(context.getCustomFieldValueType("exp_test_ab", "overrides"),
    //         equals("json"));
    //     expect(context.getCustomFieldValue("exp_test_ab", "languages"), isNull);
    //     expect(
    //         context.getCustomFieldValueType("exp_test_ab", "languages"), isNull);

    //     expect(context.getCustomFieldValue("exp_test_abc", "country"),
    //         equals("US,PT,ES"));
    //     expect(context.getCustomFieldValueType("exp_test_abc", "country"),
    //         equals("string"));
    //     expect(context.getCustomFieldValue("exp_test_abc", "overrides"), isNull);
    //     expect(
    //         context.getCustomFieldValueType("exp_test_abc", "overrides"), isNull);
    //     expect(context.getCustomFieldValue("exp_test_abc", "languages"),
    //         equals("en-US,en-GB,pt-PT,pt-BR,es-ES,es-MX"));
    //     expect(context.getCustomFieldValueType("exp_test_abc", "languages"),
    //         equals("string"));

    //     expect(
    //         context.getCustomFieldValue("exp_test_no_custom_fields", "country"),
    //         isNull);
    //     expect(
    //         context.getCustomFieldValueType(
    //             "exp_test_no_custom_fields", "country"),
    //         isNull);
    //     expect(
    //         context.getCustomFieldValue("exp_test_no_custom_fields", "overrides"),
    //         isNull);
    //     expect(
    //         context.getCustomFieldValueType(
    //             "exp_test_no_custom_fields", "overrides"),
    //         isNull);
    //     expect(
    //         context.getCustomFieldValue("exp_test_no_custom_fields", "languages"),
    //         isNull);
    //     expect(
    //         context.getCustomFieldValueType(
    //             "exp_test_no_custom_fields", "languages"),
    //         isNull);
    //   });
  });
}
