import 'dart:convert';
import 'audience_deserializer.dart';

class DefaultAudienceDeserializer implements AudienceDeserializer {
  // final JsonDecoder decoder;
  //
  // DefaultAudienceDeserializer() : decoder = const JsonDecoder();

  @override
  Map<String, dynamic>? deserialize(List<int> bytes, int offset, int length) {
    try {

      var rawData = utf8.decode(bytes.sublist(offset, length));
      return jsonDecode(rawData);
    } catch (e) {
      print(e);
      return null;
    }
  }
}
