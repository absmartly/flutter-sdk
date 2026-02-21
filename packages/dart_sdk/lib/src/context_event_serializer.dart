import 'json/publish_event.dart';

abstract class ContextEventSerializer {
  List<int>? serialize(PublishEvent publishEvent);
}
