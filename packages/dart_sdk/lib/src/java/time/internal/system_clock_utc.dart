import '../clock.dart';

class SystemClockUTC extends Clock {
  @override
  int millis() {
    return DateTime.now().millisecondsSinceEpoch;
  }
}
