import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

abstract class MD5 {
  static Uint8List digestBase64UrlNoPadding(
    Uint8List key, {
    int? offset,
    int? len,
  }) {
    offset = offset ?? 0;
    len = len ?? (key.length - offset);

    var result = const Base64Codec.urlSafe()
        .encode(md5.convert(key.sublist(offset, (offset) + len)).bytes);

    for (int i = result.length - 1; i < result.length; i++) {
      if (result[i] == '=') {
        result = result.substring(0, i - 1);
        break;
      }
    }

    return ascii.encoder.convert(result);
  }
}
