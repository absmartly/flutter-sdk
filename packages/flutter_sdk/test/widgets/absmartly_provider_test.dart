import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ABSmartlyProvider', () {
    testWidgets('provides ABSmartlyData to descendants', (tester) async {
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

      ABSmartlyData? capturedData;

      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context,
          child: Builder(
            builder: (context) {
              capturedData = ABSmartlyProvider.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedData, isNotNull);
      expect(capturedData!.sdk, equals(sdk));
      expect(capturedData!.context, equals(context));
      expect(capturedData!.defaultLoadingBehavior, equals(LoadingBehavior.placeholder));
      expect(capturedData!.readyTimeout, equals(const Duration(seconds: 3)));
    });

    testWidgets('maybeOf returns null when no provider', (tester) async {
      ABSmartlyData? capturedData;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            capturedData = ABSmartlyProvider.maybeOf(context);
            return const SizedBox();
          },
        ),
      );

      expect(capturedData, isNull);
    });

    testWidgets('of throws when no provider', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(
              () => ABSmartlyProvider.of(context),
              throwsA(isA<FlutterError>()),
            );
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('respects custom defaultLoadingBehavior', (tester) async {
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

      ABSmartlyData? capturedData;

      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context,
          defaultLoadingBehavior: LoadingBehavior.control,
          child: Builder(
            builder: (context) {
              capturedData = ABSmartlyProvider.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedData!.defaultLoadingBehavior, equals(LoadingBehavior.control));
    });

    testWidgets('respects custom readyTimeout', (tester) async {
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

      ABSmartlyData? capturedData;

      await tester.pumpWidget(
        ABSmartlyProvider(
          sdk: sdk,
          context: context,
          readyTimeout: const Duration(seconds: 10),
          child: Builder(
            builder: (context) {
              capturedData = ABSmartlyProvider.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedData!.readyTimeout, equals(const Duration(seconds: 10)));
    });
  });

  group('LoadingBehavior', () {
    test('has placeholder and control values', () {
      expect(LoadingBehavior.values, contains(LoadingBehavior.placeholder));
      expect(LoadingBehavior.values, contains(LoadingBehavior.control));
      expect(LoadingBehavior.values.length, equals(2));
    });
  });

  group('ABSmartlyData', () {
    test('isReady returns context.isReady()', () {
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

      final data = ABSmartlyData(
        sdk: sdk,
        context: context,
        defaultLoadingBehavior: LoadingBehavior.placeholder,
        readyTimeout: const Duration(seconds: 3),
        resetContext: ({required Map<String, String> units}) async {},
      );

      expect(data.isReady, equals(context.isReady()));
    });

    test('isFailed returns context.isFailed()', () {
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

      final data = ABSmartlyData(
        sdk: sdk,
        context: context,
        defaultLoadingBehavior: LoadingBehavior.placeholder,
        readyTimeout: const Duration(seconds: 3),
        resetContext: ({required Map<String, String> units}) async {},
      );

      expect(data.isFailed, equals(context.isFailed()));
    });
  });
}
