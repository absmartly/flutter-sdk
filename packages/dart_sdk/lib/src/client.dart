import 'dart:async';
import 'dart:typed_data';
import 'default_http_client.dart';
import 'client_config.dart';
import 'default_context_data_serializer.dart';
import 'default_context_event_serializer.dart';
import 'default_http_client_config.dart';
import 'context_data_deserializer.dart';
import 'context_event_serializer.dart';
import 'http_client.dart';
import 'json/context_data.dart';
import 'json/publish_event.dart';
import 'sdk_version.dart';

class Client {
  static Client create(ClientConfig config, {HTTPClient? httpClient}) {
    if (httpClient == null) {
      return Client(
          config, DefaultHTTPClient.create(DefaultHTTPClientConfig.create()));
    } else {
      return Client(config, httpClient);
    }
  }

  Client(ClientConfig config, HTTPClient httpClient) {
    final String? endpoint = config.endpoint_;

    if ((endpoint == null) || endpoint.isEmpty) {
      throw ArgumentError("Missing Endpoint configuration");
    }

    final String? apiKey = config.apiKey_;
    if ((apiKey == null) || apiKey.isEmpty) {
      throw ArgumentError("Missing APIKey configuration");
    }

    final String? application = config.application_;
    if ((application == null) || application.isEmpty) {
      throw ArgumentError("Missing Application configuration");
    }

    final String? environment = config.environment_;
    if ((environment == null) || environment.isEmpty) {
      throw ArgumentError("Missing Environment configuration");
    }

    application_ = application;
    environment_ = environment;
    applicationVersion_ = config.applicationVersion_ ?? "0";

    url_ = "$endpoint/context";
    httpClient_ = httpClient;
    deserializer_ = config.deserializer_;
    serializer_ = config.serializer_;

    deserializer_ ??= DefaultContextDataDeserializer();

    serializer_ ??= DefaultContextEventSerializer();

    headers_ = {
      "X-API-Key": apiKey,
      "X-Application": application,
      "X-Environment": environment,
      // The collector parses X-Application-Version as a whole number and
      // rejects the request otherwise, so a version such as "2.4.1" is sent
      // as "0".
      "X-Application-Version": applicationVersionHeader(applicationVersion_),
      "X-Agent": SdkVersion.agent,
    };

    query_ = {
      "application": application,
      "environment": environment,
    };
  }

  Completer<ContextData> getContextData() {
    Completer<ContextData> dataFuture = Completer<ContextData>();

    httpClient_.get(url_, query_, headers_).then((response) {
      final int code = response.getStatusCode() ?? 0;
      if ((code / 100) == 2) {
        final Uint8List content =
            Uint8List.fromList(response.getContent() ?? []);
        final ContextData? data =
            deserializer_!.deserialize(content, 0, content.length);
        if (data != null) {
          dataFuture.complete(data);
        } else {
          dataFuture.completeError(
              Exception('Failed to deserialize context data response'));
        }
      } else {
        dataFuture.completeError(Exception(response.getStatusMessage()));
      }
    }).catchError((exception) {
      dataFuture.completeError(exception);
    });

    return dataFuture;
  }

  /// The configured application name, read by audience filters as the
  /// `application` attribute.
  String? getApplication() => application_;

  /// The configured environment name, read by audience filters as the
  /// `environment` attribute.
  String? getEnvironment() => environment_;

  /// The configured application version, or "0" when none is set.
  String getApplicationVersion() => applicationVersion_;

  /// The SDK name without version: "absmartly-dart-sdk".
  String getAgentName() => SdkVersion.name;

  /// The SDK version, e.g. "3.0.0".
  String getAgentVersion() => SdkVersion.version;

  /// The X-Agent header value: "<name>/<version>".
  String getAgent() => SdkVersion.agent;

  // At most 18 ASCII digits, so the value fits the collector's signed 64-bit
  // integer; anything else is sent as "0".
  static String applicationVersionHeader(String applicationVersion) {
    if (applicationVersion.isEmpty ||
        applicationVersion.length > 18 ||
        !RegExp(r'^[0-9]+$').hasMatch(applicationVersion)) {
      return "0";
    }
    return applicationVersion;
  }

  Completer<void> publish(final PublishEvent event) {
    Completer<void> publishFuture = Completer<void>();

    var content = serializer_?.serialize(event);

    httpClient_.put(url_, null, headers_, content).then((response) {
      final int code = response.getStatusCode() ?? 0;
      if ((code / 100) == 2) {
        publishFuture.complete();
      } else {
        publishFuture
            .completeError(Exception(response.getStatusMessage() ?? ""));
      }
    }).catchError((exception) {
      publishFuture.completeError(exception);
    });

    return publishFuture;
  }

  late final String url_;
  late final Map<String, String> query_;
  late final Map<String, String> headers_;
  late final HTTPClient httpClient_;

  String? application_;
  String? environment_;
  late final String applicationVersion_;

  ContextDataDeserializer? deserializer_;
  ContextEventSerializer? serializer_;
}
