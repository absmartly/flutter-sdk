import 'dart:async';

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
  Timer? _scheduler;
  AudienceDeserializer? _audienceDeserializer;

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

  ABSmartlyConfig setVariableParser(VariableParser parser) {
    _variableParser = parser;
    return this;
  }

  ABSmartlyConfig setScheduler(Timer scheduler) {
    _scheduler = scheduler;
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

  VariableParser? getVariableParser() => _variableParser;

  Timer? getScheduler() => _scheduler;

  AudienceDeserializer? getAudienceDeserializer() => _audienceDeserializer;
}
