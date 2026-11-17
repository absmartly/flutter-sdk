import 'package:collection/collection.dart';

import 'context_holdout.dart';
import 'experiment.dart';

class ContextData {
  late List<Experiment> experiments;
  // Library-private, so classes implementing ContextData in other libraries
  // are not required to declare it; read through [ContextDataHoldouts]. A
  // field (unlike an Expando) travels with the object across isolates.
  List<ContextHoldout>? _holdoutList;

  ContextData({this.experiments = const [], List<ContextHoldout>? holdouts}) {
    if (holdouts != null) {
      this.holdouts = holdouts;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContextData &&
        const ListEquality().equals(other.experiments, experiments) &&
        const ListEquality().equals(other.holdouts, holdouts);
  }

  @override
  int get hashCode {
    return experiments.hashCode;
  }

  @override
  String toString() {
    final List<ContextHoldout>? holdouts = _holdoutList;
    return holdouts == null
        ? "ContextData{experiments=$experiments}"
        : "ContextData{experiments=$experiments, holdouts=$holdouts}";
  }

  ContextData.fromMap(Map<String, dynamic> data) {
    List experiments = data["experiments"] ?? [];
    this.experiments = List.generate(
        experiments.length, (index) => Experiment.fromMap(experiments[index]));

    final rawHoldouts = data["holdouts"];
    if (rawHoldouts is List) {
      // A malformed entry is dropped on its own, like an entry the SDK cannot
      // serve; it never fails the context.
      final List<ContextHoldout> holdouts = [];
      for (final entry in rawHoldouts) {
        if (entry is Map<String, dynamic>) {
          try {
            holdouts.add(ContextHoldout.fromMap(entry));
          } on FormatException {
            // skipped
          }
        }
      }
      this.holdouts = holdouts;
    }
  }

  Map<String, dynamic> toMap() {
    List experiments = List.generate(
        this.experiments.length, (index) => this.experiments[index].toMap());
    final List<ContextHoldout>? holdouts = _holdoutList;
    return {
      "experiments": experiments,
      if (holdouts != null)
        "holdouts": holdouts.map((holdout) => holdout.toMap()).toList(),
    };
  }
}

// Holdouts of a customer class that implements ContextData, which has no
// private field to hold them.
final Expando<List<ContextHoldout>> _foreignHoldouts =
    Expando<List<ContextHoldout>>();

/// The holdouts of a [ContextData] (the payload's top-level `holdouts`
/// array). An extension rather than a member of [ContextData], so existing
/// classes that implement it keep compiling.
extension ContextDataHoldouts on ContextData {
  /// The holdouts that experiments reference through
  /// [ExperimentHoldouts.holdoutIds]; empty when the payload has none.
  List<ContextHoldout> get holdouts {
    try {
      return _holdoutList ?? const [];
    } on NoSuchMethodError {
      // A customer class that implements ContextData has no private field.
      return _foreignHoldouts[this] ?? const [];
    }
  }

  set holdouts(List<ContextHoldout> holdouts) {
    try {
      _holdoutList = holdouts;
    } on NoSuchMethodError {
      _foreignHoldouts[this] = holdouts;
    }
  }
}
