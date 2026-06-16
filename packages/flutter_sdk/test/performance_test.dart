import 'dart:async';

import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Performance Tests - Phase 4', () {
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

    group('4.1 Large Context Data Handling', () {
      test('handles context with many units', () {
        final contextConfig = ContextConfig.create();
        for (int i = 0; i < 100; i++) {
          contextConfig.setUnit('unit_$i', 'value_$i');
        }

        final testContext = sdk.createContext(contextConfig);
        expect(testContext, isNotNull);
      });

      test('handles context with many attributes', () {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');

        final attributes = <String, dynamic>{};
        for (int i = 0; i < 100; i++) {
          attributes['attr_$i'] = 'value_$i';
        }
        contextConfig.setAttributes(attributes);

        final testContext = sdk.createContext(contextConfig);
        expect(testContext, isNotNull);
      });

      test('handles context with many overrides', () {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');

        final overrides = <String, int>{};
        for (int i = 0; i < 100; i++) {
          overrides['experiment_$i'] = i % 3;
        }
        contextConfig.setOverrides(overrides);

        final testContext = sdk.createContext(contextConfig);
        expect(testContext, isNotNull);

        for (int i = 0; i < 100; i++) {
          expect(contextConfig.getOverride('experiment_$i'), equals(i % 3));
        }
      });

      test('handles context with many custom assignments', () {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');

        final customAssignments = <String, int>{};
        for (int i = 0; i < 100; i++) {
          customAssignments['experiment_$i'] = i % 5;
        }
        contextConfig.setCustomAssignments(customAssignments);

        final testContext = sdk.createContext(contextConfig);
        expect(testContext, isNotNull);
      });

      testWidgets('handles many Treatment widgets', (tester) async {
        final startTime = DateTime.now();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(
                  100,
                  (index) => Treatment(
                    name: 'experiment_$index',
                    variants: {
                      0: Text('Control $index',
                          textDirection: TextDirection.ltr),
                      1: Text('Variant $index',
                          textDirection: TextDirection.ltr),
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final duration = DateTime.now().difference(startTime);
        expect(duration.inSeconds, lessThan(30));
        expect(find.text('Control 0'), findsOneWidget);
        expect(find.text('Control 99'), findsOneWidget);
      });
    });

    group('4.2 Cache and Memory Efficiency', () {
      test('context config reuses attribute map', () {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345')
          ..setAttribute('key1', 'value1')
          ..setAttribute('key2', 'value2')
          ..setAttribute('key3', 'value3');

        final attrs1 = contextConfig.getAttributes();
        final attrs2 = contextConfig.getAttributes();

        expect(attrs1, equals(attrs2));
        expect(attrs1.length, equals(3));
      });

      test('context config reuses units map', () {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345')
          ..setUnit('session_id', 'session123')
          ..setUnit('device_id', 'device456');

        final units1 = contextConfig.getUnits();
        final units2 = contextConfig.getUnits();

        expect(units1, equals(units2));
        expect(units1.length, equals(3));
      });

      testWidgets('widgets maintain efficient state', (tester) async {
        final key = GlobalKey<State>();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
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
        final state1 = key.currentState;

        await tester.pump();
        final state2 = key.currentState;

        expect(identical(state1, state2), isTrue);
      });

      test('creating multiple contexts does not cause memory issues', () {
        final contexts = <Context>[];
        for (int i = 0; i < 50; i++) {
          final contextConfig = ContextConfig.create()
            ..setUnit('user_id', 'user_$i')
            ..setAttributes({'iteration': i});
          contexts.add(sdk.createContext(contextConfig));
        }

        expect(contexts.length, equals(50));

        for (int i = 0; i < contexts.length; i++) {
          expect(contexts[i], isNotNull);
        }
      });
    });

    group('4.3 Rapid State Changes', () {
      testWidgets('handles rapid experiment name changes', (tester) async {
        String experimentName = 'experiment_0';

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
                        for (int i = 0; i < 10; i++) {
                          setState(() {
                            experimentName = 'experiment_$i';
                          });
                        }
                      },
                      child: const Text('Change Rapidly',
                          textDirection: TextDirection.ltr),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('Control for experiment_0'), findsOneWidget);

        await tester.tap(find.byKey(const Key('change_button')));
        await tester.pump();
        expect(find.text('Control for experiment_9'), findsOneWidget);
      });

      testWidgets('handles rapid widget tree changes', (tester) async {
        bool showFirst = true;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (ctx, setState) {
              return ABSmartlyProvider(
                sdk: sdk,
                context: context,
                defaultLoadingBehavior: LoadingBehavior.control,
                child: Column(
                  children: [
                    if (showFirst)
                      Treatment(
                        name: 'experiment_first',
                        variants: {
                          0: const Text('First',
                              textDirection: TextDirection.ltr),
                        },
                      )
                    else
                      Treatment(
                        name: 'experiment_second',
                        variants: {
                          0: const Text('Second',
                              textDirection: TextDirection.ltr),
                        },
                      ),
                    GestureDetector(
                      key: const Key('toggle_button'),
                      onTap: () {
                        setState(() {
                          showFirst = !showFirst;
                        });
                      },
                      child: const Text('Toggle',
                          textDirection: TextDirection.ltr),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('First'), findsOneWidget);

        for (int i = 0; i < 20; i++) {
          await tester.tap(find.byKey(const Key('toggle_button')));
          await tester.pump();
        }

        expect(find.text('First'), findsOneWidget);
      });

      testWidgets('handles rapid context switches', (tester) async {
        Context currentContext = context;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (ctx, setState) {
              return ABSmartlyProvider(
                sdk: sdk,
                context: currentContext,
                defaultLoadingBehavior: LoadingBehavior.control,
                child: Column(
                  children: [
                    Treatment(
                      name: 'test_experiment',
                      variants: {
                        0: const Text('Control',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                    GestureDetector(
                      key: const Key('switch_button'),
                      onTap: () {
                        setState(() {
                          final newConfig = ContextConfig.create()
                            ..setUnit('user_id',
                                'user_${DateTime.now().millisecondsSinceEpoch}');
                          currentContext = sdk.createContext(newConfig);
                        });
                      },
                      child: const Text('Switch Context',
                          textDirection: TextDirection.ltr),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        await tester.pump();

        for (int i = 0; i < 10; i++) {
          await tester.tap(find.byKey(const Key('switch_button')));
          await tester.pump();
        }

        expect(find.text('Control'), findsOneWidget);
      });

      testWidgets('handles StreamBuilder with high-frequency updates',
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
                  name: 'stream_experiment',
                  variants: {
                    0: Text('Value: ${snapshot.data}',
                        textDirection: TextDirection.ltr),
                  },
                );
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Value: 0'), findsOneWidget);

        controller.add(50);
        await tester.pumpAndSettle();
        expect(find.text('Value: 50'), findsOneWidget);

        controller.add(100);
        await tester.pumpAndSettle();
        expect(find.text('Value: 100'), findsOneWidget);

        await controller.close();
      });

      testWidgets('timer-based updates work correctly', (tester) async {
        int updateCount = 0;

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: StatefulBuilder(
              builder: (ctx, setState) {
                return Column(
                  children: [
                    Treatment(
                      name: 'timer_experiment',
                      variants: {
                        0: Text('Updates: $updateCount',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                    GestureDetector(
                      key: const Key('update_button'),
                      onTap: () {
                        setState(() {
                          updateCount++;
                        });
                      },
                      child: const Text('Update',
                          textDirection: TextDirection.ltr),
                    ),
                  ],
                );
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Updates: 0'), findsOneWidget);

        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byKey(const Key('update_button')));
          await tester.pump();
        }

        expect(find.text('Updates: 5'), findsOneWidget);
      });
    });

    group('Performance Benchmarks', () {
      test('context creation is fast', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          final contextConfig = ContextConfig.create()
            ..setUnit('user_id', 'user_$i');
          sdk.createContext(contextConfig);
        }

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('attribute setting is fast', () {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');

        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 1000; i++) {
          contextConfig.setAttribute('attr_$i', 'value_$i');
        }

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });

      test('override setting is fast', () {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');

        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 1000; i++) {
          contextConfig.setOverride('experiment_$i', i % 5);
        }

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });

      testWidgets('widget rendering is efficient', (tester) async {
        final stopwatch = Stopwatch()..start();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(
                  50,
                  (index) => Treatment(
                    name: 'experiment_$index',
                    variants: {
                      0: Text('Control $index',
                          textDirection: TextDirection.ltr),
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      });
    });
  });
}
