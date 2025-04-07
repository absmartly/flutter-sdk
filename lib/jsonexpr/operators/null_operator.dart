import 'package:absmartly_sdk/jsonexpr/operators/unary_operator.dart';

import '../evaluator.dart';

class NullOperator extends UnaryOperator {
  @override
  dynamic unary(Evaluator evaluator, dynamic arg) {
    return arg == null;
  }
}
