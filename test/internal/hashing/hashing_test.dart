import 'dart:convert';

import 'package:absmartly_sdk/internal/hashing/hashing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test buffer resizing', () {
    final longString =
        'a' * 1000; // a string longer than the default buffer size
    final hash = Hashing.hashUnit(longString);
    expect(hash, isNotNull); // make sure a hash was generated
  });
  test('Test threadBuffer sharing', () {
    final hash1 = Hashing.hashUnit('foo');
    final hash2 = Hashing.hashUnit('bar');
    expect(
        hash1,
        isNot(equals(
            hash2))); // make sure different inputs generate different hashes
  });

  test('Test hashUnit', () {
    expect(
        utf8.decode(Hashing.hashUnit(
            '4a42766ca6313d26f49985e799ff4f3790fb86efa0fce46edb3ea8fbf1ea3408')),
        equals('H2jvj6o9YcAgNdhKqEbtWw'));
    expect(utf8.decode(Hashing.hashUnit('bleh@absmarty.com')),
        equals('DRgslOje35bZMmpaohQjkA'));
    expect(utf8.decode(Hashing.hashUnit('açb↓c')),
        equals('LxcqH5VC15rXfWfA_smreg'));
    expect(utf8.decode(Hashing.hashUnit('testy')),
        equals('K5I_V6RgP8c6sYKz-TVn8g'));
    expect(utf8.decode(Hashing.hashUnit(123456778999.toString())),
        equals('K4uy4bTeCy34W97lmceVRg'));
  });

  test('Test hashUnitLarge', () {
    const String chars =
        '4a42766ca6313d26f49985e799ff4f3790fb86efa0fce46edb3ea8fbf1ea3408';
    final StringBuffer sb = StringBuffer();

    const int count = (2048 + chars.length - 1) ~/ chars.length;
    for (int i = 0; i < count; ++i) {
      sb.write(chars);
    }

    expect(utf8.decode(Hashing.hashUnit(sb.toString())),
        equals('Rxnq-eM9eE1SEoMnkEMOIw'));
  });
}
