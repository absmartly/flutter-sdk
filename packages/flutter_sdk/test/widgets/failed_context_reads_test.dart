import 'dart:async';

import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingProvider implements ContextDataProvider {
  @override
  Completer<ContextData> getContextData() =>
      Completer<ContextData>()..completeError(Exception('load failed'));
}

Future<Context> _failedContext() async {
  final clientConfig = ClientConfig()
    ..setEndpoint('http://localhost')
    ..setAPIKey('k')
    ..setApplication('a')
    ..setEnvironment('e');
  final sdk = ABSmartly(ABSmartlyConfig.create()
    ..setClient(Client.create(clientConfig))
    ..setContextDataProvider(_FailingProvider()));
  final context = sdk.createContext(ContextConfig.create()
    ..setUnit('user_id', '12345')
    ..setPublishDelay(-1));
  await context.waitUntilReady();
  return context;
}

void main() {
  testWidgets('Treatment on a failed context reads through the SDK',
      (tester) async {
    final context = await _failedContext();
    expect(context.isFailed(), isTrue);

    await tester.pumpWidget(Treatment(
      name: 'exp_test',
      context: context,
      variants: {0: const Text('control', textDirection: TextDirection.ltr)},
    ));
    await tester.pump();

    expect(find.text('control'), findsOneWidget);
    expect(context.getPendingCount(), equals(1));
  });

  testWidgets('VariableValue on a failed context reads through the SDK',
      (tester) async {
    final context = await _failedContext();

    await tester.pumpWidget(VariableValue<String>(
      name: 'button.color',
      defaultValue: 'blue',
      context: context,
      builder: (v) => Text(v, textDirection: TextDirection.ltr),
    ));
    await tester.pump();

    expect(find.text('blue'), findsOneWidget);
  });

  testWidgets('TreatmentBuilder on a failed context reads through the SDK',
      (tester) async {
    final context = await _failedContext();

    await tester.pumpWidget(TreatmentBuilder(
      name: 'exp_test',
      context: context,
      builder: (_, variant, variables) =>
          Text('v$variant', textDirection: TextDirection.ltr),
    ));
    await tester.pump();

    expect(find.text('v0'), findsOneWidget);
    expect(context.getPendingCount(), equals(1));
  });

  testWidgets('TreatmentSwitch on a failed context reads through the SDK',
      (tester) async {
    final context = await _failedContext();

    await tester.pumpWidget(TreatmentSwitch(
      name: 'exp_test',
      context: context,
      children: const [
        TreatmentVariant(
            variant: 0,
            child: Text('control', textDirection: TextDirection.ltr)),
      ],
    ));
    await tester.pump();

    expect(find.text('control'), findsOneWidget);
    expect(context.getPendingCount(), equals(1));
  });
}
