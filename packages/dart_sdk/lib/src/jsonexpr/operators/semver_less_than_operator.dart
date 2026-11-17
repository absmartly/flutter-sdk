import '../evaluator.dart';
import '../semver_comparator.dart';
import 'binary_operator.dart';

class SemverLessThanOperator extends BinaryOperator {
  @override
  dynamic binary(Evaluator evaluator, dynamic lhs, dynamic rhs) {
    final result = SemverComparator.compareValues(evaluator, lhs, rhs);
    return result != null ? result < 0 : null;
  }
}
