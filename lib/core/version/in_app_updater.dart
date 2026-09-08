import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';

/// Google Play In-App Update API'sini sarmalar — main.dart doğrudan pakete
/// bağımlı olmasın diye (test edilebilirlik + iOS'ta hiç çağrılmaması için).
///
/// Play'den kurulmamış bir uygulamada (emülatör, sideload, APK) her metod
/// [PlatformException] fırlatır — bu BEKLENEN bir durum, hata olarak
/// loglanmaz; çağıran taraf `false` alıp mevcut banner/storeUrl akışına
/// düşer. RevenueCat paywall'da yaşanan "emülatörde Play Store yok"
/// sorununun aynısı (bkz. hafıza).
abstract class InAppUpdater {
  Future<bool> isAvailable();
  Future<bool> startImmediate();
  Future<bool> startFlexible();
  Future<void> completeFlexible();
}

class PlayInAppUpdater implements InAppUpdater {
  const PlayInAppUpdater();

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> startImmediate() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      return result == AppUpdateResult.success;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> startFlexible() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      return result == AppUpdateResult.success;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> completeFlexible() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } on PlatformException {
      // Kullanıcı yeniden başlatma isteğini reddetmiş olabilir — sessizce
      // yut, bir sonraki manuel açılışta güncelleme zaten devreye girer.
    }
  }
}
