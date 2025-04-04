import 'context.dart';

abstract class ContextEventLogger {
  void handleEvent(Context context, EventType type, dynamic data);
}

enum EventType {
  Error,
  Ready,
  Refresh,
  Publish,
  Exposure,
  Goal,
  Close,
}
