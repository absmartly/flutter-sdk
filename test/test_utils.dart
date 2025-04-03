import 'package:flutter/services.dart';

Future<List<int>> getResourceBytes(String resourceName) async {
  String path = "resources/$resourceName";

  ByteData byteData = await rootBundle.load(path);
  Uint8List bytes = byteData.buffer.asUint8List();
  return bytes;
}
