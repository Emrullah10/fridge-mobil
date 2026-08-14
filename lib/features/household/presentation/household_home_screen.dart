import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../receipt/presentation/receipt_scan_screen.dart';
import '../application/household_providers.dart';
import '../data/household_repository.dart';

class _LocationStyle {
  const _LocationStyle(this.icon, this.color);
  final IconData icon;
  final Color color;
}

const _locationStyles = {
  'fridge': _LocationStyle(Icons.kitchen_rounded, Color(0xFF3B82F6)),
  'freezer': _LocationStyle(Icons.ac_unit_rounded, Color(0xFF06B6D4)),
  'pantry': _LocationStyle(Icons.inventory_2_rounded, Color(0xFFB45309)),
};
const _defaultLocationStyle = _LocationStyle(Icons.category_rounded, Color(0xFF6B7280));

class HouseholdHomeScreen extends ConsumerWidget {
  const HouseholdHomeScreen({super.key, required this.household});

  final Household household;

  Future<void> _showInviteCode(BuildContext context, WidgetRef ref) async {
    final String code;
    try {
      code = await ref.read(householdRepositoryProvider).createInvite(household.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
      return;
    }
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Davet Kodu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu kodu ev arkadaşınla paylaş.'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
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
            tooltip: 'Ev arkadaşı davet et',
            onPressed: () => _showInviteCode(context, ref),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: AsyncView(
        value: locationsAsync,
        data: (locations) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl * 2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.1,
          ),
          itemCount: locations.length,
          itemBuilder: (context, index) {
            final location = locations[index];
            final style = _locationStyles[location.kind] ?? _defaultLocationStyle;
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: style.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(style.icon, color: style.color, size: 26),
                      ),
                      const Spacer(),
                      Text(location.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text('Fiş Tara'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReceiptScanScreen(householdId: household.id)),
        ),
      ),
    );
  }
}
