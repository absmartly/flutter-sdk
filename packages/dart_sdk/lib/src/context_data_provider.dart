import 'dart:async';
import 'json/context_data.dart';

abstract class ContextDataProvider {
  Completer<ContextData> getContextData();
}
