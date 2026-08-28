import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/button_progress.dart';
import '../../../../core/widgets/form_error_text.dart';
import '../../application/auth_providers.dart';
import '../login_screen.dart';
import '../register_screen.dart';

/// "Denemeye Başla" (misafir modu) / "Giriş Yap" / "Kayıt ol" üçlüsü.
/// Hem açılış tanıtımının son (CTA) sayfası hem de WelcomeScreen bunu
/// kullanır — misafir başlatma mantığı tek yerde dursun diye.
class AuthCtaBlock extends ConsumerStatefulWidget {
  const AuthCtaBlock({super.key});

  @override
  ConsumerState<AuthCtaBlock> createState() => _AuthCtaBlockState();
}

class _AuthCtaBlockState extends ConsumerState<AuthCtaBlock> {
  bool _isStartingGuest = false;
  String? _errorMessage;

  Future<void> _startAsGuest() async {
    setState(() {
      _isStartingGuest = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).continueAsGuest();
      // _AuthGate guest durumuna geçince HouseholdListScreen'e yönlendirir.
    } catch (error) {
      if (mounted) setState(() => _errorMessage = describeApiError(error));
    } finally {
      if (mounted) setState(() => _isStartingGuest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          FormErrorText(_errorMessage!),
          const SizedBox(height: AppSpacing.md),
        ],
        FilledButton(
          onPressed: _isStartingGuest ? null : _startAsGuest,
          child: _isStartingGuest ? const ButtonProgress() : const Text('Denemeye Başla'),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Kayıt olmadan hemen başla — istersen sonra hesabını kalıcı yaparsın',
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          child: const Text('Giriş Yap'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          child: const Text('Hesabın yok mu? Kayıt ol'),
        ),
      ],
    );
  }
}
