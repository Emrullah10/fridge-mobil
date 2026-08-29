import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/core/validation/validators.dart';

void main() {
  group('Validators.email', () {
    test('geçerli e-postayı kabul eder', () {
      expect(Validators.email('a@test.local'), isNull);
    });

    test('@ olmadan reddeder', () {
      expect(Validators.email('atest.local'), isNotNull);
    });

    test('nokta olmadan (domain kısmında) reddeder — eski contains(\'@\') kuralı bunu geçiriyordu', () {
      expect(Validators.email('a@testlocal'), isNotNull);
    });

    test('null reddeder', () {
      expect(Validators.email(null), isNotNull);
    });
  });

  group('Validators.newPassword', () {
    test('8 karakter ve üstünü kabul eder', () {
      expect(Validators.newPassword('sifre123'), isNull);
    });

    test('8 karakterden kısayı reddeder', () {
      expect(Validators.newPassword('kisa1'), isNotNull);
    });
  });

  group('Validators.requiredPassword', () {
    test('kısa ama dolu şifreyi kabul eder — login eski kısa şifreli kullanıcıyı bloklamamalı', () {
      expect(Validators.requiredPassword('123'), isNull);
    });

    test('boş şifreyi reddeder', () {
      expect(Validators.requiredPassword(''), isNotNull);
    });
  });

  group('Validators.resetCode', () {
    test('6 haneli kodu kabul eder', () {
      expect(Validators.resetCode('123456'), isNull);
    });

    test('5 haneli kodu reddeder', () {
      expect(Validators.resetCode('12345'), isNotNull);
    });

    test('rakam olmayan karakter içerirse reddeder', () {
      expect(Validators.resetCode('12345a'), isNotNull);
    });
  });

  group('Validators.required', () {
    test('boşluklardan oluşan metni reddeder', () {
      expect(Validators.required('   ', 'Ad'), isNotNull);
    });

    test('dolu metni kabul eder', () {
      expect(Validators.required('Ali', 'Ad'), isNull);
    });
  });
}
