// Work counters for tests that bound the cost of the Context read path. Not
// exported from the package.
class ContextCounters {
  ContextCounters._();

  static int attributesMapBuilds = 0;

  static int ruleKeyBuilds = 0;

  static int ruleKeyComparisons = 0;

  static int holdoutAssignmentLookups = 0;

  static int coveredAssignmentResolutions = 0;

  static int holdoutKeyLookups = 0;

  static int variableCandidateLookups = 0;

  static int assignmentLookups = 0;

  static int holdoutSetComparisons = 0;
  static int switchbackPeriodLookups = 0;

  static int switchbackServingResolutions = 0;

  static int slowAssignmentLookups = 0;

  static int keyOrderScans = 0;

  static void reset() {
    attributesMapBuilds = 0;
    ruleKeyBuilds = 0;
    ruleKeyComparisons = 0;
    holdoutAssignmentLookups = 0;
    coveredAssignmentResolutions = 0;
    holdoutKeyLookups = 0;
    variableCandidateLookups = 0;
    assignmentLookups = 0;
    holdoutSetComparisons = 0;
    switchbackPeriodLookups = 0;
    switchbackServingResolutions = 0;
    slowAssignmentLookups = 0;
    keyOrderScans = 0;
  }
}
