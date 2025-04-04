import 'dart:async';

import 'context.dart';
import 'json/publish_event.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<ContextEventHandler>()])
abstract class ContextEventHandler {
  Completer<void> publish(Context context, PublishEvent event);
}
