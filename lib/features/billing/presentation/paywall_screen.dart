import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show PackageType;

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_icons.dart';
import '../../../core/ui/app_progress.dart';
import '../application/entitlements_providers.dart';
import '../data/purchase_repository.dart';
import 'widgets/premium_benefits_card.dart';
import 'widgets/product_tile.dart';

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
  OfferingsFailure? _failure;
  String? _debugMessage;
  bool _loading = true;
  String? _selectedId;
  bool _purchasing = false;
  bool _restoring = false;
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
  List<PurchaseProduct> get _visibleProducts =>
      _familyTab ? _familyProducts : _individualProducts;

  /// Aylık/yıllık ayrımı artık RC'nin `packageType`'ıyla yapılır —
  /// `identifier.contains('annual')` string tahmini yalnızca `packageType`
  /// gelmediyse (unknown/custom) yedek olarak kalır.
  PurchaseProduct? _annualOf(List<PurchaseProduct> list) =>
      list.where((p) => p.packageType == PackageType.annual).firstOrNull ??
      list
          .where(
            (p) => p.packageType == null && p.identifier.contains('annual'),
          )
          .firstOrNull;

  PurchaseProduct? _monthlyOf(List<PurchaseProduct> list) =>
      list.where((p) => p.packageType == PackageType.monthly).firstOrNull ??
      list
          .where(
            (p) => p.packageType == null && p.identifier.contains('monthly'),
          )
          .firstOrNull;

  /// try/catch/finally ile sarılı — eskiden fetchOfferings() bir exception
  /// fırlatırsa hiç yakalanmıyordu, bu da _loading hiç false olmadığı için
  /// ekranın sonsuza kadar spinner'da donmasına sebep oluyordu (buglog:
  /// "abonelik ekranı boş geliyor").
  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final result = await ref
          .read(purchaseRepositoryProvider)
          .fetchOfferings();
      if (!mounted) return;
      setState(() {
        _products = result.products;
        _failure = result.failure;
        _debugMessage = result.debugMessage;
        // Yıllık varsayılan seçili (plan §Faz 4 "Paywall içeriği").
        _selectedId =
            _annualOf(_individualProducts)?.identifier ??
            _individualProducts.firstOrNull?.identifier;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectTab(bool family) {
    setState(() {
      _familyTab = family;
      final list = family ? _familyProducts : _individualProducts;
      _selectedId = _annualOf(list)?.identifier ?? list.firstOrNull?.identifier;
    });
  }

  Future<void> _purchase() async {
    if (_selectedId == null) return;
    setState(() => _purchasing = true);
    final result = await ref
        .read(purchaseRepositoryProvider)
        .purchase(_selectedId!);
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
        SnackBar(
          content: Text(result.errorMessage ?? 'Satın alma başarısız oldu.'),
        ),
      );
    }
  }

  /// Play politikası: satın alma "geri yükle" seçeneği sunulmalı — webhook
  /// kaçarsa (nadiren) kullanıcının tek kurtarma yolu. Önceden tanımlıydı
  /// ama hiçbir ekrandan çağrılmıyordu.
  Future<void> _restore() async {
    setState(() => _restoring = true);
    final restored = await ref
        .read(purchaseRepositoryProvider)
        .restorePurchases();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (restored) {
      ref.read(entitlementsControllerProvider.notifier).invalidate();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored
              ? 'Satın alımların geri yüklendi.'
              : 'Geri yüklenecek bir satın alma bulunamadı.',
        ),
      ),
    );
  }

  /// Politika gereği (Play/App Store) otomatik yenileme bildirimi seçili
  /// ürün deneme/indirim içeriyorsa süre ve sonraki fiyatı da anmalı —
  /// bildirimsiz deneme sürüm reddi sebebi olabilir.
  String _renewalDisclosure() {
    final selected = _visibleProducts
        .where((p) => p.identifier == _selectedId)
        .firstOrNull;
    if (selected == null)
      return 'Otomatik yenilenir · İstediğin zaman iptal edebilirsin';
    final period = selected.trialPeriodLabel;
    if (selected.hasFreeTrial && period != null) {
      return 'İlk $period ücretsiz, sonra ${selected.priceString} · İstediğin zaman iptal edebilirsin';
    }
    if (selected.hasIntroDiscount && selected.introPriceString != null) {
      return '${selected.introPriceString} ile başlar, sonra ${selected.priceString} · İstediğin zaman iptal edebilirsin';
    }
    return 'Otomatik yenilenir · İstediğin zaman iptal edebilirsin';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kapat',
          icon: Icon(AppIcons.close(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Elde Premium',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sınırsız fiş tarama, tarif üretimi ve AI Chef',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            const PremiumBenefitsCard(),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: AppProgress()),
              )
            else if (_failure != null)
              _OfferingsProblemNotice(
                failure: _failure!,
                debugMessage: _debugMessage,
                onRetry: _loadProducts,
              )
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
                      'Ev halkın tam premium olur.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
              for (final product in _visibleProducts)
                ProductTile(
                  product: product,
                  selected: product.identifier == _selectedId,
                  onTap: () => setState(() => _selectedId = product.identifier),
                  monthlyForComparison:
                      product.packageType == PackageType.annual
                      ? _monthlyOf(_visibleProducts)
                      : null,
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _purchasing ? null : _purchase,
                child: _purchasing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: AppProgress(strokeWidth: 2),
                      )
                    : const Text('Devam Et'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _renewalDisclosure(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: _restoring ? null : _restore,
                  child: _restoring
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: AppProgress(strokeWidth: 2),
                        )
                      : const Text('Satın alımları geri yükle'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanTabSelector extends StatelessWidget {
  const _PlanTabSelector({
    required this.familySelected,
    required this.onSelect,
  });

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
          Expanded(
            child: _TabButton(
              label: 'Bireysel',
              selected: !familySelected,
              onTap: () => onSelect(false),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Aile',
              selected: familySelected,
              onTap: () => onSelect(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// fetchOfferings()'in üç OfferingsFailure durumunu kullanıcıya ayrı ayrı,
/// suçlayıcı olmayan bir dille anlatır + "Tekrar dene" butonu — eskiden
/// tek bir "yakında açılıyor" metni vardı, sorunun sebebi hiç görünmüyordu.
class _OfferingsProblemNotice extends StatelessWidget {
  const _OfferingsProblemNotice({
    required this.failure,
    required this.debugMessage,
    required this.onRetry,
  });

  final OfferingsFailure failure;
  final String? debugMessage;
  final VoidCallback onRetry;

  String get _message => switch (failure) {
    OfferingsFailure.notConfigured =>
      'Abonelik satın alma şu an bu sürümde kapalı.',
    OfferingsFailure.noOffering =>
      'Paketler şu anda yüklenemedi, birazdan tekrar dene.',
    OfferingsFailure.storeError =>
      'Mağazaya ulaşılamadı — internet bağlantını kontrol edip tekrar dene.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (kDebugMode && debugMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${failure.name}: $debugMessage',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}
