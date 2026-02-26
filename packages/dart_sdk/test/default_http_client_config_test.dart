import 'package:absmartly_dart/src/default_http_client_config.dart';
import 'package:absmartly_dart/src/http_version_policy.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultHTTPClientConfig', () {
    test('setConnectTimeout', () {
      final config = DefaultHTTPClientConfig.create().setConnectTimeout(123);
      expect(config.getConnectTimeout(), equals(123));
    });

    test('setConnectionKeepAlive', () {
      final config =
          DefaultHTTPClientConfig.create().setConnectionKeepAlive(123);
      expect(config.getConnectionKeepAlive(), equals(123));
    });

    test('setConnectionRequestTimeout', () {
      final config =
          DefaultHTTPClientConfig.create().setConnectionRequestTimeout(123);
      expect(config.getConnectionRequestTimeout(), equals(123));
    });

    test('setMaxRetries', () {
      final config = DefaultHTTPClientConfig.create().setMaxRetries(123);
      expect(config.getMaxRetries(), equals(123));
    });

    test('setRetryInterval', () {
      final config = DefaultHTTPClientConfig.create().setRetryInterval(123);
      expect(config.getRetryInterval(), equals(123));
    });

    test('setHttpVersionPolicy', () {
      final config = DefaultHTTPClientConfig.create()
          .setHTTPVersionPolicy(HTTPVersionPolicy.forceHttp1);
      expect(
          config.getHTTPVersionPolicy(), equals(HTTPVersionPolicy.forceHttp1));
    });
  });

  group('DefaultHTTPClientConfig.create with named parameters', () {
    test('create with all parameters', () {
      final config = DefaultHTTPClientConfig.create(
        connectTimeout: 5000,
        connectionKeepAlive: 60000,
        connectionRequestTimeout: 2000,
        maxRetries: 3,
        retryInterval: 500,
        httpVersionPolicy: HTTPVersionPolicy.forceHttp1,
      );

      expect(config.getConnectTimeout(), equals(5000));
      expect(config.getConnectionKeepAlive(), equals(60000));
      expect(config.getConnectionRequestTimeout(), equals(2000));
      expect(config.getMaxRetries(), equals(3));
      expect(config.getRetryInterval(), equals(500));
      expect(
          config.getHTTPVersionPolicy(), equals(HTTPVersionPolicy.forceHttp1));
    });

    test('create with partial parameters keeps defaults', () {
      final config = DefaultHTTPClientConfig.create(
        connectTimeout: 5000,
        maxRetries: 3,
      );

      expect(config.getConnectTimeout(), equals(5000));
      expect(config.getConnectionKeepAlive(), equals(30000));
      expect(config.getConnectionRequestTimeout(), equals(1000));
      expect(config.getMaxRetries(), equals(3));
      expect(config.getRetryInterval(), equals(333));
      expect(config.getHTTPVersionPolicy(),
          equals(HTTPVersionPolicy.negotiate));
    });

    test('create with no parameters is backward compatible', () {
      final config = DefaultHTTPClientConfig.create();
      expect(config.getConnectTimeout(), equals(3000));
      expect(config.getConnectionKeepAlive(), equals(30000));
      expect(config.getConnectionRequestTimeout(), equals(1000));
      expect(config.getMaxRetries(), equals(5));
      expect(config.getRetryInterval(), equals(333));
      expect(config.getHTTPVersionPolicy(),
          equals(HTTPVersionPolicy.negotiate));
    });
  });
}
