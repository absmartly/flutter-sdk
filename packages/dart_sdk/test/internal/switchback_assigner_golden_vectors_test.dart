// Port of java-sdk SwitchbackAssignerGoldenVectorsTest. The fixture
// test/resources/switchback/golden-vectors.json is copied byte-for-byte from
// absmartly/abs 9bd2b5ca35 lib/utils/src/test/resources/switchback/golden-vectors.json
// (git blob b314abeb9e97), via java-sdk core-api/src/test/resources.
// Runs on the VM and compiled to JavaScript (dart test -p node), where 64-bit
// values only survive as BigInt.
import 'dart:typed_data';

import 'package:absmartly_dart/src/internal/buffers.dart';
import 'package:absmartly_dart/src/internal/hashing/murmur3_32.dart';
import 'package:absmartly_dart/src/internal/switchback_assigner.dart';
import 'package:test/test.dart';

import 'fixture_loader.dart';

// The platform hashes a numeric cluster unit as its decimal text; strings
// pass through.
String clusterUnit(final dynamic node) {
  if (node is String) {
    return node;
  }
  expect(node, isA<int>(), reason: 'clusterUnit must be a string or integer');
  return '$node';
}

// 64-bit fields are decimal strings; a number would mean the fixture
// regressed to a lossy encoding.
BigInt exactLong(final dynamic node) {
  expect(node, isA<String>(), reason: '64-bit field must be a decimal string');
  return BigInt.parse(node as String);
}

final BigInt longMin = -(BigInt.one << 63);
final BigInt longMax = (BigInt.one << 63) - BigInt.one;

void main() {
  late Map<String, dynamic> vectors;

  setUpAll(() async {
    vectors = await loadJsonResource('switchback/golden-vectors.json')
        as Map<String, dynamic>;
  });

  test('assignSwitchbackMatchesEveryGoldenVector', () {
    final List cases = vectors['assignSwitchback'] as List;
    expect(cases, hasLength(882));

    final Set<int> armCounts = {};
    int boundaryCases = 0;
    for (final c in cases) {
      final String unit = clusterUnit(c['clusterUnit']);
      final BigInt periodIndex = exactLong(c['periodIndex']);
      final BigInt seed = exactLong(c['seed']);
      final int armCount = c['armCount'] as int;
      armCounts.add(armCount);
      if (periodIndex == longMin ||
          periodIndex == longMax ||
          seed == longMin ||
          seed == longMax) {
        ++boundaryCases;
      }

      expect(SwitchbackAssigner.assign(unit, periodIndex, seed, armCount),
          c['expectedVariant'],
          reason: '$c');
    }

    expect(armCounts, containsAll([2, 3, 10]));
    expect(boundaryCases, greaterThan(0));
  });

  test('fisherYatesPermutationMatchesEveryGoldenVector', () {
    final List cases = vectors['fisherYatesPermutation'] as List;
    expect(cases, hasLength(504));

    for (final c in cases) {
      final String unit = clusterUnit(c['clusterUnit']);
      final BigInt cycleIndex = exactLong(c['cycleIndex']);
      final BigInt seed = exactLong(c['seed']);
      final int armCount = c['armCount'] as int;

      expect(
          SwitchbackAssigner.fisherYatesPermutation(
              armCount, SwitchbackAssigner.baseHash(unit, cycleIndex, seed)),
          c['expectedPermutation'],
          reason: '$c');
    }
  });

  test('everyCycleCoversEveryArmExactlyOnce', () {
    for (final int armCount in [2, 3, 10]) {
      for (int cycle = -3; cycle < 20; ++cycle) {
        final Set<int> seen = {};
        for (int slot = 0; slot < armCount; ++slot) {
          final int variant = SwitchbackAssigner.assign(
              'store_42',
              BigInt.from(cycle * armCount + slot),
              BigInt.from(0x123456789abc),
              armCount);
          expect(seen.add(variant), isTrue, reason: 'arm repeated in a cycle');
        }
      }
    }
  });

  test('rejectsFewerThanTwoArms', () {
    expect(() => SwitchbackAssigner.assign('u', BigInt.zero, BigInt.zero, 1),
        throwsArgumentError);
    expect(() => SwitchbackAssigner.fisherYatesPermutation(0, 0),
        throwsArgumentError);
  });

  test('floorDiv', () {
    BigInt f(BigInt a, int b) => SwitchbackAssigner.floorDiv(a, BigInt.from(b));
    expect(f(BigInt.zero, 3), BigInt.zero);
    expect(f(BigInt.two, 3), BigInt.zero);
    expect(f(BigInt.from(3), 3), BigInt.one);
    expect(f(BigInt.from(-1), 3), BigInt.from(-1));
    expect(f(BigInt.from(-3), 3), BigInt.from(-1));
    expect(f(BigInt.from(-4), 3), BigInt.from(-2));
    // Math.floorDiv(Long.MIN_VALUE, 3L) and Math.floorDiv(Long.MAX_VALUE, 10L).
    expect(f(longMin, 3), BigInt.parse('-3074457345618258603'));
    expect(f(longMax, 10), BigInt.parse('922337203685477580'));
  });

  // A step hash of 0xffffffff gives prob == 1.0, which would map to i + 1
  // without the clamp. Base hash 0x67ab735b makes the only step of a 2-arm
  // permutation (i = 1) hash to 0xffffffff (found by exhaustive search).
  test('aStepHashOfAllOnesStaysInRange', () {
    final Uint8List step = Uint8List(8);
    Buffers.putUInt32(step, 0, 0x67ab735b);
    Buffers.putUInt32(step, 4, 1);
    expect(Murmur3_32.digest(step, 0), 0xffffffff);
    expect(SwitchbackAssigner.fisherYatesPermutation(2, 0x67ab735b), [0, 1]);
  });
}
