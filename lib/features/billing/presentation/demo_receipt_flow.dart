import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/scan_progress.dart';

/// Misafir modunda "Fiş Tara" FAB'ına basınca gerçek kamera/Gemini yerine
/// açılan sıfır-maliyetli demo — plan §Faz 2. Gemini HİÇ çağrılmaz, sahte
/// veri envantere ASLA yazılmaz (bu ekranın hiçbir yerinde bir mutation
/// çağrısı yok). Amaç: misafire ürünün "aha" anını göstermek (araştırma:
/// ilk oturumda değer görmeyen kullanıcı %50+ oranda kayboluyor) ama gerçek
/// AI maliyetini hiç harcamadan.
class _DemoLineItem {
  const _DemoLineItem({required this.name, required this.brand, required this.price, required this.icon});
  final String name;
  final String brand;
  final double price;
  final IconData icon;
}

// Gerçekçi marka + fiyatlarla sabit bir Dart const — backend'e hiç istek
// atılmaz. Fiyatlar TL, yaklaşık piyasa değerleri.
const _demoItems = <_DemoLineItem>[
  _DemoLineItem(name: 'Süt 1L', brand: 'Sütaş', price: 32.50, icon: Icons.icecream_outlined),
  _DemoLineItem(name: 'Yumurta 10lu', brand: 'Yumurtacı', price: 89.90, icon: Icons.egg_outlined),
  _DemoLineItem(name: 'Domates (Kg)', brand: '', price: 44.00, icon: Icons.circle_outlined),
  _DemoLineItem(name: 'Ekmek', brand: 'Fırın', price: 12.00, icon: Icons.bakery_dining_outlined),
  _DemoLineItem(name: 'Beyaz Peynir', brand: 'Pınar', price: 156.90, icon: Icons.square_outlined),
  _DemoLineItem(name: 'Zeytinyağı 1L', brand: 'Komili', price: 289.90, icon: Icons.water_drop_outlined),
];

/// FAB'a bağlanan giriş noktası — misafirse bunu, kayıtlı kullanıcıysa
/// gerçek ReceiptScanScreen'i açan karar household_home_screen.dart'ta.
Future<void> showDemoReceiptFlow(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.dialog)),
    ),
    builder: (_) => const _DemoReceiptSheet(),
  );
}

class _DemoReceiptSheet extends StatefulWidget {
  const _DemoReceiptSheet();

  @override
  State<_DemoReceiptSheet> createState() => _DemoReceiptSheetState();
}

enum _DemoStep { scanning, reading, matching, done }

class _DemoReceiptSheetState extends State<_DemoReceiptSheet> {
  _DemoStep _step = _DemoStep.scanning;

  static const _stepLabels = ['Fotoğraf okunuyor', 'Satırlar ayrıştırılıyor', 'Ürünler eşleştiriliyor'];

  @override
  void initState() {
    super.initState();
    _runFakeProgress();
  }

  Future<void> _runFakeProgress() async {
    // Gerçek akışın hissini verecek kısa, sabit bir animasyon zinciri —
    // gerçek Gemini gecikmesini taklit etmeye çalışmaz (55sn beklemek
    // demoyu can sıkıcı yapardı), sadece "bir şey oluyor" hissi verir.
    for (final step in [_DemoStep.reading, _DemoStep.matching, _DemoStep.done]) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() => _step = step);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              const AppBadge(label: 'ÖRNEK', variant: AppBadgeVariant.warning),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_step != _DemoStep.done) ...[
            const SizedBox(height: AppSpacing.xl),
            ScanProgress(steps: _stepLabels, currentStep: _stepIndex),
            const SizedBox(height: AppSpacing.xl),
          ] else ...[
            Text('Örnek fiş taraması tamamlandı', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Gerçek fişini taradığında ürünler otomatik dolabına eklenir.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            ..._demoItems.map((item) => _DemoLineTile(item: item)),
            const Divider(height: AppSpacing.lg),
            _DemoTotalRow(total: _demoItems.fold<double>(0, (sum, item) => sum + item.price)),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kendi Fişini Tara — Ücretsiz Hesap Aç'),
            ),
          ],
        ],
      ),
    );
  }

  int get _stepIndex => switch (_step) {
        _DemoStep.scanning => 0,
        _DemoStep.reading => 0,
        _DemoStep.matching => 1,
        _DemoStep.done => 2,
      };
}

class _DemoLineTile extends StatelessWidget {
  const _DemoLineTile({required this.item});
  final _DemoLineItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Icon(item.icon, size: 18, color: theme.colorScheme.onSecondaryContainer),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: theme.textTheme.bodyMedium),
                if (item.brand.isNotEmpty)
                  Text(item.brand, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text('₺${item.price.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _DemoTotalRow extends StatelessWidget {
  const _DemoTotalRow({required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Toplam', style: theme.textTheme.titleSmall),
        Text('₺${total.toStringAsFixed(2)}', style: theme.textTheme.titleSmall),
      ],
    );
  }
}
