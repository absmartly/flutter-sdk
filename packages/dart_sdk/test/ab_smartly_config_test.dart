import 'package:absmartly_dart/src/absmartly_sdk_config.dart';
import 'package:absmartly_dart/src/client.dart';
import 'package:absmartly_dart/src/context_data_provider.dart';
import 'package:absmartly_dart/src/context_event_handler.dart';
import 'package:absmartly_dart/src/context_event_logger.dart';
import 'package:absmartly_dart/src/variable_parser.dart';
import 'package:test/test.dart';
import 'package:mockito/annotations.dart';

import 'ab_smartly_config_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ContextDataProvider>(),
  MockSpec<ContextEventHandler>(),
  MockSpec<ContextEventLogger>(),
  MockSpec<VariableParser>(),
  MockSpec<Client>(),
])
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

    test('setAll', () {
      final handler = MockContextEventHandler();
      final provider = MockContextDataProvider();
      final parser = MockVariableParser();
      final client = MockClient();
      final eventlogger = MockContextEventLogger();
      final config = ABSmartlyConfig.create()
          .setVariableParser(parser)
          .setContextDataProvider(provider)
          .setContextEventHandler(handler)
          .setClient(client)
          .setContextEventLogger(eventlogger);
      expect(config.getContextDataProvider(), equals(provider));
      expect(config.getContextEventHandler(), equals(handler));
      expect(config.getVariableParser(), equals(parser));
      expect(config.getClient(), equals(client));
    });
  });

  group('ABSmartlyConfig.create with named parameters', () {
    test('create with all parameters', () {
      final handler = MockContextEventHandler();
      final provider = MockContextDataProvider();
      final parser = MockVariableParser();
      final client = MockClient();
      final eventLogger = MockContextEventLogger();

      final config = ABSmartlyConfig.create(
        client: client,
        contextDataProvider: provider,
        contextEventHandler: handler,
        contextEventLogger: eventLogger,
        variableParser: parser,
      );

      expect(config.getClient(), equals(client));
      expect(config.getContextDataProvider(), equals(provider));
      expect(config.getContextEventHandler(), equals(handler));
      expect(config.getContextEventLogger(), equals(eventLogger));
      expect(config.getVariableParser(), equals(parser));
    });

    test('create with client only', () {
      final client = MockClient();

      final config = ABSmartlyConfig.create(client: client);

      expect(config.getClient(), equals(client));
    });

    test('create with no parameters is backward compatible', () {
      final config = ABSmartlyConfig.create();
      expect(() => config.getClient(), throwsException);
    });
  });
}
