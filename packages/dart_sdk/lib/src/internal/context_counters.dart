// Work counters for tests that bound the cost of the Context read path. Not
// exported from the package.
class ContextCounters {
  ContextCounters._();

  // Attribute maps built for audience or rule evaluation.
  static int attributesMapBuilds = 0;

  // Rule keys built from an experiment's assignment rules.
  static int ruleKeyBuilds = 0;

  static void reset() {
    attributesMapBuilds = 0;
    ruleKeyBuilds = 0;
  }
}
