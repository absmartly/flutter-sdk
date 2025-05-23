import 'package:absmartly_sdk/variable_parser.dart';

import 'audience_deserializer.dart';
import 'client.dart';
import 'context_data_provider.dart';
import 'context_event_handler.dart';
import 'default_audience_deserializer.dart';
import 'default_variable_parser.dart';

class ABSmartlyConfig {
  static ABSmartlyConfig create() {
    return ABSmartlyConfig();
  }

  ABSmartlyConfig();

  ContextDataProvider? getContextDataProvider() {
    return contextDataProvider_;
  }

  ABSmartlyConfig setContextDataProvider(
      ContextDataProvider contextDataProvider) {
    contextDataProvider_ = contextDataProvider;
    return this;
  }

  ContextEventHandler? getContextEventHandler() {
    return contextEventHandler_;
  }

  ABSmartlyConfig setContextEventHandler(
      ContextEventHandler contextEventHandler) {
    contextEventHandler_ = contextEventHandler;
    return this;
  }

  VariableParser getVariableParser() {
    return variableParser_ ?? DefaultVariableParser();
  }

  ABSmartlyConfig setVariableParser(VariableParser variableParser) {
    variableParser_ = variableParser;
    return this;
  }

  AudienceDeserializer getAudienceDeserializer() {
    return audienceDeserializer_ ?? DefaultAudienceDeserializer();
  }

  ABSmartlyConfig setAudienceDeserializer(
      AudienceDeserializer audienceDeserializer) {
    audienceDeserializer_ = audienceDeserializer;
    return this;
  }

  Client? getClient() {
    return client_;
  }

  ABSmartlyConfig setClient(Client client) {
    client_ = client;
    return this;
  }

  ContextDataProvider? contextDataProvider_;
  ContextEventHandler? contextEventHandler_;

  VariableParser? variableParser_;

  AudienceDeserializer? audienceDeserializer_;

  Client? client_;
}
