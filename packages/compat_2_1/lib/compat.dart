// Written against the absmartly_sdk 2.1.2 README and public API. It must
// keep compiling against the published 2.1.2 package; do not use newer APIs.
// ignore_for_file: avoid_print, unused_local_variable
import 'dart:async';
import 'dart:typed_data';

import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:absmartly_sdk/ab_smartly.dart';
import 'package:absmartly_sdk/ab_smartly_config.dart' as old_cfg;
import 'package:absmartly_sdk/audience_deserializer.dart';
import 'package:absmartly_sdk/audience_matcher.dart';
import 'package:absmartly_sdk/client_config.dart';
import 'package:absmartly_sdk/context_config.dart';
import 'package:absmartly_sdk/context_data_deserializer.dart';
import 'package:absmartly_sdk/context_event_serializer.dart';
import 'package:absmartly_sdk/context_event_logger.dart';
import 'package:absmartly_sdk/default_http_client.dart';
import 'package:absmartly_sdk/default_http_client_config.dart';
import 'package:absmartly_sdk/http_client.dart';
import 'package:absmartly_sdk/variable_parser.dart';
import 'package:absmartly_sdk/java/time/clock.dart';
import 'package:absmartly_sdk/jsonexpr/json_expr.dart';
import 'package:absmartly_sdk/jsonexpr/operators/greater_then_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/less_then_or_eqal_operator.dart';
import 'package:absmartly_sdk/internal/hashing/hashing.dart';
import 'package:absmartly_sdk/internal/variant_assigner.dart';
import 'package:absmartly_sdk/json/experiment_application.dart';
import 'package:http/http.dart' as http;

class CustomEventLogger implements ContextEventLogger {
  final List<EventType> seen = [];
  @override
  void handleEvent(Context context, EventType event, dynamic data) {
    seen.add(event);
    switch (event) {
      case EventType.exposure:
        final Exposure exposure = data as Exposure;
        print("exposed to experiment ${exposure.name}");
        break;
      case EventType.goal:
        final GoalAchievement goal = data as GoalAchievement;
        print("goal tracked: ${goal.name}");
        break;
      case EventType.error:
        print("error: $data");
        break;
      case EventType.publish:
      case EventType.ready:
      case EventType.refresh:
      case EventType.close:
        break;
    }
  }
}

class MyHandler implements ContextEventHandler {
  @override
  Completer<void> publish(Context context, PublishEvent event) =>
      Completer<void>()..complete();
}

class MyProvider implements ContextDataProvider {
  @override
  Completer<ContextData> getContextData() =>
      Completer<ContextData>()..complete(ContextData());
}

class MyHttp implements HTTPClient {
  @override
  Future<Response> get(String url, Map<String, String>? query,
          Map<String, String>? headers) =>
      throw UnimplementedError();
  @override
  Future<Response> put(String url, Map<String, String>? query,
          Map<String, String>? headers, List<int>? body) =>
      throw UnimplementedError();
  @override
  Future<Response> post(String url, Map<String, String>? query,
          Map<String, String>? headers, List<int>? body) =>
      throw UnimplementedError();
  @override
  close() {}
}

class MyParser implements VariableParser {
  @override
  Map<String, dynamic>? parse(Context context, String experimentName,
          String variantName, String config) =>
      null;
}

class MyDeserializer implements AudienceDeserializer {
  @override
  Map<String, dynamic>? deserialize(List<int> bytes, int offset, int length) =>
      null;
}

class MyClient implements Client {
  @override
  Completer<ContextData> getContextData() => throw UnimplementedError();
  @override
  Completer<void> publish(PublishEvent event) => throw UnimplementedError();
  @override
  late String url_;
  @override
  late Map<String, String> query_;
  @override
  late Map<String, String> headers_;
  @override
  late HTTPClient httpClient_;
  @override
  ContextDataDeserializer? deserializer_;
  @override
  ContextEventSerializer? serializer_;
}

class MyClientConfig implements ClientConfig {
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
      throw UnimplementedError();
  @override
  ClientConfig setContextDataDeserializer(ContextDataDeserializer value) =>
      this..deserializer_ = value;
  @override
  ContextEventSerializer getContextEventSerializer() =>
      throw UnimplementedError();
  @override
  ClientConfig setContextEventSerializer(ContextEventSerializer value) =>
      this..serializer_ = value;
}

