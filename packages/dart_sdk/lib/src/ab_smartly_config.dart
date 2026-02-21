import 'variable_parser.dart';

import 'audience_deserializer.dart';
import 'client.dart';
import 'context_data_provider.dart';
import 'context_event_handler.dart';
import 'default_audience_deserializer.dart';
import 'default_variable_parser.dart';

class ABsmartlyConfig {
  static ABsmartlyConfig create() {
    return ABsmartlyConfig();
  }

  ABsmartlyConfig();

  ContextDataProvider? getContextDataProvider() {
    return contextDataProvider_;
  }

  ABsmartlyConfig setContextDataProvider(
      ContextDataProvider contextDataProvider) {
    contextDataProvider_ = contextDataProvider;
    return this;
  }

  ContextEventHandler? getContextEventHandler() {
    return contextEventHandler_;
  }

  ABsmartlyConfig setContextEventHandler(
      ContextEventHandler contextEventHandler) {
    contextEventHandler_ = contextEventHandler;
    return this;
  }

  VariableParser getVariableParser() {
    return variableParser_ ?? DefaultVariableParser();
  }

  ABsmartlyConfig setVariableParser(VariableParser variableParser) {
    variableParser_ = variableParser;
    return this;
  }

  AudienceDeserializer getAudienceDeserializer() {
    return audienceDeserializer_ ?? DefaultAudienceDeserializer();
  }

  ABsmartlyConfig setAudienceDeserializer(
      AudienceDeserializer audienceDeserializer) {
    audienceDeserializer_ = audienceDeserializer;
    return this;
  }

  Client? getClient() {
    return client_;
  }

  ABsmartlyConfig setClient(Client client) {
    client_ = client;
    return this;
  }

  void validate() {
    if (client_ == null) {
      throw ArgumentError('ABsmartlyConfig: client is required');
    }
    if (contextDataProvider_ == null) {
      throw ArgumentError('ABsmartlyConfig: contextDataProvider is required');
    }
  }

  ContextDataProvider? contextDataProvider_;
  ContextEventHandler? contextEventHandler_;

  VariableParser? variableParser_;

  AudienceDeserializer? audienceDeserializer_;

  Client? client_;
}
