import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_providers.dart';
import '../../../auth/presentation/upgrade_account_screen.dart';
import '../../application/entitlements_providers.dart';
import '../../domain/entitlements.dart';
import '../subscription_screen.dart';

/// Ayarlar'ın en üstünde (profil kartının hemen altında) gösterilen kompakt
/// premium rozeti — eski "Abonelik" ListTile'ının yerini alır, tek fark:
/// MİSAFİR kullanıcıya da gösterilir (eski satır tamamen gizliydi — kullanıcı
/// "abonelik hiçbir yerde görünmüyor" derken muhtemelen misafir modundaydı).
/// Misafirde dokununca satın alma değil, hesap kalıcılaştırma akışına gider
/// (misafir satın alma yapamaz, bkz. auth_providers.dart).
class PremiumStatusCard extends ConsumerWidget {
  const PremiumStatusCard({super.key});

  String _planLabel(PlanTier plan) => switch (plan) {
        PlanTier.guest => 'Misafir modu',
        PlanTier.free => 'Ücretsiz plan',
        PlanTier.trial => 'Deneme (Premium)',
        PlanTier.premium => 'Premium',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isGuest = ref.watch(authControllerProvider).isGuest;
    final entitlements = ref.watch(entitlementsProvider);
    final isPremiumLike = entitlements.isPremium || entitlements.isTrial;

    return Card(
      child: ListTile(
        leading: Icon(
          isPremiumLike ? Icons.workspace_premium_rounded : Icons.workspace_premium_outlined,
          color: isPremiumLike ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(_planLabel(entitlements.plan)),
        subtitle: Text(
          isGuest
              ? 'Premium\'u görmek için hesabını kalıcı yap'
              : isPremiumLike
                  ? 'Aboneliğini yönet'
                  : 'Planları karşılaştır, Premium\'a geç',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => isGuest ? const UpgradeAccountScreen() : const SubscriptionScreen(),
          ),
        ),
      ),
    );
  }
}