class MyConfig extends ABSmartlyConfig {}

// Every public member of the released Context, no noSuchMethod: a member
// added to Context breaks this class.
class MyContext implements Context {
  @override
  bool isReady() => throw UnimplementedError();
  @override
  bool isFailed() => throw UnimplementedError();
  @override
  bool isClosed() => throw UnimplementedError();
  @override
  bool isClosing() => throw UnimplementedError();
  @override
  Future<Context> waitUntilReady() => throw UnimplementedError();
  @override
  List<String> getExperiments() => throw UnimplementedError();
  @override
  ContextData getData() => throw UnimplementedError();
  @override
  void setOverride(final String experimentName, final int variant) =>
      throw UnimplementedError();
  @override
  int? getOverride(final String experimentName) => throw UnimplementedError();
  @override
  void setOverrides(Map<String, int> overrides) => throw UnimplementedError();
  @override
  void setCustomAssignment(String experimentName, int variant) =>
      throw UnimplementedError();
  @override
  int? getCustomAssignment(String experimentName) => throw UnimplementedError();
  @override
  void setCustomAssignments(Map<String, int> customAssignments) =>
      throw UnimplementedError();
  @override
  String? getUnit(final String unitType) => throw UnimplementedError();
  @override
  void setUnit(final String unitType, final String uid) =>
      throw UnimplementedError();
  @override
  Map<String, String> getUnits() => throw UnimplementedError();
  @override
  void setUnits(Map<String, String> units) => throw UnimplementedError();
  @override
  dynamic getAttribute(final String name) => throw UnimplementedError();
  @override
  void setAttribute(String name, dynamic value) => throw UnimplementedError();
  @override
  Map<String, dynamic> getAttributes() => throw UnimplementedError();
  @override
  void setAttributes(final Map<String, dynamic> attributes) =>
      throw UnimplementedError();
  @override
  int getTreatment(final String experimentName) => throw UnimplementedError();
  @override
  void queueExposure(final Assignment assignment) => throw UnimplementedError();
  @override
  int peekTreatment(final String experimentName) => throw UnimplementedError();
  @override
  Map<String, List<String>> getVariableKeys() => throw UnimplementedError();
  @override
  dynamic getVariableValue(final String key, final dynamic defaultValue) =>
      throw UnimplementedError();
  @override
  dynamic peekVariableValue(final String key, final dynamic defaultValue) =>
      throw UnimplementedError();
  @override
  void track(final String goalName, final Map<String, dynamic>? properties) =>
      throw UnimplementedError();
  @override
  Future<void> publish() => throw UnimplementedError();
  @override
  int getPendingCount() => throw UnimplementedError();
  @override
  Future<void> refresh() => throw UnimplementedError();
  @override
  Future<void> close() => throw UnimplementedError();
  @override
  Future<void> flush() => throw UnimplementedError();
  @override
  void checkNotClosed() => throw UnimplementedError();
  @override
  void checkReady(final bool expectNotClosed) => throw UnimplementedError();
  @override
  bool experimentMatches(
          final Experiment experiment, final Assignment assignment) =>
      throw UnimplementedError();
  @override
  Assignment getAssignment(final String experimentName) =>
      throw UnimplementedError();
  @override
  Assignment? getVariableAssignment(final String key) =>
      throw UnimplementedError();
  @override
  ExperimentVariables? getExperiment(final String experimentName) =>
      throw UnimplementedError();
  @override
  List<ExperimentVariables>? getVariableExperiments(final String key) =>
      throw UnimplementedError();
  @override
  Uint8List getUnitHash(final String unitType, final String unitUID) =>
      throw UnimplementedError();
  @override
  VariantAssigner getVariantAssigner(
          final String unitType, final Uint8List unitHash) =>
      throw UnimplementedError();
  @override
  void setTimeout() => throw UnimplementedError();
  @override
  void clearTimeout() => throw UnimplementedError();
  @override
  void setRefreshTimer() => throw UnimplementedError();
  @override
  void clearRefreshTimer() => throw UnimplementedError();
  @override
  void setData(final ContextData data) => throw UnimplementedError();
  @override
  void setDataFailed(exception) => throw UnimplementedError();
  @override
  void logEvent(EventType event, dynamic data) => throw UnimplementedError();
  @override
  void logError(error) => throw UnimplementedError();
  @override
  late Clock clock_;
  @override
  int publishDelay_ = 100;
  @override
  int refreshInterval_ = 0;
  @override
  late ContextEventHandler eventHandler_;
  @override
  late ContextDataProvider dataProvider_;
  @override
  late VariableParser variableParser_;
  @override
  late AudienceMatcher audienceMatcher_;
  @override
  late ContextEventLogger? eventLogger_;
  @override
  final Map<String, String> units_ = {};
  @override
  bool failed_ = false;
  @override
  ContextData? data_;
  @override
  Map<String, ExperimentVariables> index_ = {};
  @override
  Map<String, List<ExperimentVariables>> indexVariables_ = {};
  @override
  final Map<String, Uint8List> hashedUnits_ = {};
  @override
  final Map<String, VariantAssigner> assigners_ = {};
  @override
  final Map<String, Assignment> assignmentCache_ = {};
  @override
  final List<Exposure> exposures_ = [];
  @override
  final List<GoalAchievement> achievements_ = [];
  @override
  final List<Attribute> attributes_ = [];
  @override
  final Map<String, int> overrides_ = {};
  @override
  final Map<String, int> cassignments_ = {};
  @override
  int pendingCount_ = 0;
  @override
  bool closing_ = false;
  @override
  bool closed_ = false;
  @override
  bool refreshing_ = false;
  @override
  Completer<void>? readyFuture_;
  @override
  Completer<void>? closingFuture_;
  @override
  Completer<void>? refreshFuture_;
  @override
  Timer? timeout_;
  @override
  Timer? refreshTimer_;
}

