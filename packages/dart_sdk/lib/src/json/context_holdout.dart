import 'package:collection/collection.dart';

import '../internal/whole_number.dart';

/// A holdout from the context payload's top-level `holdouts` array.
///
/// An experiment lists the holdouts that cover it in `holdoutIds`. A covered
/// unit is hashed into one of the holdout's arms with [split] and the
/// holdout's seed; arm 0 holds the experiment out, and in a 3-arm holdout arm 1
/// holds out experiments that are not full-on. The arm count comes from
/// [split], never from [holdoutType].
class ContextHoldout {
  late int id;
  late String name;
  // Informational: a covered experiment is always hashed with its own unit
  // type, never this one.
  String? unitType;
  late int iteration;
  late int seedHi;
  late int seedLo;
  late List<double> split;
  String? holdoutType;

  ContextHoldout({
    required this.id,
    required this.name,
    this.unitType,
    required this.iteration,
    required this.seedHi,
    required this.seedLo,
    required this.split,
    this.holdoutType,
  });

  /// Reads a holdout entry; unknown keys are ignored. Only `id` and `split`
  /// are needed to serve a holdout (JS context.ts keeps every entry with a
  /// split); a missing name reads as "" and a missing iteration or seed as 0.
  /// Throws a [FormatException] when `id` or `split` is missing or malformed.
  ContextHoldout.fromMap(Map<String, dynamic> data) {
    final int? id = _int(data['id']);
    if (id == null) {
      throw FormatException('Invalid holdout id: ${data['id']}');
    }
    this.id = id;
    final name = data['name'];
    this.name = name is String ? name : '';
    final unitType = data['unitType'];
    this.unitType = unitType is String ? unitType : null;
    iteration = _int(data['iteration']) ?? 0;
    seedHi = _int(data['seedHi']) ?? 0;
    seedLo = _int(data['seedLo']) ?? 0;
    final split = data['split'];
    if (split is! List) {
      throw FormatException('Invalid holdout split: $split');
    }
    this.split = List<double>.generate(split.length, (index) {
      final element = split[index];
      if (element is! num) {
        throw FormatException('Invalid holdout split element: $element');
      }
      return element.toDouble();
    });
    final holdoutType = data['holdoutType'];
    this.holdoutType = holdoutType is String ? holdoutType : null;
  }

  static int? _int(dynamic value) => wholeNumber(value);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (unitType != null) 'unitType': unitType,
      'iteration': iteration,
      'seedHi': seedHi,
      'seedLo': seedLo,
      'split': split,
      if (holdoutType != null) 'holdoutType': holdoutType,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ContextHoldout &&
            id == other.id &&
            name == other.name &&
            unitType == other.unitType &&
            iteration == other.iteration &&
            seedHi == other.seedHi &&
            seedLo == other.seedLo &&
            const ListEquality().equals(split, other.split) &&
            holdoutType == other.holdoutType;
  }

  @override
  int get hashCode => Object.hash(id, name, unitType, iteration, seedHi, seedLo,
      const ListEquality().hash(split), holdoutType);

  @override
  String toString() {
    return "ContextHoldout{id=$id, name='$name', unitType='$unitType', iteration=$iteration, seedHi=$seedHi, seedLo=$seedLo, split=$split, holdoutType='$holdoutType'}";
  }
}
