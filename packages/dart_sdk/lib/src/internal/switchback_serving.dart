import 'dart:convert';

import 'switchback_attribute_path.dart';

// On the web an int is a JavaScript number, so 3.0 and 3 are the same value.
const bool _isWeb = identical(0, 0.0);

// Port of java-sdk internal/SwitchbackClusterKeys (the Collector's
// SwitchbackClusterKeys.normalize): the cluster key an attribute value yields,
// or null when it yields none. A non-empty String is the key as-is and a
// whole-number int is its base-10 text. Null, empty strings, booleans,
// floating-point numbers, maps and lists yield no key. The key is passed to
// SwitchbackAssigner unhashed.
//
// On the web a whole-number double such as 3.0 is an int and yields "3", as
// the integer 3 does: the web cannot tell them apart. The key is the number's
// text in the published attributes, which the Collector re-reads, so a number
// published as a float (-0.0, 1e+21) yields none and one published rounded
// (2^60 as 1152921504606847000) yields that rounded text.
abstract class SwitchbackClusterKeys {
  static String? normalize(final dynamic value) {
    if (value is String) {
      return value.isEmpty ? null : value;
    }
    if (value is int) {
      if (_isWeb) {
        // Infinity is an int on the web and has no JSON encoding.
        if (!value.isFinite) {
          return null;
        }
        final String text = jsonEncode(value);
        return text.contains('.') || text.contains('e') ? null : text;
      }
      return value.toString();
    }
    return null;
  }
}

// A linked unit type and the attribute path its cluster value is read at.
class SwitchbackSource {
  const SwitchbackSource(this.unitType, this.path);

  final String unitType;
  final SwitchbackAttributePath path;
}

class SwitchbackUnit {
  const SwitchbackUnit(this.type, this.uid);

  final String type;
  final Object uid;
}

enum SwitchbackStatus { absent, ineligible, eligible }

// Which unit serves a switchback experiment and under which cluster key. Port
// of java-sdk internal/SwitchbackServing (the Collector's
// ContextAPI.switchbackServing, R33 cluster-defined switchbacks):
//
// - The experiment's switchbackClusters map, in its declared order, lists the
//   linked unit types and, for each, the attribute path holding its cluster
//   value.
// - No context unit of a linked type: the experiment does not apply (absent).
// - Otherwise each linked unit, in source order, reads the attribute at its
//   source's path, normalised by SwitchbackClusterKeys. The first unit
//   yielding a value is the serving unit and the value is the cluster key;
//   units yielding no value are skipped.
// - Ineligible, served under the first linked unit: no unit yields a value,
//   two units yield different values, or an allow-list is set and lacks the
//   key.
// - Eligible otherwise.
// - A missing, empty or unreadable cluster map takes the Collector's legacy
//   path instead (legacy).
class SwitchbackServing {
  const SwitchbackServing._(this.status, this.unit, this.clusterKey,
      [this.readAt = 0]);

  final SwitchbackStatus status;
  final SwitchbackUnit? unit;
  // The raw normalised cluster key when eligible; never hashed.
  final String? clusterKey;
  // The clock reading the cluster attributes were read at.
  final int readAt;

  SwitchbackServing at(final int readAt) =>
      SwitchbackServing._(status, unit, clusterKey, readAt);

  // The same unit and key: the status follows from them.
  bool servesSameAs(final SwitchbackServing other) =>
      unit?.type == other.unit?.type && clusterKey == other.clusterKey;

  static const SwitchbackServing _absent =
      SwitchbackServing._(SwitchbackStatus.absent, null, null);

  // [sources] in declared order, for a readable cluster map. The declared
  // source order alone decides which unit serves: the source loop is the
  // outer one.
  static SwitchbackServing resolve(
      final List<SwitchbackSource> sources,
      final List<String>? allowedValues,
      final List<SwitchbackUnit> units,
      final dynamic Function(SwitchbackAttributePath path) read) {
    SwitchbackUnit? first;
    SwitchbackUnit? serving;
    String? key;
    bool disagreement = false;
    for (final SwitchbackSource source in sources) {
      for (final SwitchbackUnit unit in units) {
        if (unit.type != source.unitType) {
          continue;
        }
        first ??= unit;
        final String? value =
            SwitchbackClusterKeys.normalize(read(source.path));
        if (value == null) {
          continue;
        }
        if (key == null) {
          key = value;
          serving = unit;
        } else if (key != value) {
          disagreement = true;
        }
      }
    }

    if (first == null) {
      return _absent;
    }
    if (key == null || disagreement || !allowed(allowedValues, key)) {
      return SwitchbackServing._(SwitchbackStatus.ineligible, first, null);
    }
    return SwitchbackServing._(SwitchbackStatus.eligible, serving, key);
  }

  // The Collector's compatibility path for a missing, empty or unreadable
  // cluster map: the experiment's declared unitType only identifies an
  // ineligible control response (never an assignment or a cluster); without a
  // unit of that type the experiment does not apply.
  static SwitchbackServing legacy(
      final String? unitType, final List<SwitchbackUnit> units) {
    if (unitType != null) {
      for (final SwitchbackUnit unit in units) {
        if (unit.type == unitType) {
          return SwitchbackServing._(SwitchbackStatus.ineligible, unit, null);
        }
      }
    }
    return _absent;
  }

  // A null or empty allow-list admits every value, as in the Collector.
  static bool allowed(final List<String>? allowedValues, final String key) {
    return allowedValues == null ||
        allowedValues.isEmpty ||
        allowedValues.contains(key);
  }

  // The sources of a switchbackClusters map, in declared order; null for a
  // missing or empty map or any path that is not a supported attribute path
  // (the legacy path).
  static List<SwitchbackSource>? sources(final Map<String, String?>? clusters) {
    if (clusters == null || clusters.isEmpty) {
      return null;
    }
    final List<SwitchbackSource> sources = [];
    for (final MapEntry<String, String?> entry in clusters.entries) {
      final SwitchbackAttributePath? parsed =
          SwitchbackAttributePath.parseSupported(entry.value);
      if (parsed == null) {
        return null;
      }
      sources.add(SwitchbackSource(entry.key, parsed));
    }
    return List.unmodifiable(sources);
  }
}
