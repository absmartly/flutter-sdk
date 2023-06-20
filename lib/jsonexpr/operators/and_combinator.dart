import '../evaluator.dart';
import 'boolean_combinator.dart';

class AndCombinator extends BooleanCombinator {
  @override
  combine(Evaluator evaluator, List<dynamic> exprs) {
    for (final expr in exprs) {
      if (!evaluator.booleanConvert(evaluator.evaluate(expr))) {
        return false;
      }
    }
    return true;
  }
}