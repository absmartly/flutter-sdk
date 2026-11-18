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
// map), the values as set, keyed by that map. Such a map cannot see its own
// writes, so a stored value is used while the map holds its string form: a
// write of a different string wins, and a lookup that finds the unit missing
// drops it. Only a same-string rewrite that is never seen missing keeps it.
final Expando<Map<String, Object>> _plainValues =
    Expando<Map<String, Object>>();

/// Stores [uid] for [unitType] in [units], keeping a number as set.
void setUnitValue(Map<String, String> units, String unitType, Object uid) {
  if (units is UnitsMap) {
    units.setValue(unitType, uid);
    return;
  }
  units[unitType] = uid is String ? uid : uid.toString();
  (_plainValues[units] ??= <String, Object>{})[unitType] = uid;
}

/// The UID of [unitType] in [units] as set, or its string form.
Object? unitValue(Map<String, String> units, String unitType) {
  if (units is UnitsMap) {
    return units.value(unitType);
  }
  final String? uid = units[unitType];
  final Map<String, Object>? values = _plainValues[units];
  if (uid == null) {
    values?.remove(unitType);
    return null;
  }
  final Object? value = values?[unitType];
  return (value != null && value.toString() == uid) ? value : uid;
}
