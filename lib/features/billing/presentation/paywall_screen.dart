import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/entitlements_providers.dart';
import '../data/purchase_repository.dart';

/// Tam ekran paywall — deneme bitişinde (plan §Faz 4 tetikleyici #3) veya
/// "Premium'a Geç" ile açılır. Bağlamsal alt sayfadan (paywall_sheet.dart)
/// farkı: kullanıcı "Şimdi değil" diyemez bir yerden gelmişse (deneme
/// bitti, o günkü ilk açılış) burası kullanılır — ama HER ZAMAN geri
/// tuşu/kapatma ile atlanabilir, uygulamayı asla kilitlemez (hard paywall
/// DEĞİL, plan §Faz 3 "ücretsiz kademeye iner").
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<PurchaseProduct> _products = const [];
  bool _loading = true;
  String? _selectedId;
  bool _purchasing = false;
  // Aile paketi 4 ürünle geldiği için (bireysel aylık/yıllık + aile aylık/
  // yıllık) artık tek bir 'annual' araması yetmiyor — ürün kimliğinde
  // 'family' geçenler ayrı bir sekmede gösterilir (bkz. plan §Mobil özet).
  bool _familyTab = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  List<PurchaseProduct> get _individualProducts =>
      _products.where((p) => !p.identifier.contains('family')).toList();
  List<PurchaseProduct> get _familyProducts =>
      _products.where((p) => p.identifier.contains('family')).toList();
  List<PurchaseProduct> get _visibleProducts => _familyTab ? _familyProducts : _individualProducts;

  Future<void> _loadProducts() async {
    final products = await ref.read(purchaseRepositoryProvider).fetchOfferings();
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
      // Yıllık varsayılan seçili (plan §Faz 4 "Paywall içeriği") — ürün
      // kimlikleri Play Console'da 'fridge_premium_annual'/'_monthly'
      // olarak tanımlanacak (plan §Faz 5 Ürünler tablosu); burada isim
      // içinde 'annual' geçeni ararız, yoksa ilk ürün seçilir.
      _selectedId = _individualProducts.where((p) => p.identifier.contains('annual')).firstOrNull?.identifier
          ?? _individualProducts.firstOrNull?.identifier;
    });
  }

  void _selectTab(bool family) {
    setState(() {
      _familyTab = family;
      final list = family ? _familyProducts : _individualProducts;
      _selectedId = list.where((p) => p.identifier.contains('annual')).firstOrNull?.identifier
          ?? list.firstOrNull?.identifier;
    });
  }

  Future<void> _purchase() async {
    if (_selectedId == null) return;
    setState(() => _purchasing = true);
    final result = await ref.read(purchaseRepositoryProvider).purchase(_selectedId!);
    if (!mounted) return;
    setState(() => _purchasing = false);

    if (result.success) {
      // Webhook asenkron geldiği için entitlement'ı hemen zorla tazele —
      // kullanıcı "ödedim ama hâlâ ücretsiz görünüyorum" hissine kapılmasın.
      ref.read(entitlementsControllerProvider.notifier).invalidate();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (result.cancelled) return; // sessizce kapat, hata gösterme
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Satın alma başarısız oldu.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.workspace_premium_rounded, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text('Fridge Premium', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sınırsız fiş tarama, tarif üretimi ve AI Chef',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_products.isEmpty)
                _NotConfiguredNotice(theme: theme)
              else ...[
                if (_familyProducts.isNotEmpty) ...[
                  _PlanTabSelector(
                    familySelected: _familyTab,
                    onSelect: _selectTab,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_familyTab)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        '5 kişiye kadar ev halkın tam premium olur.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
                for (final product in _visibleProducts)
                  _ProductTile(
                    product: product,
                    selected: product.identifier == _selectedId,
                    onTap: () => setState(() => _selectedId = product.identifier),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _purchasing ? null : _purchase,
                  child: _purchasing
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Devam Et'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Otomatik yenilenir · İstediğin zaman iptal edebilirsin',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTabSelector extends StatelessWidget {
  const _PlanTabSelector({required this.familySelected, required this.onSelect});

  final bool familySelected;
  final void Function(bool family) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Expanded(child: _TabButton(label: 'Bireysel', selected: !familySelected, onTap: () => onSelect(false))),
          Expanded(child: _TabButton(label: 'Aile', selected: familySelected, onTap: () => onSelect(true))),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.selected, required this.onTap});

  final PurchaseProduct product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          child: Row(
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
                    Text(product.title, style: theme.textTheme.titleSmall),
                    Text(
                      product.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Fiyat MAĞAZADAN gelen yerelleştirilmiş string — asla sabit
              // kodlanmaz (plan §Faz 4 Play politikası notu).
              Text(product.priceString, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotConfiguredNotice extends StatelessWidget {
  const _NotConfiguredNotice({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Text(
        'Abonelik satın alma yakında açılıyor.',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }
}
