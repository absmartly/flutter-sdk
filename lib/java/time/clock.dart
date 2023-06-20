
import 'internal/fixed_clock.dart';
import 'internal/system_clock_utc.dart';

abstract class Clock {
  int millis();

  static Clock fixed(int millis) {
    return FixedClock(millis);
  }

  static Clock systemUTC() {
    if (utc_ != null) {
      return utc_!;
    }

    return utc_ = SystemClockUTC();
  }

  static SystemClockUTC? utc_;
}