import 'dart:core';
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
    final int n = value.length;

    int out = offset;
    for (int i = 0; i < n; ++i) {
      final c = value[i].codeUnitAt(0);
      if (c < 0x80) {
        buf[out++] = c;
      } else if (c < 0x800) {
        buf[out++] = ((c >> 6) | 192);
        buf[out++] = ((c & 63) | 128);
      } else {
        buf[out++] = ((c >> 12) | 224);
        buf[out++] = (((c >> 6) & 63) | 128);
        buf[out++] = ((c & 63) | 128);
      }
    }
    return out - offset;
  }
}
