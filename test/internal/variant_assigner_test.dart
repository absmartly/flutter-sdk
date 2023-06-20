import 'dart:typed_data';

import 'package:absmartly_sdk/internal/hashing/hashing.dart';
import 'package:absmartly_sdk/internal/variant_assigner.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('chooseVariant', ()
  {
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

    expect(
        VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.66600001), equals(2));
    expect(
        VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 0.75), equals(2));
    expect(
        VariantAssigner.chooseVariant([0.333, 0.333, 0.334], 1.0), equals(2));
    expect(
        VariantAssigner.chooseVariant([0.0, 1.0], 0.0), equals(1));
    expect(
        VariantAssigner.chooseVariant([0.0, 1.0], 1.0), equals(1));
  });


}

