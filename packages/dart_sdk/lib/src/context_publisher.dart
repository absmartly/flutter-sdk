import 'dart:async';

import 'context.dart';
import 'json/publish_event.dart';

abstract class ContextPublisher {
  // Complete when this event has been delivered. Do not await a re-entrant
  // context.publish() or context.close() here: both wait for this delivery,
  // so completing only after them would create a circular dependency.
  Completer<void> publish(Context context, PublishEvent event);
}
