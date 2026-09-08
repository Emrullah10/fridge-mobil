import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/purchase_repository.dart';

/// Paywall'daki tek bir paket kartı. Eskiden tek bir `Text(priceString)`
/// satırıydı — mağazada tanımlı ücretsiz deneme/indirimli teklif hiç
/// görünmüyordu. Sonra üç durumu ayırt eden bir yatay tek-satır düzene
/// geçildi, ama uzun Türkçe başlık + rozet + üstü çizili fiyat aynı satıra
/// sığmayınca taşma/iç içe girme oldu (kullanıcı şikayeti: "yazılar içi içe
/// girmiş"). Şimdi dikey/bölünmüş düzen: üstte başlık+rozet satırı, altta
/// büyük fiyat + tek kısa ikincil satır. Uzun yasal açıklama ("İlk X
/// ücretsiz, sonra Y") karttan kaldırıldı — Play/App Store zorunluluğu artık
/// tek başına ekran altındaki `_renewalDisclosure()` satırınca karşılanıyor
/// (bkz. paywall_screen.dart).
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.selected,
    required this.onTap,
    this.monthlyForComparison,
  });

  final PurchaseProduct product;
  final bool selected;
  final VoidCallback onTap;

  /// Yıllık paketin tasarruf yüzdesini hesaplamak için aylık paket —
  /// verilmezse (aylık paket yoksa ya da bu paketin kendisi aylıksa) rozet
  /// gösterilmez.
  final PurchaseProduct? monthlyForComparison;

  /// Radyo ikonu (24) + aradaki boşluk (AppSpacing.sm) — alt satırların sol
  /// kenarı buna göre hizalanır (eskiden sabit 36 kullanılıyordu, ikonla
  /// hizalı değildi).
  static const double _indicatorGutter = 24 + AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = _badgeLabel();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary.withValues(alpha: 0.06) : null,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      product.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _Badge(label: badge),
                  ],
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: _indicatorGutter, top: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _PriceRow(product: product),
                    if (_secondaryLine() case final line?) ...[
                      const SizedBox(height: 2),
                      Text(
                        line,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _badgeLabel() {
    if (product.hasFreeTrial) {
      final period = product.trialPeriodLabel;
      return period != null ? '$period ÜCRETSİZ'.toUpperCase() : 'ÜCRETSİZ DENEME';
    }
    if (product.hasIntroDiscount) return 'İNDİRİM';
    final percent = monthlyForComparison != null ? product.discountPercentAgainst(monthlyForComparison) : null;
    if (percent != null && percent > 0) return '%$percent TASARRUF';
    return null;
  }

  /// Fiyatın altındaki tek kısa satır — uzun yasal metin (süre + sonraki
  /// fiyat) artık burada değil, ekran altındaki kalıcı yenileme satırında.
  /// Öncelik: aylık karşılığı > kısa deneme notu.
  String? _secondaryLine() {
    final perMonth = product.pricePerMonthString;
    if (perMonth != null && monthlyForComparison != null && !product.hasFreeTrial && !product.hasIntroDiscount) {
      return '≈ $perMonth/ay';
    }
    final period = product.trialPeriodLabel;
    if (product.hasFreeTrial && period != null) {
      return 'İlk $period ücretsiz';
    }
    return null;
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});

  final PurchaseProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Fiyat MAĞAZADAN gelen yerelleştirilmiş string — asla sabit kodlanmaz
    // (plan §Faz 4 Play politikası notu).
    if (product.hasFreeTrial || product.hasIntroDiscount) {
      final introPrice = product.introPriceString;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            introPrice ?? product.priceString,
            style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
          ),
          if (introPrice != null && !product.hasFreeTrial) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              product.priceString,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ],
      );
    }

    return Text(
      product.priceString,
      style: theme.textTheme.titleLarge,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
