import '../evaluator.dart';
import 'binary_operator.dart';

class InOperator extends BinaryOperator {
  @override
  dynamic binary(Evaluator evaluator, dynamic lhs, dynamic rhs) {
    if (lhs is List) {
      for (final item in lhs) {
        if (evaluator.compare(item, rhs) == 0) {
          return true;
        }
      }
      return false;
    } else if (lhs is String) {
      final needleString = evaluator.stringConvert(rhs);
      return needleString != null && (lhs).contains(needleString);
    } else if (lhs is Map) {
      final needleString = evaluator.stringConvert(rhs);
      return needleString != null && (lhs as Map<String, dynamic>).containsKey(needleString);
    }
    return null;
  }
}


