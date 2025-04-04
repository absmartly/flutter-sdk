abstract class HTTPClient {
  Future<Response> get(
      String url, Map<String, String>? query, Map<String, String>? headers);

  Future<Response> put(String url, Map<String, String>? query,
      Map<String, String>? headers, List<int>? body);

  Future<Response> post(String url, Map<String, String>? query,
      Map<String, String>? headers, List<int>? body);
}

abstract class Response {
  int? getStatusCode();

  String? getStatusMessage();

  String? getContentType();

  List<int>? getContent();
}
