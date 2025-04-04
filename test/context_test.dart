import 'dart:async';

import 'package:absmartly_sdk/audience_matcher.dart';
import 'package:absmartly_sdk/context.dart';
import 'package:absmartly_sdk/context_config.dart';
import 'package:absmartly_sdk/context_data_provider.dart';
import 'package:absmartly_sdk/context_event_handler.dart';
import 'package:absmartly_sdk/context_event_logger.dart';
import 'package:absmartly_sdk/default_audience_deserializer.dart';
import 'package:absmartly_sdk/default_context_data_serializer.dart';
import 'package:absmartly_sdk/default_variable_parser.dart';
import 'package:absmartly_sdk/java/time/clock.dart';
import 'package:absmartly_sdk/json/context_data.dart';
import 'package:absmartly_sdk/json/exposure.dart';
import 'package:absmartly_sdk/json/goal_achievement.dart';
import 'package:absmartly_sdk/variable_parser.dart';
import 'package:flutter_test/flutter_test.dart';
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
      TestWidgetsFlutterBinding.ensureInitialized();

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

      await context.ready();

      expect(context.isReady(), isTrue);
      expect(context.getData(), equals(data));
    });

    test('becomesReadyAndFailedWithCompletedExceptionallyFuture', () async {
      final Context context = createContextWithDefaultConfig(dataFutureFailed);

      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      dataFutureFailed.completeError(Exception('FAILED'));

      await context.ready();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isTrue);
    });

    test('becomesReadyAndFailedWithException', () async {
      final Context context = createContextWithDefaultConfig(dataFuture);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      dataFuture.completeError(Exception('FAILED'));

      await context.ready();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isTrue);
    });

    test('callsEventLoggerWhenReady', () async {
      final Context context = createContextWithDefaultConfig(dataFuture);

      dataFuture.complete(data);

      await context.ready();

      // Verify event logger was called with Ready event
      verify(eventLogger.handleEvent(context, EventType.Ready, data)).called(1);
    });

    test('callsEventLoggerWithCompletedFuture', () async {
      final Context context = createReadyContext();
      await context.ready();

      // Verify event logger was called with Ready event
      verify(eventLogger.handleEvent(context, EventType.Ready, data)).called(1);
    });

    test('callsEventLoggerWithException', () async {
      final Context context = createContextWithDefaultConfig(dataFuture);

      final Exception error = Exception('FAILED');
      dataFuture.completeError(error);

      await context.ready();

      // Verify event logger was called with Error event
      verify(eventLogger.handleEvent(context, EventType.Error, error))
          .called(1);
    });

    test('ready', () async {
      final Context context = createContextWithDefaultConfig(dataFuture);
      expect(context.isReady(), isFalse);

      // Start a separate task to complete the future
      Future.delayed(Duration.zero, () {
        dataFuture.complete(data);
      });

      await context.ready();

      expect(context.isReady(), isTrue);
      expect(context.getData(), equals(data));
    });

    test('readyWithCompletedFuture', () async {
      final Context context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);
      expect(context.getData(), equals(data));
    });

    test('throwsWhenNotReady', () {
      final Context context = createContextWithDefaultConfig(dataFuture);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      expect(() => context.peekTreatment('exp_test_ab'),
          throwsA(isA<Exception>()));
      expect(
          () => context.getTreatment('exp_test_ab'), throwsA(isA<Exception>()));
      expect(() => context.getData(), throwsA(isA<Exception>()));
      expect(() => context.getExperiments(), throwsA(isA<Exception>()));
      expect(() => context.getVariableValue('banner.border', 17),
          throwsA(isA<Exception>()));
      expect(() => context.peekVariableValue('banner.border', 17),
          throwsA(isA<Exception>()));
      expect(() => context.getVariableKeys(), throwsA(isA<Exception>()));
    });

    test('throwsWhenFinalized', () async {
      final Context context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      context.track('goal1', {'amount': 125, 'hours': 245});

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.finalize();

      expect(context.isFinalized(), isTrue);

      expect(() => context.setAttribute('attr1', 'value1'),
          throwsA(isA<Exception>()));
      expect(() => context.setAttributes({'attr1': 'value1'}),
          throwsA(isA<Exception>()));
      expect(() => context.setOverride('exp_test_ab', 2),
          throwsA(isA<Exception>()));
      expect(() => context.setOverrides({'exp_test_ab': 2}),
          throwsA(isA<Exception>()));
      expect(() => context.setUnit('test', 'test'), throwsA(isA<Exception>()));
      expect(() => context.setCustomAssignment('exp_test_ab', 2),
          throwsA(isA<Exception>()));
      expect(() => context.setCustomAssignments({'exp_test_ab': 2}),
          throwsA(isA<Exception>()));
      expect(() => context.peekTreatment('exp_test_ab'),
          throwsA(isA<Exception>()));
      expect(
          () => context.getTreatment('exp_test_ab'), throwsA(isA<Exception>()));
      expect(() => context.track('goal1', null), throwsA(isA<Exception>()));
      expect(() => context.publish(), throwsA(isA<Exception>()));
      expect(() => context.getData(), throwsA(isA<Exception>()));
      expect(() => context.getExperiments(), throwsA(isA<Exception>()));
      expect(() => context.getVariableValue('banner.border', 17),
          throwsA(isA<Exception>()));
      expect(() => context.peekVariableValue('banner.border', 17),
          throwsA(isA<Exception>()));
      expect(() => context.getVariableKeys(), throwsA(isA<Exception>()));
    });

    test('getExperiments', () async {
      final Context context = createReadyContext();
      await context.ready();

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
      await context.ready();

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
      await context.ready();

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

      await context.ready();

      context.getTreatment('exp_test_ab');

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('setUnitThrowsOnAlreadySet', () async {
      final Context context = createReadyContext();
      await context.ready();

      expect(() => context.setUnit('session_id', 'new_uid'),
          throwsA(isA<Exception>()));
    });

    test('peekTreatment', () async {
      final Context context = createReadyContext();
      await context.ready();

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
      await context.ready();

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
      await context.ready();

      expect(context.peekTreatment('exp_test_ab'), equals(1));
    });

    test('peekTreatmentReturnsControlVariantOnAudienceMismatchStrictMode',
        () async {
      final Context context = createReadyContextWithData(audienceStrictData);
      await context.ready();

      expect(context.peekTreatment('exp_test_ab'), equals(0));
    });

    test('getTreatment', () async {
      final Context context = createReadyContext();
      await context.ready();

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
      await context.ready();

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
      await context.ready();

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
      await context.ready();

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
      await context.ready();

      expect(context.getTreatment('exp_test_ab'), equals(1));
      expect(context.getPendingCount(), equals(1));

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('getTreatmentCallsEventLogger', () async {
      final Context context = createReadyContext();
      await context.ready();

      // Clear any previous invocations
      reset(eventLogger);

      context.getTreatment('exp_test_ab');
      context.getTreatment('not_found');

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
      verify(eventLogger.handleEvent(context, EventType.Exposure, any))
          .called(expectedExposures.length);

      // Verify not called again with the same exposure
      reset(eventLogger);
      context.getTreatment('exp_test_ab');
      context.getTreatment('not_found');

      verifyNever(eventLogger.handleEvent(context, EventType.Exposure, any));
    });

    test('getVariableValueCallsEventLogger', () async {
      final Context context = createReadyContext();
      await context.ready();

      // Clear any previous invocations
      reset(eventLogger);

      context.getVariableValue('banner.border', null);
      context.getVariableValue('banner.size', null);

      // Verify event logger was called once for the experiment exposure
      verify(eventLogger.handleEvent(context, EventType.Exposure, any))
          .called(1);

      // Verify not called again with the same exposure
      reset(eventLogger);
      context.getVariableValue('banner.border', null);
      context.getVariableValue('banner.size', null);

      verifyNever(eventLogger.handleEvent(context, EventType.Exposure, any));
    });

    test('peekVariableValue', () async {
      final Context context = createReadyContext();
      await context.ready();

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
      await context.ready();

      expect(
          context.peekVariableValue('banner.size', 'small'), equals('large'));
    });

    test('peekVariableValueReturnsControlVariantOnAudienceMismatchStrictMode',
        () async {
      final Context context = createReadyContextWithData(audienceStrictData);
      await context.ready();

      expect(
          context.peekVariableValue('banner.size', 'small'), equals('small'));
    });

    test('getVariableValue', () async {
      final Context context = createReadyContext();
      await context.ready();

      final Set<String> experiments =
          data.experiments.map((e) => e.name).toSet();

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
      await context.ready();

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
      await context.ready();

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
      await context.ready();

      expect(context.getVariableValue('banner.size', 'small'), equals('small'));
      expect(context.getPendingCount(), equals(0));
    });

    test('getVariableKeys', () async {
      final Context context = createReadyContextWithData(refreshData);
      await context.ready();

      expect(context.getVariableKeys(), equals(variableExperiments));
    });

    test('trackCallsEventLogger', () async {
      final Context context = createReadyContext();
      await context.ready();

      // Clear any previous invocations
      reset(eventLogger);

      final Map<String, dynamic> properties = {'amount': 125, 'hours': 245};
      context.track('goal1', properties);

      final List<GoalAchievement> expectedAchievements = [
        GoalAchievement(
            name: 'goal1', achievedAt: clock.millis(), properties: properties)
      ];

      // Verify event logger was called for the goal achievement
      verify(eventLogger.handleEvent(context, EventType.Goal, any))
          .called(expectedAchievements.length);

      // Verify called again with the same goal (unlike exposures, goals can be tracked multiple times)
      reset(eventLogger);
      context.track('goal1', properties);

      verify(eventLogger.handleEvent(context, EventType.Goal, any)).called(1);
    });

    test('publishCallsEventLogger', () async {
      final Context context = createReadyContext();
      await context.ready();

      context.track('goal1', {'amount': 125, 'hours': 245});

      reset(eventLogger);

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.publish();

      verify(eventLogger.handleEvent(context, EventType.Publish, any))
          .called(1);
    });

    test('publishCallsEventLoggerOnError', () async {
      final Context context = createReadyContext();
      await context.ready();

      context.track('goal1', {'amount': 125, 'hours': 245});

      reset(eventLogger);

      final Exception failure = Exception('ERROR');
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createErrorVoidCompleter(failure));

      await expectLater(context.publish(), throwsA(isA<Exception>()));

      verify(eventLogger.handleEvent(context, EventType.Error, failure))
          .called(1);
    });

    test('track', () async {
      final Context context = createReadyContext();
      await context.ready();

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

    test('trackQueuesWhenNotReady', () {
      final Context context = createContextWithDefaultConfig(dataFuture);

      context.track('goal1', {'amount': 125, 'hours': 245});
      context.track('goal2', {'tries': 7});
      context.track('goal3', null);

      expect(context.getPendingCount(), equals(3));
    });

    test('publishDoesNotCallEventHandlerWhenQueueIsEmpty', () async {
      final Context context = createReadyContext();
      await context.ready();

      expect(context.getPendingCount(), equals(0));

      await context.publish();

      verifyNever(eventHandler.publish(any, any));
    });

    test('publishDoesNotCallEventHandlerWhenFailed', () async {
      final Context context = createContextWithDefaultConfig(dataFutureFailed);
      dataFutureFailed.completeError(Exception('Failed'));

      await context.ready();

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
      await context.ready();

      reset(eventLogger);

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);
      refreshDataFuture.complete(refreshData);

      await context.refresh();

      // Verify event logger was called for the refresh event
      verify(eventLogger.handleEvent(context, EventType.Refresh, refreshData))
          .called(1);
    });

    test('refreshCallsEventLoggerOnError', () async {
      final Context context = createReadyContext();
      await context.ready();

      reset(eventLogger);

      final Exception failure = Exception('ERROR');
      when(dataProvider.getContextData()).thenAnswer((_) {
        final Completer<ContextData> result = Completer<ContextData>();
        result.completeError(failure);
        return result;
      });

      await expectLater(context.refresh(), throwsException);

      // Verify event logger was called for the error
      verify(eventLogger.handleEvent(context, EventType.Error, failure))
          .called(1);
    });

    test('finalizeCallsEventLogger', () async {
      final Context context = createReadyContext();
      await context.ready();

      reset(eventLogger);

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.finalize();

      verify(eventLogger.handleEvent(context, EventType.Close, null)).called(1);
    });

    test('finalizeCallsEventLoggerWithPendingEvents', () async {
      final Context context = createReadyContext();
      await context.ready();

      context.track('goal1', {'amount': 125, 'hours': 245});

      reset(eventLogger);

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.finalize();

      verify(eventLogger.handleEvent(context, EventType.Publish, any))
          .called(1);
      verify(eventLogger.handleEvent(context, EventType.Close, null)).called(1);
    });

    test('finalizeCallsEventLoggerOnError', () async {
      final Context context = createReadyContext();
      await context.ready();

      context.track('goal1', {'amount': 125, 'hours': 245});

      reset(eventLogger);

      final Exception failure = Exception('FAILED');
      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createErrorVoidCompleter(failure));

      await expectLater(context.finalize(), throwsException);

      verify(eventLogger.handleEvent(context, EventType.Error, failure))
          .called(1);
    });

    test('refresh', () async {
      final Context context = createReadyContext();
      await context.ready();

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
      await context.ready();

      expect(context.isReady(), isTrue);

      const String experimentName = 'exp_test_abc';
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment('not_found'), equals(0));

      expect(context.getPendingCount(), equals(2));

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);

      refreshData.experiments = refreshData.experiments
          .where((e) => e.name != experimentName)
          .toList();

      refreshDataFuture.complete(refreshData);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment(experimentName), equals(0));
      expect(context.getTreatment('not_found'), equals(0));

      expect(context.getPendingCount(),
          equals(3)); // stopped experiment triggered a new exposure
    });

    test('refreshClearAssignmentCacheForStartedExperiment', () async {
      final Context context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);

      const String experimentName = 'exp_test_new';
      expect(context.getTreatment(experimentName), equals(0));
      expect(context.getTreatment('not_found'), equals(0));

      expect(context.getPendingCount(), equals(2));

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);

      refreshDataFuture.complete(refreshData);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment('not_found'), equals(0));

      expect(context.getPendingCount(),
          equals(3)); // stopped experiment triggered a new exposure
    });

    test('refreshClearAssignmentCacheForFullOnExperiment', () async {
      final Context context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);

      const String experimentName = 'exp_test_abc';
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment('not_found'), equals(0));

      expect(context.getPendingCount(), equals(2));

      when(dataProvider.getContextData()).thenAnswer((_) => refreshDataFuture);

      // Change the fullOnVariant for the experiment
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

      expect(context.getPendingCount(),
          equals(3)); // full-on experiment triggered a new exposure
    });

    test('refreshKeepsAssignmentCacheWhenNotChangedWithOverride', () async {
      final Context context = createReadyContext();
      await context.ready();

      context.setOverride('exp_test_ab', 3);
      expect(context.getTreatment('exp_test_ab'), equals(3));

      expect(context.getPendingCount(), equals(1));

      when(dataProvider.getContextData()).thenAnswer((_) => dataFutureReady);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment('exp_test_ab'), equals(3));

      expect(context.getPendingCount(), equals(1)); // no new exposure
    });

    test('finalize', () async {
      final Context context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);

      context.track('goal1', {'amount': 125, 'hours': 245});

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createCompleteVoidCompleter());

      await context.finalize();

      expect(context.isFinalized(), isTrue);

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('finalizeWithEmptyQueue', () async {
      final Context context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);
      expect(context.getPendingCount(), equals(0));

      await context.finalize();

      expect(context.isFinalized(), isTrue);

      verifyNever(eventHandler.publish(any, any));
    });

    test('startsRefreshTimerWhenReady', () async {
      final config = ContextConfig.create()
        ..setUnits(units)
        ..setRefreshInterval(1000);

      final context = createContext(config, dataFutureReady);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      await context.ready();

      Completer<void> refreshCompleter = Completer<void>();

      verifyNever(dataProvider.getContextData());
      when(dataProvider.getContextData()).thenAnswer((_) {
        refreshCompleter.complete();
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
      await context.ready();

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
      await context.ready();

      verifyNever(eventHandler.publish(any, any));

      await Future.delayed(const Duration(milliseconds: 666));

      verify(eventHandler.publish(any, any)).called(1);
    });

    test('setUnitEmpty', () async {
      final context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);
      expect(
          () => context.setUnit("db_user_id", ""), throwsA(isA<Exception>()));
    });

    test('setOverrideClearsAssignmentCache', () async {
      final context = createReadyContext();
      await context.ready();

      final Map<String, int> overrides = {
        "exp_test_new": 3,
        "exp_test_new_2": 5
      };

      context.setOverrides(overrides);

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
      await context.ready();

      context.setCustomAssignment("exp_test_not_eligible", 3);
      context.setCustomAssignment("exp_test_fullon", 3);

      expect(context.getTreatment("exp_test_not_eligible"), equals(0));
      expect(context.getTreatment("exp_test_fullon"), equals(2));
    });

    test('setCustomAssignmentClearsAssignmentCache', () async {
      final context = createReadyContext();
      await context.ready();

      final Map<String, int> customAssignments = {
        "exp_test_ab": 2,
        "exp_test_abc": 3
      };

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
        await context.ready();

        context.setAttribute("age", 20);
        expect(context.peekVariableValue("icon", "square"), equals("arrow"));
      }

      {
        final context = createReadyContextWithData(data);
        await context.ready();

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
      await context.ready();

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

      {
        final context = createReadyContextWithData(data);
        await context.ready();

        context.setAttribute("age", 20);
        expect(context.getVariableValue("icon", "square"), equals("arrow"));
        expect(context.getPendingCount(), equals(1));
      }

      {
        final context = createReadyContextWithData(data);
        await context.ready();

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
      await context.ready();

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
      await context.ready();

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
      await context.ready();

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
      await context.ready();

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
      await context.ready();

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
      await context.ready();

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

      expect(() => context.refresh(), throwsA(isA<Exception>()));

      verify(dataProvider.getContextData()).called(1);
    });

    test('refreshKeepsAssignmentCacheWhenNotChanged', () async {
      final context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);

      for (final experiment in data.experiments) {
        context.getTreatment(experiment.name);
      }
      context.getTreatment("not_found");

      expect(context.getPendingCount(), equals(data.experiments.length + 1));

      when(dataProvider.getContextData()).thenReturn(refreshDataFutureReady);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      for (final experiment in refreshData.experiments) {
        context.getTreatment(experiment.name);
      }
      context.getTreatment("not_found");

      expect(context.getPendingCount(),
          equals(refreshData.experiments.length + 1));
    });

    test('refreshKeepsAssignmentCacheWhenNotChangedOnAudienceMismatch',
        () async {
      final context = createReadyContextWithData(audienceStrictData);
      await context.ready();

      expect(context.getTreatment("exp_test_ab"), equals(0));
      expect(context.getPendingCount(), equals(1));

      when(dataProvider.getContextData())
          .thenReturn(audienceStrictDataFutureReady);

      await context.refresh();

      verify(dataProvider.getContextData()).called(1);

      expect(context.getTreatment("exp_test_ab"), equals(0));
      expect(context.getPendingCount(), equals(1)); // no new exposure
    });

    test('refreshClearAssignmentCacheForTrafficSplitChange', () async {
      final context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_not_eligible";
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

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
      expect(context.getPendingCount(),
          equals(3)); // newly eligible experiment triggered a new exposure
    });

    test('refreshClearAssignmentCacheForIterationChange', () async {
      final context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_abc";
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

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
      expect(context.getPendingCount(),
          equals(3)); // full-on experiment triggered a new exposure
    });

    test('refreshClearAssignmentCacheForExperimentIdChange', () async {
      final context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);

      const experimentName = "exp_test_abc";
      expect(context.getTreatment(experimentName),
          equals(expectedVariants[experimentName]));
      expect(context.getTreatment("not_found"), equals(0));
      expect(context.getPendingCount(), equals(2));

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
      expect(context.getPendingCount(),
          equals(3)); // full-on experiment triggered a new exposure
    });

    test('finalizeStopsRefreshTimer', () async {
      final config =
          ContextConfig.create().setUnits(units).setRefreshInterval(333);

      final context = createContext(config, dataFutureReady);
      await context.ready();

      expect(context.isReady(), isTrue);

      await context.finalize();

      expect(context.isFinalized(), isTrue);

      await Future.delayed(const Duration(milliseconds: 666));

      verifyNever(dataProvider.getContextData());
    });

    test('finalizeExceptionally', () async {
      final context = createReadyContext();
      await context.ready();

      expect(context.isReady(), isTrue);

      final trackAttributes = {'amount': 125, 'hours': 245};
      context.track("goal1", trackAttributes);

      final failure = Exception("FAILED");

      when(eventHandler.publish(any, any))
          .thenAnswer((_) => createErrorVoidCompleter(failure));

      await expectLater(context.finalize(), throwsA(isA<Exception>()));

      verify(eventLogger.handleEvent(context, EventType.Error, failure))
          .called(1);
    });
  });
}
