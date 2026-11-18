// JS Number.MAX_SAFE_INTEGER: past it, distinct JSON numbers can decode to
// the same value, and dart2js and the VM disagree on which do.
const int _maxSafeInteger = 9007199254740991;

// [value] as an int when it is a whole number within +-(2^53 - 1), checked
// the same way for ints and doubles so the VM and the web agree; else null.
int? wholeNumber(dynamic value) {
  if (value is! num || !value.isFinite || value != value.truncate()) {
    return null;
  }
  // Not abs(): on the VM the minimum int's abs() overflows to itself.
  if (value < -_maxSafeInteger || value > _maxSafeInteger) {
    return null;
  }
  return value.toInt();
}
