import 'context_counters.dart';

// Recovers the wire key order of the "switchbackClusters" objects in a
// context payload. On the web, jsonDecode builds JavaScript objects, which
// enumerate integer-like keys (a unit type named "2") before the others, so
// the decoded map loses the declared order the serving unit depends on.

// The path from the payload root to a value: map keys and list indices.
typedef JsonPath = List<Object>;

// Every object-valued "switchbackClusters" member in [json], with its path
// and its keys in wire order (first occurrence of a repeated key). Field
// names are compared decoded, so an escaped spelling counts. Null when [json]
// is not well-formed enough to follow.
List<(JsonPath, List<String>)>? switchbackClusterKeyOrders(final String json) {
  // Only a \u escape can spell the field name other than literally.
  if (!json.contains('switchbackClusters') && !json.contains(r'\u')) {
    return const [];
  }
  ContextCounters.keyOrderScans++;
  final _Scanner scanner = _Scanner(json);
  try {
    scanner.value(const []);
    return scanner.found;
  } catch (_) {
    // Malformed, or nested deeper than the scanner's stack allows.
    return null;
  }
}

// Re-keys each "switchbackClusters" map of [decoded] at a recorded path in
// that path's wire order. A path that does not lead to a map with exactly
// the recorded keys is left as decoded.
dynamic withSwitchbackClusterKeyOrder(
    final dynamic decoded, final List<(JsonPath, List<String>)> orders) {
  for (final (JsonPath path, List<String> order) in orders) {
    dynamic node = decoded;
    for (final Object step in path) {
      if (step is String && node is Map) {
        node = node[step];
      } else if (step is int && node is List && step < node.length) {
        node = node[step];
      } else {
        node = null;
        break;
      }
    }
    if (node is! Map ||
        node.length != order.length ||
        !order.every(node.containsKey)) {
      continue;
    }
    final Map<dynamic, dynamic> copy = Map.of(node);
    node.clear();
    for (final String key in order) {
      node[key] = copy[key];
    }
  }
  return decoded;
}

class _Scanner {
  _Scanner(this.json);

  final String json;
  int i = 0;
  final List<(JsonPath, List<String>)> found = [];

  Never fail() => throw const FormatException();

  void skipWhitespace() {
    while (i < json.length) {
      final int c = json.codeUnitAt(i);
      if (c != 0x20 && c != 0x0a && c != 0x0d && c != 0x09) {
        return;
      }
      ++i;
    }
  }

  void expect(final int c) {
    skipWhitespace();
    if (i >= json.length || json.codeUnitAt(i) != c) {
      fail();
    }
    ++i;
  }

  bool peek(final int c) {
    skipWhitespace();
    return i < json.length && json.codeUnitAt(i) == c;
  }

  String string() {
    expect(0x22);
    final StringBuffer out = StringBuffer();
    while (true) {
      if (i >= json.length) {
        fail();
      }
      final int c = json.codeUnitAt(i++);
      if (c == 0x22) {
        return out.toString();
      }
      if (c != 0x5c) {
        out.writeCharCode(c);
        continue;
      }
      if (i >= json.length) {
        fail();
      }
      final int e = json.codeUnitAt(i++);
      switch (e) {
        case 0x6e: // n
          out.writeCharCode(0x0a);
        case 0x74: // t
          out.writeCharCode(0x09);
        case 0x72: // r
          out.writeCharCode(0x0d);
        case 0x62: // b
          out.writeCharCode(0x08);
        case 0x66: // f
          out.writeCharCode(0x0c);
        case 0x75: // u
          if (i + 4 > json.length) {
            fail();
          }
          final int? code = int.tryParse(json.substring(i, i + 4), radix: 16);
          if (code == null) {
            fail();
          }
          out.writeCharCode(code);
          i += 4;
        default:
          out.writeCharCode(e);
      }
    }
  }

  void value(final JsonPath path) {
    skipWhitespace();
    if (i >= json.length) {
      fail();
    }
    final int c = json.codeUnitAt(i);
    if (c == 0x7b) {
      ++i;
      if (peek(0x7d)) {
        ++i;
        return;
      }
      while (true) {
        final String key = string();
        expect(0x3a);
        final JsonPath child = [...path, key];
        if (key == 'switchbackClusters' && peek(0x7b)) {
          found.add((child, clusterKeys()));
        } else {
          value(child);
        }
        if (peek(0x2c)) {
          ++i;
          continue;
        }
        expect(0x7d);
        return;
      }
    }
    if (c == 0x5b) {
      ++i;
      if (peek(0x5d)) {
        ++i;
        return;
      }
      for (int index = 0;; ++index) {
        value([...path, index]);
        if (peek(0x2c)) {
          ++i;
          continue;
        }
        expect(0x5d);
        return;
      }
    }
    if (c == 0x22) {
      string();
      return;
    }
    // A number or literal: up to the next delimiter.
    final int start = i;
    while (i < json.length) {
      final int d = json.codeUnitAt(i);
      if (d == 0x2c || d == 0x7d || d == 0x5d || d <= 0x20) {
        break;
      }
      ++i;
    }
    if (i == start) {
      fail();
    }
  }

  // The keys of the object at [i], in wire order, first occurrence kept.
  List<String> clusterKeys() {
    expect(0x7b);
    final List<String> keys = [];
    if (peek(0x7d)) {
      ++i;
      return keys;
    }
    while (true) {
      final String key = string();
      if (!keys.contains(key)) {
        keys.add(key);
      }
      expect(0x3a);
      value(const []);
      if (peek(0x2c)) {
        ++i;
        continue;
      }
      expect(0x7d);
      return keys;
    }
  }
}
