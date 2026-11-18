import 'dart:async';

import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _experiment(int id, String name, int price) => {
      'id': id,
      'name': name,
      'unitType': 'user_id',
      'iteration': 1,
      'seedHi': 0,
      'seedLo': 0,
      'split': [0.5, 0.5],
      'trafficSeedHi': 0,
      'trafficSeedLo': 0,
      'trafficSplit': [0.0, 1.0],
      'fullOnVariant': 1,
      'applications': [
        {'name': 'test-app'}
      ],
      'variants': [
        {'name': 'A', 'config': null},
        {'name': 'B', 'config': '{"price":$price}'},
      ],
    };

class _BoundaryClock extends Clock {
  static const int anchor = 1767225600000;
  static const int hour = 3600000;
  int now = anchor;
  int? nextRead;

  @override
  int millis() {
    final next = nextRead;
    nextRead = null;
    return next ?? now;
  }
}

class _Publisher implements ContextPublisher {
  final events = <PublishEvent>[];
  @override
  Completer<void> publish(Context context, PublishEvent event) {
    events.add(event);
    return Completer<void>()..complete();
  }
}

class _DataProvider implements ContextDataProvider {
  @override
  Completer<ContextData> getContextData() => Completer<ContextData>();
}

void main() {
  testWidgets('TreatmentBuilder reads variables from the named experiment',
      (tester) async {
    final client = Client.create(ClientConfig()
      ..setEndpoint('https://test.absmartly.io/v1')
      ..setAPIKey('test-api-key')
      ..setApplication('test-app')
      ..setEnvironment('development'));
    final sdk = ABSmartly(ABSmartlyConfig.create()..setClient(client));
    final context = sdk.createContextWith(
        ContextConfig.create(publishDelay: -1)..setUnit('user_id', '12345'),
        ContextData.fromMap({
          'experiments': [
            _experiment(1, 'exp_a', 10),
            _experiment(2, 'exp_b', 20),
          ]
        }));

    Map<String, dynamic>? captured;
    await tester.pumpWidget(ABSmartlyProvider(
      sdk: sdk,
      context: context,
      child: TreatmentBuilder(
        name: 'exp_b',
        builder: (context, variant, variables) {
          captured = variables;
          return Text('$variant', textDirection: TextDirection.ltr);
        },
      ),
    ));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(captured, equals({'price': 20}));
  });
  testWidgets(
      'TreatmentBuilder pairs variant and variables at a period boundary',
      (tester) async {
    final clock = _BoundaryClock();
    final publisher = _Publisher();
    final map = _experiment(1, 'sb', 1)
      ..addAll({
        'seedHi': -5,
        'seedLo': -7,
        'fullOnVariant': 0,
        'randomizationType': 'switchback',
        'switchbackClusters': {'user_id': 'city'},
        'switchbackStartAt': _BoundaryClock.anchor,
        'switchbackPeriodMs': _BoundaryClock.hour,
        'variants': [
          {'name': 'A', 'config': '{"price":0}'},
          {'name': 'B', 'config': '{"price":1}'},
        ],
      });
    final context = Context.create(
        clock,
        ContextConfig.create(publishDelay: -1)..setUnit('user_id', 'u1'),
        Completer<ContextData>()
          ..complete(ContextData.fromMap({
            'experiments': [map]
          })),
        _DataProvider(),
        publisher,
        DefaultVariableParser(),
        AudienceMatcher(DefaultAudienceDeserializer()),
        null);
    context.setAttribute('city', 'store-42');
    await context.waitUntilReady();
    clock.now = _BoundaryClock.anchor + _BoundaryClock.hour;
    clock.nextRead = clock.now - 1;
    final sdk = ABSmartly(ABSmartlyConfig.create()
      ..setClient(Client.create(ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development'))));
    int? renderedVariant;
    Map<String, dynamic>? renderedVariables;
    await tester.pumpWidget(ABSmartlyProvider(
      sdk: sdk,
      context: context,
      child: TreatmentBuilder(
        name: 'sb',
        builder: (_, variant, variables) {
          renderedVariant = variant;
          renderedVariables = variables;
          return const SizedBox();
        },
      ),
    ));
    await tester.pump();
    expect(renderedVariant, 0);
    expect(renderedVariables, {'price': 0});
    await context.publish();
    expect(publisher.events.single.exposures.single.variant, renderedVariant);
  });
}
