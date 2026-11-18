import 'dart:convert';
import 'dart:typed_data';

import 'buffers.dart';
import 'hashing/murmur3_32.dart';

// Balanced-block switchback assignment. Port of java-sdk
// internal/SwitchbackAssigner (itself a port of the platform's
// SwitchbackAssignment, Guava murmur3_32_fixed, seed 0):
//   key       = utf8(clusterUnit + "\u001f" + cycleIndex)
//   baseHash  = murmur3_32(le64(seed) ++ le32(murmur3_32(key)))
//   stepHash  = murmur3_32(le32(baseHash) ++ le32(i)),  i = armCount-1 .. 1
//   j         = min(i, floor(u32(stepHash) / 0xffffffff * (i + 1)))
//   variant   = permutation[floorMod(periodIndex, armCount)],
//               cycle = floorDiv(periodIndex, armCount)
// periodIndex, cycleIndex and seed are signed 64-bit values. They are BigInt
// so the web, where an int is a JavaScript number, computes the same results
// as the VM. Any change here breaks parity with the platform golden vectors.
abstract class SwitchbackAssigner {
  static const double _normalizer = 1.0 / 0xffffffff;
  static const String _separator = '\u001f';
  static final BigInt _word = BigInt.from(0xffffffff);

  static int assign(final String clusterUnit, final BigInt periodIndex,
      final BigInt seed, final int armCount) {
    _requireValidArmCount(armCount);
    final BigInt arms = BigInt.from(armCount);
    final BigInt cycleIndex = floorDiv(periodIndex, arms);
    final int cycleSlot = (periodIndex - cycleIndex * arms).toInt();
    return fisherYatesPermutation(
        armCount, baseHash(clusterUnit, cycleIndex, seed))[cycleSlot];
  }

  static int baseHash(
      final String clusterUnit, final BigInt cycleIndex, final BigInt seed) {
    final Uint8List keyBytes =
        Uint8List.fromList(utf8.encode('$clusterUnit$_separator$cycleIndex'));
    final int keyHash = Murmur3_32.digest(keyBytes, 0);

    final Uint8List buffer = Uint8List(12);
    Buffers.putUInt32(buffer, 0, (seed & _word).toInt());
    Buffers.putUInt32(buffer, 4, ((seed >> 32) & _word).toInt());
    Buffers.putUInt32(buffer, 8, keyHash);
    return Murmur3_32.digest(buffer, 0);
  }

  static List<int> fisherYatesPermutation(
      final int armCount, final int baseHash) {
    _requireValidArmCount(armCount);

    final List<int> permutation = List<int>.generate(armCount, (i) => i);

    final Uint8List buffer = Uint8List(8);
    Buffers.putUInt32(buffer, 0, baseHash);
    for (int i = armCount - 1; i > 0; --i) {
      Buffers.putUInt32(buffer, 4, i);
      final int stepHash = Murmur3_32.digest(buffer, 0);
      final double prob = (stepHash & 0xffffffff) * _normalizer;
      // prob == 1.0 would map to i + 1
      final int floored = (prob * (i + 1)).floor();
      final int j = floored < i ? floored : i;

      final int tmp = permutation[i];
      permutation[i] = permutation[j];
      permutation[j] = tmp;
    }

    return permutation;
  }

  // The divisor is always positive here.
  static BigInt floorDiv(final BigInt dividend, final BigInt divisor) {
    final BigInt q = dividend ~/ divisor;
    return (dividend.remainder(divisor) != BigInt.zero && dividend.isNegative)
        ? q - BigInt.one
        : q;
  }

  static void _requireValidArmCount(final int armCount) {
    if (armCount < 2) {
      throw ArgumentError('armCount must be >= 2, got $armCount');
    }
  }
}
