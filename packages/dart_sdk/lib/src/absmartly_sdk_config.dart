import 'context_event_logger.dart';
import 'default_audience_deserializer.dart';
import 'default_variable_parser.dart';

import 'client.dart';
import 'client_config.dart';
import 'context_data_provider.dart';
import 'context_event_handler.dart';
import 'default_context_data_provider.dart';
import 'default_context_event_handler.dart';
import 'default_http_client.dart';
import 'default_http_client_config.dart';
import 'http_client.dart';
import 'variable_parser.dart';
import 'audience_deserializer.dart';

class ABsmartlyConfig {
  Client? _client;
  ContextDataProvider? _contextDataProvider;
  ContextEventHandler? _contextEventHandler;
  VariableParser? _variableParser;
  AudienceDeserializer? _audienceDeserializer;
  ContextEventLogger? _contextEventLogger;

  // Client config parameters - allow creating client internally
  String? _endpoint;
  String? _apiKey;
  String? _application;
  String? _environment;
  HTTPClient? _httpClient;
  int? _retries;
  int? _timeout;

  ABsmartlyConfig();

  static ABsmartlyConfig create() {
    return ABsmartlyConfig();
  }

  // Client configuration methods (alternative to setClient)
  ABsmartlyConfig setEndpoint(String endpoint) {
    _endpoint = endpoint;
    return this;
  }

  ABsmartlyConfig setAPIKey(String apiKey) {
    _apiKey = apiKey;
    return this;
  }

  ABsmartlyConfig setApplication(String application) {
    _application = application;
    return this;
  }

  ABsmartlyConfig setEnvironment(String environment) {
    _environment = environment;
    return this;
  }

  ABsmartlyConfig setHTTPClient(HTTPClient httpClient) {
    _httpClient = httpClient;
    return this;
  }

  ABsmartlyConfig setRetries(int retries) {
    _retries = retries;
    return this;
  }

  ABsmartlyConfig setTimeout(int timeout) {
    _timeout = timeout;
    return this;
  }

  // Direct client override (for advanced use cases)
  ABsmartlyConfig setClient(Client client) {
    _client = client;
    return this;
  }

  ABsmartlyConfig setContextDataProvider(ContextDataProvider provider) {
    _contextDataProvider = provider;
    return this;
  }

  ABsmartlyConfig setContextEventHandler(ContextEventHandler handler) {
    _contextEventHandler = handler;
    return this;
  }

  ABsmartlyConfig setContextEventLogger(ContextEventLogger logger) {
    _contextEventLogger = logger;
    return this;
  }

  ABsmartlyConfig setVariableParser(VariableParser parser) {
    _variableParser = parser;
    return this;
  }

  ABsmartlyConfig setAudienceDeserializer(AudienceDeserializer deserializer) {
    _audienceDeserializer = deserializer;
    return this;
  }

  Client? getClient() {
    // Return explicitly set client if provided
    if (_client != null) {
      return _client;
    }

    // Create client automatically if config parameters are provided
    if (_endpoint != null && _apiKey != null && _application != null && _environment != null) {
      final clientConfig = ClientConfig();
      clientConfig.setEndpoint(_endpoint!);
      clientConfig.setAPIKey(_apiKey!);
      clientConfig.setApplication(_application!);
      clientConfig.setEnvironment(_environment!);

      final httpClient = _httpClient ?? DefaultHTTPClient.create(
        DefaultHTTPClientConfig()
          ..setMaxRetries(_retries ?? 5)
          ..setConnectTimeout(_timeout ?? 3000)
      );

      _client = Client.create(clientConfig, httpClient: httpClient);
      return _client;
    }

    // Client is optional - only needed if using default providers/handlers
    return null;
  }

  ContextDataProvider getContextDataProvider() {
    if (_contextDataProvider != null) {
      return _contextDataProvider!;
    }

    // Create default provider with client
    final client = getClient();
    if (client == null) {
      throw Exception("Cannot create DefaultContextDataProvider: missing client configuration. Either set a client, provide endpoint/apiKey/application/environment, or set a custom ContextDataProvider.");
    }
    return DefaultContextDataProvider(client);
  }

  ContextEventHandler getContextEventHandler() {
    if (_contextEventHandler != null) {
      return _contextEventHandler!;
    }

    // Create default handler with client
    final client = getClient();
    if (client == null) {
      throw Exception("Cannot create DefaultContextEventHandler: missing client configuration. Either set a client, provide endpoint/apiKey/application/environment, or set a custom ContextEventHandler.");
    }
    return DefaultContextEventHandler(client);
  }

  ContextEventLogger? getContextEventLogger() {
    return _contextEventLogger;
  }

  VariableParser getVariableParser() {
    if (_variableParser != null) {
      return _variableParser!;
    }
    return DefaultVariableParser();
  }

  AudienceDeserializer getAudienceDeserializer() {
    if (_audienceDeserializer != null) {
      return _audienceDeserializer!;
    }
    return DefaultAudienceDeserializer();
  }
}

/// Alias for backwards compatibility.
/// The correct name is ABsmartlyConfig (AB uppercase, smartly lowercase).
@Deprecated('Use ABsmartlyConfig instead. ABSmartlyConfig with uppercase S is deprecated.')
typedef ABSmartlyConfig = ABsmartlyConfig;
