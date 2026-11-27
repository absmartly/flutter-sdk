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
    // Combine valid pairs, but retain 2.1's three-byte encoding for an
    // unpaired surrogate, as released JavaScript and Java do for unit IDs.
    int k = offset;
    for (int i = 0; i < value.length; i++) {
      int c = value.codeUnitAt(i);
      if (c >= 0xd800 && c <= 0xdbff && i + 1 < value.length) {
        final int next = value.codeUnitAt(i + 1);
        if (next >= 0xdc00 && next <= 0xdfff) {
          c = ((c - 0xd800) << 10) + (next - 0xdc00) + 0x10000;
          i++;
        }
      }
      if (c < 0x80) {
        buf[k++] = c;
      } else if (c < 0x800) {
        buf[k++] = 0xc0 | (c >> 6);
        buf[k++] = 0x80 | (c & 0x3f);
      } else if (c < 0x10000) {
        buf[k++] = 0xe0 | (c >> 12);
        buf[k++] = 0x80 | ((c >> 6) & 0x3f);
        buf[k++] = 0x80 | (c & 0x3f);
      } else {
        buf[k++] = 0xf0 | (c >> 18);
        buf[k++] = 0x80 | ((c >> 12) & 0x3f);
        buf[k++] = 0x80 | ((c >> 6) & 0x3f);
        buf[k++] = 0x80 | (c & 0x3f);
      }
    }
    return k - offset;
  }
}
