import 'dart:async';

import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _HeldPublisher implements ContextPublisher {
  final Completer<void> pending = Completer<void>();

  @override
  Completer<void> publish(Context context, PublishEvent event) => pending;
}

class _ReadyProvider implements ContextDataProvider {
  @override
  Completer<ContextData> getContextData() =>
      Completer<ContextData>()..complete(ContextData());
}

class _CountingPublisher implements ContextPublisher {
  int calls = 0;
  bool fail = false;

  @override
  Completer<void> publish(Context context, PublishEvent event) {
    calls++;
    final result = Completer<void>();
    if (fail) {
      result.completeError(Exception('collector unavailable'));
    } else {
      result.complete();
    }
    return result;
  }
}

ABSmartly _sdk(ContextPublisher publisher) {
  final client = Client.create(ClientConfig()
    ..setEndpoint('https://test.absmartly.io/v1')
    ..setAPIKey('test-api-key')
    ..setApplication('test-app')
    ..setEnvironment('development'));
  return ABSmartly(ABSmartlyConfig.create()
    ..setClient(client)
    ..setContextPublisher(publisher)
    ..setContextDataProvider(_ReadyProvider()));
}

Context _ready(ABSmartly sdk) => sdk.createContextWith(
    ContextConfig.create(publishDelay: -1)..setUnit('user_id', '1'),
    ContextData());

void main() {
  for (final replace in [false, true]) {
    for (final fail in [false, true]) {
      testWidgets('reset owns replacement: replace=$replace failure=$fail',
          (tester) async {
        final publisher = _CountingPublisher();
        final sdk = _sdk(publisher);
        final original = _ready(sdk);
        ABSmartlyData? data;
        Widget tree(Context ctx) => ABSmartlyProvider(
              sdk: sdk,
              context: ctx,
              child: Builder(builder: (c) {
                data = ABSmartlyProvider.of(c);
                return const SizedBox();
              }),
            );
        await tester.pumpWidget(tree(original));
        await tester
            .runAsync(() => data!.resetContext(units: {'user_id': '2'}));
        await tester.pump();
        final owned = data!.context;
        expect(identical(owned, original), isFalse);
        await tester.runAsync(() => owned.waitUntilReady());
        owned.track('goal', null);
        publisher.fail = fail;
        if (replace) {
          await tester.pumpWidget(tree(_ready(sdk)));
        } else {
          await tester.pumpWidget(const SizedBox());
        }
        await tester.pump();
        expect(publisher.calls, 1);
        expect(tester.takeException(), isNull);
        expect(owned.isClosed(), !fail);
        if (fail) expect(owned.getPendingCount(), 1);
      });
    }
  }

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
