import 'dart:convert';
import 'dart:typed_data';

import 'package:absmartly_dart/src/context_data_deserializer.dart';
import 'package:absmartly_dart/src/default_context_data_serializer.dart';
import 'package:absmartly_dart/src/json/context_data.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:absmartly_dart/src/json/experiment_variant.dart';
import 'package:absmartly_dart/src/json/experiment_application.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group("DefaultContextDataDeserializerTest", () {
    test("deserialize", () async {
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

    // JSON has one number type, so a whole-number weight may arrive as `1`
    // rather than `1.0` (the collector emits `double[]`, but any JSON
    // producer, proxy or re-encoder in between may drop the fraction).
    Map<String, dynamic> experimentJson(
        {required List<num> split, required List<num> trafficSplit}) {
      return {
        'id': 1,
        'name': 'exp_int_split',
        'unitType': 'session_id',
        'iteration': 1,
        'seedHi': 3603515,
        'seedLo': 233373850,
        'split': split,
        'trafficSeedHi': 449867249,
        'trafficSeedLo': 455443629,
        'trafficSplit': trafficSplit,
        'fullOnVariant': 0,
        'applications': [
          {'name': 'website'}
        ],
        'variants': [
          {'name': 'A', 'config': null},
          {'name': 'B', 'config': null}
        ],
        'audience': '',
      };
    }

    ContextData? deserializeJson(Object json) {
      final bytes = utf8.encode(jsonEncode(json));
      return DefaultContextDataDeserializer()
          .deserialize(bytes, 0, bytes.length);
    }

    test('deserializeIntegerTrafficSplitAsDoubles', () {
      final data = deserializeJson({
        'experiments': [
          experimentJson(split: [0.5, 0.5], trafficSplit: [0, 1])
        ]
      });

      expect(data, isNotNull);
      final experiment = data!.experiments.single;
      expect(experiment.trafficSplit, [0.0, 1.0]);
      expect(experiment.trafficSplit, everyElement(isA<double>()));
      expect(experiment.split, [0.5, 0.5]);
    });

    test('deserializeIntegerSplitAsDoubles', () {
      final data = deserializeJson({
        'experiments': [
          experimentJson(split: [1, 0], trafficSplit: [0, 1])
        ]
      });

      expect(data, isNotNull);
      final experiment = data!.experiments.single;
      expect(experiment.split, [1.0, 0.0]);
      expect(experiment.split, everyElement(isA<double>()));
    });

    test('deserializeIntegerSplitsEqualsDoubleSplits', () {
      final fromInts = deserializeJson({
        'experiments': [
          experimentJson(split: [1, 0], trafficSplit: [0, 1])
        ]
      });
      final fromDoubles = deserializeJson({
        'experiments': [
          experimentJson(split: [1.0, 0.0], trafficSplit: [0.0, 1.0])
        ]
      });

      expect(fromInts, isNotNull);
      expect(fromInts, fromDoubles);
    });

    test('deserializeIgnoresUnknownFields', () {
      final data = deserializeJson({
        'experiments': [
          {
            ...experimentJson(split: [0.5, 0.5], trafficSplit: [0, 1]),
            'holdoutIds': [7],
            'assignmentRules': '{}',
            'someFutureField': {'nested': true},
          }
        ],
        'holdouts': [],
        'someFutureTopLevelField': 1,
      });

      expect(data, isNotNull);
      expect(data!.experiments.single.trafficSplit, [0.0, 1.0]);
    });

    test('deserializeRejectsNonNumericSplitEntries', () {
      final data = deserializeJson({
        'experiments': [
          experimentJson(split: [0.5, 0.5], trafficSplit: [0, 1])
            ..['trafficSplit'] = ['0', '1']
        ]
      });

      expect(data, isNull);
    });
  });
}
