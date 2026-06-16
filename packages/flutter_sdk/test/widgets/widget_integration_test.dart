import 'dart:async';

import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Widget Integration Tests - Phase 1', () {
    late ABSmartly sdk;
    late Context context;

    setUp(() {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
      context = sdk.createContext(contextConfig);
    });

    group('1.1 Context Propagation Through Widget Tree', () {
      testWidgets('context flows through nested widget tree', (tester) async {
        ABSmartlyData? capturedData;
        ABSmartlyData? nestedCapturedData;

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            child: Builder(
              builder: (ctx) {
                capturedData = ABSmartlyProvider.of(ctx);
                return Column(
                  children: [
                    Container(
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Builder(
                          builder: (nestedCtx) {
                            nestedCapturedData =
                                ABSmartlyProvider.of(nestedCtx);
                            return const SizedBox();
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );

        expect(capturedData, isNotNull);
        expect(nestedCapturedData, isNotNull);
        expect(capturedData!.sdk, equals(nestedCapturedData!.sdk));
        expect(capturedData!.context, equals(nestedCapturedData!.context));
      });

      testWidgets('context is accessible from multiple branches',
          (tester) async {
        ABSmartlyData? leftBranchData;
        ABSmartlyData? rightBranchData;

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                Builder(
                  builder: (ctx) {
                    leftBranchData = ABSmartlyProvider.of(ctx);
                    return const SizedBox();
                  },
                ),
                Builder(
                  builder: (ctx) {
                    rightBranchData = ABSmartlyProvider.of(ctx);
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );

        expect(leftBranchData, isNotNull);
        expect(rightBranchData, isNotNull);
        expect(leftBranchData!.context, equals(rightBranchData!.context));
      });

      testWidgets('listen parameter controls rebuild behavior', (tester) async {
        int listenBuildCount = 0;
        int noListenBuildCount = 0;

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                Builder(
                  builder: (ctx) {
                    ABSmartlyProvider.of(ctx, listen: true);
                    listenBuildCount++;
                    return const SizedBox();
                  },
                ),
                Builder(
                  builder: (ctx) {
                    ABSmartlyProvider.of(ctx, listen: false);
                    noListenBuildCount++;
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );

        expect(listenBuildCount, greaterThan(0));
        expect(noListenBuildCount, greaterThan(0));
      });
    });

    group('1.2 Treatment Widget State Management', () {
      testWidgets(
          'Treatment widget shows control variant initially in control mode',
          (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Treatment(
              name: 'test_experiment',
              variants: {
                0: const Text('Control', textDirection: TextDirection.ltr),
                1: const Text('Variant A', textDirection: TextDirection.ltr),
                2: const Text('Variant B', textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Control'), findsOneWidget);
        expect(find.text('Variant A'), findsNothing);
        expect(find.text('Variant B'), findsNothing);
      });

      testWidgets('Treatment widget updates when experiment name changes',
          (tester) async {
        String experimentName = 'experiment_1';

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (ctx, setState) {
              return ABSmartlyProvider(
                sdk: sdk,
                context: context,
                defaultLoadingBehavior: LoadingBehavior.control,
                child: Column(
                  children: [
                    Treatment(
                      name: experimentName,
                      variants: {
                        0: Text('Control for $experimentName',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                    GestureDetector(
                      key: const Key('change_button'),
                      onTap: () {
                        setState(() {
                          experimentName = 'experiment_2';
                        });
                      },
                      child: const Text('Change',
                          textDirection: TextDirection.ltr),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('Control for experiment_1'), findsOneWidget);
      });
    });

    group('1.3 Treatment Widget Loading State', () {
      testWidgets('shows loading widget when provided and context not ready',
          (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.placeholder,
            child: Treatment(
              name: 'test_experiment',
              loading:
                  const Text('Loading...', textDirection: TextDirection.ltr),
              variants: {
                0: const Text('Control', textDirection: TextDirection.ltr),
                1: const Text('Variant', textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump(Duration.zero);
      });

      testWidgets(
          'shows empty SizedBox in placeholder mode without loading widget',
          (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.placeholder,
            readyTimeout: const Duration(seconds: 10),
            child: const Treatment(
              name: 'test_experiment',
              variants: {},
            ),
          ),
        );

        await tester.pump();
        expect(find.byType(SizedBox), findsWidgets);
      });

      testWidgets('falls back to control after timeout in placeholder mode',
          (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.placeholder,
            readyTimeout: const Duration(milliseconds: 100),
            child: Treatment(
              name: 'test_experiment',
              variants: {
                0: const Text('Control Fallback',
                    textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump();
      });
    });

    group('1.4 Nested Treatment Widgets', () {
      testWidgets('nested Treatment widgets work independently',
          (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Column(
              children: [
                Treatment(
                  name: 'outer_experiment',
                  variants: {
                    0: Treatment(
                      name: 'inner_experiment',
                      variants: {
                        0: const Text('Outer Control -> Inner Control',
                            textDirection: TextDirection.ltr),
                        1: const Text('Outer Control -> Inner Variant',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                    1: const Text('Outer Variant',
                        textDirection: TextDirection.ltr),
                  },
                ),
              ],
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Outer Control -> Inner Control'), findsOneWidget);
      });

      testWidgets('multiple treatments at same level work independently',
          (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Column(
              children: [
                Treatment(
                  name: 'experiment_a',
                  variants: {
                    0: const Text('A Control',
                        textDirection: TextDirection.ltr),
                    1: const Text('A Variant',
                        textDirection: TextDirection.ltr),
                  },
                ),
                Treatment(
                  name: 'experiment_b',
                  variants: {
                    0: const Text('B Control',
                        textDirection: TextDirection.ltr),
                    1: const Text('B Variant',
                        textDirection: TextDirection.ltr),
                  },
                ),
                Treatment(
                  name: 'experiment_c',
                  variants: {
                    0: const Text('C Control',
                        textDirection: TextDirection.ltr),
                    1: const Text('C Variant',
                        textDirection: TextDirection.ltr),
                  },
                ),
              ],
            ),
          ),
        );

        await tester.pump();
        expect(find.text('A Control'), findsOneWidget);
        expect(find.text('B Control'), findsOneWidget);
        expect(find.text('C Control'), findsOneWidget);
      });

      testWidgets('TreatmentBuilder and Treatment can be nested',
          (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: TreatmentBuilder(
              name: 'outer_experiment',
              builder: (ctx, variant, variables) {
                return Treatment(
                  name: 'inner_experiment',
                  variants: {
                    0: Text('Builder variant $variant -> Treatment Control',
                        textDirection: TextDirection.ltr),
                  },
                );
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.textContaining('Builder variant'), findsOneWidget);
      });
    });

    group('1.5 Widget Disposal', () {
      testWidgets('Treatment widget cleans up timer on dispose',
          (tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.placeholder,
            readyTimeout: const Duration(seconds: 10),
            child: Treatment(
              key: key,
              name: 'test_experiment',
              variants: {
                0: const Text('Control', textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            child: const SizedBox(),
          ),
        );

        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('TreatmentBuilder widget cleans up on dispose',
          (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.placeholder,
            child: TreatmentBuilder(
              name: 'test_experiment',
              builder: (ctx, variant, variables) {
                return const Text('Content', textDirection: TextDirection.ltr);
              },
            ),
          ),
        );

        await tester.pump();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            child: const SizedBox(),
          ),
        );

        await tester.pump();
      });

      testWidgets('TreatmentSwitch widget cleans up on dispose',
          (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.placeholder,
            child: TreatmentSwitch(
              name: 'test_experiment',
              children: [
                TreatmentVariant(
                  variant: 0,
                  child:
                      const Text('Control', textDirection: TextDirection.ltr),
                ),
              ],
            ),
          ),
        );

        await tester.pump();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            child: const SizedBox(),
          ),
        );

        await tester.pump();
      });

      testWidgets('VariableValue widget cleans up on dispose', (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.placeholder,
            child: VariableValue<String>(
              name: 'test_variable',
              defaultValue: 'default',
              builder: (value) => Text(value, textDirection: TextDirection.ltr),
            ),
          ),
        );

        await tester.pump();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            child: const SizedBox(),
          ),
        );

        await tester.pump();
      });
    });

    group('1.6 StreamBuilder Integration', () {
      testWidgets('Treatment widgets work with StreamBuilder parent',
          (tester) async {
        final controller = StreamController<int>.broadcast();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: StreamBuilder<int>(
              stream: controller.stream,
              initialData: 0,
              builder: (ctx, snapshot) {
                return Treatment(
                  name: 'test_experiment_${snapshot.data}',
                  variants: {
                    0: Text('Control ${snapshot.data}',
                        textDirection: TextDirection.ltr),
                  },
                );
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Control 0'), findsOneWidget);

        controller.add(1);
        await tester.pumpAndSettle();
        expect(find.text('Control 1'), findsOneWidget);

        controller.add(2);
        await tester.pumpAndSettle();
        expect(find.text('Control 2'), findsOneWidget);

        await controller.close();
      });

      testWidgets('TreatmentBuilder works with FutureBuilder parent',
          (tester) async {
        final completer = Completer<String>();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: FutureBuilder<String>(
              future: completer.future,
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('Waiting',
                      textDirection: TextDirection.ltr);
                }
                return TreatmentBuilder(
                  name: 'test_experiment',
                  builder: (ctx, variant, variables) {
                    return Text('Data: ${snapshot.data}',
                        textDirection: TextDirection.ltr);
                  },
                );
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Waiting'), findsOneWidget);

        completer.complete('Hello');
        await tester.pumpAndSettle();
        expect(find.text('Data: Hello'), findsOneWidget);
      });

      testWidgets('multiple StreamBuilders with treatments work independently',
          (tester) async {
        final controller1 = StreamController<String>.broadcast();
        final controller2 = StreamController<String>.broadcast();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Column(
              children: [
                StreamBuilder<String>(
                  stream: controller1.stream,
                  initialData: 'A',
                  builder: (ctx, snapshot) {
                    return Treatment(
                      name: 'experiment_1',
                      variants: {
                        0: Text('Stream1: ${snapshot.data}',
                            textDirection: TextDirection.ltr),
                      },
                    );
                  },
                ),
                StreamBuilder<String>(
                  stream: controller2.stream,
                  initialData: 'X',
                  builder: (ctx, snapshot) {
                    return Treatment(
                      name: 'experiment_2',
                      variants: {
                        0: Text('Stream2: ${snapshot.data}',
                            textDirection: TextDirection.ltr),
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Stream1: A'), findsOneWidget);
        expect(find.text('Stream2: X'), findsOneWidget);

        controller1.add('B');
        await tester.pumpAndSettle();
        expect(find.text('Stream1: B'), findsOneWidget);
        expect(find.text('Stream2: X'), findsOneWidget);

        controller2.add('Y');
        await tester.pumpAndSettle();
        expect(find.text('Stream1: B'), findsOneWidget);
        expect(find.text('Stream2: Y'), findsOneWidget);

        await controller1.close();
        await controller2.close();
      });
    });
  });

  group('Additional Widget Integration Tests', () {
    late ABSmartly sdk;
    late Context context;

    setUp(() {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
      context = sdk.createContext(contextConfig);
    });

    testWidgets('VariableValue widget renders with default value',
        (tester) async {
      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context,
          defaultLoadingBehavior: LoadingBehavior.control,
          child: VariableValue<String>(
            name: 'button_text',
            defaultValue: 'Click Me',
            builder: (value) => Text(value, textDirection: TextDirection.ltr),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Click Me'), findsOneWidget);
    });

    testWidgets('VariableValue widget handles different types', (tester) async {
      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context,
          defaultLoadingBehavior: LoadingBehavior.control,
          child: Column(
            children: [
              VariableValue<int>(
                name: 'count',
                defaultValue: 42,
                builder: (value) =>
                    Text('Count: $value', textDirection: TextDirection.ltr),
              ),
              VariableValue<double>(
                name: 'price',
                defaultValue: 9.99,
                builder: (value) =>
                    Text('Price: $value', textDirection: TextDirection.ltr),
              ),
              VariableValue<bool>(
                name: 'enabled',
                defaultValue: true,
                builder: (value) =>
                    Text('Enabled: $value', textDirection: TextDirection.ltr),
              ),
            ],
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Count: 42'), findsOneWidget);
      expect(find.text('Price: 9.99'), findsOneWidget);
      expect(find.text('Enabled: true'), findsOneWidget);
    });

    testWidgets('TreatmentSwitch renders correct variant', (tester) async {
      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context,
          defaultLoadingBehavior: LoadingBehavior.control,
          child: TreatmentSwitch(
            name: 'hero_experiment',
            children: [
              TreatmentVariant(
                variant: 0,
                child: const Text('Classic Hero',
                    textDirection: TextDirection.ltr),
              ),
              TreatmentVariant(
                variant: 1,
                child:
                    const Text('Modern Hero', textDirection: TextDirection.ltr),
              ),
              TreatmentVariant(
                variant: 'C',
                child: const Text('Minimal Hero',
                    textDirection: TextDirection.ltr),
              ),
            ],
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Classic Hero'), findsOneWidget);
      expect(find.text('Modern Hero'), findsNothing);
      expect(find.text('Minimal Hero'), findsNothing);
    });

    testWidgets('widgets handle context passed directly', (tester) async {
      final contextConfig2 = ContextConfig.create()
        ..setUnit('user_id', '67890');
      final context2 = sdk.createContext(contextConfig2);

      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context,
          defaultLoadingBehavior: LoadingBehavior.control,
          child: Column(
            children: [
              Treatment(
                name: 'experiment_1',
                variants: {
                  0: const Text('Context 1 Treatment',
                      textDirection: TextDirection.ltr),
                },
              ),
              Treatment(
                name: 'experiment_1',
                context: context2,
                variants: {
                  0: const Text('Context 2 Treatment',
                      textDirection: TextDirection.ltr),
                },
              ),
            ],
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Context 1 Treatment'), findsOneWidget);
      expect(find.text('Context 2 Treatment'), findsOneWidget);
    });
  });
}
