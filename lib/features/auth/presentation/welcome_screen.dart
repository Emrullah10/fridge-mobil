import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import 'widgets/auth_cta_block.dart';
import 'widgets/auth_hero_header.dart';

/// Açılış ekranı — tanıtımı zaten görmüş (ya da atlamış) kullanıcı için
/// kompakt karşılama. Değer kartlarının tekrarı yok; misafir/giriş/kayıt
/// üçlüsü [AuthCtaBlock]'tan gelir (IntroScreen'in CTA sayfasıyla aynı
/// kaynak). İlk açılışta bunun yerine IntroScreen gösterilir (bkz.
/// _AuthGate).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: formMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  const AuthHeroHeader(
                    subtitle: 'Dolabındaki, depondaki, atölyendeki her şey tek yerde',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const AuthCtaBlock(),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
