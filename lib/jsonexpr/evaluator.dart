import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<Evaluator>()])
abstract class Evaluator {
  dynamic evaluate(dynamic expr);

  dynamic booleanConvert(dynamic x);

  num? numberConvert(dynamic x);

  String? stringConvert(dynamic x);

  dynamic extractVar(String path);

  dynamic compare(dynamic lhs, dynamic rhs);
}
