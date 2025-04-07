import 'evaluator.dart';

abstract class Operator {
  dynamic evaluate(Evaluator evaluator, dynamic args);
}
