// Port of java-sdk ContextSwitchbackClusterTest: cluster key selection
// inside Context. Variants are derived from the raw key and
// SwitchbackAssigner, both pinned by the platform golden vectors.
import 'package:absmartly_dart/src/context.dart';
import 'package:absmartly_dart/src/internal/hashing/hashing.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:absmartly_dart/src/json/exposure.dart';
import 'package:absmartly_dart/src/json/publish_event.dart';
import 'package:test/test.dart';

import 'switchback_test_support.dart';

const bool isWeb = identical(0, 0.0);

// 3 arms over 12 periods: two keys in different buckets are told apart by
// their schedules.
const int arms = 3;

Experiment attributeSwitchback(String path) =>
    sb(arms, hour)..switchbackClusters = {unitType: path};

int expected(String key, int periodIndex) => draw(key, periodIndex, arms);

List<int> expectedSchedule(String key) =>
    [for (int i = 0; i < 12; ++i) expected(key, i)];

Exposure clusterExposure(int variant, int exposedAt,
        {bool eligible = true, bool audienceMismatch = false}) =>
    exposure(1, 'exp_sb', variant, exposedAt,
        eligible: eligible, audienceMismatch: audienceMismatch);

void main() {
  late Harness h;

  setUp(() {
    h = Harness();
  });

  Future<Context> create(Experiment experiment,
          {Map<String, Object>? units, Harness? harness}) =>
      (harness ?? h)
          .create(dataOf([experiment]), units: units, clusterAttribute: false);

  List<int> peekSchedule(Context context, [Harness? harness]) =>
      (harness ?? h).peekSchedule(context, 'exp_sb', hour, 12);

  Future<PublishEvent> exposeAndPublish(
      Context context, Harness harness) async {
    harness.clock.now = anchor;
    context.getTreatment('exp_sb');
    await context.publish();
    return harness.publisher.events.single;
  }

  // The unit uid is never the cluster key: with no cluster value the unit is
  // ineligible.
  test('unitUidIsNeverTheClusterKey', () async {
    final context = await create(attributeSwitchback('city'));
    for (int i = 0; i < 3; ++i) {
      h.clock.now = anchor + i * hour;
      expect(context.getTreatment('exp_sb'), 0);
    }
    expect(context.getPendingCount(), 0);
  });

  // A numeric UID serves and publishes under its canonical string, exactly
  // as the same string UID does; the cluster key is the attribute.
  test('numericUnitUidClustersLikeItsCanonicalString', () async {
    final List<List<Object>> cases = [
      [123456789, '123456789'],
      [123456789.0, '123456789'],
      [125.75, '126'],
    ];
    for (final pair in cases) {
      final numericHarness = Harness();
      final numeric = await create(attributeSwitchback('city'),
          units: {unitType: pair[0]}, harness: numericHarness);
      numeric.setAttribute('city', 'Lisboa');
      final numericEvent = await exposeAndPublish(numeric, numericHarness);
      final numericSchedule = peekSchedule(numeric, numericHarness);

      final textHarness = Harness();
      final text = await create(attributeSwitchback('city'),
          units: {unitType: pair[1]}, harness: textHarness);
      text.setAttribute('city', 'Lisboa');
      final textEvent = await exposeAndPublish(text, textHarness);

      expect(numericSchedule, expectedSchedule('Lisboa'));
      expect(numericSchedule, peekSchedule(text, textHarness));
      expect(numericEvent.units, textEvent.units);
      expect(numericEvent.exposures, textEvent.exposures);
      expect(numericEvent.units.single.uid,
          String.fromCharCodes(Hashing.hashUnit(pair[1] as String)));
    }
  });

  // Independent reference (Python MD5/base64url) for the published hash of a
  // numeric UID, and the raw-key schedule of "123456789" as a numeric
  // attribute value (murmur3 reference).
  test('numericUnitUidMatchesTheIndependentReference', () async {
    const schedule = [0, 2, 1, 0, 1, 2, 0, 1, 2, 2, 1, 0];
    final harness = Harness();
    final context = await create(attributeSwitchback('region'),
        units: {unitType: 123456789}, harness: harness);
    context.setAttribute('region', 123456789);
    final event = await exposeAndPublish(context, harness);

    expect(event.units.single.uid, 'JfnnlDI7RTiF9RgfG2JNCw');
    expect(event.exposures, [clusterExposure(schedule[0], anchor)]);
    expect(peekSchedule(context, harness), schedule);
  });

  // Periods 0..11 of the raw key "Lisboa", from the independent murmur3
  // reference.
  test('attributeSourceServesTheRawAttributeValue', () async {
    final context = await create(attributeSwitchback('city'));
    context.setAttribute('city', 'Lisboa');
    expect(peekSchedule(context), [0, 2, 1, 2, 1, 0, 1, 0, 2, 0, 1, 2]);
    expect(peekSchedule(context), expectedSchedule('Lisboa'));
  });

  test('unitsSharingAnAttributeValueShareTheSchedule', () async {
    final lisboa = await create(attributeSwitchback('city'));
    lisboa.setAttribute('city', 'Lisboa');
    final portoHarness = Harness();
    final porto =
        await create(attributeSwitchback('city'), harness: portoHarness);
    porto.setAttribute('city', 'Porto');
    final otherHarness = Harness();
    final otherLisboa = await create(attributeSwitchback('city'),
        units: {unitType: 'another-store'}, harness: otherHarness);
    otherLisboa.setAttribute('city', 'Lisboa');

    expect(peekSchedule(lisboa), expectedSchedule('Lisboa'));
    expect(peekSchedule(otherLisboa, otherHarness), expectedSchedule('Lisboa'));
    expect(peekSchedule(porto, portoHarness), expectedSchedule('Porto'));
    expect(expectedSchedule('Lisboa'), isNot(expectedSchedule('Porto')));
  });

  test('nestedAndArrayPathsAndIntegerValuesResolve', () async {
    final nested = await create(attributeSwitchback('geo/city'));
    nested.setAttribute('geo', {'city': 'Porto'});
    expect(peekSchedule(nested), expectedSchedule('Porto'));

    h.clock.now = anchor;
    final array = await create(attributeSwitchback('items/1/city'));
    array.setAttribute('items', [
      {'city': 'Lisbon'},
      {'city': 'Faro'}
    ]);
    expect(peekSchedule(array), expectedSchedule('Faro'));

    h.clock.now = anchor;
    final integer = await create(attributeSwitchback('region'));
    integer.setAttribute('region', 42);
    expect(peekSchedule(integer), expectedSchedule('42'));

    h.clock.now = anchor;
    final nestedInteger = await create(attributeSwitchback('geo/city'));
    nestedInteger.setAttribute('geo', {'city': 42});
    expect(peekSchedule(nestedInteger), expectedSchedule('42'));

    h.clock.now = anchor + 10;
    final floating = await create(attributeSwitchback('city'));
    floating.setAttribute('city', 2.5);
    expect(floating.getTreatment('exp_sb'), 0);
    expect(floating.getPendingCount(), 0);
  });

  // Attribute values that yield no cluster key serve variant 0, not
  // eligible, record no exposure and never throw. On the web a whole-number
  // double is an integer (see wholeNumberDoublesKeyLikeIntegersOnTheWeb).
  test('valuesWithoutAClusterKeyAreIneligible', () async {
    for (final value in [
      null,
      '',
      true,
      1.5,
      if (!isWeb) 2.0,
      {'a': 'b'},
      ['x']
    ]) {
      final harness = Harness();
      final context =
          await create(attributeSwitchback('city'), harness: harness);
      context.setAttribute('city', value);
      harness.clock.now = anchor + 10;
      expect(context.getTreatment('exp_sb'), 0, reason: '$value');
      // Variant 0's own config, like any ineligible assignment.
      expect(context.getVariableValue('sb.arm', -1), 0, reason: '$value');
      expect(context.getPendingCount(), 0, reason: '$value');
    }

    final missing = await create(attributeSwitchback('geo/city'));
    missing.setAttribute('geo', {'country': 'PT'});
    h.clock.now = anchor + 10;
    expect(missing.getTreatment('exp_sb'), 0);
    expect(missing.getPendingCount(), 0);
  });

  // The web cannot tell 3.0 from 3, so 3.0 keys the cluster "3" there, as the
  // integer does; on the VM a double never keys a cluster.
  test('wholeNumberDoublesKeyLikeIntegersOnTheWeb', () async {
    final context = await create(attributeSwitchback('city'));
    context.setAttribute('city', 3.0);
    h.clock.now = anchor + hour;
    expect(context.getTreatment('exp_sb'), isWeb ? expected('3', 1) : 0);
    expect(context.getPendingCount(), isWeb ? 1 : 0);
  });

  // A value with no JSON encoding has no cluster key.
  test('unencodableAttributeValuesAreIneligible', () async {
    final Map<String, dynamic> cyclic = {};
    cyclic['self'] = cyclic;
    for (final value in [cyclic, Object()]) {
      final harness = Harness();
      final context =
          await create(attributeSwitchback('geo/city'), harness: harness);
      context.setAttribute('geo', value);
      expect(context.getTreatment('exp_sb'), 0);
      expect(context.getPendingCount(), 0);
    }
  });

  // Unservable configurations serve an ineligible control to linked units,
  // never a unit-assignment draw, and record nothing.
  test('unservableConfigurationsAreIneligible', () async {
    final experiments = [
      for (final path in [
        'items/0',
        'items/-1/city',
        '',
        'geo.city',
        "'city",
        '"city'
      ])
        attributeSwitchback(path),
      attributeSwitchback('city')..switchbackPeriodMs = null,
      attributeSwitchback('city')..switchbackPeriodMs = 0,
      attributeSwitchback('city')..switchbackPeriodMs = -hour,
      attributeSwitchback('city')..split = [1.0],
      attributeSwitchback('city')..switchbackClusters = {unitType: null},
    ];
    for (final experiment in experiments) {
      final harness = Harness();
      final context = await create(experiment, harness: harness);
      context.setAttribute('city', 'Lisboa');
      context.setAttribute('items', [
        {'city': 'Lisbon'}
      ]);
      for (int i = 0; i < 3; ++i) {
        harness.clock.now = anchor + i * hour;
        expect(context.getTreatment('exp_sb'), 0, reason: '$experiment');
      }
      expect(context.getPendingCount(), 0, reason: '$experiment');
    }
  });

  // A missing or empty cluster map takes the legacy path: a unit of the
  // declared unitType only identifies an ineligible control (variant 0's
  // config, no exposure); without one the experiment does not apply.
  test('missingOrEmptyClusterMapIsOnlyALegacyIneligibleControl', () async {
    for (final clusters in [null, <String, String?>{}]) {
      final experiment = attributeSwitchback('city')
        ..switchbackClusters = clusters;
      final harness = Harness();
      final context = await create(experiment, harness: harness);
      context.setAttribute('city', 'Lisboa');
      expect(context.getTreatment('exp_sb'), 0);
      expect(context.getVariableValue('sb.arm', -1), 0);
      expect(context.getPendingCount(), 0);

      final other = await create(experiment,
          units: {'user_id': 'u1'}, harness: Harness());
      other.setAttribute('city', 'Lisboa');
      expect(other.getTreatment('exp_sb'), 0);
      expect(other.getVariableValue('sb.arm', -1), -1);
      expect(other.getPendingCount(), 0);
    }
  });

  // The Collector reads the attribute set at or before the exposure instant,
  // latest setAt first.
  test('latestAttributeSetAtOrBeforeTheResolutionInstantIsUsed', () async {
    final context = await create(attributeSwitchback('city'));
    h.clock.now = anchor + 2 * hour;
    context.setAttribute('city', 'Porto');
    h.clock.now = anchor + 4 * hour;
    context.setAttribute('city', 'Lisboa');

    h.clock.now = anchor + hour;
    expect(context.peekTreatment('exp_sb'), 0);
    h.clock.now = anchor + 3 * hour;
    expect(context.peekTreatment('exp_sb'), expected('Porto', 3));
    h.clock.now = anchor + 4 * hour;
    expect(context.peekTreatment('exp_sb'), expected('Lisboa', 4));
  });

  // Attribute names are matched trimmed, and only attributes set on the
  // context are read: system attributes are never a cluster source.
  test('attributeNamesAreTrimmedAndSystemAttributesAreNotRead', () async {
    final context = await create(attributeSwitchback('city'));
    context.setAttribute(' city ', 'Lisboa');
    h.clock.now = anchor + 2 * hour;
    expect(context.peekTreatment('exp_sb'), expected('Lisboa', 2));

    final system =
        await create(attributeSwitchback('environment'), harness: Harness());
    expect(system.getTreatment('exp_sb'), 0);
    expect(system.getPendingCount(), 0);
  });

  // Within a period the cluster key is fixed at first resolution; the next
  // period reads the attribute again.
  test('setAttributeMidPeriodDoesNotReassignWithinThePeriod', () async {
    final context = await create(attributeSwitchback('city'));
    h.clock.now = anchor + 10;
    context.setAttribute('city', 'Lisboa');
    expect(context.getTreatment('exp_sb'), expected('Lisboa', 0));

    h.clock.now = anchor + 20;
    context.setAttribute('city', 'Porto');
    expect(context.getTreatment('exp_sb'), expected('Lisboa', 0));
    expect(context.peekTreatment('exp_sb'), expected('Lisboa', 0));
    expect(context.getPendingCount(), 1);

    int differing = 0;
    for (int i = 1; i < 12; ++i) {
      h.clock.now = anchor + i * hour;
      expect(context.getTreatment('exp_sb'), expected('Porto', i));
      if (expected('Porto', i) != expected('Lisboa', i)) {
        ++differing;
      }
    }
    expect(differing, isNot(0));
    expect(context.getPendingCount(), 12);
  });

  // A unit first resolved without a key stays ineligible (and unrecorded)
  // for the rest of that period.
  test('attributeSetAfterAnIneligibleResolutionWaitsForTheNextPeriod',
      () async {
    final context = await create(attributeSwitchback('city'));
    h.clock.now = anchor + 10;
    expect(context.getTreatment('exp_sb'), 0);
    context.setAttribute('city', 'Lisboa');
    h.clock.now = anchor + 20;
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getPendingCount(), 0);

    h.clock.now = anchor + hour;
    expect(context.getTreatment('exp_sb'), expected('Lisboa', 1));
    expect(await h.publishExposures(context),
        [clusterExposure(expected('Lisboa', 1), anchor + hour)]);
  });

  // A slot replaced through an ineligible resolution still keeps the
  // period's first key.
  test('trafficChangesWithinThePeriodKeepThePeriodsBucket', () async {
    final context = await create(attributeSwitchback('city'));
    h.clock.now = anchor + 10;
    context.setAttribute('city', 'Lisboa');
    expect(context.getTreatment('exp_sb'), expected('Lisboa', 0));

    h.clock.now = anchor + 20;
    context.setAttribute('city', 'Porto');
    await h.refreshTo(context, [
      attributeSwitchback('city')..trafficSplit = [1.0, 0.0]
    ]);
    expect(context.getTreatment('exp_sb'), 0);

    await h.refreshTo(context, [attributeSwitchback('city')]);
    expect(context.getTreatment('exp_sb'), expected('Lisboa', 0));
    expect(context.getPendingCount(), 3);

    h.clock.now = anchor + hour;
    expect(context.getTreatment('exp_sb'), expected('Porto', 1));
  });

  // The cluster is resolved before traffic: a traffic miss of an eligible
  // cluster is a recorded ineligible exposure under the serving unit, and
  // traffic restored later in the period serves the key read at first
  // resolution.
  test('trafficRestoredWithinThePeriodKeepsTheKey', () async {
    final context =
        await create(attributeSwitchback('city')..trafficSplit = [1.0, 0.0]);
    h.clock.now = anchor + 10;
    context.setAttribute('city', 'Faro');
    expect(context.getTreatment('exp_sb'), 0);

    h.clock.now = anchor + 20;
    context.setAttribute('city', 'Lisboa');
    await h.refreshTo(context, [attributeSwitchback('city')]);
    expect(expected('Faro', 0), 1);
    expect(context.getTreatment('exp_sb'), expected('Faro', 0));
    expect(await h.publishExposures(context), [
      clusterExposure(0, anchor + 10, eligible: false),
      clusterExposure(expected('Faro', 0), anchor + 20),
    ]);
  });

  // An audience change re-resolves the period slot (new exposure state) but
  // keeps its key.
  test('audienceRevalidationAfterSetAttributeKeepsThePeriodsBucket', () async {
    final context = await create(attributeSwitchback('city')
      ..audience = '{"filter":[{"eq":[{"var":"tier"},{"value":"gold"}]}]}');
    h.clock.now = anchor + 10;
    context.setAttribute('city', 'Lisboa');
    context.setAttribute('tier', 'gold');
    expect(context.getTreatment('exp_sb'), expected('Lisboa', 0));

    h.clock.now = anchor + 20;
    context.setAttribute('city', 'Porto');
    context.setAttribute('tier', 'silver');
    expect(context.getTreatment('exp_sb'), expected('Lisboa', 0));

    expect(await h.publishExposures(context), [
      clusterExposure(expected('Lisboa', 0), anchor + 10),
      clusterExposure(expected('Lisboa', 0), anchor + 20,
          audienceMismatch: true),
    ]);
  });

  // A slot first resolved without a key carries that missing key into its
  // replacement.
  test('audienceRevalidationAfterAnIneligibleResolutionKeepsTheMissingKey',
      () async {
    final context = await create(attributeSwitchback('city')
      ..audience = '{"filter":[{"eq":[{"var":"tier"},{"value":"gold"}]}]}');
    h.clock.now = anchor + 10;
    context.setAttribute('tier', 'gold');
    expect(context.getTreatment('exp_sb'), 0);

    h.clock.now = anchor + 20;
    context.setAttribute('city', 'Faro');
    context.setAttribute('tier', 'silver');
    expect(expected('Faro', 0), 1);
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getPendingCount(), 0);

    h.clock.now = anchor + hour;
    expect(context.peekTreatment('exp_sb'), expected('Faro', 1));
    // Period 1 of Faro is variant 0; period 2 is not, so the key is visibly
    // read again.
    h.clock.now = anchor + 2 * hour;
    expect(expected('Faro', 2), 2);
    expect(context.peekTreatment('exp_sb'), expected('Faro', 2));
  });

  test('clusterPathChangesInvalidateThePeriod', () async {
    final context = await create(attributeSwitchback('city'));
    h.clock.now = anchor + 10;
    context.setAttribute('city', 'Lisboa');
    context.setAttribute('geo', {'city': 'Porto'});
    expect(context.getTreatment('exp_sb'), expected('Lisboa', 0));
    expect(context.getPendingCount(), 1);

    await h.refreshTo(context, [attributeSwitchback('city')]);
    expect(context.getTreatment('exp_sb'), expected('Lisboa', 0));
    expect(context.getPendingCount(), 1);

    await h.refreshTo(context, [attributeSwitchback('geo/city')]);
    expect(context.getTreatment('exp_sb'), expected('Porto', 0));
    expect(context.getPendingCount(), 2);

    await h.refreshTo(context, [
      attributeSwitchback('geo/city')
        ..switchbackClusterValues = ['Porto', 'Faro']
    ]);
    expect(context.getTreatment('exp_sb'), expected('Porto', 0));
    expect(context.getPendingCount(), 3);
  });

  // Re-linking the experiment to another unit type re-keys the period and
  // moves the exposure unit.
  test('linkedUnitTypeChangeRekeysThePeriod', () async {
    final context = await create(attributeSwitchback('city'),
        units: {unitType: uid, 'user_id': 'user-0002'});
    h.clock.now = anchor + 1;
    context.setAttribute('city', 'Lisboa');
    context.setAttribute('ucity', 'Faro');
    expect(context.getTreatment('exp_sb'), expected('Lisboa', 0));

    await h.refreshTo(context, [
      attributeSwitchback('ucity')..switchbackClusters = {'user_id': 'ucity'}
    ]);
    expect(context.getTreatment('exp_sb'), expected('Faro', 0));
    final exposures = await h.publishExposures(context);
    expect(exposures, hasLength(2));
    expect(exposures[0].unit, unitType);
    expect(exposures[1].unit, 'user_id');
  });

  test('customAssignmentAppliesOnlyToUnitsWithAClusterKey', () async {
    final keyed = await create(attributeSwitchback('city'));
    keyed.setAttribute('city', 'Lisboa');
    keyed.setCustomAssignment('exp_sb', 2);
    expect(keyed.getTreatment('exp_sb'), 2);

    final unkeyed =
        await create(attributeSwitchback('city'), harness: Harness());
    unkeyed.setCustomAssignment('exp_sb', 2);
    expect(unkeyed.getTreatment('exp_sb'), 0);
  });

  // A custom assignment set after a switchback slot resolved re-resolves it,
  // and one equal to the old value does not.
  test('aChangedCustomAssignmentReresolvesTheSlot', () async {
    final context = await create(attributeSwitchback('city'));
    context.setAttribute('city', 'Lisboa');
    h.clock.now = anchor + 2 * hour;
    expect(context.getTreatment('exp_sb'), expected('Lisboa', 2));
    context.setCustomAssignment('exp_sb', 0);
    expect(context.getTreatment('exp_sb'), 0);
    context.setCustomAssignment('exp_sb', 0);
    expect(context.getTreatment('exp_sb'), 0);
    expect(context.getPendingCount(), 2);
  });

  // Inertness: a unit experiment ("unit" or absent) carrying every
  // switchback field serves and publishes exactly what the same experiment
  // without them does.
  test('unitExperimentsIgnoreClusterFields', () async {
    for (final type in ['unit', null]) {
      Experiment unitWith({required bool fields}) {
        final e = attributeSwitchback('city')
          ..randomizationType = type
          // A split rule randomizes over unitType for a unit experiment,
          // never a cluster unit.
          ..assignmentRules =
              '{"rules":[{"type":"split","environments":[],"percentages":"34/33/33"}]}';
        if (fields) {
          e.switchbackClusters = {'user_id': 'city', unitType: "'x"};
          e.switchbackClusterValues = ['nothing'];
          e.switchbackPeriodMs = 0;
        } else {
          e.switchbackClusters = null;
          e.switchbackStartAt = null;
          e.switchbackPeriodMs = null;
          e.switchbackCarryoverDurationMs = null;
          e.switchbackBurnInDurationMs = null;
          e.switchbackBurnOutDurationMs = null;
          e.switchbackDesignType = null;
          e.switchbackEstimand = null;
        }
        return e;
      }

      final published = <List<Exposure>>[];
      for (final fields in [true, false]) {
        final harness = Harness(now: anchor - hour);
        final context = await create(unitWith(fields: fields),
            units: {unitType: uid, 'user_id': 'u'}, harness: harness);
        context.setAttribute('city', 'Lisboa');
        final first = context.getTreatment('exp_sb');
        for (int i = 1; i < 6; ++i) {
          harness.clock.now = anchor - hour + i * hour;
          expect(context.getTreatment('exp_sb'), first);
        }
        published.add(await harness.publishExposures(context));
      }
      expect(published[0], hasLength(1));
      expect(published[0].single.eligible, isTrue);
      expect(published[0].single.ruleOverride, isTrue);
      expect(published[0].single.exposedAt, anchor - hour);
      expect(published[0], published[1]);
    }
  });
}
