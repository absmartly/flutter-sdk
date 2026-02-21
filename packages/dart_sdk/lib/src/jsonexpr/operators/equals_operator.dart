import '../evaluator.dart';
import 'binary_operator.dart';

class EqualsOperator extends BinaryOperator {
  @override
  dynamic binary(Evaluator evaluator, dynamic lhs, dynamic rhs) {
    final result = evaluator.compare(lhs, rhs);
    return result == null ? null : result == 0;
  }
}
