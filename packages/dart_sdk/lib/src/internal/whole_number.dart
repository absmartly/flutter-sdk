// JS Number.MAX_SAFE_INTEGER: past it, distinct JSON numbers can decode to
// the same value, and dart2js and the VM disagree on which do.
const int _maxSafeInteger = 9007199254740991;

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
