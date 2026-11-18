// switchbackClusters order through the default context-data decoder, on the
// VM and compiled to JavaScript, where jsonDecode lists integer-like object
// keys first.
import 'dart:convert';

import 'package:absmartly_dart/src/default_context_data_serializer.dart';
import 'package:absmartly_dart/src/internal/json_key_order.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:test/test.dart';

String experiment(int id, String clusters) =>
    '{"id":$id,"name":"e$id","unitType":"u","iteration":1,"seedHi":0,'
    '"seedLo":0,"split":[0.5,0.5],"trafficSeedHi":0,"trafficSeedLo":0,'
    '"trafficSplit":[0,1],"fullOnVariant":0,"variants":[],'
    '"randomizationType":"switchback","switchbackClusters":$clusters}';

List<List<String>> decodedOrders(String payload) {
  final bytes = utf8.encode(payload);
  final data =
      DefaultContextDataDeserializer().deserialize(bytes, 0, bytes.length)!;
  return [
    for (final e in data.experiments) e.switchbackClusters?.keys.toList() ?? []
  ];
}

void main() {
  test('integer-like unit type names keep their wire order', () {
    final payload = '{"experiments":['
        '${experiment(1, '{"store_id":"city","2":"city"}')},'
        '${experiment(2, '{"z":"a", "10" : "b","1":"c","a\\"b":"d"}')}'
        ']}';
    expect(decodedOrders(payload), [
      ['store_id', '2'],
      ['z', '10', '1', 'a"b'],
    ]);
  });

  test('the scanner reads keys, escapes and nesting in document order', () {
    expect(
        switchbackClusterKeyOrders(
            '{"a":"switchbackClusters","switchbackClusters":{"x":{"y":[1,"}"]},'
            r'"2":"p"},"b":[{"switchbackClusters":{}}]}'),
        [
          ['x', '2'],
          <String>[]
        ]);
    expect(switchbackClusterKeyOrders('{"e":[]}'), isEmpty);
    expect(switchbackClusterKeyOrders('{"switchbackClusters":{"a"'), isNull);
  });

  test('a payload whose occurrences do not line up keeps the decoded order',
      () {
    final decoded = {
      'switchbackClusters': {'a': 1}
    };
    expect(
        withSwitchbackClusterKeyOrder(decoded, [
          ['b']
        ]),
        same(decoded));
    expect(decoded['switchbackClusters']!.keys, ['a']);
  });
}
