import 'dart:core';
import 'dart:convert';
import 'dart:typed_data';

abstract class Buffers {
  static void putUInt32(Uint8List buf, int offset, int x) {
    buf[offset] = (x & 0xff);
    buf[offset + 1] = ((x >> 8) & 0xff);
    buf[offset + 2] = ((x >> 16) & 0xff);
    buf[offset + 3] = ((x >> 24) & 0xff);
  }

  static int getUInt32(Uint8List buf, int offset) {
    return (buf[offset] & 0xff) |
        ((buf[offset + 1] & 0xff) << 8) |
        ((buf[offset + 2] & 0xff) << 16) |
        ((buf[offset + 3] & 0xff) << 24);
  }

  static int getUInt24(Uint8List buf, int offset) {
    return (buf[offset] & 0xff) |
        ((buf[offset + 1] & 0xff) << 8) |
        ((buf[offset + 2] & 0xff) << 16);
  }

  static int getUInt16(Uint8List buf, int offset) {
    return (buf[offset] & 0xff) | ((buf[offset + 1] & 0xff) << 8);
  }

  static int getUInt8(Uint8List buf, int offset) {
    return (buf[offset] & 0xff);
  }

  static int encodeUTF8(Uint8List buf, int offset, String value) {
    // Delegate to the platform UTF-8 encoder so characters outside the Basic
    // Multilingual Plane (e.g. emoji, stored as UTF-16 surrogate pairs) produce
    // correct 4-byte UTF-8 sequences. The previous hand-rolled loop processed
    // each UTF-16 code unit independently and emitted invalid CESU-8 for
    // surrogate pairs, yielding a different unit hash than the other SDKs and
    // the collector.
    final List<int> bytes = utf8.encode(value);
    buf.setRange(offset, offset + bytes.length, bytes);
    return bytes.length;
  }
}
