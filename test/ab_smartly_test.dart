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
  MockSpec<DefaultContextDataProvider>(),
  MockSpec<Context>(),
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
        final _ = ABSmartly(config);
      },
          throwsA(const TypeMatcher<Exception>().having((e) => e.toString(),
              'message', contains('Exception: Missing Client instance'))));
    });

    test('createContext', () async {
      final config = ABSmartlyConfig.create().setClient(client);

      final dataFuture = Completer<ContextData>();
      final contextData = ContextData();

      final mockDataProvider = MockDefaultContextDataProvider();
      when(mockDataProvider.getContextData()).thenReturn(dataFuture);

      final absmartly = ABSmartly(config);

      absmartly.contextDataProvider_ = mockDataProvider;

      final contextConfig = ContextConfig.create()
        ..setUnit('user_id', '1234567');

      final context = absmartly.createContext(contextConfig);

      dataFuture.complete(contextData);

      expect(context, isA<Context>());

      verify(mockDataProvider.getContextData()).called(1);

      expect(absmartly.contextDataProvider_, isA<DefaultContextDataProvider>());
      expect(absmartly.contextEventHandler_, isA<DefaultContextEventHandler>());

      await context.waitUntilReady();

      expect(context.getUnit('user_id'), equals('1234567'));
      expect(context.getData(), equals(contextData));
    });

    test('ABSmartly createContext returns a valid Context object', () async {
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

      final contxtDataFuture = Completer<ContextData>();
      contxtDataFuture.complete(ContextData());

      when(client.getContextData()).thenReturn(contxtDataFuture);
      expect(context, isA<Context>());
    });

    test('ABSmartly createContextWith returns a valid Context object',
        () async {
      final abSmartly = ABSmartly(config);
      final contextConfig = ContextConfig();
      final contextData = ContextData();
      final context = abSmartly.createContextWith(contextConfig, contextData);
      expect(context, isA<Context>());
    });
  });
}
