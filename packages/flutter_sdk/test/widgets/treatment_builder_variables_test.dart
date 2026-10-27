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
}
