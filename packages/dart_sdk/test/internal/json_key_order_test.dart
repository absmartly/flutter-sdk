// switchbackClusters order through the default context-data decoder, on the
// VM and compiled to JavaScript, where jsonDecode lists integer-like object
// keys first.
import 'dart:convert';

import 'package:absmartly_dart/src/default_context_data_serializer.dart';
import 'package:absmartly_dart/src/internal/context_counters.dart';
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

  // Every experiment is checked, not only the first.
  test('a later experiment with an integer-like key keeps its order', () {
    final payload = '{"experiments":['
        '${experiment(1, '{"store_id":"city"}')},'
        '${experiment(2, '{"store_id":"city","2":"city"}')}'
        ']}';
    expect(decodedOrders(payload), [
      ['store_id'],
      ['store_id', '2'],
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

  // A repeated key keeps its first position, as JavaScript and Dart maps do.
  test('a repeated unit type keeps its first position', () {
    final payload = '{"experiments":['
        '${experiment(1, '{"2":"a","store_id":"b","2":"c"}')}'
        ']}';
    expect(decodedOrders(payload), [
      ['2', 'store_id']
    ]);
  });

  // Only a payload whose cluster map has an integer-like unit type name is
  // scanned: an escaped character elsewhere, or names JavaScript keeps in
  // wire order, cost nothing.
  test('only a cluster map with an integer-like key is scanned', () {
    for (final payload in [
      '{"experiments":[]}',
      '{"experiments":[${experiment(1, '{"store_id":"caf\\u00e9"}')}]}',
      '{"experiments":[${experiment(1, '{"b":"x","a":"y","02":"z"}')}]}',
      '{"experiments":[${experiment(1, '{"b":"x","4294967295":"y","-1":"z"}')}]}',
      // A cluster map outside an experiment is not read.
      '{"experiments":[],"x":{"switchbackClusters":{"a":"b","2":"c"}}}',
    ]) {
      ContextCounters.reset();
      decodedOrders(payload);
      expect(ContextCounters.keyOrderScans, 0, reason: payload);
    }
    for (final key in ['0', '2', '42', '4294967294']) {
      expect(
          hasReorderedSwitchbackClusters(jsonDecode('{"experiments":'
              '[{"switchbackClusters":{"store_id":"c","$key":"c"}}]}')),
          isTrue,
          reason: key);
    }
  });

  // A deeply nested unrelated field never fails a payload without
  // switchbacks, wherever it sits.
  test('a deeply nested payload without switchbacks decodes', () {
    final deep = '${'[' * 5000}${']' * 5000}';
    for (final payload in [
      '{"experiments":[],"x":$deep}',
      '{"x":$deep,"experiments":[]}',
    ]) {
      final bytes = utf8.encode(payload);
      expect(
          DefaultContextDataDeserializer().deserialize(bytes, 0, bytes.length),
          isNotNull);
    }
  });

  // An unrelated value nested deeper than the scanner can follow keeps the
  // decoded order instead of failing the payload.
  test('a deeply nested payload still decodes', () {
    final deep = '${'[' * 5000}${']' * 5000}';
    final payload = '{"experiments":['
        '${experiment(1, '{"store_id":"city","2":"city"}')}'
        '],"x":$deep}';
    expect(decodedOrders(payload).single.toSet(), {'store_id', '2'});
  });
}
