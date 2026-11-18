import 'dart:convert';

// A switchback cluster attribute path, resolved like java-sdk
// internal/SwitchbackAttributePath (a port of the Collector's): "/" separates
// segments, a segment wrapped in ' or " is a literal key, and an unquoted
// segment that Guava Ints.tryParse accepts (ASCII digits, optional leading
// '-') indexes a List and nothing else. Every other segment reads a Map key. A
// path is malformed, and its experiment unservable, when a quote is left
// unterminated or any segment key, quoted or not, contains a '.' (dotted paths
// are not a nesting syntax; nesting is written with '/').
class SwitchbackAttributePath {
  static const int _maxDepth = 64;

  SwitchbackAttributePath._(this._keys, this._indices);

  final List<String> _keys;
  // Parallel to _keys; null where the segment is a map key.
  final List<int?> _indices;

  // Null for an unsupported path: malformed (see above), empty, or an array
  // index that is negative, first, last, or directly after another index.
  // Analysis cannot read those.
  static SwitchbackAttributePath? parseSupported(final String? path) {
    if (path == null) {
      return null;
    }
    final SwitchbackAttributePath? parsed = _parse(path);
    if (parsed == null) {
      return null;
    }
    final int n = parsed._keys.length;
    if (n == 0) {
      return null;
    }
    for (int i = 0; i < n; ++i) {
      final int? index = parsed._indices[i];
      if (index != null &&
          (index < 0 ||
              i == 0 ||
              i == n - 1 ||
              parsed._indices[i - 1] != null)) {
        return null;
      }
    }
    return parsed;
  }

  String get rootKey => _keys[0];

  dynamic resolve(final Map<String, dynamic> attributes) =>
      _resolveFrom(attributes, 0);

  // Resolves the path below rootKey in an attribute value, read as the
  // Collector reads it: through the value's JSON encoding, the form it is
  // published in. Null when the value has no JSON encoding, or nests maps and
  // lists in a cycle or deeper than _maxDepth.
  dynamic resolveAttribute(final dynamic rootValue) {
    if (rootValue == null) {
      return null;
    }
    final dynamic decoded;
    if (rootValue is String || rootValue is bool || rootValue is int) {
      // Each of these decodes back to an equal value of the same type.
      decoded = rootValue;
    } else {
      if (!_isAcyclicWithinDepth(rootValue, Set.identity(), 0)) {
        return null;
      }
      try {
        decoded = jsonDecode(jsonEncode(rootValue));
      } catch (_) {
        return null;
      }
    }
    return _resolveFrom(decoded, 1);
  }

  // `path` holds the containers on the current branch only, so a value shared
  // by two siblings is not a cycle.
  static bool _isAcyclicWithinDepth(
      final dynamic value, final Set<Object> path, final int depth) {
    final Iterable<dynamic> children;
    if (value is Map) {
      children = value.values;
    } else if (value is Iterable) {
      children = value;
    } else {
      return true;
    }
    if (depth >= _maxDepth || !path.add(value)) {
      return false;
    }
    for (final dynamic child in children) {
      if (!_isAcyclicWithinDepth(child, path, depth + 1)) {
        return false;
      }
    }
    path.remove(value);
    return true;
  }

  dynamic _resolveFrom(final dynamic root, final int first) {
    dynamic current = root;
    for (int i = first; i < _keys.length; ++i) {
      current = _step(current, _keys[i], _indices[i]);
      if (current == null) {
        return null;
      }
    }
    return current;
  }

  static SwitchbackAttributePath? _parse(final String path) {
    if (path.contains('.')) {
      return null;
    }
    final List<String> keys = [];
    final List<int?> indices = [];
    int i = 0;
    while (i < path.length) {
      if (path[i] == '/') {
        ++i;
        continue;
      }

      final String first = path[i];
      if (first == "'" || first == '"') {
        final int end = path.indexOf(first, i + 1);
        if (end < 0) {
          return null;
        }
        keys.add(path.substring(i + 1, end));
        indices.add(null);
        i = end + 1;
      } else {
        final int end = path.indexOf('/', i);
        final int stop = end < 0 ? path.length : end;
        final String key = path.substring(i, stop);
        keys.add(key);
        indices.add(tryParseInt(key));
        i = stop;
      }
    }
    return SwitchbackAttributePath._(
        List.unmodifiable(keys), List.unmodifiable(indices));
  }

  static dynamic _step(
      final dynamic current, final String key, final int? index) {
    if (index != null) {
      if (current is List) {
        return (index >= 0 && index < current.length) ? current[index] : null;
      }
      return null;
    }
    if (current is Map) {
      return current[key];
    }
    return null;
  }

  // Guava Ints.tryParse(String): optional '-', then one or more ASCII digits,
  // within int32 range; otherwise null. "+1" and non-ASCII digits are not
  // numbers; "-0" is 0.
  static int? tryParseInt(final String s) {
    final int length = s.length;
    final bool negative = length > 0 && s.codeUnitAt(0) == 0x2d;
    int i = negative ? 1 : 0;
    if (i == length) {
      return null;
    }
    int magnitude = 0;
    for (; i < length; ++i) {
      final int c = s.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) {
        return null;
      }
      magnitude = magnitude * 10 + (c - 0x30);
      if (magnitude > 0x80000000) {
        return null;
      }
    }
    final int value = negative ? -magnitude : magnitude;
    return value > 0x7fffffff ? null : value;
  }
}
