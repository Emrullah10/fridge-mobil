import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_date_picker.dart';
import '../../../core/ui/app_progress.dart';
import '../../../core/ui/app_sheet.dart';
import '../../household/application/household_providers.dart';

class TransferResult {
  const TransferResult({required this.storageLocationId, this.expiresAt});
  final String storageLocationId;
  final DateTime? expiresAt;
}

/// "Dolaba Aktar" öncesi hedef bölüm seçtiren sheet. Household'un
/// bölümlerini listeler, varsayılan olarak ilk 'fridge' kind'li bölümü
/// önceden seçer.
Future<TransferResult?> showTransferSheet(
  BuildContext context, {
  required String householdId,
}) {
  return showAppSheet<TransferResult>(
    context,
    builder: (_, __) => _TransferSheet(householdId: householdId),
  );
}

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet({required this.householdId});
  final String householdId;

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  String? _selectedLocationId;
  DateTime? _expiresAt;

  void _confirm() {
    if (_selectedLocationId == null) return;
    Navigator.of(context).pop(
      TransferResult(
        storageLocationId: _selectedLocationId!,
        expiresAt: _expiresAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(
      storageLocationsProvider(widget.householdId),
    );

    return AppSheetScaffold(
      title: 'Dolaba Aktar',
      subtitle: 'İşaretli ürünler hangi bölüme eklensin?',
      onClose: () => Navigator.of(context).pop(),
      onConfirm: _selectedLocationId == null ? null : _confirm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          locationsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: AppProgress(),
              ),
            ),
            error: (_, __) => const Text('Bölümler yüklenemedi'),
            data: (locations) {
              _selectedLocationId ??=
                  locations
                      .where((l) => l.kind == 'fridge')
                      .map((l) => l.id)
                      .firstOrNull ??
                  locations.firstOrNull?.id;

              return Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final location in locations)
                    ChoiceChip(
                      label: Text(location.name),
                      selected: _selectedLocationId == location.id,
                      onSelected: (_) =>
                          setState(() => _selectedLocationId = location.id),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showAppDatePicker(
                context,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              if (picked != null) setState(() => _expiresAt = picked);
            },
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(
              _expiresAt == null
                  ? 'Son kullanma tarihi ekle (opsiyonel)'
                  : '${_expiresAt!.day}.${_expiresAt!.month}.${_expiresAt!.year}',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedLocationId == null ? null : _confirm,
              child: const Text('Dolaba Aktar'),
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
