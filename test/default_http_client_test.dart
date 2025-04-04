import 'package:absmartly_sdk/default_http_client.dart';
import 'package:absmartly_sdk/default_http_client_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultHTTPClient', () {
    late DefaultHTTPClient client;

    setUp(() {
      client = DefaultHTTPClient.create(DefaultHTTPClientConfig());
    });

    test('GET request returns successful response', () async {
      final response = await client.get(
          'https://jsonplaceholder.typicode.com/posts/1', null, null);
      expect(response.getStatusCode(), equals(200));
      expect(
          response.getContentType(), equals('application/json; charset=utf-8'));
      expect(response.getContent(), isNotNull);
    });

    test('POST request returns successful response', () async {
      final body = {'title': 'foo', 'body': 'bar', 'userId': 1};
      final response = await client.post(
          'https://jsonplaceholder.typicode.com/posts',
          null,
          null,
          body.toString().codeUnits);
      expect(response.getStatusCode(), equals(201));
      expect(
          response.getContentType(), equals('application/json; charset=utf-8'));
      expect(response.getContent(), isNotNull);
    });

    test('PUT request returns successful response', () async {
      final body = {'title': 'foo', 'body': 'bar', 'userId': 1};
      final response = await client.put(
          'https://jsonplaceholder.typicode.com/posts/1',
          null,
          null,
          body.toString().codeUnits);
      expect(response.getStatusCode(), equals(200));
      expect(
          response.getContentType(), equals('application/json; charset=utf-8'));
      expect(response.getContent(), isNotNull);
    });

    test('Handles null values correctly', () async {
      final response = await client.get(
          'https://jsonplaceholder.typicode.com/posts', null, null);
      expect(response.getStatusCode(), equals(200));
      expect(
          response.getContentType(), equals('application/json; charset=utf-8'));
      expect(response.getContent(), isNotNull);
    });
  });
}
