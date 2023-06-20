import 'operator.dart';
import 'expr_evaluator.dart';
import 'operators/and_combinator.dart';
import 'operators/equals_operator.dart';
import 'operators/greater_then_operator.dart';
import 'operators/greater_then_or_equal_operator.dart';
import 'operators/in_operator.dart';
import 'operators/less_then_operator.dart';
import 'operators/less_then_or_eqal_operator.dart';
import 'operators/match_operator.dart';
import 'operators/not_operator.dart';
import 'operators/null_operator.dart';
import 'operators/or_combinator.dart';
import 'operators/value_operator.dart';
import 'operators/var_operator.dart';

class JsonExpr {
  static final Map<String, Operator> operators = {
    'and': AndCombinator(),
    'or': OrCombinator(),
    'value': ValueOperator(),
    'var': VarOperator(),
    'null': NullOperator(),
    'not': NotOperator(),
    'in': InOperator(),
    'match': MatchOperator(),
    'eq': EqualsOperator(),
    'gt': GreaterThenOperator(),
    'gte': GreaterThenOrEqualOperator(),
    'lt': LessThenOperator(),
    'lte': LessThenOrEqualOperator(),
  };

  bool evaluateBooleanExpr(dynamic expr, Map<String?, dynamic> vars) {
   final evaluator = ExprEvaluator(operators, vars);

    return evaluator.booleanConvert(evaluator.evaluate(expr));
  }

  dynamic evaluateExpr(dynamic expr, Map<String?, dynamic> vars) {
    final evaluator = ExprEvaluator(operators, vars);

    return evaluator.evaluate(expr);
  }
}