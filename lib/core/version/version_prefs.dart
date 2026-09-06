import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının "Kapat"a bastığı son güncelleme sürümü. Yeni bir sürüm
/// çıktığında bu değer eskisiyle eşleşmeyeceği için banner tekrar gösterilir.
const _prefsKey = 'dismissed_update_version_v1';

Future<String?> dismissedUpdateVersion() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_prefsKey);
}

Future<void> setDismissedUpdateVersion(String version) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, version);
}
