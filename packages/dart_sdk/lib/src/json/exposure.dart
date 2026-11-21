import '../internal/context_counters.dart';

class Exposure {
  late int id;
  late String name;
  late String? unit;
  late int variant;
  late int exposedAt;
  late bool assigned;
  late bool eligible;
  late bool overridden;
  late bool fullOn;
  late bool custom;
  late bool audienceMismatch;
  bool _ruleOverride = false;

  Exposure({
    required this.id,
    required this.name,
    required this.unit,
    required this.variant,
    required this.exposedAt,
    required this.assigned,
    required this.eligible,
    required this.overridden,
    required this.fullOn,
    required this.custom,
    required this.audienceMismatch,
    bool ruleOverride = false,
  }) : _ruleOverride = ruleOverride;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Exposure &&
            id == other.id &&
            variant == other.variant &&
            exposedAt == other.exposedAt &&
            assigned == other.assigned &&
            eligible == other.eligible &&
            overridden == other.overridden &&
            fullOn == other.fullOn &&
            custom == other.custom &&
            audienceMismatch == other.audienceMismatch &&
            ruleOverride == other.ruleOverride &&
            name == other.name &&
            unit == other.unit;
  }

  @override
  int get hashCode => Object.hash(id, name, unit, variant, exposedAt, assigned,
      eligible, overridden, fullOn, custom, audienceMismatch, ruleOverride);

  @override
  String toString() {
    return 'Exposure{id: $id, name: $name, unit: $unit, variant: $variant, exposedAt: $exposedAt, assigned: $assigned, eligible: $eligible, overridden: $overridden, fullOn: $fullOn, custom: $custom, audienceMismatch: $audienceMismatch, ruleOverride: $ruleOverride}';
  }

  Exposure.fromMap(Map<String, dynamic> data) {
    id = data["id"];
    name = data["name"];
    unit = data["unit"];
    variant = data["variant"];
    exposedAt = data["exposedAt"];
    assigned = data["assigned"];
    eligible = data["eligible"];
    overridden = data["overridden"];
    fullOn = data["fullOn"];
    custom = data["custom"];
    audienceMismatch = data["audienceMismatch"];
    _ruleOverride = data["ruleOverride"] ?? false;
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "unit": unit,
      "variant": variant,
      "exposedAt": exposedAt,
      "assigned": assigned,
      "eligible": eligible,
      "overridden": overridden,
      "fullOn": fullOn,
      "custom": custom,
      "audienceMismatch": audienceMismatch,
      "ruleOverride": _ruleOverride,
    };
  }
}

// Exposure is implementable by customers, so ruleOverride is a private field
// (it survives copying to another isolate, unlike an Expando): a public one
// would break `implements Exposure`. A class from another library that
// implements Exposure has no such field; its value lives in an Expando.
final Expando<bool> _implRuleOverrides = Expando<bool>();

// Objects from another library that implements Exposure, which have no
// private field. Remembered per object (a type could be faked through an
// overridden runtimeType), so each such object throws at most once.
final Expando<bool> _foreignExposures = Expando<bool>();

bool _ownsExposureFields(Exposure exposure) {
  if (_foreignExposures[exposure] == true) {
    return false;
  }
  try {
    exposure._ruleOverride;
    return true;
  } on NoSuchMethodError {
    ContextCounters.modelFieldProbes++;
    _foreignExposures[exposure] = true;
    return false;
  }
}

/// Whether an assignment rule chose the variant. An extension rather than a
/// field of [Exposure], so existing `implements Exposure` classes keep
/// compiling.
extension ExposureRuleOverride on Exposure {
  bool get ruleOverride => _ownsExposureFields(this)
      ? _ruleOverride
      : _implRuleOverrides[this] ?? false;

  set ruleOverride(bool value) {
    if (_ownsExposureFields(this)) {
      _ruleOverride = value;
    } else {
      _implRuleOverrides[this] = value;
    }
  }
}
