import 'package:intl/intl.dart';

import 'evaluator.dart';

/// Semantic version comparison used by the semver_* operators, ported from
/// the JavaScript SDK evaluator: a leading "v"/"V" and build metadata are
/// ignored, missing core parts count as 0, numeric identifiers compare
/// numerically (leading zeros ignored) and rank below alphanumeric ones, and a
/// release ranks above any of its pre-releases.
///
/// Parsing is as permissive as the JavaScript SDK's, so both order the same
/// inputs the same way: a non-numeric core part (as in "1.x") is compared as an
/// alphanumeric identifier, and an empty pre-release ("1.0.0-") is a release.
class SemverComparator {
  SemverComparator._();

  // Same format as ExprEvaluator.stringConvert, but with a fixed locale: under
  // a locale with a comma decimal separator, 2.5 would otherwise become "2,5",
  // a single alphanumeric core part instead of "2" and "5".
  static final NumberFormat _formatter = NumberFormat.decimalPattern('en_US')
    ..maximumFractionDigits = 15
    ..minimumFractionDigits = 0
    ..minimumIntegerDigits = 1
    ..turnOffGrouping();

  static final RegExp _numeric = RegExp(r'^\d+$');

  /// Returns -1, 0 or 1, or null when either side is not a string, number or
  /// boolean, or has an empty version core after removing a leading v/V and
  /// build metadata (for example "", "v", "+build" or "-beta").
  static int? compareValues(Evaluator evaluator, dynamic lhs, dynamic rhs) {
    final lhsStr = _stringConvert(evaluator, lhs);
    final rhsStr = _stringConvert(evaluator, rhs);
    if (lhsStr == null || rhsStr == null) {
      return null;
    }
    return compare(lhsStr, rhsStr);
  }

  static String? _stringConvert(Evaluator evaluator, dynamic x) {
    return x is num ? _formatter.format(x) : evaluator.stringConvert(x);
  }

  static int? compare(String lhs, String rhs) {
    final l = _parse(lhs);
    final r = _parse(rhs);
    if (l == null || r == null) {
      return null;
    }

    final maxLen =
        l.parts.length > r.parts.length ? l.parts.length : r.parts.length;
    for (int i = 0; i < maxLen; ++i) {
      final lPart = i < l.parts.length ? l.parts[i] : '0';
      final rPart = i < r.parts.length ? r.parts[i] : '0';
      final result = _compareIdentifiers(lPart, rPart);
      if (result != 0) {
        return result;
      }
    }

    if (l.preRelease.isEmpty && r.preRelease.isEmpty) {
      return 0;
    } else if (l.preRelease.isEmpty) {
      return 1;
    } else if (r.preRelease.isEmpty) {
      return -1;
    }

    final lPre = l.preRelease.split('.');
    final rPre = r.preRelease.split('.');
    final preLen = lPre.length > rPre.length ? lPre.length : rPre.length;
    for (int i = 0; i < preLen; ++i) {
      if (i >= lPre.length) {
        return -1;
      }
      if (i >= rPre.length) {
        return 1;
      }
      final result = _compareIdentifiers(lPre[i], rPre[i]);
      if (result != 0) {
        return result;
      }
    }
    return 0;
  }

  static _Version? _parse(String version) {
    String v = version;
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }

    final plusIndex = v.indexOf('+');
    if (plusIndex >= 0) {
      v = v.substring(0, plusIndex);
    }

    if (v.isEmpty) {
      return null;
    }

    final dashIndex = v.indexOf('-');
    final core = dashIndex >= 0 ? v.substring(0, dashIndex) : v;
    final preRelease = dashIndex >= 0 ? v.substring(dashIndex + 1) : '';
    if (core.isEmpty) {
      return null;
    }

    return _Version(core.split('.'), preRelease);
  }

  static String _stripLeadingZeros(String s) {
    int i = 0;
    while (i < s.length - 1 && s.codeUnitAt(i) == 0x30) {
      ++i;
    }
    return s.substring(i);
  }

  static int _compareIdentifiers(String a, String b) {
    final aIsNum = _numeric.hasMatch(a);
    final bIsNum = _numeric.hasMatch(b);

    if (aIsNum && bIsNum) {
      final aNorm = _stripLeadingZeros(a);
      final bNorm = _stripLeadingZeros(b);
      if (aNorm.length != bNorm.length) {
        return aNorm.length > bNorm.length ? 1 : -1;
      }
      return aNorm.compareTo(bNorm).sign;
    }
    if (aIsNum) {
      return -1;
    }
    if (bIsNum) {
      return 1;
    }
    return a.compareTo(b).sign;
  }
}

class _Version {
  _Version(this.parts, this.preRelease);

  final List<String> parts;
  final String preRelease;
}
