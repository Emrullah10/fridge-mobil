import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mobil/core/version/app_config_repository.dart';
import 'package:fridge_mobil/core/version/update_decision.dart';

const _config = AppConfig(
  latestVersion: '1.2.0',
  minSupportedVersion: '1.0.0',
  storeUrl:
      'https://play.google.com/store/apps/details?id=com.fridge.fridge_mobil',
);

void main() {
  group('decideUpdate', () {
    test('mevcut sürüm minSupportedVersion altındaysa forced döner', () {
      final action = decideUpdate(
        currentVersion: '0.9.0',
        config: _config,
        dismissedVersion: null,
      );
      expect(action, UpdateAction.forced);
    });

    test('dismiss edilmiş olsa bile minSupported altındaysa forced döner', () {
      // Zorunlu güncelleme kararı dismiss geçmişini hiçbir zaman dikkate
      // almaz — kullanıcı önceki bir sürümü kapatmış olabilir.
      final action = decideUpdate(
        currentVersion: '0.9.0',
        config: _config,
        dismissedVersion: '1.2.0',
      );
      expect(action, UpdateAction.forced);
    });

    test(
      'minSupported ile latest arasındaysa ve dismiss edilmemişse optional döner',
      () {
        final action = decideUpdate(
          currentVersion: '1.1.0',
          config: _config,
          dismissedVersion: null,
        );
        expect(action, UpdateAction.optional);
      },
    );

    test('latestVersion zaten dismiss edilmişse none döner', () {
      final action = decideUpdate(
        currentVersion: '1.1.0',
        config: _config,
        dismissedVersion: '1.2.0',
      );
      expect(action, UpdateAction.none);
    });

    test(
      'eski bir sürüm dismiss edilmiş ama şimdiki latest farklıysa yine optional döner',
      () {
        final action = decideUpdate(
          currentVersion: '1.1.0',
          config: _config,
          dismissedVersion: '1.1.5',
        );
        expect(action, UpdateAction.optional);
      },
    );

    test('sürüm zaten güncelse none döner', () {
      final action = decideUpdate(
        currentVersion: '1.2.0',
        config: _config,
        dismissedVersion: null,
      );
      expect(action, UpdateAction.none);
    });
  });

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
