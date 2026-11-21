// Work counters for tests that bound the cost of the Context read path. Not
// exported from the package.
class ContextCounters {
  ContextCounters._();

  static int attributesMapBuilds = 0;

  static int ruleKeyBuilds = 0;

  static int ruleKeyComparisons = 0;

  static int modelFieldProbes = 0;

  static void reset() {
    attributesMapBuilds = 0;
    ruleKeyBuilds = 0;
    ruleKeyComparisons = 0;
    modelFieldProbes = 0;
  }
}
