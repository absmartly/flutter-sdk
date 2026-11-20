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

  /// The string a unit UID is hashed as: a number written with no decimals
  /// like JavaScript's toFixed(0) (a native int in its exact decimal form),
  /// otherwise the string itself.
  static String hashInput(Object unit) {
    if (unit is num) {
      // JS (-0).toFixed(0) is "0", but (-0.4).toFixed(0) is "-0", as here.
      if (unit == 0) {
        return '0';
      }
      // On the VM int.toStringAsFixed goes through a double, which would
      // merge distinct IDs above 2^53, so an int uses toString(). Compiled to
      // JS every number is a double and a whole one also passes `is int`, so
      // there toStringAsFixed(0), which is JS toFixed(0), is always right.
      return unit is int && !_isJs ? unit.toString() : unit.toStringAsFixed(0);
    }
    return unit as String;
  }

  // True when compiled to JavaScript, where int and double are one type.
  static const bool _isJs = identical(0, 0.0);

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
