import 'dart:async';

import 'package:absmartly_sdk/ab_smartly.dart';
import 'package:absmartly_sdk/absmartly_sdk_config.dart';
import 'package:absmartly_sdk/client.dart';
import 'package:absmartly_sdk/context.dart';
import 'package:absmartly_sdk/context_config.dart';
import 'package:absmartly_sdk/default_context_data_provider.dart';
import 'package:absmartly_sdk/default_context_event_handler.dart';
import 'package:absmartly_sdk/json/context_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'ab_smartly_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<Client>(),
])
void main() {
  group('ABSmartly', () {
    late Client client;
    late ABSmartlyConfig config;
    setUp(() {
      client = MockClient();
      config = ABSmartlyConfig.create().setClient(client);
    });

    test('create', () {
      final config = ABSmartlyConfig.create().setClient(client);

      final absmartly = ABSmartly(config);
      expect(absmartly, isNotNull);
    });

    test('createThrowsWithInvalidConfig', () {
      expect(() {
        final config = ABSmartlyConfig.create();
        final absmartly = ABSmartly(config);
      },
          throwsA(const TypeMatcher<Exception>().having((e) => e.toString(),
              'message', contains('Exception: Missing Client instance'))));
    });

    test('ABSmartly createContext returns a valid Context object', () async {
      // final config = ABSmartlyConfig().setClient(client);
      final abSmartly = ABSmartly(config);
      final contextConfig = ContextConfig();
      final context = abSmartly.createContext(contextConfig);
      expect(context, isA<Context>());
    });

    test(
        'ABSmartly constructor creates default contextDataProvider when getContextDataProvider() returns null',
        () {
      // final config = ABSmartlyConfig();
      expect(ABSmartly(config).contextDataProvider_,
          isA<DefaultContextDataProvider>());
    });

    test(
        'ABSmartly constructor creates default contextEventHandler when getContextEventHandler() returns null',
        () {
      expect(ABSmartly(config).contextEventHandler_,
          isA<DefaultContextEventHandler>());
    });

    test('ABSmartly createContext returns a valid Context object', () async {
      // final config = ABSmartlyConfig();
      final abSmartly = ABSmartly(config);
      final contextConfig = ContextConfig();
      final context = abSmartly.createContext(contextConfig);
      expect(context, isA<Context>());
    });

    test('ABSmartly createContextWith returns a valid Context object',
        () async {
      final schedulerCaptor = Timer(const Duration(seconds: 1), () {});
      config.setScheduler(schedulerCaptor);
      final abSmartly = ABSmartly(config);
      final contextConfig = ContextConfig();
      final contextData = ContextData();
      final context = abSmartly.createContextWith(contextConfig, contextData);
      expect(context, isA<Context>());
    });

    test('ABSmartly close sets client_ and scheduler_ variables to null',
        () async {
      // final config = ABSmartlyConfig();
      final abSmartly = ABSmartly(config);
      await abSmartly.close();
      expect(abSmartly.client_, isNull);
      expect(abSmartly.scheduler_, isNull);
    });

    test('ABSmartly close calls close() method of client_ object', () async {
      final mockClient = MockClient();
      config.setClient(mockClient);
      final abSmartly = ABSmartly(config);
      await abSmartly.close();
      verify(mockClient.close()).called(1);
    });

    test(
        'ABSmartly close waits for scheduler_ to complete tasks before setting it to null',
        () async {
      // final config = ABSmartlyConfig();
      final abSmartly = ABSmartly(config);
      abSmartly.scheduleTask();
      await abSmartly.close();
      expect(abSmartly.scheduler_, isNull);
    });

    test(
        'ABSmartly scheduleTask sets scheduler_ variable to Timer object with duration of 5 seconds',
        () {
      // final config = ABSmartlyConfig();
      final schedulerCaptor = Timer(const Duration(seconds: 5), () {});
      final abSmartly = ABSmartly(config);
      abSmartly.scheduleTask();
      expect(abSmartly.scheduler_, isA<Timer>());
    });
  });
}
