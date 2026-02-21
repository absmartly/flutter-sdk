import 'context.dart';

abstract class VariableParser {
  Map<String, dynamic>? parse(Context context, String experimentName,
      String variantName, String variableValue);
}
