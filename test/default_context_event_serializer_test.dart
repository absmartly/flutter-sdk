import 'dart:convert';
import 'dart:typed_data';

import 'package:absmartly_sdk/context_event_serializer.dart';
import 'package:absmartly_sdk/default_context_event_serializer.dart';
import 'package:absmartly_sdk/json/attribute.dart';
import 'package:absmartly_sdk/json/exposure.dart';
import 'package:absmartly_sdk/json/goal_achievement.dart';
import 'package:absmartly_sdk/json/publish_event.dart';
import 'package:absmartly_sdk/json/unit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';


// not working

void main() {
  group("DefaultContextEventSerializerTest", () {
    test("serialize", () {
      final event = PublishEvent(
        hashed: true,
        units: [
          Unit(type: "session_id", uid: "pAE3a1i5Drs5mKRNq56adA"),
          Unit(type: "user_id",uid: "JfnnlDI7RTiF9RgfG2JNCw"),
        ],
        publishedAt: 123456789,
        exposures: [
          Exposure(id: 1, name: "exp_test_ab", unit: "session_id", variant: 1, exposedAt: 123470000, assigned: true, eligible: true, overridden: false, fullOn: false, custom: false, audienceMismatch: true),
        ],
        goals: [
          GoalAchievement(name: "goal1",  achievedAt :123456000,properties: {
            "amount": 6,
            "value": 5.0,
            "tries": 1,
            "nested": {"value": 5},
            "nested_arr": {"nested": [1, 2, "test"]}
          }),
          GoalAchievement(name: "goal2",  achievedAt :123456789,properties: null),
        ],
        attributes: [
          Attribute(name: "attr1", value: "value1",setAt: 123456000),
          Attribute(name: "attr2", value: "value2", setAt: 123456789),
          Attribute(name: "attr2", value: null, setAt: 123450000),
          Attribute(name: "attr3", value: {"nested": {"value": 5},},setAt: 123470000),
          Attribute(name: "attr4", value: {"nested": [1, 2, "test"]},setAt: 123480000),
        ],
      );

      final ContextEventSerializer ser = DefaultContextEventSerializer();
      final Uint8List bytes = Uint8List.fromList(ser.serialize(event) ?? []);

      print(utf8.decode(bytes));
      expect(utf8.decode(bytes), equals('{"hashed":true,"units":[{"type":"session_id","uid":"pAE3a1i5Drs5mKRNq56adA"},{"type":"user_id","uid":"JfnnlDI7RTiF9RgfG2JNCw"}],"publishedAt":123456789,"exposures":[{"id":1,"name":"exp_test_ab","unit":"session_id","variant":1,"exposedAt":123470000,"assigned":true,"eligible":true,"overridden":false,"fullOn":false,"custom":false,"audienceMismatch":true}],"goals":[{"name":"goal1","achievedAt":123456000,"properties":{"amount":6,"value":5.0,"tries":1,"nested":{"value":5},"nested_arr":{"nested":[1,2,"test"]}}},{"name":"goal2","achievedAt":123456789,"properties":null}],"attributes":[{"name":"attr1","value":"value1","setAt":123456000},{"name":"attr2","value":"value2","setAt":123456789},{"name":"attr2","value":null,"setAt":123450000},{"name":"attr3","value":{"nested":{"value":5}},"setAt":123470000},{"name":"attr4","value":{"nested":[1,2,"test"]},"setAt":123480000}]}'));

    });

  });
}
