import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_icons.dart';
import '../../../core/ui/app_progress.dart';
import '../../../core/ui/app_text_field.dart';
import '../../billing/application/paywall_controller.dart';
import '../../billing/presentation/widgets/quota_upsell_banner.dart';
import '../../shopping/application/shopping_providers.dart';
import '../application/assistant_providers.dart';
import '../data/assistant_repository.dart';
import 'conversation_drawer.dart';
import 'guide_card.dart';
import 'mode_chips.dart';
import 'mode_mismatch_banner.dart';

/// AI Asistan — chef_chat_screen.dart'ın genellemesi (bkz. plan §D1). Tek
/// ekran, ayrı Chef/Usta ekranı yok. [initialHouseholdId] verilirse alan
/// içinden açılmıştır (yeni sohbet o alana bağlanır); verilmezse alansız
/// (household_list_screen.dart'tan).
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({
    super.key,
    this.initialHouseholdId,
    this.initialConversationId,
    this.seedPrompt,
  });

  final String? initialHouseholdId;
  final String? initialConversationId;
  final String? seedPrompt;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _composerFocus = FocusNode();
  bool _seedSent = false;
  final Set<String> _savingGuideFor = {};
  final Set<String> _savedGuideFor = {};

  static const _quickPrompts = [
    'Son kullanma tarihi yaklaşanlarla ne pişirebilirim?',
    'Bu akşam 30 dakikada ne yapabilirim?',
    'Bir şey tamir etmem lazım, yardım eder misin?',
  ];

  late String? _conversationId = widget.initialConversationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeConversationIdProvider.notifier).state = _conversationId;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    _controller.clear();
    await ref
        .read(conversationChatProvider(_conversationId).notifier)
        .send(
          text,
          initialHouseholdId: widget.initialHouseholdId,
          initialMode: widget.initialHouseholdId != null ? 'food' : 'general',
        );
    // Sohbet ilk mesajda yaratıldıysa provider'ın kendi ürettiği id'yi al.
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId != _conversationId) {
      setState(() => _conversationId = activeId);
    }
    _scrollToBottom();
    _composerFocus.requestFocus();
  }

  Future<void> _acceptSuggestion(
    AssistantShoppingSuggestion s,
    String householdId,
  ) async {
    try {
      await ref
          .read(shoppingRepositoryProvider)
          .addItem(
            householdId,
            customName: s.name,
            quantity: s.quantity ?? 1,
            unit: s.unit ?? 'piece',
            source: 'manual',
          );
      ref.invalidate(shoppingListProvider(householdId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${s.name} listene eklendi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    }
  }

  Future<void> _saveGuide(AssistantMessage message) async {
    setState(() => _savingGuideFor.add(message.id));
    try {
      await ref
          .read(conversationChatProvider(_conversationId).notifier)
          .saveGuideAsRecipe(message.id, householdId: widget.initialHouseholdId);
      if (mounted) {
        setState(() {
          _savingGuideFor.remove(message.id);
          _savedGuideFor.add(message.id);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tarife kaydedildi')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingGuideFor.remove(message.id));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationChatProvider(_conversationId));
    final cs = Theme.of(context).colorScheme;
    final mode = state.conversation?.mode ??
        (widget.initialHouseholdId != null ? 'food' : 'general');
    final householdId = state.conversation?.householdId ?? widget.initialHouseholdId;

    if (!_seedSent && widget.seedPrompt != null && !state.loading) {
      _seedSent = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _send(widget.seedPrompt!),
      );
    }

    ref.listen(
      conversationChatProvider(_conversationId),
      (_, _) => _scrollToBottom(),
    );

    // 402 (misafir/kota dolu) geldiğinde metin hatası yerine paywall göster.
    ref.listen(conversationChatProvider(_conversationId), (previous, next) {
      final info = next.planLimitInfo;
      if (info == null) return;
      final notifier =
          ref.read(conversationChatProvider(_conversationId).notifier);
      notifier.dismissPlanLimitInfo();
      final controllerAsync = ref.read(paywallControllerProvider);
      controllerAsync.whenData((controller) {
        controller.maybeShow(
          context,
          trigger: PaywallTrigger.quotaExceeded,
          info: info,
        );
      });
    });

    return Scaffold(
      // endDrawer (sağdan açılır) — solda drawer varsa Flutter'ın AppBar
      // otomatik leading mantığı hamburger ikonunu geri okunun önüne
      // koyabiliyor, bu ekran her zaman push ile açıldığı için geri oku
      // garanti solda kalsın diye çekmece sağa alındı, geri butonu da
      // açıkça leading'e yazıldı (otomatik algılamaya bırakılmadı).
      endDrawer: ConversationDrawer(
        activeConversationId: _conversationId,
        onSelect: (id) => setState(() {
          _conversationId = id;
          ref.read(activeConversationIdProvider.notifier).state = id;
        }),
        onNew: () => setState(() {
          _conversationId = null;
          ref.read(activeConversationIdProvider.notifier).state = null;
        }),
      ),
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('AI Asistan'),
        actions: [
          if (_conversationId != null)
            IconButton(
              tooltip: 'Yeni sohbet',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: () => setState(() {
                _conversationId = null;
                ref.read(activeConversationIdProvider.notifier).state = null;
              }),
            ),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Sohbet geçmişi',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (householdId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: QuotaUpsellBanner(feature: 'chef'),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ModeChips(
                mode: mode,
                onChanged: (newMode) {
                  if (_conversationId != null) {
                    ref
                        .read(conversationChatProvider(_conversationId).notifier)
                        .changeMode(newMode);
                  }
                },
              ),
            ),
          ),
          if (state.error != null)
            Container(
              width: double.infinity,
              color: cs.errorContainer,
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                state.error!,
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          Expanded(
            child: state.loading
                ? const Center(child: AppProgress())
                : state.messages.isEmpty
                ? _EmptyAssistant(onQuick: _send, prompts: _quickPrompts)
                : ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.messages.length + (state.sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.messages.length) {
                        return const _TypingBubble();
                      }
                      final message = state.messages[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!message.isUser && message.modeMismatch != null)
                            ModeMismatchBanner(
                              mismatchMode: message.modeMismatch!,
                              onSwitch: () {
                                if (_conversationId != null) {
                                  ref
                                      .read(conversationChatProvider(_conversationId)
                                          .notifier)
                                      .changeMode(message.modeMismatch!);
                                }
                              },
                            ),
                          _MessageBubble(message: message),
                          if (!message.isUser && message.guide != null)
                            GuideCard(
                              guide: message.guide!,
                              saving: _savingGuideFor.contains(message.id),
                              saved: _savedGuideFor.contains(message.id),
                              onSave: () => _saveGuide(message),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          if (state.pendingSuggestions.isNotEmpty && householdId != null)
            _SuggestionBar(
              suggestions: state.pendingSuggestions,
              onAccept: (s) => _acceptSuggestion(s, householdId),
              onDismiss: () => ref
                  .read(conversationChatProvider(_conversationId).notifier)
                  .dismissSuggestions(),
            ),
          _Composer(
            controller: _controller,
            focusNode: _composerFocus,
            sending: state.sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: SelectableText(
          message.content,
          style: TextStyle(color: isUser ? cs.onPrimary : cs.onSurface),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              3,
              (_) => SizedBox(
                width: 8,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionBar extends StatelessWidget {
  const _SuggestionBar({
    required this.suggestions,
    required this.onAccept,
    required this.onDismiss,
  });

  final List<AssistantShoppingSuggestion> suggestions;
  final void Function(AssistantShoppingSuggestion) onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      color: cs.secondaryContainer.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_shopping_cart_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Listene eklemek ister misin?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(AppIcons.close(context), size: 18),
                onPressed: onDismiss,
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              for (final s in suggestions)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(
                    s.quantity != null
                        ? '${s.name} (${_qty(s.quantity!)} ${s.unit ?? ''})'
                              .trim()
                        : s.name,
                  ),
                  onPressed: () => onAccept(s),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final void Function(String) onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Bir şey sor...',
                  isDense: true,
                ),
                onSubmitted: sending ? null : onSend,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: sending ? null : () => onSend(controller.text),
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: AppProgress(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAssistant extends StatelessWidget {
  const _EmptyAssistant({required this.onQuick, required this.prompts});
  final void Function(String) onQuick;
  final List<String> prompts;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.auto_awesome_rounded, size: 48, color: cs.primary),
        const SizedBox(height: AppSpacing.sm),
        Text('AI Asistan', textAlign: TextAlign.center, style: tt.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Yemek, tamir/bakım ya da genel bir soru — ne istersen sorabilirsin. '
          'Bir alana bağlıysan envanterini de biliyorum.',
          textAlign: TextAlign.center,
          style: tt.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final p in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton(
              onPressed: () => onQuick(p),
              child: Align(alignment: Alignment.centerLeft, child: Text(p)),
            ),
          ),
      ],
    );
  }
}
