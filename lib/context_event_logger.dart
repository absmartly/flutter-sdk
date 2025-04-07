import 'context.dart';

abstract class ContextEventLogger {
  void handleEvent(Context context, EventType type, dynamic data);
}

enum EventType {
  error,
  ready,
  refresh,
  publish,
  exposure,
  goal,
  close,
}
