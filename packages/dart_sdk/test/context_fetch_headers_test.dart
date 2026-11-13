import 'dart:convert';

import 'package:absmartly_dart/src/ab_smartly.dart';
import 'package:absmartly_dart/src/absmartly_sdk_config.dart';
import 'package:absmartly_dart/src/client.dart';
import 'package:absmartly_dart/src/client_config.dart';
import 'package:absmartly_dart/src/context_config.dart';
import 'package:absmartly_dart/src/default_http_client.dart';
import 'package:absmartly_dart/src/http_client.dart';
import 'package:test/test.dart';

class CapturedRequest {
  CapturedRequest(this.method, this.url, this.query, this.headers);

  final String method;
  final String url;
  final Map<String, String>? query;
  final Map<String, String>? headers;
}

// Records every request and serves the scenario's context data, like the
// cross-SDK test wrapper does.
class CapturingHTTPClient implements HTTPClient {
  CapturingHTTPClient(this.contextData);

  final Map<String, dynamic> contextData;
  final List<CapturedRequest> requests = [];

  Future<Response> _respond(String method, String url,
      Map<String, String>? query, Map<String, String>? headers) async {
    requests.add(CapturedRequest(method, url, query,
        headers == null ? null : Map<String, String>.from(headers)));
    return DefaultResponse(
      content: utf8.encode(jsonEncode(method == "GET" ? contextData : {})),
      statusCode: 200,
      statusMessage: "OK",
      contentType: "application/json",
    );
  }

  @override
  Future<Response> get(String url, Map<String, String>? query,
          Map<String, String>? headers) =>
      _respond("GET", url, query, headers);

  @override
  Future<Response> put(String url, Map<String, String>? query,
          Map<String, String>? headers, List<int>? body) =>
      _respond("PUT", url, query, headers);

  @override
  Future<Response> post(String url, Map<String, String>? query,
          Map<String, String>? headers, List<int>? body) =>
      _respond("POST", url, query, headers);

  @override
  void close() {}
}

void main() {
  // Cross-SDK scenario 320: "X-Agent - Context Fetch Sends
  // absmartly-<lang>-sdk/<version>".
  test("context fetch sends the SDK headers, including X-Agent", () async {
    final httpClient = CapturingHTTPClient({
      "experiments": [
        {
          "id": 600,
          "name": "exp_xagent",
          "iteration": 1,
          "unitType": "session_id",
          "seedHi": 0,
          "seedLo": 0,
          "split": [0.0, 1.0],
          "trafficSeedHi": 0,
          "trafficSeedLo": 0,
          "trafficSplit": [0, 1],
          "fullOnVariant": 0,
          "applications": [
            {"name": "website"}
          ],
          "variants": [
            {"name": "A", "config": null},
            {"name": "B", "config": null}
          ],
          "audience": null,
          "audienceStrict": false,
          "customFieldValues": null,
          "assignmentRules": null
        }
      ]
    });

    final client = Client.create(
        ClientConfig()
            .setAPIKey("test-api-key")
            .setEndpoint("https://localhost/v1")
            .setApplication("website")
            .setEnvironment("dev"),
        httpClient: httpClient);
    final sdk = ABSmartly(ABSmartlyConfig.create(client: client));

    final context = sdk.createContext(ContextConfig.create()
      ..setUnit("session_id", "svk-unit-1")
      ..setPublishDelay(-1)
      ..setRefreshInterval(0));
    await context.waitUntilReady();

    expect(context.isReady(), isTrue);
    expect(context.isFailed(), isFalse);
    expect(context.getExperiments(), equals(["exp_xagent"]));

    final gets = httpClient.requests.where((r) => r.method == "GET").toList();
    expect(gets, hasLength(greaterThanOrEqualTo(1)));

    final get = gets.first;
    expect(get.url, equals("https://localhost/v1/context"));
    expect(get.query, equals({"application": "website", "environment": "dev"}));
    expect(
        get.headers?["X-Agent"],
        matches(RegExp(
            r"^absmartly-[a-z0-9]+-sdk/[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]*)?$")));
    expect(get.headers, containsPair("X-API-Key", "test-api-key"));
    expect(get.headers, containsPair("X-Application", "website"));
    expect(get.headers, containsPair("X-Environment", "dev"));
    expect(get.headers, containsPair("X-Application-Version", "0"));
  });
}
