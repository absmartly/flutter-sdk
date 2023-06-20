import 'dart:convert';
import 'dart:core';
import 'dart:io';


import 'package:absmartly_sdk/helper/funtions.dart';
import 'package:absmartly_sdk/helper/http/io_client.dart' as http_io;

import 'package:absmartly_sdk/helper/http/http.dart' as http;
import 'package:absmartly_sdk/http_client.dart';
import 'default_http_client_config.dart';


import 'package:mockito/annotations.dart';
@GenerateNiceMocks([MockSpec<DefaultHTTPClient>()])


class DefaultHTTPClient implements HTTPClient {
  factory DefaultHTTPClient.create(final DefaultHTTPClientConfig config) {
    return DefaultHTTPClient(config);
  }

  late http.Client client;

  DefaultHTTPClient(DefaultHTTPClientConfig config) {
    client = http_io.IOClient(
      HttpClient()
        ..maxConnectionsPerHost = 20
        ..idleTimeout = Duration(milliseconds: config.getConnectionKeepAlive())
        // ..connectionTimeout = Duration(milliseconds: config.getConnectTimeout())
        // ..connectionTimeout = Duration(milliseconds: config.getConnectionRequestTimeout()),
    );
    // http.Client client = ioClient;
  }

  @override
  void close() {
    // TODO: implement close
  }

  @override
  Future<Response> get(String url, Map<String, String>? query, Map<String, String>? headers) {
    return makeRequest(url, query, headers, null, "GET");
  }

  @override
  Future<Response> post(String url, Map<String, String>? query, Map<String, String>? headers, List<int>? body) {
    return makeRequest(url, query, headers, body, "POST");
  }

  @override
  Future<Response> put(String url, Map<String, String>? query, Map<String, String>? headers, List<int>? body) {
    return makeRequest(url, query, headers, body, "PUT");
  }

  Future<Response> makeRequest(String url, Map<String, String>? query, Map<String, String>? headers, List<int>? body, String type) async {
    var queryParams = "";

    headers?["Content-Type"] = "application/json";
    if(query != null){
      queryParams = "?";
      query.forEach((key, value) {
        queryParams = "$queryParams$key=$value&";
      });
      queryParams = queryParams.substring(0, queryParams.length - 1);
    }


    switch(type){
      case "GET":
        http.Response response = await client.get(Uri.parse(url + queryParams), headers: headers,);
        Helper.response = response.body;
        return parseHttpResponse(response);

      case "POST":
        http.Response response = await client.post(Uri.parse(url + queryParams), headers: headers, body: body, );
        return parseHttpResponse(response);


      case "PUT":
        print(utf8.decode(body!));
        print(url);
        print(queryParams);
        http.Response response = await client.put(Uri.parse(url + queryParams), headers: headers, body: body, );
        // http.Response response = await client.put(Uri.parse("https://httpbin.org/put"), headers: headers, body: body, );

        print(response.body);
        return parseHttpResponse(response);

      default:
        http.Response response = await client.get(Uri.parse(url + queryParams), headers: headers,);
        return parseHttpResponse(response);
    }

  }

  Response parseHttpResponse(http.Response response){
    var defaultResponse = DefaultResponse(statusCode: response.statusCode, statusMessage: response.reasonPhrase, contentType: response.headers["content-type"], content: response.bodyBytes);
    return defaultResponse;
  }


// final CloseableHttpAsyncClient httpClient_;
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
