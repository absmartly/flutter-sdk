import 'dart:async';

import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:test/test.dart';

import 'client_test.mocks.dart';

// Every Dart class is also an interface. These classes implement Client and
// ClientConfig with exactly the members of the released absmartly_sdk 2.1.2,
// so this file stops compiling if either class gains a public member and
// breaks customer code that implements it.
class LegacyClient implements Client {
  @override
  Completer<ContextData> getContextData() =>
      Completer<ContextData>()..complete(ContextData());

  @override
  Completer<void> publish(PublishEvent event) => Completer<void>()..complete();

  @override
  String url_ = 'https://example.com/context';
  @override
  Map<String, String> query_ = const {};
  @override
  Map<String, String> headers_ = const {};
  @override
  HTTPClient httpClient_ = MockHTTPClient();

  @override
  ContextDataDeserializer? deserializer_;
  @override
  ContextEventSerializer? serializer_;
}

class LegacyClientConfig implements ClientConfig {
  @override
  String? getEndpoint() => endpoint_;
  @override
  ClientConfig setEndpoint(String endpoint) => this..endpoint_ = endpoint;
  @override
  String? getAPIKey() => apiKey_;
  @override
  ClientConfig setAPIKey(String apiKey) => this..apiKey_ = apiKey;
  @override
  String? getEnvironment() => environment_;
  @override
  ClientConfig setEnvironment(String environment) =>
      this..environment_ = environment;
  @override
  String? getApplication() => application_;
  @override
  ClientConfig setApplication(String application) =>
      this..application_ = application;
  @override
  ContextDataDeserializer getContextDataDeserializer() =>
      DefaultContextDataDeserializer();
  @override
  ClientConfig setContextDataDeserializer(
          ContextDataDeserializer deserializer) =>
      this..deserializer_ = deserializer;
  @override
  ContextEventSerializer getContextEventSerializer() =>
      DefaultContextEventSerializer();
  @override
  ClientConfig setContextEventSerializer(ContextEventSerializer serializer) =>
      this..serializer_ = serializer;

  @override
  String? endpoint_;
  @override
  String? apiKey_;
  @override
  String? environment_;
  @override
  String? application_;
  @override
  ContextDataDeserializer? deserializer_;
  @override
  ContextEventSerializer? serializer_;
}

class LegacyExperiment implements Experiment {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LegacyExposure implements Exposure {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SubclassedClient extends Client {
  SubclassedClient(ClientConfig config) : super(config, MockHTTPClient());
}

void main() {
  ClientConfig config() => ClientConfig()
      .setEndpoint('https://example.com')
      .setAPIKey('key')
      .setApplication('website')
      .setEnvironment('production');

  test('a customer Client implementation still creates contexts', () async {
    final sdk = ABSmartly(ABSmartlyConfig.create(client: LegacyClient()));
    final context = sdk.createContext(ContextConfig.create()
      ..setUnit('session_id', 'abc')
      ..setPublishDelay(-1)
      ..setRefreshInterval(0));
    await context.waitUntilReady();

    expect(context.isFailed(), isFalse);
    expect(LegacyClient().getApplication(), isNull);
    expect(LegacyClient().getEnvironment(), isNull);
    expect(LegacyClient().getAgent(), SdkVersion.agent);
  });

  test('a customer ClientConfig implementation configures a Client', () {
    final legacy = LegacyClientConfig()
      ..setEndpoint('https://example.com')
      ..setAPIKey('key')
      ..setApplication('website')
      ..setEnvironment('production')
      ..setApplicationVersion('7');
    final client = Client(legacy, MockHTTPClient());

    expect(client.headers_['X-Application-Version'], '7');
    expect(client.getApplicationVersion(), '7');
  });

  test('a Client subclass keeps the SDK metadata', () {
    final client = SubclassedClient(config());

    expect(client.getApplication(), 'website');
    expect(client.getEnvironment(), 'production');
    expect(client.getApplicationVersion(), '0');
    expect(client.headers_['X-Agent'], SdkVersion.agent);
  });

  test('a customer Experiment implementation keeps the 2.2 fields', () {
    final experiment = LegacyExperiment();
    expect(experiment.assignmentRules, isNull);
    expect(experiment.customFieldValues, isNull);

    experiment.assignmentRules = '{"rules":[]}';
    experiment.customFieldValues = [
      CustomFieldValue(name: 'region', value: 'EU', type: 'string'),
    ];

    expect(experiment.assignmentRules, '{"rules":[]}');
    expect(experiment.customFieldValues!.single.name, 'region');
    expect(LegacyExperiment().assignmentRules, isNull);
  });

  test('a customer Exposure implementation keeps ruleOverride', () {
    final exposure = LegacyExposure();
    expect(exposure.ruleOverride, isFalse);

    exposure.ruleOverride = true;

    expect(exposure.ruleOverride, isTrue);
    expect(LegacyExposure().ruleOverride, isFalse);
  });

  test('contexts are created after a 2.1 caller clears client_', () async {
    final sdk = ABSmartly(ABSmartlyConfig.create(client: LegacyClient()))
      ..client_ = null;
    final contextConfig = ContextConfig.create()
      ..setUnit('session_id', 'abc')
      ..setPublishDelay(-1)
      ..setRefreshInterval(0);

    final created = sdk.createContext(contextConfig);
    await created.waitUntilReady();
    expect(created.isFailed(), isFalse);

    final prefetched = sdk.createContextWith(contextConfig, ContextData());
    await prefetched.waitUntilReady();
    expect(prefetched.isFailed(), isFalse);
  });
}
