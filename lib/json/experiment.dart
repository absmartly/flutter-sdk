import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'experiment_varient.dart';
import 'experimet_application.dart';

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
            listEquals(split, other.split) &&
            listEquals(trafficSplit, other.trafficSplit) &&
            listEquals(applications, other.applications) &&
            listEquals(variants, other.variants) &&
            audienceStrict == other.audienceStrict &&
            audience == other.audience;
  }

  @override
  int get hashCode {
    int result = Object.hash(id, name, unitType, iteration, seedHi, seedLo,
        trafficSeedHi, trafficSeedLo, fullOnVariant, audienceStrict, audience);
    result = 31 * result + split.hashCode;
    result = 31 * result + trafficSplit.hashCode;
    result = 31 * result + applications.hashCode;
    result = 31 * result + variants.hashCode;
    return result;
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
    List split = data["split"];
    this.split = List.generate(split.length, (index) => split[index]);
    trafficSeedHi = data["trafficSeedHi"];
    trafficSeedLo = data["trafficSeedLo"];
    List trafficSplit = data["trafficSplit"];
    this.trafficSplit =
        List.generate(trafficSplit.length, (index) => trafficSplit[index]);
    fullOnVariant = data["fullOnVariant"];
    List applications = data["applications"] ?? [];
    this.applications = List.generate(applications.length,
        (index) => ExperimentApplication.fromMap(applications[index]));

    List variants = data["variants"];
    this.variants = List.generate(
        variants.length, (index) => ExperimentVariant.fromMap(variants[index]));

    audienceStrict = data["audienceStrict"] ?? false;
    audience = data["audience"];
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
    };
  }
}
