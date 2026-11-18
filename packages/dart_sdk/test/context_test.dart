import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:absmartly_dart/src/internal/hashing/hashing.dart';
import 'package:absmartly_dart/src/internal/variant_assigner.dart';
import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/context.dart';
import 'package:absmartly_dart/src/context_config.dart';
import 'package:absmartly_dart/src/context_data_provider.dart';
import 'package:absmartly_dart/src/context_event_handler.dart';
import 'package:absmartly_dart/src/context_event_logger.dart';
import 'package:absmartly_dart/src/default_audience_deserializer.dart';
import 'package:absmartly_dart/src/default_context_data_serializer.dart';
import 'package:absmartly_dart/src/default_variable_parser.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:absmartly_dart/src/json/context_data.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:absmartly_dart/src/json/exposure.dart';
import 'package:absmartly_dart/src/json/goal_achievement.dart';
import 'package:absmartly_dart/src/json/publish_event.dart';
import 'package:absmartly_dart/src/variable_parser.dart';
import 'package:test/test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'context_test.mocks.dart';
import 'test_utils.dart';

@GenerateNiceMocks([
  MockSpec<ContextDataProvider>(),
  MockSpec<ContextEventHandler>(),
  MockSpec<ContextEventLogger>(),
])
void main() {
  group('Context Tests', () {
    final Map<String, String> units = {
      'session_id': 'e791e240fcd3df7d238cfc285f475e8152fcc0ec',
      'user_id': '123456789',
      'email': 'bleh@absmartly.com'
    };

    final Map<String, int> expectedVariants = {
      'exp_test_ab': 1,
      'exp_test_abc': 2,
      'exp_test_not_eligible': 0,
      'exp_test_fullon': 2,
      'exp_test_new': 1
    };

    final Map<String, dynamic> expectedVariables = {
      'banner.border': 1,
      'banner.size': 'large',
      'button.color': 'red',
      'submit.color': 'blue',
      'submit.shape': 'rect',
      'show-modal': true
    };

    final Map<String, List<String>> variableExperiments = {
      'banner.border': ['exp_test_ab'],
      'banner.size': ['exp_test_ab'],
      'button.color': ['exp_test_abc'],
      'card.width': ['exp_test_not_eligible'],
      'submit.color': ['exp_test_fullon'],
      'submit.shape': ['exp_test_fullon'],
      'show-modal': ['exp_test_new']
    };

    late ContextData data;
    late ContextData refreshData;
    late ContextData audienceData;
    late ContextData audienceStrictData;
    late ContextData customFieldsData;

    late Completer<ContextData> dataFutureReady;
    late Completer<ContextData> dataFutureFailed;
    late Completer<ContextData> dataFuture;

    late Completer<ContextData> refreshDataFutureReady;
    late Completer<ContextData> refreshDataFuture;

    late Completer<ContextData> audienceDataFutureReady;
    late Completer<ContextData> audienceStrictDataFutureReady;
    late Completer<ContextData> customFieldsDataFutureReady;

    late MockContextDataProvider dataProvider;
    late MockContextEventLogger eventLogger;
    late MockContextEventHandler eventHandler;
    late VariableParser variableParser;
    late AudienceMatcher audienceMatcher;
    late Clock clock;
    late DefaultContextDataDeserializer deser;

    setUp(() async {
      // Initialize deserializer
      deser = DefaultContextDataDeserializer();

      // Load data from resource files
      final contextBytes = await getResourceBytes("context.json");
      data = deser.deserialize(contextBytes, 0, contextBytes.length)!;

      final refreshedBytes = await getResourceBytes("refreshed.json");
      refreshData =
          deser.deserialize(refreshedBytes, 0, refreshedBytes.length)!;

      final audienceBytes = await getResourceBytes("audience_context.json");
      audienceData = deser.deserialize(audienceBytes, 0, audienceBytes.length)!;

      final audienceStrictBytes =
          await getResourceBytes("audience_strict_context.json");
      audienceStrictData = deser.deserialize(
          audienceStrictBytes, 0, audienceStrictBytes.length)!;

      // Load custom fields data
      final customFieldsBytes =
          await getResourceBytes("custom_fields_context.json");
      customFieldsData =
          deser.deserialize(customFieldsBytes, 0, customFieldsBytes.length)!;

      // Setup futures
      dataFutureReady = Completer<ContextData>();
      dataFutureReady.complete(data);

      dataFutureFailed = Completer<ContextData>();

      dataFuture = Completer<ContextData>();

      refreshDataFutureReady = Completer<ContextData>();
      refreshDataFutureReady.complete(refreshData);

      refreshDataFuture = Completer<ContextData>();

      audienceDataFutureReady = Completer<ContextData>();
      audienceDataFutureReady.complete(audienceData);

      audienceStrictDataFutureReady = Completer<ContextData>();
      audienceStrictDataFutureReady.complete(audienceStrictData);

      customFieldsDataFutureReady = Completer<ContextData>();
      customFieldsDataFutureReady.complete(customFieldsData);

      // Setup mocks
      dataProvider = MockContextDataProvider();
      eventHandler = MockContextEventHandler();
      eventLogger = MockContextEventLogger();
      variableParser = DefaultVariableParser();
      audienceMatcher = AudienceMatcher(DefaultAudienceDeserializer());
      clock = Clock.fixed(1620000000000);
    });

    Context createContext(
        ContextConfig config, Completer<ContextData> dataFuture) {
      return Context.create(clock, config, dataFuture, dataProvider,
          eventHandler, variableParser, audienceMatcher, eventLogger);
    }

    Context createContextWithDefaultConfig(Completer<ContextData> dataFuture) {
      final ContextConfig config = ContextConfig.create()..setUnits(units);

      return Context.create(clock, config, dataFuture, dataProvider,
          eventHandler, variableParser, audienceMatcher, eventLogger);
    }

    Context createReadyContext() {
      final ContextConfig config = ContextConfig.create()..setUnits(units);

      return Context.create(clock, config, dataFutureReady, dataProvider,
          eventHandler, variableParser, audienceMatcher, eventLogger);
    }

    Context createReadyContextWithData(ContextData contextData) {
      final ContextConfig config = ContextConfig.create()..setUnits(units);

      final completer = Completer<ContextData>();
      completer.complete(contextData);

      return Context.create(clock, config, completer, dataProvider,
          eventHandler, variableParser, audienceMatcher, eventLogger);
    }

    Completer<void> createCompleteVoidCompleter() {
      final Completer<void> completer = Completer<void>();
      completer.complete();
      return completer;
    }

    Completer<void> createErrorVoidCompleter(Exception error) {
      final Completer<void> completer = Completer<void>();
      completer.completeError(error);
      return completer;
    }

    test('constructorSetsOverrides', () {
      final Map<String, int> overrides = {'exp_test': 2, 'exp_test_1': 1};

      final ContextConfig config = ContextConfig.create()
        ..setUnits(units)
        ..setOverrides(overrides);

      final Context context = createContext(config, dataFutureReady);

      overrides.forEach((experimentName, variant) {
        expect(context.getOverride(experimentName), equals(variant));
      });
    });

    test('constructorSetsCustomAssignments', () {
      final Map<String, int> cassignments = {'exp_test': 2, 'exp_test_1': 1};

      final ContextConfig config = ContextConfig.create()
        ..setUnits(units)
        ..setCustomAssignments(cassignments);

      final Context context = createContext(config, dataFutureReady);

      cassignments.forEach((experimentName, variant) {
        expect(context.getCustomAssignment(experimentName), equals(variant));
      });
    });

    test('becomesReadyWithCompletedFuture', () async {
      final Context context = createReadyContext();
      expect(context.isReady(), isFalse);

      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.getData(), equals(data));
    });

    test('becomesReadyAndFailedWithCompletedExceptionallyFuture', () async {
      final Context context = createContextWithDefaultConfig(dataFutureFailed);

      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      dataFutureFailed.completeError(Exception('FAILED'));

      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isTrue);
    });

    test('becomesReadyAndFailedWithException', () async {
      final Context context = createContextWithDefaultConfig(dataFuture);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      dataFuture.completeError(Exception('FAILED'));

      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isTrue);
    });

    test('callsEventLoggerWhenReady', () async {
      final Context context = createContextWithDefaultConfig(dataFuture);

      dataFuture.complete(data);

      await context.waitUntilReady();

      // Verify event logger was called with Ready event
      verify(eventLogger.handleEvent(context, EventType.ready, data)).called(1);
    });

    test('callsEventLoggerWithCompletedFuture', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      // Verify event logger was called with Ready event
      verify(eventLogger.handleEvent(context, EventType.ready, data)).called(1);
    });

    test('callsEventLoggerWithException', () async {
      final Context context = createContextWithDefaultConfig(dataFuture);

      final Exception error = Exception('FAILED');
      dataFuture.completeError(error);

      await context.waitUntilReady();

      // Verify event logger was called with Error event
      verify(eventLogger.handleEvent(context, EventType.error, error))
          .called(1);
    });

    test('waitUntilReady', () async {
      final Context context = createContextWithDefaultConfig(dataFuture);
      expect(context.isReady(), isFalse);

      // Start a separate task to complete the future
      Future.delayed(Duration.zero, () {
        dataFuture.complete(data);
      });

      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.getData(), equals(data));
    });

    test('waitUntilReadyWithCompletedFuture', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.getData(), equals(data));
    });

    test('readsThrowWhenNotReady', () {
      final Context context = createContextWithDefaultConfig(dataFuture);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      final notReady = throwsA(predicate((e) =>
          e is Exception &&
          e.toString().contains('ABSmartly Context is not yet ready')));
      expect(() => context.peekTreatment('exp_test_ab'), notReady);
      expect(() => context.getTreatment('exp_test_ab'), notReady);
      expect(() => context.getData(), notReady);
      expect(() => context.getExperiments(), notReady);
      expect(() => context.getVariableValue('banner.border', 17), notReady);
      expect(() => context.peekVariableValue('banner.border', 17), notReady);
      expect(() => context.getVariableKeys(), notReady);
      expect(() => context.getCustomFieldKeys(), notReady);
      expect(() => context.getCustomFieldValue('exp_test_ab', 'x'), notReady);
      expect(
          () => context.getCustomFieldValueType('exp_test_ab', 'x'), notReady);
      // As in 2.1, publish() only rejects a closed context.
      expect(() => context.publish(), returnsNormally);
    });

    test('refreshBeforeReadyFetchesAsIn21', () async {
      final Context context = createContextWithDefaultConfig(dataFuture);
      expect(context.isReady(), isFalse);

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);
      final Future<void> refreshing = context.refresh();
      refreshDataFuture.complete(refreshData);
      await refreshing;

      verify(dataProvider.getContextData()).called(1);
    });

    test('initialFailureBeforeOverlappingRefreshKeepsTheContextFailed',
        () async {
      final context = createContextWithDefaultConfig(dataFuture);
      final ready = context.waitUntilReady();
      final error = Exception('initial load failed');
      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      final refreshing = context.refresh();
      dataFuture.completeError(error);
      expect(await ready, same(context));
      expect(context.isFailed(), isTrue);
      expect(context.getTreatment('exp_test_ab'), equals(0));
      context.track('goal1', null);

      refreshDataFuture.complete(refreshData);
      await refreshing;
      expect(context.isFailed(), isTrue);
      expect(context.readyError(), same(error));
      expect(context.getExperiments(), isEmpty);
      verifyNever(
          eventLogger.handleEvent(context, EventType.refresh, refreshData));

      await context.publish();
      verifyNever(eventHandler.publish(any, any));
      expect(context.getPendingCount(), equals(0));
    });

    test('refreshFailureThenInitialSuccessUsesTheInitialData', () async {
      final context = createContextWithDefaultConfig(dataFuture);
      final ready = context.waitUntilReady();
      final refreshError = Exception('refresh failed');
      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);

      final refreshing = context.refresh();
      refreshDataFuture.completeError(refreshError);
      await expectLater(refreshing, throwsA(same(refreshError)));
      dataFuture.complete(data);
      expect(await ready, same(context));
      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);
      expect(context.getData(), same(data));
      expect(context.getTreatment('exp_test_ab'), equals(1));
    });

    test('refreshFailureThenInitialFailureReportsTheInitialError', () async {
      final context = createContextWithDefaultConfig(dataFuture);
      final ready = context.waitUntilReady();
      final refreshError = Exception('refresh failed');
      final initialError = Exception('initial load failed');
      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);

      final refreshing = context.refresh();
      refreshDataFuture.completeError(refreshError);
      await expectLater(refreshing, throwsA(same(refreshError)));
      dataFuture.completeError(initialError);
      expect(await ready, same(context));
      expect(context.isFailed(), isTrue);
      expect(context.readyError(), same(initialError));
    });

    test('refreshWhoseDataFailsToInstallDoesNotBlockTheInitialData', () async {
      final throwingParser = _FailOnceVariableParser();
      final config = ContextConfig.create()..setUnits(units);
      final context = Context.create(clock, config, dataFuture, dataProvider,
          eventHandler, throwingParser, audienceMatcher, eventLogger);
      final ready = context.waitUntilReady();
      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);

      final refreshing = context.refresh();
      refreshDataFuture.complete(refreshData);
      await expectLater(refreshing, throwsA(isA<StateError>()));
      dataFuture.complete(data);
      expect(await ready, same(context));
      expect(context.isFailed(), isFalse);
      expect(context.getData(), same(data));
    });

    test('initialFailureAfterOverlappingRefreshKeepsRefresh', () async {
      final context = createContextWithDefaultConfig(dataFuture);
      final ready = context.waitUntilReady();
      var readyCompleted = false;
      ready.then((_) => readyCompleted = true);
      final error = Exception('initial load failed');
      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      final refreshing = context.refresh();
      refreshDataFuture.complete(refreshData);
      await refreshing;
      expect(readyCompleted, isFalse);
      dataFuture.completeError(error);
      expect(await ready, same(context));
      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);
      expect(context.readyError(), isNull);
      expect(context.getData(), same(refreshData));
      verifyInOrder([
        eventLogger.handleEvent(context, EventType.refresh, refreshData),
        eventLogger.handleEvent(context, EventType.error, error),
      ]);
      verifyNever(eventLogger.handleEvent(context, EventType.ready, any));

      context.getTreatment(refreshData.experiments.first.name);
      await context.publish();
      final published = verify(eventHandler.publish(any, captureAny)).captured;
      expect((published.single as PublishEvent).exposures, hasLength(1));
    });

    test('initialSuccessAfterOverlappingRefreshKeepsRefresh', () async {
      final context = createContextWithDefaultConfig(dataFuture);
      final ready = context.waitUntilReady();
      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);

      final refreshing = context.refresh();
      refreshDataFuture.complete(refreshData);
      await refreshing;
      dataFuture.complete(data);
      expect(await ready, same(context));
      expect(context.isFailed(), isFalse);
      expect(context.readyError(), isNull);
      expect(context.getData(), same(refreshData));
      verifyInOrder([
        eventLogger.handleEvent(context, EventType.refresh, refreshData),
        eventLogger.handleEvent(context, EventType.ready, refreshData),
      ]);
    });

    test('eventsQueuedBeforeReadyPublishAfterAnOverlappingRefreshWins',
        () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setPublishDelay(10);
      final context = Context.create(clock, config, dataFuture, dataProvider,
          eventHandler, variableParser, audienceMatcher, eventLogger);
      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      context.track('goal1', null);
      final refreshing = context.refresh();
      refreshDataFuture.complete(refreshData);
      await refreshing;
      dataFuture.completeError(Exception('initial load failed'));
      await context.waitUntilReady();
      expect(context.isFailed(), isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(context.getPendingCount(), equals(0));
      final published = verify(eventHandler.publish(any, captureAny)).captured;
      expect((published.single as PublishEvent).goals.single.name,
          equals('goal1'));
    });

    test('waitUntilReadyCompletesWhenTheInitialFetchSettlesAfterRefresh',
        () async {
      final context = createContextWithDefaultConfig(dataFuture);
      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);
      var waiterDone = false;
      final waiter = context.waitUntilReady().then((_) => waiterDone = true);

      final refreshing = context.refresh();
      refreshDataFuture.complete(refreshData);
      await refreshing;
      await Future<void>.delayed(Duration.zero);
      expect(context.isReady(), isTrue);
      expect(waiterDone, isFalse);
      expect(await context.waitUntilReady(), same(context));
      dataFuture.complete(data);
      await waiter;
      expect(waiterDone, isTrue);
    });

    test('initialSuccessBeforeOverlappingRefreshInstallsBoth', () async {
      final context = createContextWithDefaultConfig(dataFuture);
      final ready = context.waitUntilReady();
      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);

      final refreshing = context.refresh();
      dataFuture.complete(data);
      expect(await ready, same(context));
      expect(context.getData(), same(data));
      refreshDataFuture.complete(refreshData);
      await refreshing;
      expect(context.getData(), same(refreshData));
      verifyInOrder([
        eventLogger.handleEvent(context, EventType.ready, data),
        eventLogger.handleEvent(context, EventType.refresh, refreshData),
      ]);
    });

    test('throwsWhenClosed', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      context.track('goal1', {'amount': 125, 'hours': 245});

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.close();

      expect(context.isClosed(), isTrue);

      expect(() => context.setAttribute('attr1', 'value1'),
          throwsA(isA<Exception>()));
      expect(() => context.setAttributes({'attr1': 'value1'}),
          throwsA(isA<Exception>()));
      expect(() => context.setOverride('exp_test_ab', 2), returnsNormally);
      expect(() => context.setOverrides({'exp_test_ab': 2}), returnsNormally);
      expect(() => context.setUnit('test', 'test'), throwsA(isA<Exception>()));
      expect(() => context.setCustomAssignment('exp_test_ab', 2),
          throwsA(isA<Exception>()));
      expect(() => context.setCustomAssignments({'exp_test_ab': 2}),
          throwsA(isA<Exception>()));
      final finalized = throwsA(predicate((e) =>
          e is Exception &&
          e.toString().contains('ABSmartly Context is closed')));
      expect(() => context.peekTreatment('exp_test_ab'), finalized);
      expect(() => context.getTreatment('exp_test_ab'), finalized);
      expect(() => context.track('goal1', null), finalized);
      expect(() => context.publish(), finalized);
      expect(() => context.refresh(), finalized);
      expect(() => context.getVariableValue('banner.border', 17), finalized);
      expect(() => context.peekVariableValue('banner.border', 17), finalized);
      expect(() => context.getVariableKeys(), finalized);
      expect(() => context.getCustomFieldKeys(), finalized);
      // As in 2.1, data and experiments are not readable after close.
      expect(() => context.getData(), finalized);
      expect(() => context.getExperiments(), finalized);
    });

    test('getExperiments', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      final List<String> experiments =
          data.experiments.map((e) => e.name).toList();
      expect(context.getExperiments(), equals(experiments));
    });

    test('setAttributes', () {
      final Context context = createContextWithDefaultConfig(dataFuture);

      context.setAttribute('attr1', 'value1');
      context.setAttributes({'attr2': 'value2', 'attr3': 15});

      expect(context.getAttribute('attr1'), equals('value1'));
      expect(context.getAttributes(),
          equals({'attr1': 'value1', 'attr2': 'value2', 'attr3': 15}));
    });

    test('setAttributesBeforeReady', () {
      final Context context = createContextWithDefaultConfig(dataFuture);
      expect(context.isReady(), isFalse);

      context.setAttribute('attr1', 'value1');
      context.setAttributes({'attr2': 'value2'});

      expect(context.getAttribute('attr1'), equals('value1'));
      expect(context.getAttributes(),
          equals({'attr1': 'value1', 'attr2': 'value2'}));

      dataFuture.complete(data);
    });

    test('setOverride', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.setOverride('exp_test', 2);
      expect(context.getOverride('exp_test'), equals(2));

      context.setOverride('exp_test', 3);
      expect(context.getOverride('exp_test'), equals(3));

      context.setOverride('exp_test_2', 1);
      expect(context.getOverride('exp_test_2'), equals(1));

      final Map<String, int> overrides = {
        'exp_test_new': 3,
        'exp_test_new_2': 5
      };

      context.setOverrides(overrides);

      expect(context.getOverride('exp_test'), equals(3));
      expect(context.getOverride('exp_test_2'), equals(1));

      overrides.forEach((experimentName, variant) {
        expect(context.getOverride(experimentName), equals(variant));
      });

      expect(context.getOverride('exp_test_not_found'), isNull);
    });

    test('setOverridesBeforeReady', () {
      final Context context = createContextWithDefaultConfig(dataFuture);
      expect(context.isReady(), isFalse);

      context.setOverride('exp_test', 2);
      context.setOverrides({'exp_test_new': 3, 'exp_test_new_2': 5});

      dataFuture.complete(data);

      expect(context.getOverride('exp_test'), equals(2));
      expect(context.getOverride('exp_test_new'), equals(3));
      expect(context.getOverride('exp_test_new_2'), equals(5));
    });

    test('setCustomAssignment', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.setCustomAssignment('exp_test', 2);

      expect(context.getCustomAssignment('exp_test'), equals(2));

      context.setCustomAssignment('exp_test', 3);
      expect(context.getCustomAssignment('exp_test'), equals(3));

      context.setCustomAssignment('exp_test_2', 1);
      expect(context.getCustomAssignment('exp_test_2'), equals(1));

      final Map<String, int> cassignments = {
        'exp_test_new': 3,
        'exp_test_new_2': 5
      };

      context.setCustomAssignments(cassignments);

      expect(context.getCustomAssignment('exp_test'), equals(3));
      expect(context.getCustomAssignment('exp_test_2'), equals(1));

      cassignments.forEach((experimentName, variant) {
        expect(context.getCustomAssignment(experimentName), equals(variant));
      });

      expect(context.getCustomAssignment('exp_test_not_found'), isNull);
    });

    test('setCustomAssignmentsBeforeReady', () {
      final Context context = createContextWithDefaultConfig(dataFuture);
      expect(context.isReady(), isFalse);

      context.setCustomAssignment('exp_test', 2);
      context.setCustomAssignments({'exp_test_new': 3, 'exp_test_new_2': 5});

      dataFuture.complete(data);

      expect(context.getCustomAssignment('exp_test'), equals(2));
      expect(context.getCustomAssignment('exp_test_new'), equals(3));
      expect(context.getCustomAssignment('exp_test_new_2'), equals(5));
    });

    test('setUnits', () {
      final Context context = createContext(ContextConfig.create(), dataFuture);
      context.setUnits(units);

      units.forEach((unitType, uid) {
        expect(context.getUnit(unitType), equals(uid));
      });
    });

    test('setUnitsBeforeReady', () async {
      final Context context = createContext(ContextConfig.create(), dataFuture);
      expect(context.isReady(), isFalse);

      context.setUnits(units);

      dataFuture.complete(data);

      await context.waitUntilReady();

      context.getTreatment('exp_test_ab');

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('setUnitThrowsOnAlreadySet', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(() => context.setUnit('session_id', 'new_uid'),
          throwsA(isA<Exception>()));
    });

    test('peekTreatment', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      for (var experiment in data.experiments) {
        expect(context.peekTreatment(experiment.name),
            equals(expectedVariants[experiment.name]));
      }

      expect(context.peekTreatment('not_found'), equals(0));

      // Call again
      for (var experiment in data.experiments) {
        expect(context.peekTreatment(experiment.name),
            equals(expectedVariants[experiment.name]));
      }

      expect(context.peekTreatment('not_found'), equals(0));

      expect(context.getPendingCount(), equals(0));
    });

    test('peekTreatmentReturnsOverrideVariant', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      for (var experiment in data.experiments) {
        context.setOverride(
            experiment.name, 11 + expectedVariants[experiment.name]!);
      }

      context.setOverride('not_found', 3);

      for (var experiment in data.experiments) {
        expect(context.peekTreatment(experiment.name),
            equals(expectedVariants[experiment.name]! + 11));
      }

      expect(context.peekTreatment('not_found'), equals(3));

      // Call again
      for (var experiment in data.experiments) {
        expect(context.peekTreatment(experiment.name),
            equals(expectedVariants[experiment.name]! + 11));
      }

      expect(context.peekTreatment('not_found'), equals(3));

      expect(context.getPendingCount(), equals(0));
    });

    test('peekTreatmentReturnsAssignedVariantOnAudienceMismatchNonStrictMode',
        () async {
      final Context context = createReadyContextWithData(audienceData);
      await context.waitUntilReady();

      expect(context.peekTreatment('exp_test_ab'), equals(1));
    });

    test('peekTreatmentReturnsControlVariantOnAudienceMismatchStrictMode',
        () async {
      final Context context = createReadyContextWithData(audienceStrictData);
      await context.waitUntilReady();

      expect(context.peekTreatment('exp_test_ab'), equals(0));
    });

    test('getTreatment', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      for (var experiment in data.experiments) {
        expect(context.getTreatment(experiment.name),
            equals(expectedVariants[experiment.name]));
      }

      expect(context.getTreatment('not_found'), equals(0));
      expect(context.getPendingCount(), equals(data.experiments.length + 1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('getTreatmentQueuesExposureOnce', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      for (var experiment in data.experiments) {
        context.getTreatment(experiment.name);
      }

      context.getTreatment('not_found');

      expect(context.getPendingCount(), equals(data.experiments.length + 1));

      // Call again
      for (var experiment in data.experiments) {
        context.getTreatment(experiment.name);
      }

      context.getTreatment('not_found');

      expect(context.getPendingCount(), equals(data.experiments.length + 1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);

      expect(context.getPendingCount(), equals(0));

      for (var experiment in data.experiments) {
        context.getTreatment(experiment.name);
      }

      context.getTreatment('not_found');
      expect(context.getPendingCount(), equals(0));
    });

    test('getTreatmentReturnsOverrideVariant', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      for (var experiment in data.experiments) {
        context.setOverride(
            experiment.name, 11 + expectedVariants[experiment.name]!);
      }

      context.setOverride('not_found', 3);

      for (var experiment in data.experiments) {
        expect(context.getTreatment(experiment.name),
            equals(expectedVariants[experiment.name]! + 11));
      }

      expect(context.getTreatment('not_found'), equals(3));
      expect(context.getPendingCount(), equals(data.experiments.length + 1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('getTreatmentQueuesExposureWithAudienceMismatchFalseOnAudienceMatch',
        () async {
      final Context context = createReadyContextWithData(audienceData);
      await context.waitUntilReady();

      context.setAttribute('age', 21);

      expect(context.getTreatment('exp_test_ab'), equals(1));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('getTreatmentQueuesExposureWithAudienceMismatchTrueOnAudienceMismatch',
        () async {
      final Context context = createReadyContextWithData(audienceData);
      await context.waitUntilReady();

      expect(context.getTreatment('exp_test_ab'), equals(1));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('getTreatmentCallsEventLogger', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      // Clear any previous invocations
      reset(eventLogger);

      context.getTreatment('exp_test_ab');
      context.getTreatment('not_found');

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      final List<Exposure> expectedExposures = [
        Exposure(
            id: 1,
            name: 'exp_test_ab',
            unit: 'session_id',
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
            name: 'not_found',
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

      // Verify event logger was called for each exposure
      verify(eventLogger.handleEvent(context, EventType.exposure, any))
          .called(expectedExposures.length);

      // Verify not called again with the same exposure
      reset(eventLogger);
      context.getTreatment('exp_test_ab');
      context.getTreatment('not_found');

      verifyNever(eventLogger.handleEvent(context, EventType.exposure, any));
    });

    test('getVariableValueCallsEventLogger', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      // Clear any previous invocations
      reset(eventLogger);

      context.getVariableValue('banner.border', null);
      context.getVariableValue('banner.size', null);

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      // Verify event logger was called once for the experiment exposure
      verify(eventLogger.handleEvent(context, EventType.exposure, any))
          .called(1);

      // Verify not called again with the same exposure
      reset(eventLogger);
      context.getVariableValue('banner.border', null);
      context.getVariableValue('banner.size', null);

      verifyNever(eventLogger.handleEvent(context, EventType.exposure, any));
    });

    test('peekVariableValue', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      final Set<String> experiments =
          data.experiments.map((e) => e.name).toSet();

      variableExperiments.forEach((variable, experimentNames) {
        final String experimentName = experimentNames[0];
        final dynamic actual = context.peekVariableValue(variable, 17);
        final bool eligible = experimentName != 'exp_test_not_eligible';

        if (eligible && experiments.contains(experimentName)) {
          expect(actual, equals(expectedVariables[variable]));
        } else {
          expect(actual, equals(17));
        }
      });

      expect(context.getPendingCount(), equals(0));
    });

    test(
        'peekVariableValueReturnsAssignedVariantOnAudienceMismatchNonStrictMode',
        () async {
      final Context context = createReadyContextWithData(audienceData);
      await context.waitUntilReady();

      expect(
          context.peekVariableValue('banner.size', 'small'), equals('large'));
    });

    test('peekVariableValueReturnsControlVariantOnAudienceMismatchStrictMode',
        () async {
      final Context context = createReadyContextWithData(audienceStrictData);
      await context.waitUntilReady();

      expect(
          context.peekVariableValue('banner.size', 'small'), equals('small'));
    });

    test('getVariableValue', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      final Set<String> experiments =
          data.experiments.map((e) => e.name).toSet();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      variableExperiments.forEach((variable, experimentNames) {
        final String experimentName = experimentNames[0];
        final dynamic actual = context.getVariableValue(variable, 17);
        final bool eligible = experimentName != 'exp_test_not_eligible';

        if (eligible && experiments.contains(experimentName)) {
          expect(actual, equals(expectedVariables[variable]));
        } else {
          expect(actual, equals(17));
        }
      });

      expect(context.getPendingCount(), equals(experiments.length));
    });

    test(
        'getVariableValueQueuesExposureWithAudienceMismatchFalseOnAudienceMatch',
        () async {
      final Context context = createReadyContextWithData(audienceData);
      await context.waitUntilReady();

      context.setAttribute('age', 21);

      expect(context.getVariableValue('banner.size', 'small'), equals('large'));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test(
        'getVariableValueQueuesExposureWithAudienceMismatchTrueOnAudienceMismatch',
        () async {
      final Context context = createReadyContextWithData(audienceData);
      await context.waitUntilReady();

      expect(context.getVariableValue('banner.size', 'small'), equals('large'));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test(
        'getVariableValueDoesNotQueuesExposureWithAudienceMismatchFalseAndControlVariantOnAudienceMismatchInStrictMode',
        () async {
      final Context context = createReadyContextWithData(audienceStrictData);
      await context.waitUntilReady();

      expect(context.getVariableValue('banner.size', 'small'), equals('small'));
      expect(context.getPendingCount(), equals(0));
    });

    test('getVariableKeys', () async {
      final Context context = createReadyContextWithData(refreshData);
      await context.waitUntilReady();

      expect(context.getVariableKeys(), equals(variableExperiments));
    });

    test('trackCallsEventLogger', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      // Clear any previous invocations
      reset(eventLogger);

      final Map<String, dynamic> properties = {'amount': 125, 'hours': 245};
      context.track('goal1', properties);

      final List<GoalAchievement> expectedAchievements = [
        GoalAchievement(
            name: 'goal1', achievedAt: clock.millis(), properties: properties)
      ];

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      // Verify event logger was called for the goal achievement
      verify(eventLogger.handleEvent(context, EventType.goal, any))
          .called(expectedAchievements.length);

      // Verify called again with the same goal (unlike exposures, goals can be tracked multiple times)
      reset(eventLogger);
      context.track('goal1', properties);

      verify(eventLogger.handleEvent(context, EventType.goal, any)).called(1);
    });

    test('publishCallsEventLogger', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 125, 'hours': 245});

      reset(eventLogger);

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventLogger.handleEvent(context, EventType.publish, any))
          .called(1);
    });

    test('publishCallsEventLoggerOnError', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 125, 'hours': 245});

      reset(eventLogger);

      final Exception failure = Exception('ERROR');
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createErrorVoidCompleter(failure));

      await expectLater(context.publish(), throwsA(isA<Exception>()));

      verify(eventLogger.handleEvent(context, EventType.error, failure))
          .called(1);
    });

    test('track', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      context.track('goal1', {'amount': 125, 'hours': 245});
      context.track('goal2', {'tries': 7});

      expect(context.getPendingCount(), equals(2));

      context.track('goal2', {'tests': 12});
      context.track('goal3', null);

      expect(context.getPendingCount(), equals(4));

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('trackKeepsNullProperties', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      final captured = <dynamic>[];
      when(eventLogger.handleEvent(any, EventType.goal, any))
          .thenAnswer((inv) => captured.add(inv.positionalArguments[2]));
      when(eventHandler.publish(any, any)).thenAnswer((inv) {
        captured.add(inv.positionalArguments[1]);
        return createCompleteVoidCompleter();
      });

      context.track('goal_null', null);
      final props = {'amount': 1};
      context.track('goal_props', props);
      props['amount'] = 2;

      final GoalAchievement first = captured[0];
      final GoalAchievement second = captured[1];
      expect(first.properties, isNull);
      expect(first.toMap()['properties'], isNull);
      expect(second.properties, equals({'amount': 1}));

      await context.publish();
      final PublishEvent event = captured[2];
      expect(event.goals[0].toMap()['properties'], isNull);
    });

    test('unitsKeepTheirType', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.setUnit('int_id', 125);
      context.setUnit('float_id', 125.75);
      context.setUnit('text_id', ' 007 ');

      expect(context.getUnit('int_id'), equals('125'));
      expect(context.getUnitValue('int_id'), isA<int>());
      expect(context.getUnitValue('int_id'), equals(125));
      expect(context.getUnitValue('float_id'), equals(125.75));
      expect(context.getUnit('text_id'), equals('007'));
      expect(context.getUnitValue('text_id'), equals('007'));
      expect(context.getUnits()['int_id'], equals('125'));
      expect(context.getUnitValues()['int_id'], isA<int>());
      expect(
          context.getUnitValues()['session_id'], equals(units['session_id']));

      expect(
          () => context.setUnit('int_id', '125'),
          throwsA(predicate(
              (e) => e.toString() == 'Exception: Unit int_id already set.')));
      context.setUnit('int_id', 125);

      expect(
          () => context.setUnit('bad', true),
          throwsA(predicate((e) => e
              .toString()
              .contains("Unit 'bad' must be a string or a number."))));
    });

    test('contextConfigUnitValuesKeepTheirType', () {
      final config = ContextConfig.create()
        ..setUnit('user_id', 42)
        ..setUnit('session_id', 'abc');
      final String? uid = config.getUnit('user_id');
      final Map<String, String> units = config.getUnits();
      expect(uid, equals('42'));
      expect(units, equals({'user_id': '42', 'session_id': 'abc'}));
      expect(config.getUnitValue('user_id'), equals(42));
      expect(
          config.getUnitValues(), equals({'user_id': 42, 'session_id': 'abc'}));

      config.units_['user_id'] = '43';
      expect(config.getUnitValue('user_id'), equals('43'));

      final Context context = Context.create(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher, null);
      expect(context.getUnitValue('user_id'), equals('43'));
      expect(context.getUnitValue('session_id'), equals('abc'));
    });

    test('unitValueFollowsAUidChangedThroughUnitsField', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.setUnit('u', 7);
      expect(context.getUnitValue('u'), equals(7));
      context.units_['u'] = '8';
      expect(context.getUnitValue('u'), equals('8'));
      expect(context.getUnitValues()['u'], equals('8'));
      expect(() => context.setUnit('u', '8'), returnsNormally);
    });

    test('aUidRewrittenThroughUnitsFieldDropsTheNumberItWasSetAs', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.setUnit('u', 125.75);
      context.units_.remove('u');
      context.units_['u'] = '125.75';
      expect(context.getUnitValue('u'), equals('125.75'));
      expect(context.getUnitHash('u', context.getUnitValue('u')!),
          equals(Hashing.hashUnit('125.75')));

      final config = ContextConfig.create()..setUnit('c', 125.75);
      config.units_['c'] = '125.75';
      expect(config.getUnitValue('c'), equals('125.75'));
      config.setUnit('m', 8);
      expect(config.getUnitValue('m'), equals(8));
      config.units_.remove('m');
      expect(config.getUnitValue('m'), isNull);
      expect(config.units_, isA<LinkedHashMap<String, String>>());

      // An assigned map is kept as given, as in 2.1: setUnit writes the
      // string form into it, and later writes to it are seen.
      final assigned = <String, String>{'n': '7'};
      config.units_ = assigned;
      expect(identical(config.units_, assigned), isTrue);
      config.setUnit('o', 9);
      expect(assigned['o'], equals('9'));
      expect(config.getUnitValue('o'), equals(9));
      expect(config.getUnitValue('absent'), isNull);
      expect(config.getUnitValue('o'), equals(9));
      assigned['o'] = '10';
      expect(config.getUnitValue('o'), equals('10'));

      config.setUnit('q', 125.75);
      assigned.clear();
      expect(config.getUnitValue('q'), isNull);
      assigned['q'] = '125.75';
      expect(config.getUnitValue('q'), equals('125.75'));
      final fresh = Context.create(clock, config, dataFutureReady, dataProvider,
          eventHandler, variableParser, audienceMatcher, null);
      expect(fresh.getUnitHash('q', fresh.getUnitValue('q')!),
          equals(Hashing.hashUnit('125.75')));
      assigned['p'] = 'x';
      expect(config.getUnit('p'), equals('x'));
    });

    test('aSetUnitsOverrideThatRewritesUnitsIsNotUndone', () async {
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());
      final config = ContextConfig.create()
        ..setUnit('session_id', 125)
        ..setUnit('user_id', 125);
      final context = _RewritingUnitsContext(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher);
      await context.waitUntilReady();

      expect(context.getUnits(), equals({'session_id': 'p-125'}));
      context.track('goal1', null);
      await context.publish();
      final PublishEvent event =
          verify(eventHandler.publish(context, captureAny)).captured.single
              as PublishEvent;
      expect(event.units.map((u) => u.uid),
          equals([utf8.decode(Hashing.hashUnit('p-125'))]));
    });

    test('aLegacyStringGetUnitHashOverrideWorksWithNumericUids', () async {
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());
      final config = ContextConfig.create()..setUnit('session_id', 125.75);
      final context = _StringHashContext(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher);
      await context.waitUntilReady();

      final int treatment = context.getTreatment('exp_test_ab');
      context.track('goal1', null);
      await context.publish();
      expect(context.getPendingCount(), equals(0));
      expect(context.hashedUids, everyElement('126'));
      final PublishEvent event =
          verify(eventHandler.publish(context, captureAny)).captured.single
              as PublishEvent;
      expect(
          event.units.single.uid, equals(utf8.decode(Hashing.hashUnit('126'))));
      final ExperimentVariables ab = context.getExperiment('exp_test_ab')!;
      expect(
          treatment,
          equals(VariantAssigner(Hashing.hashUnit('126'))
              .assign(ab.data.split, ab.data.seedHi, ab.data.seedLo)));
    });

    test('aCaseInsensitiveUnitsMapKeepsOneValuePerEntry', () {
      final config = ContextConfig.create();
      config.units_ = SplayTreeMap<String, String>(
          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      config.setUnit('User', 125.75);
      expect(config.getUnitValue('user'), equals(125.75));
      config.setUnit('user', '125.75');
      expect(config.getUnitValue('User'), equals('125.75'));
      expect(config.getUnitValue('user'), equals('125.75'));
      expect(config.getUnitValues().values.single, equals('125.75'));
      final context = Context.create(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher, null);
      final String key = context.getUnits().keys.single;
      expect(context.getUnitHash(key, context.getUnitValue(key)!),
          equals(Hashing.hashUnit('125.75')));
    });

    test('unitValuesHonourAContextThatOverridesTheUnitGetters', () async {
      final context = _GetterUnitsContext(
          clock,
          ContextConfig.create(),
          dataFutureReady,
          dataProvider,
          eventHandler,
          variableParser,
          audienceMatcher);
      expect(context.getUnitValue('session_id'), equals('abc'));
      expect(context.getUnitValues(), equals({'session_id': 'abc'}));
    });

    test('aContextUnitSeenMissingDropsItsNumber', () async {
      final config = ContextConfig.create();
      final context = _SortedUnitsContext(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher);
      context.setUnit('k', 5.0);
      expect(context.getUnitValue('k'), equals(5.0));
      context.units_.remove('k');
      expect(context.getUnitValue('k'), isNull);
      context.units_['k'] = '5.0';
      expect(context.getUnitValue('k'), equals('5.0'));
      expect(context.getUnitValues(), equals({'k': '5.0'}));
    });

    test('unitValuesFollowTheGettersWhenTheyDisagreeWithUnits', () async {
      final config = ContextConfig.create();
      final context = _OtherUnitContext(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher);
      context.setUnit('k', 5.0);
      expect(context.getUnitValue('k'), equals('other'));
      expect(context.getUnitValues(), equals({'k': 'other'}));
    });

    test('aCaseInsensitiveMissDropsTheNumberOfAnEqualKey', () {
      final config = ContextConfig.create();
      config.units_ = SplayTreeMap<String, String>(
          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      config.setUnit('User', 5.0);
      config.units_.remove('user');
      expect(config.getUnitValue('user'), isNull);
      config.units_['user'] = '5.0';
      expect(config.getUnitValue('user'), equals('5.0'));
    });

    test('creatingAContextReadsTheConfigUnitsOnce', () {
      final config = _CountingUnitsConfig()..setUnit('session_id', 'abc');
      Context.create(clock, config, dataFutureReady, dataProvider, eventHandler,
          variableParser, audienceMatcher, null);
      expect(config.getUnitsCalls, equals(1));
    });

    test('plainUnitsMapsFromSubclassesAreUsedAsIn21', () async {
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());
      final config = _SortedUnitsConfig()
        ..setUnit('session_id', 'e791e240fcd3df7d238cfc285f475e8152fcc0ec');
      expect(config.getUnit('session_id'),
          equals('e791e240fcd3df7d238cfc285f475e8152fcc0ec'));
      expect(config.units_, isA<SplayTreeMap<String, String>>());

      final context = _SortedUnitsContext(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher);
      await context.waitUntilReady();
      expect(context.getUnitValue('session_id'),
          equals('e791e240fcd3df7d238cfc285f475e8152fcc0ec'));
      expect(context.getTreatment('exp_test_ab'), equals(1));

      await context.publish();
      final PublishEvent event =
          verify(eventHandler.publish(context, captureAny)).captured.single
              as PublishEvent;
      expect(
          event.units.single.uid,
          equals(utf8.decode(
              Hashing.hashUnit('e791e240fcd3df7d238cfc285f475e8152fcc0ec'))));
    });

    test('numericUidsKeepTheirHashWithPlainUnitsMaps', () async {
      final config = _SortedUnitsConfig()
        ..setUnit('session_id', 5.0)
        ..setUnit('user_id', 125.75);
      expect(config.getUnit('session_id'), equals('5.0'));
      expect(config.getUnitValue('session_id'), equals(5.0));

      final context = _SortedUnitsContext(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher);
      await context.waitUntilReady();
      expect(context.getUnitValue('session_id'), equals(5.0));
      expect(context.getUnitValues(),
          equals({'session_id': 5.0, 'user_id': 125.75}));
      expect(context.getUnitHash('session_id', 5.0),
          equals(Hashing.hashUnit('5')));
    });

    test('aConfigThatImplementsGetUnitsOnlyStillCreatesAContext', () async {
      final config = _GetUnitsOnlyConfig();
      final context = Context.create(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher, null);
      await context.waitUntilReady();
      expect(context.getUnit('session_id'), equals('abc'));
      expect(config.getUnitValue('session_id'), equals('abc'));
    });

    test('aSecondOverlappingRefreshDoesNotRetryAFailedPublish', () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setPublishDelay(0);
      final context = Context.create(clock, config, dataFuture, dataProvider,
          eventHandler, variableParser, audienceMatcher, null);
      when(eventHandler.publish(any, any)).thenAnswer(
          (_) => Completer<void>()..completeError(Exception('publish failed')));
      context.track('goal1', null);

      var refreshFuture = Completer<ContextData>();
      when(dataProvider.getContextData()).thenAnswer((_) => refreshFuture);
      final first = context.refresh();
      refreshFuture.complete(refreshData);
      await first;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      verify(eventHandler.publish(any, any)).called(1);

      refreshFuture = Completer<ContextData>();
      final second = context.refresh();
      refreshFuture.complete(refreshData);
      await second;
      dataFuture.complete(data);
      await context.waitUntilReady();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      verifyNever(eventHandler.publish(any, any));
      expect(context.getPendingCount(), equals(1));
    });

    test('aRefreshOfAReadyContextDoesNotRetryAFailedPublish', () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setPublishDelay(0);
      final context = Context.create(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher, null);
      await context.waitUntilReady();
      when(eventHandler.publish(any, any)).thenAnswer(
          (_) => Completer<void>()..completeError(Exception('publish failed')));
      context.track('goal1', null);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      verify(eventHandler.publish(any, any)).called(1);
      expect(context.getPendingCount(), equals(1));

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);
      refreshDataFuture.complete(refreshData);
      await context.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      verifyNever(eventHandler.publish(any, any));
      expect(context.getPendingCount(), equals(1));
    });

    test('aUidRewrittenAfterHashingKeepsTheFirstHashAsIn21', () async {
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());
      final config = ContextConfig.create()..setUnit('session_id', 'A');
      final context = Context.create(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher, null);
      await context.waitUntilReady();

      final int ab = context.getTreatment('exp_test_ab');
      context.units_['session_id'] = 'B';
      final int abc = context.getTreatment('exp_test_abc');
      await context.publish();

      final assigner = VariantAssigner(Hashing.hashUnit('A'));
      final ExperimentVariables abData = context.getExperiment('exp_test_ab')!;
      final ExperimentVariables abcData =
          context.getExperiment('exp_test_abc')!;
      expect(
          ab,
          equals(assigner.assign(
              abData.data.split, abData.data.seedHi, abData.data.seedLo)));
      expect(
          abc,
          equals(assigner.assign(
              abcData.data.split, abcData.data.seedHi, abcData.data.seedLo)));
      final PublishEvent event =
          verify(eventHandler.publish(context, captureAny)).captured.single
              as PublishEvent;
      expect(
          event.units.single.uid, equals(utf8.decode(Hashing.hashUnit('A'))));
      expect(
          identical(context.getUnitHash('session_id', 'B'),
              context.getUnitHash('session_id', 'A')),
          isTrue);
    });

    test('paddedUidSetAgainThrowsAsIn21', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.setUnit('padded', ' abc ');
      expect(context.getUnit('padded'), equals('abc'));
      expect(() => context.setUnit('padded', 'abc'), returnsNormally);
      expect(
          () => context.setUnit('padded', ' abc '),
          throwsA(predicate(
              (e) => e.toString() == 'Exception: Unit padded already set.')));
    });

    test('numericUnitIsPublishedWithItsNumericHash', () async {
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());
      final config = ContextConfig.create()..setUnit('float_id', 125.75);
      final Context context = Context.create(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher, null);
      await context.waitUntilReady();

      context.track('goal1', null);
      await context.publish();

      final PublishEvent event =
          verify(eventHandler.publish(context, captureAny)).captured.single
              as PublishEvent;
      expect(event.units.single.type, equals('float_id'));
      expect(
          event.units.single.uid, equals(utf8.decode(Hashing.hashUnit('126'))));
    });

    test('subclassOverridingSetUnitsWithStringsStillWorks', () async {
      final config = ContextConfig.create()
        ..setUnit('session_id', 'abc')
        ..setUnit('user_id', 42);
      final context = _StringUnitsContext(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher);
      await context.waitUntilReady();

      expect(context.seen, equals({'session_id': 'abc', 'user_id': '42'}));
      expect(context.getUnitValue('user_id'), equals(42));
      expect(
          context.getUnitHash('user_id', 42), equals(Hashing.hashUnit('42')));
    });

    test('numericUnitsAssignLikeTheirJavaScriptToFixedForm', () async {
      final Experiment ruleFree =
          data.experiments.firstWhere((e) => e.name == 'exp_test_abc');
      final ContextData splitRule = ContextData(experiments: [
        Experiment(
            id: ruleFree.id,
            name: 'exp_split_rule',
            unitType: 'u',
            iteration: 1,
            seedHi: 123,
            seedLo: 456,
            split: ruleFree.split,
            trafficSeedHi: ruleFree.trafficSeedHi,
            trafficSeedLo: ruleFree.trafficSeedLo,
            trafficSplit: ruleFree.trafficSplit,
            fullOnVariant: 0,
            applications: ruleFree.applications,
            variants: ruleFree.variants,
            audienceStrict: false,
            audience: null,
            assignmentRules:
                '{"rules":[{"type":"split","percentages":"20/30/50"}]}'),
        Experiment(
            id: ruleFree.id + 1000,
            name: 'exp_no_rule',
            unitType: 'u',
            iteration: 1,
            seedHi: ruleFree.seedHi,
            seedLo: ruleFree.seedLo,
            split: ruleFree.split,
            trafficSeedHi: ruleFree.trafficSeedHi,
            trafficSeedLo: ruleFree.trafficSeedLo,
            trafficSplit: ruleFree.trafficSplit,
            fullOnVariant: 0,
            applications: ruleFree.applications,
            variants: ruleFree.variants,
            audienceStrict: false,
            audience: null),
      ]);

      // One context per experiment: the unit hash is cached per unit type,
      // so each assignment path must hash the UID itself.
      // [legacy] uses a 2.1 subclass with a String-typed getUnitHash.
      Future<int> treatment(Object uid, String experiment,
          {bool legacy = false}) async {
        final config = ContextConfig.create()..setUnit('u', uid);
        final completer = Completer<ContextData>()..complete(splitRule);
        final context = legacy
            ? _StringHashContext(clock, config, completer, dataProvider,
                eventHandler, variableParser, audienceMatcher)
            : Context.create(clock, config, completer, dataProvider,
                eventHandler, variableParser, audienceMatcher, null);
        await context.waitUntilReady();
        return context.peekTreatment(experiment);
      }

      for (final name in ['exp_split_rule', 'exp_no_rule']) {
        int discriminating = 0;
        for (int i = 0; i < 40; i++) {
          final int expected = await treatment('${i + 1}', name);
          expect(await treatment(i + 0.75, name), equals(expected),
              reason: '$name uid ${i + 0.75}');
          expect(
              await treatment(i + 0.75, name, legacy: true), equals(expected),
              reason: 'legacy $name uid ${i + 0.75}');
          if (await treatment('${i + 0.75}', name) != expected) {
            discriminating++;
          }
        }
        // Hashing "i.75" instead of "i+1" would change some assignments.
        expect(discriminating, greaterThan(0), reason: name);
      }
    });

    test('negativeZeroUnitHashesLikeZero', () {
      expect(Hashing.hashUnitValue(-0.0), equals(Hashing.hashUnit('0')));
      expect(Hashing.hashUnitValue(-0.4), equals(Hashing.hashUnit('-0')));
      expect(Hashing.hashUnitValue(0), equals(Hashing.hashUnit('0')));
    });

    test('numericUnitFromConfigIsHashedAsANumber', () async {
      final config = ContextConfig.create()..setUnit('float_id', 125.75);
      final Context context = Context.create(clock, config, dataFutureReady,
          dataProvider, eventHandler, variableParser, audienceMatcher, null);
      await context.waitUntilReady();
      expect(context.getUnitValue('float_id'), equals(125.75));
      expect(context.getUnitHash('float_id', 125.75),
          equals(Hashing.hashUnit('126')));
    });

    test('numericUnitHashesLikeJavaScript', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();
      context.setUnit('float_id', 125.75);
      expect(String.fromCharCodes(context.getUnitHash('float_id', 125.75)),
          equals(String.fromCharCodes(Hashing.hashUnit('126'))));
    });

    test('trackQueuesWhenNotReady', () {
      final Context context = createContextWithDefaultConfig(dataFuture);

      context.track('goal1', {'amount': 125, 'hours': 245});
      context.track('goal2', {'tries': 7});
      context.track('goal3', null);

      expect(context.getPendingCount(), equals(3));
    });

    test('publishDoesNotCallEventHandlerWhenQueueIsEmpty', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(context.getPendingCount(), equals(0));

      await context.publish();

      verifyNever(eventHandler.publish(any, any));
    });

    test('publishDoesNotCallEventHandlerWhenFailed', () async {
      final Context context = createContextWithDefaultConfig(dataFutureFailed);
      dataFutureFailed.completeError(Exception('Failed'));

      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isTrue);

      context.getTreatment('exp_test_abc');
      context.track('goal1', {'amount': 125, 'hours': 245});

      expect(context.getPendingCount(), equals(2));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verifyNever(eventHandler.publish(any, any));
    });

    test('refreshCallsEventLogger', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      reset(eventLogger);

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);
      refreshDataFuture.complete(refreshData);

      await context.refresh();

      // Verify event logger was called for the refresh event
      verify(eventLogger.handleEvent(context, EventType.refresh, refreshData))
          .called(1);
    });

    test('refreshCallsEventLoggerOnError', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      reset(eventLogger);

      final Exception failure = Exception('ERROR');
      when(dataProvider.getContextData()).thenAnswer((_) {
        final Completer<ContextData> result = Completer<ContextData>();
        result.completeError(failure);
        return result;
      });

      await expectLater(context.refresh(), throwsException);

      // Verify event logger was called for the error
      verify(eventLogger.handleEvent(context, EventType.error, failure))
          .called(1);
    });

    test('closeCallsEventLogger', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      reset(eventLogger);

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.close();

      verify(eventLogger.handleEvent(context, EventType.finalize, null))
          .called(1);
    });

    test('closeCallsEventLoggerWithPendingEvents', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 125, 'hours': 245});

      reset(eventLogger);

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.close();

      verify(eventLogger.handleEvent(context, EventType.publish, any))
          .called(1);
      verify(eventLogger.handleEvent(context, EventType.finalize, null))
          .called(1);
    });

    test('closeCallsEventLoggerOnError', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 125, 'hours': 245});

      reset(eventLogger);

      final Exception failure = Exception('FAILED');
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createErrorVoidCompleter(failure));

      await expectLater(context.close(), throwsException);

      verify(eventLogger.handleEvent(context, EventType.error, failure))
          .called(1);
    });

    test('refresh', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);
      refreshDataFuture.complete(refreshData);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      final List<String> experiments =
          refreshData.experiments.map((e) => e.name).toList();
      expect(context.getExperiments(), equals(experiments));
    });

    test('refreshClearAssignmentCacheForStoppedExperiment', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      const String experimentName = 'exp_test_abc';
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment('not_found'), equals(0));

      expect(context.getPendingCount(), equals(2));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);

      refreshData.experiments = refreshData.experiments
          .where((e) => e.name != experimentName)
          .toList();

      refreshDataFuture.complete(refreshData);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment(experimentName), equals(0));
      expect(context.getTreatment('not_found'), equals(0));

      expect(context.getPendingCount(), equals(3));
    });

    test('refreshClearAssignmentCacheForStartedExperiment', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      const String experimentName = 'exp_test_new';
      expect(context.getTreatment(experimentName), equals(0));
      expect(context.getTreatment('not_found'), equals(0));

      expect(context.getPendingCount(), equals(2));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);

      refreshDataFuture.complete(refreshData);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment('not_found'), equals(0));

      expect(context.getPendingCount(), equals(3));
    });

    test('refreshClearAssignmentCacheForFullOnExperiment', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      const String experimentName = 'exp_test_abc';
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment('not_found'), equals(0));

      expect(context.getPendingCount(), equals(2));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);

      for (var experiment in refreshData.experiments) {
        if (experiment.name == experimentName) {
          experiment.fullOnVariant = 1;
          break;
        }
      }

      refreshDataFuture.complete(refreshData);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment(experimentName), equals(1));
      expect(context.getTreatment('not_found'), equals(0));

      expect(context.getPendingCount(), equals(3));
    });

    test('refreshKeepsAssignmentCacheWhenNotChangedWithOverride', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.setOverride('exp_test_ab', 3);
      expect(context.getTreatment('exp_test_ab'), equals(3));

      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      when(dataProvider.getContextData()).thenAnswer((_) => dataFutureReady);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment('exp_test_ab'), equals(3));

      expect(context.getPendingCount(), equals(1));
    });

    test('close', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      context.track('goal1', {'amount': 125, 'hours': 245});

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.close();

      expect(context.isClosed(), isTrue);

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('closeWithEmptyQueue', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.getPendingCount(), equals(0));

      await context.close();

      expect(context.isClosed(), isTrue);

      verifyNever(eventHandler.publish(any, any));
    });

    test('startsRefreshTimerWhenReady', () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setRefreshInterval(1000);

      final context = createContext(config, dataFutureReady);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      await context.waitUntilReady();

      Completer<void> refreshCompleter = Completer<void>();
      bool refreshCalled = false;

      verifyNever(dataProvider.getContextData());

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      when(dataProvider.getContextData()).thenAnswer((_) {
        if (!refreshCalled) {
          refreshCalled = true;
          refreshCompleter.complete();
        }
        return refreshDataFutureReady;
      });

      await refreshCompleter.future;

      verify(dataProvider.getContextData()).called(1);
    });

    test('doesNotStartRefreshTimerWhenFailed', () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setRefreshInterval(1000);

      final context = createContext(config, dataFuture);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      dataFuture.completeError(Exception("test error"));
      await context.waitUntilReady();

      expect(context.isFailed(), isTrue);

      Completer<void> refreshCompleter = Completer<void>();

      verifyNever(dataProvider.getContextData());
      when(dataProvider.getContextData()).thenAnswer((_) {
        refreshCompleter.complete();
        return refreshDataFutureReady;
      });

      expect(
          () async => await refreshCompleter.future
              .timeout(const Duration(milliseconds: 2000)),
          throwsA(isA<TimeoutException>()));

      verifyNever(dataProvider.getContextData());
    });

    test('startsPublishTimeoutWhenReadyWithQueueNotEmpty', () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setPublishDelay(333);

      final context = createContext(config, dataFuture);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      context.track("goal1", {"amount": 125});

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      dataFuture.complete(data);
      await context.waitUntilReady();

      verifyNever(eventHandler.publish(any, any));

      await Future.delayed(const Duration(milliseconds: 666));

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('setUnitEmpty', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(
          () => context.setUnit("db_user_id", ""), throwsA(isA<Exception>()));
    });

    test('setOverrideClearsAssignmentCache', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      final Map<String, int> overrides = {
        "exp_test_new": 3,
        "exp_test_new_2": 5
      };

      context.setOverrides(overrides);

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      overrides.forEach((experimentName, variant) {
        expect(context.getTreatment(experimentName), equals(variant));
      });
      expect(context.getPendingCount(), equals(overrides.length));

      overrides.forEach((experimentName, variant) {
        context.setOverride(experimentName, variant);
        expect(context.getTreatment(experimentName), equals(variant));
      });
      expect(context.getPendingCount(), equals(overrides.length));

      overrides.forEach((experimentName, variant) {
        context.setOverride(experimentName, variant + 11);
        expect(context.getTreatment(experimentName), equals(variant + 11));
      });
      expect(context.getPendingCount(), equals(overrides.length * 2));

      expect(context.getTreatment("exp_test_ab"),
          equals(expectedVariants["exp_test_ab"]));
      expect(context.getPendingCount(), equals(1 + overrides.length * 2));

      context.setOverride("exp_test_ab", 9);
      expect(context.getTreatment("exp_test_ab"), equals(9));
      expect(context.getPendingCount(), equals(2 + overrides.length * 2));
    });

    test('setCustomAssignmentDoesNotOverrideFullOnOrNotEligibleAssignments',
        () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      context.setCustomAssignment("exp_test_not_eligible", 3);
      context.setCustomAssignment("exp_test_fullon", 3);

      expect(context.getTreatment("exp_test_not_eligible"), equals(0));
      expect(context.getTreatment("exp_test_fullon"), equals(2));
    });

    test('setCustomAssignmentClearsAssignmentCache', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      final Map<String, int> customAssignments = {
        "exp_test_ab": 2,
        "exp_test_abc": 3
      };

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      customAssignments.forEach((experimentName, _) {
        expect(context.getTreatment(experimentName),
            equals(expectedVariants[experimentName]));
      });
      expect(context.getPendingCount(), equals(customAssignments.length));

      context.setCustomAssignments(customAssignments);

      customAssignments.forEach((experimentName, variant) {
        expect(context.getTreatment(experimentName), equals(variant));
      });
      expect(context.getPendingCount(), equals(2 * customAssignments.length));

      customAssignments.forEach((experimentName, variant) {
        context.setCustomAssignment(experimentName, variant);
        expect(context.getTreatment(experimentName), equals(variant));
      });
      expect(context.getPendingCount(), equals(2 * customAssignments.length));

      customAssignments.forEach((experimentName, variant) {
        context.setCustomAssignment(experimentName, variant + 11);
        expect(context.getTreatment(experimentName), equals(variant + 11));
      });
      expect(context.getPendingCount(), equals(customAssignments.length * 3));
    });

    test('peekVariableValueConflictingKeyDisjointAudiences', () async {
      for (final experiment in data.experiments) {
        switch (experiment.name) {
          case "exp_test_ab":
            assert(expectedVariants["exp_test_ab"]! != 0);
            experiment.audienceStrict = true;
            experiment.audience =
                "{\"filter\":[{\"gte\":[{\"var\":\"age\"},{\"value\":20}]}]}";
            experiment.variants[expectedVariants["exp_test_ab"]!].config =
                "{\"icon\":\"arrow\"}";
            break;
          case "exp_test_abc":
            assert(expectedVariants["exp_test_abc"]! != 0);
            experiment.audienceStrict = true;
            experiment.audience =
                "{\"filter\":[{\"lt\":[{\"var\":\"age\"},{\"value\":20}]}]}";
            experiment.variants[expectedVariants["exp_test_abc"]!].config =
                "{\"icon\":\"circle\"}";
            break;
          default:
            break;
        }
      }

      {
        final context = createReadyContextWithData(data);
        await context.waitUntilReady();

        context.setAttribute("age", 20);
        expect(context.peekVariableValue("icon", "square"), equals("arrow"));
      }

      {
        final context = createReadyContextWithData(data);
        await context.waitUntilReady();

        context.setAttribute("age", 19);
        expect(context.peekVariableValue("icon", "square"), equals("circle"));
      }
    });

    test('peekVariableValuePicksLowestExperimentIdOnConflictingKey', () async {
      for (final experiment in data.experiments) {
        switch (experiment.name) {
          case "exp_test_ab":
            assert(expectedVariants["exp_test_ab"]! != 0);
            experiment.id = 99;
            experiment.variants[expectedVariants["exp_test_ab"]!].config =
                "{\"icon\":\"arrow\"}";
            break;
          case "exp_test_abc":
            assert(expectedVariants["exp_test_abc"]! != 0);
            experiment.id = 1;
            experiment.variants[expectedVariants["exp_test_abc"]!].config =
                "{\"icon\":\"circle\"}";
            break;
          default:
            break;
        }
      }

      final context = createReadyContextWithData(data);
      await context.waitUntilReady();

      expect(context.peekVariableValue("icon", "square"), equals("circle"));
    });

    test('getVariableValueConflictingKeyDisjointAudiences', () async {
      for (final experiment in data.experiments) {
        switch (experiment.name) {
          case "exp_test_ab":
            assert(expectedVariants["exp_test_ab"]! != 0);
            experiment.audienceStrict = true;
            experiment.audience =
                "{\"filter\":[{\"gte\":[{\"var\":\"age\"},{\"value\":20}]}]}";
            experiment.variants[expectedVariants["exp_test_ab"]!].config =
                "{\"icon\":\"arrow\"}";
            break;
          case "exp_test_abc":
            assert(expectedVariants["exp_test_abc"]! != 0);
            experiment.audienceStrict = true;
            experiment.audience =
                "{\"filter\":[{\"lt\":[{\"var\":\"age\"},{\"value\":20}]}]}";
            experiment.variants[expectedVariants["exp_test_abc"]!].config =
                "{\"icon\":\"circle\"}";
            break;
          default:
            break;
        }
      }

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      {
        final context = createReadyContextWithData(data);
        await context.waitUntilReady();

        context.setAttribute("age", 20);
        expect(context.getVariableValue("icon", "square"), equals("arrow"));
        expect(context.getPendingCount(), equals(1));
      }

      {
        final context = createReadyContextWithData(data);
        await context.waitUntilReady();

        context.setAttribute("age", 19);
        expect(context.getVariableValue("icon", "square"), equals("circle"));
        expect(context.getPendingCount(), equals(1));
      }
    });

    test('getTreatmentStartsPublishTimeoutAfterExposure', () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setPublishDelay(333);

      final context = createContext(config, dataFutureReady);
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      context.getTreatment("exp_test_ab");
      context.getTreatment("exp_test_abc");

      verifyNever(eventHandler.publish(any, any));

      await Future.delayed(const Duration(milliseconds: 666));

      verify(eventHandler.publish(any, any)).called(1);
    });

    test(
        'getTreatmentQueuesExposureWithAudienceMismatchTrueAndControlVariantOnAudienceMismatchInStrictMode',
        () async {
      final context = createReadyContextWithData(audienceStrictData);
      await context.waitUntilReady();

      expect(context.getTreatment("exp_test_ab"), equals(0));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('trackStartsPublishTimeoutAfterAchievement', () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setPublishDelay(333);

      final context = createContext(config, dataFutureReady);
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      context.track("goal1", {"amount": 125});
      context.track("goal2", {"value": 999.0});

      verifyNever(eventHandler.publish(any, any));

      await Future.delayed(const Duration(milliseconds: 666));

      verify(eventHandler.publish(any, any)).called(1);
    });

    test(
        'publishResetsInternalQueuesAndKeepsAttributesOverridesAndCustomAssignments',
        () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setAttributes({"attr1": "value1", "attr2": "value2"})
        ..setCustomAssignments({"exp_test_abc": 3})
        ..setOverrides({"not_found": 3});

      final context = createContext(config, dataFutureReady);
      await context.waitUntilReady();

      expect(context.getPendingCount(), equals(0));

      expect(context.getTreatment("exp_test_ab"), equals(1));
      expect(context.getTreatment("exp_test_abc"), equals(3));
      expect(context.getTreatment("not_found"), equals(3));
      context.track("goal1", {"amount": 125, "hours": 245});

      expect(context.getPendingCount(), equals(4));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();
      expect(context.getPendingCount(), equals(0));
      expect(context.getCustomAssignment("exp_test_abc"), equals(3));
      expect(context.getOverride("not_found"), equals(3));

      verify(eventHandler.publish(any, any)).called(1);

      clearInteractions(eventHandler);

      expect(context.getTreatment("exp_test_ab"), equals(1));
      expect(context.getTreatment("exp_test_abc"), equals(3));
      expect(context.getTreatment("not_found"), equals(3));
      context.track("goal1", {"amount": 125, "hours": 245});

      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();
      expect(context.getPendingCount(), equals(0));

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('publishExceptionally', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      context.track("goal1", {"amount": 125, "hours": 245});
      expect(context.getPendingCount(), equals(1));

      final failure = Exception("FAILED");
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createErrorVoidCompleter(failure));

      expect(() => context.publish(), throwsA(isA<Exception>()));

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('refreshExceptionally', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      context.track("goal1", {"amount": 125, "hours": 245});
      expect(context.getPendingCount(), equals(1));

      final failure = Exception("FAILED");
      when(dataProvider.getContextData()).thenAnswer((_) {
        final Completer<ContextData> completer = Completer<ContextData>();
        completer.completeError(failure);
        return completer;
      });
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      expect(() => context.refresh(), throwsA(isA<Exception>()));

      verify(dataProvider.getContextData()).called(1);
    });

    test('refreshFailsAndCanRetryWhenApplyingDataThrows', () async {
      final failure = Exception('parser failed');
      final throwingContext = Context.create(
          clock,
          ContextConfig.create()..setUnits(units),
          dataFutureReady,
          dataProvider,
          eventHandler,
          DefaultVariableParser(),
          audienceMatcher,
          eventLogger);
      await throwingContext.waitUntilReady();
      throwingContext.variableParser_ = _ThrowingVariableParser(failure);

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFutureReady);

      await expectLater(throwingContext.refresh(), throwsA(same(failure)))
          .timeout(const Duration(seconds: 2));
      verify(eventLogger.handleEvent(throwingContext, EventType.error, failure))
          .called(1);

      throwingContext.variableParser_ = DefaultVariableParser();
      await throwingContext.refresh().timeout(const Duration(seconds: 2));
      expect(throwingContext.getExperiments(),
          equals(refreshData.experiments.map((e) => e.name).toList()));
    });

    test('restoresRefreshTimerWhenCloseFails', () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setRefreshInterval(50);
      final context = createContext(config, dataFutureReady);
      await context.waitUntilReady();

      context.track('goal1', {'amount': 125});
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createErrorVoidCompleter(Exception('FAILED')));
      await expectLater(context.close(), throwsException);
      expect(context.isClosed(), isFalse);

      final refreshed = Completer<void>();
      when(dataProvider.getContextData()).thenAnswer((_) {
        if (!refreshed.isCompleted) refreshed.complete();
        return refreshDataFutureReady;
      });
      await refreshed.future.timeout(const Duration(seconds: 2));
      verify(dataProvider.getContextData()).called(greaterThan(0));
    });

    test('refreshKeepsAssignmentCacheWhenNotChanged', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      for (final experiment in data.experiments) {
        context.getTreatment(experiment.name);
      }
      context.getTreatment("not_found");

      expect(context.getPendingCount(), equals(data.experiments.length + 1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      when(dataProvider.getContextData()).thenReturn(refreshDataFutureReady);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      for (final experiment in refreshData.experiments) {
        context.getTreatment(experiment.name);
      }
      context.getTreatment("not_found");

      expect(
          context.getPendingCount(), equals(data.experiments.length + 1 + 1));
    });

    test('refreshKeepsAssignmentCacheWhenNotChangedOnAudienceMismatch',
        () async {
      final context = createReadyContextWithData(audienceStrictData);
      await context.waitUntilReady();

      expect(context.getTreatment("exp_test_ab"), equals(0));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      when(dataProvider.getContextData())
          .thenReturn(audienceStrictDataFutureReady);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment("exp_test_ab"), equals(0));
      expect(context.getPendingCount(), equals(1));
    });

    test('refreshClearAssignmentCacheForTrafficSplitChange', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_not_eligible";
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      when(dataProvider.getContextData()).thenReturn(refreshDataFutureReady);

      for (final experiment in refreshData.experiments) {
        if (experiment.name == experimentName) {
          experiment.trafficSplit = [0.0, 1.0];
        }
      }

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment(experimentName), equals(2));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(3));
    });

    test('refreshClearAssignmentCacheForIterationChange', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_abc";
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      when(dataProvider.getContextData()).thenReturn(refreshDataFutureReady);

      for (final experiment in refreshData.experiments) {
        if (experiment.name == experimentName) {
          experiment.iteration = 2;
          experiment.trafficSeedHi = 54870830;
          experiment.trafficSeedLo = 398724581;
          experiment.seedHi = 77498863;
          experiment.seedLo = 34737352;
        }
      }

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment(experimentName), equals(2));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(3));
    });

    test('refreshClearAssignmentCacheForExperimentIdChange', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_abc";
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      when(dataProvider.getContextData()).thenReturn(refreshDataFutureReady);

      for (final experiment in refreshData.experiments) {
        if (experiment.name == experimentName) {
          experiment.id = 11;
          experiment.trafficSeedHi = 54870830;
          experiment.trafficSeedLo = 398724581;
          experiment.seedHi = 77498863;
          experiment.seedLo = 34737352;
        }
      }

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment(experimentName), equals(2));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(3));
    });

    test('closeStopsRefreshTimer', () async {
      final config =
          ContextConfig.create().setUnits(units).setRefreshInterval(333);

      final context = createContext(config, dataFutureReady);
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      await context.close();

      expect(context.isClosed(), isTrue);

      await Future.delayed(const Duration(milliseconds: 666));

      verifyNever(dataProvider.getContextData());
    });

    test('closeExceptionally', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      final trackAttributes = {'amount': 125, 'hours': 245};
      context.track("goal1", trackAttributes);

      final failure = Exception("FAILED");

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createErrorVoidCompleter(failure));

      await expectLater(context.close(), throwsA(isA<Exception>()));

      verify(eventLogger.handleEvent(context, EventType.error, failure))
          .called(1);
    });

    test('refreshKeepsOverrides', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.setOverride('exp_test_ab', 3);
      context.setOverride('not_found', 5);
      expect(context.getOverride('exp_test_ab'), equals(3));
      expect(context.getOverride('not_found'), equals(5));

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);
      refreshDataFuture.complete(refreshData);
      await context.refresh();

      expect(context.getOverride('exp_test_ab'), equals(3));
      expect(context.getOverride('not_found'), equals(5));
    });

    test('refreshKeepsCustomAssignments', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.setCustomAssignment('exp_test_ab', 2);
      context.setCustomAssignment('exp_test_abc', 3);
      expect(context.getCustomAssignment('exp_test_ab'), equals(2));
      expect(context.getCustomAssignment('exp_test_abc'), equals(3));

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);
      refreshDataFuture.complete(refreshData);
      await context.refresh();

      expect(context.getCustomAssignment('exp_test_ab'), equals(2));
      expect(context.getCustomAssignment('exp_test_abc'), equals(3));
    });

    test('getTreatmentQueuesExposureAfterPeek', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      for (final experiment in data.experiments) {
        context.peekTreatment(experiment.name);
      }
      context.peekTreatment('not_found');

      expect(context.getPendingCount(), equals(0));

      for (final experiment in data.experiments) {
        context.getTreatment(experiment.name);
      }
      context.getTreatment('not_found');

      expect(context.getPendingCount(), equals(data.experiments.length + 1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('getTreatmentQueuesExposureWithCustomAssignmentVariant', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.setCustomAssignment('exp_test_ab', 2);

      expect(context.getTreatment('exp_test_ab'), equals(2));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('getVariableValueQueuesExposureAfterPeekVariableValue', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      context.peekVariableValue('banner.border', 17);
      context.peekVariableValue('banner.size', 'small');

      expect(context.getPendingCount(), equals(0));

      context.getVariableValue('banner.border', 17);
      context.getVariableValue('banner.size', 'small');

      expect(context.getPendingCount(), equals(1));

      await context.close();
    });

    test('getVariableValueQueuesExposuresOnlyOnce', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      context.getVariableValue('banner.border', 17);
      context.getVariableValue('banner.size', 'small');

      expect(context.getPendingCount(), equals(1));

      context.getVariableValue('banner.border', 17);
      context.getVariableValue('banner.size', 'small');

      expect(context.getPendingCount(), equals(1));

      await context.close();
    });

    test('closeDoesNotCallEventHandlerWhenFailed', () async {
      final context = createContextWithDefaultConfig(dataFutureFailed);
      dataFutureFailed.completeError(Exception('Failed'));

      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isTrue);

      context.track('goal1', {'amount': 125});

      await context.close();

      expect(context.isClosed(), isTrue);

      verifyNever(eventHandler.publish(any, any));
    });

    test('closePropagatesClientErrorMessage', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 125});

      final failure = Exception('PUBLISH_ERROR');
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createErrorVoidCompleter(failure));

      await expectLater(context.close(), throwsA(isA<Exception>()));

      // A failed final publish leaves the context open and retryable with
      // its events still queued (JS context.ts _finalize).
      expect(context.isClosed(), isFalse);
      expect(context.isClosing(), isFalse);
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());
      await context.close();

      expect(context.isClosed(), isTrue);
      expect(context.getPendingCount(), equals(0));
      verify(eventLogger.handleEvent(context, EventType.finalize, null))
          .called(1);
    });

    test('publishDoesNotClearQueueOnFailure', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 125});
      expect(context.getPendingCount(), equals(1));

      final failure = Exception('FAILED');
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createErrorVoidCompleter(failure));

      await expectLater(context.publish(), throwsA(isA<Exception>()));

      expect(context.getPendingCount(), equals(1));
    });

    test('publishClearsQueueOnSuccess', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 125});
      context.track('goal2', {'tries': 7});
      expect(context.getPendingCount(), equals(2));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      expect(context.getPendingCount(), equals(0));
    });

    test('publishKeepsQueueOnFailure', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 125});
      context.track('goal2', {'tries': 7});
      expect(context.getPendingCount(), equals(2));

      when(eventHandler.publish(any, any)).thenAnswer(
          (_) => createErrorVoidCompleter(Exception('publish error')));

      await expectLater(context.publish(), throwsException);

      expect(context.getPendingCount(), equals(2));
    });

    test('refreshPreservesExposedFlagForUnchangedExperiment', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      const String experimentName = 'exp_test_ab';
      context.getTreatment(experimentName);
      expect(context.getPendingCount(), equals(1));

      when(dataProvider.getContextData()).thenAnswer((_) => dataFutureReady);

      await context.refresh();

      context.getTreatment(experimentName);
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());
      await context.close();
    });

    test('setAttributeReturnsLastSetValue', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.setAttribute('attr1', 'value1');
      context.setAttribute('attr1', 'value2');

      expect(context.getAttribute('attr1'), equals('value2'));
    });

    test('setUnitsThrowsAfterClose', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.close();

      expect(() => context.setUnit('test', 'test'), throwsA(isA<Exception>()));
    });

    test('setOverrideSucceedsAfterClose', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.close();

      expect(() => context.setOverride('exp_test', 2), returnsNormally);
      expect(context.getOverride('exp_test'), equals(2));
    });

    test('setCustomAssignmentThrowsAfterClose', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.close();

      expect(() => context.setCustomAssignment('exp_test', 2),
          throwsA(isA<Exception>()));
    });

    test('refreshThrowsAfterClose', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.close();

      expect(() => context.refresh(), throwsA(isA<Exception>()));
    });

    test('publishThrowsAfterClose', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.close();

      expect(() => context.publish(), throwsA(isA<Exception>()));
    });

    test('trackThrowsAfterClose', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.close();

      expect(() => context.track('goal1', null), throwsA(isA<Exception>()));
    });

    test('getTreatmentReturnsBaseVariantOnUnknownExperiment', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      expect(context.getTreatment('unknown_experiment'), equals(0));
      expect(context.getPendingCount(), equals(1));

      await context.close();
    });

    test('peekTreatmentReturnsBaseVariantOnUnknownExperiment', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      expect(context.peekTreatment('unknown_experiment'), equals(0));
      expect(context.getPendingCount(), equals(0));
    });

    test('getVariableValueReturnsDefaultOnUnknownVariable', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      expect(context.getVariableValue('unknown_variable', 42), equals(42));
    });

    test('peekVariableValueReturnsDefaultOnUnknownVariable', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      expect(context.peekVariableValue('unknown_variable', 42), equals(42));
      expect(context.getPendingCount(), equals(0));
    });

    test('doesNotStartRefreshTimerWithZeroInterval', () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setRefreshInterval(0);

      final context = createContext(config, dataFutureReady);
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);

      await Future.delayed(const Duration(milliseconds: 500));

      verifyNever(dataProvider.getContextData());
    });

    test('getUnitsReturnsActualUnits', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      final returnedUnits = context.getUnits();
      expect(returnedUnits, equals(units));
      expect(returnedUnits['session_id'],
          equals('e791e240fcd3df7d238cfc285f475e8152fcc0ec'));
      expect(returnedUnits['user_id'], equals('123456789'));
      expect(returnedUnits['email'], equals('bleh@absmartly.com'));
    });

    test('getUnitsReturnsACopy', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      final returnedUnits = context.getUnits();
      returnedUnits['new_key'] = 'value';
      expect(context.getUnit('new_key'), isNull);
      expect(context.getUnits().containsKey('new_key'), isFalse);
    });

    test('getUnitsKeepsTheReleasedStringMapType', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      final Map<String, String> released = context.getUnits();
      expect(released, equals(units));
      final String? uid = context.getUnit('session_id');
      expect(uid, equals('e791e240fcd3df7d238cfc285f475e8152fcc0ec'));

      context.setUnit('org_id', 42);
      final Map<String, String> after = context.getUnits();
      expect(after['org_id'], equals('42'));
      final Map<String, String> field = context.units_;
      expect(field['org_id'], equals('42'));
    });

    test('trackPassesPropertiesToGoalAchievement', () async {
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      final Context context = createReadyContext();
      await context.waitUntilReady();

      final properties = {'amount': 125, 'currency': 'USD'};
      context.track('goal1', properties);

      expect(context.getPendingCount(), equals(1));

      await context.publish();

      final captured =
          verify(eventHandler.publish(context, captureAny)).captured;
      final event = captured.first as PublishEvent;
      expect(event.goals.length, equals(1));
      expect(event.goals[0].name, equals('goal1'));
      expect(event.goals[0].properties, equals(properties));
    });

    test('trackWithNullPropertiesPublishesNull', () async {
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      final Context context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', null);

      await context.publish();

      final captured =
          verify(eventHandler.publish(context, captureAny)).captured;
      final event = captured.first as PublishEvent;
      expect(event.goals[0].properties, isNull);
    });

    test('readyErrorReturnsNullOnSuccess', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      expect(context.readyError(), isNull);
    });

    test('readyErrorReturnsErrorOnFailure', () async {
      final Context context = createContextWithDefaultConfig(dataFutureFailed);

      final Exception error = Exception('FAILED');
      dataFutureFailed.completeError(error);

      await context.waitUntilReady();

      expect(context.isFailed(), isTrue);
      expect(context.readyError(), equals(error));
    });

    test('getCustomFieldKeys', () async {
      final Context context = createReadyContextWithData(customFieldsData);
      await context.waitUntilReady();

      final keys = context.getCustomFieldKeys();
      expect(keys, containsAll(['country', 'overrides', 'languages']));
    });

    test('getCustomFieldKeysReturnsEmptySetWhenNoCustomFields', () async {
      final Context context = createReadyContext();
      await context.waitUntilReady();

      final keys = context.getCustomFieldKeys();
      expect(keys, isEmpty);
    });

    test('getCustomFieldValue', () async {
      final Context context = createReadyContextWithData(customFieldsData);
      await context.waitUntilReady();

      expect(context.getCustomFieldValue('exp_test_ab', 'country'),
          equals('US,PT,ES,DE,FR'));
      expect(context.getCustomFieldValue('exp_test_abc', 'country'),
          equals('US,PT,ES'));
      expect(context.getCustomFieldValue('exp_test_abc', 'languages'),
          equals('en-US,en-GB,pt-PT,pt-BR,es-ES,es-MX'));
      expect(context.getCustomFieldValue('exp_test_ab', 'overrides'),
          equals({'123': 1, '456': 0}));
    });

    test('getCustomFieldValueReturnsNullForMissingKeyOrExperiment', () async {
      final Context context = createReadyContextWithData(customFieldsData);
      await context.waitUntilReady();

      expect(context.getCustomFieldValue('exp_test_ab', 'missing'), isNull);
      expect(
          context.getCustomFieldValue('not_an_experiment', 'country'), isNull);
      expect(
          context.getCustomFieldValue('exp_test_no_custom_fields', 'country'),
          isNull);
    });

    test('getCustomFieldValueType', () async {
      final Context context = createReadyContextWithData(customFieldsData);
      await context.waitUntilReady();

      expect(context.getCustomFieldValueType('exp_test_ab', 'country'),
          equals('string'));
      expect(context.getCustomFieldValueType('exp_test_ab', 'overrides'),
          equals('json'));
      expect(context.getCustomFieldValueType('exp_test_abc', 'languages'),
          equals('string'));
    });

    test('getCustomFieldValueTypeReturnsNullForMissingKeyOrExperiment',
        () async {
      final Context context = createReadyContextWithData(customFieldsData);
      await context.waitUntilReady();

      expect(context.getCustomFieldValueType('exp_test_ab', 'missing'), isNull);
      expect(context.getCustomFieldValueType('not_an_experiment', 'country'),
          isNull);
      expect(
          context.getCustomFieldValueType(
              'exp_test_no_custom_fields', 'country'),
          isNull);
    });

    test('customFieldKeysAliasMatchesGetCustomFieldKeys', () async {
      final Context context = createReadyContextWithData(customFieldsData);
      await context.waitUntilReady();

      expect(context.customFieldKeys(), equals(context.getCustomFieldKeys()));
    });

    test('customFieldValueAliasMatchesGetCustomFieldValue', () async {
      final Context context = createReadyContextWithData(customFieldsData);
      await context.waitUntilReady();

      expect(context.customFieldValue('exp_test_ab', 'country'),
          equals(context.getCustomFieldValue('exp_test_ab', 'country')));
      expect(context.customFieldValue('exp_test_ab', 'overrides'),
          equals(context.getCustomFieldValue('exp_test_ab', 'overrides')));
      expect(context.customFieldValue('not_found', 'country'),
          equals(context.getCustomFieldValue('not_found', 'country')));
    });

    test('customFieldValueTypeAliasMatchesGetCustomFieldValueType', () async {
      final Context context = createReadyContextWithData(customFieldsData);
      await context.waitUntilReady();

      expect(context.customFieldValueType('exp_test_ab', 'country'),
          equals(context.getCustomFieldValueType('exp_test_ab', 'country')));
      expect(context.customFieldValueType('exp_test_ab', 'overrides'),
          equals(context.getCustomFieldValueType('exp_test_ab', 'overrides')));
      expect(context.customFieldValueType('not_found', 'country'),
          equals(context.getCustomFieldValueType('not_found', 'country')));
    });

    test('setDataSortsConflictingVariablesByExperimentId', () async {
      for (final experiment in data.experiments) {
        switch (experiment.name) {
          case "exp_test_ab":
            experiment.id = 99;
            experiment.variants[expectedVariants["exp_test_ab"]!].config =
                "{\"shared_var\":\"from_ab\"}";
            break;
          case "exp_test_abc":
            experiment.id = 1;
            experiment.variants[expectedVariants["exp_test_abc"]!].config =
                "{\"shared_var\":\"from_abc\"}";
            break;
          default:
            break;
        }
      }

      final context = createReadyContextWithData(data);
      await context.waitUntilReady();

      final variableKeys = context.getVariableKeys();
      expect(variableKeys['shared_var'], isNotNull);
      expect(variableKeys['shared_var']!.first, equals('exp_test_abc'));
    });

    test('concurrentPublishSendsEachEventOnce', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 1});
      context.track('goal2', {'amount': 2});

      final List<PublishEvent> sent = [];
      final List<Completer<void>> pending = [];
      when(eventHandler.publish(any, any)).thenAnswer((invocation) {
        sent.add(invocation.positionalArguments[1] as PublishEvent);
        final completer = Completer<void>();
        pending.add(completer);
        return completer;
      });

      final first = context.publish();
      final second = context.publish();
      await Future.delayed(Duration.zero);

      // The second publish waits for the in-flight one instead of resending.
      expect(sent.length, equals(1));
      expect(sent[0].goals!.map((g) => g.name), equals(['goal1', 'goal2']));
      expect(context.getPendingCount(), equals(0));

      context.track('goal3', {'amount': 3});
      pending[0].complete();
      await first;
      await Future.delayed(Duration.zero);

      expect(sent.length, equals(2));
      expect(sent[1].goals!.map((g) => g.name), equals(['goal3']));
      pending[1].complete();
      await second;

      expect(context.getPendingCount(), equals(0));
    });

    test('failedPublishRestoresBatchAheadOfNewerEvents', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 1});

      final List<PublishEvent> sent = [];
      final List<Completer<void>> pending = [];
      when(eventHandler.publish(any, any)).thenAnswer((invocation) {
        sent.add(invocation.positionalArguments[1] as PublishEvent);
        final completer = Completer<void>();
        pending.add(completer);
        return completer;
      });

      final first = context.publish();
      context.track('goal2', {'amount': 2});
      pending[0].completeError(Exception('FAILED'));
      await expectLater(first, throwsA(isA<Exception>()));

      expect(context.getPendingCount(), equals(2));

      final retry = context.publish();
      pending[1].complete();
      await retry;

      expect(sent[1].goals!.map((g) => g.name), equals(['goal1', 'goal2']));
      expect(context.getPendingCount(), equals(0));
    });

    test('publisherThrowingSynchronouslyKeepsEventsQueued', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 1});
      when(eventHandler.publish(any, any)).thenThrow(Exception('SYNC'));

      await expectLater(context.publish(), throwsA(isA<Exception>()));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());
      await context.publish();
      expect(context.getPendingCount(), equals(0));
    });

    test('closeWaitsForInFlightPublish', () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      context.track('goal1', {'amount': 1});

      final inFlight = Completer<void>();
      when(eventHandler.publish(any, any)).thenAnswer((_) => inFlight);

      final publishing = context.publish();
      expect(context.getPendingCount(), equals(0));

      final closing1 = context.close();
      final closing2 = context.close();
      expect(context.isClosing(), isTrue);
      expect(context.isClosed(), isFalse);

      inFlight.complete();
      await publishing;
      await closing1;
      await closing2;

      expect(context.isClosed(), isTrue);
      verify(eventHandler.publish(any, any)).called(1);
      verify(eventLogger.handleEvent(context, EventType.finalize, null))
          .called(1);
    });

    test('throwingEventLoggerDoesNotFailPublish', () async {
      final context = Context.create(
          clock,
          ContextConfig.create()..setUnits(units),
          dataFutureReady,
          dataProvider,
          eventHandler,
          variableParser,
          audienceMatcher,
          _ThrowingEventLogger());
      await context.waitUntilReady();

      context.track('goal1', {'amount': 1});
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();
      expect(context.getPendingCount(), equals(0));
      verify(eventHandler.publish(any, any)).called(1);
    });

    test('refreshOnFailedContextIsNoOp', () async {
      final context = createContextWithDefaultConfig(dataFutureFailed);
      dataFutureFailed.completeError(Exception('FAILED'));
      await context.waitUntilReady();
      expect(context.isFailed(), isTrue);

      await context.refresh();

      verifyNever(dataProvider.getContextData());
      expect(context.isFailed(), isTrue);
    });

    test('refreshCompletingAfterCloseDoesNotRearmRefreshTimer', () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setRefreshInterval(60000);
      final context = createContext(config, dataFutureReady);
      await context.waitUntilReady();
      expect(context.refreshTimer_, isNotNull);

      final refreshing = Completer<ContextData>();
      when(dataProvider.getContextData()).thenAnswer((_) => refreshing);
      final refresh = context.refresh();

      await context.close();
      expect(context.refreshTimer_, isNull);

      refreshing.complete(refreshData);
      await refresh;

      expect(context.refreshTimer_, isNull);
    });

    test('assignmentsStickyAcrossRefreshWhenOnlySeedsSplitConfigChange',
        () async {
      final context = createReadyContext();
      await context.waitUntilReady();

      const String experimentName = 'exp_test_ab';
      final int variant = context.getTreatment(experimentName);
      expect(context.getPendingCount(), equals(1));

      final contextBytes = await getResourceBytes("context.json");
      final changed = deser.deserialize(contextBytes, 0, contextBytes.length)!;
      final experiment =
          changed.experiments.firstWhere((e) => e.name == experimentName);
      experiment.seedHi = experiment.seedHi + 1;
      experiment.seedLo = experiment.seedLo + 1;
      experiment.split = [0.99, 0.01];
      experiment.audience = '{"filter":[{"value":false}]}';
      experiment.variants[1].config = '{"banner.border":2}';

      final refreshing = Completer<ContextData>()..complete(changed);
      when(dataProvider.getContextData()).thenAnswer((_) => refreshing);
      await context.refresh();

      expect(context.getTreatment(experimentName), equals(variant));
      expect(context.getPendingCount(), equals(1));

      // A trafficSplit change invalidates the cached assignment.
      final contextBytes2 = await getResourceBytes("context.json");
      final moved = deser.deserialize(contextBytes2, 0, contextBytes2.length)!;
      moved.experiments
          .firstWhere((e) => e.name == experimentName)
          .trafficSplit = [0.5, 0.5];
      final refreshing2 = Completer<ContextData>()..complete(moved);
      when(dataProvider.getContextData()).thenAnswer((_) => refreshing2);
      await context.refresh();

      context.getTreatment(experimentName);
      expect(context.getPendingCount(), equals(2));
    });

    test('indeterminateAudienceKeepsCachedMismatchAssignment', () async {
      final context = createReadyContextWithData(audienceData);
      await context.waitUntilReady();
      context.setAttribute('age', 10);

      context.getTreatment('exp_test_ab');
      expect(context.getPendingCount(), equals(1));
      expect(context.exposures_.last.audienceMismatch, isTrue);

      final bytes = await getResourceBytes("audience_context.json");
      final changed = deser.deserialize(bytes, 0, bytes.length)!;
      changed.experiments.firstWhere((e) => e.name == 'exp_test_ab').audience =
          'not json';
      final refreshing = Completer<ContextData>()..complete(changed);
      when(dataProvider.getContextData()).thenAnswer((_) => refreshing);
      await context.refresh();

      // The audience now evaluates to null: JS keeps the cached flag rather
      // than treating it as a change, so no second exposure is queued.
      context.setAttribute('other', 1);
      context.getTreatment('exp_test_ab');
      expect(context.getPendingCount(), equals(1));
    });
  });
}

