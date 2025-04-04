import 'dart:async';
import 'json/context_data.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<ContextDataProvider>()])
abstract class ContextDataProvider {
  Completer<ContextData> getContextData();
}
