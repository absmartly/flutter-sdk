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
    final Map<String, dynamic> John = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> Terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> Kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> Maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> AgeTwentyAndUS = [
      binaryOp("eq", varFor("age"), valueFor(20)),
      binaryOp("eq", varFor("language"), valueFor("en-US"))
    ];
    final List<dynamic> AgeOverFifty = [
      binaryOp("gte", varFor("age"), valueFor(50))
    ];

    final List<dynamic> agetwentyandusOrAgeoverfifty = [
      {
        "or": [AgeTwentyAndUS, AgeOverFifty]
      }
    ];

    final List<dynamic> Returning = [varFor("returning")];

    final List<dynamic> returningAndAgetwentyandusOrAgeoverfifty = [
      Returning,
      agetwentyandusOrAgeoverfifty
    ];

    final List<dynamic> notreturningAndSpanish = [
      unaryOp("not", Returning),
      binaryOp("eq", varFor("language"), valueFor("es-ES"))
    ];

    expect(jsonExpr.evaluateBooleanExpr(AgeTwentyAndUS, John), equals(true));
    expect(jsonExpr.evaluateBooleanExpr(AgeTwentyAndUS, Terry), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(AgeTwentyAndUS, Kate), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(AgeTwentyAndUS, Maria), equals(false));
  });

  test('testAgeOverFifty', () {
    final Map<String, dynamic> John = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> Terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> Kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> Maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> AgeOverFifty = [
      binaryOp("gte", varFor("age"), valueFor(50))
    ];

    expect(jsonExpr.evaluateBooleanExpr(AgeOverFifty, John), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(AgeOverFifty, Terry), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(AgeOverFifty, Kate), equals(true));
    expect(jsonExpr.evaluateBooleanExpr(AgeOverFifty, Maria), equals(true));
  });

  test('testAgeTwentyAndUS_Or_AgeOverFifty', () {
    final Map<String, dynamic> John = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> Terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> Kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> Maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> AgeTwentyAndUS = [
      binaryOp("eq", varFor("age"), valueFor(20)),
      binaryOp("eq", varFor("language"), valueFor("en-US"))
    ];
    final List<dynamic> AgeOverFifty = [
      binaryOp("gte", varFor("age"), valueFor(50))
    ];

    final List<dynamic> agetwentyandusOrAgeoverfifty = [
      {
        "or": [AgeTwentyAndUS, AgeOverFifty]
      }
    ];

    expect(jsonExpr.evaluateBooleanExpr(agetwentyandusOrAgeoverfifty, John),
        equals(true));
    expect(jsonExpr.evaluateBooleanExpr(agetwentyandusOrAgeoverfifty, Terry),
        equals(false));
    expect(jsonExpr.evaluateBooleanExpr(agetwentyandusOrAgeoverfifty, Kate),
        equals(true));
    expect(jsonExpr.evaluateBooleanExpr(agetwentyandusOrAgeoverfifty, Maria),
        equals(true));
  });

  test('testReturning', () {
    final Map<String, dynamic> John = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> Terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> Kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> Maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> Returning = [varFor("returning")];

    expect(jsonExpr.evaluateBooleanExpr(Returning, John), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(Returning, Terry), equals(true));
    expect(jsonExpr.evaluateBooleanExpr(Returning, Kate), equals(false));
    expect(jsonExpr.evaluateBooleanExpr(Returning, Maria), equals(true));
  });

  test('testReturning_And_AgeTwentyAndUS_Or_AgeOverFifty', () {
    final Map<String, dynamic> John = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> Terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> Kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> Maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> AgeTwentyAndUS = [
      binaryOp("eq", varFor("age"), valueFor(20)),
      binaryOp("eq", varFor("language"), valueFor("en-US"))
    ];
    final List<dynamic> AgeOverFifty = [
      binaryOp("gte", varFor("age"), valueFor(50))
    ];

    final List<dynamic> agetwentyandusOrAgeoverfifty = [
      {
        "or": [AgeTwentyAndUS, AgeOverFifty]
      }
    ];

    final List<dynamic> Returning = [varFor("returning")];

    final List<dynamic> returningAndAgetwentyandusOrAgeoverfifty = [
      Returning,
      agetwentyandusOrAgeoverfifty
    ];

    expect(
        jsonExpr.evaluateBooleanExpr(
            returningAndAgetwentyandusOrAgeoverfifty, John),
        equals(false));
    expect(
        jsonExpr.evaluateBooleanExpr(
            returningAndAgetwentyandusOrAgeoverfifty, Terry),
        equals(false));
    expect(
        jsonExpr.evaluateBooleanExpr(
            returningAndAgetwentyandusOrAgeoverfifty, Kate),
        equals(false));
    expect(
        jsonExpr.evaluateBooleanExpr(
            returningAndAgetwentyandusOrAgeoverfifty, Maria),
        equals(true));
  });

  test('testNotReturning_And_Spanish', () {
    final Map<String, dynamic> John = {
      "age": 20,
      "language": "en-US",
      "returning": false
    };
    final Map<String, dynamic> Terry = {
      "age": 20,
      "language": "en-GB",
      "returning": true
    };
    final Map<String, dynamic> Kate = {
      "age": 50,
      "language": "es-ES",
      "returning": false
    };
    final Map<String, dynamic> Maria = {
      "age": 52,
      "language": "pt-PT",
      "returning": true
    };

    final JsonExpr jsonExpr = JsonExpr();

    final List<dynamic> Returning = [varFor("returning")];

    final List<dynamic> notreturningAndSpanish = [
      unaryOp("not", Returning),
      binaryOp("eq", varFor("language"), valueFor("es-ES"))
    ];

    expect(jsonExpr.evaluateBooleanExpr(notreturningAndSpanish, John),
        equals(false));
    expect(jsonExpr.evaluateBooleanExpr(notreturningAndSpanish, Terry),
        equals(false));
    expect(jsonExpr.evaluateBooleanExpr(notreturningAndSpanish, Kate),
        equals(true));
    expect(jsonExpr.evaluateBooleanExpr(notreturningAndSpanish, Maria),
        equals(false));
  });
}
