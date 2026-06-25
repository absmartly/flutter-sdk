// Hermetic local-HTTP-server integration test.
//
// Drives the PUBLIC Dart SDK surface (ABSmartly.createContext ->
// Context.getTreatment / track -> Context.publish) so that the REAL
// DefaultHTTPClient performs an actual GET /context and PUT /context against a
// local loopback server (HttpServer.bind on an ephemeral port). It asserts the
// documented ABsmartly collector wire contract:
//
//   GET  <endpoint>/context  with ?application=&environment=  (drives ready)
//   PUT  <endpoint>/context  with X-API-Key / X-Application / X-Environment /
//                            X-Application-Version / X-Agent and a body
//                            containing hashed / units / publishedAt.
//
// Hermetic: no live backend, so it runs in the repo's own PR CI.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:test/test.dart';

/// A single request as captured by the local server.
class CapturedRequest {
  CapturedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers; // lower-cased names
  final String body;
}

/// A tiny hermetic HTTP server bound to an ephemeral loopback port. It serves
/// requests and records what it saw.
class LocalServer {
  LocalServer._(this._server, this.contextData);

  final HttpServer _server;
  final String contextData;
  final List<CapturedRequest> requests = [];

  int get port => _server.port;
  String get baseUrl => 'http://127.0.0.1:$port';

  static Future<LocalServer> start(String contextData) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final local = LocalServer._(server, contextData);
    local._listen();
    return local;
  }

  void _listen() {
    _server.listen((HttpRequest request) async {
      final body = await utf8.decoder.bind(request).join();

      final headers = <String, String>{};
      request.headers.forEach((name, values) {
        headers[name.toLowerCase()] = values.join(',');
      });

      requests.add(CapturedRequest(
        method: request.method,
        path: request.uri.path,
        query: request.uri.queryParameters,
        headers: headers,
        body: body,
      ));

      request.response.headers.contentType = ContentType.json;
      if (request.method == 'GET') {
        request.response.write(contextData);
      } else {
        request.response.write('{}');
      }
      await request.response.close();
    });
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  test('real HTTP client hits local server with the wire contract', () async {
    final contextData =
        await File('test/resources/context.json').readAsString();
    final server = await LocalServer.start(contextData);

    try {
      // Build a real Client (uses the real DefaultHTTPClient) pointed at the
      // local server, then drive it through the public ABSmartly surface.
      final clientConfig = ClientConfig.create(
        endpoint: server.baseUrl,
        apiKey: 'test-api-key',
        application: 'website',
        environment: 'test',
      );
      final client = Client.create(clientConfig);

      final sdkConfig = ABSmartlyConfig.create().setClient(client);
      final absmartly = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()
        ..setUnit('session_id', 'e791e240fcd3df7d238cfc285f475e8152fcc0ec')
        ..setUnit('user_id', '123456789');

      // createContext -> real GET /context.
      final context = absmartly.createContext(contextConfig);
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isFalse);

      // Queue an exposure + a goal so publish() has something to send.
      context.getTreatment('exp_test_ab');
      context.track('payment', {'amount': 1000});
      expect(context.getPendingCount(), greaterThan(0));

      // publish() -> real PUT /context.
      await context.publish();

      expect(server.requests.length, equals(2));

      final get = server.requests.firstWhere((r) => r.method == 'GET');
      final put = server.requests.firstWhere((r) => r.method == 'PUT');

      // ---- GET /context (fetch -> ready) ----
      expect(get.path, equals('/context'));
      expect(get.query['application'], equals('website'));
      expect(get.query['environment'], equals('test'));

      // ---- PUT /context (publish) ----
      expect(put.path, equals('/context'));
      expect(put.query, isEmpty); // no query params on the PUT

      // Required auth / identity headers (exact names per the wire contract).
      expect(put.headers['x-api-key'], equals('test-api-key'));
      expect(put.headers['x-application'], equals('website'));
      expect(put.headers['x-environment'], equals('test'));
      expect(put.headers['x-application-version'], equals('0'));
      expect(put.headers['x-agent'], isNotNull);
      expect(put.headers['x-agent'], isNotEmpty); // value varies per SDK
      expect(put.headers['content-type'], contains('application/json'));

      // Body must carry the required publish fields.
      final decoded = jsonDecode(put.body) as Map<String, dynamic>;
      expect(decoded['hashed'], isA<bool>());
      expect(decoded['units'], isA<List>());
      expect((decoded['units'] as List), isNotEmpty);
      expect(decoded['publishedAt'], isA<int>());
      expect(decoded['publishedAt'] as int, greaterThan(0));
      // We tracked a goal, so goals must be present and non-empty.
      expect(decoded['goals'], isA<List>());
      expect((decoded['goals'] as List), isNotEmpty);
      expect((decoded['goals'] as List).first['name'], equals('payment'));
    } finally {
      await server.stop();
    }
  });
}
