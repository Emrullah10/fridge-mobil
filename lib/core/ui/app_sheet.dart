import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tüm modal bottom sheet'ler için tek giriş noktası. `isScrollControlled`,
/// `useSafeArea`, drag handle, üst radius — tek yerde tutulur ki 6 sheet'in
/// hepsi birden aynı kabuğu paylaşsın. Sheet İÇERİKLERİ (paywall, ürün
/// arama, alışveriş kalemi vb.) bu fonksiyonun dışında, kendi dosyalarında
/// kalır — burada değişen yalnızca çağrı parametreleridir.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool useRootNavigator = false,
  // `DraggableScrollableSheet` kullanan içerikler (ör. product_picker_sheet)
  // kendi sürükleme algılayıcısını taşır — global drag handle ile çakışır,
  // o çağrılarda false ver.
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    useSafeArea: true,
    showDragHandle: showDragHandle,
    builder: builder,
  );
}

/// Sheet içeriği için ortak kabuk: başlık + opsiyonel alt açıklama + kapat
/// düğmesi + `viewInsets` (klavye) padding. `transfer_sheet`'in bugünkü
/// başlık hiyerarşisi (titleMedium + alt açıklama bodySmall) buradan gelir.
class AppSheetScaffold extends StatelessWidget {
  const AppSheetScaffold({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  ?trailing,
                ],
              ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle!, style: textTheme.bodySmall),
            ],
            if (title != null || subtitle != null)
              const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
