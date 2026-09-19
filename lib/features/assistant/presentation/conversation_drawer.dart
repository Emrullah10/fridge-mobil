import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_action_sheet.dart';
import '../../../core/ui/app_dialog.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/household_kind.dart';
import '../../household/application/household_providers.dart';
import '../application/assistant_providers.dart';
import '../data/assistant_repository.dart';

enum _ConvMenuAction { rename, delete }

/// Çekmece: sohbet geçmişi + alan rozeti (bkz. plan §D2). Flutter'ın
/// hamburger ikonunu ve kaydırma jestini Scaffold.drawer otomatik verir.
class ConversationDrawer extends ConsumerWidget {
  const ConversationDrawer({
    super.key,
    required this.activeConversationId,
    required this.onSelect,
    required this.onNew,
  });

  final String? activeConversationId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onNew;

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Conversation c,
  ) async {
    final controller = TextEditingController(text: c.title ?? '');
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbeti yeniden adlandır'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty) return;
    await ref.read(conversationListProvider.notifier).rename(c.id, newTitle);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Conversation c) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Sohbeti sil',
      message: 'Bu sohbet ve tüm geçmişi silinsin mi?',
      confirmLabel: 'Sil',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    await ref.read(conversationListProvider.notifier).remove(c.id);
    if (activeConversationId == c.id) onSelect(null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationListProvider);
    final households = ref.watch(householdsProvider).valueOrNull ?? [];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sohbetler',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Yeni sohbet',
                    icon: const Icon(Icons.add_comment_outlined),
                    onPressed: () {
                      onNew();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AsyncView(
                value: conversationsAsync,
                onRetry: () =>
                    ref.read(conversationListProvider.notifier).refresh(),
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Henüz sohbet yok'),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final c = conversations[index];
                      final household = c.householdId == null
                          ? null
                          : households
                              .where((h) => h.id == c.householdId)
                              .firstOrNull;

                      return ListTile(
                        selected: c.id == activeConversationId,
                        leading: Icon(
                          c.householdId == null
                              ? Icons.public
                              : householdIconFor(
                                  iconKey: household?.icon,
                                  kind: household?.kind ?? 'home',
                                ),
                        ),
                        title: Text(
                          c.title ?? 'Yeni sohbet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          household?.name ?? 'Alansız',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          onSelect(c.id);
                          Navigator.of(context).pop();
                        },
                        onLongPress: () async {
                          final action = await showAppActionSheet<_ConvMenuAction>(
                            context,
                            title: c.title ?? 'Yeni sohbet',
                            actions: const [
                              AppSheetAction(
                                value: _ConvMenuAction.rename,
                                label: 'Yeniden adlandır',
                                icon: Icons.edit_outlined,
                              ),
                              AppSheetAction(
                                value: _ConvMenuAction.delete,
                                label: 'Sil',
                                icon: Icons.delete_outline_rounded,
                                isDestructive: true,
                              ),
                            ],
                          );
                          if (!context.mounted || action == null) return;
                          switch (action) {
                            case _ConvMenuAction.rename:
                              await _rename(context, ref, c);
                            case _ConvMenuAction.delete:
                              await _delete(context, ref, c);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
