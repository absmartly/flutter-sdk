import 'unary_operator.dart';

import '../evaluator.dart';

class NotOperator extends UnaryOperator {
  @override
  dynamic unary(Evaluator evaluator, dynamic args) {
    return !evaluator.booleanConvert(args);
  }
}
