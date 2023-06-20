import 'dart:ui';

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
  });

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
            name == other.name &&
            unit == other.unit;
  }

  @override
  int get hashCode => hashValues(id, name, unit, variant, exposedAt, assigned,
      eligible, overridden, fullOn, custom, audienceMismatch);

  @override
  String toString() {
    return 'Exposure{id: $id, name: $name, unit: $unit, variant: $variant, exposedAt: $exposedAt, assigned: $assigned, eligible: $eligible, overridden: $overridden, fullOn: $fullOn, custom: $custom, audienceMismatch: $audienceMismatch}';
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
    };
  }
}
