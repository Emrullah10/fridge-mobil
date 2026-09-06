import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mobil/core/version/app_config_repository.dart';

void main() {
  group('compareVersions', () {
    test('patch farkı', () {
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    });

    test('minor artışı patch\'i geride bırakır', () {
      expect(compareVersions('1.0.9', '1.1.0'), lessThan(0));
    });

    test('eşit sürümler', () {
      expect(compareVersions('1.0.0', '1.0.0'), equals(0));
    });

    test('major farkı', () {
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('eksik parça 0 sayılır', () {
      expect(compareVersions('1.0', '1.0.0'), equals(0));
    });

    test('bozuk girdi çökmez', () {
      expect(compareVersions('abc', '1.0.0'), lessThan(0));
    });
  });
}
