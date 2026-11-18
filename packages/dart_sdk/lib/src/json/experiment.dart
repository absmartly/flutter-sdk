import 'package:collection/collection.dart';

import '../internal/whole_number.dart';

import 'experiment_variant.dart';
import 'experiment_application.dart';

class CustomFieldValue {
  final String name;
  final String value;
  final String type;

  CustomFieldValue(
      {required this.name, required this.value, required this.type});

  factory CustomFieldValue.fromMap(Map<String, dynamic> data) {
    final name = data['name'];
    final value = data['value'];
    final type = data['type'];
    if (name is! String || value is! String || type is! String) {
      throw FormatException('Invalid customFieldValues entry: $data');
    }
    return CustomFieldValue(name: name, value: value, type: type);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'value': value,
      'type': type,
    };
  }
}

class Experiment {
  late int id;
  late String name;
  late String unitType;
  late int iteration;
  late int seedHi;
  late int seedLo;
  late List<double> split;
  late int trafficSeedHi;
  late int trafficSeedLo;
  late List<double> trafficSplit;
  late int fullOnVariant;
  late List<ExperimentApplication> applications;
  late List<ExperimentVariant> variants;
  late bool audienceStrict;
  late String? audience;
  late String? assignmentRules;
  late List<CustomFieldValue>? customFieldValues;
  // Library-private, so classes implementing Experiment in other libraries
  // are not required to declare them; read through [ExperimentHoldouts]. A
  // field (unlike an Expando) travels with the object across isolates.
  List<int>? _holdoutIdList;
  String? _holdoutTypeValue;

