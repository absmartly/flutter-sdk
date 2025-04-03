import 'package:absmartly_sdk/jsonexpr/expr_evaluator.dart';
import 'package:absmartly_sdk/jsonexpr/operator.mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  test('testEvaluateConsidersListAsAndCombinator', () {
    final andOperator = MockOperator();
    final orOperator = MockOperator();

    when(andOperator.evaluate(any, any)).thenReturn(true);

    final evaluator = ExprEvaluator({'and': andOperator, 'or': orOperator}, {});

    final args = [
      {'value': true},
      {'value': false}
    ];
    expect(evaluator.evaluate(args), isNotNull);

    verifyNever(orOperator.evaluate(any, any));
    verify(andOperator.evaluate(any, args)).called(1);
  });

  test('testEvaluateReturnsNullIfOperatorNotFound', () {
    final valueOperator = MockOperator();

    when(valueOperator.evaluate(any, any)).thenReturn(true);

    final evaluator = ExprEvaluator({'value': valueOperator}, {});
    expect(evaluator.evaluate({'not_found': true}), isNull);

    verifyNever(valueOperator.evaluate(any, any));
  });

  test('testEvaluateCallsOperatorWithArgs', () {
    final valueOperator = MockOperator();

    final args = [1, 2, 3];

    when(valueOperator.evaluate(any, args)).thenReturn(args);

    final evaluator = ExprEvaluator({'value': valueOperator}, {});
    expect(evaluator.evaluate({'value': args}), equals(args));

    verify(valueOperator.evaluate(any, args)).called(1);
  });

  test('testBooleanConvert', () {
    final evaluator = ExprEvaluator({}, {});

    expect(evaluator.booleanConvert({}), isTrue);
    expect(evaluator.booleanConvert([]), isTrue);
    expect(evaluator.booleanConvert(null), isFalse);

    expect(evaluator.booleanConvert(true), isTrue);
    expect(evaluator.booleanConvert(1), isTrue);
    expect(evaluator.booleanConvert(2), isTrue);
    expect(evaluator.booleanConvert("abc"), isTrue);
    expect(evaluator.booleanConvert("1"), isTrue);

    expect(evaluator.booleanConvert(false), isFalse);
    expect(evaluator.booleanConvert(0), isFalse);
    expect(evaluator.booleanConvert(""), isFalse);
    expect(evaluator.booleanConvert("0"), isFalse);
    expect(evaluator.booleanConvert("false"), isFalse);
  });

  test('testNumberConvert', () {
    final evaluator = ExprEvaluator({}, {});

    expect(evaluator.numberConvert({}), isNull);
    expect(evaluator.numberConvert([]), isNull);
    expect(evaluator.numberConvert(null), isNull);
    expect(evaluator.numberConvert(""), isNull);
    expect(evaluator.numberConvert("abcd"), isNull);
    expect(evaluator.numberConvert("x1234"), isNull);

    expect(evaluator.numberConvert(true), equals(1.0));
    expect(evaluator.numberConvert(false), equals(0.0));

    expect(evaluator.numberConvert(-1.0), equals(-1.0));
    expect(evaluator.numberConvert(0.0), equals(0.0));
    expect(evaluator.numberConvert(1.0), equals(1.0));
    expect(evaluator.numberConvert(1.5), equals(1.5));
    expect(evaluator.numberConvert(2.0), equals(2.0));
    expect(evaluator.numberConvert(3.0), equals(3.0));

    expect(evaluator.numberConvert(-1), equals(-1.0));
    expect(evaluator.numberConvert(0), equals(0.0));
    expect(evaluator.numberConvert(1), equals(1.0));
    expect(evaluator.numberConvert(2), equals(2.0));
    expect(evaluator.numberConvert(3), equals(3.0));
    expect(evaluator.numberConvert(2147483647), equals(2147483647.0));
    expect(evaluator.numberConvert(-2147483647), equals(-2147483647.0));
    expect(
        evaluator.numberConvert(9007199254740991), equals(9007199254740991.0));
    expect(evaluator.numberConvert(-9007199254740991),
        equals(-9007199254740991.0));

    expect(evaluator.numberConvert("-1"), equals(-1.0));
    expect(evaluator.numberConvert("0"), equals(0.0));
    expect(evaluator.numberConvert("1"), equals(1.0));
    expect(evaluator.numberConvert("1.5"), equals(1.5));
    expect(evaluator.numberConvert("2"), equals(2.0));
    expect(evaluator.numberConvert("3.0"), equals(3.0));
  });

  test('testStringConvert', () {
    final evaluator = ExprEvaluator({}, {});

    expect(evaluator.stringConvert(null), isNull);
    expect(evaluator.stringConvert({}), isNull);
    expect(evaluator.stringConvert([]), isNull);

    expect(evaluator.stringConvert(true), equals("true"));
    expect(evaluator.stringConvert(false), equals("false"));

    expect(evaluator.stringConvert(""), equals(""));
    expect(evaluator.stringConvert("abc"), equals("abc"));

    expect(evaluator.stringConvert(-1.0), equals("-1"));
    expect(evaluator.stringConvert(0.0), equals("0"));
    expect(evaluator.stringConvert(1.0), equals("1"));
    expect(evaluator.stringConvert(1.5), equals("1.5"));
    expect(evaluator.stringConvert(2.0), equals("2"));
    expect(evaluator.stringConvert(3.0), equals("3"));
    expect(evaluator.stringConvert(2147483647.0), equals("2147483647"));
    expect(evaluator.stringConvert(-2147483647.0), equals("-2147483647"));
    expect(evaluator.stringConvert(9007199254740991.0),
        equals("9007199254740991"));
    expect(evaluator.stringConvert(-9007199254740991.0),
        equals("-9007199254740991"));
    expect(evaluator.stringConvert(0.9007199254740991),
        equals("0.900719925474099"));
    expect(evaluator.stringConvert(-0.9007199254740991),
        equals("-0.900719925474099"));

    expect(evaluator.stringConvert(-1), equals("-1"));
    expect(evaluator.stringConvert(0), equals("0"));
    expect(evaluator.stringConvert(1), equals("1"));
    expect(evaluator.stringConvert(2), equals("2"));
    expect(evaluator.stringConvert(3), equals("3"));
    expect(evaluator.stringConvert(2147483647), equals("2147483647"));
    expect(evaluator.stringConvert(-2147483647), equals("-2147483647"));
    expect(
        evaluator.stringConvert(9007199254740991), equals("9007199254740991"));
    expect(evaluator.stringConvert(-9007199254740991),
        equals("-9007199254740991"));
  });

  test('testExtractVar', () {
    final Map<String, Object> vars = {
      'a': 1,
      'b': true,
      'c': false,
      'd': [1, 2, 3],
      'e': [
        1,
        {'z': 2},
        3
      ],
      'f': {
        'y': {'x': 3, '0': 10}
      }
    };

    final evaluator = ExprEvaluator({}, vars);

    expect(evaluator.extractVar("a"), equals(1));
    expect(evaluator.extractVar("b"), equals(true));
    expect(evaluator.extractVar("c"), equals(false));
    expect(evaluator.extractVar("d"), equals([1, 2, 3]));
    expect(
        evaluator.extractVar("e"),
        equals([
          1,
          {'z': 2},
          3
        ]));
    expect(
        evaluator.extractVar("f"),
        equals({
          'y': {'x': 3, '0': 10}
        }));

    expect(evaluator.extractVar("a/0"), isNull);
    expect(evaluator.extractVar("a/b"), isNull);
    expect(evaluator.extractVar("b/0"), isNull);
    expect(evaluator.extractVar("b/e"), isNull);

    expect(evaluator.extractVar("d/0"), equals(1));
    expect(evaluator.extractVar("d/1"), equals(2));
    expect(evaluator.extractVar("d/2"), equals(3));
    expect(evaluator.extractVar("d/3"), isNull);

    expect(evaluator.extractVar("e/0"), equals(1));
    expect(evaluator.extractVar("e/1/z"), equals(2));
    expect(evaluator.extractVar("e/2"), equals(3));
    expect(evaluator.extractVar("e/1/0"), isNull);

    expect(evaluator.extractVar("f/y"), equals({'x': 3, '0': 10}));
    expect(evaluator.extractVar("f/y/x"), equals(3));
    expect(evaluator.extractVar("f/y/0"), equals(10));
  });

  test('testCompareNull', () {
    final evaluator = ExprEvaluator({}, {});

    expect(evaluator.compare(null, null), equals(0));

    expect(evaluator.compare(null, 0), isNull);
    expect(evaluator.compare(null, 1), isNull);
    expect(evaluator.compare(null, true), isNull);
    expect(evaluator.compare(null, false), isNull);
    expect(evaluator.compare(null, ""), isNull);
    expect(evaluator.compare(null, "abc"), isNull);
    expect(evaluator.compare(null, {}), isNull);
    expect(evaluator.compare(null, []), isNull);

    expect(evaluator.compare(0, null), isNull);
    expect(evaluator.compare(1, null), isNull);
    expect(evaluator.compare(true, null), isNull);
    expect(evaluator.compare(false, null), isNull);
    expect(evaluator.compare("", null), isNull);
    expect(evaluator.compare("abc", null), isNull);
    expect(evaluator.compare({}, null), isNull);
    expect(evaluator.compare([], null), isNull);
  });

  test('testCompareObjects', () {
    final evaluator = ExprEvaluator({}, {});

    expect(evaluator.compare({}, 0), isNull);
    expect(evaluator.compare({}, 1), isNull);
    expect(evaluator.compare({}, true), isNull);
    expect(evaluator.compare({}, false), isNull);
    expect(evaluator.compare({}, ""), isNull);
    expect(evaluator.compare({}, "abc"), isNull);
    expect(evaluator.compare({}, {}), equals(0));
    expect(evaluator.compare({'a': 1}, {'a': 1}), equals(0));
    expect(evaluator.compare({'a': 1}, {'b': 2}), isNull);
    expect(evaluator.compare({}, []), isNull);

    expect(evaluator.compare([], 0), isNull);
    expect(evaluator.compare([], 1), isNull);
    expect(evaluator.compare([], true), isNull);
    expect(evaluator.compare([], false), isNull);
    expect(evaluator.compare([], ""), isNull);
    expect(evaluator.compare([], "abc"), isNull);
    expect(evaluator.compare([], {}), isNull);
    expect(evaluator.compare([], []), equals(0));
    expect(evaluator.compare([1, 2], [1, 2]), equals(0));
    expect(evaluator.compare([1, 2], [3, 4]), isNull);
  });

  test('testCompareBooleans', () {
    final evaluator = ExprEvaluator({}, {});

    expect(evaluator.compare(false, 0), equals(0));
    expect(evaluator.compare(false, 1), equals(-1));
    expect(evaluator.compare(false, true), equals(-1));
    expect(evaluator.compare(false, false), equals(0));
    expect(evaluator.compare(false, ""), equals(0));
    expect(evaluator.compare(false, "abc"), equals(-1));
    expect(evaluator.compare(false, {}), equals(-1));
    expect(evaluator.compare(false, []), equals(-1));

    expect(evaluator.compare(true, 0), equals(1));
    expect(evaluator.compare(true, 1), equals(0));
    expect(evaluator.compare(true, true), equals(0));
    expect(evaluator.compare(true, false), equals(1));
    expect(evaluator.compare(true, ""), equals(1));
    expect(evaluator.compare(true, "abc"), equals(0));
    expect(evaluator.compare(true, {}), equals(0));
    expect(evaluator.compare(true, []), equals(0));
  });

  test('testCompareNumbers', () {
    final evaluator = ExprEvaluator({}, {});

    expect(evaluator.compare(0, 0), equals(0));
    expect(evaluator.compare(0, 1), equals(-1));
    expect(evaluator.compare(0, true), equals(-1));
    expect(evaluator.compare(0, false), equals(0));
    expect(evaluator.compare(0, ""), isNull);
    expect(evaluator.compare(0, "abc"), isNull);
    expect(evaluator.compare(0, {}), isNull);
    expect(evaluator.compare(0, []), isNull);

    expect(evaluator.compare(1, 0), equals(1));
    expect(evaluator.compare(1, 1), equals(0));
    expect(evaluator.compare(1, true), equals(0));
    expect(evaluator.compare(1, false), equals(1));
    expect(evaluator.compare(1, ""), isNull);
    expect(evaluator.compare(1, "abc"), isNull);
    expect(evaluator.compare(1, {}), isNull);
    expect(evaluator.compare(1, []), isNull);

    expect(evaluator.compare(1.0, 1), equals(0));
    expect(evaluator.compare(1.5, 1), equals(1));
    expect(evaluator.compare(2.0, 1), equals(1));
    expect(evaluator.compare(3.0, 1), equals(1));

    expect(evaluator.compare(1, 1.0), equals(0));
    expect(evaluator.compare(1, 1.5), equals(-1));
    expect(evaluator.compare(1, 2.0), equals(-1));
    expect(evaluator.compare(1, 3.0), equals(-1));

    expect(evaluator.compare(9007199254740991, 9007199254740991), equals(0));
    expect(evaluator.compare(0, 9007199254740991), equals(-1));
    expect(evaluator.compare(9007199254740991, 0), equals(1));

    expect(
        evaluator.compare(9007199254740991.0, 9007199254740991.0), equals(0));
    expect(evaluator.compare(0.0, 9007199254740991.0), equals(-1));
    expect(evaluator.compare(9007199254740991.0, 0.0), equals(1));
  });

  test('testCompareStrings', () {
    final evaluator = ExprEvaluator({}, {});

    expect(evaluator.compare("", ""), equals(0));
    expect(evaluator.compare("abc", "abc"), equals(0));
    expect(evaluator.compare("0", 0), equals(0));
    expect(evaluator.compare("1", 1), equals(0));
    expect(evaluator.compare("true", true), equals(0));
    expect(evaluator.compare("false", false), equals(0));
    expect(evaluator.compare("", {}), isNull);
    expect(evaluator.compare("abc", {}), isNull);
    expect(evaluator.compare("", []), isNull);
    expect(evaluator.compare("abc", []), isNull);

    expect(evaluator.compare("abc", "bcd"), equals(-1));
    expect(evaluator.compare("bcd", "abc"), equals(1));
    expect(evaluator.compare("0", "1"), equals(-1));
    expect(evaluator.compare("1", "0"), equals(1));
    expect(evaluator.compare("9", "100"), equals(1));
    expect(evaluator.compare("100", "9"), equals(-1));
  });
}
