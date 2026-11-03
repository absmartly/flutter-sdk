import 'dart:async';

import 'json/publish_event.dart';

import 'default_context_publisher.dart';
import 'context_event_handler.dart';
import 'client.dart';

@Deprecated('Use DefaultContextPublisher instead.')
class DefaultContextEventHandler extends DefaultContextPublisher {
  DefaultContextEventHandler(Client client) : super(client);
}
