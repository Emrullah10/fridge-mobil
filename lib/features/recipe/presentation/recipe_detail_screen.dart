import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/unit_label.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../shopping/application/shopping_providers.dart';
import '../application/recipe_providers.dart';
import '../data/recipe_repository.dart';
import 'recipe_step_screen.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.householdId, required this.recipeId});

  final String householdId;
  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _isCooking = false;
  bool _isAddingMissing = false;

  RecipeDetailParams get _params => RecipeDetailParams(householdId: widget.householdId, recipeId: widget.recipeId);

  Future<void> _addMissingToList(List<RecipeIngredient> missing) async {
    setState(() => _isAddingMissing = true);
    try {
      final added = await ref.read(shoppingRepositoryProvider).addFromRecipe(widget.householdId, widget.recipeId);
      ref.invalidate(shoppingListProvider(widget.householdId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$added ürün alışveriş listesine eklendi'),
          action: SnackBarAction(label: 'Listeye git', onPressed: () => Navigator.of(context).pop()),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    } finally {
      if (mounted) setState(() => _isAddingMissing = false);
    }
  }

  Future<void> _cook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bu tarifi pişirdin mi?'),
        content: const Text('Malzemeler dolabından düşülecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Evet, pişirdim')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCooking = true);
    try {
      final result = await ref.read(recipeRepositoryProvider).cook(widget.householdId, widget.recipeId);
      // Fiş onayı bug'ında yaşanan aynı hata sınıfı: envanteri güncelleyen
      // bir işlemden sonra inventoryItemsProvider invalidate edilmezse UI
      // stale kalır ("eklenmedi/düşmedi" sanılır). Parametresiz invalidate —
      // hangi lokasyon etkilendiği burada belirsiz, tüm aile düşürülür.
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(shoppingSuggestionsProvider(widget.householdId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.insufficientCount > 0
              ? 'Pişirildi — ${result.insufficientCount} malzeme yetersizdi'
              : 'Afiyet olsun!'),
        ));
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    } finally {
      if (mounted) setState(() => _isCooking = false);
    }
  }

  Widget _matchIcon(BuildContext context, String? status) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      'available' => Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 20),
      'partial' => const Icon(Icons.circle_outlined, color: Color(0xFFB45309), size: 20),
      'unit_mismatch' => const Icon(Icons.help_outline_rounded, color: Color(0xFFB45309), size: 20),
      _ => Icon(Icons.cancel_outlined, color: colorScheme.error, size: 20),
    };
  }

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(_params));

    return Scaffold(
      appBar: AppBar(title: const Text('Tarif')),
      body: AsyncView(
        value: recipeAsync,
        onRetry: () => ref.invalidate(recipeDetailProvider(_params)),
        data: (recipe) {
          final missing = recipe.ingredients
              .where((i) => !i.isOptional && i.matchStatus != 'available')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(recipe.title, style: Theme.of(context).textTheme.headlineMedium),
              if (recipe.description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(recipe.description!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  if (recipe.servings != null) Chip(label: Text('${recipe.servings} porsiyon')),
                  if (recipe.prepMinutes != null || recipe.cookMinutes != null)
                    Chip(label: Text('${(recipe.prepMinutes ?? 0) + (recipe.cookMinutes ?? 0)} dk')),
                  if (recipe.difficulty != null) Chip(label: Text(recipe.difficulty!)),
                ],
              ),
              if (recipe.nutrition != null && recipe.nutrition!.hasData) ...[
                const SizedBox(height: AppSpacing.md),
                _NutritionCard(nutrition: recipe.nutrition!),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Malzemeler', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Card(
                child: Column(
                  children: [
                    for (final ingredient in recipe.ingredients)
                      ListTile(
                        leading: _matchIcon(context, ingredient.matchStatus),
                        title: Text(ingredient.productName),
                        trailing: Text('${ingredient.quantity.toStringAsFixed(ingredient.quantity % 1 == 0 ? 0 : 1)} ${unitShortLabel(ingredient.unit)}'),
                      ),
                  ],
                ),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isAddingMissing ? null : () => _addMissingToList(missing),
                    icon: _isAddingMissing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_shopping_cart_rounded),
                    label: Text('Eksik ${missing.length} malzemeyi listeye ekle'),
                  ),
                ),
              ],
              if (recipe.steps.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Hazırlanışı', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeStepScreen(title: recipe.title, steps: recipe.steps),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Adım Adım Pişirme Modu'),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final step in recipe.steps)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Text('${step.order}. ${step.text}'),
                  ),
              ] else if (recipe.instructions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Hazırlanışı', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(recipe.instructions),
              ],
              const SizedBox(height: AppSpacing.fabBottomPadding),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isCooking ? null : _cook,
              icon: _isCooking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.restaurant_rounded),
              label: const Text('Pişirdim'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Porsiyon başına besin değeri. complete=false ise "yaklaşık" rozeti gösterir
/// (bazı malzemelerin besin verisi yoktu — tahmin uydurulmaz).
class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.nutrition});

  final RecipeNutrition nutrition;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Widget macro(String label, String value) => Column(
          children: [
            Text(value, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        );

    String g(double v) => '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} g';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Porsiyon başına', style: tt.titleSmall),
                const SizedBox(width: AppSpacing.sm),
                if (!nutrition.complete)
                  Text('· yaklaşık', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                macro('kcal', '${nutrition.kcal}'),
                macro('protein', g(nutrition.protein)),
                macro('karb.', g(nutrition.carb)),
                macro('yağ', g(nutrition.fat)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
