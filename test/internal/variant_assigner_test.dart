import 'package:absmartly_sdk/internal/hashing/hashing.dart';
import 'package:absmartly_sdk/internal/variant_assigner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chooseVariant', () {
    expect(VariantAssigner.chooseVariant([0.0, 1.0], 0.0), equals(1));
    expect(VariantAssigner.chooseVariant([0.0, 1.0], 0.5), equals(1));
    expect(VariantAssigner.chooseVariant([0.0, 1.0], 1.0), equals(1));

    expect(VariantAssigner.chooseVariant([1.0, 0.0], 0.0), equals(0));
    expect(VariantAssigner.chooseVariant([1.0, 0.0], 0.5), equals(0));
    expect(VariantAssigner.chooseVariant([1.0, 0.0], 1.0), equals(1));

    expect(VariantAssigner.chooseVariant([0.5, 0.5], 0.0), equals(0));
    expect(VariantAssigner.chooseVariant([0.5, 0.5], 0.25), equals(0));
    expect(VariantAssigner.chooseVariant([0.5, 0.5], 0.49999999), equals(0));
    expect(VariantAssigner.chooseVariant([0.5, 0.5], 0.5), equals(1));
    expect(VariantAssigner.chooseVariant([0.5, 0.5], 0.50000001), equals(1));
    expect(VariantAssigner.chooseVariant([0.5, 0.5], 0.75), equals(1));
    expect(VariantAssigner.chooseVariant([0.5, 0.5], 1.0), equals(1));

    expect(
        VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.0), equals(0));
    expect(
        VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.25), equals(0));
    expect(VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.33299999),
        equals(0));
    expect(
        VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.333), equals(1));
    expect(VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.33300001),
        equals(1));
    expect(
        VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.5), equals(1));
    expect(VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.66599999),
        equals(1));
    expect(
        VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.666), equals(2));

    expect(VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.66600001),
        equals(2));
    expect(
        VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.75), equals(2));
    expect(
        VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 1.0), equals(2));
    expect(VariantAssigner.chooseVariant([0.0, 1.0], 0.0), equals(1));
    expect(VariantAssigner.chooseVariant([0.0, 1.0], 1.0), equals(1));
  });

  test('assign() should be deterministic', () {
    final testCases = {
      "bleh@absmartly.com": [
        [
          [0.5, 0.5],
          0x00000000,
          0x00000000,
          0
        ],
        [
          [0.5, 0.5],
          0x00000000,
          0x00000001,
          1
        ],
        [
          [0.5, 0.5],
          0x8015406f,
          0x7ef49b98,
          0
        ],
        [
          [0.5, 0.5],
          0x3b2e7d90,
          0xca87df4d,
          0
        ],
        [
          [0.5, 0.5],
          0x52c1f657,
          0xd248bb2e,
          0
        ],
        [
          [0.5, 0.5],
          0x865a84d0,
          0xaa22d41a,
          0
        ],
        [
          [0.5, 0.5],
          0x27d1dc86,
          0x845461b9,
          1
        ],
        [
          [0.33, 0.33, 0.34],
          0x00000000,
          0x00000000,
          0
        ],
        [
          [0.33, 0.33, 0.34],
          0x00000000,
          0x00000001,
          2
        ],
        [
          [0.33, 0.33, 0.34],
          0x8015406f,
          0x7ef49b98,
          0
        ],
        [
          [0.33, 0.33, 0.34],
          0x3b2e7d90,
          0xca87df4d,
          0
        ],
        [
          [0.33, 0.33, 0.34],
          0x52c1f657,
          0xd248bb2e,
          0
        ],
        [
          [0.33, 0.33, 0.34],
          0x865a84d0,
          0xaa22d41a,
          1
        ],
        [
          [0.33, 0.33, 0.34],
          0x27d1dc86,
          0x845461b9,
          1
        ],
      ],
      "123456789": [
        [
          [0.5, 0.5],
          0x00000000,
          0x00000000,
          1
        ],
        [
          [0.5, 0.5],
          0x00000000,
          0x00000001,
          0
        ],
        [
          [0.5, 0.5],
          0x8015406f,
          0x7ef49b98,
          1
        ],
        [
          [0.5, 0.5],
          0x3b2e7d90,
          0xca87df4d,
          1
        ],
        [
          [0.5, 0.5],
          0x52c1f657,
          0xd248bb2e,
          1
        ],
        [
          [0.5, 0.5],
          0x865a84d0,
          0xaa22d41a,
          0
        ],
        [
          [0.5, 0.5],
          0x27d1dc86,
          0x845461b9,
          0
        ],
        [
          [0.33, 0.33, 0.34],
          0x00000000,
          0x00000000,
          2
        ],
        [
          [0.33, 0.33, 0.34],
          0x00000000,
          0x00000001,
          1
        ],
        [
          [0.33, 0.33, 0.34],
          0x8015406f,
          0x7ef49b98,
          2
        ],
        [
          [0.33, 0.33, 0.34],
          0x3b2e7d90,
          0xca87df4d,
          2
        ],
        [
          [0.33, 0.33, 0.34],
          0x52c1f657,
          0xd248bb2e,
          2
        ],
        [
          [0.33, 0.33, 0.34],
          0x865a84d0,
          0xaa22d41a,
          0
        ],
        [
          [0.33, 0.33, 0.34],
          0x27d1dc86,
          0x845461b9,
          0
        ],
      ],
      "e791e240fcd3df7d238cfc285f475e8152fcc0ec": [
        [
          [0.5, 0.5],
          0x00000000,
          0x00000000,
          1
        ],
        [
          [0.5, 0.5],
          0x00000000,
          0x00000001,
          0
        ],
        [
          [0.5, 0.5],
          0x8015406f,
          0x7ef49b98,
          1
        ],
        [
          [0.5, 0.5],
          0x3b2e7d90,
          0xca87df4d,
          1
        ],
        [
          [0.5, 0.5],
          0x52c1f657,
          0xd248bb2e,
          0
        ],
        [
          [0.5, 0.5],
          0x865a84d0,
          0xaa22d41a,
          0
        ],
        [
          [0.5, 0.5],
          0x27d1dc86,
          0x845461b9,
          0
        ],
        [
          [0.33, 0.33, 0.34],
          0x00000000,
          0x00000000,
          2
        ],
        [
          [0.33, 0.33, 0.34],
          0x00000000,
          0x00000001,
          0
        ],
        [
          [0.33, 0.33, 0.34],
          0x8015406f,
          0x7ef49b98,
          2
        ],
        [
          [0.33, 0.33, 0.34],
          0x3b2e7d90,
          0xca87df4d,
          1
        ],
        [
          [0.33, 0.33, 0.34],
          0x52c1f657,
          0xd248bb2e,
          0
        ],
        [
          [0.33, 0.33, 0.34],
          0x865a84d0,
          0xaa22d41a,
          0
        ],
        [
          [0.33, 0.33, 0.34],
          0x27d1dc86,
          0x845461b9,
          1
        ],
      ],
    };

    testCases.forEach((unit, tests) {
      final assigner = VariantAssigner(Hashing.hashUnit(unit));
      for (final testCase in tests) {
        final variant = assigner.assign(testCase[0] as List<double>,
            testCase[1] as int, testCase[2] as int);
        expect(variant, equals(testCase[3]));
      }
    });
  });
}
