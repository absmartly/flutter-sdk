import 'dart:typed_data';

import '../buffers.dart';

// ignore: camel_case_types
abstract class Murmur3_32 {
  static int digest(
    Uint8List key,
    int seed, {
    int? offset,
    int? len,
  }) {
    offset = offset ?? 0;
    len = len ?? (key.length - offset);

    final int n = offset + (len & ~3);

    int hash = seed;
    int i = offset;
    for (; i < n; i += 4) {
      final int chunk = Buffers.getUInt32(key, i);
      hash ^= scramble32(chunk);
      hash = rotl32(hash, 13);
      hash = (imul32(hash, 5) + 0xe6546b64) & 0xffffffff;
    }

    switch (len & 3) {
      case 3:
        hash ^= scramble32(Buffers.getUInt24(key, i));
        break;
      case 2:
        hash ^= scramble32(Buffers.getUInt16(key, i));
        break;
      case 1:
        hash ^= scramble32(Buffers.getUInt8(key, i));
        break;
      case 0:
      default:
        break;
    }

    hash ^= len;
    hash = fmix32(hash);
    return hash;
  }

  static int fmix32(int h) {
    h ^= h >>> 16;
    h = imul32(h, 0x85ebca6b);
    h ^= h >>> 13;
    h = imul32(h, 0xc2b2ae35);
    h ^= h >>> 16;

    return h;
  }

  static int imul32(int a, int b) {
    return (a * b) & 0xffffffff;
  }

  static int rotl32(int n, int d) {
    return (n << d) | (n >> (32 - d));
  }

  static int scramble32(int block) {
    return imul32(rotl32(imul32(block, 0xcc9e2d51), 15), 0x1b873593);
  }
}
