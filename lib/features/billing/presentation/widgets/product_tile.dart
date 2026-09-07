import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/purchase_repository.dart';

/// Paywall'daki tek bir paket kartı. Eskiden tek bir `Text(priceString)`
/// satırıydı — mağazada tanımlı ücretsiz deneme/indirimli teklif hiç
/// görünmüyordu (kullanıcı şikayeti: "indirimlerimiz var ama kartlarda tam
/// ücret yazıyor"). Şimdi üç durumu ayırt eder: ücretsiz deneme, indirimli
/// giriş fiyatı, ya da (indirim yoksa) yıllığın aylık karşılığı + tasarruf
/// rozeti.
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(product.title, style: theme.textTheme.titleSmall),
                            if (badge != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              _Badge(label: badge),
                            ],
                          ],
                        ),
                        Text(
                          product.description,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _PriceColumn(product: product, monthlyForComparison: monthlyForComparison),
                ],
              ),
              if (_disclosure() case final disclosure?) ...[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    disclosure,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
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

  /// Fiyatın altında çıkan açıklama satırı — Play/App Store politikası
  /// deneme/indirim varsa süre ve sonraki fiyatın AÇIKÇA belirtilmesini
  /// zorunlu kılıyor (bildirimsiz deneme sürüm reddi sebebi olabilir).
  String? _disclosure() {
    final period = product.trialPeriodLabel;
    if (product.hasFreeTrial && period != null) {
      return 'İlk $period ücretsiz, sonra ${product.priceString}';
    }
    if (product.hasIntroDiscount && product.introPriceString != null) {
      final cycles = product.introCycles;
      final periodLabel = cycles != null && cycles > 1 ? 'İlk $cycles dönem' : 'İlk dönem';
      return '$periodLabel ${product.introPriceString}, sonra ${product.priceString}';
    }
    return null;
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({required this.product, required this.monthlyForComparison});

  final PurchaseProduct product;
  final PurchaseProduct? monthlyForComparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Fiyat MAĞAZADAN gelen yerelleştirilmiş string — asla sabit kodlanmaz
    // (plan §Faz 4 Play politikası notu).
    if (product.hasFreeTrial || product.hasIntroDiscount) {
      final introPrice = product.introPriceString;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (introPrice != null && !product.hasFreeTrial)
            Text(
              product.priceString,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          Text(
            introPrice ?? product.priceString,
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      );
    }

    final perMonth = product.pricePerMonthString;
    if (perMonth != null && monthlyForComparison != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(product.priceString, style: theme.textTheme.titleMedium),
          Text(
            '$perMonth/ay',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return Text(product.priceString, style: theme.textTheme.titleMedium);
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
      ),
    );
  }
}
