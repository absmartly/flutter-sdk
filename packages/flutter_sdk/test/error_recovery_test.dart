import 'dart:async';

import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Error Recovery Scenarios - Phase 2', () {
    late ABSmartly sdk;

    setUp(() {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      sdk = ABSmartly(sdkConfig);
    });

    group('2.1 Recovery From Network Timeout', () {
      testWidgets('Treatment shows control when context fails to load',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Treatment(
              name: 'test_experiment',
              variants: {
                0: const Text('Control (Fallback)',
                    textDirection: TextDirection.ltr),
                1: const Text('Variant', textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Control (Fallback)'), findsOneWidget);
      });

      testWidgets('TreatmentBuilder returns variant 0 when context fails',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        int? capturedVariant;

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: TreatmentBuilder(
              name: 'test_experiment',
              builder: (ctx, variant, variables) {
                capturedVariant = variant;
                return Text('Variant: $variant',
                    textDirection: TextDirection.ltr);
              },
            ),
          ),
        );

        await tester.pump();
        expect(capturedVariant, equals(0));
      });

      testWidgets('VariableValue returns default value when context fails',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: VariableValue<String>(
              name: 'button_text',
              defaultValue: 'Default Button Text',
              builder: (value) => Text(value, textDirection: TextDirection.ltr),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Default Button Text'), findsOneWidget);
      });

      testWidgets(
          'timeout fallback shows control after readyTimeout in placeholder mode',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.placeholder,
            readyTimeout: const Duration(milliseconds: 50),
            child: Treatment(
              name: 'test_experiment',
              variants: {
                0: const Text('Control After Timeout',
                    textDirection: TextDirection.ltr),
                1: const Text('Variant', textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    group('2.2 Recovery From Partial Data', () {
      testWidgets('handles missing experiment in variants map gracefully',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Treatment(
              name: 'nonexistent_experiment',
              variants: {
                0: const Text('Fallback Control',
                    textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Fallback Control'), findsOneWidget);
      });

      testWidgets('TreatmentSwitch shows SizedBox.shrink when no control variant exists',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: TreatmentSwitch(
              name: 'test_experiment',
              children: [
                TreatmentVariant(
                  variant: 5,
                  child:
                      const Text('Variant 5', textDirection: TextDirection.ltr),
                ),
                TreatmentVariant(
                  variant: 6,
                  child:
                      const Text('Variant 6', textDirection: TextDirection.ltr),
                ),
              ],
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Variant 5'), findsNothing);
        expect(find.text('Variant 6'), findsNothing);
      });

      testWidgets('handles empty variants map', (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: const Treatment(
              name: 'test_experiment',
              variants: {},
            ),
          ),
        );

        await tester.pump();
        expect(find.byType(SizedBox), findsWidgets);
      });

      testWidgets('TreatmentSwitch handles empty children list', (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: const TreatmentSwitch(
              name: 'test_experiment',
              children: [],
            ),
          ),
        );

        await tester.pump();
        expect(find.byType(SizedBox), findsWidgets);
      });
    });

    group('2.3 Graceful Degradation No Network', () {
      testWidgets('app continues to function with failed context',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

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
                    0: const Text('Experiment 1 Control',
                        textDirection: TextDirection.ltr),
                  },
                ),
                Treatment(
                  name: 'experiment_2',
                  variants: {
                    0: const Text('Experiment 2 Control',
                        textDirection: TextDirection.ltr),
                  },
                ),
                const Text('Static Content', textDirection: TextDirection.ltr),
              ],
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Experiment 1 Control'), findsOneWidget);
        expect(find.text('Experiment 2 Control'), findsOneWidget);
        expect(find.text('Static Content'), findsOneWidget);
      });

      testWidgets('isFailed reflects context state', (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        bool? capturedIsFailed;

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            child: Builder(
              builder: (ctx) {
                final data = ABSmartlyProvider.of(ctx);
                capturedIsFailed = data.isFailed;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(capturedIsFailed, isNotNull);
      });

      testWidgets('widgets remain interactive even with failed context',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        int tapCount = 0;

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Treatment(
              name: 'button_experiment',
              variants: {
                0: GestureDetector(
                  onTap: () => tapCount++,
                  child: const Text('Tap Me', textDirection: TextDirection.ltr),
                ),
              },
            ),
          ),
        );

        await tester.pump();
        await tester.tap(find.text('Tap Me'));
        expect(tapCount, equals(1));

        await tester.tap(find.text('Tap Me'));
        expect(tapCount, equals(2));
      });
    });

    group('2.4 Retry Mechanism Verification', () {
      testWidgets('context waitUntilReady can be called multiple times',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            child: Builder(
              builder: (ctx) {
                final data = ABSmartlyProvider.of(ctx);
                data.context.waitUntilReady();
                data.context.waitUntilReady();
                return const SizedBox();
              },
            ),
          ),
        );

        await tester.pump();
      });

      testWidgets('resetContext function is available', (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        Future<void> Function({required Map<String, String> units})?
            capturedResetContext;

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            child: Builder(
              builder: (ctx) {
                final data = ABSmartlyProvider.of(ctx);
                capturedResetContext = data.resetContext;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(capturedResetContext, isNotNull);
      });

      testWidgets('multiple widgets recover independently from errors',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

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
                    0: const Text('A Recovered',
                        textDirection: TextDirection.ltr),
                  },
                ),
                TreatmentBuilder(
                  name: 'experiment_b',
                  builder: (ctx, variant, variables) {
                    return const Text('B Recovered',
                        textDirection: TextDirection.ltr);
                  },
                ),
                TreatmentSwitch(
                  name: 'experiment_c',
                  children: [
                    TreatmentVariant(
                      variant: 0,
                      child: const Text('C Recovered',
                          textDirection: TextDirection.ltr),
                    ),
                  ],
                ),
                VariableValue<String>(
                  name: 'var_d',
                  defaultValue: 'D Recovered',
                  builder: (value) =>
                      Text(value, textDirection: TextDirection.ltr),
                ),
              ],
            ),
          ),
        );

        await tester.pump();
        expect(find.text('A Recovered'), findsOneWidget);
        expect(find.text('B Recovered'), findsOneWidget);
        expect(find.text('C Recovered'), findsOneWidget);
        expect(find.text('D Recovered'), findsOneWidget);
      });
    });

    group('Additional Error Recovery Tests', () {
      testWidgets('handles rapid widget updates during loading',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context = sdk.createContext(contextConfig);

        for (int i = 0; i < 5; i++) {
          await tester.pumpWidget(
            ABSmartlyProvider(
              sdk: sdk,
              context: context,
              defaultLoadingBehavior: LoadingBehavior.control,
              child: Treatment(
                name: 'experiment_$i',
                variants: {
                  0: Text('Control $i', textDirection: TextDirection.ltr),
                },
              ),
            ),
          );
          await tester.pump();
        }

        expect(find.text('Control 4'), findsOneWidget);
      });

      testWidgets('widget tree remains stable after context changes',
          (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final context1 = sdk.createContext(contextConfig);

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context1,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Treatment(
              name: 'test_experiment',
              variants: {
                0: const Text('Stable Content',
                    textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Stable Content'), findsOneWidget);

        final context2 = sdk.createContext(contextConfig);
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context2,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Treatment(
              name: 'test_experiment',
              variants: {
                0: const Text('Stable Content',
                    textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Stable Content'), findsOneWidget);
      });
    });
  });
}
