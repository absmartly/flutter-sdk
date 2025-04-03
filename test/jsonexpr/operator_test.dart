import 'package:absmartly_sdk/jsonexpr/json_expr.dart';
import 'package:absmartly_sdk/jsonexpr/evaluator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/and_combinator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/equals_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/greater_then_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/greater_then_or_equal_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/in_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/less_then_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/less_then_or_eqal_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/match_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/not_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/null_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/or_combinator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/value_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/var_operator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockEvaluator extends Mock implements Evaluator {}

void main() {
  group('JsonExpr Integration Tests', () {
    test('evaluateExpr() test equals operator', () {
      final expr = {
        'eq': [
          {"var": "age"},
          {"value": 20}
        ],
      };
      var vars = {'age': 20};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));

      vars = {'age': 42};

      result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(false));
    });

    test('evaluateExpr() test and operator', () {
      final expr = {
        'and': [
          {"var": "age"},
          {"value": 1}
        ],
      };
      var vars = {'age': 1};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));

      vars = {'age': 0};

      result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(false));
    });

    test('evaluateExpr() test or operator', () {
      final expr = {
        'or': [
          {"var": "age"},
          {"value": 0}
        ],
      };
      var vars = {'age': 1};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));

      vars = {'age': 0};

      result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(false));
    });

    test('evaluateExpr() test greater than operator', () {
      final expr = {
        'gt': [
          {"var": "age"},
          {"value": 22}
        ],
      };
      var vars = {'age': 23};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));

      vars = {'age': 22};

      result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(false));
    });

    test('evaluateExpr() test greater than equal to operator', () {
      final expr = {
        'gte': [
          {"var": "age"},
          {"value": 22}
        ],
      };
      var vars = {'age': 22};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));

      vars = {'age': 21};

      result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(false));
    });

    test('evaluateExpr() test less than operator', () {
      final expr = {
        'lt': [
          {"var": "age"},
          {"value": 22}
        ],
      };
      var vars = {'age': 21};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));

      vars = {'age': 23};

      result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(false));
    });

    test('evaluateExpr() test less than equal to operator', () {
      final expr = {
        'lte': [
          {"var": "age"},
          {"value": 22}
        ],
      };
      var vars = {'age': 22};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));

      vars = {'age': 23};

      result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(false));
    });

    test('evaluateExpr() test not operator', () {
      final expr = {
        'not': [
          {"var": "age"},
        ],
      };
      var vars = {'age': 0};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));

      vars = {'age': 1};

      result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(false));
    });

    test('evaluateExpr() test in operator', () {
      final expr = {
        'in': [
          {"var": "value"},
          {"value": "am"}
        ],
      };
      Map<String, dynamic> vars = {'value': "Hamza"};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));

      vars = {
        "value": {"am": "name"}
      };
      result = JsonExpr().evaluateExpr(expr, vars);

      expect(result, equals(true));
    });

    test('evaluateExpr() test null operator', () {
      final expr = {
        'null': null,
      };
      var vars = {'age': null};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));
    });

    test('evaluateExpr() test match operator', () {
      final expr = {
        'match': [
          {"var": "email"},
          {"value": r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"}
        ],
      };
      var vars = {'email': "test@test.com"};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));
    });

    test('evaluateExpr() test value operator', () {
      final expr = {
        'value': 42,
      };
      Map<String, dynamic> vars = {};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(42));
    });

    test('evaluateExpr() test var operator', () {
      final expr = {
        'var': "path",
      };
      var vars = {'path': true};
      var result = JsonExpr().evaluateExpr(expr, vars);
      expect(result, equals(true));
    });
  });

  // Unit tests for individual operators
  group('AndCombinator Tests', () {
    late MockEvaluator evaluator;
    late AndCombinator combinator;

    setUp(() {
      evaluator = MockEvaluator();
      combinator = AndCombinator();

      when(evaluator.evaluate(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
      when(evaluator.booleanConvert(any)).thenAnswer((invocation) {
        final arg = invocation.positionalArguments[0];
        return arg ?? false;
      });
    });

    test('testCombineTrue', () {
      when(evaluator.booleanConvert(true)).thenReturn(true);

      final result = combinator.combine(evaluator, [true]);

      expect(result, equals(true));
      verify(evaluator.booleanConvert(true)).called(1);
      verify(evaluator.evaluate(true)).called(1);
    });

    test('testCombineFalse', () {
      when(evaluator.booleanConvert(false)).thenReturn(false);

      final result = combinator.combine(evaluator, [false]);

      expect(result, equals(false));
      verify(evaluator.booleanConvert(false)).called(1);
      verify(evaluator.evaluate(false)).called(1);
    });

    test('testCombineNull', () {
      when(evaluator.booleanConvert(null)).thenReturn(false);

      final result = combinator.combine(evaluator, [null]);

      expect(result, equals(false));
      verify(evaluator.booleanConvert(null)).called(1);
      verify(evaluator.evaluate(null)).called(1);
    });

    test('testCombineShortCircuit', () {
      when(evaluator.booleanConvert(true)).thenReturn(true);
      when(evaluator.booleanConvert(false)).thenReturn(false);

      final result = combinator.combine(evaluator, [true, false, true]);

      expect(result, equals(false));
      verify(evaluator.booleanConvert(true)).called(1);
      verify(evaluator.evaluate(true)).called(1);
      verify(evaluator.booleanConvert(false)).called(1);
      verify(evaluator.evaluate(false)).called(1);
      verifyNever(evaluator.evaluate(true));
    });

    test('testCombine', () {
      when(evaluator.booleanConvert(true)).thenReturn(true);
      when(evaluator.booleanConvert(false)).thenReturn(false);

      expect(combinator.combine(evaluator, [true, true]), equals(true));
      expect(combinator.combine(evaluator, [true, true, true]), equals(true));
      expect(combinator.combine(evaluator, [true, false]), equals(false));
      expect(combinator.combine(evaluator, [false, true]), equals(false));
      expect(combinator.combine(evaluator, [false, false]), equals(false));
      expect(
          combinator.combine(evaluator, [false, false, false]), equals(false));
    });
  });

  group('EqualsOperator Tests', () {
    late MockEvaluator evaluator;
    late EqualsOperator operator;

    setUp(() {
      evaluator = MockEvaluator();
      operator = EqualsOperator();

      when(evaluator.evaluate(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
    });

    test('testEvaluate', () {
      when(evaluator.compare(0, 0)).thenReturn(0);
      when(evaluator.compare(1, 0)).thenReturn(1);
      when(evaluator.compare(0, 1)).thenReturn(-1);

      expect(operator.evaluate(evaluator, [0, 0]), equals(true));
      verify(evaluator.evaluate(0)).called(2);
      verify(evaluator.compare(0, 0)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [1, 0]), equals(false));
      verify(evaluator.evaluate(1)).called(1);
      verify(evaluator.evaluate(0)).called(1);
      verify(evaluator.compare(1, 0)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [0, 1]), equals(false));
      verify(evaluator.evaluate(0)).called(1);
      verify(evaluator.evaluate(1)).called(1);
      verify(evaluator.compare(0, 1)).called(1);

      clearInteractions(evaluator);

      when(evaluator.evaluate(null)).thenReturn(null);
      expect(operator.evaluate(evaluator, [null, null]), equals(null));
      verify(evaluator.evaluate(null)).called(1);
      verifyNever(evaluator.compare(any, any));

      clearInteractions(evaluator);

      final list1 = [1, 2];
      final list2 = [2, 3];
      when(evaluator.compare(list1, list1)).thenReturn(0);
      when(evaluator.compare(list1, list2)).thenReturn(null);

      expect(operator.evaluate(evaluator, [list1, list1]), equals(true));
      verify(evaluator.evaluate(list1)).called(2);
      verify(evaluator.compare(list1, list1)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [list1, list2]), equals(null));
      verify(evaluator.evaluate(list1)).called(1);
      verify(evaluator.evaluate(list2)).called(1);
      verify(evaluator.compare(list1, list2)).called(1);

      clearInteractions(evaluator);

      final map1 = {"a": 1, "b": 2};
      final map2 = {"a": 3, "b": 4};
      when(evaluator.compare(map1, map1)).thenReturn(0);
      when(evaluator.compare(map1, map2)).thenReturn(null);

      expect(operator.evaluate(evaluator, [map1, map1]), equals(true));
      verify(evaluator.evaluate(map1)).called(2);
      verify(evaluator.compare(map1, map1)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [map1, map2]), equals(null));
      verify(evaluator.evaluate(map1)).called(1);
      verify(evaluator.evaluate(map2)).called(1);
      verify(evaluator.compare(map1, map2)).called(1);
    });
  });

  group('GreaterThanOperator Tests', () {
    late MockEvaluator evaluator;
    late GreaterThenOperator operator;

    setUp(() {
      evaluator = MockEvaluator();
      operator = GreaterThenOperator();

      when(evaluator.evaluate(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
    });

    test('testEvaluate', () {
      when(evaluator.compare(0, 0)).thenReturn(0);
      when(evaluator.compare(1, 0)).thenReturn(1);
      when(evaluator.compare(0, 1)).thenReturn(-1);

      expect(operator.evaluate(evaluator, [0, 0]), equals(false));
      verify(evaluator.evaluate(0)).called(2);
      verify(evaluator.compare(0, 0)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [1, 0]), equals(true));
      verify(evaluator.evaluate(1)).called(1);
      verify(evaluator.evaluate(0)).called(1);
      verify(evaluator.compare(1, 0)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [0, 1]), equals(false));
      verify(evaluator.evaluate(0)).called(1);
      verify(evaluator.evaluate(1)).called(1);
      verify(evaluator.compare(0, 1)).called(1);

      clearInteractions(evaluator);

      when(evaluator.evaluate(null)).thenReturn(null);
      expect(operator.evaluate(evaluator, [null, null]), equals(null));
      verify(evaluator.evaluate(null)).called(1);
      verifyNever(evaluator.compare(any, any));
    });
  });

  group('GreaterThanOrEqualOperator Tests', () {
    late MockEvaluator evaluator;
    late GreaterThenOrEqualOperator operator;

    setUp(() {
      evaluator = MockEvaluator();
      operator = GreaterThenOrEqualOperator();

      when(evaluator.evaluate(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
    });

    test('testEvaluate', () {
      when(evaluator.compare(0, 0)).thenReturn(0);
      when(evaluator.compare(1, 0)).thenReturn(1);
      when(evaluator.compare(0, 1)).thenReturn(-1);

      expect(operator.evaluate(evaluator, [0, 0]), equals(true));
      verify(evaluator.evaluate(0)).called(2);
      verify(evaluator.compare(0, 0)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [1, 0]), equals(true));
      verify(evaluator.evaluate(1)).called(1);
      verify(evaluator.evaluate(0)).called(1);
      verify(evaluator.compare(1, 0)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [0, 1]), equals(false));
      verify(evaluator.evaluate(0)).called(1);
      verify(evaluator.evaluate(1)).called(1);
      verify(evaluator.compare(0, 1)).called(1);

      clearInteractions(evaluator);

      when(evaluator.evaluate(null)).thenReturn(null);
      expect(operator.evaluate(evaluator, [null, null]), equals(null));
      verify(evaluator.evaluate(null)).called(1);
      verifyNever(evaluator.compare(any, any));
    });
  });

  group('InOperator Tests', () {
    late MockEvaluator evaluator;
    late InOperator operator;

    setUp(() {
      evaluator = MockEvaluator();
      operator = InOperator();

      when(evaluator.evaluate(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
    });

    test('testString', () {
      when(evaluator.stringConvert("abc")).thenReturn("abc");
      when(evaluator.stringConvert("def")).thenReturn("def");
      when(evaluator.stringConvert("xxx")).thenReturn("xxx");

      expect(
          operator.evaluate(evaluator, ["abcdefghijk", "abc"]), equals(true));
      expect(
          operator.evaluate(evaluator, ["abcdefghijk", "def"]), equals(true));
      expect(
          operator.evaluate(evaluator, ["abcdefghijk", "xxx"]), equals(false));

      when(evaluator.evaluate(null)).thenReturn(null);
      expect(operator.evaluate(evaluator, ["abcdefghijk", null]), equals(null));
      expect(operator.evaluate(evaluator, [null, "abc"]), equals(null));

      verify(evaluator.evaluate("abcdefghijk")).called(4);
      verify(evaluator.evaluate("abc")).called(1);
      verify(evaluator.evaluate("def")).called(1);
      verify(evaluator.evaluate("xxx")).called(1);

      verify(evaluator.stringConvert("abc")).called(1);
      verify(evaluator.stringConvert("def")).called(1);
      verify(evaluator.stringConvert("xxx")).called(1);
    });

    test('testArrayEmpty', () {
      expect(operator.evaluate(evaluator, [[], 1]), equals(false));
      expect(operator.evaluate(evaluator, [[], "1"]), equals(false));
      expect(operator.evaluate(evaluator, [[], true]), equals(false));
      expect(operator.evaluate(evaluator, [[], false]), equals(false));

      when(evaluator.evaluate(null)).thenReturn(null);
      expect(operator.evaluate(evaluator, [[], null]), equals(null));

      verifyNever(evaluator.booleanConvert(any));
      verifyNever(evaluator.numberConvert(any));
      verifyNever(evaluator.stringConvert(any));
      verifyNever(evaluator.compare(any, any));
    });

    test('testArrayCompares', () {
      final haystack01 = [0, 1];
      final haystack12 = [1, 2];

      when(evaluator.compare(0, 2)).thenReturn(-1);
      when(evaluator.compare(1, 2)).thenReturn(-1);
      when(evaluator.compare(1, 0)).thenReturn(1);
      when(evaluator.compare(2, 0)).thenReturn(1);
      when(evaluator.compare(1, 1)).thenReturn(0);
      when(evaluator.compare(2, 2)).thenReturn(0);

      expect(operator.evaluate(evaluator, [haystack01, 2]), equals(false));
      verify(evaluator.evaluate(haystack01)).called(1);
      verify(evaluator.evaluate(2)).called(1);
      verify(evaluator.compare(0, 2)).called(1);
      verify(evaluator.compare(1, 2)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [haystack12, 0]), equals(false));
      verify(evaluator.evaluate(haystack12)).called(1);
      verify(evaluator.evaluate(0)).called(1);
      verify(evaluator.compare(1, 0)).called(1);
      verify(evaluator.compare(2, 0)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [haystack12, 1]), equals(true));
      verify(evaluator.evaluate(haystack12)).called(1);
      verify(evaluator.evaluate(1)).called(1);
      verify(evaluator.compare(1, 1)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [haystack12, 2]), equals(true));
      verify(evaluator.evaluate(haystack12)).called(1);
      verify(evaluator.evaluate(2)).called(1);
      verify(evaluator.compare(1, 2)).called(1);
      verify(evaluator.compare(2, 2)).called(1);
    });

    test('testObject', () {
      final haystackab = {"a": 1, "b": 2};
      final haystackbc = {"b": 2, "c": 3, "0": 100};

      when(evaluator.stringConvert("a")).thenReturn("a");
      when(evaluator.stringConvert("b")).thenReturn("b");
      when(evaluator.stringConvert("c")).thenReturn("c");
      when(evaluator.stringConvert(0)).thenReturn("0");

      expect(operator.evaluate(evaluator, [haystackab, "c"]), equals(false));
      verify(evaluator.evaluate(haystackab)).called(1);
      verify(evaluator.stringConvert("c")).called(1);
      verify(evaluator.evaluate("c")).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [haystackbc, "a"]), equals(false));
      verify(evaluator.evaluate(haystackbc)).called(1);
      verify(evaluator.stringConvert("a")).called(1);
      verify(evaluator.evaluate("a")).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [haystackbc, "b"]), equals(true));
      verify(evaluator.evaluate(haystackbc)).called(1);
      verify(evaluator.stringConvert("b")).called(1);
      verify(evaluator.evaluate("b")).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [haystackbc, "c"]), equals(true));
      verify(evaluator.evaluate(haystackbc)).called(1);
      verify(evaluator.stringConvert("c")).called(1);
      verify(evaluator.evaluate("c")).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [haystackbc, 0]), equals(true));
      verify(evaluator.evaluate(haystackbc)).called(1);
      verify(evaluator.stringConvert(0)).called(1);
      verify(evaluator.evaluate(0)).called(1);
    });
  });

  group('LessThanOperator Tests', () {
    late MockEvaluator evaluator;
    late LessThenOperator operator;

    setUp(() {
      evaluator = MockEvaluator();
      operator = LessThenOperator();

      when(evaluator.evaluate(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
    });

    test('testEvaluate', () {
      when(evaluator.compare(0, 0)).thenReturn(0);
      when(evaluator.compare(1, 0)).thenReturn(1);
      when(evaluator.compare(0, 1)).thenReturn(-1);

      expect(operator.evaluate(evaluator, [0, 0]), equals(false));
      verify(evaluator.evaluate(0)).called(2);
      verify(evaluator.compare(0, 0)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [1, 0]), equals(false));
      verify(evaluator.evaluate(1)).called(1);
      verify(evaluator.evaluate(0)).called(1);
      verify(evaluator.compare(1, 0)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [0, 1]), equals(true));
      verify(evaluator.evaluate(0)).called(1);
      verify(evaluator.evaluate(1)).called(1);
      verify(evaluator.compare(0, 1)).called(1);

      clearInteractions(evaluator);

      when(evaluator.evaluate(null)).thenReturn(null);
      expect(operator.evaluate(evaluator, [null, null]), equals(null));
      verify(evaluator.evaluate(null)).called(1);
      verifyNever(evaluator.compare(any, any));
    });
  });

  group('LessThanOrEqualOperator Tests', () {
    late MockEvaluator evaluator;
    late LessThenOrEqualOperator operator;

    setUp(() {
      evaluator = MockEvaluator();
      operator = LessThenOrEqualOperator();

      when(evaluator.evaluate(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
    });

    test('testEvaluate', () {
      when(evaluator.compare(0, 0)).thenReturn(0);
      when(evaluator.compare(1, 0)).thenReturn(1);
      when(evaluator.compare(0, 1)).thenReturn(-1);

      expect(operator.evaluate(evaluator, [0, 0]), equals(true));
      verify(evaluator.evaluate(0)).called(2);
      verify(evaluator.compare(0, 0)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [1, 0]), equals(false));
      verify(evaluator.evaluate(1)).called(1);
      verify(evaluator.evaluate(0)).called(1);
      verify(evaluator.compare(1, 0)).called(1);

      clearInteractions(evaluator);

      expect(operator.evaluate(evaluator, [0, 1]), equals(true));
      verify(evaluator.evaluate(0)).called(1);
      verify(evaluator.evaluate(1)).called(1);
      verify(evaluator.compare(0, 1)).called(1);

      clearInteractions(evaluator);

      when(evaluator.evaluate(null)).thenReturn(null);
      expect(operator.evaluate(evaluator, [null, null]), equals(null));
      verify(evaluator.evaluate(null)).called(1);
      verifyNever(evaluator.compare(any, any));
    });
  });

  group('MatchOperator Tests', () {
    late MockEvaluator evaluator;
    late MatchOperator operator;

    setUp(() {
      evaluator = MockEvaluator();
      operator = MatchOperator();

      when(evaluator.evaluate(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
      when(evaluator.stringConvert(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
    });

    test('testEvaluate', () {
      expect(operator.evaluate(evaluator, ["abcdefghijk", ""]), equals(true));
      expect(
          operator.evaluate(evaluator, ["abcdefghijk", "abc"]), equals(true));
      expect(
          operator.evaluate(evaluator, ["abcdefghijk", "ijk"]), equals(true));
      expect(
          operator.evaluate(evaluator, ["abcdefghijk", "^abc"]), equals(true));
      expect(operator.evaluate(evaluator, [",l5abcdefghijk", "ijk\$"]),
          equals(true));
      expect(
          operator.evaluate(evaluator, ["abcdefghijk", "def"]), equals(true));
      expect(
          operator.evaluate(evaluator, ["abcdefghijk", "b.*j"]), equals(true));
      expect(
          operator.evaluate(evaluator, ["abcdefghijk", "xyz"]), equals(false));

      when(evaluator.evaluate(null)).thenReturn(null);
      expect(operator.evaluate(evaluator, [null, "abc"]), equals(null));
      expect(operator.evaluate(evaluator, ["abcdefghijk", null]), equals(null));
    });
  });

  group('NotOperator Tests', () {
    late MockEvaluator evaluator;
    late NotOperator operator;

    setUp(() {
      evaluator = MockEvaluator();

      when(evaluator.evaluate(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
    });

    test('testFalse', () {
      operator = NotOperator();
      when(evaluator.booleanConvert(false)).thenReturn(false);

      expect(operator.evaluate(evaluator, false), equals(true));
      verify(evaluator.evaluate(false)).called(1);
      verify(evaluator.booleanConvert(false)).called(1);
    });

    test('testTrue', () {
      operator = NotOperator();
      when(evaluator.booleanConvert(true)).thenReturn(true);

      expect(operator.evaluate(evaluator, true), equals(false));
      verify(evaluator.evaluate(true)).called(1);
      verify(evaluator.booleanConvert(true)).called(1);
    });

    test('testNull', () {
      operator = NotOperator();
      when(evaluator.booleanConvert(null)).thenReturn(false);

      expect(operator.evaluate(evaluator, null), equals(true));
      verify(evaluator.evaluate(null)).called(1);
      verify(evaluator.booleanConvert(null)).called(1);
    });
  });

  group('NullOperator Tests', () {
    late MockEvaluator evaluator;
    late NullOperator operator;

    setUp(() {
      evaluator = MockEvaluator();
      operator = NullOperator();

      when(evaluator.evaluate(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
    });

    test('testNull', () {
      when(evaluator.evaluate(null)).thenReturn(null);

      expect(operator.evaluate(evaluator, null), equals(true));
      verify(evaluator.evaluate(null)).called(1);
    });

    test('testNotNull', () {
      expect(operator.evaluate(evaluator, true), equals(false));
      verify(evaluator.evaluate(true)).called(1);

      expect(operator.evaluate(evaluator, false), equals(false));
      verify(evaluator.evaluate(false)).called(1);

      expect(operator.evaluate(evaluator, 0), equals(false));
      verify(evaluator.evaluate(0)).called(1);
    });
  });

  group('OrCombinator Tests', () {
    late MockEvaluator evaluator;
    late OrCombinator combinator;

    setUp(() {
      evaluator = MockEvaluator();
      combinator = OrCombinator();

      when(evaluator.evaluate(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0]);
      when(evaluator.booleanConvert(any)).thenAnswer((invocation) {
        final arg = invocation.positionalArguments[0];
        return arg ?? false;
      });
    });

    test('testCombineTrue', () {
      when(evaluator.booleanConvert(true)).thenReturn(true);

      final result = combinator.combine(evaluator, [true]);

      expect(result, equals(true));
      verify(evaluator.booleanConvert(true)).called(1);
      verify(evaluator.evaluate(true)).called(1);
    });

    test('testCombineFalse', () {
      when(evaluator.booleanConvert(false)).thenReturn(false);

      final result = combinator.combine(evaluator, [false]);

      expect(result, equals(false));
      verify(evaluator.booleanConvert(false)).called(1);
      verify(evaluator.evaluate(false)).called(1);
    });

    test('testCombineNull', () {
      when(evaluator.booleanConvert(null)).thenReturn(false);

      final result = combinator.combine(evaluator, [null]);

      expect(result, equals(false));
      verify(evaluator.booleanConvert(null)).called(1);
      verify(evaluator.evaluate(null)).called(1);
    });

    test('testCombineShortCircuit', () {
      when(evaluator.booleanConvert(true)).thenReturn(true);

      final result = combinator.combine(evaluator, [true, false, true]);

      expect(result, equals(true));
      verify(evaluator.booleanConvert(true)).called(1);
      verify(evaluator.evaluate(true)).called(1);

      verifyNever(evaluator.booleanConvert(false));
      verifyNever(evaluator.evaluate(false));
    });

    test('testCombine', () {
      when(evaluator.booleanConvert(true)).thenReturn(true);
      when(evaluator.booleanConvert(false)).thenReturn(false);

      expect(combinator.combine(evaluator, [true, true]), equals(true));
      expect(combinator.combine(evaluator, [true, true, true]), equals(true));
      expect(combinator.combine(evaluator, [true, false]), equals(true));
      expect(combinator.combine(evaluator, [false, true]), equals(true));
      expect(combinator.combine(evaluator, [false, false]), equals(false));
      expect(
          combinator.combine(evaluator, [false, false, false]), equals(false));
    });
  });

  group('ValueOperator Tests', () {
    late MockEvaluator evaluator;
    late ValueOperator operator;

    setUp(() {
      evaluator = MockEvaluator();
      operator = ValueOperator();
    });

    test('testEvaluate', () {
      expect(operator.evaluate(evaluator, 0), equals(0));
      expect(operator.evaluate(evaluator, 1), equals(1));
      expect(operator.evaluate(evaluator, true), equals(true));
      expect(operator.evaluate(evaluator, false), equals(false));
      expect(operator.evaluate(evaluator, ""), equals(""));
      expect(operator.evaluate(evaluator, {}), equals({}));
      expect(operator.evaluate(evaluator, []), equals([]));
      expect(operator.evaluate(evaluator, null), equals(null));

      verifyNever(evaluator.evaluate(any));
    });
  });

  group('VarOperator Tests', () {
    late MockEvaluator evaluator;
    late VarOperator operator;

    setUp(() {
      evaluator = MockEvaluator();
      operator = VarOperator();
    });

    test('testEvaluate', () {
      when(evaluator.extractVar("a/b/c")).thenReturn("abc");

      expect(operator.evaluate(evaluator, "a/b/c"), equals("abc"));

      verify(evaluator.extractVar("a/b/c")).called(1);
      verifyNever(evaluator.evaluate(any));
    });
  });
}
