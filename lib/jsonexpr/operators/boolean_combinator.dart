import '../evaluator.dart';
import '../operator.dart';

abstract class BooleanCombinator implements Operator {
  @override
  dynamic evaluate(Evaluator evaluator, dynamic args) {
    if (args is List) {
      final argsList = args as List<dynamic>;
      return combine(evaluator, argsList);
    }
    return null;
  }

  dynamic combine(Evaluator evaluator, List<dynamic> args);
}