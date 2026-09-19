import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/haptics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/button_progress.dart';
import '../../../core/widgets/form_error_text.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/application/auth_providers.dart';
import '../application/household_providers.dart';

/// Davet kodu 12 haneli hex — backend household-invite.repository.js'te
/// üretiliyor, 4'erli gruplu gösteriliyor ("a3f9 c1d0 e2b7").
const _codeLength = 12;

/// "Kod ile Katıl" tam ekranı — eski generic `showSingleFieldDialog`
/// çağrısının ve deep-link `_confirmJoin` dialogunun (main.dart) yerine
/// geçer. İki giriş yolu (FAB / deep link) artık tek ekranda birleşiyor.
///
/// [initialCode] deep link'ten geldiyse kutular dolu açılır ama OTOMATİK
/// GÖNDERİLMEZ — kullanıcı görüp "Katıl"a basmalı.
class JoinHouseholdScreen extends ConsumerStatefulWidget {
  const JoinHouseholdScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinHouseholdScreen> createState() =>
      _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends ConsumerState<JoinHouseholdScreen> {
  late final TextEditingController _codeController;
  final _focusNode = FocusNode();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
    // Deep link/pano kaynaklı kod zaten temiz gelmeyebilir (boşluklu/büyük
    // harfli olabilir) — formatter'ın uyguladığı temizliği burada da uygula.
    _codeController.value = _CodeInputFormatter.clean(_codeController.value);
    if (widget.initialCode == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryFillFromClipboard();
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Panoda görüntülemedeki 4'erli gruplu koda ("a3f9 c1d0 e2b7") benzer bir
  // metin varsa otomatik doldur — otomatik GÖNDERMEZ, kullanıcı görüp
  // onaylasın.
  static final _codeLikePattern = RegExp(
    r'^[a-f0-9\s]{12,17}$',
    caseSensitive: false,
  );

  Future<void> _tryFillFromClipboard() async {
    if (!mounted || _codeController.text.isNotEmpty) return;
    try {
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboard?.text?.trim();
      if (text != null && _codeLikePattern.hasMatch(text) && mounted) {
        setState(() {
          _codeController.value = _CodeInputFormatter.clean(
            TextEditingValue(text: text),
          );
        });
      }
    } catch (_) {
      // Pano erişimi başarısız olsa da ekran çalışmaya devam etsin.
    }
  }

  Future<void> _submit() async {
    final code = _codeController.text;
    if (code.length != _codeLength || _isSubmitting) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(householdRepositoryProvider).acceptInvite(code);
      ref.invalidate(householdsProvider);
      AppHaptics.success();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      AppHaptics.destructive();
      if (mounted) setState(() => _error = describeApiError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Login/register akışı ortasında deep link ile açılmışsa ve oturum
    // unauthenticated'e dönerse (ör. kullanıcı geri gidip çıkış yaptı) bu
    // ekran stack'te asılı kalmasın.
    ref.listen(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated && mounted) {
        Navigator.of(context).maybePop();
      }
    });

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Kod ile Katıl')),
      body: SafeArea(
        child: AppFormScroll(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.logo),
                  ),
                  child: Icon(
                    Icons.group_add_rounded,
                    size: 36,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Davet kodunu gir',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sana gönderilen 12 haneli kodu yaz ya da yapıştır.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),
              _CodeGroupInput(
                controller: _codeController,
                focusNode: _focusNode,
                enabled: !_isSubmitting,
                hasError: _error != null,
                onChanged: () {
                  if (_error != null) setState(() => _error = null);
                },
                onCompleted: _submit,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                FormErrorText(_error!),
              ],
              const SizedBox(height: AppSpacing.lg),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _codeController,
                builder: (context, value, _) {
                  final isComplete = value.text.length == _codeLength;
                  return FilledButton(
                    onPressed: isComplete && !_isSubmitting ? _submit : null,
                    child: _isSubmitting
                        ? const ButtonProgress()
                        : const Text('Katıl'),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: _isSubmitting ? null : _tryFillFromClipboard,
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('Panodan yapıştır'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yapıştırılan/yazılan metni 12 haneli küçük harf hex koda temizler —
/// boşluk/tire otomatik düşer, hex-dışı karakter kabul edilmez.
class _CodeInputFormatter extends TextInputFormatter {
  const _CodeInputFormatter();

  static TextEditingValue clean(TextEditingValue value) {
    final cleaned = value.text.toLowerCase().replaceAll(
      RegExp(r'[^a-f0-9]'),
      '',
    );
    final truncated = cleaned.length > _codeLength
        ? cleaned.substring(0, _codeLength)
        : cleaned;
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
    );
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return clean(newValue);
  }
}

/// 12 haneli davet kodu için segment giriş: tek görünmez `TextField` +
/// altında 3 grup × 4 kutu çizim. 12 ayrı controller KULLANMIYORUZ —
/// otomatik ilerleme/geri silme/yapıştırma davranışlarının üçü birden
/// "gerçek" bir metin alanının doğal davranışından bedava geliyor; bunları
/// 12 controller arasında elle senkronlamak klasik bir hata kaynağı olurdu.
class _CodeGroupInput extends StatelessWidget {
  const _CodeGroupInput({
    required this.controller,
    required this.focusNode,
    required this.onCompleted,
    required this.onChanged,
    this.enabled = true,
    this.hasError = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onCompleted;
  final VoidCallback onChanged;
  final bool enabled;
  final bool hasError;

  static const _groupSizes = [4, 4, 4];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => focusNode.requestFocus() : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gerçek giriş — görünmez ama işlevsel; yapıştırma, sistem
          // otomatik doldurma ve fiziksel klavye buradan geçer.
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 1,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: false,
                showCursor: false,
                keyboardType: TextInputType.visiblePassword,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: const [_CodeInputFormatter()],
                onChanged: (value) {
                  onChanged();
                  if (value.length == _codeLength) onCompleted();
                },
                decoration: const InputDecoration.collapsed(hintText: ''),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final boxSize =
                  ((constraints.maxWidth - 2 * AppSpacing.md) / _codeLength)
                      .clamp(24.0, 36.0);
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final text = value.text;
                  final activeIndex = focusNode.hasFocus
                      ? text.length.clamp(0, _codeLength - 1)
                      : -1;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var g = 0; g < _groupSizes.length; g++) ...[
                        if (g > 0) SizedBox(width: AppSpacing.md),
                        for (var i = 0; i < _groupSizes[g]; i++)
                          _CodeBox(
                            index: g * 4 + i,
                            char: (g * 4 + i) < text.length
                                ? text[g * 4 + i]
                                : '',
                            isActive: (g * 4 + i) == activeIndex,
                            hasError: hasError,
                            size: boxSize,
                          ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.index,
    required this.char,
    required this.isActive,
    required this.hasError,
    required this.size,
  });

  final int index;
  final String char;
  final bool isActive;
  final bool hasError;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = hasError
        ? colorScheme.error
        : isActive
        ? colorScheme.primary
        : Colors.transparent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
      ),
      child: Text(
        char,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
