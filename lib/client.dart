import 'dart:async';
import 'dart:typed_data';
import 'package:absmartly_sdk/default_http_client.dart';
import 'client_config.dart';
import 'default_context_data_serializer.dart';
import 'default_context_event_serializer.dart';
import 'default_http_client_config.dart';
import 'context_data_deserializer.dart';
import 'context_event_serializer.dart';
import 'http_client.dart';
import 'json/context_data.dart';
import 'json/publish_event.dart';

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
      "X-Application-Version": "0",
      "X-Agent": "absmartly-dart-sdk",
    };

    query_ = {
      "application": application,
      "environment": environment,
    };
  }

  Completer<ContextData> getContextData() {
    Completer<ContextData> dataFuture = Completer<ContextData>();

    httpClient_.get(url_, query_, null).then((response) {
      final int code = response.getStatusCode() ?? 0;
      if ((code / 100) == 2) {
        final Uint8List content =
            Uint8List.fromList(response.getContent() ?? []);
        dataFuture.complete(deserializer_!.deserialize(
            Uint8List.fromList(response.getContent() ?? []),
            0,
            content.length));
      } else {
        dataFuture.completeError(Exception(response.getStatusMessage()));
      }
    }).catchError((exception) {
      dataFuture.completeError(exception);
    });

    return dataFuture;
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

  ContextDataDeserializer? deserializer_;
  ContextEventSerializer? serializer_;
}
