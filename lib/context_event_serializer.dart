import 'json/publish_event.dart';

import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<ContextEventSerializer>()])

abstract class ContextEventSerializer {
  List<int>? serialize(PublishEvent publishEvent);
}
