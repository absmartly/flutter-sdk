import 'dart:async';

import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _data(int price) => {
      'experiments': [
        {
          'id': 1,
          'name': 'exp',
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
        }
      ]
    };

void main() {
  testWidgets('VariableValue follows a provider context swap', (tester) async {
    final client = Client.create(ClientConfig()
      ..setEndpoint('https://test.absmartly.io/v1')
      ..setAPIKey('test-api-key')
      ..setApplication('test-app')
      ..setEnvironment('development'));
    final sdk = ABSmartly(ABSmartlyConfig.create()..setClient(client));
    Context ready(int price) => sdk.createContextWith(
        ContextConfig.create(publishDelay: -1)..setUnit('user_id', '1'),
        ContextData.fromMap(_data(price)));

    Widget tree(Context ctx) => ABSmartlyProvider(
          sdk: sdk,
          context: ctx,
          child: VariableValue<int>(
            name: 'price',
            defaultValue: 0,
            builder: (v) => Text('$v', textDirection: TextDirection.ltr),
          ),
        );

    await tester.pumpWidget(tree(ready(10)));
    expect(find.text('10'), findsOneWidget);

    await tester.pumpWidget(tree(ready(20)));
    await tester.pump();
    expect(find.text('20'), findsOneWidget);
  });
}
