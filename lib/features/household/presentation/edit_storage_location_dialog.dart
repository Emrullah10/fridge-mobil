import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/widgets/storage_kind.dart';
import '../data/household_repository.dart';

/// "Yeni Bölüm" / "Bölümü Düzenle" sheet'inin sonucu: isim + tür + ikon.
class StorageLocationFormResult {
  const StorageLocationFormResult({
    required this.name,
    required this.kind,
    this.icon,
  });

  final String name;
  final String kind;
  final String? icon;
}

/// Bölüm ekleme/düzenleme sheet'i — isim, tür seçimi (Buzdolabı/Depo/Mutfak
/// Dolabı/...) ve serbest ikon seçimi. `existing` verilirse "düzenle" modu.
///
/// AlertDialog DEĞİL sheet: isim + 2 ChoiceChip grubu bir dialog sınırına
/// sıkışmıyordu (SingleChildScrollView ile zorlanıyordu).
Future<StorageLocationFormResult?> showStorageLocationFormDialog(
  BuildContext context, {
  StorageLocation? existing,
}) {
  return showAppSheet<StorageLocationFormResult>(
    context,
    builder: (_, __) => _StorageLocationFormSheet(existing: existing),
  );
}

class _StorageLocationFormSheet extends StatefulWidget {
  const _StorageLocationFormSheet({this.existing});

  final StorageLocation? existing;

  @override
  State<_StorageLocationFormSheet> createState() =>
      _StorageLocationFormSheetState();
}

class _StorageLocationFormSheetState extends State<_StorageLocationFormSheet> {
  late final TextEditingController _controller;
  late String _selectedKind;
  String? _selectedIcon;
  String? _nameError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.name ?? '');
    _selectedKind = widget.existing?.kind ?? storageKindOptions.first.kind;
    _selectedIcon = widget.existing?.icon;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _controller.text.trim();
    // BUG (2026-09-08 düzeltildi): eskiden onay butonu
    // `controller.text.trim().isEmpty ? null : confirm` ile disabled
    // ediliyordu ve controller'a listener yoktu — kullanıcı isim yazınca
    // buton rebuild olmadığı için "Yeni Bölüm" oluşturmak, kullanıcı bir
    // tür/ikon çipine dokunup dolaylı rebuild tetiklemediği sürece, KALICI
    // OLARAK MÜMKÜN DEĞİLDİ. create_household_dialog.dart'taki doğru kalıba
    // (buton hep aktif, boşsa inline hata) geçildi.
    if (name.isEmpty) {
      setState(() => _nameError = 'Bir isim girin');
      return;
    }
    Navigator.pop(
      context,
      StorageLocationFormResult(
        name: name,
        kind: _selectedKind,
        icon: _selectedIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetScaffold(
      title: _isEdit ? 'Bölümü Düzenle' : 'Yeni Bölüm',
      onClose: () => Navigator.pop(context),
      onConfirm: _confirm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Örn. Mutfak Dolabı, Depo, Kutu 1',
              errorText: _nameError,
            ),
            autofocus: !_isEdit,
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
            child: Text('Tür', style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in storageKindOptions)
                ChoiceChip(
                  selected: _selectedKind == option.kind,
                  onSelected: (_) =>
                      setState(() => _selectedKind = option.kind),
                  avatar: Icon(option.icon, size: 18),
                  label: Text(option.label),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'İkon (opsiyonel — boş bırakılırsa türün ikonu kullanılır)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final iconData in storageIconChoices)
                ChoiceChip(
                  selected: iconKeyForIcon(iconData) == _selectedIcon,
                  onSelected: (selected) => setState(
                    () => _selectedIcon = selected
                        ? iconKeyForIcon(iconData)
                        : null,
                  ),
                  label: Icon(iconData, size: 18),
                ),
            ],
          ),
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
