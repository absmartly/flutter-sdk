
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GoalAchievement {
  late String name;
  late int achievedAt;
  Map<String, dynamic>? properties;

  GoalAchievement({required this.name, required this.achievedAt, required this.properties});

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is GoalAchievement &&
        achievedAt == other.achievedAt &&
        name == other.name &&
        mapEquals(properties, other.properties);
  }

  @override
  int get hashCode => hashValues(name, achievedAt, properties);

  @override
  String toString() {
    return 'GoalAchievement{name: $name, achievedAt: $achievedAt, properties: $properties}';
  }


  GoalAchievement.fromMap(Map<String, dynamic> data){
    name = data["name"];
    achievedAt = data["achievedAt"];
    properties = data["properties"];
  }

  Map<String, dynamic> toMap(){
    return {
      "name" : name,
      "achievedAt" : achievedAt,
      "properties" : properties,
    };
  }
}