import 'dart:convert';

import 'package:collection/collection.dart';

import 'audience_deserializer.dart';
import 'jsonexpr/json_expr.dart';

class AudienceMatcher {
  AudienceMatcher(this.deserializer_, {JsonExpr? jsonExpr}) {
    jsonExpr_ = jsonExpr ?? JsonExpr();
  }

  Result? evaluate(String audience, Map<String, dynamic>? attributes) {
    if (audience.isEmpty || audience == 'null' || audience == '{}') {
      return null;
    }

    try {
      final bytes = utf8.encode(audience);
      final audienceMap = deserializer_.deserialize(bytes, 0, bytes.length);
      if (audienceMap != null) {
        final filter = audienceMap['filter'];
        if (filter is Map || filter is List) {
          return Result(
              jsonExpr_.evaluateBooleanExpr(filter, attributes ?? {}));
        }
      }
    } on FormatException {
      // Handle invalid JSON
      return null;
    } catch (e) {
      // Silently handle any other errors
    }

    return null;
  }

  final AudienceDeserializer deserializer_;
  late final JsonExpr jsonExpr_;
}

/// Assignment rule evaluation. An extension rather than members of
/// [AudienceMatcher], so existing `implements AudienceMatcher` classes keep
/// compiling.
extension AssignmentRulesMatcher on AudienceMatcher {
  /// Returns the action of the first rule in [assignmentRules] that applies to
  /// [environmentName] and whose conditions match [attributes], or null when
  /// none does. Malformed rules are skipped. An assign variant is not bounds
  /// checked here; that is the caller's job.
  RuleAction? evaluateRules(String assignmentRules, String? environmentName,
      Map<String, dynamic>? attributes) {
    final List? rules = parseRules(assignmentRules);
    return rules != null
        ? evaluateParsedRules(rules, environmentName, attributes)
        : null;
  }

  // JS AudienceMatcher.parseRules.
  List? parseRules(String assignmentRules) {
    final dynamic parsed;
    try {
      final bytes = utf8.encode(assignmentRules);
      parsed = deserializer_.deserialize(bytes, 0, bytes.length);
    } catch (_) {
      return null;
    }

    if (parsed is! Map || parsed['rules'] is! List) {
      return null;
    }
    return parsed['rules'] as List;
  }

  // JS AudienceMatcher.evaluateParsedRules.
  RuleAction? evaluateParsedRules(
      List rules, String? environmentName, Map<String, dynamic>? attributes) {
    for (final rule in rules) {
      if (rule is! Map) continue;

      final action = _parseRuleAction(rule);
      if (action == null) continue;

      final environments = rule['environments'];
      if (environments != null) {
        if (environments is! List) continue;

        if (environments.isNotEmpty &&
            (environmentName == null ||
                !environments.contains(environmentName))) {
          continue;
        }
      }

      final conditions = rule['conditions'];
      if (conditions == null) {
        return action;
      }

      if (conditions is! Map) continue;

      try {
        if (jsonExpr_.evaluateBooleanExpr(conditions, attributes ?? {})) {
          return action;
        }
      } catch (_) {
        // A rule whose conditions fail to evaluate does not match.
      }
    }

    return null;
  }

  static RuleAction? _parseRuleAction(Map rule) {
    switch (rule['type']) {
      case 'assign':
        final variant = rule['variant'];
        if (variant is int) {
          return RuleAction.assign(variant);
        }
        // JSON has a single number type, so 1.0 is the integer 1
        // (JS Number.isInteger). An integral value beyond the int range (1e20)
        // is still selected: toInt() saturates, so it stays out of bounds and
        // the caller falls back to normal assignment instead of trying later
        // rules, as JS does.
        if (variant is double &&
            variant.isFinite &&
            variant == variant.truncateToDouble()) {
          return RuleAction.assign(variant.toInt());
        }
        return null;
      case 'split':
        final split = _parseSplitPercentages(rule['percentages']);
        return split != null ? RuleAction.split(split) : null;
      default:
        return null;
    }
  }
}

// Accepts gaps from 100 that round to 0.01 or less at two decimals, the same
// check the backend applies to the experiment split.
const double _splitPercentagesSumTolerance = 0.01;

List<double>? _parseSplitPercentages(dynamic percentages) {
  if (percentages is! String) return null;

  final values = percentages.split('/').map(_parseFloat).toList();
  if (values.any((value) => value.isNaN || value < 0)) return null;

  final total = values.fold<double>(0, (sum, value) => sum + value);
  final gap = double.parse((100 - total).abs().toStringAsFixed(2));
  if (gap > _splitPercentagesSumTolerance) return null;

  return values.map((value) => value / 100).toList();
}

// ECMAScript WhiteSpace and LineTerminator, the characters parseFloat skips.
// Dart's trimLeft() also strips U+0085, which JS does not.
final RegExp _leadingWhiteSpace =
    RegExp('^[\t\n\v\f\r \u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F'
        '\u3000\uFEFF]+');

final RegExp _floatPrefix =
    RegExp(r'^[+-]?(Infinity|(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)');

// JS parseFloat: leading whitespace is skipped and the longest numeric prefix
// is parsed, so "50abc" is 50 and "abc" is NaN.
double _parseFloat(String value) {
  final match =
      _floatPrefix.firstMatch(value.replaceFirst(_leadingWhiteSpace, ''));
  if (match == null) return double.nan;
  final text = match.group(0)!;
  if (text.endsWith('Infinity')) {
    return text.startsWith('-') ? double.negativeInfinity : double.infinity;
  }
  return double.parse(text);
}

/// The outcome of a matched assignment rule: a fixed [variant] for an assign
/// rule, or the variant [split] (fractions summing to 1) for a split rule.
class RuleAction {
  RuleAction.assign(int this.variant) : split = null;

  RuleAction.split(List<double> this.split) : variant = null;

  final int? variant;
  final List<double>? split;

  @override
  bool operator ==(Object other) =>
      other is RuleAction &&
      variant == other.variant &&
      const ListEquality<double>().equals(split, other.split);

  @override
  int get hashCode =>
      Object.hash(variant, const ListEquality<double>().hash(split));

  @override
  String toString() => variant != null
      ? 'RuleAction{variant=$variant}'
      : 'RuleAction{split=$split}';
}

class Result {
  Result(this.result);

  bool get() {
    return result;
  }

  final bool result;
}
