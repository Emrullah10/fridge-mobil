import 'package:flutter/material.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';

/// Bağlamsal paywall — kota doldu / kilitli özelliğe dokunuldu / misafir
/// AI denedi anlarında gösterilir (bkz. plan §Faz 4 Tetiklenme #1, #6).
/// Tam ekran DEĞİL — kullanıcı "Şimdi değil" diyebilir, akışını kaybetmez.
///
/// info null ise (ör. sadece "kilitli özellik" — henüz bir 402 alınmadı)
/// genel bir mesaj gösterilir.
Future<void> showPaywallSheet(
  BuildContext context, {
  PlanLimitInfo? info,
  VoidCallback? onUpgrade,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.dialog)),
    ),
    builder: (sheetContext) => _PaywallSheetContent(info: info, onUpgrade: onUpgrade),
  );
}

class _PaywallSheetContent extends StatelessWidget {
  const _PaywallSheetContent({this.info, this.onUpgrade});

  final PlanLimitInfo? info;
  final VoidCallback? onUpgrade;

  String get _title {
    switch (info?.code) {
      case 'SIGNUP_REQUIRED':
        return 'Bu özellik için ücretsiz hesap aç';
      case 'PLAN_LIMIT_REACHED':
        return 'Bu ayki hakkını doldurdun';
      case 'PLAN_FEATURE_LOCKED':
        return 'Bu özellik planında yok';
      default:
        return 'Bu özellik şu an kilitli';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                // Kilit ikonuna Opacity uygulamıyoruz (cerebrum kuralı) —
                // düz bir dolgu rengi kullanılıyor.
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Icon(Icons.lock_rounded, size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text(_title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          if (info?.message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              info!.message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          if (info?.limit != null && info?.used != null) ...[
            const SizedBox(height: AppSpacing.md),
            _UsageMeter(used: info!.used!, limit: info!.limit!),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (info?.upgradeAvailable ?? true)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                onUpgrade?.call();
              },
              child: Text(info?.code == 'SIGNUP_REQUIRED' ? 'Ücretsiz Hesap Aç' : 'Planları Gör'),
            ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Şimdi değil'),
          ),
        ],
      ),
    );
  }
}

class _UsageMeter extends StatelessWidget {
  const _UsageMeter({required this.used, required this.limit});

  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = limit == 0 ? 1.0 : (used / limit).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$used / $limit kullanıldı',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
