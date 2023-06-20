import 'dart:convert';

import 'package:ab_smartly/default_audience_deserializer.dart';
import 'package:flutter_test/flutter_test.dart';

// all working

void main() {
  test('deserialize', () {
    final DefaultAudienceDeserializer deser = DefaultAudienceDeserializer();
    final String audience = '{"filter":[{"gte":[{"var":"age"},{"value":20}]}]}';
    final List<int> bytes = utf8.encode(audience);

    final Object expected = {"filter": [
      {"gte": [{"var": "age"}, {"value": 20}]}
    ]};
    final dynamic actual = deser.deserialize(bytes, 0, bytes.length);
    expect(expected, equals(actual));
  });

  test('deserializeDoesNotThrow', () {
    final DefaultAudienceDeserializer deser = DefaultAudienceDeserializer();
    final String audience = '{"filter":[{"gte":[{"var":"age"},{"value":20}]}]}';
    final List<int> bytes = utf8.encode(audience);

    expect(() {
      final dynamic actual = deser.deserialize(bytes, 0, 14);
      expect(actual, isNull);
    }, returnsNormally);
  });
}