class _ThrowingEventLogger implements ContextEventLogger {
  @override
  void handleEvent(Context context, EventType type, dynamic data) {
    throw Exception('logger failure');
  }
}

class _ThrowingVariableParser implements VariableParser {
  _ThrowingVariableParser(this.error);
  final Exception error;

  @override
  Map<String, dynamic>? parse(Context context, String experimentName,
      String variantName, String variableValue) {
    throw error;
  }
}

// A 2.1-style subclass: setUnits overridden with the released String types.
class _StringUnitsContext extends Context {
  _StringUnitsContext(
      Clock clock,
      ContextConfig config,
      Completer<ContextData> dataFuture,
      ContextDataProvider dataProvider,
      ContextEventHandler eventHandler,
      VariableParser variableParser,
      AudienceMatcher audienceMatcher)
      : super(clock, config, dataFuture, dataProvider, eventHandler,
            variableParser, audienceMatcher, null);

  Map<String, String>? seen;

  @override
  void setUnits(Map<String, String> units) {
    seen = Map.of(units);
    super.setUnits(units);
  }
}

class _FailOnceVariableParser extends DefaultVariableParser {
  bool _failed = false;

  @override
  Map<String, dynamic>? parse(Context context, String experimentName,
      String variantName, String config) {
    if (!_failed) {
      _failed = true;
      throw StateError('bad config');
    }
    return super.parse(context, experimentName, variantName, config);
  }
}

