import 'dart:convert';

import 'package:test/test.dart';

// Reads a vendored fixture under test/resources as JSON. A hybrid VM isolate
// reads the file, so the same test runs on the VM and compiled to JavaScript.
Future<dynamic> loadJsonResource(final String name) async {
  final channel = spawnHybridCode('''
import 'dart:io';
import 'package:stream_channel/stream_channel.dart';

void hybridMain(StreamChannel channel) {
  channel.sink.add(File('test/resources/$name').readAsStringSync());
  channel.sink.close();
}
''');
  return jsonDecode(await channel.stream.first as String);
}
