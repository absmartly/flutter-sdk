// Recovers the wire key order of every "switchbackClusters" object in a
// context payload. On the web, jsonDecode builds JavaScript objects, which
// enumerate integer-like keys (a unit type named "2") before the others, so
// the decoded map loses the declared order the serving unit depends on.
//
// Returns, per occurrence of an object-valued "switchbackClusters" key in
// document order, its keys in wire order. A minimal scanner: it only tracks
// strings and nesting, and gives up (returns null) on input it cannot follow,
// in which case the decoded order is kept.
List<List<String>>? switchbackClusterKeyOrders(final String json) {
  if (!json.contains('"switchbackClusters"')) {
    return const [];
  }
  final List<List<String>> orders = [];
  int i = 0;
  final int n = json.length;

  // Reads the string starting at the quote at [i]; returns its decoded value
  // and leaves [i] after the closing quote.
  String? readString() {
    if (i >= n || json.codeUnitAt(i) != 0x22) {
      return null;
    }
    final int start = i;
    ++i;
    bool escaped = false;
    while (i < n) {
      final int c = json.codeUnitAt(i);
      if (c == 0x5c) {
        escaped = true;
        i += 2;
        continue;
      }
      if (c == 0x22) {
        ++i;
        final String raw = json.substring(start, i);
        return escaped ? _decodeString(raw) : raw.substring(1, raw.length - 1);
      }
      ++i;
    }
    return null;
  }

  void skipWhitespace() {
    while (i < n) {
      final int c = json.codeUnitAt(i);
      if (c != 0x20 && c != 0x0a && c != 0x0d && c != 0x09) {
        return;
      }
      ++i;
    }
  }

  // Skips one JSON value starting at [i]; false on malformed input.
  bool skipValue() {
    skipWhitespace();
    if (i >= n) {
      return false;
    }
    final int c = json.codeUnitAt(i);
    if (c == 0x22) {
      return readString() != null;
    }
    if (c == 0x7b || c == 0x5b) {
      int depth = 0;
      while (i < n) {
        final int d = json.codeUnitAt(i);
        if (d == 0x22) {
          if (readString() == null) {
            return false;
          }
          continue;
        }
        if (d == 0x7b || d == 0x5b) {
          ++depth;
        } else if (d == 0x7d || d == 0x5d) {
          --depth;
          if (depth == 0) {
            ++i;
            return true;
          }
        }
        ++i;
      }
      return false;
    }
    while (i < n) {
      final int d = json.codeUnitAt(i);
      if (d == 0x2c || d == 0x7d || d == 0x5d) {
        return true;
      }
      ++i;
    }
    return true;
  }

  while (i < n) {
    final int c = json.codeUnitAt(i);
    if (c != 0x22) {
      ++i;
      continue;
    }
    final String? key = readString();
    if (key == null) {
      return null;
    }
    skipWhitespace();
    if (key != 'switchbackClusters' || i >= n || json.codeUnitAt(i) != 0x3a) {
      continue;
    }
    ++i;
    skipWhitespace();
    if (i >= n || json.codeUnitAt(i) != 0x7b) {
      continue;
    }
    ++i;
    final List<String> keys = [];
    while (true) {
      skipWhitespace();
      if (i >= n) {
        return null;
      }
      if (json.codeUnitAt(i) == 0x7d) {
        ++i;
        break;
      }
      final String? name = readString();
      if (name == null) {
        return null;
      }
      keys.add(name);
      skipWhitespace();
      if (i >= n || json.codeUnitAt(i) != 0x3a) {
        return null;
      }
      ++i;
      if (!skipValue()) {
        return null;
      }
      skipWhitespace();
      if (i < n && json.codeUnitAt(i) == 0x2c) {
        ++i;
      }
    }
    orders.add(keys);
  }
  return orders;
}

String _decodeString(final String quoted) {
  final StringBuffer out = StringBuffer();
  for (int i = 1; i < quoted.length - 1; ++i) {
    final String c = quoted[i];
    if (c != r'\') {
      out.write(c);
      continue;
    }
    final String e = quoted[++i];
    switch (e) {
      case 'n':
        out.write('\n');
      case 't':
        out.write('\t');
      case 'r':
        out.write('\r');
      case 'b':
        out.write('\b');
      case 'f':
        out.write('\f');
      case 'u':
        out.writeCharCode(int.parse(quoted.substring(i + 1, i + 5), radix: 16));
        i += 4;
      default:
        out.write(e);
    }
  }
  return out.toString();
}

// Re-keys every object-valued "switchbackClusters" map in [decoded] in the
// wire order [orders] recorded, visiting maps in document order. Changes
// nothing when the occurrences do not line up one to one with the same key
// sets.
dynamic withSwitchbackClusterKeyOrder(
    final dynamic decoded, final List<List<String>> orders) {
  final List<Map> found = [];
  void visit(dynamic value) {
    if (value is Map) {
      value.forEach((key, child) {
        if (key == 'switchbackClusters' && child is Map) {
          found.add(child);
        } else {
          visit(child);
        }
      });
    } else if (value is List) {
      value.forEach(visit);
    }
  }

  visit(decoded);
  if (found.length != orders.length) {
    return decoded;
  }
  for (int k = 0; k < found.length; ++k) {
    final Map map = found[k];
    final List<String> order = orders[k];
    if (map.length != order.length || !order.every(map.containsKey)) {
      return decoded;
    }
  }
  for (int k = 0; k < found.length; ++k) {
    final Map map = found[k];
    final Map<dynamic, dynamic> copy = Map.of(map);
    map.clear();
    for (final String key in orders[k]) {
      map[key] = copy[key];
    }
  }
  return decoded;
}
