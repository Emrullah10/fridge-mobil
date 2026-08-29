/// Ortak form validasyon kuralları — daha önce login/register/upgrade
/// ekranlarına kopyalanmış ve tutarsızdı (login şifre `< 6`, register `< 8`,
/// e-posta her yerde gevşek `contains('@')`). Backend'in EMAIL_PATTERN /
/// MIN_PASSWORD_LENGTH kuralları (auth.routes.js) ile birebir eşleşir.
class Validators {
  Validators._();

  // Backend auth.routes.js:20 EMAIL_PATTERN ile aynı.
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static const int minPasswordLength = 8;

  static String? email(String? value) {
    if (value == null || !_emailPattern.hasMatch(value)) {
      return 'Geçerli bir e-posta girin';
    }
    return null;
  }

  /// Yeni şifre belirlenen yerlerde (register, upgrade, reset) kullanılır —
  /// backend'deki MIN_PASSWORD_LENGTH=8 kuralıyla eşleşir.
  static String? newPassword(String? value) {
    if (value == null || value.length < minPasswordLength) {
      return 'En az $minPasswordLength karakter';
    }
    return null;
  }

  /// Login'de KULLANILMAZ min uzunluk kuralı — 8'den kısa eski şifresi olan
  /// kullanıcıyı (register minimumu sonradan eklendi) giriş yapamaz hale
  /// getirmemek için sadece boşluk kontrolü yapılır.
  static String? requiredPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre gerekli';
    }
    return null;
  }

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label gerekli';
    }
    return null;
  }

  static String? resetCode(String? value) {
    if (value == null || !RegExp(r'^\d{6}$').hasMatch(value)) {
      return '6 haneli kodu gir';
    }
    return null;
  }
}
