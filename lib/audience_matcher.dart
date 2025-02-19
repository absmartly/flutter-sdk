import 'dart:convert';
import 'audience_deserializer.dart';
import 'jsonexpr/json_expr.dart';

class AudienceMatcher {
  AudienceMatcher(this.deserializer_) {
    jsonExpr_ = JsonExpr();
  }


  Result? evaluate(String audience, Map<String, dynamic>? attributes) {
    if (audience.isEmpty || audience == 'null' || audience == '{}') {
      return null;
    }

    try {
      final bytes = utf8.encode(audience);
      final audienceMap = deserializer_.deserialize(bytes, 0, bytes.length);
      if (audienceMap != null) {
        final filter = audienceMap['filter'];
        if (filter is Map || filter is List) {
          return Result(jsonExpr_.evaluateBooleanExpr(filter, attributes ?? {}));
        }
      }
    } on FormatException {
      // Handle invalid JSON
      return null;
    } catch (e) {
      // Silently handle any other errors
    }

    return null;
  }

  final AudienceDeserializer deserializer_;
  late final JsonExpr jsonExpr_;
}

class Result {
  Result(this.result);

  bool get() {
    return result;
  }

  final bool result;
}