import 'dart:core';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/io_client.dart' as http_io;

import 'package:http/http.dart' as http;
import 'package:absmartly_sdk/http_client.dart';
import 'default_http_client_config.dart';

const int minRetryInterval = 5;

class DefaultHTTPClient implements HTTPClient {
  factory DefaultHTTPClient.create(final DefaultHTTPClientConfig config) {
    return DefaultHTTPClient(config);
  }

  late int retryInterval;
  late int maxRetries;

  late http.Client client;

  DefaultHTTPClient(DefaultHTTPClientConfig config) {
    client = http_io.IOClient(HttpClient()
      ..maxConnectionsPerHost = 20
      ..connectionTimeout = Duration(milliseconds: config.getConnectTimeout())
      ..idleTimeout = Duration(milliseconds: config.getConnectionKeepAlive()));

    maxRetries = config.getMaxRetries();
    retryInterval = config.getRetryInterval();
  }

  @override
  Future<Response> get(
      String url, Map<String, String>? query, Map<String, String>? headers) {
    return makeRequest(url, query, headers, null, "GET");
  }

  @override
  Future<Response> post(String url, Map<String, String>? query,
      Map<String, String>? headers, List<int>? body) {
    return makeRequest(url, query, headers, body, "POST");
  }

  @override
  Future<Response> put(String url, Map<String, String>? query,
      Map<String, String>? headers, List<int>? body) {
    return makeRequest(url, query, headers, body, "PUT");
  }

  Future<Response> makeRequest(
    String url,
    Map<String, String>? query,
    Map<String, String>? headers,
    List<int>? body,
    String type,
  ) async {
    headers?["Content-Type"] = "application/json";

    Uri parsedUri = Uri.parse(url);
    Uri uri = parsedUri.replace(queryParameters: query ?? {});

    int attempt = 0;

    while (true) {
      attempt++;
      try {
        http.Response response;
        switch (type) {
          case "GET":
            response = await client.get(
              uri,
              headers: headers,
            );
            break;

          case "POST":
            response = await client.post(
              uri,
              headers: headers,
              body: body,
            );
            break;

          case "PUT":
            response = await client.put(
              uri,
              headers: headers,
              body: body,
            );
            break;

          default:
            response = await client.get(
              uri,
              headers: headers,
            );
            break;
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return parseHttpResponse(response);
        }

        if (attempt >= maxRetries ||
            (response.statusCode != 502 && response.statusCode != 503)) {
          return parseHttpResponse(response);
        }
      } catch (e) {
        if (attempt >= maxRetries) {
          rethrow;
        }
      }

      final int interval = math.max(
          0, (2 * (retryInterval - minRetryInterval)) ~/ (1 << maxRetries));
      final Duration delay = Duration(
          milliseconds: minRetryInterval + (((1 << (attempt - 1)) * interval)));

      await Future.delayed(delay);
    }
  }

  @override
  close() {
    client.close();
  }

  Response parseHttpResponse(http.Response response) {
    var defaultResponse = DefaultResponse(
        statusCode: response.statusCode,
        statusMessage: response.reasonPhrase,
        contentType: response.headers["content-type"],
        content: response.bodyBytes);
    return defaultResponse;
  }
}

class DefaultResponse implements Response {
  DefaultResponse({
    required this.statusCode,
    required this.statusMessage,
    required this.contentType,
    required this.content,
  });

  final int? statusCode;
  final String? statusMessage;
  final String? contentType;
  final List<int>? content;

  @override
  List<int>? getContent() {
    return content;
  }

  @override
  String? getContentType() {
    return contentType;
  }

  @override
  int? getStatusCode() {
    return statusCode;
  }

  @override
  String? getStatusMessage() {
    return statusMessage;
  }
}
