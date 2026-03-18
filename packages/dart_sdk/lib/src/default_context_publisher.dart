import 'dart:async';

import 'json/publish_event.dart';

import 'context_publisher.dart';
import 'client.dart';

class DefaultContextPublisher implements ContextPublisher {
  DefaultContextPublisher(this.client_);

  final Client client_;

  @override
  Completer<void> publish(context, PublishEvent event) {
    return client_.publish(event);
  }
}
