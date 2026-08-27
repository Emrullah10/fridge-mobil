import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/async_view.dart';
import '../../product/application/product_providers.dart';
import '../application/insights_providers.dart';
import '../data/insights_repository.dart';

/// Para & israf paneli. Frantry'nin "bu ay X TL kurtardın" kancasının
/// karşılığı + bizde ek olan üye kırılımı ("kim ne kadar tüketti/israf etti").
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  // 0 = bu ay, 1 = geçen ay, 2 = son 90 gün
  int _rangeIndex = 0;

  ({DateTime? from, DateTime? to}) get _range {
    final now = DateTime.now().toUtc();
    switch (_rangeIndex) {
      case 1:
        return (from: DateTime.utc(now.year, now.month - 1, 1), to: DateTime.utc(now.year, now.month, 1));
      case 2:
        return (from: now.subtract(const Duration(days: 90)), to: null);
      default:
        return (from: null, to: null); // backend: içinde bulunulan ay
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _range;
    final period = InsightsPeriod(householdId: widget.householdId, from: r.from, to: r.to);
    final value = ref.watch(householdInsightsProvider(period));

    return Scaffold(
      appBar: AppBar(title: const Text('Para & İsraf')),
      bottomNavigationBar: AppBottomNav(
        currentTab: AppBottomTab.insights,
        householdId: widget.householdId,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(householdInsightsProvider(period)),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _RangeSelector(
              index: _rangeIndex,
              onChanged: (i) => setState(() => _rangeIndex = i),
            ),
            const SizedBox(height: AppSpacing.md),
            AsyncView<HouseholdInsights>(
              value: value,
              onRetry: () => ref.invalidate(householdInsightsProvider(period)),
              data: (d) => _InsightsBody(data: d, householdId: widget.householdId),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('Bu ay')),
        ButtonSegment(value: 1, label: Text('Geçen ay')),
        ButtonSegment(value: 2, label: Text('Son 90 gün')),
      ],
      selected: {index},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _InsightsBody extends ConsumerWidget {
  const _InsightsBody({required this.data, required this.householdId});
  final HouseholdInsights data;
  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final categories = ref.watch(productCategoriesProvider(householdId)).valueOrNull ?? [];
    String catLabel(String key) {
      if (key == 'uncategorized') return 'Kategorisiz';
      for (final c in categories) {
        if (c.key == key) return c.nameTr;
      }
      return key;
    }

    final hasAnyData = data.saved > 0 || data.wasted > 0 || data.spent > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Kurtarılan',
                amount: data.saved,
                color: cs.primary,
                icon: Icons.savings_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                label: 'İsraf',
                amount: data.wasted,
                color: cs.error,
                icon: Icons.delete_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _StatTile(
          label: 'Bu dönem alışverişe giren',
          amount: data.spent,
          color: cs.tertiary,
          icon: Icons.receipt_long_rounded,
          dense: true,
        ),
        if (data.missingPriceCount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _NoticeCard(
            text: '${data.missingPriceCount} hareket fiyatsız olduğu için '
                'toplamlara katılmadı. Eski kayıtlarda fiyat bilgisi olmayabilir.',
          ),
        ],
        if (!hasAnyData) ...[
          const SizedBox(height: AppSpacing.lg),
          const _EmptyHint(),
        ],
        if (data.topWasted.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('En çok israf edilenler'),
          const SizedBox(height: AppSpacing.sm),
          for (final w in data.topWasted)
            _WastedRow(
              title: [w.productBrand, w.productName].where((s) => s != null && s.isNotEmpty).join(' '),
              amount: w.wasted,
              max: data.topWasted.first.wasted,
              color: cs.error,
            ),
        ],
        if (data.byCategory.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('Kategoriye göre'),
          const SizedBox(height: AppSpacing.sm),
          for (final b in _sortedByTotal(data.byCategory))
            _CategoryRow(
              label: catLabel(b.categoryKey),
              saved: b.saved,
              wasted: b.wasted,
              max: _maxTotal(data.byCategory),
              savedColor: cs.primary,
              wastedColor: cs.error,
            ),
        ],
        if (data.byMember.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('Kişiye göre'),
          const SizedBox(height: AppSpacing.sm),
          for (final m in data.byMember)
            _CategoryRow(
              label: m.displayName ?? 'Bilinmeyen',
              saved: m.saved,
              wasted: m.wasted,
              max: _maxMemberTotal(data.byMember),
              savedColor: cs.primary,
              wastedColor: cs.error,
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  static List<InsightBucket> _sortedByTotal(List<InsightBucket> list) {
    final copy = [...list]..sort((a, b) => (b.saved + b.wasted).compareTo(a.saved + a.wasted));
    return copy;
  }

  static double _maxTotal(List<InsightBucket> list) {
    double m = 0;
    for (final b in list) {
      final t = b.saved + b.wasted;
      if (t > m) m = t;
    }
    return m == 0 ? 1 : m;
  }

  static double _maxMemberTotal(List<InsightMember> list) {
    double m = 0;
    for (final b in list) {
      final t = b.saved + b.wasted;
      if (t > m) m = t;
    }
    return m == 0 ? 1 : m;
  }
}

String _money(double v) {
  // Basit TL biçimlendirme — intl locale kurulumu Faz 5'te gelecek.
  final s = v.toStringAsFixed(2);
  return '₺$s';
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.dense = false,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(dense ? AppSpacing.md : AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: dense ? 22 : 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tt.bodySmall),
                const SizedBox(height: 2),
                Text(
                  _money(amount),
                  style: (dense ? tt.titleMedium : tt.titleLarge)?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleSmall);
  }
}

class _WastedRow extends StatelessWidget {
  const _WastedRow({required this.title, required this.amount, required this.max, required this.color});
  final String title;
  final double amount;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final frac = max <= 0 ? 0.0 : (amount / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title.isEmpty ? 'Ürün' : title, style: tt.bodyMedium, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: AppSpacing.sm),
              Text(_money(amount), style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          _Bar(fraction: frac, color: color),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.saved,
    required this.wasted,
    required this.max,
    required this.savedColor,
    required this.wastedColor,
  });

  final String label;
  final double saved;
  final double wasted;
  final double max;
  final Color savedColor;
  final Color wastedColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final savedFrac = (saved / max).clamp(0.0, 1.0);
    final wastedFrac = (wasted / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tt.bodyMedium),
          const SizedBox(height: 4),
          // İki ayrı bar: üstte kurtarılan, altta israf. Renk tek başına ayrım
          // taşımasın diye her satırın kendi etiketi (₺ tutar) var.
          if (saved > 0) ...[
            _LabeledBar(fraction: savedFrac, color: savedColor, trailing: _money(saved), tag: 'kurtarılan'),
            const SizedBox(height: 3),
          ],
          if (wasted > 0)
            _LabeledBar(fraction: wastedFrac, color: wastedColor, trailing: _money(wasted), tag: 'israf'),
        ],
      ),
    );
  }
}

class _LabeledBar extends StatelessWidget {
  const _LabeledBar({required this.fraction, required this.color, required this.trailing, required this.tag});
  final double fraction;
  final Color color;
  final String trailing;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(width: 62, child: Text(tag, style: tt.bodySmall)),
        Expanded(child: _Bar(fraction: fraction, color: color)),
        const SizedBox(width: AppSpacing.sm),
        Text(trailing, style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: fraction <= 0 ? 0.02 : fraction,
        minHeight: 8,
        backgroundColor: color.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(Icons.query_stats_rounded, size: 48, color: cs.onSurfaceVariant),
        const SizedBox(height: AppSpacing.sm),
        Text('Bu dönem için henüz veri yok', style: tt.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Fiş taradıkça ve ürünleri "kullandım / attım" olarak işaretledikçe '
          'burada ne kadar kurtardığını ve ne kadarının israf olduğunu göreceksin.',
          textAlign: TextAlign.center,
          style: tt.bodySmall,
        ),
      ],
    );
  }
}
