// Work counters for tests that bound the cost of the Context read path. Not
// exported from the package.
class ContextCounters {
  ContextCounters._();

  // Attribute maps built for audience or rule evaluation.
  static int attributesMapBuilds = 0;

  // Rule keys built from an experiment's assignment rules.
  static int ruleKeyBuilds = 0;

  // Rule keys compared by content because they were not the same object.
  static int ruleKeyComparisons = 0;

  static void reset() {
    attributesMapBuilds = 0;
    ruleKeyBuilds = 0;
    ruleKeyComparisons = 0;
  }
}
