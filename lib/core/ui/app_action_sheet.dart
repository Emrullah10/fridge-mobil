import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../haptics.dart';
import '../theme/app_theme.dart';
import 'adaptive.dart';

/// `showAppActionSheet` içinde tek bir eylemi tanımlar.
class AppSheetAction<T> {
  const AppSheetAction({
    required this.value,
    required this.label,
    this.icon,
    this.isDestructive = false,
  });

  final T value;
  final String label;

  /// Yalnızca Android (Material) dalında `ListTile.leading` olarak çizilir.
  /// iOS'ta `CupertinoActionSheetAction` ikon slotu yok, HIG'e uyularak
  /// eklenmiyor.
  final IconData? icon;
  final bool isDestructive;
}

/// Bir liste eylemi seçtirmek için tek çağrı noktası — projedeki eski
/// `SimpleDialog` (Material 2 kalıntısı) ve çıplak `showModalBottomSheet` +
/// `ListTile` kopyalarının yerine geçer. iOS'ta `CupertinoActionSheet`,
/// Android'de başlıklı/drag-handle'lı bir `ListTile` sheet'i üretir.
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppSheetAction<T>> actions,
  String cancelLabel = 'Vazgeç',
}) {
  if (isCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: title == null
            ? null
            : Text(title, style: cupertinoDialogTitleStyle(sheetContext)),
        message: message == null
            ? null
            : Text(message, style: cupertinoDialogMessageStyle(sheetContext)),
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: action.isDestructive,
              onPressed: () {
                if (action.isDestructive) AppHaptics.destructive();
                Navigator.pop(sheetContext, action.value);
              },
              child: Text(action.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  0,
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  0,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            for (final action in actions)
              ListTile(
                leading: action.icon == null
                    ? null
                    : Icon(
                        action.icon,
                        color: action.isDestructive
                            ? colorScheme.error
                            : colorScheme.onSurface,
                      ),
                title: Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: action.isDestructive
                      ? TextStyle(color: colorScheme.error)
                      : null,
                ),
                onTap: () {
                  if (action.isDestructive) AppHaptics.destructive();
                  Navigator.pop(sheetContext, action.value);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}
