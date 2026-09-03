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

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

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
      _selectedId = products.where((p) => p.identifier.contains('annual')).firstOrNull?.identifier
          ?? products.firstOrNull?.identifier;
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
                for (final product in _products)
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
