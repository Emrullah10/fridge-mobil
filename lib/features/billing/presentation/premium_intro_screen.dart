import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'paywall_screen.dart';
import 'widgets/premium_benefits_card.dart';

/// Onboarding sonrası (kullanıcı ilk kez AppShell'e girdiğinde) bir kez
/// gösterilen tam ekran premium tanıtımı — plan §Faz 5. PaywallScreen'den
/// farkı: burada satın alma akışı YOK, sadece "ne var" anlatılır; "Premium'u
/// dene" gerçek paywall'a götürür. HER ZAMAN geri tuşu/"Ücretsizle devam et"
/// ile atlanabilir, asla kilitlemez (aynı ilke: hard paywall değil).
class PremiumIntroScreen extends StatelessWidget {
  const PremiumIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Icon(Icons.workspace_premium_rounded, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text('Fridge Premium ile tanış', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'İstersen ücretsiz devam et, istediğin zaman geç.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              const PremiumBenefitsCard(),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                },
                child: const Text('Premium\'u dene'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ücretsizle devam et'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
