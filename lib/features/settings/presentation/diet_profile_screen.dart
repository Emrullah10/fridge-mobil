import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_number_field.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/auth_repository.dart';

/// Kişisel diyet & alerjen profili. Tarif önerisi ve AI Chef bu kısıtlara
/// uyar (çakışan tarifleri eler). Profil kullanıcıya aittir — birden fazla
/// alanda aynı kısıt geçerli olur.
class DietProfileScreen extends ConsumerStatefulWidget {
  const DietProfileScreen({super.key});

  @override
  ConsumerState<DietProfileScreen> createState() => _DietProfileScreenState();
}

class _DietProfileScreenState extends ConsumerState<DietProfileScreen> {
  static const _diets = <(String, String)>[
    ('none', 'Kısıt yok'),
    ('vegetarian', 'Vejetaryen'),
    ('vegan', 'Vegan'),
    ('pescatarian', 'Peskataryen'),
    ('halal', 'Helal'),
    ('glutenfree', 'Glutensiz'),
    ('lactosefree', 'Laktozsuz'),
  ];

  late String _diet;
  late List<String> _allergens;
  final _allergenController = TextEditingController();
  final _kcalController = TextEditingController();
  final _kcalFocus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p =
        ref.read(authControllerProvider).user?.dietProfile ??
        const DietProfile();
    _diet = p.diet;
    _allergens = [...p.allergens];
    if (p.dailyKcalTarget != null)
      _kcalController.text = p.dailyKcalTarget.toString();
  }

  @override
  void dispose() {
    _allergenController.dispose();
    _kcalController.dispose();
    _kcalFocus.dispose();
    super.dispose();
  }

  void _addAllergen() {
    final v = _allergenController.text.trim();
    if (v.isEmpty) return;
    if (!_allergens.any((a) => a.toLowerCase() == v.toLowerCase())) {
      setState(() => _allergens.add(v));
    }
    _allergenController.clear();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final kcal = Validators.parseDecimal(_kcalController.text)?.round();
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            displayName: ref.read(authControllerProvider).user!.displayName,
            dietProfile: DietProfile(
              allergens: _allergens,
              diet: _diet,
              dailyKcalTarget: kcal != null && kcal > 0 ? kcal : null,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profil kaydedildi')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Diyet & Alerjenler')),
      // Önceki çıplak ListView'de `viewInsets` payı yoktu — kalori alanı
      // ve hemen altındaki Kaydet butonu klavye açılınca klavyenin
      // arkasında kalıyordu. AppFormScroll (login/register ile aynı
      // desen) hem bunu hem de boş-yere-kaydırınca-kapat davranışını
      // veriyor.
      body: AppFormScroll(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tarif önerileri ve AI Chef bu bilgilere göre malzeme seçer.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Beslenme tercihi', style: tt.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final (key, label) in _diets)
                  ChoiceChip(
                    label: Text(label),
                    selected: _diet == key,
                    onSelected: (_) => setState(() => _diet = key),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Alerjenler / kaçınılan malzemeler', style: tt.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _allergenController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'örn. fındık, süt, deniz ürünleri',
                    ),
                    onSubmitted: (_) => _addAllergen(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filledTonal(
                  onPressed: _addAllergen,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final a in _allergens)
                  InputChip(
                    label: Text(a),
                    onDeleted: () => setState(() => _allergens.remove(a)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Günlük kalori hedefi (opsiyonel)', style: tt.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            AppNumberField(
              controller: _kcalController,
              focusNode: _kcalFocus,
              decimal: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saving ? null : _save(),
              decoration: const InputDecoration(
                hintText: 'örn. 2000',
                suffixText: 'kcal',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
