import 'dart:math';

import 'dart:math';

import 'dart:math';

import 'package:absmartly_sdk/jsonexpr/evaluator.dart';
import 'package:absmartly_sdk/jsonexpr/evaluator.mocks.dart';
import 'package:absmartly_sdk/jsonexpr/expr_evaluator.dart';
import 'package:absmartly_sdk/jsonexpr/operator.dart';
import 'package:absmartly_sdk/jsonexpr/operator.mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main(){
  var EMPTY_MAP = {};
  var EMPTY_LIST = [];
  final Evaluator ev = MockEvaluator();
  test("testEvaluateConsidersListAsAndCombinator", (){
    final Operator andOperator = MockOperator();
    final Operator orOperator = MockOperator();

    // when(andOperator.evaluate(ev, null)).thenReturn(true);

    final ExprEvaluator evaluator = ExprEvaluator({"and": andOperator, "or": orOperator}, {});

    final List<dynamic> args = [{"value": true}, {"value": false}];


    
  });

  

  test("testEvaluateReturnsNullIfOperatorNotFound", (){
    final Operator valueOperator = MockOperator();

    final ExprEvaluator evaluator = ExprEvaluator({"value": valueOperator}, {});
    expect(evaluator.evaluate({"not_found": true}), null);

  });
  


  test("testBooleanConvert", (){
    final ExprEvaluator evaluator = ExprEvaluator({}, {});

    expect(evaluator.booleanConvert(EMPTY_MAP), true);
    expect(evaluator.booleanConvert(EMPTY_LIST), true);
    expect(evaluator.booleanConvert(null), false);

    expect(evaluator.booleanConvert(true), true);
    expect(evaluator.booleanConvert(1), true);
    expect(evaluator.booleanConvert(2), true);
    expect(evaluator.booleanConvert("abc"), true);
    expect(evaluator.booleanConvert("1"), true);

    expect(evaluator.booleanConvert(false), false);
    expect(evaluator.booleanConvert(0), false);
    expect(evaluator.booleanConvert(""), false);
    expect(evaluator.booleanConvert("0"), false);
    expect(evaluator.booleanConvert("false"), false);
  });


  test("testCompareNull", (){
    final ExprEvaluator evaluator = ExprEvaluator({}, {});

    expect(evaluator.compare(null, null), 0);

    expect(evaluator.compare(null, 0), null);
    expect(evaluator.compare(null, 1), null);
    expect(evaluator.compare(null, true), null);
    expect(evaluator.compare(null, false), null);
    expect(evaluator.compare(null, ""), null);
    expect(evaluator.compare(null, "abc"), null);
    expect(evaluator.compare(null, EMPTY_MAP), null);
    expect(evaluator.compare(null, EMPTY_LIST), null);

    expect(evaluator.compare(0, null), null);
    expect(evaluator.compare(1, null), null);
    expect(evaluator.compare(true, null), null);
    expect(evaluator.compare(false, null), null);
    expect(evaluator.compare("", null), null);
    expect(evaluator.compare("abc", null), null);
    expect(evaluator.compare(EMPTY_MAP, null), null);
    expect(evaluator.compare(EMPTY_LIST, null), null);
  });

  test('test booleanConvert with a boolean input', () {
    final operators = <String, Operator>{};
    final vars = <String, dynamic>{};
    final evaluator = ExprEvaluator(operators, vars);
    final result = evaluator.booleanConvert(true);
    expect(result, true);
  });

  test('test booleanConvert with a string input', () {
    final operators = <String, Operator>{};
    final vars = <String, dynamic>{};
    final evaluator = ExprEvaluator(operators, vars);
    final result = evaluator.booleanConvert("true");
    expect(result, true);
  });

  test('test numberConvert with a number input', () {
    final operators = <String, Operator>{};
    final vars = <String, dynamic>{};
    final evaluator = ExprEvaluator(operators, vars);
    final result = evaluator.numberConvert(3);
    expect(result, 3);
  });



}