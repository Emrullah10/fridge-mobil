import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/household_kind.dart';
import '../../../core/widgets/single_field_dialog.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/upgrade_account_screen.dart';
import '../application/household_providers.dart';
import 'create_household_dialog.dart';

class HouseholdListScreen extends ConsumerWidget {
  const HouseholdListScreen({super.key});

  Future<void> _createHousehold(BuildContext context, WidgetRef ref) async {
    final result = await showHouseholdFormDialog(context);

    if (result == null || result.name.isEmpty) return;
    try {
      await ref
          .read(householdRepositoryProvider)
          .createHousehold(
            result.name,
            icon: result.icon,
            foodEnabled: result.foodEnabled,
          );
      ref.invalidate(householdsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  // 12 hane hex kod (bkz. household-invite.repository.js), 4'erli gruplu
  // gösterimle boşluklu ya da boşluksuz olabilir. WhatsApp'tan kopyalanan
  // kod panodaysa dialog açılırken otomatik dolsun diye kontrol ediyoruz.
  static final _codeLikePattern = RegExp(
    r'^[a-f0-9\s]{12,17}$',
    caseSensitive: false,
  );

  Future<void> _joinHousehold(BuildContext context, WidgetRef ref) async {
    String? clipboardCode;
    try {
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboard?.text?.trim();
      if (text != null && _codeLikePattern.hasMatch(text)) {
        clipboardCode = text;
      }
    } catch (_) {
      // Pano erişimi başarısız olsa da katılma akışını engellemesin.
    }

    if (!context.mounted) return;
    final code = await showSingleFieldDialog(
      context,
      title: 'Davet Koduyla Katıl',
      hintText: 'Davet kodu',
      confirmLabel: 'Katıl',
      initialText: clipboardCode,
    );

    // Kullanıcı görüntülemedeki 4'erli gruplu kodu ("a3f9 c1d0 e2b7") kopyalayıp
    // yapıştırabilir — boşlukları ve baş/son boşlukları temizle, büyük/küçük
    // harf duyarlılığını kaldır.
    final cleanCode = code?.trim().replaceAll(' ', '').toLowerCase();
    if (cleanCode == null || cleanCode.isEmpty) return;
    try {
      await ref.read(householdRepositoryProvider).acceptInvite(cleanCode);
      ref.invalidate(householdsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Alana katıldın')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdsAsync = ref.watch(householdsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isGuest = ref.watch(authControllerProvider).isGuest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alanlarım'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Çıkış yap',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          // Misafirin sürekli görünür bir hatırlatıcısı — verilerin bu
          // cihaza bağlı olduğunu ve kaybolabileceğini unutmasın.
          if (isGuest)
            Material(
              color: colorScheme.tertiaryContainer,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UpgradeAccountScreen(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Misafir modundasın — verilerin bu cihaza bağlı. Kalıcı yap.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: AsyncView(
              value: householdsAsync,
              onRetry: () => ref.invalidate(householdsProvider),
              data: (households) {
                Future<void> onRefresh() async {
                  ref.invalidate(householdsProvider);
                  await ref.read(householdsProvider.future);
                }

                if (households.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.6,
                          child: EmptyState(
                            icon: Icons.home_outlined,
                            message:
                                'Henüz bir alanın yok.\nAşağıdan yeni bir alan oluştur veya davet koduyla katıl.',
                            action: FilledButton.icon(
                              onPressed: () => _createHousehold(context, ref),
                              icon: const Icon(Icons.add),
                              label: const Text('Alan Oluştur'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.fabBottomPadding,
                    ),
                    itemCount: households.length,
                    itemBuilder: (context, index) {
                      final household = households[index];
                      final areaIcon = householdIconFor(
                        iconKey: household.icon,
                        kind: household.kind,
                      );
                      return Card(
                        child: ListTile(
                          // Hero: alan ana ekranının AppBar'ındaki eşleşen daireye
                          // "uçarak" büyüyen bir açılış hissi verir (bkz.
                          // household_home_screen.dart AppBar.title).
                          leading: Hero(
                            tag: 'household-avatar-${household.id}',
                            flightShuttleBuilder:
                                (
                                  context,
                                  animation,
                                  direction,
                                  fromContext,
                                  toContext,
                                ) => Material(
                                  type: MaterialType.transparency,
                                  child: CircleAvatar(
                                    backgroundColor:
                                        colorScheme.primaryContainer,
                                    child: Icon(
                                      areaIcon,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                            child: CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(
                                areaIcon,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(
                            household.name,
                            style: textTheme.titleSmall,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ref
                                    .read(selectedHouseholdIdProvider.notifier)
                                    .state =
                                household.id;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    AppShell.forHousehold(household),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpacing.sm,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join',
            onPressed: () => _joinHousehold(context, ref),
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            elevation: 0,
            icon: const Icon(Icons.group_add_rounded),
            label: const Text('Katıl'),
          ),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () => _createHousehold(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Alan'),
          ),
        ],
      ),
    );
  }
}
