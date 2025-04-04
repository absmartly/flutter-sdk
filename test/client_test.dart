import 'dart:async';
import 'dart:convert';

import 'package:absmartly_sdk/client.dart';
import 'package:absmartly_sdk/client_config.dart';
import 'package:absmartly_sdk/context_data_deserializer.mocks.dart';
import 'package:absmartly_sdk/context_event_serializer.mocks.dart';
import 'package:absmartly_sdk/default_http_client.dart';
import 'package:absmartly_sdk/http_client.dart';
import 'package:absmartly_sdk/http_client.mocks.dart';
import 'package:absmartly_sdk/json/context_data.dart';
import 'package:absmartly_sdk/json/publish_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// some are not working

void main() {
  Future<Response> getByteResponse(List<int> bytes) async {
    return DefaultResponse(
      content: bytes,
      statusCode: 200,
      statusMessage: "OK",
      contentType: 'application/json; charset=utf8',
    );
  }

  group("Client", () {
    test(
        'create method should return a new instance of Client with a default HTTPClient if httpClient is null',
        () {
      final config = ClientConfig()
          .setEndpoint("https://example.com")
          .setAPIKey("test-api-key")
          .setApplication("website")
          .setEnvironment("dev");
      final client = Client.create(config);

      expect(client.runtimeType, equals(Client));
      expect(client.url_, equals('https://example.com/context'));
      expect(client.query_,
          equals({'application': 'website', 'environment': 'dev'}));
      expect(client.headers_['X-API-Key'], equals('test-api-key'));
      expect(client.headers_['X-Application'], equals('website'));
      expect(client.headers_['X-Environment'], equals('dev'));
      expect(client.headers_['X-Application-Version'], equals('0'));
      expect(client.headers_['X-Agent'], equals('absmartly-dart-sdk'));
      expect(client.httpClient_.runtimeType, equals(DefaultHTTPClient));
    });
    final config = ClientConfig()
        .setEndpoint("https://example.com")
        .setAPIKey("test-api-key")
        .setApplication("website")
        .setEnvironment("dev");

    test('Client constructor initializes properties correctly', () {
      final config = ClientConfig()
          .setEndpoint("https://example.com")
          .setAPIKey("test-api-key")
          .setApplication("website")
          .setEnvironment("dev");
      final httpClient = MockHTTPClient();
      final client = Client(config, httpClient);
      expect(client.url_, equals('https://example.com/context'));
      expect(client.query_,
          equals({'application': 'website', 'environment': 'dev'}));
      expect(
          client.headers_,
          equals({
            'X-API-Key': 'test-api-key',
            'X-Application': 'website',
            'X-Environment': 'dev',
            'X-Application-Version': '0',
            'X-Agent': 'absmartly-dart-sdk',
          }));
      expect(client.httpClient_, equals(httpClient));
      expect(client.deserializer_, isNotNull);
      expect(client.serializer_, isNotNull);
    });

    // .setEndpoint("https://localhost/v1")
    //     .setAPIKey("test-api-key")
    //     .setApplication("website")
    //     .setEnvironment("dev")
    //     .setContextEventSerializer(ser), httpClient);

    test('publish', () async {
      final httpClient = MockHTTPClient();
      final ser = MockContextEventSerializer();
      var config = ClientConfig()
          .setAPIKey("test-api-key")
          .setEndpoint("https://localhost/v1")
          .setApplication("website")
          .setEnvironment("dev")
          .setContextEventSerializer(ser);

      final client = Client.create(config, httpClient: httpClient);

      final expectedHeaders = {
        "X-API-Key": "test-api-key",
        "X-Application": "website",
        "X-Environment": "dev",
        "X-Application-Version": "0",
        "X-Agent": "absmartly-dart-sdk"
      };

      final event = PublishEvent(
          hashed: true,
          units: [],
          publishedAt: DateTime.now().millisecondsSinceEpoch,
          exposures: [],
          goals: [],
          attributes: []);
      final bytes = [0];

      when(ser.serialize(event)).thenReturn(bytes);
      when(httpClient.put(
              "https://localhost/v1/context", null, expectedHeaders, bytes))
          .thenAnswer((_) async => DefaultResponse(
              statusCode: 200,
              statusMessage: "OK",
              contentType: "",
              content: [0]));

      final publishFuture = client.publish(event);
      publishFuture;

      verify(ser.serialize(event)).called(1);
      verify(httpClient.put(
              "https://localhost/v1/context", null, expectedHeaders, bytes))
          .called(1);
    });
  });

  test("getContextData", () async {
    final httpClient = MockHTTPClient();
    final deser = MockContextDataDeserializer();
    var config = ClientConfig()
        .setAPIKey("test-api-key")
        .setEndpoint("https://localhost/v1")
        .setApplication("website")
        .setEnvironment("dev")
        .setContextDataDeserializer(deser);

    final client = Client.create(config, httpClient: httpClient);

    var bytes = utf8.encode("{}");

    final Map<String, String> expectedQuery = {
      "application": "website",
      "environment": "dev"
    };

    when(httpClient.get("https://localhost/v1/context", expectedQuery, null))
        .thenAnswer((_) => getByteResponse(bytes));

    final ContextData expected = ContextData();
    when(deser.deserialize(bytes, 0, bytes.length)).thenReturn(expected);

    final Completer<ContextData> dataFuture = client.getContextData();
    final ContextData actual = await dataFuture.future;

    expect(expected, actual);
  });
}
