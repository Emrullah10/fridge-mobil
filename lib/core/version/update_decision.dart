import 'app_config_repository.dart';

/// Sürüm karşılaştırma sonucunda alınacak aksiyon.
enum UpdateAction {
  /// Güncel — hiçbir şey gösterilmez.
  none,

  /// Yeni sürüm var ama zorunlu değil — kapatılabilir bildirim.
  optional,

  /// Mevcut sürüm minSupportedVersion'ın altında — kapatılamaz.
  forced,
}

/// main.dart'tan ayrıştırılmış saf karar mantığı — UI/paket bağımlılığı yok,
/// doğrudan unit test edilebilir.
///
/// Zorunlu güncelleme kararı dismiss geçmişini HİÇBİR ZAMAN dikkate almaz:
/// kullanıcı önceki (opsiyonel) bir sürümü kapatmış olsa bile, şimdiki sürüm
/// minSupportedVersion'ın altındaysa yine de zorunlu ekran gösterilir.
UpdateAction decideUpdate({
  required String currentVersion,
  required AppConfig config,
  required String? dismissedVersion,
}) {
  if (compareVersions(currentVersion, config.minSupportedVersion) < 0) {
    return UpdateAction.forced;
  }
  if (compareVersions(currentVersion, config.latestVersion) < 0) {
    if (dismissedVersion == config.latestVersion) return UpdateAction.none;
    return UpdateAction.optional;
  }
  return UpdateAction.none;
}
