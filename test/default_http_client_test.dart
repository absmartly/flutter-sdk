import 'dart:convert';

import 'package:absmartly_sdk/default_http_client.dart';
import 'package:absmartly_sdk/default_http_client_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'default_http_client_test.mocks.dart';

@GenerateNiceMocks([MockSpec<http.Client>()])
void main() {
  group('DefaultHTTPClient', () {
    late MockClient mockHttpClient;
    late DefaultHTTPClient client;

    setUp(() {
      mockHttpClient = MockClient();
      client = DefaultHTTPClient.create(
        DefaultHTTPClientConfig(),
        httpClient: mockHttpClient,
      );
    });

    test('GET request returns successful response', () async {
      final responseBody = {'id': 1, 'title': 'Test'};
      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
            jsonEncode(responseBody),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      final response = await client.get(
        'https://example.com/api/posts/1',
        null,
        null,
      );

      expect(response.getStatusCode(), equals(200));
      expect(
          response.getContentType(), equals('application/json; charset=utf-8'));
      expect(response.getContent(), isNotNull);

      verify(mockHttpClient.get(
        argThat(predicate<Uri>((uri) =>
            uri.host == 'example.com' && uri.path == '/api/posts/1')),
        headers: anyNamed('headers'),
      )).called(1);
    });

    test('GET request with query parameters', () async {
      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      final response = await client.get(
        'https://example.com/api/posts',
        {'userId': '1'},
        null,
      );

      expect(response.getStatusCode(), equals(200));

      verify(mockHttpClient.get(
        argThat(predicate<Uri>((uri) =>
            uri.toString() == 'https://example.com/api/posts?userId=1')),
        headers: anyNamed('headers'),
      )).called(1);
    });

    test('POST request returns successful response', () async {
      final responseBody = {'id': 101, 'title': 'foo'};
      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        encoding: anyNamed('encoding'),
      )).thenAnswer((_) async => http.Response(
            jsonEncode(responseBody),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      final body = {'title': 'foo', 'body': 'bar', 'userId': 1};
      final response = await client.post(
        'https://example.com/api/posts',
        null,
        null,
        utf8.encode(jsonEncode(body)),
      );

      expect(response.getStatusCode(), equals(201));
      expect(
          response.getContentType(), equals('application/json; charset=utf-8'));
      expect(response.getContent(), isNotNull);

      verify(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        encoding: anyNamed('encoding'),
      )).called(1);
    });

    test('PUT request returns successful response', () async {
      final responseBody = {'id': 1, 'title': 'updated'};
      when(mockHttpClient.put(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        encoding: anyNamed('encoding'),
      )).thenAnswer((_) async => http.Response(
            jsonEncode(responseBody),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      final body = {'title': 'updated', 'body': 'bar', 'userId': 1};
      final response = await client.put(
        'https://example.com/api/posts/1',
        null,
        null,
        utf8.encode(jsonEncode(body)),
      );

      expect(response.getStatusCode(), equals(200));
      expect(
          response.getContentType(), equals('application/json; charset=utf-8'));
      expect(response.getContent(), isNotNull);

      verify(mockHttpClient.put(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        encoding: anyNamed('encoding'),
      )).called(1);
    });

    test('GET request with custom headers', () async {
      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          ));

      await client.get(
        'https://example.com/api/posts',
        null,
        {'Authorization': 'Bearer token123'},
      );

      verify(mockHttpClient.get(
        any,
        headers: argThat(
          predicate<Map<String, String>?>((headers) =>
              headers != null &&
              headers['Authorization'] == 'Bearer token123' &&
              headers['Content-Type'] == 'application/json'),
          named: 'headers',
        ),
      )).called(1);
    });

    test('returns 4xx error without retrying', () async {
      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
            '{"error": "Not found"}',
            404,
            headers: {'content-type': 'application/json'},
          ));

      final response = await client.get(
        'https://example.com/api/posts/999',
        null,
        null,
      );

      expect(response.getStatusCode(), equals(404));
      verify(mockHttpClient.get(any, headers: anyNamed('headers'))).called(1);
    });

    test('retries on 502 error and succeeds', () async {
      var callCount = 0;
      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('Bad Gateway', 502);
        }
        return http.Response('{"success": true}', 200,
            headers: {'content-type': 'application/json'});
      });

      final response = await client.get(
        'https://example.com/api/posts',
        null,
        null,
      );

      expect(response.getStatusCode(), equals(200));
      verify(mockHttpClient.get(any, headers: anyNamed('headers'))).called(2);
    });

    test('retries on 503 error and succeeds', () async {
      var callCount = 0;
      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('Service Unavailable', 503);
        }
        return http.Response('{"success": true}', 200,
            headers: {'content-type': 'application/json'});
      });

      final response = await client.get(
        'https://example.com/api/posts',
        null,
        null,
      );

      expect(response.getStatusCode(), equals(200));
      verify(mockHttpClient.get(any, headers: anyNamed('headers'))).called(2);
    });

    test('stops retrying after max retries', () async {
      final config = DefaultHTTPClientConfig()..setMaxRetries(3);
      final clientWithRetries = DefaultHTTPClient.create(
        config,
        httpClient: mockHttpClient,
      );

      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response('Bad Gateway', 502));

      final response = await clientWithRetries.get(
        'https://example.com/api/posts',
        null,
        null,
      );

      expect(response.getStatusCode(), equals(502));
      verify(mockHttpClient.get(any, headers: anyNamed('headers'))).called(3);
    });

    test('retries on connection error and succeeds', () async {
      var callCount = 0;
      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw Exception('Connection failed');
        }
        return http.Response('{"success": true}', 200,
            headers: {'content-type': 'application/json'});
      });

      final response = await client.get(
        'https://example.com/api/posts',
        null,
        null,
      );

      expect(response.getStatusCode(), equals(200));
      verify(mockHttpClient.get(any, headers: anyNamed('headers'))).called(2);
    });

    test('throws after max retries on connection error', () async {
      final config = DefaultHTTPClientConfig()..setMaxRetries(2);
      final clientWithRetries = DefaultHTTPClient.create(
        config,
        httpClient: mockHttpClient,
      );

      when(mockHttpClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenThrow(Exception('Connection failed'));

      expect(
        () => clientWithRetries.get(
          'https://example.com/api/posts',
          null,
          null,
        ),
        throwsException,
      );
    });

    test('close calls client.close', () {
      client.close();
      verify(mockHttpClient.close()).called(1);
    });
  });
}
