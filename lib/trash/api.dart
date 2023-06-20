import 'dart:io';
import 'dart:convert';
main(){
  makePostRequest();
}
Future<void> makePostRequest() async {
  HttpClient client = HttpClient();
  client.badCertificateCallback =
      (X509Certificate cert, String host, int port) => true;


  HttpClientRequest request = await client.postUrl(Uri.parse("https://httpbin.org/post"));
  request.headers.set("content-type", "application/json");
  request.add(utf8.encode(json.encode({"key": "value"})));


  HttpClientResponse response = await request.close();

  response.transform(utf8.decoder).listen((data) {
    print(data);
  });
}
