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
  // The switchback fields, read through [ExperimentSwitchback]; null when the
  // payload has none of them.
  _SwitchbackFields? _switchbackFields;

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
    String? randomizationType,
    Map<String, String?>? switchbackClusters,
    List<String>? switchbackClusterValues,
    int? switchbackStartAt,
    int? switchbackPeriodMs,
    int? switchbackCarryoverDurationMs,
    int? switchbackBurnInDurationMs,
    int? switchbackBurnOutDurationMs,
    String? switchbackDesignType,
    String? switchbackEstimand,
  })  : _holdoutIdList = holdoutIds,
        _holdoutTypeValue = holdoutType {
    if (randomizationType != null ||
        switchbackClusters != null ||
        switchbackClusterValues != null ||
        switchbackStartAt != null ||
        switchbackPeriodMs != null ||
        switchbackCarryoverDurationMs != null ||
        switchbackBurnInDurationMs != null ||
        switchbackBurnOutDurationMs != null ||
        switchbackDesignType != null ||
        switchbackEstimand != null) {
      _switchbackFields = _SwitchbackFields()
        ..randomizationType = randomizationType
        ..clusters = switchbackClusters
        ..clusterValues = switchbackClusterValues
        ..startAt = switchbackStartAt
        ..periodMs = switchbackPeriodMs
        ..carryoverDurationMs = switchbackCarryoverDurationMs
        ..burnInDurationMs = switchbackBurnInDurationMs
        ..burnOutDurationMs = switchbackBurnOutDurationMs
        ..designType = switchbackDesignType
        ..estimand = switchbackEstimand;
    }
  }

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
            holdoutType == other.holdoutType &&
            randomizationType == other.randomizationType &&
            switchbackClustersEqual(
                switchbackClusters, other.switchbackClusters) &&
            const ListEquality().equals(
                switchbackClusterValues, other.switchbackClusterValues) &&
            switchbackStartAt == other.switchbackStartAt &&
            switchbackPeriodMs == other.switchbackPeriodMs &&
            switchbackCarryoverDurationMs ==
                other.switchbackCarryoverDurationMs &&
            switchbackBurnInDurationMs == other.switchbackBurnInDurationMs &&
            switchbackBurnOutDurationMs == other.switchbackBurnOutDurationMs &&
            switchbackDesignType == other.switchbackDesignType &&
            switchbackEstimand == other.switchbackEstimand;
  }

  /// Whether two `switchbackClusters` maps hold the same entries in the same
  /// order. The order is semantic: the first linked unit, in declared order,
  /// whose path yields a value serves the experiment.
  static bool switchbackClustersEqual(
      final Map<String, String?>? a, final Map<String, String?>? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null || a.length != b.length) {
      return false;
    }
    final Iterator<MapEntry<String, String?>> ia = a.entries.iterator;
    final Iterator<MapEntry<String, String?>> ib = b.entries.iterator;
    while (ia.moveNext() && ib.moveNext()) {
      if (ia.current.key != ib.current.key ||
          ia.current.value != ib.current.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    const listEquality = ListEquality();
    final int hash = Object.hash(
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
    // Unchanged for an experiment without switchback fields.
    return _switchbackFields == null
        ? hash
        : Object.hash(hash, _switchbackHash(this));
  }

  static int _switchbackHash(final Experiment e) {
    final Map<String, String?>? clusters = e.switchbackClusters;
    return Object.hash(
      e.randomizationType,
      clusters == null
          ? null
          : Object.hashAll([
              for (final entry in clusters.entries) ...[entry.key, entry.value]
            ]),
      const ListEquality().hash(e.switchbackClusterValues),
      e.switchbackStartAt,
      e.switchbackPeriodMs,
      e.switchbackCarryoverDurationMs,
      e.switchbackBurnInDurationMs,
      e.switchbackBurnOutDurationMs,
      e.switchbackDesignType,
      e.switchbackEstimand,
    );
  }

  @override
  String toString() {
    return "ContextExperiment{id=$id, name='$name', unitType='$unitType', iteration=$iteration, seedHi=$seedHi, seedLo=$seedLo, split=$split, trafficSeedHi=$trafficSeedHi, trafficSeedLo=$trafficSeedLo, trafficSplit=$trafficSplit, fullOnVariant=$fullOnVariant, applications=$applications, variants=$variants, audienceStrict=$audienceStrict, audience='$audience', assignmentRules='$assignmentRules'${_switchbackFields == null ? "" : ", randomizationType='$randomizationType', switchbackClusters=$switchbackClusters, switchbackClusterValues=$switchbackClusterValues, switchbackStartAt=$switchbackStartAt, switchbackPeriodMs=$switchbackPeriodMs, switchbackCarryoverDurationMs=$switchbackCarryoverDurationMs, switchbackBurnInDurationMs=$switchbackBurnInDurationMs, switchbackBurnOutDurationMs=$switchbackBurnOutDurationMs, switchbackDesignType='$switchbackDesignType', switchbackEstimand='$switchbackEstimand'"}}";
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
    _switchbackFields = _SwitchbackFields.fromMap(data);
  }

  // Whole numbers up to 2^53 - 1 only; any other entry can't name a holdout
  // and is dropped.
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
      ...?_switchbackFields?.toMap(),
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

// The switchback wire fields. Instants and durations are epoch and duration
// milliseconds.
class _SwitchbackFields {
  _SwitchbackFields();

  String? randomizationType;
  Map<String, String?>? clusters;
  List<String>? clusterValues;
  int? startAt;
  int? periodMs;
  int? carryoverDurationMs;
  int? burnInDurationMs;
  int? burnOutDurationMs;
  String? designType;
  String? estimand;

  // Null when the payload has none of the fields, so an experiment without
  // them carries nothing. A field of the wrong type reads as absent; it never
  // fails the context.
  static _SwitchbackFields? fromMap(final Map<String, dynamic> data) {
    final randomizationType = data['randomizationType'];
    final clusters = data['switchbackClusters'];
    final clusterValues = data['switchbackClusterValues'];
    final startAt = data['switchbackStartAt'];
    final periodMs = data['switchbackPeriodMs'];
    final carryover = data['switchbackCarryoverDurationMs'];
    final burnIn = data['switchbackBurnInDurationMs'];
    final burnOut = data['switchbackBurnOutDurationMs'];
    final designType = data['switchbackDesignType'];
    final estimand = data['switchbackEstimand'];
    if (randomizationType == null &&
        clusters == null &&
        clusterValues == null &&
        startAt == null &&
        periodMs == null &&
        carryover == null &&
        burnIn == null &&
        burnOut == null &&
        designType == null &&
        estimand == null) {
      return null;
    }
    return _SwitchbackFields()
      ..randomizationType =
          randomizationType is String ? randomizationType : null
      ..clusters = _parseClusters(clusters)
      ..clusterValues = _parseClusterValues(clusterValues)
      ..startAt = _parseMillis(startAt)
      ..periodMs = _parseMillis(periodMs)
      ..carryoverDurationMs = _parseMillis(carryover)
      ..burnInDurationMs = _parseMillis(burnIn)
      ..burnOutDurationMs = _parseMillis(burnOut)
      ..designType = designType is String ? designType : null
      ..estimand = estimand is String ? estimand : null;
  }

  // Kept in the payload's key order, which is semantic. A number or boolean
  // path is read as its text, as Java's decoder does; any other non-string
  // path reads as null, which makes the map unreadable (the legacy path).
  static Map<String, String?>? _parseClusters(final dynamic value) {
    if (value is! Map) {
      return null;
    }
    final Map<String, String?> clusters = <String, String?>{};
    value.forEach((key, path) {
      clusters[key.toString()] =
          (path is String || path is num || path is bool) ? '$path' : null;
    });
    return Map.unmodifiable(clusters);
  }

  // A non-string entry is kept in its text form rather than dropped, so a
  // malformed allow-list never widens into "every value".
  static List<String>? _parseClusterValues(final dynamic value) {
    if (value is! List) {
      return null;
    }
    return List.unmodifiable([
      for (final element in value) element is String ? element : '$element'
    ]);
  }

  static int? _parseMillis(final dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      return value.toInt();
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      if (randomizationType != null) 'randomizationType': randomizationType,
      if (clusters != null) 'switchbackClusters': clusters,
      if (clusterValues != null) 'switchbackClusterValues': clusterValues,
      if (startAt != null) 'switchbackStartAt': startAt,
      if (periodMs != null) 'switchbackPeriodMs': periodMs,
      if (carryoverDurationMs != null)
        'switchbackCarryoverDurationMs': carryoverDurationMs,
      if (burnInDurationMs != null)
        'switchbackBurnInDurationMs': burnInDurationMs,
      if (burnOutDurationMs != null)
        'switchbackBurnOutDurationMs': burnOutDurationMs,
      if (designType != null) 'switchbackDesignType': designType,
      if (estimand != null) 'switchbackEstimand': estimand,
    };
  }
}

// Switchback fields of a customer class that implements Experiment, which has
// no private field to hold them.
final Expando<_SwitchbackFields> _foreignSwitchbackFields =
    Expando<_SwitchbackFields>();

/// The switchback fields of an [Experiment]. An extension rather than members
/// of [Experiment], so existing classes that implement it keep compiling.
///
/// A switchback experiment (`randomizationType == "switchback"`) is
/// randomized over clusters and time: see "Switchback experiments" in the
/// README.
extension ExperimentSwitchback on Experiment {
  _SwitchbackFields? get _fields {
    try {
      return _switchbackFields;
    } on NoSuchMethodError {
      return _foreignSwitchbackFields[this];
    }
  }

  _SwitchbackFields get _writableFields {
    try {
      return _switchbackFields ??= _SwitchbackFields();
    } on NoSuchMethodError {
      return _foreignSwitchbackFields[this] ??= _SwitchbackFields();
    }
  }

  /// `"unit"` or `"switchback"`; null means a unit experiment.
  String? get randomizationType => _fields?.randomizationType;
  set randomizationType(String? value) =>
      _writableFields.randomizationType = value;

  /// Unit type name to cluster attribute path, in the served order. The
  /// order is semantic and is kept as received.
  Map<String, String?>? get switchbackClusters => _fields?.clusters;
  set switchbackClusters(Map<String, String?>? value) =>
      _writableFields.clusters = value;

  /// Allowed cluster values; null or empty allows every value.
  List<String>? get switchbackClusterValues => _fields?.clusterValues;
  set switchbackClusterValues(List<String>? value) =>
      _writableFields.clusterValues = value;

  /// Start of the period grid (the anchor), in epoch milliseconds.
  int? get switchbackStartAt => _fields?.startAt;
  set switchbackStartAt(int? value) => _writableFields.startAt = value;

  /// Period length in milliseconds.
  int? get switchbackPeriodMs => _fields?.periodMs;
  set switchbackPeriodMs(int? value) => _writableFields.periodMs = value;

  /// Analysis only; not used for assignment.
  int? get switchbackCarryoverDurationMs => _fields?.carryoverDurationMs;
  set switchbackCarryoverDurationMs(int? value) =>
      _writableFields.carryoverDurationMs = value;

  /// Analysis only; not used for assignment.
  int? get switchbackBurnInDurationMs => _fields?.burnInDurationMs;
  set switchbackBurnInDurationMs(int? value) =>
      _writableFields.burnInDurationMs = value;

  /// Analysis only; not used for assignment.
  int? get switchbackBurnOutDurationMs => _fields?.burnOutDurationMs;
  set switchbackBurnOutDurationMs(int? value) =>
      _writableFields.burnOutDurationMs = value;

  String? get switchbackDesignType => _fields?.designType;
  set switchbackDesignType(String? value) => _writableFields.designType = value;

  /// Analysis only; not used for assignment.
  String? get switchbackEstimand => _fields?.estimand;
  set switchbackEstimand(String? value) => _writableFields.estimand = value;
}
