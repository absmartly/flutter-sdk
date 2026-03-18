import 'dart:async';

import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Platform-Specific Edge Cases - Phase 3', () {
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

    group('3.1 Dart VM Behavior', () {
      test('ContextConfig handles null values correctly', () {
        final config = ContextConfig.create();
        expect(config.getUnit('nonexistent'), isNull);
        expect(config.getOverride('nonexistent'), isNull);
        expect(config.getCustomAssignment('nonexistent'), isNull);
      });

      test('ContextConfig setUnits with empty map', () {
        final config = ContextConfig.create()..setUnits({});
        expect(config.getUnits().isEmpty, isTrue);
      });

      test('ContextConfig setUnits with special characters', () {
        final config = ContextConfig.create()
          ..setUnit('user_id', 'id-with-special-chars!@#\$%^&*()');
        expect(config.getUnit('user_id'),
            equals('id-with-special-chars!@#\$%^&*()'));
      });

      test('ContextConfig setUnits with unicode characters', () {
        final config = ContextConfig.create()
          ..setUnit('user_id', 'user-\u4e2d\u6587-\u0391\u0392\u0393');
        expect(
            config.getUnit('user_id'), equals('user-\u4e2d\u6587-\u0391\u0392\u0393'));
      });

      test('ContextConfig setAttributes with various types', () {
        final config = ContextConfig.create()
          ..setAttributes({
            'string_attr': 'value',
            'int_attr': 42,
            'double_attr': 3.14,
            'bool_attr': true,
            'null_attr': null,
            'list_attr': [1, 2, 3],
            'map_attr': {'nested': 'value'},
          });

        final attrs = config.getAttributes();
        expect(attrs['string_attr'], equals('value'));
        expect(attrs['int_attr'], equals(42));
        expect(attrs['double_attr'], equals(3.14));
        expect(attrs['bool_attr'], equals(true));
        expect(attrs['null_attr'], isNull);
        expect(attrs['list_attr'], equals([1, 2, 3]));
        expect(attrs['map_attr'], equals({'nested': 'value'}));
      });

      test('ABSmartly SDK creation with minimal config', () {
        final clientConfig = ClientConfig()
          ..setEndpoint('https://test.absmartly.io/v1')
          ..setAPIKey('test-api-key')
          ..setApplication('test-app')
          ..setEnvironment('development');

        final client = Client.create(clientConfig);
        final sdkConfig = ABSmartlyConfig.create()..setClient(client);
        final testSdk = ABSmartly(sdkConfig);

        expect(testSdk, isNotNull);
      });

      test('multiple contexts can be created from same SDK', () {
        final context1 = sdk.createContext(
            ContextConfig.create()..setUnit('user_id', 'user1'));
        final context2 = sdk.createContext(
            ContextConfig.create()..setUnit('user_id', 'user2'));
        final context3 = sdk.createContext(
            ContextConfig.create()..setUnit('user_id', 'user3'));

        expect(context1, isNotNull);
        expect(context2, isNotNull);
        expect(context3, isNotNull);
        expect(context1, isNot(equals(context2)));
        expect(context2, isNot(equals(context3)));
      });
    });

    group('3.2 Flutter Widget Platform Behavior', () {
      testWidgets('widgets handle directionality correctly', (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: Treatment(
                name: 'test_experiment',
                variants: {},
              ),
            ),
          ),
        );

        await tester.pump();
      });

      testWidgets('widgets work in constrained layout', (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: SizedBox(
              width: 100,
              height: 50,
              child: Treatment(
                name: 'test_experiment',
                variants: {
                  0: const Text('Constrained',
                      textDirection: TextDirection.ltr),
                },
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Constrained'), findsOneWidget);
      });

      testWidgets('widgets handle MediaQuery context', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 812),
              devicePixelRatio: 3.0,
            ),
            child: ABSmartlyProvider(
              sdk: sdk,
              context: context,
              defaultLoadingBehavior: LoadingBehavior.control,
              child: Builder(
                builder: (ctx) {
                  final mediaQuery = MediaQuery.of(ctx);
                  return Treatment(
                    name: 'responsive_experiment',
                    variants: {
                      0: Text('Width: ${mediaQuery.size.width}',
                          textDirection: TextDirection.ltr),
                    },
                  );
                },
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Width: 375.0'), findsOneWidget);
      });

      testWidgets('widgets handle dark/light theme context', (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Treatment(
              name: 'theme_experiment',
              variants: {
                0: const ColoredBox(
                  color: Color(0xFFFFFFFF),
                  child: Text('Themed', textDirection: TextDirection.ltr),
                ),
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Themed'), findsOneWidget);
      });
    });

    group('3.3 Async/Await Edge Cases', () {
      testWidgets('handles multiple rapid async operations', (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Treatment(
              name: 'test_experiment',
              variants: {
                0: const Text('Async Test', textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(find.text('Async Test'), findsOneWidget);
      });

      test('context waitUntilReady returns same future when called multiple times',
          () async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final testContext = sdk.createContext(contextConfig);

        final future1 = testContext.waitUntilReady();
        final future2 = testContext.waitUntilReady();

        final result1 = await future1;
        final result2 = await future2;
        expect(result1, same(result2));
      });

      testWidgets('widget survives pump without duration', (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Treatment(
              name: 'test_experiment',
              variants: {
                0: const Text('Survives', textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.text('Survives'), findsOneWidget);
      });

      testWidgets('FutureBuilder with treatment works correctly',
          (tester) async {
        final completer = Completer<int>();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: FutureBuilder<int>(
              future: completer.future,
              builder: (ctx, snapshot) {
                return Treatment(
                  name: 'async_experiment',
                  variants: {
                    0: Text(
                        'Value: ${snapshot.hasData ? snapshot.data : "waiting"}',
                        textDirection: TextDirection.ltr),
                  },
                );
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Value: waiting'), findsOneWidget);

        completer.complete(42);
        await tester.pumpAndSettle();
        expect(find.text('Value: 42'), findsOneWidget);
      });

      testWidgets('StreamBuilder with treatment handles stream events',
          (tester) async {
        final controller = StreamController<String>.broadcast();

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: StreamBuilder<String>(
              stream: controller.stream,
              initialData: 'initial',
              builder: (ctx, snapshot) {
                return Treatment(
                  name: 'stream_experiment',
                  variants: {
                    0: Text('Stream: ${snapshot.data}',
                        textDirection: TextDirection.ltr),
                  },
                );
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Stream: initial'), findsOneWidget);

        controller.add('updated');
        await tester.pumpAndSettle();
        expect(find.text('Stream: updated'), findsOneWidget);

        controller.add('final');
        await tester.pumpAndSettle();
        expect(find.text('Stream: final'), findsOneWidget);

        await controller.close();
      });
    });

    group('3.4 Thread Safety and Isolation', () {
      test('multiple SDK instances are independent', () {
        final clientConfig1 = ClientConfig()
          ..setEndpoint('https://test1.absmartly.io/v1')
          ..setAPIKey('test-api-key-1')
          ..setApplication('test-app-1')
          ..setEnvironment('development');

        final clientConfig2 = ClientConfig()
          ..setEndpoint('https://test2.absmartly.io/v1')
          ..setAPIKey('test-api-key-2')
          ..setApplication('test-app-2')
          ..setEnvironment('production');

        final client1 = Client.create(clientConfig1);
        final client2 = Client.create(clientConfig2);

        final sdkConfig1 = ABSmartlyConfig.create()..setClient(client1);
        final sdkConfig2 = ABSmartlyConfig.create()..setClient(client2);

        final sdk1 = ABSmartly(sdkConfig1);
        final sdk2 = ABSmartly(sdkConfig2);

        expect(sdk1, isNotNull);
        expect(sdk2, isNotNull);
        expect(sdk1, isNot(equals(sdk2)));
      });

      test('contexts from different SDKs are independent', () {
        final clientConfig1 = ClientConfig()
          ..setEndpoint('https://test1.absmartly.io/v1')
          ..setAPIKey('test-api-key-1')
          ..setApplication('test-app-1')
          ..setEnvironment('development');

        final clientConfig2 = ClientConfig()
          ..setEndpoint('https://test2.absmartly.io/v1')
          ..setAPIKey('test-api-key-2')
          ..setApplication('test-app-2')
          ..setEnvironment('production');

        final client1 = Client.create(clientConfig1);
        final client2 = Client.create(clientConfig2);

        final sdkConfig1 = ABSmartlyConfig.create()..setClient(client1);
        final sdkConfig2 = ABSmartlyConfig.create()..setClient(client2);

        final testSdk1 = ABSmartly(sdkConfig1);
        final testSdk2 = ABSmartly(sdkConfig2);

        final context1 = testSdk1.createContext(
            ContextConfig.create()..setUnit('user_id', 'shared_user'));
        final context2 = testSdk2.createContext(
            ContextConfig.create()..setUnit('user_id', 'shared_user'));

        expect(context1, isNot(equals(context2)));
      });

      testWidgets('concurrent widget operations are safe', (tester) async {
        final contexts = <Context>[];
        for (int i = 0; i < 5; i++) {
          final contextConfig = ContextConfig.create()
            ..setUnit('user_id', 'user_$i');
          contexts.add(sdk.createContext(contextConfig));
        }

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Column(
              children: List.generate(
                5,
                (index) => Treatment(
                  name: 'experiment_$index',
                  context: contexts[index],
                  variants: {
                    0: Text('Context $index', textDirection: TextDirection.ltr),
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        for (int i = 0; i < 5; i++) {
          expect(find.text('Context $i'), findsOneWidget);
        }
      });

      testWidgets('state is preserved across rebuilds', (tester) async {
        int buildCount = 0;

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: StatefulBuilder(
              builder: (ctx, setState) {
                buildCount++;
                return Column(
                  children: [
                    Treatment(
                      name: 'test_experiment',
                      variants: {
                        0: Text('Build: $buildCount',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                    GestureDetector(
                      key: const Key('rebuild_button'),
                      onTap: () => setState(() {}),
                      child: const Text('Rebuild',
                          textDirection: TextDirection.ltr),
                    ),
                  ],
                );
              },
            ),
          ),
        );

        await tester.pump();
        expect(buildCount, equals(1));

        await tester.tap(find.byKey(const Key('rebuild_button')));
        await tester.pump();
        expect(buildCount, equals(2));

        await tester.tap(find.byKey(const Key('rebuild_button')));
        await tester.pump();
        expect(buildCount, equals(3));
      });
    });

    group('Edge Case Boundary Tests', () {
      test('handles very long experiment names', () {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345');
        final testContext = sdk.createContext(contextConfig);

        final longName = 'a' * 1000;
        expect(testContext.peekTreatment(longName), equals(0));
      });

      test('handles very long unit values', () {
        final longValue = 'v' * 10000;
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', longValue);
        final testContext = sdk.createContext(contextConfig);

        expect(testContext, isNotNull);
      });

      testWidgets('handles deeply nested widget trees', (tester) async {
        Widget buildNestedTree(int depth) {
          if (depth == 0) {
            return Treatment(
              name: 'deep_experiment',
              variants: {
                0: const Text('Deep Control', textDirection: TextDirection.ltr),
              },
            );
          }
          return Container(child: buildNestedTree(depth - 1));
        }

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: buildNestedTree(20),
          ),
        );

        await tester.pump();
        expect(find.text('Deep Control'), findsOneWidget);
      });

      testWidgets('handles many widgets at same level', (tester) async {
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
                      0: Text('Widget $index',
                          textDirection: TextDirection.ltr),
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Widget 0'), findsOneWidget);
        expect(find.text('Widget 49'), findsOneWidget);
      });

      test('ContextConfig handles negative override values', () {
        final config = ContextConfig.create()
          ..setOverride('experiment', -1);
        expect(config.getOverride('experiment'), equals(-1));
      });

      test('ContextConfig handles zero override values', () {
        final config = ContextConfig.create()..setOverride('experiment', 0);
        expect(config.getOverride('experiment'), equals(0));
      });

      test('ContextConfig handles large override values', () {
        final config = ContextConfig.create()
          ..setOverride('experiment', 2147483647);
        expect(config.getOverride('experiment'), equals(2147483647));
      });
    });
  });
}