// Every public member of the released ABSmartlyConfig.
class ImplABSmartlyConfig implements ABSmartlyConfig {
  @override
  ABSmartlyConfig setClient(Client client) => this;
  @override
  ABSmartlyConfig setContextDataProvider(ContextDataProvider provider) => this;
  @override
  ABSmartlyConfig setContextEventHandler(ContextEventHandler handler) => this;
  @override
  ABSmartlyConfig setContextEventLogger(ContextEventLogger logger) => this;
  @override
  ABSmartlyConfig setVariableParser(VariableParser parser) => this;
  @override
  ABSmartlyConfig setAudienceDeserializer(AudienceDeserializer deserializer) =>
      this;
  @override
  Client getClient() => throw UnimplementedError();
  @override
  ContextDataProvider getContextDataProvider() => throw UnimplementedError();
  @override
  ContextEventHandler getContextEventHandler() => throw UnimplementedError();
  @override
  ContextEventLogger? getContextEventLogger() => null;
  @override
  VariableParser getVariableParser() => throw UnimplementedError();
  @override
  AudienceDeserializer getAudienceDeserializer() => throw UnimplementedError();
}

class MyMatcher implements AudienceMatcher {
  @override
  late final AudienceDeserializer deserializer_;
  @override
  late final JsonExpr jsonExpr_;
  @override
  Result? evaluate(String audience, Map<String, dynamic>? attributes) => null;
}

// Public instance members of the published 2.1.2 models. Avoid noSuchMethod:
// a new interface member must cause a compile error in this fixture.
class MyExperiment implements Experiment {
  @override
  late int id;
  @override
  late String name;
  @override
  late String unitType;
  @override
  late int iteration;
  @override
  late int seedHi;
  @override
  late int seedLo;
  @override
  late List<double> split;
  @override
  late int trafficSeedHi;
  @override
  late int trafficSeedLo;
  @override
  late List<double> trafficSplit;
  @override
  late int fullOnVariant;
  @override
  late List<ExperimentApplication> applications;
  @override
  late List<ExperimentVariant> variants;
  @override
  late bool audienceStrict;
  @override
  late String? audience;
  @override
  Map<String, dynamic> toMap() => throw UnimplementedError();
}

class MyExposure implements Exposure {
  @override
  late int id;
  @override
  late String name;
  @override
  late String? unit;
  @override
  late int variant;
  @override
  late int exposedAt;
  @override
  late bool assigned;
  @override
  late bool eligible;
  @override
  late bool overridden;
  @override
  late bool fullOn;
  @override
  late bool custom;
  @override
  late bool audienceMismatch;
  @override
  Map<String, dynamic> toMap() => throw UnimplementedError();
}