// 2.1-style subclasses whose units_ is a plain sorted map.
class _SortedUnitsConfig extends ContextConfig {
  @override
  Map<String, String> units_ = SplayTreeMap<String, String>();
}

class _SortedUnitsContext extends Context {
  _SortedUnitsContext(
      Clock clock,
      ContextConfig config,
      Completer<ContextData> dataFuture,
      ContextDataProvider dataProvider,
      ContextEventHandler eventHandler,
      VariableParser variableParser,
      AudienceMatcher audienceMatcher)
      : super(clock, config, dataFuture, dataProvider, eventHandler,
            variableParser, audienceMatcher, null);

  @override
  final Map<String, String> units_ = SplayTreeMap<String, String>();
}

class _GetUnitsOnlyConfig implements ContextConfig {
  @override
  Map<String, String> getUnits() => {'session_id': 'abc'};

  @override
  Map<String, dynamic> getAttributes() => {};

  @override
  Map<String, int> getOverrides() => {};

  @override
  Map<String, int> getCustomAssignments() => {};

  @override
  int getPublishDelay() => -1;

  @override
  int getRefreshInterval() => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

class _CountingUnitsConfig extends ContextConfig {
  int getUnitsCalls = 0;

  @override
  Map<String, String> getUnits() {
    getUnitsCalls++;
    return super.getUnits();
  }
}

// A 2.1-style subclass whose setUnits drops one unit and rewrites another.
class _RewritingUnitsContext extends Context {
  _RewritingUnitsContext(
      Clock clock,
      ContextConfig config,
      Completer<ContextData> dataFuture,
      ContextDataProvider dataProvider,
      ContextEventHandler eventHandler,
      VariableParser variableParser,
      AudienceMatcher audienceMatcher)
      : super(clock, config, dataFuture, dataProvider, eventHandler,
            variableParser, audienceMatcher, null);

