import 'dart:collection';

/// The `units_` map of [Context] and [ContextConfig]: UIDs in their 2.1
/// string form, plus the value each was set as (a number keeps its type for
/// hashing). A write or removal through the map itself drops that key's
/// stored value, so the string written is what is used from then on.
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
