// Port of java-sdk SwitchbackServingTest, plus the cluster-value rule of
// SwitchbackClusterKeys on the VM and the web.
import 'package:absmartly_dart/src/internal/switchback_attribute_path.dart';
import 'package:absmartly_dart/src/internal/switchback_serving.dart';
import 'package:test/test.dart';

const bool isWeb = identical(0, 0.0);

void main() {
  // The declared source order decides, not the order of the units: with units
  // listed user first and sources declared session first, both agreeing,
  // session serves.
  test('sourceOrderDecidesWhateverTheUnitOrder', () {
    final units = [
      const SwitchbackUnit('user_id', 'u1'),
      const SwitchbackUnit('session_id', 'x1'),
    ];
    final attributes = {'session_store': 's-1', 'user_store': 's-1'};
    final serving = SwitchbackServing.resolve([
      'session_id',
      'user_id'
    ], [
      SwitchbackAttributePath.parseSupported('session_store')!,
      SwitchbackAttributePath.parseSupported('user_store')!
    ], null, units, (path) => path.resolve(attributes));

    expect(serving.status, SwitchbackStatus.eligible);
    expect(serving.unit!.type, 'session_id');
    expect(serving.clusterKey, 's-1');
  });

  // A non-empty string is used as-is and a whole-number integer becomes its
  // base-10 text. Every floating-point number, boolean, map, list, empty
  // string and null gives no value.
  test('normalizeFollowsTheClusterValueRule', () {
    expect(SwitchbackClusterKeys.normalize('s-1'), 's-1');
    expect(SwitchbackClusterKeys.normalize(' '), ' ');
    expect(SwitchbackClusterKeys.normalize(''), isNull);
    expect(SwitchbackClusterKeys.normalize(17), '17');
    expect(SwitchbackClusterKeys.normalize(-17), '-17');
    expect(SwitchbackClusterKeys.normalize(0), '0');
    expect(
        SwitchbackClusterKeys.normalize(9007199254740992), '9007199254740992');
    for (final value in [
      null,
      true,
      false,
      1.5,
      0.1,
      double.nan,
      double.infinity,
      {'a': 1},
      ['a'],
    ]) {
      expect(SwitchbackClusterKeys.normalize(value), isNull, reason: '$value');
    }
  });

  // On the VM a double never keys a cluster, whole or not. On the web 3.0
  // and 3 are the same number, so a whole-number double is the integer.
  test('wholeNumberDoublesFollowThePlatformNumberModel', () {
    if (isWeb) {
      expect(SwitchbackClusterKeys.normalize(3.0), '3');
      expect(SwitchbackClusterKeys.normalize(-0.0), '0');
      expect(SwitchbackClusterKeys.normalize(1e20), '100000000000000000000');
      // JavaScript prints 1e21 in exponent form, a float to the Collector.
      expect(SwitchbackClusterKeys.normalize(1e21), isNull);
      expect(SwitchbackClusterKeys.normalize(-1e21), isNull);
    } else {
      for (final value in [3.0, -0.0, 0.0, 1e20, 1e21, -1e21]) {
        expect(SwitchbackClusterKeys.normalize(value), isNull,
            reason: '$value');
      }
      // Integers beyond 2^53 keep every digit on the VM.
      expect(SwitchbackClusterKeys.normalize(int.parse('9007199254740993')),
          '9007199254740993');
    }
  });

  test('anAllowListAdmitsOnlyItsValuesAndEmptyAdmitsAll', () {
    expect(SwitchbackServing.allowed(null, 'x'), isTrue);
    expect(SwitchbackServing.allowed(const [], 'x'), isTrue);
    expect(SwitchbackServing.allowed(const ['x'], 'x'), isTrue);
    expect(SwitchbackServing.allowed(const ['y'], 'x'), isFalse);
  });

  test('sourcePathsIsNullForAMissingEmptyOrUnreadableMap', () {
    expect(SwitchbackServing.sourcePaths(null), isNull);
    expect(SwitchbackServing.sourcePaths(const {}), isNull);
    expect(SwitchbackServing.sourcePaths(const {'a': null}), isNull);
    expect(SwitchbackServing.sourcePaths(const {'a': 'x', 'b': "'y"}), isNull);
    expect(SwitchbackServing.sourcePaths(const {'a': 'x', 'b': 'y'}),
        hasLength(2));
  });
}
