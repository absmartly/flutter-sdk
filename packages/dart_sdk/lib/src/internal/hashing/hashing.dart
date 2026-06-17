import 'dart:typed_data';

import '../buffers.dart';
import 'md5.dart';

abstract class Hashing {
  static Uint8List threadBuffer =
      Uint8List.fromList(List.generate(512, (index) => 0));

  static Uint8List hashUnit(String unit) {
    final int n = unit.length;
    // Up to 4 UTF-8 bytes per UTF-16 code unit (3-byte BMP chars, and 4-byte
    // astral chars span two code units). n << 1 underflowed for 3-byte chars.
    final int bufferLen = n * 4;

    Uint8List buffer = threadBuffer;
    if (buffer.length < bufferLen) {
      final int bit = 32 - (32 - (bufferLen - 1).bitLength);
      buffer = Uint8List.fromList(List.generate(1 << bit, (index) => 0));
      threadBuffer = buffer;
    }

    final int encoded = Buffers.encodeUTF8(buffer, 0, unit);
    return MD5.digestBase64UrlNoPadding(buffer, offset: 0, len: encoded);
  }
}
