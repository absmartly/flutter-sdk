library absmartly_sdk;

import 'dart:async';

import 'context_event_logger.dart';
import 'variable_parser.dart';

import 'absmartly_sdk_config.dart';
import 'audience_deserializer.dart';
import 'audience_matcher.dart';
import 'context.dart';
import 'context_config.dart';
import 'context_data_provider.dart';
import 'context_event_handler.dart';
import 'http_client.dart';
import 'java/time/clock.dart';
import 'client.dart';
import 'json/context_data.dart';

class ABsmartly {
  /// Constructor accepting ABsmartlyConfig (for backwards compatibility).
  ///
  /// Prefer using ABsmartly.create() factory for cleaner syntax.
  ABsmartly(ABsmartlyConfig config, {Client? client}) {
    contextDataProvider_ = config.getContextDataProvider();
    contextEventHandler_ = config.getContextEventHandler();
    contextEventLogger_ = config.getContextEventLogger();
    variableParser_ = config.getVariableParser();
    audienceDeserializer_ = config.getAudienceDeserializer();
    client_ = client ?? config.getClient();

    // Client is optional - only needed if using default providers/handlers
    // If custom providers/handlers are set, client may be null
  }

  /// Create an ABsmartly SDK instance with simplified configuration.
  ///
  /// This is the recommended way to create an SDK instance. Simply provide
  /// your endpoint, API key, application, and environment:
  ///
  /// ```dart
  /// final sdk = ABsmartly.create(
  ///   endpoint: 'https://your-company.absmartly.io',
  ///   apiKey: 'your-api-key',
  ///   application: 'website',
  ///   environment: 'production',
  /// );
  /// ```
  ///
  /// You can also pass a pre-configured client directly:
  /// ```dart
  /// final client = Client.createWithParams(
  ///   endpoint: 'https://your-company.absmartly.io',
  ///   apiKey: 'your-api-key',
  ///   application: 'website',
  ///   environment: 'production',
  /// );
  /// final sdk = ABsmartly.create(client: client);
  /// ```
  ///
  /// All parameters are optional for advanced use cases where you provide
  /// custom implementations of ContextDataProvider or ContextEventHandler.
  factory ABsmartly.create({
    String? endpoint,
    String? apiKey,
    String? application,
    String? environment,
    Client? client,
    HTTPClient? httpClient,
    int? retries,
    int? timeout,
    ContextDataProvider? contextDataProvider,
    ContextEventHandler? contextEventHandler,
    ContextEventLogger? contextEventLogger,
    VariableParser? variableParser,
    AudienceDeserializer? audienceDeserializer,
  }) {
    final config = ABsmartlyConfig();

    if (client != null) {
      config.setClient(client);
    } else if (endpoint != null) {
      config.setEndpoint(endpoint);
      if (apiKey != null) config.setAPIKey(apiKey);
      if (application != null) config.setApplication(application);
      if (environment != null) config.setEnvironment(environment);
      if (httpClient != null) config.setHTTPClient(httpClient);
      if (retries != null) config.setRetries(retries);
      if (timeout != null) config.setTimeout(timeout);
    }

    if (contextDataProvider != null) {
      config.setContextDataProvider(contextDataProvider);
    }
    if (contextEventHandler != null) {
      config.setContextEventHandler(contextEventHandler);
    }
    if (contextEventLogger != null) {
      config.setContextEventLogger(contextEventLogger);
    }
    if (variableParser != null) {
      config.setVariableParser(variableParser);
    }
    if (audienceDeserializer != null) {
      config.setAudienceDeserializer(audienceDeserializer);
    }

    return ABsmartly(config, client: client);
  }

  Context createContext(ContextConfig config) {
    return Context.create(
        Clock.systemUTC(),
        config,
        contextDataProvider_!.getContextData(),
        contextDataProvider_!,
        contextEventHandler_!,
        variableParser_!,
        AudienceMatcher(audienceDeserializer_!),
        contextEventLogger_);
  }

  Context createContextWith(ContextConfig config, ContextData data) {
    return Context.create(
        Clock.systemUTC(),
        config,
        Completer<ContextData>()..complete(data),
        contextDataProvider_!,
        contextEventHandler_!,
        variableParser_!,
        AudienceMatcher(audienceDeserializer_!),
        contextEventLogger_);
  }

  Future<ContextData> getContextData() {
    return contextDataProvider_!.getContextData().future;
  }

  Client? client_;
  late ContextDataProvider? contextDataProvider_;
  late ContextEventHandler? contextEventHandler_;
  late ContextEventLogger? contextEventLogger_;
  late VariableParser? variableParser_;
  late AudienceDeserializer? audienceDeserializer_;
}

/// Alias for backwards compatibility.
/// The correct name is ABsmartly (AB uppercase, smartly lowercase).
@Deprecated('Use ABsmartly instead. ABSmartly with uppercase S is deprecated.')
typedef ABSmartly = ABsmartly;
