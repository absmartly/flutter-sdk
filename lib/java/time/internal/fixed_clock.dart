import 'package:absmartly_sdk/java/time/clock.dart';

class FixedClock extends Clock {
  int mills;

  FixedClock(this.mills);

  @override
  int millis() {
    return mills;
  }
}
