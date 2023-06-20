import 'dart:convert';

class StandardCharsets{
  /// Seven-bit ASCII, a.k.a. ISO646-US, a.k.a. the Basic Latin block of the
  /// Unicode character set
  static const US_ASCII = AsciiCodec();

  /// Eight-bit UCS Transformation Format
  static const UTF_8 = Utf8Codec();
}