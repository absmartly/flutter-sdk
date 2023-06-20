import 'context.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<VariableParser>()])

abstract class VariableParser {
  Map<String, dynamic>? parse(Context context, String experimentName,
      String variantName, String variableValue);
}
