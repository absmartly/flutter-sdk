import 'package:collection/collection.dart';

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
  late List<CustomFieldValue>? customFieldValues;

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
    this.customFieldValues,
  });

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
            audience == other.audience;
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
      listEquality.hash(split),
      listEquality.hash(trafficSplit),
      listEquality.hash(applications),
      listEquality.hash(variants),
    );
  }

  @override
  String toString() {
    return "ContextExperiment{id=$id, name='$name', unitType='$unitType', iteration=$iteration, seedHi=$seedHi, seedLo=$seedLo, split=$split, trafficSeedHi=$trafficSeedHi, trafficSeedLo=$trafficSeedLo, trafficSplit=$trafficSplit, fullOnVariant=$fullOnVariant, applications=$applications, variants=$variants, audienceStrict=$audienceStrict, audience='$audience'}";
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
    final rawCustomFields = data["customFieldValues"];
    if (rawCustomFields != null) {
      customFieldValues = (rawCustomFields as List)
          .map((e) => CustomFieldValue.fromMap(e as Map<String, dynamic>))
          .toList();
    } else {
      customFieldValues = null;
    }
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
      if (customFieldValues != null)
        "customFieldValues": customFieldValues!.map((e) => e.toMap()).toList(),
    };
  }
}
