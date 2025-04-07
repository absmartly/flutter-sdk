import 'package:absmartly_sdk/context_event_logger.dart';
import 'package:absmartly_sdk/default_audience_deserializer.dart';
import 'package:absmartly_sdk/default_variable_parser.dart';

import 'client.dart';
import 'context_data_provider.dart';
import 'context_event_handler.dart';
import 'default_context_data_provider.dart';
import 'default_context_event_handler.dart';
import 'variable_parser.dart';
import 'audience_deserializer.dart';

class ABSmartlyConfig {
  Client? _client;
  ContextDataProvider? _contextDataProvider;
  ContextEventHandler? _contextEventHandler;
  VariableParser? _variableParser;
  AudienceDeserializer? _audienceDeserializer;
  ContextEventLogger? _contextEventLogger;

  ABSmartlyConfig();

  static ABSmartlyConfig create() {
    return ABSmartlyConfig();
  }

  ABSmartlyConfig setClient(Client client) {
    _client = client;
    return this;
  }

  ABSmartlyConfig setContextDataProvider(ContextDataProvider provider) {
    _contextDataProvider = provider;
    return this;
  }

  ABSmartlyConfig setContextEventHandler(ContextEventHandler handler) {
    _contextEventHandler = handler;
    return this;
  }

  ABSmartlyConfig setContextEventLogger(ContextEventLogger logger) {
    _contextEventLogger = logger;
    return this;
  }

  ABSmartlyConfig setVariableParser(VariableParser parser) {
    _variableParser = parser;
    return this;
  }

  ABSmartlyConfig setAudienceDeserializer(AudienceDeserializer deserializer) {
    _audienceDeserializer = deserializer;
    return this;
  }

  Client getClient() {
    if (_client == null) {
      throw Exception("Client not set in ABSmartlyConfig");
    }
    return _client!;
  }

  ContextDataProvider getContextDataProvider() {
    if (_contextDataProvider != null) {
      return _contextDataProvider!;
    }
    if (_client == null) {
      throw Exception("Missing Client instance");
    }
    return DefaultContextDataProvider(_client!);
  }

  ContextEventHandler getContextEventHandler() {
    if (_contextEventHandler != null) {
      return _contextEventHandler!;
    }
    if (_client == null) {
      throw Exception("Missing Client instance");
    }
    return DefaultContextEventHandler(_client!);
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
