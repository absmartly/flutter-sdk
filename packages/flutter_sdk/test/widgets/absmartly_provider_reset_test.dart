import 'dart:async';

import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _HeldPublisher implements ContextPublisher {
  final Completer<void> pending = Completer<void>();

  @override
  Completer<void> publish(Context context, PublishEvent event) => pending;
}

ABSmartly _sdk(ContextPublisher publisher) {
  final client = Client.create(ClientConfig()
    ..setEndpoint('https://test.absmartly.io/v1')
    ..setAPIKey('test-api-key')
    ..setApplication('test-app')
    ..setEnvironment('development'));
  return ABSmartly(ABSmartlyConfig.create()
    ..setClient(client)
    ..setContextPublisher(publisher));
}

Context _ready(ABSmartly sdk) => sdk.createContextWith(
    ContextConfig.create(publishDelay: -1)..setUnit('user_id', '1'),
    ContextData());

void main() {
  testWidgets('a pending reset does not overwrite a replaced provider context',
      (tester) async {
    final publisher = _HeldPublisher();
    final sdkA = _sdk(publisher);
    final contextA = _ready(sdkA)..track('goal', null);
    final sdkB = _sdk(publisher);
    final contextB = _ready(sdkB);

    ABSmartlyData? data;
    Widget tree(ABSmartly sdk, Context ctx) => ABSmartlyProvider(
          sdk: sdk,
          context: ctx,
          child: Builder(builder: (c) {
            data = ABSmartlyProvider.of(c);
            return const SizedBox();
          }),
        );

    await tester.pumpWidget(tree(sdkA, contextA));
    final reset = data!.resetContext(units: {'user_id': '2'});

    await tester.pumpWidget(tree(sdkB, contextB));
    expect(identical(data!.context, contextB), isTrue);

    publisher.pending.complete();
    await tester.runAsync(() => reset);
    await tester.pump();

    expect(identical(data!.context, contextB), isTrue);
  });

  testWidgets('a pending reset does nothing after the provider is disposed',
      (tester) async {
    final publisher = _HeldPublisher();
    final sdk = _sdk(publisher);
    final ctx = _ready(sdk)..track('goal', null);

    ABSmartlyData? data;
    await tester.pumpWidget(ABSmartlyProvider(
      sdk: sdk,
      context: ctx,
      child: Builder(builder: (c) {
        data = ABSmartlyProvider.of(c);
        return const SizedBox();
      }),
    ));
    final reset = data!.resetContext(units: {'user_id': '2'});

    await tester.pumpWidget(const SizedBox());
    publisher.pending.complete();
    await tester.runAsync(() => reset);

    expect(tester.takeException(), isNull);
  });
}
