import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_icons.dart';
import '../../../core/ui/app_text_form_field.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/button_progress.dart';
import '../../../core/widgets/form_error_text.dart';
import '../../../core/widgets/responsive.dart';
import '../application/auth_providers.dart';
import 'widgets/auth_hero_header.dart';

/// Misafir hesabını kalıcı hesaba yükseltir — alan/envanter/fiş hiç
/// taşınmaz (aynı user_id, sunucu tarafında AYNI satır UPDATE edilir).
/// register_screen.dart ile aynı form deseni, farkı: mevcut misafir adını
/// başlangıç değeri olarak dolduruyor ve navigasyon sonrası _AuthGate
/// otomatik olarak HouseholdListScreen'e düşüyor (guest -> authenticated
/// geçişinde ekran değişmiyor, sadece üst şeritteki misafir uyarısı kalkar).
class UpgradeAccountScreen extends ConsumerStatefulWidget {
  const UpgradeAccountScreen({super.key});

  @override
  ConsumerState<UpgradeAccountScreen> createState() =>
      _UpgradeAccountScreenState();
}

class _UpgradeAccountScreenState extends ConsumerState<UpgradeAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // create-guest-user.use-case.js varsayılan adı hep 'Misafir' yazar —
    // kullanıcının gerçek adı olmadığı için ön doldurmaya değmez.
    final currentName = ref.read(authControllerProvider).user?.displayName;
    if (currentName != null && currentName != 'Misafir') {
      _nameController.text = currentName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .upgradeAccount(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
          );
      TextInput.finishAutofillContext();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hesabın kalıcı hale geldi — verilerin korundu'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      setState(() => _errorMessage = describeApiError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hesabını Kalıcı Yap')),
      body: SafeArea(
        child: AppFormScroll(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  const AuthHeroHeader(
                    subtitle:
                        'Verilerin yerinde kalır — sadece giriş bilgisi ekliyorsun',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.10),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.25),
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Alanların, envanterin ve fiş geçmişin aynen kalır — sadece bir e-posta ve şifre ekliyorsun.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextFormField(
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => Validators.required(value, 'Ad'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextFormField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(AppIcons.mail(context)),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _isSubmitting ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: Icon(AppIcons.lock(context)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? AppIcons.eye(context)
                              : AppIcons.eyeOff(context),
                        ),
                        tooltip: _obscurePassword
                            ? 'Şifreyi göster'
                            : 'Şifreyi gizle',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: Validators.newPassword,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    FormErrorText(_errorMessage!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const ButtonProgress()
                        : const Text('Hesabı Kalıcı Yap'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
