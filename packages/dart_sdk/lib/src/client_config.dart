import 'dart:core';

import 'default_context_data_serializer.dart';

import 'context_data_deserializer.dart';
import 'context_event_serializer.dart';
import 'default_context_event_serializer.dart';

class ClientConfig {
  static ClientConfig create({
    String? endpoint,
    String? apiKey,
    String? environment,
    String? application,
    ContextDataDeserializer? contextDataDeserializer,
    ContextEventSerializer? contextEventSerializer,
  }) {
    final config = ClientConfig();
    if (endpoint != null) config.setEndpoint(endpoint);
    if (apiKey != null) config.setAPIKey(apiKey);
    if (environment != null) config.setEnvironment(environment);
    if (application != null) config.setApplication(application);
    if (contextDataDeserializer != null) {
      config.setContextDataDeserializer(contextDataDeserializer);
    }
    if (contextEventSerializer != null) {
      config.setContextEventSerializer(contextEventSerializer);
    }
    return config;
  }

  static ClientConfig createFromProperties(Map<String, dynamic> properties,
      [String? prefix]) {
    if (prefix == null) {
      return createFromProperties(properties, "");
    } else {
      return create(
        endpoint: properties["${prefix}endpoint"],
        environment: properties["${prefix}environment"],
        application: properties["${prefix}application"],
        apiKey: properties["${prefix}apikey"],
        contextDataDeserializer: DefaultContextDataDeserializer(),
      );
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
