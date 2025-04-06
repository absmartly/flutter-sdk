import 'dart:typed_data';

import 'package:absmartly_sdk/context_data_deserializer.dart';
import 'package:absmartly_sdk/default_context_data_serializer.dart';
import 'package:absmartly_sdk/json/context_data.dart';
import 'package:absmartly_sdk/json/experiment.dart';
import 'package:absmartly_sdk/json/experiment_variant.dart';
import 'package:absmartly_sdk/json/experimet_application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  group("DefaultContextDataDeserializerTest", () {
    test("deserialize", () async {
      WidgetsFlutterBinding.ensureInitialized();
      final Uint8List bytes =
          Uint8List.fromList(await getResourceBytes("context.json"));

      final ContextDataDeserializer deser = DefaultContextDataDeserializer();
      final ContextData? data = deser.deserialize(bytes, 0, bytes.length);

      final experiment0 = Experiment(
        id: 1,
        name: 'exp_test_ab',
        unitType: 'session_id',
        iteration: 1,
        seedHi: 3603515,
        seedLo: 233373850,
        split: [0.5, 0.5],
        trafficSeedHi: 449867249,
        trafficSeedLo: 455443629,
        trafficSplit: [0.0, 1.0],
        fullOnVariant: 0,
        applications: [ExperimentApplication(name: 'website')],
        variants: [
          ExperimentVariant(name: 'A', config: null),
          ExperimentVariant(
              name: 'B', config: '{"banner.border":1,"banner.size":"large"}')
        ],
        audienceStrict: false,
        audience: null,
      );

      final Experiment experiment1 = Experiment(
        id: 2,
        name: "exp_test_abc",
        unitType: "session_id",
        iteration: 1,
        seedHi: 55006150,
        seedLo: 47189152,
        split: [0.34, 0.33, 0.33],
        trafficSeedHi: 705671872,
        trafficSeedLo: 212903484,
        trafficSplit: [0.0, 1.0],
        fullOnVariant: 0,
        applications: [ExperimentApplication(name: "website")],
        variants: [
          ExperimentVariant(name: "A", config: null),
          ExperimentVariant(name: "B", config: "{\"button.color\":\"blue\"}"),
          ExperimentVariant(name: "C", config: "{\"button.color\":\"red\"}")
        ],
        audienceStrict: false,
        audience: "",
      );

      final Experiment experiment2 = Experiment(
        id: 3,
        name: "exp_test_not_eligible",
        unitType: "user_id",
        iteration: 1,
        seedHi: 503266407,
        seedLo: 144942754,
        split: [0.34, 0.33, 0.33],
        trafficSeedHi: 87768905,
        trafficSeedLo: 511357582,
        trafficSplit: [0.99, 0.01],
        fullOnVariant: 0,
        applications: [ExperimentApplication(name: "website")],
        variants: [
          ExperimentVariant(name: "A", config: null),
          ExperimentVariant(name: "B", config: "{\"card.width\":\"80%\"}"),
          ExperimentVariant(name: "C", config: "{\"card.width\":\"75%\"}")
        ],
        audienceStrict: false,
        audience: "{}",
      );

      final Experiment experiment3 = Experiment(
        id: 4,
        name: "exp_test_fullon",
        unitType: "session_id",
        iteration: 1,
        seedHi: 856061641,
        seedLo: 990838475,
        split: [0.25, 0.25, 0.25, 0.25],
        trafficSeedHi: 360868579,
        trafficSeedLo: 330937933,
        trafficSplit: [0.0, 1.0],
        fullOnVariant: 2,
        applications: [ExperimentApplication(name: "website")],
        variants: [
          ExperimentVariant(name: "A", config: null),
          ExperimentVariant(
              name: "B",
              config: "{\"submit.color\":\"red\",\"submit.shape\":\"circle\"}"),
          ExperimentVariant(
              name: "C",
              config: "{\"submit.color\":\"blue\",\"submit.shape\":\"rect\"}"),
          ExperimentVariant(
              name: "D",
              config:
                  "{\"submit.color\":\"green\",\"submit.shape\":\"square\"}")
        ],
        audienceStrict: false,
        audience: "null",
      );
      final expected = ContextData();
      expected.experiments = [
        experiment0,
        experiment1,
        experiment2,
        experiment3
      ];
      expect(data, expected);
    });
  });
}
