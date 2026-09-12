import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Giriş/Kayıt/Karşılama/Hesabı Kalıcı Yap ekranlarının ortak başlığı:
/// 72×72 logo kutusu + "Elde" başlığı + alt başlık.
///
/// Daha önce bu blok dört ekrana ayrı ayrı kopyalanmıştı ve hepsinde aynı
/// hata vardı: `Container(width: 72)` bir `Column(crossAxisAlignment:
/// stretch)` içinde olduğu için stretch genişliği eziyor, logo kutusu tam
/// genişlikte bir yeşil bant olarak render oluyordu (mağaza ekran
/// görüntüsünde görüldü). Buradaki `Align` bunu kesin çözer — tek yerde.
///
/// Spec §11: 72×72 / radius 20 / assets/images/logo.png (gerçek marka logosu).
class AuthHeroHeader extends StatelessWidget {
  const AuthHeroHeader({
    super.key,
    this.title = 'Elde',
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Align(
          alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.logo),
            child: Image.asset(
              'assets/images/logo.png',
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          style: textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
