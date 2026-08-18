import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_providers.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../auth/application/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Çıkış yap'),
        content: const Text('Hesabından çıkış yapmak istediğine emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Çıkış yap')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.fabBottomPadding,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(
              'GÖRÜNÜM',
              style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant, letterSpacing: 0.3),
            ),
          ),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: themeMode,
              onChanged: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode!),
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: Text('Sistem'),
                    subtitle: Text('Cihaz temasını takip et'),
                    secondary: Icon(Icons.brightness_auto_rounded),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: Text('Aydınlık'),
                    secondary: Icon(Icons.light_mode_rounded),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: Text('Karanlık'),
                    secondary: Icon(Icons.dark_mode_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(
              'HESAP',
              style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant, letterSpacing: 0.3),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: colorScheme.error),
              title: Text('Çıkış yap', style: TextStyle(color: colorScheme.error)),
              onTap: () => _confirmLogout(context, ref),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentTab: AppBottomTab.settings),
    );
  }
}
