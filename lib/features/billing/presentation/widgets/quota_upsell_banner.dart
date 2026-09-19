import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../application/entitlements_providers.dart';
import '../../application/paywall_controller.dart';
import '../../domain/entitlements.dart';
import '../paywall_screen.dart';

/// AI özelliği kullanım kotasının %80'ine ulaşınca ekranın üstünde çıkan
/// ölçülü, kapatılabilir şerit — `PaywallTrigger.usageWarning80`'in tek
/// gösterim yeri (kota verisi `AiQuota.usageRatio` zaten 5 dakikada bir
/// çekiliyordu ama hiçbir UI okumuyordu).
///
/// Kota tamamen dolduğunda (`isExhausted`) gösterilmez — o an zaten asıl
/// istek 402 döner ve `paywall_sheet.dart` devreye girer; iki uyarı üst
/// üste binmesin.
class QuotaUpsellBanner extends ConsumerWidget {
  const QuotaUpsellBanner({super.key, required this.feature});

  /// Backend `plans.js`'teki AI_FEATURES anahtarlarından biri:
  /// 'receipt' | 'recipe' | 'chef' | 'shopping'.
  final String feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlements = ref.watch(entitlementsProvider);
    final quota = entitlements.quotaFor(feature);
    if (quota == null ||
        quota.isUnlimited ||
        quota.isExhausted ||
        quota.usageRatio < 0.8) {
      return const SizedBox.shrink();
    }

    final controllerAsync = ref.watch(paywallControllerProvider);
    return controllerAsync.maybeWhen(
      data: (controller) {
        if (controller.isFrequencyLimited(PaywallTrigger.usageWarning80))
          return const SizedBox.shrink();
        return _BannerContent(
          quota: quota,
          onUpgrade: () {
            controller.recordShown(PaywallTrigger.usageWarning80);
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const PaywallScreen(),
              ),
            );
          },
          // "24 saatte 1" kuralı recordShown ile aynı zaman damgasını
          // kullanıyor (bkz. paywall_controller.dart _minInterval) —
          // kapatmak da bir sonraki 24 saat için susturur.
          onDismiss: () =>
              controller.recordShown(PaywallTrigger.usageWarning80),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _BannerContent extends StatefulWidget {
  const _BannerContent({
    required this.quota,
    required this.onUpgrade,
    required this.onDismiss,
  });

  final AiQuota quota;
  final VoidCallback onUpgrade;
  final VoidCallback onDismiss;

  @override
  State<_BannerContent> createState() => _BannerContentState();
}

class _BannerContentState extends State<_BannerContent> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final quota = widget.quota;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${quota.used}/${quota.limit} kullandın',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: quota.usageRatio.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(onPressed: widget.onUpgrade, child: const Text('Premium')),
          IconButton(
            tooltip: 'Kapat',
            icon: Icon(AppIcons.close(context), size: 18),
            visualDensity: VisualDensity.compact,
            // bkz. assistant_screen.dart'taki aynı not — compact yoğunluk
            // dokunma alanını iOS 44×44pt minimumunun altına düşürüyordu.
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () {
              widget.onDismiss();
              setState(() => _dismissed = true);
            },
          ),
        ],
      ),
    );
  }
}
