import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Giriş/Kayıt/Karşılama/Hesabı Kalıcı Yap ekranlarının ortak başlığı:
/// 72×72 logo kutusu + "Fridge" başlığı + alt başlık.
///
/// Daha önce bu blok dört ekrana ayrı ayrı kopyalanmıştı ve hepsinde aynı
/// hata vardı: `Container(width: 72)` bir `Column(crossAxisAlignment:
/// stretch)` içinde olduğu için stretch genişliği eziyor, logo kutusu tam
/// genişlikte bir yeşil bant olarak render oluyordu (mağaza ekran
/// görüntüsünde görüldü). Buradaki `Align` bunu kesin çözer — tek yerde.
///
/// Spec §11: 72×72 / radius 20 / primaryContainer zemin / 36pt kitchen_rounded.
class AuthHeroHeader extends StatelessWidget {
  const AuthHeroHeader({
    super.key,
    this.title = 'Fridge',
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.logo),
            ),
            child: Icon(Icons.kitchen_rounded, size: 36, color: colorScheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
