// A customer class implementing the released Experiment (absmartly_sdk
// 2.1.2), and a minimal experiment payload. Shared by the compat tests; no
// dart:io, so web suites can use it.
import 'package:absmartly_dart/absmartly_dart.dart';

class LegacyExperiment implements Experiment {
  LegacyExperiment(this._delegate);

  final Experiment _delegate;

  @override
  int get id => _delegate.id;
  @override
  set id(int value) => _delegate.id = value;
  @override
  String get name => _delegate.name;
  @override
  set name(String value) => _delegate.name = value;
  @override
  String get unitType => _delegate.unitType;
  @override
  set unitType(String value) => _delegate.unitType = value;
  @override
  int get iteration => _delegate.iteration;
  @override
  set iteration(int value) => _delegate.iteration = value;
  @override
  int get seedHi => _delegate.seedHi;
  @override
  set seedHi(int value) => _delegate.seedHi = value;
  @override
  int get seedLo => _delegate.seedLo;
  @override
  set seedLo(int value) => _delegate.seedLo = value;
  @override
  List<double> get split => _delegate.split;
  @override
  set split(List<double> value) => _delegate.split = value;
  @override
  int get trafficSeedHi => _delegate.trafficSeedHi;
  @override
  set trafficSeedHi(int value) => _delegate.trafficSeedHi = value;
  @override
  int get trafficSeedLo => _delegate.trafficSeedLo;
  @override
  set trafficSeedLo(int value) => _delegate.trafficSeedLo = value;
  @override
  List<double> get trafficSplit => _delegate.trafficSplit;
  @override
  set trafficSplit(List<double> value) => _delegate.trafficSplit = value;
  @override
  int get fullOnVariant => _delegate.fullOnVariant;
  @override
  set fullOnVariant(int value) => _delegate.fullOnVariant = value;
  @override
  List<ExperimentApplication> get applications => _delegate.applications;
  @override
  set applications(List<ExperimentApplication> value) =>
      _delegate.applications = value;
  @override
  List<ExperimentVariant> get variants => _delegate.variants;
  @override
  set variants(List<ExperimentVariant> value) => _delegate.variants = value;
  @override
  bool get audienceStrict => _delegate.audienceStrict;
  @override
  set audienceStrict(bool value) => _delegate.audienceStrict = value;
  @override
  String? get audience => _delegate.audience;
  @override
  set audience(String? value) => _delegate.audience = value;
  @override
  String? get assignmentRules => _delegate.assignmentRules;
  @override
  set assignmentRules(String? value) => _delegate.assignmentRules = value;
  @override
  List<CustomFieldValue>? get customFieldValues => _delegate.customFieldValues;
  @override
  set customFieldValues(List<CustomFieldValue>? value) =>
      _delegate.customFieldValues = value;
  @override
  Map<String, dynamic> toMap() => _delegate.toMap();
}

Map<String, dynamic> experimentMap() => {
      'id': 1,
      'name': 'exp',
      'unitType': 'session_id',
      'iteration': 1,
      'seedHi': 0,
      'seedLo': 0,
      'split': [0.5, 0.5],
      'trafficSeedHi': 0,
      'trafficSeedLo': 0,
      'trafficSplit': [0.0, 1.0],
      'fullOnVariant': 0,
      'applications': [],
      'variants': [
        {'name': 'A', 'config': null},
        {'name': 'B', 'config': null}
      ],
    };
