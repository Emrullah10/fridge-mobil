import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../application/paywall_controller.dart';

/// Bir AI özelliği butonuna sarılıp, dokunulduğunda kilitliyse (misafir/kota
/// dolu) paywall'ı gösterir, değilse normal onTap'i çalıştırır. Ekranlar
/// kendi 402 try/catch'ini yazmak zorunda kalmasın diye — chef/recipe/
/// shopping ekranlarının hepsi aynı deseni (dokun -> kontrol et -> ya çalış
/// ya paywall göster) tekrarlıyordu.
///
/// NOT: Bu widget kotayı ÖNCEDEN kontrol ETMEZ (entitlements cache 5dk
/// eski olabilir) — sadece asıl isteği yapar, 402 alırsa paywall'ı orada
/// gösterir. Böylece sunucu her zaman son sözü söyler (plan §Mimari ilke).
class LockedFeatureGate extends ConsumerWidget {
  const LockedFeatureGate({
    super.key,
    required this.trigger,
    required this.action,
    required this.builder,
  });

  final PaywallTrigger trigger;

  /// Asıl AI çağrısını yapan fonksiyon — 402 (DioException) fırlatırsa bu
  /// widget yakalayıp paywall gösterir, başka hatalar olduğu gibi yukarı
  /// fırlatılır (çağıranın kendi describeApiError akışı çalışır).
  final Future<void> Function() action;

  /// onTap: bu widget'ın sardığı `action`'ı çalıştıran fonksiyon —
  /// çocuğa geçirilir (ör. bir FilledButton'ın onPressed'i).
  final Widget Function(BuildContext context, VoidCallback onTap) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleTap() async {
      try {
        await action();
      } on Object catch (error) {
        final info = PlanLimitInfo.tryParse(error);
        if (info == null) rethrow;
        if (!context.mounted) return;
        final controllerAsync = ref.read(paywallControllerProvider);
        controllerAsync.whenData((controller) {
          controller.maybeShow(context, trigger: trigger, info: info);
        });
      }
    }

    return builder(context, () => handleTap());
  }
}
