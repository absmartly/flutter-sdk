import '../evaluator.dart';
import 'binary_operator.dart';

class InOperator extends BinaryOperator {
  @override
  dynamic binary(Evaluator evaluator, dynamic lhs, dynamic rhs) {
    if (rhs is List) {
      for (final item in rhs) {
        if (evaluator.compare(item, lhs) == 0) {
          return true;
        }
      }
      return false;
    } else if (rhs is String) {
      if (lhs is! String) return null;
      return rhs.contains(lhs);
    } else if (rhs is Map) {
      final needleString = evaluator.stringConvert(lhs);
      return needleString != null &&
          (rhs as Map<String, dynamic>).containsKey(needleString);
    }
    return null;
  }
}
