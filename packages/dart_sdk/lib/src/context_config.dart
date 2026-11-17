import 'context_event_logger.dart';

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

  ContextConfig setUnit(final String unitType, covariant final Object uid) {
    _units[unitType] = uid;
    return this;
  }

  ContextConfig setUnits(covariant final Map<String, Object> units) {
    for (final entry in units.entries) {
      setUnit(entry.key, entry.value);
    }
    return this;
  }

  /// The UID as set: a [String], or a [num] for a numeric UID. Typed
  /// `dynamic` so 2.1 code reading it as `String?` keeps compiling.
  dynamic getUnit(final String unitType) => _units[unitType];

  /// The units map itself, typed `Map<String, String>` while every UID is a
  /// [String] (as in 2.1), otherwise `Map<String, Object>`.
  dynamic getUnits() => units_;

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

  Map<String, Object> _units = {};

  /// The units map, typed `Map<String, String>` while every UID is a
  /// [String] (as in 2.1), otherwise `Map<String, Object>`.
  dynamic get units_ => _units.values.every((uid) => uid is String)
      ? _units.cast<String, String>()
      : _units;

  set units_(dynamic units) {
    _units = Map<String, Object>.from(units as Map);
  }

  Map<String, dynamic> attributes_ = {};
  Map<String, int> overrides_ = {};
  Map<String, int> cassigmnents_ = {};
  int publishDelay = 100;
  int refreshInterval = 0;

  ContextEventLogger? logger_;
}
