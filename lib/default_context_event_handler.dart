import 'package:absmartly_sdk/json/publish_event.dart';

import 'context_event_handler.dart';
import 'client.dart';

class DefaultContextEventHandler implements ContextEventHandler {
  DefaultContextEventHandler(this.client_);

  final Client client_;

  @override
  Future<void> publish(context, PublishEvent event) async {
    return client_.publish(event);
  }
}
