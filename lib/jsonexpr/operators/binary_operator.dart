import '../evaluator.dart';
import '../operator.dart';

abstract class BinaryOperator implements Operator {
  @override
  dynamic evaluate(Evaluator evaluator, dynamic args) {
    if (args is List) {
      final argsList = args;
      print(argsList);
      final lhs = argsList.isNotEmpty ? evaluator.evaluate(argsList[0]) : null;
      if (lhs != null) {
        final rhs = argsList.length > 1 ? evaluator.evaluate(argsList[1]) : null;
        if (rhs != null) {
          return binary(evaluator, lhs, rhs);
        }
      }
    }
    return null;
  }

  dynamic binary(Evaluator evaluator, dynamic lhs, dynamic rhs);
}