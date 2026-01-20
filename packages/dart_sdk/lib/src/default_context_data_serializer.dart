import 'dart:convert';

import 'context_data_deserializer.dart';
import 'json/context_data.dart';

class DefaultContextDataDeserializer implements ContextDataDeserializer {
  @override
  ContextData? deserialize(
      final List<int> bytes, final int offset, final int length) {
    try {
      var data = utf8.decode(bytes);
      var contextData = ContextData.fromMap(jsonDecode(data));
      return contextData;
    } catch (e) {
      print(e);
      return null;
    }
  }
}
