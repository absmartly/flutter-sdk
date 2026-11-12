import 'package:absmartly_dart/src/jsonexpr/expr_evaluator.dart';
import 'package:absmartly_dart/src/jsonexpr/json_expr.dart';
import 'package:absmartly_dart/src/jsonexpr/semver_comparator.dart';
import 'package:intl/intl.dart';
import 'package:test/test.dart';

void main() {
  final evaluator = ExprEvaluator({}, {});

  int? cmp(dynamic lhs, dynamic rhs) =>
      SemverComparator.compareValues(evaluator, lhs, rhs);

  group('SemverComparator', () {
    test('equal versions', () {
      expect(cmp('1.0.0', '1.0.0'), 0);
      expect(cmp('0.0.0', '0.0.0'), 0);
      expect(cmp('999.999.999', '999.999.999'), 0);
    });

    test('major, minor and patch', () {
      expect(cmp('2.0.0', '1.0.0'), 1);
      expect(cmp('1.0.0', '2.0.0'), -1);
      expect(cmp('1.2.0', '1.1.0'), 1);
      expect(cmp('1.1.0', '1.2.0'), -1);
      expect(cmp('1.0.2', '1.0.1'), 1);
      expect(cmp('1.0.1', '1.0.2'), -1);
    });

    test('numeric, not lexicographic', () {
      expect(cmp('1.10.0', '1.9.0'), 1);
      expect(cmp('1.9.0', '1.10.0'), -1);
      expect(cmp('10.0.0', '9.0.0'), 1);
    });

    test('missing parts are zero', () {
      expect(cmp('1.2', '1.2.0'), 0);
      expect(cmp('1', '1.0.0'), 0);
      expect(cmp('1.2.0', '1.2'), 0);
      expect(cmp('1.0.0', '1'), 0);
    });

    test('leading zeros', () {
      expect(cmp('1.02.0', '1.2.0'), 0);
      expect(cmp('1.002.030', '1.2.30'), 0);
      expect(cmp('01.0.0', '1.0.0'), 0);
      expect(cmp('1.02.0', '1.3.0'), -1);
      expect(cmp('1.00.0', '1.0.0'), 0);
    });

    test('pre-release', () {
      expect(cmp('1.0.0', '1.0.0-alpha'), 1);
      expect(cmp('1.0.0-alpha', '1.0.0'), -1);
      expect(cmp('1.0.0-alpha', '1.0.0-alpha'), 0);
      expect(cmp('1.0.0-alpha', '1.0.0-beta'), -1);
      expect(cmp('1.0.0-beta', '1.0.0-alpha'), 1);
      expect(cmp('1.0.0-alpha.1', '1.0.0-alpha.2'), -1);
      expect(cmp('1.0.0-alpha.2', '1.0.0-alpha.1'), 1);
      expect(cmp('1.0.0-1', '1.0.0-2'), -1);
      expect(cmp('1.0.0-2', '1.0.0-1'), 1);
      expect(cmp('1.0.0-rc-1', '1.0.0-rc-1'), 0);
    });

    test('numeric pre-release ranks below alphanumeric', () {
      expect(cmp('1.0.0-1', '1.0.0-alpha'), -1);
      expect(cmp('1.0.0-alpha', '1.0.0-1'), 1);
    });

    test('fewer pre-release identifiers is less', () {
      expect(cmp('1.0.0-alpha', '1.0.0-alpha.1'), -1);
      expect(cmp('1.0.0-alpha.1', '1.0.0-alpha'), 1);
    });

    test('v prefix', () {
      expect(cmp('v1.0.0', '1.0.0'), 0);
      expect(cmp('V1.0.0', '1.0.0'), 0);
      expect(cmp('v1.0.0', 'V1.0.0'), 0);
    });

    test('null inputs', () {
      expect(cmp(null, '1.0.0'), isNull);
      expect(cmp('1.0.0', null), isNull);
      expect(cmp(null, null), isNull);
    });

    test('coerces non-strings', () {
      expect(cmp(1, '1.0.0'), 0);
      expect(cmp('1.0.0', 1), 0);
      expect(cmp(true, 'true'), 0);
      expect(cmp(2.5, '2.5.0'), 0);
    });

    test('formats numbers independently of the default locale', () {
      final previous = Intl.defaultLocale;
      Intl.defaultLocale = 'de_DE';
      try {
        expect(cmp(2.5, '2.5.0'), 0);
        expect(cmp(2.5, '2.4'), 1);
      } finally {
        Intl.defaultLocale = previous;
      }
    });

    test('unconvertible inputs', () {
      expect(cmp(<String, dynamic>{}, '1.0.0'), isNull);
      expect(cmp('1.0.0', <String, dynamic>{}), isNull);
      expect(cmp(<dynamic>[], '1.0.0'), isNull);
    });

    test('build metadata is ignored', () {
      expect(cmp('1.0.0+build1', '1.0.0+build2'), 0);
      expect(cmp('1.0.0+build1', '1.0.0'), 0);
      expect(cmp('1.0.0-alpha+build1', '1.0.0-alpha+build2'), 0);
      expect(cmp('1.0.0-alpha+build1', '1.0.0-beta'), -1);
      expect(cmp('1.0.0-alpha+build1', '1.0.0'), -1);
    });

    test('empty inputs', () {
      expect(cmp('', '1.0.0'), isNull);
      expect(cmp('1.0.0', ''), isNull);
      expect(cmp('', ''), isNull);
    });

    test('empty core', () {
      expect(cmp('v', '1.0.0'), isNull);
      expect(cmp('V', '1.0.0'), isNull);
      expect(cmp('+build', '1.0.0'), isNull);
      expect(cmp('v+build', '1.0.0'), isNull);
      expect(cmp('1.0.0', 'v'), isNull);
      expect(cmp('-alpha', '1.0.0'), isNull);
    });
  });

  group('semver operators', () {
    final jsonExpr = JsonExpr();

    dynamic op(String name, dynamic lhs, dynamic rhs) => jsonExpr.evaluateExpr({
          name: [
            {'value': lhs},
            {'value': rhs},
          ]
        }, {});

    test('semver_eq', () {
      expect(op('semver_eq', '1.0.0', 'v1.0'), isTrue);
      expect(op('semver_eq', '1.0.0', '1.0.1'), isFalse);
      expect(op('semver_eq', '', '1.0.0'), isNull);
      expect(op('semver_eq', null, '1.0.0'), isNull);
    });

    test('semver_gt', () {
      expect(op('semver_gt', '1.10.0', '1.9.0'), isTrue);
      expect(op('semver_gt', '1.0.0', '1.0.0'), isFalse);
      expect(op('semver_gt', '1.0.0-alpha', '1.0.0'), isFalse);
      expect(op('semver_gt', 'v', '1.0.0'), isNull);
    });

    test('semver_gte', () {
      expect(op('semver_gte', '1.0.0', '1.0.0'), isTrue);
      expect(op('semver_gte', '1.0.1', '1.0.0'), isTrue);
      expect(op('semver_gte', '1.0.0-rc.1', '1.0.0'), isFalse);
      expect(op('semver_gte', '1.0.0', null), isNull);
    });

    test('semver_lt', () {
      expect(op('semver_lt', '1.0.0-alpha', '1.0.0'), isTrue);
      expect(op('semver_lt', '2.0.0', '1.0.0'), isFalse);
      expect(op('semver_lt', '1.0.0', '1.0.0'), isFalse);
      expect(op('semver_lt', '+build', '1.0.0'), isNull);
    });

    test('semver_lte', () {
      expect(op('semver_lte', '1.0.0', '1.0.0+build'), isTrue);
      expect(op('semver_lte', '1.0.0', '0.9.9'), isFalse);
      expect(op('semver_lte', '1.0.0-1', '1.0.0-alpha'), isTrue);
      expect(op('semver_lte', '1.0.0', ''), isNull);
    });

    test('evaluates against a variable in an audience filter', () {
      final filter = [
        {
          'semver_gte': [
            {'var': 'app_version'},
            {'value': '2.4.0'},
          ]
        }
      ];
      expect(
          jsonExpr.evaluateBooleanExpr(
              filter, <String, dynamic>{'app_version': '2.4.1'}),
          isTrue);
      expect(
          jsonExpr.evaluateBooleanExpr(
              filter, <String, dynamic>{'app_version': '2.3.9'}),
          isFalse);
      expect(
          jsonExpr.evaluateBooleanExpr(filter, <String, dynamic>{}), isFalse);
    });
  });
}