  @override
  void setUnits(Map<String, String> units) {
    super.setUnits({'session_id': 'p-${units['session_id']}'});
  }
}

// A 2.1-style subclass with the released String-typed hash override.
class _StringHashContext extends Context {
  _StringHashContext(
      Clock clock,
      ContextConfig config,
      Completer<ContextData> dataFuture,
      ContextDataProvider dataProvider,
      ContextEventHandler eventHandler,
      VariableParser variableParser,
      AudienceMatcher audienceMatcher)
      : super(clock, config, dataFuture, dataProvider, eventHandler,
            variableParser, audienceMatcher, null);

  final List<String> hashedUids = [];

  @override
  Uint8List getUnitHash(final String unitType, final String unitUID) {
    hashedUids.add(unitUID);
    return super.getUnitHash(unitType, unitUID);
  }
}

// A 2.1-style subclass exposing its units through the getters only.
class _GetterUnitsContext extends Context {
  _GetterUnitsContext(
      Clock clock,
      ContextConfig config,
      Completer<ContextData> dataFuture,
      ContextDataProvider dataProvider,
      ContextEventHandler eventHandler,
      VariableParser variableParser,
      AudienceMatcher audienceMatcher)
      : super(clock, config, dataFuture, dataProvider, eventHandler,
            variableParser, audienceMatcher, null);

  @override
  String? getUnit(final String unitType) =>
      unitType == 'session_id' ? 'abc' : null;

  @override
  Map<String, String> getUnits() => {'session_id': 'abc'};
}

// A 2.1-style subclass whose getters report another UID than units_ holds.
class _OtherUnitContext extends Context {
  _OtherUnitContext(
      Clock clock,
      ContextConfig config,
      Completer<ContextData> dataFuture,
      ContextDataProvider dataProvider,
      ContextEventHandler eventHandler,
      VariableParser variableParser,
      AudienceMatcher audienceMatcher)
      : super(clock, config, dataFuture, dataProvider, eventHandler,
            variableParser, audienceMatcher, null);

  @override
  String? getUnit(final String unitType) =>
      super.getUnit(unitType) == null ? null : 'other';

  @override
  Map<String, String> getUnits() =>
      super.getUnits().map((key, _) => MapEntry(key, 'other'));
}
