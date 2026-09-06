import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/plan_catalog_providers.dart';
import '../../domain/plan_catalog.dart';

/// "Ücretsiz vs Premium" karşılaştırma kartı — Ayarlar, Abonelik ekranı ve
/// paywall'da AYNI widget (tek kaynak). Satırlar HER ZAMAN /api/plans'tan
/// gelir, hiçbir sayı burada sabit kodlanmaz (bkz. plan_catalog.dart
/// üstündeki mimari ilke notu).
///
/// Yüklenirken skeleton, hatada tamamen gizlenir — paywall'ın satın alma
/// kısmı bu karta bağımlı olmadan çalışmaya devam etsin diye.
class PremiumBenefitsCard extends ConsumerWidget {
  const PremiumBenefitsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(planCatalogProvider);
    return catalogAsync.when(
      loading: () => const _BenefitsCardSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (catalog) => _BenefitsCardContent(catalog: catalog),
    );
  }
}

class _Row {
  const _Row({required this.label, required this.free, required this.premium});
  final String label;
  final String free;
  final String premium;
}

String _countLabel(int? value, {String unlimited = 'Sınırsız'}) => value == null ? unlimited : '$value';

List<_Row> _rowsFor(PlanCatalog catalog) {
  final free = catalog.free;
  final premium = catalog.premium;
  return [
    _Row(label: 'Fiş tarama / ay', free: _countLabel(free.aiReceipt), premium: _countLabel(premium.aiReceipt)),
    _Row(label: 'Tarif üretimi / ay', free: _countLabel(free.aiRecipe), premium: _countLabel(premium.aiRecipe)),
    _Row(label: 'AI Chef / ay', free: _countLabel(free.aiChef), premium: _countLabel(premium.aiChef)),
    _Row(label: 'Alışveriş önerisi / ay', free: _countLabel(free.aiShopping), premium: _countLabel(premium.aiShopping)),
    _Row(label: 'Alan sayısı', free: _countLabel(free.householdCount), premium: _countLabel(premium.householdCount)),
    _Row(
      label: 'Bölüm / alan',
      free: _countLabel(free.locationPerHousehold),
      premium: _countLabel(premium.locationPerHousehold),
    ),
    _Row(
      label: 'Üye / alan',
      free: _countLabel(free.memberPerHousehold),
      premium: _countLabel(premium.memberPerHousehold),
    ),
    _Row(
      label: 'İçgörü geçmişi',
      free: free.insightsWindowDays == null ? 'Tüm zamanlar' : '${free.insightsWindowDays} gün',
      premium: premium.insightsWindowDays == null ? 'Tüm zamanlar' : '${premium.insightsWindowDays} gün',
    ),
    _Row(label: 'Barkod okuma', free: free.barcode ? '✓' : '—', premium: premium.barcode ? '✓' : '—'),
    _Row(label: 'CSV dışa aktarma', free: free.export ? '✓' : '—', premium: premium.export ? '✓' : '—'),
  ];
}

class _BenefitsCardContent extends StatelessWidget {
  const _BenefitsCardContent({required this.catalog});
  final PlanCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _rowsFor(catalog);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('Fridge Premium', style: theme.textTheme.titleMedium)),
              ],
            ),
            if (catalog.familySeats != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${catalog.familySeats} kişiye kadar aile paketiyle paylaş',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Expanded(flex: 3, child: SizedBox.shrink()),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Ücretsiz',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Premium',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < rows.length; i++)
              _AnimatedBenefitRow(index: i, row: rows[i], showDivider: i != rows.length - 1),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBenefitRow extends StatelessWidget {
  const _AnimatedBenefitRow({required this.index, required this.row, required this.showDivider});

  final int index;
  final _Row row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + index * 40),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          // Metne değil, satırın TAMAMINA (dekoratif giriş animasyonu) —
          // cerebrum 2026-08-29 kuralı: "pasif" metin rengine opacity
          // verilmez, ama burada kalıcı bir soluk durum değil, geçici bir
          // giriş efekti (animasyon bitince value=1, opacity=1'e döner).
          opacity: value,
          child: Transform.translate(offset: Offset(0, (1 - value) * 6), child: child),
        );
      },
      child: _BenefitRow(row: row, showDivider: showDivider),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.row, required this.showDivider});
  final _Row row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(row.label, style: theme.textTheme.bodyMedium)),
              Expanded(
                flex: 2,
                child: Text(
                  row.free,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  row.premium,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ],
    );
  }
}

class _BenefitsCardSkeleton extends StatelessWidget {
  const _BenefitsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 20, width: 160, color: theme.colorScheme.surfaceContainerHighest),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < 4; i++) ...[
              Container(height: 14, width: double.infinity, color: theme.colorScheme.surfaceContainerHighest),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
