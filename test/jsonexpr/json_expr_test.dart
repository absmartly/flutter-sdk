import 'package:absmartly_sdk/jsonexpr/json_expr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> valueFor(dynamic x) {
    return {"value": x};
  }

  Map<String, dynamic> varFor(dynamic x) {
    return {
      "var": {"path": x}
    };
  }

  Map<String, dynamic> unaryOp(String op, dynamic arg) {
    return {op: arg};
  }

  Map<String, dynamic> binaryOp(String op, dynamic lhs, dynamic rhs) {
    return {
      op: [lhs, rhs]
    };
  }

  test('testAgeTwentyAsUSEnglish', () {
    final Map<String, dynamic> john = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> ageTwentyAndUS = [
      binaryOp("eq", varFor("age"), valueFor(20)),
      binaryOp("eq", varFor("language"), valueFor("en-US"))
    ];
    expect(jsonExpr.evaluateBooleanExpr(ageTwentyAndUS, john), equals(true));
    expect(jsonExpr.evaluateBooleanExpr(ageTwentyAndUS, terry), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(ageTwentyAndUS, kate), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(ageTwentyAndUS, maria), equals(false));
  });

  test('testAgeOverFifty', () {
    final Map<String, dynamic> john = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> ageOverFifty = [
      binaryOp("gte", varFor("age"), valueFor(50))
    ];

    expect(jsonExpr.evaluateBooleanExpr(ageOverFifty, john), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(ageOverFifty, terry), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(ageOverFifty, kate), equals(true));
    expect(jsonExpr.evaluateBooleanExpr(ageOverFifty, maria), equals(true));
  });

  test('testAgeTwentyAndUS_Or_AgeOverFifty', () {
    final Map<String, dynamic> john = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> ageTwentyAndUS = [
      binaryOp("eq", varFor("age"), valueFor(20)),
      binaryOp("eq", varFor("language"), valueFor("en-US"))
    ];
    final List<dynamic> ageOverFifty = [
      binaryOp("gte", varFor("age"), valueFor(50))
    ];

    final List<dynamic> agetwentyandusOrAgeoverfifty = [
      {
        "or": [ageTwentyAndUS, ageOverFifty]
      }
    ];

    expect(jsonExpr.evaluateBooleanExpr(agetwentyandusOrAgeoverfifty, john),
        equals(true));
    expect(jsonExpr.evaluateBooleanExpr(agetwentyandusOrAgeoverfifty, terry),
        equals(false));
    expect(jsonExpr.evaluateBooleanExpr(agetwentyandusOrAgeoverfifty, kate),
        equals(true));
    expect(jsonExpr.evaluateBooleanExpr(agetwentyandusOrAgeoverfifty, maria),
        equals(true));
  });

  test('testReturning', () {
    final Map<String, dynamic> john = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> returning = [varFor("returning")];

    expect(jsonExpr.evaluateBooleanExpr(returning, john), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(returning, terry), equals(true));
    expect(jsonExpr.evaluateBooleanExpr(returning, kate), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(returning, maria), equals(true));
  });

  test('testReturning_And_AgeTwentyAndUS_Or_AgeOverFifty', () {
    final Map<String, dynamic> john = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> ageTwentyAndUS = [
      binaryOp("eq", varFor("age"), valueFor(20)),
      binaryOp("eq", varFor("language"), valueFor("en-US"))
    ];
    final List<dynamic> ageOverFifty = [
      binaryOp("gte", varFor("age"), valueFor(50))
    ];

    final List<dynamic> agetwentyandusOrAgeoverfifty = [
      {
        "or": [ageTwentyAndUS, ageOverFifty]
      }
    ];

    final List<dynamic> returning = [varFor("returning")];

    final List<dynamic> returningAndAgetwentyandusOrAgeoverfifty = [
      returning,
      agetwentyandusOrAgeoverfifty
    ];

    expect(
        jsonExpr.evaluateBooleanExpr(
            returningAndAgetwentyandusOrAgeoverfifty, john),
        equals(false));
    expect(
        jsonExpr.evaluateBooleanExpr(
            returningAndAgetwentyandusOrAgeoverfifty, terry),
        equals(false));
    expect(
        jsonExpr.evaluateBooleanExpr(
            returningAndAgetwentyandusOrAgeoverfifty, kate),
        equals(false));
    expect(
        jsonExpr.evaluateBooleanExpr(
            returningAndAgetwentyandusOrAgeoverfifty, maria),
        equals(true));
  });

  test('testNotReturning_And_Spanish', () {
    final Map<String, dynamic> john = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> returning = [varFor("returning")];

    final List<dynamic> notreturningAndSpanish = [
      unaryOp("not", returning),
      binaryOp("eq", varFor("language"), valueFor("es-ES"))
    ];

    expect(jsonExpr.evaluateBooleanExpr(notreturningAndSpanish, john),
        equals(false));
    expect(jsonExpr.evaluateBooleanExpr(notreturningAndSpanish, terry),
        equals(false));
    expect(jsonExpr.evaluateBooleanExpr(notreturningAndSpanish, kate),
        equals(true));
    expect(jsonExpr.evaluateBooleanExpr(notreturningAndSpanish, maria),
        equals(false));
  });
}
