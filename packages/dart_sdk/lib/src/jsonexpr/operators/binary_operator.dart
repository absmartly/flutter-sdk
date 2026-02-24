import '../evaluator.dart';
import '../operator.dart';

abstract class BinaryOperator implements Operator {
  @override
  dynamic evaluate(Evaluator evaluator, dynamic args) {
    if (args is List && args.length == 2) {
      final lhs = evaluator.evaluate(args[0]);
      final rhs = evaluator.evaluate(args[1]);
      return binary(evaluator, lhs, rhs);
    }
    return null;
  }

  dynamic binary(Evaluator evaluator, dynamic lhs, dynamic rhs);
}
