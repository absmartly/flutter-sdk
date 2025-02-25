import 'dart:convert';
import 'audience_deserializer.dart';

class DefaultAudienceDeserializer implements AudienceDeserializer {
  // final JsonDecoder decoder;
  //
  // DefaultAudienceDeserializer() : decoder = const JsonDecoder();

  @override
  Map<String, dynamic>? deserialize(List<int> bytes, int offset, int length) {
    if (bytes.isEmpty || length <= 0 || offset < 0 || offset >= bytes.length) {
      return null;
    }

    try {
      final endIndex = (offset + length <= bytes.length) ? offset + length : bytes.length;
      final rawData = utf8.decode(bytes.sublist(offset, endIndex));
      if (rawData.isEmpty) {
        return null;
      }
      return jsonDecode(rawData) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
