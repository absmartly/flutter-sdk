import 'dart:convert';

import 'context_data_deserializer.dart';
import 'internal/json_key_order.dart';
import 'json/context_data.dart';

// On the web an int is a JavaScript number, and jsonDecode builds JavaScript
// objects, which list integer-like keys first.
const bool _isWeb = identical(0, 0.0);

class DefaultContextDataDeserializer implements ContextDataDeserializer {
  @override
  ContextData? deserialize(
      final List<int> bytes, final int offset, final int length) {
    try {
      var data = utf8.decode(bytes);
      dynamic decoded = jsonDecode(data);
      if (_isWeb && hasReorderedSwitchbackClusters(decoded)) {
        // switchbackClusters order is semantic: restore the wire order a
        // unit type with an integer-like name would lose.
        final orders = switchbackClusterKeyOrders(data);
        if (orders != null && orders.isNotEmpty) {
          decoded = withSwitchbackClusterKeyOrder(decoded, orders);
        }
      }
      var contextData = ContextData.fromMap(decoded);
      return contextData;
    } catch (e) {
      print(e);
      return null;
    }
  }
}
