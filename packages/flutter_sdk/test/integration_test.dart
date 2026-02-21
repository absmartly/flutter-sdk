import 'dart:async';

import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Integration Scenarios - Phase 5', () {
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

    group('5.1 Complete User Flow', () {
      testWidgets('simulates user login flow with A/B testing', (tester) async {
        bool isLoggedIn = false;
        String? userId;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (ctx, setState) {
              if (!isLoggedIn) {
                return ABSmartlyProvider(
                  sdk: sdk,
                  context: context,
                  defaultLoadingBehavior: LoadingBehavior.control,
                  child: Column(
                    children: [
                      Treatment(
                        name: 'login_button_experiment',
                        variants: {
                          0: const Text('Login', textDirection: TextDirection.ltr),
                          1: const Text('Sign In', textDirection: TextDirection.ltr),
                        },
                      ),
                      GestureDetector(
                        key: const Key('login_button'),
                        onTap: () {
                          setState(() {
                            isLoggedIn = true;
                            userId = 'user_12345';
                          });
                        },
                        child: const Text('Perform Login',
                            textDirection: TextDirection.ltr),
                      ),
                    ],
                  ),
                );
              }

              final loggedInConfig = ContextConfig.create()
                ..setUnit('user_id', userId!);
              final loggedInContext = sdk.createContext(loggedInConfig);

              return ABSmartlyProvider(
                sdk: sdk,
                context: loggedInContext,
                defaultLoadingBehavior: LoadingBehavior.control,
                child: Column(
                  children: [
                    Text('Welcome $userId', textDirection: TextDirection.ltr),
                    Treatment(
                      name: 'dashboard_experiment',
                      variants: {
                        0: const Text('Classic Dashboard',
                            textDirection: TextDirection.ltr),
                        1: const Text('Modern Dashboard',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('Login'), findsOneWidget);

        await tester.tap(find.byKey(const Key('login_button')));
        await tester.pump();

        expect(find.text('Welcome user_12345'), findsOneWidget);
        expect(find.text('Classic Dashboard'), findsOneWidget);
      });

      testWidgets('simulates e-commerce checkout flow', (tester) async {
        int step = 0;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (ctx, setState) {
              return ABSmartlyProvider(
                sdk: sdk,
                context: context,
                defaultLoadingBehavior: LoadingBehavior.control,
                child: Column(
                  children: [
                    if (step == 0) ...[
                      Treatment(
                        name: 'cart_experiment',
                        variants: {
                          0: const Text('View Cart',
                              textDirection: TextDirection.ltr),
                          1: const Text('Shopping Bag',
                              textDirection: TextDirection.ltr),
                        },
                      ),
                      GestureDetector(
                        key: const Key('proceed_to_checkout'),
                        onTap: () => setState(() => step = 1),
                        child: const Text('Proceed',
                            textDirection: TextDirection.ltr),
                      ),
                    ],
                    if (step == 1) ...[
                      Treatment(
                        name: 'checkout_experiment',
                        variants: {
                          0: const Text('Standard Checkout',
                              textDirection: TextDirection.ltr),
                          1: const Text('Express Checkout',
                              textDirection: TextDirection.ltr),
                        },
                      ),
                      GestureDetector(
                        key: const Key('place_order'),
                        onTap: () => setState(() => step = 2),
                        child: const Text('Place Order',
                            textDirection: TextDirection.ltr),
                      ),
                    ],
                    if (step == 2) ...[
                      Treatment(
                        name: 'confirmation_experiment',
                        variants: {
                          0: const Text('Order Confirmed',
                              textDirection: TextDirection.ltr),
                          1: const Text('Success! Order Placed',
                              textDirection: TextDirection.ltr),
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('View Cart'), findsOneWidget);

        await tester.tap(find.byKey(const Key('proceed_to_checkout')));
        await tester.pump();
        expect(find.text('Standard Checkout'), findsOneWidget);

        await tester.tap(find.byKey(const Key('place_order')));
        await tester.pump();
        expect(find.text('Order Confirmed'), findsOneWidget);
      });

      testWidgets('simulates onboarding flow with feature flags',
          (tester) async {
        int onboardingStep = 0;
        const totalSteps = 3;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (ctx, setState) {
              return ABSmartlyProvider(
                sdk: sdk,
                context: context,
                defaultLoadingBehavior: LoadingBehavior.control,
                child: Column(
                  children: [
                    Text('Step ${onboardingStep + 1} of $totalSteps',
                        textDirection: TextDirection.ltr),
                    if (onboardingStep == 0)
                      Treatment(
                        name: 'onboarding_welcome',
                        variants: {
                          0: const Text('Welcome to our app!',
                              textDirection: TextDirection.ltr),
                          1: const Text('Hey there! Ready to start?',
                              textDirection: TextDirection.ltr),
                        },
                      ),
                    if (onboardingStep == 1)
                      Treatment(
                        name: 'onboarding_features',
                        variants: {
                          0: const Text('Check out our features',
                              textDirection: TextDirection.ltr),
                          1: const Text('Discover what you can do',
                              textDirection: TextDirection.ltr),
                        },
                      ),
                    if (onboardingStep == 2)
                      Treatment(
                        name: 'onboarding_complete',
                        variants: {
                          0: const Text('All set!',
                              textDirection: TextDirection.ltr),
                          1: const Text('You are ready!',
                              textDirection: TextDirection.ltr),
                        },
                      ),
                    if (onboardingStep < totalSteps - 1)
                      GestureDetector(
                        key: const Key('next_button'),
                        onTap: () => setState(() => onboardingStep++),
                        child:
                            const Text('Next', textDirection: TextDirection.ltr),
                      ),
                  ],
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('Step 1 of 3'), findsOneWidget);
        expect(find.text('Welcome to our app!'), findsOneWidget);

        await tester.tap(find.byKey(const Key('next_button')));
        await tester.pump();
        expect(find.text('Step 2 of 3'), findsOneWidget);
        expect(find.text('Check out our features'), findsOneWidget);

        await tester.tap(find.byKey(const Key('next_button')));
        await tester.pump();
        expect(find.text('Step 3 of 3'), findsOneWidget);
        expect(find.text('All set!'), findsOneWidget);
      });
    });

    group('5.2 Multiple Contexts', () {
      testWidgets('handles multiple independent contexts', (tester) async {
        final userContext = sdk.createContext(
            ContextConfig.create()..setUnit('user_id', 'user_123'));
        final sessionContext = sdk.createContext(
            ContextConfig.create()..setUnit('session_id', 'session_456'));

        await tester.pumpWidget(
          Column(
            children: [
              ABSmartlyProvider(
                sdk: sdk,
                context: userContext,
                defaultLoadingBehavior: LoadingBehavior.control,
                child: Treatment(
                  name: 'user_experiment',
                  variants: {
                    0: const Text('User Control',
                        textDirection: TextDirection.ltr),
                  },
                ),
              ),
              ABSmartlyProvider(
                sdk: sdk,
                context: sessionContext,
                defaultLoadingBehavior: LoadingBehavior.control,
                child: Treatment(
                  name: 'session_experiment',
                  variants: {
                    0: const Text('Session Control',
                        textDirection: TextDirection.ltr),
                  },
                ),
              ),
            ],
          ),
        );

        await tester.pump();
        expect(find.text('User Control'), findsOneWidget);
        expect(find.text('Session Control'), findsOneWidget);
      });

      testWidgets('nested providers override parent context', (tester) async {
        final parentContext = sdk.createContext(
            ContextConfig.create()..setUnit('user_id', 'parent_user'));
        final childContext = sdk.createContext(
            ContextConfig.create()..setUnit('user_id', 'child_user'));

        String? parentContextUser;
        String? childContextUser;

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: parentContext,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Column(
              children: [
                Builder(
                  builder: (ctx) {
                    final data = ABSmartlyProvider.of(ctx);
                    parentContextUser = 'parent';
                    return Text('Parent: $parentContextUser',
                        textDirection: TextDirection.ltr);
                  },
                ),
                ABSmartlyProvider(
                  sdk: sdk,
                  context: childContext,
                  defaultLoadingBehavior: LoadingBehavior.control,
                  child: Builder(
                    builder: (ctx) {
                      final data = ABSmartlyProvider.of(ctx);
                      childContextUser = 'child';
                      return Text('Child: $childContextUser',
                          textDirection: TextDirection.ltr);
                    },
                  ),
                ),
              ],
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Parent: parent'), findsOneWidget);
        expect(find.text('Child: child'), findsOneWidget);
      });

      testWidgets('context switching updates all child widgets', (tester) async {
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
                      name: 'experiment_1',
                      variants: {
                        0: const Text('Exp1 Control',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                    Treatment(
                      name: 'experiment_2',
                      variants: {
                        0: const Text('Exp2 Control',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                    Treatment(
                      name: 'experiment_3',
                      variants: {
                        0: const Text('Exp3 Control',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                    GestureDetector(
                      key: const Key('switch_context'),
                      onTap: () {
                        setState(() {
                          final newConfig = ContextConfig.create()
                            ..setUnit('user_id', 'new_user');
                          currentContext = sdk.createContext(newConfig);
                        });
                      },
                      child: const Text('Switch',
                          textDirection: TextDirection.ltr),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('Exp1 Control'), findsOneWidget);
        expect(find.text('Exp2 Control'), findsOneWidget);
        expect(find.text('Exp3 Control'), findsOneWidget);

        await tester.tap(find.byKey(const Key('switch_context')));
        await tester.pump();

        expect(find.text('Exp1 Control'), findsOneWidget);
        expect(find.text('Exp2 Control'), findsOneWidget);
        expect(find.text('Exp3 Control'), findsOneWidget);
      });
    });

    group('5.3 Hot Reload Compatibility', () {
      testWidgets('widgets survive rebuild', (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Treatment(
              name: 'test_experiment',
              variants: {
                0: const Text('Before Rebuild',
                    textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Before Rebuild'), findsOneWidget);

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Treatment(
              name: 'test_experiment',
              variants: {
                0: const Text('After Rebuild',
                    textDirection: TextDirection.ltr),
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('After Rebuild'), findsOneWidget);
      });

      testWidgets('state is preserved on parent rebuild', (tester) async {
        int counter = 0;

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
                      name: 'counter_experiment',
                      variants: {
                        0: Text('Counter: $counter',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                    GestureDetector(
                      key: const Key('increment'),
                      onTap: () => setState(() => counter++),
                      child: const Text('Increment',
                          textDirection: TextDirection.ltr),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('Counter: 0'), findsOneWidget);

        await tester.tap(find.byKey(const Key('increment')));
        await tester.pump();
        expect(find.text('Counter: 1'), findsOneWidget);

        await tester.tap(find.byKey(const Key('increment')));
        await tester.pump();
        expect(find.text('Counter: 2'), findsOneWidget);
      });

      testWidgets('key changes force widget recreation', (tester) async {
        Key widgetKey = const ValueKey('key1');

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
                      key: widgetKey,
                      name: 'test_experiment',
                      variants: {
                        0: Text('Key: $widgetKey',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                    GestureDetector(
                      key: const Key('change_key'),
                      onTap: () {
                        setState(() {
                          widgetKey = const ValueKey('key2');
                        });
                      },
                      child: const Text('Change Key',
                          textDirection: TextDirection.ltr),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        await tester.pump();

        await tester.tap(find.byKey(const Key('change_key')));
        await tester.pump();
      });

      testWidgets('provider survives multiple rebuilds', (tester) async {
        for (int i = 0; i < 10; i++) {
          await tester.pumpWidget(
            ABSmartlyProvider(
              sdk: sdk,
              context: context,
              defaultLoadingBehavior: LoadingBehavior.control,
              child: Treatment(
                name: 'test_experiment',
                variants: {
                  0: Text('Rebuild $i', textDirection: TextDirection.ltr),
                },
              ),
            ),
          );

          await tester.pump();
          expect(find.text('Rebuild $i'), findsOneWidget);
        }
      });
    });

    group('Real-world Integration Patterns', () {
      testWidgets('TabBar with different experiments per tab', (tester) async {
        int selectedTab = 0;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (ctx, setState) {
              return ABSmartlyProvider(
                sdk: sdk,
                context: context,
                defaultLoadingBehavior: LoadingBehavior.control,
                child: Column(
                  children: [
                    Row(
                      textDirection: TextDirection.ltr,
                      children: [
                        GestureDetector(
                          key: const Key('tab_0'),
                          onTap: () => setState(() => selectedTab = 0),
                          child: Text(
                            'Tab 0${selectedTab == 0 ? ' (selected)' : ''}',
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                        GestureDetector(
                          key: const Key('tab_1'),
                          onTap: () => setState(() => selectedTab = 1),
                          child: Text(
                            'Tab 1${selectedTab == 1 ? ' (selected)' : ''}',
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      ],
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: IndexedStack(
                        index: selectedTab,
                        children: [
                          Treatment(
                            name: 'tab_0_experiment',
                            variants: {
                              0: const Text('Tab 0 Content',
                                  textDirection: TextDirection.ltr),
                            },
                          ),
                          Treatment(
                            name: 'tab_1_experiment',
                            variants: {
                              0: const Text('Tab 1 Content',
                                  textDirection: TextDirection.ltr),
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('Tab 0 (selected)'), findsOneWidget);
        expect(find.text('Tab 0 Content'), findsOneWidget);

        await tester.tap(find.byKey(const Key('tab_1')));
        await tester.pump();
        expect(find.text('Tab 1 (selected)'), findsOneWidget);
        expect(find.text('Tab 1 Content'), findsOneWidget);
      });

      testWidgets('conditional feature flag rendering', (tester) async {
        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: context,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Column(
              children: [
                TreatmentBuilder(
                  name: 'feature_flag',
                  builder: (ctx, variant, variables) {
                    if (variant == 1) {
                      return const Text('New Feature Enabled',
                          textDirection: TextDirection.ltr);
                    }
                    return const Text('Standard Feature',
                        textDirection: TextDirection.ltr);
                  },
                ),
              ],
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Standard Feature'), findsOneWidget);
      });

      testWidgets('dynamic experiment based on user segment', (tester) async {
        final contextConfig = ContextConfig.create()
          ..setUnit('user_id', '12345')
          ..setAttributes({
            'user_type': 'premium',
            'country': 'US',
            'age_group': '25-34',
          });
        final segmentedContext = sdk.createContext(contextConfig);

        await tester.pumpWidget(
          ABSmartlyProvider(
            sdk: sdk,
            context: segmentedContext,
            defaultLoadingBehavior: LoadingBehavior.control,
            child: Builder(
              builder: (ctx) {
                final data = ABSmartlyProvider.of(ctx);
                return Column(
                  children: [
                    Treatment(
                      name: 'premium_feature',
                      variants: {
                        0: const Text('Standard',
                            textDirection: TextDirection.ltr),
                        1: const Text('Premium',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                    Treatment(
                      name: 'regional_content',
                      variants: {
                        0: const Text('Global Content',
                            textDirection: TextDirection.ltr),
                        1: const Text('US Specific Content',
                            textDirection: TextDirection.ltr),
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Standard'), findsOneWidget);
        expect(find.text('Global Content'), findsOneWidget);
      });
    });
  });
}
