import 'dart:async';

import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:test/test.dart';

// Runs on the VM and compiled to JavaScript (CI: dart test -p node): a whole
// context must give a unit the variant the JavaScript SDK gives it, through
// the traffic split, the variant split and a split assignment rule.
//
// [uid, variant, split-rule variant], generated from the JavaScript SDK at
// published 1.14.1 artifact, git ff23cbf (VariantAssigner and hashUnit, as
// context.ts _assign uses
// them). The last UID of every four ends in an unpaired surrogate.
const List<List<Object>> _jsAssignments = [
  ['user-0@example.com', 1, 2],
  ['1000003', 2, 2],
  ['\u00FC2\uD83D\uDE00', 2, 2],
  ['lone3\uD800', 0, 2],
  ['user-4@example.com', 0, 0],
  ['5000015', 0, 2],
  ['\u00FC6\uD83D\uDE00', 2, 2],
  ['lone7\uD800', 0, 0],
  ['user-8@example.com', 1, 1],
  ['9000027', 2, 2],
  ['\u00FC10\uD83D\uDE00', 0, 2],
  ['lone11\uD800', 1, 2],
  ['user-12@example.com', 0, 1],
  ['13000039', 1, 2],
  ['\u00FC14\uD83D\uDE00', 1, 1],
  ['lone15\uD800', 0, 0],
  ['user-16@example.com', 1, 2],
  ['17000051', 0, 1],
  ['\u00FC18\uD83D\uDE00', 2, 2],
  ['lone19\uD800', 0, 2],
  ['user-20@example.com', 1, 2],
  ['21000063', 0, 0],
  ['\u00FC22\uD83D\uDE00', 0, 0],
  ['lone23\uD800', 0, 0],
  ['user-24@example.com', 2, 2],
  ['25000075', 2, 2],
  ['\u00FC26\uD83D\uDE00', 2, 2],
  ['lone27\uD800', 0, 1],
  ['user-28@example.com', 2, 2],
  ['29000087', 0, 1],
  ['\u00FC30\uD83D\uDE00', 0, 0],
  ['lone31\uD800', 0, 0],
  ['user-32@example.com', 0, 1],
  ['33000099', 0, 0],
  ['\u00FC34\uD83D\uDE00', 2, 2],
  ['lone35\uD800', 0, 1],
  ['user-36@example.com', 0, 1],
  ['37000111', 0, 1],
  ['\u00FC38\uD83D\uDE00', 0, 2],
  ['lone39\uD800', 2, 2],
];

class _NoData implements ContextDataProvider {
  @override
  Completer<ContextData> getContextData() => Completer<ContextData>();
}

class _NoPublish implements ContextPublisher {
  @override
  Completer<void> publish(Context context, PublishEvent event) =>
      Completer<void>()..complete();
}

Experiment _experiment(String name, int id, String? rules) => Experiment(
      id: id,
      name: name,
      unitType: 'u',
      iteration: 1,
      seedHi: 3755441452,
      seedLo: 1611309155,
      split: [0.34, 0.33, 0.33],
      trafficSeedHi: 2242306224,
      trafficSeedLo: 3426557412,
      trafficSplit: [0.2, 0.8],
      fullOnVariant: 0,
      applications: [ExperimentApplication(name: 'website')],
      variants: [
        ExperimentVariant(name: 'A', config: null),
        ExperimentVariant(name: 'B', config: null),
        ExperimentVariant(name: 'C', config: null),
      ],
      audienceStrict: false,
      audience: null,
      assignmentRules: rules,
    );

void main() {
  final data = ContextData(experiments: [
    _experiment('exp_plain', 1, null),
    _experiment('exp_split_rule', 2,
        '{"rules":[{"type":"split","percentages":"20/30/50"}]}'),
  ]);

  Future<Context> contextFor(String uid) async {
    final context = Context.create(
        Clock.fixed(1620000000000),
        ContextConfig.create()..setUnit('u', uid),
        Completer<ContextData>()..complete(data),
        _NoData(),
        _NoPublish(),
        DefaultVariableParser(),
        AudienceMatcher(DefaultAudienceDeserializer()),
        null);
    await context.waitUntilReady();
    return context;
  }

  test('a context assigns every unit as the JavaScript SDK does', () async {
    for (final row in _jsAssignments) {
      final uid = row[0] as String;
      expect((await contextFor(uid)).peekTreatment('exp_plain'), row[1],
          reason: 'exp_plain $uid');
      expect((await contextFor(uid)).peekTreatment('exp_split_rule'), row[2],
          reason: 'exp_split_rule $uid');
    }
  });
}
