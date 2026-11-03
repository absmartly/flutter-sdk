import 'dart:typed_data';
import 'dart:convert';

import 'package:absmartly_dart/src/internal/buffers.dart';
import 'package:absmartly_dart/src/internal/hashing/hashing.dart';
import 'package:absmartly_dart/src/internal/variant_assigner.dart';
import 'package:test/test.dart';

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

  test('Test hashUnit astral and multibyte', () {
    // Characters outside the Basic Multilingual Plane are stored as UTF-16
    // surrogate pairs and must encode to 4-byte UTF-8. These canonical hashes
    // are shared across all SDKs (computed from correct UTF-8 bytes); a buggy
    // per-code-unit encoder produces a different hash and fails here.
    expect(
        utf8.decode(Hashing.hashUnit('😀')), equals('KgLqw51xanDs83V5GFkntg'));
    expect(utf8.decode(Hashing.hashUnit('😀😁')),
        equals('ZJuDalvUWRJnVtkspj-2bQ'));
    expect(utf8.decode(Hashing.hashUnit('世界你好')),
        equals('v2CJG7YcjjWncKOSCzF2GA'));
    expect(utf8.decode(Hashing.hashUnit('user_世界_123')),
        equals('SCgk4OzXlFMvo1UMsP88fA'));
  });

  group('cross-SDK UTF-8 vectors', () {
    // Shared vectors validated against the JS SDK's stringToUint8Array and
    // hashUnit: standard 4-byte UTF-8 for non-BMP characters (never CESU-8)
    // and U+FFFD for a lone surrogate.
    final vectors = <String, List<Object>>{
      'user\u{1F600}id': [
        [117, 115, 101, 114, 240, 159, 152, 128, 105, 100],
        'nnPMxN6wY36LGRnuJ6jZrw'
      ],
      '\u{1F600}': [
        [240, 159, 152, 128],
        'KgLqw51xanDs83V5GFkntg'
      ],
      '\u{2000B}': [
        [240, 160, 128, 139],
        '8mWvgvNGn-DZqb6Ft0HVjA'
      ],
      'a€\u{1D11E}z': [
        [97, 226, 130, 172, 240, 157, 132, 158, 122],
        'AGGq8R9K1XjO77q33izhLg'
      ],
      '\u{1F1F5}\u{1F1F9}': [
        [240, 159, 135, 181, 240, 159, 135, 185],
        '1RRpVphazpblARsm5DaSkg'
      ],
      'ab\uD83Dcd': [
        [97, 98, 239, 191, 189, 99, 100],
        'jvDxBUzS9Tdsml3QQStWSg'
      ],
    };

    vectors.forEach((value, expected) {
      test('encodes and hashes ${jsonEncode(value)}', () {
        final buf = Uint8List(64);
        final n = Buffers.encodeUTF8(buf, 0, value);
        expect(buf.sublist(0, n), equals(expected[0]));
        expect(utf8.decode(Hashing.hashUnit(value)), equals(expected[1]));
      });
    });

    test('assigns non-BMP units like the JS VariantAssigner', () {
      const split = [0.5, 0.5];
      const seedHi = 3603583;
      const seedLo = 233373918;
      final expected = {
        '\u{1F600}': 1,
        '\u{1F1F5}\u{1F1F9}': 0,
        'a€\u{1D11E}z': 1,
        'user\u{1F600}id': 0,
      };
      expected.forEach((unit, variant) {
        final assigner = VariantAssigner(Hashing.hashUnit(unit));
        expect(assigner.assign(split, seedHi, seedLo), equals(variant),
            reason: unit);
      });
    });
  });
}
