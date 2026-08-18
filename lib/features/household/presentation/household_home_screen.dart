import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/storage_icon_box.dart';
import '../../../core/widgets/storage_kind.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../receipt/application/receipt_providers.dart';
import '../../receipt/presentation/receipt_review_screen.dart';
import '../../receipt/presentation/receipt_scan_screen.dart';
import '../application/household_providers.dart';
import '../data/household_repository.dart';

class HouseholdHomeScreen extends ConsumerWidget {
  const HouseholdHomeScreen({super.key, required this.household});

  final Household household;

  Future<void> _showInviteCode(BuildContext context, WidgetRef ref) async {
    final String code;
    try {
      code = await ref
          .read(householdRepositoryProvider)
          .createInvite(household.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
      return;
    }
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Davet Kodu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu kodu alanı paylaştığın kişiyle paylaş.'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.titleSmall?.copyWith(letterSpacing: 1),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  // Fiş taraması artık ekranı kilitlemiyor (bkz. receipt_scan_screen.dart) —
  // arka planda süren işi burada, ev ekranında bir banner ile gösteriyoruz.
  // İşleniyor/hazır/başarısız üç hali de kapsar; kullanıcı "Fiş Tara"ya
  // bastıktan sonra gezinmeye devam edebilir, sonucu buradan görür.
  Widget _buildPendingScanBanner(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingReceiptScanProvider(household.id));
    if (pending == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final notifier = ref.read(
      pendingReceiptScanProvider(household.id).notifier,
    );

    switch (pending.status) {
      case PendingScanStatus.processing:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: colorScheme.secondaryContainer,
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Fiş işleniyor...',
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
            ],
          ),
        );
      case PendingScanStatus.ready:
        return Material(
          color: colorScheme.primaryContainer,
          child: InkWell(
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => ReceiptReviewScreen(
                        householdId: household.id,
                        scanId: pending.scanId,
                        lineItems: pending.result!.lineItems,
                      ),
                    ),
                  )
                  .then((_) => notifier.clear());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Fiş hazır — incelemek için dokun',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
          ),
        );
      case PendingScanStatus.failed:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: colorScheme.errorContainer,
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Fiş işlenemedi',
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: notifier.clear,
                child: Text(
                  'Kapat',
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildLocationCard(BuildContext context, dynamic location) {
    final style = storageKindStyle(context, location.kind as String);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InventoryScreen(householdId: household.id, location: location),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StorageIconBox(icon: style.icon, color: style.color, size: 48, iconSize: 24),
              const SizedBox(height: AppSpacing.sm),
              Text(
                location.name as String,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(storageLocationsProvider(household.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(household.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_rounded),
            tooltip: 'Bu alana davet et',
            onPressed: () => _showInviteCode(context, ref),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          _buildPendingScanBanner(context, ref),
          Expanded(
            child: AsyncView(
              value: locationsAsync,
              onRetry: () => ref.invalidate(storageLocationsProvider(household.id)),
              data: (locations) {
                if (locations.isEmpty) {
                  return const EmptyState(
                    icon: Icons.category_rounded,
                    message: 'Bu alanda henüz bir depolama bölümü yok.',
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = gridColumnsFor(constraints.maxWidth);
                    // Tek sayıda kart varsa son kart iki sütun genişliğinde
                    // gösterilir (Stitch'in Ev Ana tasarımındaki Kiler kartı).
                    final hasDanglingLast = locations.length.isOdd && locations.length > 1 && columns == 2;
                    final gridCount = hasDanglingLast ? locations.length - 1 : locations.length;

                    return CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: AppSpacing.sm,
                              crossAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 1.1,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildLocationCard(context, locations[index]),
                              childCount: gridCount,
                            ),
                          ),
                        ),
                        if (hasDanglingLast)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                            sliver: SliverToBoxAdapter(
                              child: SizedBox(
                                height: constraints.maxWidth / columns / 1.1,
                                child: _buildLocationCard(context, locations.last),
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.fabBottomPadding),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentTab: AppBottomTab.areas),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text('Fiş Tara'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReceiptScanScreen(householdId: household.id),
          ),
        ),
      ),
    );
  }
}
