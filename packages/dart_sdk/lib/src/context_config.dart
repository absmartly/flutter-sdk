import 'context_event_logger.dart';
import 'internal/unit_values.dart';

class ContextConfig {
  ContextConfig();

  static ContextConfig create({
    Map<String, Object>? units,
    Map<String, dynamic>? attributes,
    Map<String, int>? overrides,
    Map<String, int>? customAssignments,
    int? publishDelay,
    int? refreshInterval,
    ContextEventLogger? contextEventLogger,
  }) {
    final config = ContextConfig();
    if (units != null) config.setUnits(units);
    if (attributes != null) config.setAttributes(attributes);
    if (overrides != null) config.setOverrides(overrides);
    if (customAssignments != null)
      config.setCustomAssignments(customAssignments);
    if (publishDelay != null) config.setPublishDelay(publishDelay);
    if (refreshInterval != null) config.setRefreshInterval(refreshInterval);
    if (contextEventLogger != null) {
      config.setContextEventLogger(contextEventLogger);
    }
    return config;
  }

  /// Sets the UID of [unitType]: a [String], or a [num] for a numeric UID.
  /// [getUnit] and [getUnits] return it as a string, as in 2.1;
  /// [ContextConfigUnitValues.getUnitValue] returns it as set.
  ContextConfig setUnit(final String unitType, covariant final Object uid) {
    if (uid is! String && uid is! num) {
      throw Exception("Unit '$unitType' must be a string or a number.");
    }
    _units.setValue(unitType, uid);
    return this;
  }

  ContextConfig setUnits(covariant final Map<String, Object> units) {
    for (final entry in units.entries) {
      setUnit(entry.key, entry.value);
    }
    return this;
  }

  String? getUnit(final String unitType) => _units[unitType];

  Map<String, String> getUnits() => _units;

  ContextConfig setAttribute(final String name, final Object value) {
    attributes_[name] = value;
    return this;
  }

  ContextConfig setAttributes(final Map<String, dynamic> attributes) {
    attributes_.addAll(attributes);
    return this;
  }

  dynamic getAttribute(final String name) => attributes_[name];

  Map<String, dynamic> getAttributes() => attributes_;

  ContextConfig setOverride(final String experimentName, int variant) {
    overrides_[experimentName] = variant;
    return this;
  }

  ContextConfig setOverrides(final Map<String, int> overrides) {
    overrides_.addAll(overrides);
    return this;
  }

  dynamic getOverride(String experimentName) => overrides_[experimentName];

  Map<String, int> getOverrides() => overrides_;

  ContextConfig setCustomAssignment(String experimentName, int variant) {
    cassigmnents_[experimentName] = variant;
    return this;
  }

  ContextConfig setCustomAssignments(Map<String, int> customAssignments) {
    cassigmnents_.addAll(customAssignments);
    return this;
  }

  dynamic getCustomAssignment(String experimentName) =>
      cassigmnents_[experimentName];

  Map<String, int> getCustomAssignments() => cassigmnents_;

  ContextConfig setPublishDelay(int delayMs) {
    publishDelay = delayMs;
    return this;
  }

  int getPublishDelay() => publishDelay;

  ContextConfig setRefreshInterval(int intervalMs) {
    refreshInterval = intervalMs;
    return this;
  }

  ContextEventLogger? getContextEventLogger() {
    return logger_;
  }

  void setContextEventLogger(ContextEventLogger logger) {
    logger_ = logger;
  }

  int getRefreshInterval() => refreshInterval;

  UnitsMap _units = UnitsMap();

  /// The units, numeric UIDs in their `toString()` form. A UID written
  /// directly to this map replaces the value it was set as.
  Map<String, String> get units_ => _units;

  set units_(Map<String, String> units) {
    _units = UnitsMap()..addAll(units);
  }

  Map<String, dynamic> attributes_ = {};
  Map<String, int> overrides_ = {};
  Map<String, int> cassigmnents_ = {};
  int publishDelay = 100;
  int refreshInterval = 0;

  ContextEventLogger? logger_;
}

/// The units of a [ContextConfig] as they were set, numbers included. An
/// extension rather than members of [ContextConfig], so existing
/// `implements ContextConfig` classes keep compiling.
extension ContextConfigUnitValues on ContextConfig {
  /// The UID of [unitType] as set: a [String] or a [num].
  Object? getUnitValue(final String unitType) {
    final Map<String, String> units = getUnits();
    return units is UnitsMap ? units.value(unitType) : units[unitType];
  }

  /// Every unit as set. A UID written through [ContextConfig.units_] is
  /// returned as that string.
  Map<String, Object> getUnitValues() {
    return getUnits().map(
        (unitType, uid) => MapEntry(unitType, getUnitValue(unitType) ?? uid));
  }
}
