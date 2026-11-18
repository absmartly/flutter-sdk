import 'dart:typed_data';

import '../buffers.dart';
import 'md5.dart';

abstract class Hashing {
  static Uint8List threadBuffer =
      Uint8List.fromList(List.generate(512, (index) => 0));

  /// Hashes a unit UID. A number is first written with no decimals, rounded
  /// like JavaScript's toFixed(0) (JS utils.ts hashUnit), so 125.75 hashes
  /// as "126".
  static Uint8List hashUnitValue(Object unit) {
    return hashUnit(hashInput(unit));
  }

  /// The string a unit UID is hashed as: a number written with no decimals,
  /// like JavaScript's toFixed(0), otherwise the string itself.
  static String hashInput(Object unit) {
    if (unit is num) {
      // JS (-0).toFixed(0) is "0", but (-0.4).toFixed(0) is "-0", as here.
      return unit == 0 ? '0' : unit.toStringAsFixed(0);
    }
    return unit as String;
  }

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
