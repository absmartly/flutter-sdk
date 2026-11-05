import '../evaluator.dart';
import '../operator.dart';

abstract class BinaryOperator implements Operator {
  @override
  dynamic evaluate(Evaluator evaluator, dynamic args) {
    // A missing or null operand short-circuits to null; extra operands are
    // ignored (JS jsonexpr/operators/binary.ts).
    if (args is List) {
      final lhs = args.isNotEmpty ? evaluator.evaluate(args[0]) : null;
      if (lhs != null) {
        final rhs = args.length > 1 ? evaluator.evaluate(args[1]) : null;
        if (rhs != null) {
          return binary(evaluator, lhs, rhs);
        }
      }
    }
    return null;
  }

  dynamic binary(Evaluator evaluator, dynamic lhs, dynamic rhs);
}
