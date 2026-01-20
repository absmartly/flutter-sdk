import 'dart:core';

import 'package:absmartly_sdk/default_context_data_serializer.dart';

import 'context_data_deserializer.dart';
import 'context_event_serializer.dart';
import 'default_context_event_serializer.dart';

class ClientConfig {
  static ClientConfig create() {
    return ClientConfig();
  }

  static ClientConfig createFromProperties(Map<String, dynamic> properties,
      [String? prefix]) {
    if (prefix == null) {
      return createFromProperties(properties, "");
    } else {
      return create()
          .setEndpoint(properties["${prefix}endpoint"])
          .setEnvironment(properties["${prefix}environment"])
          .setApplication(properties["${prefix}application"])
          .setAPIKey(properties["${prefix}apikey"])
          .setContextDataDeserializer(DefaultContextDataDeserializer());
    }
  }

  ClientConfig();

  String? getEndpoint() {
    return endpoint_;
  }

  ClientConfig setEndpoint(String endpoint) {
    endpoint_ = endpoint;
    return this;
  }

  String? getAPIKey() {
    return apiKey_;
  }

  ClientConfig setAPIKey(String apiKey) {
    apiKey_ = apiKey;
    return this;
  }

  String? getEnvironment() {
    return environment_;
  }

  ClientConfig setEnvironment(String environment) {
    environment_ = environment;
    return this;
  }

  String? getApplication() {
    return application_;
  }

  ClientConfig setApplication(String application) {
    application_ = application;
    return this;
  }

  ContextDataDeserializer getContextDataDeserializer() {
    return deserializer_ ?? DefaultContextDataDeserializer();
  }

  ClientConfig setContextDataDeserializer(
      ContextDataDeserializer deserializer) {
    deserializer_ = deserializer;
    return this;
  }

  ContextEventSerializer getContextEventSerializer() {
    return serializer_ ?? DefaultContextEventSerializer();
  }

  ClientConfig setContextEventSerializer(ContextEventSerializer serializer) {
    serializer_ = serializer;
    return this;
  }

  String? endpoint_;
  late String? apiKey_;
  late String? environment_;
  late String? application_;

  ContextDataDeserializer? deserializer_;
  ContextEventSerializer? serializer_;
}
