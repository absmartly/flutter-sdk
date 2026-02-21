import 'dart:convert';

import 'context_data_deserializer.dart';
import 'json/context_data.dart';

class DefaultContextDataDeserializer implements ContextDataDeserializer {
  @override
  ContextData? deserialize(
      final List<int> bytes, final int offset, final int length) {
    try {
      final endIndex = offset + length;
      final slice = bytes.sublist(offset, endIndex);
      var data = utf8.decode(slice);
      var contextData = ContextData.fromMap(jsonDecode(data));
      return contextData;
    } catch (e) {
      print('Error deserializing context data: $e');
      return null;
    }
  }
}
