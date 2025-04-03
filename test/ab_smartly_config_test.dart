import 'dart:async';

import 'package:absmartly_sdk/absmartly_sdk_config.dart';
import 'package:absmartly_sdk/client.mocks.dart';
import 'package:absmartly_sdk/context_data_provider.mocks.dart';
import 'package:absmartly_sdk/context_event_handler.mocks.dart';
import 'package:absmartly_sdk/variable_parser.mocks.dart';
import 'package:flutter_test/flutter_test.dart';

// all working

void main() {
  group('ABSmartlyConfig', () {
    test('setContextDataProvider', () {
      final provider = MockContextDataProvider();
      final config = ABSmartlyConfig.create().setContextDataProvider(provider);
      expect(config.getContextDataProvider(), equals(provider));
    });

    test('setContextEventHandler', () {
      final handler = MockContextEventHandler();
      final config = ABSmartlyConfig.create().setContextEventHandler(handler);
      expect(config.getContextEventHandler(), equals(handler));
    });

    test('setVariableParser', () {
      final parser = MockVariableParser();
      final config = ABSmartlyConfig.create().setVariableParser(parser);
      expect(config.getVariableParser(), equals(parser));
    });

    test('setScheduler', () {
      final scheduler = Timer(const Duration(seconds: 5), () {});
      final config = ABSmartlyConfig.create().setScheduler(scheduler);
      expect(config.getScheduler(), equals(scheduler));
    });

    test('setAll', () {
      final handler = MockContextEventHandler();
      final provider = MockContextDataProvider();
      final parser = MockVariableParser();
      final scheduler = Timer(const Duration(seconds: 5), () {});
      final client = MockClient();
      final config = ABSmartlyConfig.create()
          .setVariableParser(parser)
          .setContextDataProvider(provider)
          .setContextEventHandler(handler)
          .setScheduler(scheduler)
          .setClient(client);
      expect(config.getContextDataProvider(), equals(provider));
      expect(config.getContextEventHandler(), equals(handler));
      expect(config.getVariableParser(), equals(parser));
      expect(config.getScheduler(), equals(scheduler));
      expect(config.getClient(), equals(client));
    });
  });
}
