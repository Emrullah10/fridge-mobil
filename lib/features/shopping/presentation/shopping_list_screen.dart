import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/voice_input_button.dart';
import '../../../core/widgets/unit_label.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../product/presentation/product_picker_sheet.dart';
import '../application/shopping_providers.dart';
import '../data/shopping_repository.dart';
import 'shopping_item_sheet.dart';
import 'transfer_sheet.dart';

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key, required this.householdId});

  final String householdId;

  Future<void> _addFromPicker(BuildContext context, WidgetRef ref) async {
    final product = await showProductPicker(context, householdId: householdId);
    if (product == null || !context.mounted) return;

    final edit = await showShoppingItemSheet(context);
    if (edit == null) return;

    try {
      await ref.read(shoppingRepositoryProvider).addItem(
            householdId,
            productId: product.id,
            quantity: edit.quantity,
            unit: edit.unit,
            note: edit.note,
          );
      ref.invalidate(shoppingListProvider(householdId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  Future<void> _addSuggestion(BuildContext context, WidgetRef ref, ShoppingSuggestion suggestion) async {
    try {
      await ref.read(shoppingRepositoryProvider).addItem(
            householdId,
            productId: suggestion.productId,
            customName: suggestion.productId == null ? suggestion.name : null,
            quantity: suggestion.quantity ?? 1,
            unit: suggestion.unit,
            source: 'low_stock',
          );
      ref.invalidate(shoppingListProvider(householdId));
      ref.invalidate(shoppingSuggestionsProvider(householdId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  // Tüketim ritmi + serbest metin önerileri buradan eklenir. AI önerisinin
  // productId'si sunucu tarafında doğrulanmıştır (bkz. suggest-ai-shopping-items
  // use-case) ama null olabilir — bu durumda customName ile eklenir.
  Future<void> _addAiSuggestion(BuildContext context, WidgetRef ref, ShoppingSuggestion suggestion) async {
    try {
      await ref.read(shoppingRepositoryProvider).addItem(
            householdId,
            productId: suggestion.productId,
            customName: suggestion.productId == null ? suggestion.name : null,
            quantity: suggestion.quantity ?? 1,
            unit: suggestion.unit,
            source: 'ai_suggestion',
          );
      ref.invalidate(shoppingListProvider(householdId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  Future<void> _promptFreeTextRequest(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ne almalıyım?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'örn. bu hafta 4 kişilik kahvaltılık lazım',
            suffixIcon: VoiceInputButton(controller: controller),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Öner'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty || !context.mounted) return;

    await ref.read(textShoppingSuggestionsProvider(householdId).notifier).generate(text);
    if (!context.mounted) return;

    final result = ref.read(textShoppingSuggestionsProvider(householdId));
    result.whenOrNull(
      error: (error, _) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error)))),
    );
  }

  Future<void> _toggleChecked(WidgetRef ref, ShoppingItem item) async {
    await ref.read(shoppingRepositoryProvider).updateItem(householdId, item.id, isChecked: !item.isChecked);
    ref.invalidate(shoppingListProvider(householdId));
  }

  Future<void> _editItem(BuildContext context, WidgetRef ref, ShoppingItem item) async {
    final edit = await showShoppingItemSheet(context, existing: item);
    if (edit == null) return;
    await ref.read(shoppingRepositoryProvider).updateItem(
          householdId,
          item.id,
          quantity: edit.quantity,
          unit: edit.unit,
          note: edit.note,
        );
    ref.invalidate(shoppingListProvider(householdId));
  }

  Future<void> _removeItem(WidgetRef ref, ShoppingItem item) async {
    await ref.read(shoppingRepositoryProvider).removeItem(householdId, item.id);
    ref.invalidate(shoppingListProvider(householdId));
  }

  Future<void> _transfer(BuildContext context, WidgetRef ref) async {
    final result = await showTransferSheet(context, householdId: householdId);
    if (result == null) return;

    try {
      final count = await ref.read(shoppingRepositoryProvider).transferToInventory(
            householdId,
            storageLocationId: result.storageLocationId,
            expiresAt: result.expiresAt,
          );
      ref.invalidate(shoppingListProvider(householdId));
      // Envanter ekranı stale kalmasın diye TÜM inventoryItemsProvider ailesi
      // invalidate ediliyor — hangi lokasyonun etkilendiği burada belirsiz
      // (family parametreli), parametresiz invalidate tüm varyantları düşürür.
      ref.invalidate(inventoryItemsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count ürün dolaba eklendi')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  Map<String, List<ShoppingItem>> _groupBySource(List<ShoppingItem> items) {
    final unchecked = items.where((i) => !i.isChecked).toList();
    final checked = items.where((i) => i.isChecked).toList();
    return {'unchecked': unchecked, 'checked': checked};
  }

  Widget _buildSourceBadge(ShoppingItem item) {
    return switch (item.source) {
      'recipe' => AppBadge(label: item.note ?? 'Tarif', variant: AppBadgeVariant.quantity),
      'low_stock' => const AppBadge(label: 'Azalıyor', variant: AppBadgeVariant.warning),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildItemTile(BuildContext context, WidgetRef ref, ShoppingItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => _removeItem(ref, item),
      child: GestureDetector(
        onLongPress: () => _editItem(context, ref, item),
        child: CheckboxListTile(
          value: item.isChecked,
          onChanged: (_) => _toggleChecked(ref, item),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            item.name,
            style: item.isChecked
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: Row(
            children: [
              Text('${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} ${unitShortLabel(item.unit)}'),
              if (item.source != 'manual') ...[
                const SizedBox(width: AppSpacing.xs),
                _buildSourceBadge(item),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(shoppingListProvider(householdId));
    final suggestionsAsync = ref.watch(shoppingSuggestionsProvider(householdId));
    final aiSuggestionsAsync = ref.watch(aiShoppingSuggestionsProvider(householdId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alışveriş'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Ne almalıyım?',
            onPressed: () => _promptFreeTextRequest(context, ref),
          ),
        ],
      ),
      body: AsyncView(
        value: listAsync,
        onRetry: () => ref.invalidate(shoppingListProvider(householdId)),
        data: (listData) {
          final grouped = _groupBySource(listData.items);
          final unchecked = grouped['unchecked']!;
          final checked = grouped['checked']!;
          final total = listData.items.length;

          return Column(
            children: [
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$total üründen ${checked.length} tanesi alındı',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(value: total == 0 ? 0 : checked.length / total),
                      ),
                    ],
                  ),
                ),
              suggestionsAsync.maybeWhen(
                data: (suggestions) => (suggestions.isEmpty && aiSuggestionsAsync.valueOrNull?.isEmpty != false)
                    ? const SizedBox.shrink()
                    : SizedBox(
                        height: 44,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          scrollDirection: Axis.horizontal,
                          itemCount: suggestions.length
                              + (aiSuggestionsAsync.valueOrNull?.length ?? 0)
                              + 1, // "Akıllı öneriler" tetikleme çipi
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
                          itemBuilder: (context, index) {
                            if (index < suggestions.length) {
                              final suggestion = suggestions[index];
                              return ActionChip(
                                avatar: const Icon(Icons.add_rounded, size: 16),
                                label: Text(suggestion.name),
                                onPressed: () => _addSuggestion(context, ref, suggestion),
                              );
                            }

                            final aiIndex = index - suggestions.length;
                            final aiSuggestions = aiSuggestionsAsync.valueOrNull ?? [];
                            if (aiIndex < aiSuggestions.length) {
                              final suggestion = aiSuggestions[aiIndex];
                              return ActionChip(
                                avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                                label: Text(suggestion.name),
                                tooltip: suggestion.reasonText,
                                onPressed: () => _addAiSuggestion(context, ref, suggestion),
                              );
                            }

                            // Son çip: "Akıllı öneriler" tetikleyici.
                            return ActionChip(
                              avatar: aiSuggestionsAsync.isLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.auto_awesome_rounded, size: 16),
                              label: const Text('Akıllı öneriler'),
                              onPressed: aiSuggestionsAsync.isLoading
                                  ? null
                                  : () => ref.read(aiShoppingSuggestionsProvider(householdId).notifier).generate(),
                            );
                          },
                        ),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              Expanded(
                child: total == 0
                    ? const EmptyState(
                        icon: Icons.shopping_cart_outlined,
                        message: 'Alışveriş listen boş.\nSağ alttaki + ile ürün ekleyebilirsin.',
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: AppSpacing.fabBottomPadding),
                        children: [
                          for (final item in unchecked) _buildItemTile(context, ref, item),
                          if (checked.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                              child: Text('Alınanlar', style: Theme.of(context).textTheme.labelSmall),
                            ),
                            for (final item in checked) _buildItemTile(context, ref, item),
                          ],
                        ],
                      ),
              ),
              if (checked.isNotEmpty)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _transfer(context, ref),
                        icon: const Icon(Icons.kitchen_rounded),
                        label: Text('Dolaba Aktar (${checked.length})'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: AppBottomNav(currentTab: AppBottomTab.shopping, householdId: householdId),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addFromPicker(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
