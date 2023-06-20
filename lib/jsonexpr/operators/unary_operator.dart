import '../evaluator.dart';
import '../operator.dart';

abstract class UnaryOperator implements Operator {
  @override
  dynamic evaluate(Evaluator evaluator, dynamic args) {
    final arg = evaluator.evaluate(args);
    return unary(evaluator, arg);
  }

  dynamic unary(Evaluator evaluator, dynamic arg);
}

class NotOperator extends UnaryOperator {
  @override
  dynamic unary(Evaluator evaluator, dynamic args) {
    return !evaluator.booleanConvert(args);
  }
}