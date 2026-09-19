import 'package:flutter/material.dart';

import '../../../core/ui/app_action_sheet.dart';
import '../../household/data/household_repository.dart';

/// Sohbetin alanını değiştir/kaldır (bkz. plan §D1). null döndürürse
/// "alansız"a geçirilir, iptal edilirse cancelled marker döner.
const _cancelledMarker = '__cancelled__';

Future<String?> showAreaPickerSheet(
  BuildContext context, {
  required List<Household> households,
  String? currentHouseholdId,
}) async {
  final result = await showAppActionSheet<String>(
    context,
    title: 'Sohbetin alanı',
    actions: [
      const AppSheetAction(
        value: '',
        label: 'Alansız (envanter görünmez)',
        icon: Icons.public,
      ),
      for (final h in households)
        AppSheetAction(
          value: h.id,
          label: h.name,
          icon: Icons.home_rounded,
        ),
    ],
  );

  if (result == null) return _cancelledMarker;
  return result.isEmpty ? null : result;
}
