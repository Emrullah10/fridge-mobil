import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../household/data/household_repository.dart';
import '../application/inventory_providers.dart';
import '../data/inventory_repository.dart';
import 'add_inventory_item_screen.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key, required this.householdId, required this.location});

  final String householdId;
  final StorageLocation location;

  Future<void> _consume(BuildContext context, WidgetRef ref, String itemId) async {
    final controller = TextEditingController(text: '1');
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ne kadar tüketildi?'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, double.tryParse(controller.text)),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0) return;
    final params = InventoryParams(householdId: householdId, storageLocationId: location.id);
    try {
      await ref.read(inventoryRepositoryProvider).consume(householdId, itemId, amount);
      ref.invalidate(inventoryItemsProvider(params));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  /// Son kullanma tarihi yaklaşanları (3 gün içinde) turuncu, geçmişleri
  /// kırmızı, uzak/yoksa nötr renkte gösterir — envanteri tararken göz
  /// bir bakışta hangi ürünün acele istediğini yakalar.
  Color? _expiryColor(BuildContext context, DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final daysLeft = expiresAt.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return Theme.of(context).colorScheme.error;
    if (daysLeft <= 3) return const Color(0xFFB45309);
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = InventoryParams(householdId: householdId, storageLocationId: location.id);
    final itemsAsync = ref.watch(inventoryItemsProvider(params));
    final dateFormat = DateFormat('dd.MM.yyyy');
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(location.name)),
      body: AsyncView(
        value: itemsAsync,
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              message: 'Bu bölüm boş.\nFiş tarayarak veya elle ekleyerek doldurabilirsin.',
              action: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Ürün Ekle'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddInventoryItemScreen(householdId: householdId, storageLocationId: location.id),
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) {
              final InventoryItem item = items[index];
              final expiryColor = _expiryColor(context, item.expiresAt);

              return Card(
                child: ListTile(
                  title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: item.expiresAt != null
                      ? Row(
                          children: [
                            Icon(Icons.event_rounded, size: 14, color: expiryColor ?? colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              'SKT ${dateFormat.format(item.expiresAt!)}',
                              style: TextStyle(
                                color: expiryColor ?? colorScheme.onSurfaceVariant,
                                fontWeight: expiryColor != null ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        )
                      : null,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.quantity} ${item.unit}',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    tooltip: 'Tüket',
                    onPressed: () => _consume(context, ref, item.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddInventoryItemScreen(householdId: householdId, storageLocationId: location.id),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
