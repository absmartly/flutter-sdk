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

  /// The string a unit UID is hashed as: an int in its exact decimal form, a
  /// double written with no decimals like JavaScript's toFixed(0), otherwise
  /// the string itself.
  static String hashInput(Object unit) {
    if (unit is num) {
      // JS (-0).toFixed(0) is "0", but (-0.4).toFixed(0) is "-0", as here.
      // The zero check comes first: on the web -0.0 is also an int.
      if (unit == 0) {
        return '0';
      }
      // int.toStringAsFixed goes through a double on the VM, which would merge
      // distinct IDs above 2^53. On the web an int is a JS number, and its
      // toString() is what toFixed(0) gives for a whole number.
      return unit is int ? unit.toString() : unit.toStringAsFixed(0);
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
