import 'dart:convert';
import 'dart:typed_data';

import 'package:absmartly_dart/src/internal/hashing/hashing.dart';
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
      final key = Uint8List.fromList(utf8.encode(v[0] as String));
      expect(Murmur3_32.digest(key, v[1] as int), v[2],
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

  test('32-bit multiply is exact for operands above 2^26', () {
    expect(Murmur3_32.imul32(0xffffffff, 0xffffffff), 1);
    expect(Murmur3_32.imul32(0xcc9e2d51, 0x1b873593), 0xaeecca83);
    expect(Murmur3_32.imul32(0x85ebca6b, 0xc2b2ae35), 0xd1cba227);
    expect(Murmur3_32.imul32(0x80000000, 3), 0x80000000);
  });
}
