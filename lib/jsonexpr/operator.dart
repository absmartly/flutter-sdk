import 'evaluator.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<Operator>()])
abstract class Operator {
  dynamic evaluate(Evaluator evaluator, dynamic args);
}
