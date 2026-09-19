import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/app_switch.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/widgets/household_kind.dart';
import '../data/household_repository.dart';

/// "Yeni Alan" / "Alanı Düzenle" sheet'inin sonucu: isim + serbest simge +
/// yemek özelliği (yemek yalnızca oluşturma modunda anlamlı).
class HouseholdFormResult {
  const HouseholdFormResult({
    required this.name,
    this.icon,
    required this.foodEnabled,
  });

  final String name;
  final String? icon;
  final bool foodEnabled;
}

/// Alan oluşturma/düzenleme sheet'i. `existing` verilirse "düzenle" modu:
/// başlık "Alanı Düzenle", buton "Kaydet", yemek switch'i gizli (o ayarın
/// tek yeri Alan Özellikleri ekranı). İsim zorunlu — boşsa inline hata,
/// sheet kapanmaz.
///
/// AlertDialog DEĞİL sheet: isim + ikon seçici (Wrap) + switch bir dialog
/// sınırına sıkışmıyordu (SingleChildScrollView ile zorlanıyordu).
Future<HouseholdFormResult?> showHouseholdFormDialog(
  BuildContext context, {
  Household? existing,
}) {
  return showAppSheet<HouseholdFormResult>(
    context,
    builder: (_, __) => _HouseholdFormSheet(existing: existing),
  );
}

class _HouseholdFormSheet extends StatefulWidget {
  const _HouseholdFormSheet({this.existing});

  final Household? existing;

  @override
  State<_HouseholdFormSheet> createState() => _HouseholdFormSheetState();
}

class _HouseholdFormSheetState extends State<_HouseholdFormSheet> {
  late final TextEditingController _controller;
  // Oluşturmada varsayılan seçili simge; düzenlemede mevcut simge (yoksa yine
  // ilk seçenek — "seçimsiz" durumu yok, kart hiç ikonsuz kalmaz).
  late String? _selectedIcon;
  bool _foodEnabled = false;
  String? _nameError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.name ?? '');
    _selectedIcon =
        widget.existing?.icon ??
        householdIconKeyForIcon(householdIconChoices.first);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Bir isim girin');
      return;
    }
    Navigator.pop(
      context,
      HouseholdFormResult(
        name: name,
        icon: _selectedIcon,
        foodEnabled: _foodEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetScaffold(
      title: _isEdit ? 'Alanı Düzenle' : 'Yeni Alan',
      onClose: () => Navigator.pop(context),
      onConfirm: _confirm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Örn. Evimiz, Ofis, Yazlık, Sığınak',
              errorText: _nameError,
            ),
            autofocus: false,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirm(),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Simge', style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final iconData in householdIconChoices)
                ChoiceChip(
                  selected: householdIconKeyForIcon(iconData) == _selectedIcon,
                  onSelected: (_) => setState(
                    () => _selectedIcon = householdIconKeyForIcon(iconData),
                  ),
                  label: Icon(iconData, size: 18),
                ),
            ],
          ),
          if (!_isEdit) ...[
            const SizedBox(height: AppSpacing.md),
            AppSwitchTile(
              value: _foodEnabled,
              onChanged: (value) => setState(() => _foodEnabled = value),
              title: 'Yemek özellikleri',
              subtitle: 'Tarifler, AI Chef, son kullanma tarihi takibi',
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _confirm,
                  child: Text(_isEdit ? 'Kaydet' : 'Oluştur'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
