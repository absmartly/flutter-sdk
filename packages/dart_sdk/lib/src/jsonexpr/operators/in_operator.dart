import '../evaluator.dart';
import 'binary_operator.dart';

/// CONTAINS operator (also registered under the legacy alias "in").
///
/// Operand order is haystack-first: `[haystack, needle]` — i.e. "does the
/// haystack (arg 0) contain the needle (arg 1)". This matches the collector
/// and the other ABsmartly SDKs.
class InOperator extends BinaryOperator {
  @override
  dynamic binary(Evaluator evaluator, dynamic haystack, dynamic needle) {
    if (haystack is List) {
      for (final item in haystack) {
        if (evaluator.compare(item, needle) == 0) {
          return true;
        }
      }
      return false;
    } else if (haystack is String) {
      if (needle is! String) return null;
      return haystack.contains(needle);
    } else if (haystack is Map) {
      final needleString = evaluator.stringConvert(needle);
      return needleString != null &&
          (haystack as Map<String, dynamic>).containsKey(needleString);
    }
    return null;
  }
}
