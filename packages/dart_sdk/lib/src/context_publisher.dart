import 'dart:async';

import 'context.dart';
import 'json/publish_event.dart';

abstract class ContextPublisher {
  Completer<void> publish(Context context, PublishEvent event);
}
