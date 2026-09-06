import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_providers.dart';
import '../../../core/widgets/single_field_dialog.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/upgrade_account_screen.dart';
import '../../billing/application/entitlements_providers.dart';
import '../../billing/presentation/widgets/premium_status_card.dart';
import '../../notification/application/notification_providers.dart';
import '../../onboarding/application/onboarding_providers.dart';
import 'diet_profile_screen.dart';

/// backend notification-types.js NOTIFICATION_TYPES ile birebir aynı
/// anahtarlar. Tercih satırı yoksa varsayılan açık (bkz. backend
/// notification-preference.repository.js filterEnabledUserIds).
const _notificationTypeLabels = {
  'member_joined': 'Birisi alana katıldığında',
  'item_expiring': 'Son kullanma tarihi yaklaştığında',
  'receipt_processed': 'Fiş işlendiğinde',
  'item_consumed': 'Bir ürün tüketildiğinde',
};

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final Map<String, bool> _pushEnabledByType = {
    for (final type in _notificationTypeLabels.keys) type: true,
  };
  bool _preferencesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await ref.read(notificationRepositoryProvider).listPreferences();
      if (!mounted) return;
      setState(() {
        for (final preference in preferences) {
          _pushEnabledByType[preference.type] = preference.pushEnabled;
        }
        _preferencesLoaded = true;
      });
    } catch (_) {
      // Sessizce varsayılan (hepsi açık) ile devam et — ayarlar ekranının
      // açılmasını bir ağ hatasına bağımlı kılmaya değmez.
      if (mounted) setState(() => _preferencesLoaded = true);
    }
  }

  Future<void> _togglePreference(String type, bool value) async {
    setState(() => _pushEnabledByType[type] = value);
    try {
      await ref.read(notificationRepositoryProvider).updatePreference(type, pushEnabled: value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _pushEnabledByType[type] = !value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
    }
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref, String currentName) async {
    final newName = await showSingleFieldDialog(
      context,
      title: 'Adını düzenle',
      hintText: 'Ad Soyad',
      confirmLabel: 'Kaydet',
      initialText: currentName,
    );
    if (newName == null || newName.trim().isEmpty || !context.mounted) return;

    try {
      await ref.read(authControllerProvider.notifier).updateProfile(displayName: newName.trim());
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final currentPassword = await showSingleFieldDialog(
      context,
      title: 'Mevcut şifren',
      hintText: 'Mevcut şifre',
      confirmLabel: 'Devam et',
      obscureText: true,
    );
    if (currentPassword == null || currentPassword.isEmpty || !context.mounted) return;

    final newPassword = await showSingleFieldDialog(
      context,
      title: 'Yeni şifre',
      hintText: 'Yeni şifre (en az 8 karakter)',
      confirmLabel: 'Şifreyi değiştir',
      obscureText: true,
    );
    if (newPassword == null || newPassword.isEmpty || !context.mounted) return;

    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifren güncellendi')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    // Misafirde çıkış = veri kaybı (hesap sentetik email/şifre taşıyor,
    // bir daha bu cihazdan bile geri dönülemez — deviceId eşleşmesi login
    // ekranından geçmez). Uyarı normal çıkıştan belirgin şekilde farklı.
    final isGuest = ref.read(authControllerProvider).isGuest;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Çıkış yap'),
        content: Text(
          isGuest
              ? 'Misafir hesabındasın. Çıkış yaparsan alanların, envanterin ve '
                'fiş geçmişin GERİ ALINAMAZ şekilde kaybolur. Önce hesabını '
                'kalıcı yapmanı öneririz.'
              : 'Hesabından çıkış yapmak istediğine emin misin?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
          FilledButton(
            style: isGuest ? FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error) : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isGuest ? 'Yine de çık' : 'Çıkış yap'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    // Aktif Premium/deneme abonesiyse hesap silmenin aboneliği İPTAL
    // ETMEDİĞİNİ ayrıca vurgula — aksi halde kullanıcı hesabını silip
    // Google Play üzerinden ücretlendirilmeye devam edebilir (plan §Faz 6).
    final entitlements = ref.read(entitlementsProvider);
    final hasActiveSubscription = entitlements.isPremium || entitlements.isTrial;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hesabını sil'),
        content: Text(
          hasActiveSubscription
              ? 'Bu işlem geri alınamaz. Hesabın ve yalnızca senin sahibi olduğun '
                'alanlardaki tüm envanter/fiş verisi kalıcı olarak silinir. '
                'Paylaşımlı alanlarda sahiplik başka bir üyeye devredilir.\n\n'
                'DİKKAT: Aktif bir aboneliğin var. Hesabını silmek aboneliğini '
                'iptal ETMEZ — Google Play üzerinden ödeme almaya devam edilebilir. '
                'Önce Ayarlar → Abonelik → Aboneliği Yönet / İptal Et yolundan '
                'aboneliğini iptal etmeni öneririz.'
              : 'Bu işlem geri alınamaz. Hesabın ve yalnızca senin sahibi olduğun '
                'alanlardaki tüm envanter/fiş verisi kalıcı olarak silinir. '
                'Paylaşımlı alanlarda sahiplik başka bir üyeye devredilir.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    final password = await showSingleFieldDialog(
      context,
      title: 'Şifreni doğrula',
      contentText: 'Silme işlemini onaylamak için şifreni gir.',
      hintText: 'Şifre',
      confirmLabel: 'Hesabı sil',
      obscureText: true,
    );
    if (password == null || password.isEmpty || !context.mounted) return;

    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(password: password);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(authControllerProvider).user;

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
          if (user != null) ...[
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                    style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(user.displayName, style: textTheme.titleSmall),
                subtitle: Text(user.email),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _editProfile(context, ref, user.displayName),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Misafire de gösterilir (bkz. premium_status_card.dart) — eski
            // "Abonelik" satırı HESAP bölümünde sadece kayıtlı kullanıcıya
            // görünüyordu, misafir modunda premium hiç görünmüyordu.
            const PremiumStatusCard(),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: ListTile(
                leading: const Icon(Icons.restaurant_menu_rounded),
                title: const Text('Diyet & Alerjenler'),
                subtitle: Text(
                  (user.dietProfile == null || user.dietProfile!.isEmpty)
                      ? 'Tarif önerileri için ayarla'
                      : [
                          if (user.dietProfile!.diet != 'none') user.dietProfile!.diet,
                          if (user.dietProfile!.allergens.isNotEmpty)
                            '${user.dietProfile!.allergens.length} alerjen',
                        ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DietProfileScreen()),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
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
              'BİLDİRİMLER',
              style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant, letterSpacing: 0.3),
            ),
          ),
          Card(
            child: _preferencesLoaded
                ? Column(
                    children: [
                      for (final entry in _notificationTypeLabels.entries) ...[
                        SwitchListTile(
                          title: Text(entry.value),
                          value: _pushEnabledByType[entry.key] ?? true,
                          onChanged: (value) => _togglePreference(entry.key, value),
                        ),
                        if (entry.key != _notificationTypeLabels.keys.last) const Divider(height: 1),
                      ],
                    ],
                  )
                : const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
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
            child: Column(
              children: [
                if (user?.isGuest ?? false) ...[
                  ListTile(
                    leading: Icon(Icons.person_add_alt_1_rounded, color: colorScheme.primary),
                    title: Text('Hesabını kalıcı yap', style: TextStyle(color: colorScheme.primary)),
                    subtitle: const Text('Verilerini kaybetmemek için e-posta/şifre ekle'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UpgradeAccountScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                ],
                if (!(user?.isGuest ?? false)) ...[
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Şifreyi değiştir'),
                    onTap: () => _changePassword(context, ref),
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: colorScheme.error),
                  title: Text('Çıkış yap', style: TextStyle(color: colorScheme.error)),
                  onTap: () => _confirmLogout(context, ref),
                ),
                if (!(user?.isGuest ?? false)) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.delete_forever_rounded, color: colorScheme.error),
                    title: Text('Hesabımı sil', style: TextStyle(color: colorScheme.error)),
                    onTap: () => _confirmDeleteAccount(context, ref),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: const Text('Tanıtımı tekrar göster'),
              onTap: () {
                ref.read(onboardingSeenProvider.notifier).reset();
                ref.read(premiumIntroSeenProvider.notifier).reset();
                for (final id in CoachTourId.values) {
                  ref.read(tourSeenProvider(id).notifier).reset();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ekranları tekrar gezdiğinde tanıtımlar yeniden gösterilecek')),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(
              'HAKKINDA',
              style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant, letterSpacing: 0.3),
            ),
          ),
          Card(
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '—';
                final buildNumber = snapshot.data?.buildNumber;
                return ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Sürüm'),
                  trailing: Text(
                    buildNumber != null ? '$version ($buildNumber)' : version,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
