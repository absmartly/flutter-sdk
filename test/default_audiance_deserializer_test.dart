import 'dart:convert';

import 'package:absmartly_sdk/default_audience_deserializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deserialize', () {
    final DefaultAudienceDeserializer deser = DefaultAudienceDeserializer();
    const String audience = '{"filter":[{"gte":[{"var":"age"},{"value":20}]}]}';
    final List<int> bytes = utf8.encode(audience);

    final Object expected = {
      "filter": [
        {
          "gte": [
            {"var": "age"},
            {"value": 20}
          ]
        }
      ]
    };
    final dynamic actual = deser.deserialize(bytes, 0, bytes.length);
    expect(expected, equals(actual));
  });

  test('deserializeDoesNotThrow', () {
    final DefaultAudienceDeserializer deser = DefaultAudienceDeserializer();
    const String audience = '{"filter":[{"gte":[{"var":"age"},{"value":20}]}]}';
    final List<int> bytes = utf8.encode(audience);

    expect(() {
      final dynamic actual = deser.deserialize(bytes, 0, 14);
      expect(actual, isNull);
    }, returnsNormally);
  });
}
