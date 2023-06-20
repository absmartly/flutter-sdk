import '../evaluator.dart';
import 'binary_operator.dart';

class LessThenOrEqualOperator extends BinaryOperator {
  @override
  dynamic binary(Evaluator evaluator, dynamic lhs, dynamic rhs) {
    final result = evaluator.compare(lhs, rhs);
    return result != null ? result <= 0 : null;
  }
}
