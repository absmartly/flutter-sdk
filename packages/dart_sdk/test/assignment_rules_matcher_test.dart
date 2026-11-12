import 'dart:convert';

import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/default_audience_deserializer.dart';
import 'package:absmartly_dart/src/jsonexpr/json_expr.dart';
import 'package:test/test.dart';

class _ThrowingOnceJsonExpr extends JsonExpr {
  int calls = 0;

  @override
  bool evaluateBooleanExpr(dynamic expr, Map<String?, dynamic> vars) {
    if (calls++ == 0) {
      throw StateError('condition failed');
    }
    return super.evaluateBooleanExpr(expr, vars);
  }
}

void main() {
  final matcher = AudienceMatcher(DefaultAudienceDeserializer());

  final usCondition = {
    'and': [
      {
        'eq': [
          {'var': 'country'},
          {'value': 'US'}
        ]
      }
    ]
  };

  Map<String, dynamic> assignRule(dynamic variant,
          {String name = 'rule1',
          dynamic conditions,
          bool withConditions = true,
          dynamic environments = const []}) =>
      {
        'name': name,
        'type': 'assign',
        if (withConditions) 'conditions': conditions ?? usCondition,
        'environments': environments,
        'variant': variant,
      };

  String rules(List<dynamic> rules) => jsonEncode({'rules': rules});

  RuleAction? evaluate(List<dynamic> list,
          [String? environment = 'production',
          Map<String, dynamic> attrs = const {'country': 'US'}]) =>
      matcher.evaluateRules(rules(list), environment, attrs);

  group('evaluateRules', () {
    test('returns null when there are no rules', () {
      expect(matcher.evaluateRules('{}', 'production', {}), isNull);
      expect(matcher.evaluateRules('{"filter":[]}', 'production', {}), isNull);
      expect(matcher.evaluateRules('{"rules":[]}', 'production', {}), isNull);
      expect(matcher.evaluateRules('{"rules":{}}', 'production', {}), isNull);
      expect(matcher.evaluateRules('', 'production', {}), isNull);
    });

    test('returns the variant when conditions match', () {
      expect(evaluate([assignRule(1)]), RuleAction.assign(1));
    });

    test('returns null when conditions do not match', () {
      expect(
          evaluate([assignRule(1)], 'production', {'country': 'GB'}), isNull);
    });

    test('skips rules for other environments', () {
      expect(
          evaluate([
            assignRule(1, environments: ['staging'])
          ]),
          isNull);
    });

    test('matches when the environment is listed', () {
      expect(
          evaluate([
            assignRule(1, environments: ['staging', 'production'])
          ]),
          RuleAction.assign(1));
    });

    test('an empty environment list matches every environment', () {
      expect(evaluate([assignRule(1)], null), RuleAction.assign(1));
    });

    test('skips rules with environments when the environment is null', () {
      expect(
          evaluate([
            assignRule(1, environments: ['production'])
          ], null),
          isNull);
    });

    test('environment names are case-sensitive', () {
      expect(
          evaluate([
            assignRule(1, environments: ['Production'])
          ]),
          isNull);
    });

    test('skips rules whose environments is not a list', () {
      expect(
          evaluate([
            assignRule(1, environments: 'production'),
            assignRule(2, name: 'fallback', conditions: null)
          ]),
          RuleAction.assign(2));
    });

    test('a missing environments field matches every environment', () {
      final rule = assignRule(1)..remove('environments');
      expect(evaluate([rule]), RuleAction.assign(1));
    });

    test('first match wins', () {
      expect(
          evaluate([
            assignRule(1),
            assignRule(2, name: 'rule2'),
          ]),
          RuleAction.assign(1));
    });

    test('continues to the next rule when one does not match', () {
      expect(
          evaluate([
            assignRule(1, conditions: {
              'eq': [
                {'var': 'country'},
                {'value': 'GB'}
              ]
            }),
            assignRule(2, name: 'rule2'),
          ]),
          RuleAction.assign(2));
    });

    test('null or absent conditions match everything', () {
      final nullConditions = assignRule(1)..['conditions'] = null;
      expect(
          evaluate([nullConditions], 'production', {}), RuleAction.assign(1));
      expect(evaluate([assignRule(3, withConditions: false)], 'production', {}),
          RuleAction.assign(3));
    });

    test('skips rules with non-map conditions', () {
      expect(
          evaluate([
            assignRule(1, conditions: 'yes'),
            assignRule(1, conditions: [true]),
            assignRule(2, withConditions: false),
          ]),
          RuleAction.assign(2));
    });

    test('handles malformed JSON', () {
      expect(matcher.evaluateRules('{not json', 'production', {}), isNull);
      expect(matcher.evaluateRules('[1,2]', 'production', {}), isNull);
    });

    test('skips malformed rule entries', () {
      expect(evaluate([null, 5, 'rule', assignRule(2, withConditions: false)]),
          RuleAction.assign(2));
    });

    test('skips rules with a missing, non-numeric or fractional variant', () {
      final missing = assignRule(1)..remove('variant');
      expect(evaluate([missing]), isNull);
      expect(evaluate([assignRule('1')]), isNull);
      expect(evaluate([assignRule(1.5)]), isNull);
      expect(
          evaluate([
            missing,
            assignRule('1'),
            assignRule(1.5),
            assignRule(2, name: 'valid'),
          ]),
          RuleAction.assign(2));
    });

    test('accepts a whole-number double variant', () {
      expect(evaluate([assignRule(1.0)]), RuleAction.assign(1));
    });

    test('supports variant 0', () {
      expect(evaluate([assignRule(0)]), RuleAction.assign(0));
    });

    test('returns a negative variant, bounds are checked by the caller', () {
      expect(evaluate([assignRule(-1)]), RuleAction.assign(-1));
    });

    test('skips rules with an unknown or missing type', () {
      final unknown = assignRule(1)..['type'] = 'block';
      final missing = assignRule(1)..remove('type');
      expect(evaluate([unknown, missing]), isNull);
      expect(evaluate([unknown, missing, assignRule(2)]), RuleAction.assign(2));
    });

    test('skips a rule whose conditions throw and continues', () {
      final jsonExpr = _ThrowingOnceJsonExpr();
      final throwing =
          AudienceMatcher(DefaultAudienceDeserializer(), jsonExpr: jsonExpr);
      final result = throwing.evaluateRules(
          rules([
            assignRule(1, conditions: {
              'and': [
                {'value': true}
              ]
            }),
            assignRule(2, name: 'fallback', withConditions: false),
          ]),
          'production',
          {});
      expect(result, RuleAction.assign(2));
      expect(jsonExpr.calls, 1);
    });
  });

  group('split rules', () {
    Map<String, dynamic> splitRule(dynamic percentages) => {
          'name': 'split',
          'type': 'split',
          'conditions': usCondition,
          'environments': [],
          'percentages': percentages,
        };
    final fallbackRule = {
      'name': 'fallback',
      'type': 'assign',
      'environments': [],
      'variant': 2
    };

    test('returns the split as fractions when conditions match', () {
      expect(
          evaluate([splitRule('20/30/50')]), RuleAction.split([0.2, 0.3, 0.5]));
    });

    test('accepts a split whose sum is within the tolerance of 100', () {
      expect(evaluate([splitRule('33.33/33.33/33.33')]),
          RuleAction.split([0.3333, 0.3333, 0.3333]));
    });

    test('returns null when split conditions do not match', () {
      expect(evaluate([splitRule('50/50')], 'production', {'country': 'GB'}),
          isNull);
    });

    test('skips a split with non-string percentages', () {
      expect(
          evaluate([
            splitRule([50, 50]),
            fallbackRule
          ]),
          RuleAction.assign(2));
    });

    test('skips a split with non-numeric percentages', () {
      expect(
          evaluate([splitRule('50/abc'), fallbackRule]), RuleAction.assign(2));
    });

    test('parses percentages like JavaScript parseFloat', () {
      expect(evaluate([splitRule(' 50/50abc')]), RuleAction.split([0.5, 0.5]));
      expect(evaluate([splitRule('/100'), fallbackRule]), RuleAction.assign(2));
    });

    test('skips a split with negative percentages', () {
      expect(
          evaluate([splitRule('150/-50'), fallbackRule]), RuleAction.assign(2));
    });

    test('skips a split whose percentages do not sum to 100', () {
      expect(
          evaluate([splitRule('50/49'), fallbackRule]), RuleAction.assign(2));
    });

    for (final percentages in ['50/50.014', '50/49.986']) {
      test('accepts $percentages, whose gap from 100 rounds to 0.01', () {
        expect(
            evaluate([splitRule(percentages), fallbackRule]),
            RuleAction.split(percentages
                .split('/')
                .map((value) => double.parse(value) / 100)
                .toList()));
      });
    }

    for (final percentages in ['50/50.015', '50/49.985']) {
      test('skips $percentages, whose gap from 100 rounds to 0.02', () {
        expect(evaluate([splitRule(percentages), fallbackRule]),
            RuleAction.assign(2));
      });
    }
  });
}