extension Shout on String {
  String shout() => toUpperCase();
}

class ImplContextConfig implements ContextConfig {
  @override
  Map<String, String> units_ = {};
  @override
  Map<String, dynamic> attributes_ = {};
  @override
  Map<String, int> overrides_ = {};
  @override
  Map<String, int> cassigmnents_ = {};
  @override
  int publishDelay = 100;
  @override
  int refreshInterval = 0;
  @override
  ContextEventLogger? logger_;
  @override
  ContextConfig setUnit(String type, String uid) => this..units_[type] = uid;
  @override
  ContextConfig setUnits(Map<String, String> units) =>
      this..units_.addAll(units);
  @override
  String? getUnit(String type) => units_[type];
  @override
  Map<String, String> getUnits() => units_;
  @override
  ContextConfig setAttribute(String name, Object value) =>
      this..attributes_[name] = value;
  @override
  ContextConfig setAttributes(Map<String, dynamic> attributes) =>
      this..attributes_.addAll(attributes);
  @override
  dynamic getAttribute(String name) => attributes_[name];
  @override
  Map<String, dynamic> getAttributes() => attributes_;
  @override
  ContextConfig setOverride(String name, int variant) =>
      this..overrides_[name] = variant;
  @override
  ContextConfig setOverrides(Map<String, int> overrides) =>
      this..overrides_.addAll(overrides);
  @override
  dynamic getOverride(String name) => overrides_[name];
  @override
  Map<String, int> getOverrides() => overrides_;
  @override
  ContextConfig setCustomAssignment(String name, int variant) =>
      this..cassigmnents_[name] = variant;
  @override
  ContextConfig setCustomAssignments(Map<String, int> assignments) =>
      this..cassigmnents_.addAll(assignments);
  @override
  dynamic getCustomAssignment(String name) => cassigmnents_[name];
  @override
  Map<String, int> getCustomAssignments() => cassigmnents_;
  @override
  ContextConfig setPublishDelay(int delayMs) => this..publishDelay = delayMs;
  @override
  int getPublishDelay() => publishDelay;
  @override
  ContextConfig setRefreshInterval(int intervalMs) =>
      this..refreshInterval = intervalMs;
  @override
  int getRefreshInterval() => refreshInterval;
  @override
  ContextEventLogger? getContextEventLogger() => logger_;
  @override
  void setContextEventLogger(ContextEventLogger logger) => logger_ = logger;
}

class SubContextConfig extends ContextConfig {
  @override
  ContextConfig setUnit(final String unitType, final String uid) =>
      super.setUnit(unitType, uid);
}

class SubContext extends Context {
  SubContext(
      Clock clock,
      ContextConfig config,
      Completer<ContextData> dataFuture,
      ContextDataProvider dataProvider,
      ContextEventHandler eventHandler,
      VariableParser variableParser,
      AudienceMatcher audienceMatcher,
      ContextEventLogger? eventLogger)
      : super(clock, config, dataFuture, dataProvider, eventHandler,
            variableParser, audienceMatcher, eventLogger);

  Map<String, String>? seenUnits;

  @override
  void setUnits(Map<String, String> units) {
    seenUnits = Map.of(units);
    super.setUnits(units);
  }

  @override
  void setUnit(final String unitType, final String uid) {
    super.setUnit(unitType, uid);
  }
}

class Holder {
  late ContextEventHandler h;
  late ABSmartly sdk;
  late http.Response r; // package:http's Response alongside the barrel
}

