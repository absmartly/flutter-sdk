// switchbackClusters order through the default context-data decoder, on the
// VM and compiled to JavaScript, where jsonDecode lists integer-like object
// keys first.
import 'dart:convert';

import 'package:absmartly_dart/src/default_context_data_serializer.dart';
import 'package:absmartly_dart/src/internal/json_key_order.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:test/test.dart';

String experiment(int id, String clusters,
        {String field = 'switchbackClusters'}) =>
    '{"id":$id,"name":"e$id","unitType":"u","iteration":1,"seedHi":0,'
    '"seedLo":0,"split":[0.5,0.5],"trafficSeedHi":0,"trafficSeedLo":0,'
    '"trafficSplit":[0,1],"fullOnVariant":0,"variants":[],'
    '"randomizationType":"switchback","$field":$clusters}';

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

  // The web enumerates an integer-like root key before "experiments", so
  // each order is bound to its own object by path, not by visit order.
  test('each object keeps its own order whatever the root key order', () {
    final payload = '{"experiments":['
        '${experiment(1, '{"store_id":"city","2":"city"}')}'
        '],"0":{"switchbackClusters":{"2":"city","store_id":"city"}}}';
    expect(decodedOrders(payload), [
      ['store_id', '2']
    ]);
  });

  test('an escaped spelling of switchbackClusters is recognized', () {
    final payload = '{"experiments":['
        '${experiment(1, '{"store_id":"city","2":"city"}', field: r'switchback\u0043lusters')}'
        ']}';
    expect(decodedOrders(payload), [
      ['store_id', '2']
    ]);
  });

  test('the scanner records paths and keys in document order', () {
    expect(
        switchbackClusterKeyOrders(
                '{"a":"switchbackClusters","switchbackClusters":{"x":{"y":[1,"}"]},'
                r'"2":"p"},"b":[{"switchbackClusters":{}}]}')!
            .map((o) => '${o.$1} ${o.$2}'),
        ['[switchbackClusters] [x, 2]', '[b, 0, switchbackClusters] []']);
    expect(switchbackClusterKeyOrders('{"e":[]}'), isEmpty);
    expect(switchbackClusterKeyOrders('{"switchbackClusters":{"a"'), isNull);
  });

  test('a path that does not match keeps the decoded order', () {
    final decoded = {
      'switchbackClusters': {'a': 1}
    };
    withSwitchbackClusterKeyOrder(decoded, [
      (['switchbackClusters'], ['b']),
      (['missing', 0], ['a']),
    ]);
    expect(decoded['switchbackClusters']!.keys, ['a']);
  });
}
