import 'dart:convert';
import 'dart:typed_data';

import 'package:absmartly_dart/src/internal/hashing/hashing.dart';
import 'package:absmartly_dart/src/internal/buffers.dart';
import 'package:absmartly_dart/src/internal/hashing/murmur3_32.dart';
import 'package:absmartly_dart/src/internal/variant_assigner.dart';
import 'package:test/test.dart';

import 'js_reference_vectors.dart';

// Runs on the VM and compiled to JavaScript (CI: dart test -p node): a unit
// must get the same variant on Flutter Web as on native and the other SDKs.
void main() {
  test('unit hashes match the JavaScript SDK', () {
    for (final v in md5Vectors) {
      expect(ascii.decode(Hashing.hashUnit(v[0])), v[1], reason: v[0]);
    }
  });

  test('murmur3 digests match the JavaScript SDK', () {
    for (final v in murmurVectors) {
      final key = Uint8List((v[0] as String).length * 4);
      final length = Buffers.encodeUTF8(key, 0, v[0] as String);
      expect(Murmur3_32.digest(key, v[1] as int, len: length), v[2],
          reason: '${v[0]} seed ${v[1]}');
    }
  });

  test('variant assignment matches the JavaScript SDK', () {
    for (final v in assignVectors) {
      final assigner = VariantAssigner(Hashing.hashUnit(v[0] as String));
      final split = (v[3] as List).cast<double>();
      expect(assigner.assign(split, v[1] as int, v[2] as int), v[4],
          reason: '${v[0]} seeds ${v[1]}/${v[2]} split $split');
    }
  });

  test('five malformed UIDs keep released JS Java and Flutter bytes', () {
    final vectors = <List<Object>>[
      [
        "x\ud800y",
        [120, 237, 160, 128, 121],
        'P_T7FloHPE54-OfzOGQwAw'
      ],
      [
        "\ud800",
        [237, 160, 128],
        'VG09yN4Q-_i0SPZ4pHkB5A'
      ],
      [
        "a\udc00",
        [97, 237, 176, 128],
        '_3emNm0tW7Ex4UI20FhR4w'
      ],
      [
        "\udbff",
        [237, 175, 191],
        'rcSX3LMCMz7OMYVfDsDE2A'
      ],
      [
        "ab\ud83dcd",
        [97, 98, 237, 160, 189, 99, 100],
        'cxcYMfzbeuuTbsQtntSfPQ'
      ],
    ];
    for (final row in vectors) {
      final value = row[0] as String;
      final buffer = Uint8List(value.length * 4 + 4)
        ..fillRange(0, value.length * 4 + 4, 0x55);
      final n = Buffers.encodeUTF8(buffer, 2, value);
      expect(buffer.sublist(2, 2 + n), row[1]);
      expect(buffer.sublist(0, 2), [0x55, 0x55]);
      expect(buffer[2 + n], 0x55);
      expect(ascii.decode(Hashing.hashUnit(value)), row[2]);
    }
  });

  test('32-bit multiply is exact for operands above 2^26', () {
    expect(Murmur3_32.imul32(0xffffffff, 0xffffffff), 1);
    expect(Murmur3_32.imul32(0xcc9e2d51, 0x1b873593), 0xaeecca83);
    expect(Murmur3_32.imul32(0x85ebca6b, 0xc2b2ae35), 0xd1cba227);
    expect(Murmur3_32.imul32(0x80000000, 3), 0x80000000);
  });
}
