
import 'json/context_data.dart';

import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<ContextDataDeserializer>()])

abstract class ContextDataDeserializer {
  ContextData? deserialize(List<int> bytes, int offset, int length);
}
