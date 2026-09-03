import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../application/entitlements_providers.dart';
import '../domain/entitlements.dart';

/// Abonelik yönetim ekranı — Play'in 2026 zorunluluğu: uygulama içinden
/// iptal, en fazla 2 dokunuş (plan §Faz 5). Buraya gelmek 1. dokunuş,
/// "Aboneliği yönet" butonu 2. dokunuş (Play'in kendi ekranına açılır).
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  String _planLabel(PlanTier plan) => switch (plan) {
        PlanTier.guest => 'Misafir',
        PlanTier.free => 'Ücretsiz',
        PlanTier.trial => 'Deneme (Premium)',
        PlanTier.premium => 'Premium',
      };

  Future<void> _openManageUrl(BuildContext context, WidgetRef ref) async {
    try {
      final url = await ref.read(entitlementsRepositoryProvider).fetchManageSubscriptionUrl();
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('URL açılamadı');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlements = ref.watch(entitlementsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Abonelik')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.layoutMarginStandard),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        entitlements.isPremium || entitlements.isTrial ? Icons.workspace_premium_rounded : Icons.person_outline_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(_planLabel(entitlements.plan), style: theme.textTheme.titleMedium),
                    ],
                  ),
                  if (entitlements.isTrial && entitlements.trialDaysLeft != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${entitlements.trialDaysLeft} gün sonra ücretsiz kademeye düşecek',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  if (entitlements.periodEndsAt != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      entitlements.status == 'canceled'
                          ? 'Aboneliğin ${_formatDate(entitlements.periodEndsAt!)} tarihinde sona erecek'
                          : '${_formatDate(entitlements.periodEndsAt!)} tarihinde yenilenir',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (entitlements.isPremium || entitlements.isTrial)
            FilledButton.tonal(
              onPressed: () => _openManageUrl(context, ref),
              child: const Text('Aboneliği Yönet / İptal Et'),
            )
          else
            const _UpgradeCta(),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}.${date.month}.${date.year}';
}

class _UpgradeCta extends StatelessWidget {
  const _UpgradeCta();

  @override
  Widget build(BuildContext context) {
    // RevenueCat entegrasyonu (plan §Faz 5) henüz bağlanmadı — bu buton
    // paywall_screen.dart'ı açar, oradaki satın alma butonu "Yakında"
    // durumunda kalır. purchases_flutter kurulduğunda burası ve
    // paywall_screen.dart aynı satın alma akışına bağlanacak.
    return FilledButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abonelik satın alma yakında açılıyor.')),
        );
      },
      child: const Text('Premium\'a Geç'),
    );
  }
}
