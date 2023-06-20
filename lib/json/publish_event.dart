import 'dart:ui';

import 'package:absmartly_sdk/json/unit.dart';
import 'package:flutter/foundation.dart';

import 'attribute.dart';
import 'exposure.dart';
import 'goal_achievement.dart';

class PublishEvent {
  late bool hashed;
  late List<Unit> units;
  late int publishedAt;
  late List<Exposure> exposures;
  late List<GoalAchievement> goals;
  List<Attribute> attributes = [];

  PublishEvent({required this.hashed, required this.units, required this.publishedAt, required this.exposures, required this.goals, required this.attributes});

  @override
  bool operator ==(dynamic o) {
    if (identical(this, o)) return true;
    return o is PublishEvent &&
        o.hashed == hashed &&
        o.publishedAt == publishedAt &&
        listEquals(o.units, units) &&
        listEquals(o.exposures, exposures) &&
        listEquals(o.goals, goals) &&
        listEquals(o.attributes, attributes);
  }

  @override
  int get hashCode {
    int result = hashValues(hashed, publishedAt);
    result = 31 * result + units.hashCode;
    result = 31 * result + exposures.hashCode;
    result = 31 * result + goals.hashCode;
    result = 31 * result + attributes.hashCode;
    return result;
  }

  @override
  String toString() {
    return "PublishEvent{hashedUnits=$hashed, units=$units, publishedAt=$publishedAt, exposures=$exposures, goals=$goals, attributes=$attributes}";
  }

  PublishEvent.fromMap(Map<String, dynamic> data){
    hashed = data["hashed"];

    List units = data["units"] ?? [];
    this.units = List.generate(units.length, (index) => Unit.fromMap(units[index]));
    publishedAt = data["publishedAt"];
    List exposures = data["exposures"] ?? [];
    this.exposures = List.generate(exposures.length, (index) => Exposure.fromMap(exposures[index]));

    List goals = data["goals"] ?? [];
    this.goals = List.generate(goals.length, (index) => GoalAchievement.fromMap(goals[index]));

    List attributes = data["attributes"] ?? [];
    this.attributes = List.generate(attributes.length, (index) => Attribute.fromMap(attributes[index]));
  }
  Map<String, dynamic> toMap(){

    List units =  List.generate(this.units.length, (index) => this.units[index].toMap());
    List exposures = List.generate(this.exposures.length, (index) => this.exposures[index].toMap());
    List goals = List.generate(this.goals.length, (index) => this.goals[index].toMap());
    List attributes = List.generate(this.attributes.length, (index) => this.attributes[index].toMap());

    return {
      "hashed" : hashed,
      "units" : units,
      "publishedAt" : publishedAt,
      "exposures" : exposures,
      "goals" : goals,
      "attributes" : attributes,
    };
  }
}