import 'dart:async';

import 'package:absmartly_sdk/json/publish_event.dart';

import 'context_event_handler.dart';
import 'client.dart';

class DefaultContextEventHandler implements ContextEventHandler {
  DefaultContextEventHandler(this.client_);

  final Client client_;

  @override
  Completer<void> publish(context, PublishEvent event) {
    return client_.publish(event);
  }
}
