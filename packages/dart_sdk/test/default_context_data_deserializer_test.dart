import 'dart:convert';
import 'dart:typed_data';

import 'package:absmartly_dart/src/context_data_deserializer.dart';
import 'package:absmartly_dart/src/default_context_data_serializer.dart';
import 'package:absmartly_dart/src/json/context_data.dart';
import 'package:absmartly_dart/src/json/context_holdout.dart';
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

    Map<String, dynamic> withRules(Object? rules) => {
          'experiments': [
            {
              ...experimentJson(split: [0.5, 0.5], trafficSplit: [0, 1]),
              'assignmentRules': rules,
            }
          ]
        };

    test('deserializeAssignmentRulesString', () {
      const rules = '{"rules":[{"type":"assign","variant":1}]}';
      final data = deserializeJson(withRules(rules));

      expect(data, isNotNull);
      expect(data!.experiments.single.assignmentRules, rules);
    });

    test('deserializeMissingOrNullAssignmentRules', () {
      final missing = deserializeJson({
        'experiments': [
          experimentJson(split: [0.5, 0.5], trafficSplit: [0, 1])
        ]
      });
      final nulled = deserializeJson(withRules(null));

      expect(missing!.experiments.single.assignmentRules, isNull);
      expect(nulled!.experiments.single.assignmentRules, isNull);
    });

    test('deserializeIgnoresObjectOrArrayAssignmentRules', () {
      final fromObject = deserializeJson(withRules({'rules': []}));
      final fromArray = deserializeJson(withRules([1, 2]));

      expect(fromObject, isNotNull);
      expect(fromObject!.experiments.single.assignmentRules, isNull);
      expect(fromArray, isNotNull);
      expect(fromArray!.experiments.single.assignmentRules, isNull);
    });

    test('deserializeScalarAssignmentRulesAsString', () {
      expect(deserializeJson(withRules(5))!.experiments.single.assignmentRules,
          '5');
      expect(
          deserializeJson(withRules(true))!.experiments.single.assignmentRules,
          'true');
    });

    test('assignmentRulesRoundTripAndEquality', () {
      const rules = '{"rules":[]}';
      final data = deserializeJson(withRules(rules))!;
      final experiment = data.experiments.single;
      final copy = Experiment.fromMap(
          jsonDecode(jsonEncode(experiment.toMap())) as Map<String, dynamic>);

      expect(experiment.toMap()['assignmentRules'], rules);
      expect(copy, experiment);
      expect(copy.hashCode, experiment.hashCode);

      final other = Experiment.fromMap(
          jsonDecode(jsonEncode(experiment.toMap())) as Map<String, dynamic>)
        ..assignmentRules = '{"rules":[{"type":"assign","variant":0}]}';
      expect(other, isNot(experiment));
    });

    // test/resources/holdouts_context.json is byte-identical to java-sdk
    // core-api/src/test/resources/holdouts_context.json at 34716f8.
    test('deserializeHoldouts', () async {
      final bytes = await getResourceBytes('holdouts_context.json');
      final data =
          DefaultContextDataDeserializer().deserialize(bytes, 0, bytes.length)!;

      final experiment = data.experiments.single;
      expect(experiment.name, 'exp_test_holdout');
      expect(experiment.holdoutIds, [11]);
      expect(experiment.holdoutType, isNull);

      expect(data.holdouts, [
        ContextHoldout(
            id: 11,
            name: 'holdout_a',
            unitType: 'session_id',
            iteration: 1,
            seedHi: 13,
            seedLo: 111,
            split: [0.1, 0.9],
            holdoutType: 'full'),
        ContextHoldout(
            id: 12,
            name: 'holdout_b',
            unitType: 'session_id',
            iteration: 1,
            seedHi: 1,
            seedLo: 222,
            split: [0.05, 0.05, 0.9]),
      ]);
    });

    test('holdoutsRoundTripAndEquality', () async {
      final bytes = await getResourceBytes('holdouts_context.json');
      final data =
          DefaultContextDataDeserializer().deserialize(bytes, 0, bytes.length)!;
      final copy = ContextData.fromMap(
          jsonDecode(jsonEncode(data.toMap())) as Map<String, dynamic>);

      expect(copy, data);
      expect(copy.holdouts, data.holdouts);
      expect(copy.experiments.single, data.experiments.single);
      expect(
          copy.experiments.single.hashCode, data.experiments.single.hashCode);
      expect(copy.holdouts.first.hashCode, data.holdouts.first.hashCode);

      final holdoutEntry = Experiment.fromMap(
          (jsonDecode(jsonEncode(data.experiments.single.toMap()))
              as Map<String, dynamic>)
            ..['holdoutType'] = 'full');
      expect(Experiment.fromMap(holdoutEntry.toMap()).holdoutType, 'full');
      expect(holdoutEntry.toMap()['holdoutType'], 'full');

      copy.experiments.single.holdoutIds = [12];
      expect(copy.experiments.single, isNot(data.experiments.single));
      copy.experiments.single.holdoutIds = [11];
      copy.experiments.single.holdoutType = 'full';
      expect(copy.experiments.single, isNot(data.experiments.single));
      copy.holdouts = [data.holdouts.first];
      expect(copy, isNot(data));
    });

    test('noHoldoutKeysAreWrittenWhenThePayloadHasNone', () {
      final data = deserializeJson({
        'experiments': [
          experimentJson(split: [0.5, 0.5], trafficSplit: [0, 1])
        ]
      })!;

      expect(data.holdouts, isEmpty);
      expect(data.experiments.single.holdoutIds, isNull);
      expect(data.toMap().containsKey('holdouts'), isFalse);
      expect(
          data.experiments.single.toMap().containsKey('holdoutIds'), isFalse);
      expect(
          data.experiments.single.toMap().containsKey('holdoutType'), isFalse);
      expect(data.toString(), isNot(contains('holdouts')));
    });

    test('deserializeHoldoutsIgnoresUnknownKeysInHoldoutEntries', () {
      final data = deserializeJson({
        'experiments': [
          {
            ...experimentJson(split: [0.5, 0.5], trafficSplit: [0, 1]),
            'holdoutIds': [11, 12],
          }
        ],
        'holdouts': [
          {
            'id': 11,
            'name': 'slim',
            'unitType': 'session_id',
            'iteration': 2,
            'seedHi': 1,
            'seedLo': 2,
            'split': [0.1, 0.9],
            'futureScalar': 'x',
            'futureObject': {
              'nested': [1, null]
            },
            'futureArray': [
              {'a': 1}
            ],
          },
          {
            // The legacy full-experiment shape.
            ...experimentJson(split: [0.05, 0.05, 0.9], trafficSplit: [0, 1]),
            'id': 12,
            'name': 'fat',
            'holdoutType': 'all_full_on',
            'customFieldValues': null,
            'switchback': {'periodMinutes': 30},
          },
        ],
      });

      expect(data, isNotNull);
      expect(data!.experiments.single.holdoutIds, [11, 12]);
      expect(data.holdouts.map((h) => h.id), [11, 12]);
      expect(data.holdouts.first.iteration, 2);
      expect(data.holdouts.last.split, [0.05, 0.05, 0.9]);
      expect(data.holdouts.last.holdoutType, 'all_full_on');
    });

    test('deserializeDropsOnlyTheMalformedHoldoutEntry', () {
      final data = deserializeJson({
        'experiments': [
          {
            ...experimentJson(split: [0.5, 0.5], trafficSplit: [0, 1]),
            'holdoutIds': [1, '2', 3.0, 3.5, null, 4],
          }
        ],
        'holdouts': [
          null,
          'not an object',
          {
            'id': 'one',
            'split': [1.0]
          },
          {'id': 2, 'split': 'all'},
          {
            'id': 3,
            'split': [0.5, '0.5']
          },
          {
            'id': 4,
            'split': [0.5, 0.5]
          },
        ],
      });

      expect(data, isNotNull);
      expect(data!.experiments.single.holdoutIds, [1, 3, 4]);
      expect(data.holdouts.single.id, 4);
      expect(data.holdouts.single.name, '');
      expect(data.holdouts.single.iteration, 0);
    });

    test('deserializeIgnoresNonListHoldoutFields', () {
      final data = deserializeJson({
        'experiments': [
          {
            ...experimentJson(split: [0.5, 0.5], trafficSplit: [0, 1]),
            'holdoutIds': {'11': true},
            'holdoutType': 3,
          }
        ],
        'holdouts': {'11': {}},
      });

      expect(data, isNotNull);
      expect(data!.experiments.single.holdoutIds, isNull);
      expect(data.experiments.single.holdoutType, isNull);
      expect(data.holdouts, isEmpty);
    });
  });
}
