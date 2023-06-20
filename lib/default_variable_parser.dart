import 'dart:convert';
import 'dart:io';
import 'package:absmartly_sdk/variable_parser.dart';

import 'context.dart';

class DefaultVariableParser implements VariableParser {

  @override
  Map<String, dynamic>? parse(Context context, String experimentName,
      String variantName, final String config) {
    try {
      var rawData = jsonDecode(config);
      return rawData;
    } on IOException catch (e) {
      print(e);
      return null;
    }
  }
}