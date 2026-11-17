import 'package:absmartly_sdk_compat_2_1/compat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('code written for 2.1.2 runs with its released behaviour', () async {
    final r = await run();
    expect(r['configUid'], '5ebf06d8cb5d8137290c4abb64155584fbdb64d8');
    expect(r['configUnits'],
        {'session_id': '5ebf06d8cb5d8137290c4abb64155584fbdb64d8'});
    expect(r['uid'], '1000013');
    expect(r['units'], {
      'session_id': '5ebf06d8cb5d8137290c4abb64155584fbdb64d8',
      'db_user_id': '1000013',
    });
    expect(r['unitsField'], r['units']);
    expect(r['configField'],
        {'session_id': '5ebf06d8cb5d8137290c4abb64155584fbdb64d8'});
    expect(r['shouted'], '1000013');
    expect(r['subUnits'], {'session_id': 'abc'});
    expect(r['t'], 0);
    expect(r['v'], 'red');
    expect(r['ca'], 1);
    expect(r['closedError'], 'Exception: ABSmartly Context is closed');
    expect(r['events'], ['ready', 'exposure', 'goal', 'publish', 'close']);
    expect(r['handler'], 'MyHandler');
    expect(r['oldHandler'], 'MyHandler');
    expect(r['default'], 'DefaultContextEventHandler');
    expect(r['g'], 'GreaterThanOperator');
  });
}
