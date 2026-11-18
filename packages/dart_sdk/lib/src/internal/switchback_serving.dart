import 'switchback_attribute_path.dart';

// On the web an int is a JavaScript number, so 3.0 and 3 are the same value.
const bool _isWeb = identical(0, 0.0);
// JavaScript prints integers from 1e21 up in exponent form, which the
// Collector decodes as a floating-point number.
const double _maxWebIntegerText = 1e21;

// Port of java-sdk internal/SwitchbackClusterKeys (the Collector's
// SwitchbackClusterKeys.normalize): the cluster key an attribute value yields,
// or null when it yields none. A non-empty String is the key as-is and a
// whole-number int is its base-10 text. Null, empty strings, booleans,
// floating-point numbers, maps and lists yield no key. The key is passed to
// SwitchbackAssigner unhashed.
//
// On the web a whole-number double such as 3.0 is an int and yields "3", as
// the integer 3 does: the web cannot tell them apart, and JavaScript publishes
// both as 3.
abstract class SwitchbackClusterKeys {
  static String? normalize(final dynamic value) {
    if (value is String) {
      return value.isEmpty ? null : value;
    }
    if (value is int) {
      if (_isWeb) {
        // -0.0 is an int on the web; BigInt prints it, and every integer
        // above 2^53, without a sign or exponent.
        return value.abs() < _maxWebIntegerText
            ? BigInt.from(value).toString()
            : null;
      }
      return value.toString();
    }
    return null;
  }
}

// A context unit: its type and uid.
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
  const SwitchbackServing._(this.status, this.unit, this.clusterKey);

  final SwitchbackStatus status;
  // The serving unit when eligible, the first linked unit when ineligible,
  // null when absent.
  final SwitchbackUnit? unit;
  // The raw normalised cluster key when eligible; never hashed.
  final String? clusterKey;

  static const SwitchbackServing _absent =
      SwitchbackServing._(SwitchbackStatus.absent, null, null);

  // sourceTypes and sourcePaths are parallel, in declared order, for a
  // readable cluster map. The declared source order alone decides which unit
  // serves: the source loop is the outer one.
  static SwitchbackServing resolve(
      final List<String> sourceTypes,
      final List<SwitchbackAttributePath> sourcePaths,
      final List<String>? allowedValues,
      final List<SwitchbackUnit> units,
      final dynamic Function(SwitchbackAttributePath path) read) {
    SwitchbackUnit? first;
    SwitchbackUnit? serving;
    String? key;
    bool disagreement = false;
    for (int s = 0; s < sourceTypes.length; ++s) {
      final String type = sourceTypes[s];
      for (final SwitchbackUnit unit in units) {
        if (unit.type != type) {
          continue;
        }
        first ??= unit;
        final String? value =
            SwitchbackClusterKeys.normalize(read(sourcePaths[s]));
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

  // The parsed paths of a switchbackClusters map, in declared order; null
  // for a missing or empty map or any path that is not a supported attribute
  // path (the legacy path).
  static List<SwitchbackAttributePath>? sourcePaths(
      final Map<String, String?>? clusters) {
    if (clusters == null || clusters.isEmpty) {
      return null;
    }
    final List<SwitchbackAttributePath> paths = [];
    for (final String? path in clusters.values) {
      final SwitchbackAttributePath? parsed =
          SwitchbackAttributePath.parseSupported(path);
      if (parsed == null) {
        return null;
      }
      paths.add(parsed);
    }
    return List.unmodifiable(paths);
  }
}
