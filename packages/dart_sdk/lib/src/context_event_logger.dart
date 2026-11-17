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
  close;

  /// The JavaScript SDK's name for [close]. An alias rather than a new value,
  /// so switches over [EventType] written for 2.1.x stay exhaustive.
  static const EventType finalize = close;
}
