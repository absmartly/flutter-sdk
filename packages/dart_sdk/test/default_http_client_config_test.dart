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
}
