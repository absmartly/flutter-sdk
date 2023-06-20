import 'dart:convert';

import 'package:absmartly_sdk/internal/hashing/hashing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test buffer resizing', () {
    final longString = 'a' * 1000; // a string longer than the default buffer size
    final hash = Hashing.hashUnit(longString);
    expect(hash, isNotNull); // make sure a hash was generated
  });
  test('Test threadBuffer sharing', () {
    final hash1 = Hashing.hashUnit('foo');
    final hash2 = Hashing.hashUnit('bar');
    expect(hash1, isNot(equals(hash2))); // make sure different inputs generate different hashes
  });


}
