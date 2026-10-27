import 'package:absmartly_dart/src/client_config.dart';
import 'package:absmartly_dart/src/context_data_deserializer.dart';
import 'package:absmartly_dart/src/context_event_serializer.dart';
import 'package:test/test.dart';
import 'package:mockito/annotations.dart';

import 'client_config_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ContextDataDeserializer>(),
  MockSpec<ContextEventSerializer>(),
])
void main() {
  group('ClientConfig', () {
    test('setEndpoint', () {
      final config =
          ClientConfig.create().setEndpoint('https://test.endpoint.com');
      expect(config.getEndpoint(), equals('https://test.endpoint.com'));
    });

    test('setAPIKey', () {
      final config = ClientConfig.create().setAPIKey('api-key-test');
      expect(config.getAPIKey(), equals('api-key-test'));
    });

    test('setEnvironment', () {
      final config = ClientConfig.create().setEnvironment('test');
      expect(config.getEnvironment(), equals('test'));
    });

    test('setApplication', () {
      final config = ClientConfig.create().setApplication('website');
      expect(config.getApplication(), equals('website'));
    });

    test('setContextDataDeserializer', () {
      final deserializer = MockContextDataDeserializer();
      final config =
          ClientConfig.create().setContextDataDeserializer(deserializer);
      expect(config.getContextDataDeserializer(), equals(deserializer));
    });

    test('setContextEventSerializer', () {
      final serializer = MockContextEventSerializer();
      final config =
          ClientConfig.create().setContextEventSerializer(serializer);
      expect(config.getContextEventSerializer(), equals(serializer));
    });

    test('setAll', () {
      final ContextDataDeserializer deserializer =
          MockContextDataDeserializer();
      final ContextEventSerializer serializer = MockContextEventSerializer();

      final config = ClientConfig.create()
          .setEndpoint('https://test.endpoint.com')
          .setAPIKey('api-key-test')
          .setEnvironment('test')
          .setApplication('website')
          .setContextDataDeserializer(deserializer)
          .setContextEventSerializer(serializer);
      expect(config.getEndpoint(), equals('https://test.endpoint.com'));
      expect(config.getAPIKey(), equals('api-key-test'));
      expect(config.getEnvironment(), equals('test'));
      expect(config.getApplication(), equals('website'));
      expect(config.getContextDataDeserializer(), equals(deserializer));
      expect(config.getContextEventSerializer(), equals(serializer));
    });
  });

  group('ClientConfig.create with named parameters', () {
    test('create with all parameters', () {
      final deserializer = MockContextDataDeserializer();
      final serializer = MockContextEventSerializer();

      final config = ClientConfig.create(
        endpoint: 'https://test.endpoint.com',
        apiKey: 'api-key-test',
        environment: 'test',
        application: 'website',
        contextDataDeserializer: deserializer,
        contextEventSerializer: serializer,
      );

      expect(config.getEndpoint(), equals('https://test.endpoint.com'));
      expect(config.getAPIKey(), equals('api-key-test'));
      expect(config.getEnvironment(), equals('test'));
      expect(config.getApplication(), equals('website'));
      expect(config.getContextDataDeserializer(), equals(deserializer));
      expect(config.getContextEventSerializer(), equals(serializer));
    });

    test('create with only required-like parameters', () {
      final config = ClientConfig.create(
        endpoint: 'https://test.endpoint.com',
        apiKey: 'api-key-test',
        environment: 'test',
        application: 'website',
      );

      expect(config.getEndpoint(), equals('https://test.endpoint.com'));
      expect(config.getAPIKey(), equals('api-key-test'));
      expect(config.getEnvironment(), equals('test'));
      expect(config.getApplication(), equals('website'));
    });

    test('create with no parameters is backward compatible', () {
      final config = ClientConfig.create();
      expect(config.getEndpoint(), isNull);
    });

    test('create with partial parameters', () {
      final config = ClientConfig.create(
        endpoint: 'https://test.endpoint.com',
        apiKey: 'api-key-test',
      );

      expect(config.getEndpoint(), equals('https://test.endpoint.com'));
      expect(config.getAPIKey(), equals('api-key-test'));
    });
  });

  group('ClientConfig nullable fields', () {
    test('fields are null by default without late initialization error', () {
      final config = ClientConfig();
      expect(config.getAPIKey(), isNull);
      expect(config.getEnvironment(), isNull);
      expect(config.getApplication(), isNull);
      expect(config.getEndpoint(), isNull);
    });
  });

  test("createFromProperties", () {
    var props = {
      "absmartly.endpoint": "https://test.endpoint.com",
      "absmartly.environment": "test",
      "absmartly.apikey": "api-key-test",
      "absmartly.application": "website"
    };

    final ContextEventSerializer serializer = MockContextEventSerializer();
    final ContextDataDeserializer deserializer = MockContextDataDeserializer();
    final ClientConfig config =
        ClientConfig.createFromProperties(props, "absmartly.")
            .setContextDataDeserializer(deserializer)
            .setContextEventSerializer(serializer);

    expect("https://test.endpoint.com", config.getEndpoint());
    expect("api-key-test", config.getAPIKey());
    expect("test", config.getEnvironment());
    expect("website", config.getApplication());
    expect(deserializer, config.getContextDataDeserializer());
    expect(serializer, config.getContextEventSerializer());
  });
}
