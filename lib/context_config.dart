import 'context_event_logger.dart';

class ContextConfig {
  ContextConfig();

  static ContextConfig create() => ContextConfig();

  ContextConfig setUnit(final String unitType, final String uid) {
    units_ ??= {};
    units_?[unitType] = uid;
    return this;
  }

  ContextConfig setUnits(final Map<String, String> units) {
    for (final entry in units.entries) {
      setUnit(entry.key, entry.value);
    }
    return this;
  }

  String? getUnit(final String unitType) => units_?[unitType];

  Map<String, String>? getUnits() => units_;

  ContextConfig setAttribute(final String name, final Object value) {
    attributes_ ??= {};
    attributes_?[name] = value;
    return this;
  }

  ContextConfig setAttributes(final Map<String, dynamic> attributes) {
    attributes_ ??= {};
    attributes_?.addAll(attributes);
    return this;
  }

  dynamic getAttribute(final String name) => attributes_?[name];

  Map<String, dynamic>? getAttributes() => attributes_;

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
    cassigmnents_ ??= <String, int>{};
    cassigmnents_![experimentName] = variant;
    return this;
  }

  ContextConfig setCustomAssignments(Map<String, int> customAssignments) {
    cassigmnents_ ??= {};
    cassigmnents_!.addAll(customAssignments);
    return this;
  }

  dynamic getCustomAssignment(String experimentName) =>
      cassigmnents_?[experimentName];

  Map<String, int>? getCustomAssignments() => cassigmnents_;

  ContextConfig setPublishDelay(int delayMs) {
    publishDelay = delayMs;
    return this;
  }

  int getPublishDelay() => publishDelay;

  ContextConfig setRefreshInterval(int intervalMs) {
    refreshInterval = intervalMs;
    return this;
  }


  ContextEventLogger? getContextEventLogger(){
    return logger_;
  }

  void setContextEventLogger(ContextEventLogger logger) {
    logger_ = logger;
  }


  int getRefreshInterval() => refreshInterval;

  Map<String, String>? units_;
  Map<String, dynamic>? attributes_;
  Map<String, int> overrides_ = {};
  Map<String, int>? cassigmnents_ = {};
  int publishDelay = 100;
  int refreshInterval = 0;


  ContextEventLogger? logger_;

}
