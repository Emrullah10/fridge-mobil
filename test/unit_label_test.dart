import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/core/widgets/unit_label.dart';

void main() {
  group('unitLabel — yeni birimler (unit_kind TEXT geçişi)', () {
    test('meter -> Metre', () {
      expect(unitLabel('meter'), 'Metre');
    });

    test('centimeter -> Santimetre', () {
      expect(unitLabel('centimeter'), 'Santimetre');
    });

    test('square_meter -> Metrekare', () {
      expect(unitLabel('square_meter'), 'Metrekare');
    });
  });

  group('unitShortLabel — yeni birimler', () {
    test('meter -> m', () {
      expect(unitShortLabel('meter'), 'm');
    });

    test('centimeter -> cm', () {
      expect(unitShortLabel('centimeter'), 'cm');
    });

    test('square_meter -> m²', () {
      expect(unitShortLabel('square_meter'), 'm²');
    });
  });

  test('bilinmeyen birim ham string olarak döner', () {
    expect(unitLabel('unknown_unit'), 'unknown_unit');
    expect(unitShortLabel('unknown_unit'), 'unknown_unit');
  });

  test('unitOptions yeni 3 birimi içerir', () {
    expect(unitOptions, containsAll(['meter', 'centimeter', 'square_meter']));
  });
}
