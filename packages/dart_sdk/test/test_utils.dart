import 'dart:io';
import 'dart:typed_data';

Future<List<int>> getResourceBytes(String resourceName) async {
  String path = "test/resources/$resourceName";

  final file = File(path);
  Uint8List bytes = await file.readAsBytes();
  return bytes;
}
