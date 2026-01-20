import 'package:flutter/foundation.dart';

import 'experiment.dart';

class ContextData {
  late List<Experiment> experiments;

  ContextData({this.experiments = const []});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContextData && listEquals(other.experiments, experiments);
  }

  @override
  int get hashCode {
    return experiments.hashCode;
  }

  @override
  String toString() {
    return "ContextData{experiments=$experiments}";
  }

  ContextData.fromMap(Map<String, dynamic> data) {
    List experiments = data["experiments"] ?? [];
    this.experiments = List.generate(
        experiments.length, (index) => Experiment.fromMap(experiments[index]));
  }

  Map<String, dynamic> toMap() {
    List experiments = List.generate(
        this.experiments.length, (index) => this.experiments[index].toMap());
    return {
      "experiments": experiments,
    };
  }
}
