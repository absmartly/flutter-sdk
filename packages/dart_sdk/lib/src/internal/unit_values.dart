import 'dart:collection';

/// The `units_` map of [Context] and [ContextConfig]: UIDs in their 2.1
/// string form, plus the value each was set as (a number keeps its type for
/// hashing). A write or removal through the map itself drops that key's
/// stored value, so the string written is what is used from then on.
// LinkedHashMap, as the released units_ maps were. It is final from Dart 3's
// language version on, so the 3.0 line must drop it and document the change.
class UnitsMap extends MapBase<String, String>
    implements LinkedHashMap<String, String> {
  final Map<String, String> _strings = {};
  final Map<String, Object> _values = {};

  /// Stores [uid] for [unitType], as set through `setUnit`.
  void setValue(String unitType, Object uid) {
    _strings[unitType] = uid is String ? uid : uid.toString();
    _values[unitType] = uid;
  }

  /// The UID of [unitType] as set, or its string when written to the map.
  Object? value(String unitType) {
    final String? uid = _strings[unitType];
    if (uid == null) {
      return null;
    }
    return _values[unitType] ?? uid;
  }

  @override
  String? operator [](Object? key) => _strings[key];

  @override
  void operator []=(String key, String value) {
    _strings[key] = value;
    _values.remove(key);
  }

  @override
  void clear() {
    _strings.clear();
    _values.clear();
  }

  @override
  Iterable<String> get keys => _strings.keys;

  @override
  String? remove(Object? key) {
    _values.remove(key);
    return _strings.remove(key);
  }
}

// For a units map that is not a UnitsMap (a subclass override or an assigned
// map), the numeric UIDs set through setUnit, keyed by that map. Such a map
// cannot see its own writes, so a number is used only while the map's entry
// still holds its string form: a write of a different string wins, and a
// lookup that finds the unit missing drops it. Only a same-string rewrite
// that is never seen missing keeps it. Lookups go through the map, so its own
// key equality decides which entry a key reads; for a SplayTreeMap keys its
// comparator treats as equal share one stored number. Other custom-equality
// maps (a LinkedHashMap with its own equals) are matched by exact key only.
final Expando<Map<String, num>> _plainValues = Expando<Map<String, num>>();

/// Stores [uid] for [unitType] in [units], keeping a number as set.
void setUnitValue(Map<String, String> units, String unitType, Object uid) {
  if (units is UnitsMap) {
    units.setValue(unitType, uid);
    return;
  }
  units[unitType] = uid is String ? uid : uid.toString();
  final Map<String, num>? values = _plainValues[units];
  // The map decides which entry a key writes (its own key equality), so
  // forget the numbers of every key that maps to the entry just written.
  // Then a string write through an equal key is not shadowed by an older
  // number.
  values?.removeWhere(
      (key, _) => units.containsKey(key) && _sameEntry(units, key, unitType));
  if (uid is num) {
    (_plainValues[units] ??= <String, num>{})[unitType] = uid;
  }
}

/// The UID of [unitType] in [units] as set, or its string form.
Object? unitValue(Map<String, String> units, String unitType) {
  if (units is UnitsMap) {
    return units.value(unitType);
  }
  final String? uid = units[unitType];
  final Map<String, num>? values = _plainValues[units];
  if (uid == null) {
    // Seen missing: drop the numbers of every unit no longer in the map,
    // including one stored under a key the map treats as equal.
    values?.removeWhere((key, _) => !units.containsKey(key));
    return null;
  }
  if (values == null || values.isEmpty) {
    return uid;
  }
  // The key the number was stored under may differ from [unitType] when a
  // SplayTreeMap treats them as equal.
  num? value = values[unitType];
  if (value == null && units is SplayTreeMap<String, String>) {
    for (final MapEntry<String, num> entry in values.entries) {
      if (_sameEntry(units, entry.key, unitType)) {
        value = entry.value;
        break;
      }
    }
  }
  return (value != null && value.toString() == uid) ? value : uid;
}

// Whether [a] and [b] address the same entry of [units]: equal keys, or keys
// the map itself treats as equal (e.g. a case-insensitive SplayTreeMap).
bool _sameEntry(Map<String, String> units, String a, String b) {
  if (a == b) {
    return true;
  }
  if (units is SplayTreeMap<String, String>) {
    // A SplayTreeMap finds a key through its comparator: a and b address the
    // same entry when looking either up lands on the other's position.
    // Both callers pass a [b] that is in the map.
    return units.lastKeyBefore(a) == units.lastKeyBefore(b) &&
        units.containsKey(a);
  }
  return false;
}