Future<Map<String, Object?>> run() async {
  final ClientConfig clientConfig = ClientConfig()
    ..setEndpoint("https://your-company.absmartly.io/v1")
    ..setAPIKey("YOUR API KEY")
    ..setApplication("website")
    ..setEnvironment("development");
  final Client client = Client.create(clientConfig, httpClient: MyHttp());
  final ABSmartlyConfig sdkConfig = ABSmartlyConfig.create()
      .setClient(client)
      .setContextDataProvider(MyProvider())
      .setContextEventHandler(MyHandler());
  final old_cfg.ABSmartlyConfig oldConfig = old_cfg.ABSmartlyConfig.create()
      .setClient(client)
      .setContextEventHandler(MyHandler());
  final ContextEventHandler? oldHandler = oldConfig.contextEventHandler_;
  final ABSmartly sdk =
      ABSmartly(sdkConfig..setContextEventLogger(CustomEventLogger()));
  final ContextEventHandler handler = sdk.contextEventHandler_!;
  final Client? c = sdk.client_;

  final logger = sdk.contextEventLogger_ as CustomEventLogger;
  final ContextConfig contextConfig = ContextConfig.create()
      .setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8");
  contextConfig.setContextEventLogger(logger);
  final String? configUid = contextConfig.getUnit("session_id");
  final Map<String, String> configUnits = contextConfig.getUnits();

  final Context context =
      await sdk.createContext(contextConfig).waitUntilReady();
  context.setUnit("db_user_id", "1000013");
  context.setUnits({"db_user_id": "1000013"});
  final String? uid = context.getUnit("db_user_id");
  final Map<String, String> units = context.getUnits();
  final Map<String, String> unitsField = context.units_;
  final Map<String, String> configField = contextConfig.units_;
  final String shouted = context.getUnit("db_user_id")!.shout();
  final List<String> allShouted =
      context.getUnits().values.map((v) => v.shout()).toList();
  final int t = context.getTreatment("exp_test_experiment");
  final int p = context.peekTreatment("exp_test_experiment");
  final dynamic v = context.getVariableValue("button.color", "red");
  context.setOverride("exp", 1);
  context.setOverrides({"exp_test_experiment": 1});
  context.setAttribute("attribute", 1);
  context.setCustomAssignment("experimentName", 1);
  final int? ca = context.getCustomAssignment("experimentName");
  context.track("payment", {"item_count": 1, "total_amount": 1999.99});
  await context.publish();
  await context.close();
  String? closedError;
  try {
    context.track("x", null);
  } on Exception catch (e) {
    closedError = e.toString();
  }

  final Experiment e = Experiment(
      id: 1,
      name: 'e',
      unitType: 'u',
      iteration: 1,
      seedHi: 0,
      seedLo: 0,
      split: [1],
      trafficSeedHi: 0,
      trafficSeedLo: 0,
      trafficSplit: [0, 1],
      fullOnVariant: 0,
      applications: <ExperimentApplication>[],
      variants: [],
      audienceStrict: false,
      audience: null);
  final Exposure x = Exposure(
      id: 1,
      name: 'e',
      unit: 'u',
      variant: 0,
      exposedAt: 0,
      assigned: true,
      eligible: true,
      overridden: false,
      fullOn: false,
      custom: false,
      audienceMismatch: false);
  final Clock clock = Clock.fixed(1);
  final sub = SubContext(
      clock,
      ContextConfig.create().setUnit("session_id", "abc"),
      Completer<ContextData>()..complete(ContextData()),
      MyProvider(),
      MyHandler(),
      MyParser(),
      AudienceMatcher(MyDeserializer()),
      null);
  await sub.waitUntilReady();
  final m = AudienceMatcher(MyDeserializer());
  final JsonExpr j = JsonExpr();
  final GreaterThenOperator g = GreaterThenOperator();
  final LessThenOrEqualOperator l = LessThenOrEqualOperator();
  final h = Hashing.hashUnit("a");
  final dh = DefaultHTTPClient.create(DefaultHTTPClientConfig.create());
  dh.close();
  return {
    'configUid': configUid,
    'configUnits': configUnits,
    'uid': uid,
    'units': units,
    'unitsField': unitsField,
    'subUnits': sub.seenUnits,
    'configField': configField,
    'shouted': shouted,
    'allShouted': allShouted,
    't': t,
    'p': p,
    'v': v,
    'ca': ca,
    'closedError': closedError,
    'events': logger.seen.map((e) => e.name).toList(),
    'handler': handler.runtimeType.toString(),
    'oldHandler': oldHandler.runtimeType.toString(),
    'client': c != null,
    'e': e.name,
    'x': x.toMap(),
    'clock': clock.millis(),
    'm': m.runtimeType.toString(),
    'j': j.runtimeType.toString(),
    'g': g.runtimeType.toString(),
    'l': l.runtimeType.toString(),
    'h': h.length,
    'default': ABSmartly(ABSmartlyConfig.create().setClient(client))
        .contextEventHandler_
        .runtimeType
        .toString(),
  };
}
