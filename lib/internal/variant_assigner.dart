import 'dart:typed_data';
import 'buffers.dart';
import 'hashing/murmur3_32.dart';

class VariantAssigner {
  static double normalizer = 1.0 / 0xffffffff;
  static final Uint8List threadBuffer =
      Uint8List.fromList(List.generate(12, (index) => 0));

  // private static final ThreadLocal<byte[]> threadBuffer = new ThreadLocal<byte[]>() {
  //   @Override
  //   public byte[] initialValue() {
  //     return new byte[12];
  //   }
  // };

  VariantAssigner(Uint8List unitHash) {
    unitHash_ = Murmur3_32.digest(unitHash, 0);
  }

  late int unitHash_;

  int assign(List<double> split, int seedHi, int seedLo) {
    final double prob = probability(seedHi, seedLo);
    return chooseVariant(split, prob);
  }

  static int chooseVariant(List<double> split, double prob) {
    double cumSum = 0.0;
    for (int i = 0; i < split.length; ++i) {
      cumSum += split[i];
      if (prob < cumSum) {
        return i;
      }
    }

    return split.length - 1;
  }

  double probability(int seedHi, int seedLo) {
    final Uint8List buffer = threadBuffer; //.get();

    Buffers.putUInt32(buffer, 0, seedLo);
    Buffers.putUInt32(buffer, 4, seedHi);
    Buffers.putUInt32(buffer, 8, unitHash_);

    final int hash = Murmur3_32.digest(buffer, 0);
    return (hash & 0xffffffff) * normalizer;
  }
}
