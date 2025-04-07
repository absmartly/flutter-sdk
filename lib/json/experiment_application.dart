class ExperimentApplication {
  late String name;

  ExperimentApplication({required this.name});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExperimentApplication && name == other.name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return 'ExperimentApplication{name: $name}';
  }

  ExperimentApplication.fromMap(Map<String, dynamic> data) {
    name = data["name"];
  }

  Map<String, dynamic> toMap() {
    return {
      "name": name,
    };
  }
}
