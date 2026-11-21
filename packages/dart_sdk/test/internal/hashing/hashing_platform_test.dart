import 'package:absmartly_dart/src/internal/hashing/hashing.dart';
import 'package:test/test.dart';

// Runs on the VM and compiled to JavaScript (CI: dart test -p node). Large
// values are parsed rather than written as literals, so the file compiles on
// both.
void main() {
  test('a large whole double hashes like JS toFixed(0) on every platform', () {
    final num uid = double.parse('1000000000000000128');
    expect(Hashing.hashInput(uid), '1000000000000000128');
    expect(Hashing.hashUnitValue(uid), Hashing.hashUnit('1000000000000000128'));
  });

  test('doubles and zero keep the toFixed(0) form', () {
    expect(Hashing.hashInput(125.75), '126');
    expect(Hashing.hashInput(-0.4), '-0');
    expect(Hashing.hashInput(-0.0), '0');
    expect(Hashing.hashInput(0), '0');
    expect(Hashing.hashInput(125), '125');
    expect(Hashing.hashInput(double.parse('1e21')), '1e+21');
  });
}
