import 'dart:math';

import 'package:absmartly_sdk/jsonexpr/json_expr.dart';
import 'package:flutter_test/flutter_test.dart';

// not working

void main(){

  test('evaluateBooleanExpr() returns true for a simple boolean expression', () {
    final expr = {'and': [true, false]};
    final vars = <String, dynamic>{};
    final result = JsonExpr().evaluateBooleanExpr(expr, vars);
    expect(result, equals(false));
  });

  test('evaluateBooleanExpr() returns false for a null operator', () {
    final expr = {null: []};
    final vars = <String?, dynamic>{};

    final result = JsonExpr().evaluateBooleanExpr(expr, vars);
    expect(result, equals(false));
  });

  test('evaluateExpr() returns the value of a variable', () {
    final expr = {'var': 'myVar'};
    final vars = {'myVar': 42};
    final result = JsonExpr().evaluateExpr(expr, vars);
    expect(result, equals(42));
  });
}