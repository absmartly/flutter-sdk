class ExperimentVariant {
  late String name;
  String? config;

  ExperimentVariant({required this.name, required this.config});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExperimentVariant &&
            name == other.name &&
            config == other.config;
  }

  @override
  int get hashCode => Object.hash(name, config);

  @override
  String toString() {
    return 'ExperimentVariant{name: $name, config: $config}';
  }

  ExperimentVariant.fromMap(Map<String, dynamic> data) {
    name = data["name"];
    config = data["config"];
  }

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "config": config,
    };
  }
}