  Experiment({
    required this.id,
    required this.name,
    required this.unitType,
    required this.iteration,
    required this.seedHi,
    required this.seedLo,
    required this.split,
    required this.trafficSeedHi,
    required this.trafficSeedLo,
    required this.trafficSplit,
    required this.fullOnVariant,
    required this.applications,
    required this.variants,
    required this.audienceStrict,
    required this.audience,
    this.assignmentRules,
    this.customFieldValues,
    List<int>? holdoutIds,
    String? holdoutType,
  })  : _holdoutIdList = holdoutIds,
        _holdoutTypeValue = holdoutType;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Experiment &&
            id == other.id &&
            name == other.name &&
            unitType == other.unitType &&
            iteration == other.iteration &&
            seedHi == other.seedHi &&
            seedLo == other.seedLo &&
            trafficSeedHi == other.trafficSeedHi &&
            trafficSeedLo == other.trafficSeedLo &&
            fullOnVariant == other.fullOnVariant &&
            const ListEquality().equals(split, other.split) &&
            const ListEquality().equals(trafficSplit, other.trafficSplit) &&
            const ListEquality().equals(applications, other.applications) &&
            const ListEquality().equals(variants, other.variants) &&
            audienceStrict == other.audienceStrict &&
            audience == other.audience &&
            assignmentRules == other.assignmentRules &&
            const ListEquality().equals(holdoutIds, other.holdoutIds) &&
            holdoutType == other.holdoutType;
  }

  @override
  int get hashCode {
    const listEquality = ListEquality();
    return Object.hash(
      id,
      name,
      unitType,
      iteration,
      seedHi,
      seedLo,
      trafficSeedHi,
      trafficSeedLo,
      fullOnVariant,
      audienceStrict,
      audience,
      assignmentRules,
      listEquality.hash(split),
      listEquality.hash(trafficSplit),
      listEquality.hash(applications),
      listEquality.hash(variants),
    );
  }

  @override
  String toString() {
    return "ContextExperiment{id=$id, name='$name', unitType='$unitType', iteration=$iteration, seedHi=$seedHi, seedLo=$seedLo, split=$split, trafficSeedHi=$trafficSeedHi, trafficSeedLo=$trafficSeedLo, trafficSplit=$trafficSplit, fullOnVariant=$fullOnVariant, applications=$applications, variants=$variants, audienceStrict=$audienceStrict, audience='$audience', assignmentRules='$assignmentRules'}";
  }

  Experiment.fromMap(Map<String, dynamic> data) {
    id = data["id"];
    name = data["name"];
    unitType = data["unitType"];
    iteration = data["iteration"];
    seedHi = data["seedHi"];
    seedLo = data["seedLo"];
    split = _parseDoubleList(data, 'split');
    trafficSeedHi = data["trafficSeedHi"];
    trafficSeedLo = data["trafficSeedLo"];
    trafficSplit = _parseDoubleList(data, 'trafficSplit');
    fullOnVariant = data["fullOnVariant"];
    List applications = data["applications"] ?? [];
    this.applications = List.generate(applications.length,
        (index) => ExperimentApplication.fromMap(applications[index]));

    List variants = data["variants"];
    this.variants = List.generate(
        variants.length, (index) => ExperimentVariant.fromMap(variants[index]));

    audienceStrict = data["audienceStrict"] ?? false;
    audience = data["audience"];
    assignmentRules = _parseAssignmentRules(data["assignmentRules"]);
    final rawCustomFields = data["customFieldValues"];
    if (rawCustomFields != null) {
      customFieldValues = (rawCustomFields as List)
          .map((e) => CustomFieldValue.fromMap(e as Map<String, dynamic>))
          .toList();
    } else {
      customFieldValues = null;
    }
    final rawHoldoutIds = data["holdoutIds"];
    if (rawHoldoutIds is List) {
      holdoutIds = _parseHoldoutIds(rawHoldoutIds);
    }
    final rawHoldoutType = data["holdoutType"];
    if (rawHoldoutType is String) {
      holdoutType = rawHoldoutType;
    }
  }

  static List<int> _parseHoldoutIds(List value) {
    final List<int> ids = [];
    for (final element in value) {
      final int? id = wholeNumber(element);
      if (id != null) {
        ids.add(id);
      }
    }
    return ids;
  }

  // The API sends assignmentRules as a JSON string. An object or array in its
  // place only drops this experiment's rules instead of failing the whole
  // context; other scalars are kept in their string form (Java
  // AssignmentRulesDeserializer).
  static String? _parseAssignmentRules(dynamic value) {
    if (value == null || value is String) {
      return value;
    }
    if (value is Map || value is List) {
      return null;
    }
    return value.toString();
  }

  // JSON has a single number type, so a producer may legitimately encode a
  // whole-number split weight as `1` instead of `1.0`. jsonDecode yields an
  // int for those on the VM, which cannot be stored in a List<double> as-is.
  static List<double> _parseDoubleList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! List) {
      throw FormatException('Invalid experiment $key: $value');
    }
    return List<double>.generate(value.length, (index) {
      final element = value[index];
      if (element is! num) {
        throw FormatException('Invalid experiment $key element: $element');
      }
      return element.toDouble();
    });
  }

  Map<String, dynamic> toMap() {
    List applications = List.generate(
        this.applications.length, (index) => this.applications[index].toMap());
    List variants = List.generate(
        this.variants.length, (index) => this.variants[index].toMap());

    return {
      "id": id,
      "name": name,
      "unitType": unitType,
      "iteration": iteration,
      "seedHi": seedHi,
      "seedLo": seedLo,
      "split": split,
      "trafficSeedHi": trafficSeedHi,
      "trafficSeedLo": trafficSeedLo,
      "trafficSplit": trafficSplit,
      "fullOnVariant": fullOnVariant,
      "applications": applications,
      "variants": variants,
      "audienceStrict": audienceStrict,
      "audience": audience,
      if (assignmentRules != null) "assignmentRules": assignmentRules,
      if (customFieldValues != null)
        "customFieldValues": customFieldValues!.map((e) => e.toMap()).toList(),
      if (_holdoutIdList != null) "holdoutIds": _holdoutIdList,
      if (_holdoutTypeValue != null) "holdoutType": _holdoutTypeValue,
    };
  }
}

// Holdout fields of a customer class that implements Experiment, which has no
// private fields to hold them.
final Expando<List<int>> _foreignHoldoutIds = Expando<List<int>>();
final Expando<String> _foreignHoldoutTypes = Expando<String>();

/// The holdout fields of an [Experiment]. An extension rather than members of
/// [Experiment], so existing classes that implement it keep compiling.
extension ExperimentHoldouts on Experiment {
  /// The ids of the holdouts (in the payload's `holdouts`) that cover this
  /// experiment. Null or empty when it is not covered.
  List<int>? get holdoutIds {
    try {
      return _holdoutIdList;
    } on NoSuchMethodError {
      return _foreignHoldoutIds[this];
    }
  }

  set holdoutIds(List<int>? holdoutIds) {
    try {
      _holdoutIdList = holdoutIds;
    } on NoSuchMethodError {
      _foreignHoldoutIds[this] = holdoutIds;
    }
  }

  /// Set only on holdout entries sent in the legacy experiment shape
  /// (`"full"`, `"all_full_on"`). Informational: the SDK derives a holdout's
  /// arm count from its split.
  String? get holdoutType {
    try {
      return _holdoutTypeValue;
    } on NoSuchMethodError {
      return _foreignHoldoutTypes[this];
    }
  }

  set holdoutType(String? holdoutType) {
    try {
      _holdoutTypeValue = holdoutType;
    } on NoSuchMethodError {
      _foreignHoldoutTypes[this] = holdoutType;
    }
  }
}
