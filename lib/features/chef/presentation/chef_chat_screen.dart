import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../shopping/application/shopping_providers.dart';
import '../application/chef_providers.dart';
import '../data/chef_repository.dart';

/// AI Chef sohbeti. Mutfağı bilen asistan — "SKT'si yaklaşanlarla ne
/// pişirebilirim?" gibi sorulara cevap verir. [seedPrompt] verilirse ekran
/// açılır açılmaz o mesaj otomatik gönderilir (envanter ekranındaki kısayol).
class ChefChatScreen extends ConsumerStatefulWidget {
  const ChefChatScreen({super.key, required this.householdId, this.seedPrompt});

  final String householdId;
  final String? seedPrompt;

  @override
  ConsumerState<ChefChatScreen> createState() => _ChefChatScreenState();
}

class _ChefChatScreenState extends ConsumerState<ChefChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _seedSent = false;

  static const _quickPrompts = [
    'Son kullanma tarihi yaklaşanlarla ne pişirebilirim?',
    'Bu akşam 30 dakikada ne yapabilirim?',
    'Kahvaltıda ne hazırlayabilirim?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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
    await ref.read(chefChatProvider(widget.householdId).notifier).send(text);
    _scrollToBottom();
  }

  Future<void> _acceptSuggestion(ChefShoppingSuggestion s) async {
    try {
      await ref.read(shoppingRepositoryProvider).addItem(
            widget.householdId,
            customName: s.name,
            quantity: s.quantity ?? 1,
            unit: s.unit ?? 'piece',
            source: 'manual',
          );
      ref.invalidate(shoppingListProvider(widget.householdId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.name} listene eklendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chefChatProvider(widget.householdId));
    final cs = Theme.of(context).colorScheme;

    // seedPrompt: geçmiş yüklendikten sonra bir kez otomatik gönder.
    if (!_seedSent && widget.seedPrompt != null && !state.loading) {
      _seedSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(widget.seedPrompt!));
    }

    // Yeni mesaj gelince aşağı kaydır.
    ref.listen(chefChatProvider(widget.householdId), (_, _) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chef'),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: 'Sohbeti temizle',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Sohbeti temizle'),
                    content: const Text('Tüm sohbet geçmişi silinsin mi?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Temizle')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(chefChatProvider(widget.householdId).notifier).clear();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.error != null)
            Container(
              width: double.infinity,
              color: cs.errorContainer,
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(state.error!, style: TextStyle(color: cs.onErrorContainer)),
            ),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? _EmptyChef(onQuick: _send, prompts: _quickPrompts)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: state.messages.length + (state.sending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= state.messages.length) {
                            return const _TypingBubble();
                          }
                          return _MessageBubble(message: state.messages[index]);
                        },
                      ),
          ),
          if (state.pendingSuggestions.isNotEmpty)
            _SuggestionBar(
              suggestions: state.pendingSuggestions,
              onAccept: _acceptSuggestion,
              onDismiss: () => ref.read(chefChatProvider(widget.householdId).notifier).dismissSuggestions(),
            ),
          _Composer(
            controller: _controller,
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
  final ChefMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
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
                  decoration: BoxDecoration(color: cs.onSurfaceVariant, shape: BoxShape.circle),
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
  const _SuggestionBar({required this.suggestions, required this.onAccept, required this.onDismiss});

  final List<ChefShoppingSuggestion> suggestions;
  final void Function(ChefShoppingSuggestion) onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      color: cs.secondaryContainer.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_shopping_cart_rounded, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text('Listene eklemek ister misin?', style: Theme.of(context).textTheme.bodySmall),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
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
                  label: Text(s.quantity != null ? '${s.name} (${_qty(s.quantity!)} ${s.unit ?? ''})'.trim() : s.name),
                  onPressed: () => onAccept(s),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
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
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Mutfağınla ilgili bir şey sor...',
                  isDense: true,
                ),
                onSubmitted: sending ? null : onSend,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: sending ? null : () => onSend(controller.text),
              icon: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChef extends StatelessWidget {
  const _EmptyChef({required this.onQuick, required this.prompts});
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
        Text('AI Chef', textAlign: TextAlign.center, style: tt.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Dolabındakileri, son kullanma tarihi yaklaşanları ve alışveriş listeni biliyorum. '
          'Ne pişireceğini birlikte bulalım.',
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
