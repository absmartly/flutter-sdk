import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Treatment', () {
    testWidgets('shows control variant in control loading mode', (tester) async {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      final sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
      final context = sdk.createContext(contextConfig);

      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context,
          defaultLoadingBehavior: LoadingBehavior.control,
          child: Treatment(
            name: 'test_experiment',
            variants: {
              0: const Text('Control', textDirection: TextDirection.ltr),
              1: const Text('Variant', textDirection: TextDirection.ltr),
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Control'), findsOneWidget);
      expect(find.text('Variant'), findsNothing);
    });

    testWidgets('falls back to first variant when requested variant missing', (tester) async {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      final sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
      final context = sdk.createContext(contextConfig);

      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context,
          defaultLoadingBehavior: LoadingBehavior.control,
          child: Treatment(
            name: 'test_experiment',
            variants: {
              0: const Text('Control', textDirection: TextDirection.ltr),
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Control'), findsOneWidget);
    });

    testWidgets('shows SizedBox.shrink when no variants provided', (tester) async {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      final sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
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

    testWidgets('accepts custom context parameter', (tester) async {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      final sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
      final context1 = sdk.createContext(contextConfig);
      final context2 = sdk.createContext(contextConfig);

      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context1,
          defaultLoadingBehavior: LoadingBehavior.control,
          child: Treatment(
            name: 'test_experiment',
            context: context2,
            variants: {
              0: const Text('Control', textDirection: TextDirection.ltr),
              1: const Text('Variant', textDirection: TextDirection.ltr),
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Control'), findsOneWidget);
    });
  });

  group('TreatmentBuilder', () {
    testWidgets('calls builder with variant and variables', (tester) async {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      final sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
      final context = sdk.createContext(contextConfig);

      int? capturedVariant;
      Map<String, dynamic>? capturedVariables;

      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context,
          defaultLoadingBehavior: LoadingBehavior.control,
          child: TreatmentBuilder(
            name: 'test_experiment',
            builder: (context, variant, variables) {
              capturedVariant = variant;
              capturedVariables = variables;
              return Text('Variant: $variant', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );

      await tester.pump();

      expect(capturedVariant, isNotNull);
      expect(capturedVariables, isNotNull);
      expect(find.textContaining('Variant:'), findsOneWidget);
    });

    testWidgets('builder receives 0 as default variant in control mode', (tester) async {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      final sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
      final context = sdk.createContext(contextConfig);

      int? capturedVariant;

      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context,
          defaultLoadingBehavior: LoadingBehavior.control,
          child: TreatmentBuilder(
            name: 'test_experiment',
            builder: (context, variant, variables) {
              capturedVariant = variant;
              return Text('Variant: $variant', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );

      await tester.pump();

      expect(capturedVariant, equals(0));
    });

    testWidgets('accepts custom context parameter', (tester) async {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      final sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
      final context1 = sdk.createContext(contextConfig);
      final context2 = sdk.createContext(contextConfig);

      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context1,
          defaultLoadingBehavior: LoadingBehavior.control,
          child: TreatmentBuilder(
            name: 'test_experiment',
            context: context2,
            builder: (context, variant, variables) {
              return Text('Variant: $variant', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.textContaining('Variant:'), findsOneWidget);
    });
  });

  group('TreatmentSwitch', () {
    testWidgets('shows control variant with TreatmentVariant children', (tester) async {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      final sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
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
                variant: 0,
                child: const Text('Control', textDirection: TextDirection.ltr),
              ),
              TreatmentVariant(
                variant: 1,
                child: const Text('Variant B', textDirection: TextDirection.ltr),
              ),
            ],
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Control'), findsOneWidget);
      expect(find.text('Variant B'), findsNothing);
    });

    testWidgets('supports letter variants', (tester) async {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      final sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
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
                variant: 'A',
                child: const Text('Control A', textDirection: TextDirection.ltr),
              ),
              TreatmentVariant(
                variant: 'B',
                child: const Text('Variant B', textDirection: TextDirection.ltr),
              ),
            ],
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Control A'), findsOneWidget);
      expect(find.text('Variant B'), findsNothing);
    });

    testWidgets('falls back to first child when no matching variant', (tester) async {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create()..setClient(client);
      final sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()..setUnit('user_id', '12345');
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
                child: const Text('Variant 5', textDirection: TextDirection.ltr),
              ),
              TreatmentVariant(
                variant: 6,
                child: const Text('Variant 6', textDirection: TextDirection.ltr),
              ),
            ],
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Variant 5'), findsOneWidget);
    });
  });

  group('TreatmentVariant', () {
    test('variantIndex handles int correctly', () {
      const variant = TreatmentVariant(
        variant: 2,
        child: SizedBox(),
      );
      expect(variant.variantIndex, equals(2));
    });

    test('variantIndex handles letter A correctly', () {
      const variant = TreatmentVariant(
        variant: 'A',
        child: SizedBox(),
      );
      expect(variant.variantIndex, equals(0));
    });

    test('variantIndex handles letter B correctly', () {
      const variant = TreatmentVariant(
        variant: 'B',
        child: SizedBox(),
      );
      expect(variant.variantIndex, equals(1));
    });

    test('variantIndex handles lowercase letters correctly', () {
      const variant = TreatmentVariant(
        variant: 'c',
        child: SizedBox(),
      );
      expect(variant.variantIndex, equals(2));
    });

    test('variantIndex handles string numbers correctly', () {
      const variant = TreatmentVariant(
        variant: '5',
        child: SizedBox(),
      );
      expect(variant.variantIndex, equals(5));
    });

    test('variantIndex defaults to 0 for invalid input', () {
      const variant = TreatmentVariant(
        variant: 'invalid',
        child: SizedBox(),
      );
      expect(variant.variantIndex, equals(0));
    });
  });
}
