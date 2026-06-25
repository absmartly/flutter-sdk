import 'dart:convert';

import 'context_event_serializer.dart';
import 'json/publish_event.dart';

class DefaultContextEventSerializer implements ContextEventSerializer {
  @override
  List<int>? serialize(PublishEvent event) {
    try {
      return utf8.encode(jsonEncode(event.toMap()));
    } catch (e) {
      print(e);
      return null;
    }
  }
}
