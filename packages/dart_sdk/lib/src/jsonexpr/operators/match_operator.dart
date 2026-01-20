import '../evaluator.dart';
import 'binary_operator.dart';

class MatchOperator extends BinaryOperator {
  @override
  dynamic binary(Evaluator evaluator, dynamic lhs, dynamic rhs) {
    final text = evaluator.stringConvert(lhs);
    if (text != null) {
      final pattern = evaluator.stringConvert(rhs);
      if (pattern != null) {
        try {
          final compiled = RegExp(pattern);
          final matcher = compiled.firstMatch(text);
          return matcher != null;
        } catch (e) {
          // ignore and return null
        }
      }
    }
    return null;
  }
}
