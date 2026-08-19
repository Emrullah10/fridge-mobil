import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/button_progress.dart';
import '../../../core/widgets/form_error_text.dart';
import '../../../core/widgets/responsive.dart';
import '../application/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _errorMessage = describeApiError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: SafeArea(
        child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: formMaxWidth),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Ad Soyad', prefixIcon: Icon(Icons.person_outline)),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Ad gerekli' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.mail_outline)),
                  validator: (value) =>
                      (value == null || !value.contains('@')) ? 'Geçerli bir e-posta girin' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      tooltip: _obscurePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) =>
                      (value == null || value.length < 8) ? 'En az 8 karakter' : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  FormErrorText(_errorMessage!),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting ? const ButtonProgress() : const Text('Kayıt Ol'),
                ),
              ],
            ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
