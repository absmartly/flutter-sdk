import '../evaluator.dart';
import '../operator.dart';

class VarOperator implements Operator {
  @override
  dynamic evaluate(Evaluator evaluator, dynamic path) {
    if (path is Map) {
      path = (path as Map<String, dynamic>)['path']!;
    }

    return path is String ? evaluator.extractVar(path) : null;
  }
}
