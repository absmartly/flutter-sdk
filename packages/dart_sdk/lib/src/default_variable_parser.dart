import 'dart:convert';
import 'variable_parser.dart';

import 'context.dart';

class DefaultVariableParser implements VariableParser {
  @override
  Map<String, dynamic>? parse(Context context, String experimentName,
      String variantName, final String config) {
    final dynamic rawData;
    try {
      rawData = jsonDecode(config);
    } on FormatException catch (e) {
      print(
          "Failed to parse variable values for experiment '$experimentName', variant '$variantName': $e");
      return null;
    }
    if (rawData is! Map<String, dynamic>) {
      print(
          "Variable values for experiment '$experimentName', variant '$variantName' are not a JSON object");
      return null;
    }
    return rawData;
  }
}
