import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/scan_progress.dart';
import '../../chef/presentation/chef_chat_screen.dart';
import '../application/recipe_providers.dart';
import '../data/recipe_repository.dart';
import 'recipe_detail_screen.dart';
import 'recipe_match_ring.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this);
  bool _isGenerating = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateAiRecipes() async {
    setState(() => _isGenerating = true);
    try {
      await ref.read(recipeRepositoryProvider).generateAiRecipes(widget.householdId);
      ref.invalidate(recipeSuggestionsProvider(widget.householdId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yeni tarifler hazır!')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _openDetail(Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(householdId: widget.householdId, recipeId: recipe.id),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: _isGenerating
          ? ScanProgress(
              steps: const ['Dolabın okunuyor...', 'Tarifler hazırlanıyor...', 'Malzemeler eşleştiriliyor...'],
              currentStep: 1,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dolabındakilerle ne pişirebilirsin?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.onPrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Yapay zeka dolabına özel tarifler önersin.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onPrimary.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: _generateAiRecipes,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.primary,
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('AI ile Tarif Üret'),
                ),
              ],
            ),
    );
  }

  Widget _buildRecipeCard(BuildContext context, Recipe recipe) {
    final total = recipe.totalIngredients ?? 0;
    final available = recipe.availableIngredients ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => _openDetail(recipe),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              if (total > 0) ...[
                RecipeMatchRing(available: available, total: total),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.title, style: Theme.of(context).textTheme.titleSmall),
                    if (recipe.description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        recipe.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        if (recipe.prepMinutes != null || recipe.cookMinutes != null)
                          Chip(
                            label: Text('${(recipe.prepMinutes ?? 0) + (recipe.cookMinutes ?? 0)} dk'),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (recipe.generatedBy == 'ai')
                          const Chip(
                            avatar: Icon(Icons.auto_awesome_rounded, size: 14),
                            label: Text('AI'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarifler'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Önerilenler'),
            Tab(text: 'Kayıtlı'),
            Tab(text: 'Favoriler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SuggestionsTab(
            householdId: widget.householdId,
            heroCard: _buildHeroCard(context),
            buildCard: _buildRecipeCard,
          ),
          _AllRecipesTab(householdId: widget.householdId, buildCard: _buildRecipeCard),
          _FavoritesTab(householdId: widget.householdId, buildCard: _buildRecipeCard, onOpen: _openDetail),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChefChatScreen(householdId: widget.householdId)),
        ),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('AI Chef'),
      ),
      bottomNavigationBar: AppBottomNav(currentTab: AppBottomTab.recipes, householdId: widget.householdId),
    );
  }
}

class _SuggestionsTab extends ConsumerWidget {
  const _SuggestionsTab({required this.householdId, required this.heroCard, required this.buildCard});

  final String householdId;
  final Widget heroCard;
  final Widget Function(BuildContext, Recipe) buildCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(recipeSuggestionsProvider(householdId));

    return AsyncView(
      value: suggestionsAsync,
      onRetry: () => ref.invalidate(recipeSuggestionsProvider(householdId)),
      data: (suggestions) => ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          heroCard,
          if (suggestions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: EmptyState(
                icon: Icons.restaurant_menu_rounded,
                message: 'Henüz bir tarifin yok.\nYukarıdan AI ile tarif üretebilirsin.',
              ),
            )
          else
            for (final recipe in suggestions) buildCard(context, recipe),
        ],
      ),
    );
  }
}

class _AllRecipesTab extends ConsumerWidget {
  const _AllRecipesTab({required this.householdId, required this.buildCard});

  final String householdId;
  final Widget Function(BuildContext, Recipe) buildCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipeListProvider(householdId));

    return AsyncView(
      value: recipesAsync,
      onRetry: () => ref.invalidate(recipeListProvider(householdId)),
      data: (recipes) => recipes.isEmpty
          ? const EmptyState(icon: Icons.menu_book_rounded, message: 'Henüz kayıtlı tarif yok.')
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [for (final recipe in recipes) buildCard(context, recipe)],
            ),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab({required this.householdId, required this.buildCard, required this.onOpen});

  final String householdId;
  final Widget Function(BuildContext, Recipe) buildCard;
  final void Function(Recipe) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIdsAsync = ref.watch(favoriteRecipeIdsProvider(householdId));
    final recipesAsync = ref.watch(recipeListProvider(householdId));

    return AsyncView(
      value: favoriteIdsAsync,
      onRetry: () => ref.invalidate(favoriteRecipeIdsProvider(householdId)),
      data: (favoriteIds) => AsyncView(
        value: recipesAsync,
        data: (recipes) {
          final favorites = recipes.where((r) => favoriteIds.contains(r.id)).toList();
          return favorites.isEmpty
              ? const EmptyState(icon: Icons.favorite_border_rounded, message: 'Henüz favori tarifin yok.')
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  children: [for (final recipe in favorites) buildCard(context, recipe)],
                );
        },
      ),
    );
  }
}
