import 'dart:async';
import 'dart:convert';

import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/ab_smartly.dart';
import 'package:absmartly_dart/src/absmartly_sdk_config.dart';
import 'package:absmartly_dart/src/client.dart';
import 'package:absmartly_dart/src/client_config.dart';
import 'package:absmartly_dart/src/context.dart';
import 'package:absmartly_dart/src/context_config.dart';
import 'package:absmartly_dart/src/context_data_provider.dart';
import 'package:absmartly_dart/src/context_event_handler.dart';
import 'package:absmartly_dart/src/context_event_logger.dart';
import 'package:absmartly_dart/src/default_audience_deserializer.dart';
import 'package:absmartly_dart/src/default_context_data_serializer.dart';
import 'package:absmartly_dart/src/default_context_event_serializer.dart';
import 'package:absmartly_dart/src/default_http_client.dart';
import 'package:absmartly_dart/src/default_variable_parser.dart';
import 'package:absmartly_dart/src/http_client.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:absmartly_dart/src/json/context_data.dart';
import 'package:absmartly_dart/src/json/publish_event.dart';
import 'package:absmartly_dart/src/variable_parser.dart';
import 'package:test/test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'context_test.mocks.dart';
import 'test_utils.dart';

// These tests pin the "always-on system attributes" behaviour: the client's
// application and environment names are evaluated by audiences exactly as if
// the user had set them, without being published (the collector attaches them
// server-side) and without an opt-in flag. See the SDK brief, §4.
@GenerateNiceMocks([
  MockSpec<ContextDataProvider>(),
  MockSpec<ContextEventHandler>(),
  MockSpec<ContextEventLogger>(),
])
void main() {
  group('System Attributes', () {
    final Map<String, String> units = {
      'session_id': 'e791e240fcd3df7d238cfc285f475e8152fcc0ec',
      'user_id': '123456789',
    };

    late ContextData systemData;

    late MockContextDataProvider dataProvider;
    late MockContextEventLogger eventLogger;
    late MockContextEventHandler eventHandler;
    late VariableParser variableParser;
    late AudienceMatcher audienceMatcher;
    late Clock clock;
    late DefaultContextDataDeserializer deser;

    setUp(() async {
      deser = DefaultContextDataDeserializer();
      final bytes = await getResourceBytes('system_attributes_context.json');
      systemData = deser.deserialize(bytes, 0, bytes.length)!;

      dataProvider = MockContextDataProvider();
      eventHandler = MockContextEventHandler();
      eventLogger = MockContextEventLogger();
      variableParser = DefaultVariableParser();
      audienceMatcher = AudienceMatcher(DefaultAudienceDeserializer());
      clock = Clock.fixed(1620000000000);
    });

    Context createContext({
      String? application = 'website',
      String? environment = 'production',
      ContextData? data,
      Map<String, dynamic>? attributes,
    }) {
      final ContextConfig config = ContextConfig.create()..setUnits(units);
      if (attributes != null) {
        config.setAttributes(attributes);
      }
      final completer = Completer<ContextData>()..complete(data ?? systemData);
      return Context.create(clock, config, completer, dataProvider,
          eventHandler, variableParser, audienceMatcher, eventLogger,
          application: application, environment: environment);
    }

    test('strict audience on environment matches', () async {
      final context = createContext();
      await context.waitUntilReady();

      expect(context.peekTreatment('exp_env'), equals(1));
      context.getTreatment('exp_env');
      expect(context.exposures_.last.audienceMismatch, isFalse);
    });

    test('strict audience on application matches', () async {
      final context = createContext();
      await context.waitUntilReady();

      expect(context.peekTreatment('exp_app'), equals(1));
      context.getTreatment('exp_app');
      expect(context.exposures_.last.audienceMismatch, isFalse);
    });

    test('strict audience on environment does not match wrong value', () async {
      final context = createContext();
      await context.waitUntilReady();

      expect(context.peekTreatment('exp_env_staging'), equals(0));
      context.getTreatment('exp_env_staging');
      expect(context.exposures_.last.audienceMismatch, isTrue);
    });

    test('user attribute overrides system value and invalidates cache',
        () async {
      final context = createContext();
      await context.waitUntilReady();

      // Cached before the override: production matches exp_env, staging doesn't.
      expect(context.peekTreatment('exp_env'), equals(1));
      expect(context.peekTreatment('exp_env_staging'), equals(0));

      // Overriding environment to staging flips both: the cached assignments
      // are invalidated by the attribute-sequence bump.
      context.setAttribute('environment', 'staging');

      expect(context.peekTreatment('exp_env'), equals(0));
      expect(context.peekTreatment('exp_env_staging'), equals(1));
    });

    test('user attribute set before ready overrides system value', () async {
      final context = createContext(attributes: {'environment': 'staging'});
      await context.waitUntilReady();

      expect(context.peekTreatment('exp_env'), equals(0));
      expect(context.peekTreatment('exp_env_staging'), equals(1));
    });

    test('missing environment config leaves the key out', () async {
      final context = createContext(environment: null);
      await context.waitUntilReady();

      expect(context.peekTreatment('exp_env'), equals(0));
      context.getTreatment('exp_env');
      expect(context.exposures_.last.audienceMismatch, isTrue);

      // The application filter still matches since application is configured.
      expect(context.peekTreatment('exp_app'), equals(1));
    });

    test('empty environment config leaves the key out', () async {
      final context = createContext(environment: '');
      await context.waitUntilReady();

      expect(context.peekTreatment('exp_env'), equals(0));
    });

    test('system attributes are not published', () async {
      final context = createContext(attributes: {'custom': 'value'});
      await context.waitUntilReady();

      context.getTreatment('exp_env');

      PublishEvent? captured;
      when(eventHandler.publish(any, any)).thenAnswer((invocation) {
        captured = invocation.positionalArguments[1] as PublishEvent;
        final completer = Completer<void>()..complete();
        return completer;
      });

      await context.publish();

      expect(captured, isNotNull);

      // Check the serialized payload, not just the in-memory object.
      final serialized = DefaultContextEventSerializer().serialize(captured!);
      final decoded =
          jsonDecode(utf8.decode(serialized!)) as Map<String, dynamic>;
      final attributes = (decoded['attributes'] as List)
          .map((a) => (a as Map<String, dynamic>)['name'] as String)
          .toList();

      expect(attributes, contains('custom'));
      expect(attributes, isNot(contains('application')));
      expect(attributes, isNot(contains('environment')));
      expect(attributes, isNot(contains('app_version')));
    });

    test('app_version is not injected into the evaluation map', () async {
      final context = createContext();
      await context.waitUntilReady();

      expect(context.peekTreatment('exp_appversion'), equals(0));
      context.getTreatment('exp_appversion');
      expect(context.exposures_.last.audienceMismatch, isTrue);
    });

    test('system attributes are available to audiences via getAttributesMap',
        () async {
      final context = createContext();
      await context.waitUntilReady();

      final attrs = context.getAttributesMap();
      expect(attrs['application'], equals('website'));
      expect(attrs['environment'], equals('production'));
      expect(attrs.containsKey('app_version'), isFalse);
    });
  });

  // End-to-end: the application and environment names flow from the client
  // config through ABSmartly.createContext into the evaluation map.
  group('System Attributes end-to-end through ABSmartly', () {
    test('client application and environment reach the evaluation map',
        () async {
      final dataBytes =
          await getResourceBytes('system_attributes_context.json');
      final clientConfig = ClientConfig()
          .setEndpoint('https://localhost/v1')
          .setAPIKey('test-api-key')
          .setApplication('website')
          .setEnvironment('production');
      final client =
          Client.create(clientConfig, httpClient: _StubHttpClient(dataBytes));

      final sdk = ABSmartly(ABSmartlyConfig.create().setClient(client));
      final context = sdk
          .createContext(ContextConfig.create()..setUnit('session_id', 'abc'));
      await context.waitUntilReady();

      expect(context.getAttributesMap()['application'], equals('website'));
      expect(context.getAttributesMap()['environment'], equals('production'));
      expect(context.peekTreatment('exp_env'), equals(1));
      expect(context.peekTreatment('exp_app'), equals(1));
      expect(context.peekTreatment('exp_env_staging'), equals(0));
    });
  });
}

// Returns the given context data bytes on GET and a 200 on PUT, so a real
// Client can be exercised without a network.
class _StubHttpClient implements HTTPClient {
  _StubHttpClient(this.dataBytes);

  final List<int> dataBytes;

  @override
  Future<Response> get(String url, Map<String, String>? query,
      Map<String, String>? headers) async {
    return DefaultResponse(
      statusCode: 200,
      statusMessage: 'OK',
      contentType: 'application/json',
      content: dataBytes,
    );
  }

  @override
  Future<Response> put(String url, Map<String, String>? query,
      Map<String, String>? headers, List<int>? body) async {
    return DefaultResponse(
      statusCode: 200,
      statusMessage: 'OK',
      contentType: 'application/json',
      content: const [],
    );
  }

  @override
  Future<Response> post(String url, Map<String, String>? query,
      Map<String, String>? headers, List<int>? body) async {
    return DefaultResponse(
      statusCode: 200,
      statusMessage: 'OK',
      contentType: 'application/json',
      content: const [],
    );
  }

  @override
  void close() {}
}
