import '../evaluator.dart';
import 'binary_operator.dart';

class EqualsOperator extends BinaryOperator {
  @override
  dynamic binary(Evaluator evaluator, dynamic lhs, dynamic rhs) {
    // A null operand short-circuits to null (canonical: eq does not treat
    // null == null as a match), matching the other SDKs and the collector.
    if (lhs == null || rhs == null) {
      return null;
    }
    final result = evaluator.compare(lhs, rhs);
    return result != null ? result == 0 : null;
  }
}
