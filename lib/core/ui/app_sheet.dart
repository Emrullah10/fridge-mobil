import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';

/// Tüm modal bottom sheet'ler için tek giriş noktası. `isScrollControlled`,
/// `useSafeArea`, drag handle, üst radius — tek yerde tutulur ki sheet'lerin
/// hepsi birden aynı kabuğu paylaşsın. Sheet İÇERİKLERİ (paywall, ürün
/// arama, alışveriş kalemi vb.) bu fonksiyonun dışında, kendi dosyalarında
/// kalır — burada değişen yalnızca çağrı parametreleridir.
///
/// [draggable] `true` ise (arama/liste gibi uzun içerikli sheet'ler)
/// `DraggableScrollableSheet` bu fonksiyon tarafından kurulur ve
/// `builder`'a bir `ScrollController` verilir — eskiden her sheet kendi
/// `DraggableScrollableSheet`'ini kurup global tutamacı kapatmak zorunda
/// kalıyordu (`showDragHandle: false`), artık tek sahip burası olduğu için
/// tutamaç her zaman açık kalabilir.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget Function(
    BuildContext context,
    ScrollController? scrollController,
  )
  builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool useRootNavigator = false,
  bool draggable = false,
  double initialSize = 0.85,
  double minSize = 0.5,
  double maxSize = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      if (!draggable) return builder(context, null);
      return DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: minSize,
        maxChildSize: maxSize,
        expand: false,
        builder: (context, scrollController) =>
            builder(context, scrollController),
      );
    },
  );
}

/// Sheet içeriği için ortak kabuk: sürükleme tutamacının altında sabit bir
/// başlık barı — solda kapat (✕), ortada başlık, sağda opsiyonel onay (✓).
/// Kullanıcı gerçek cihazda tur atarken 9 sheet'in 8'inde kapatma butonu
/// olmadığını, üstte "cancel gibi bir şey" eksik olduğunu bildirdi — bu
/// bar artık her sheet'te aynı, tek yerden geliyor.
///
/// [onConfirm] verilmezse sağ taraf boş bırakılır (başlık ortalı kalır,
/// düzen zıplamaz) — çoğu sheet'te onay zaten içerikteki tam genişlikli
/// ana buton (`Ekle`, `Kaydet`) üstleniyor, bu durumda ✓ o butonun ikizi
/// olarak eklenir.
class AppSheetScaffold extends StatelessWidget {
  const AppSheetScaffold({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.onClose,
    this.onConfirm,
    this.confirmEnabled = true,
    this.scrollController,
    this.padding,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  /// Varsayılan `Navigator.pop(context)`. `null` verirsen ✕ hiç çizilmez
  /// (ör. gösterim amaçlı, kapatılamayan bir sheet için) — ama bu istisnai
  /// olmalı, kullanıcı her sheet'in kapatılabilir olmasını bekliyor.
  final VoidCallback? onClose;
  final VoidCallback? onConfirm;
  final bool confirmEnabled;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasHeader = title != null || subtitle != null;

    Widget body = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child],
      ),
    );

    body = scrollController == null
        ? SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: body,
          )
        : SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: body,
          );

    if (!hasHeader && onClose == null && onConfirm == null) return body;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            0,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: onClose == null
                    ? null
                    : IconButton(
                        tooltip: 'Kapat',
                        icon: Icon(AppIcons.close(context)),
                        onPressed: onClose,
                      ),
              ),
              Expanded(
                child: Column(
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                child: onConfirm == null
                    ? null
                    : IconButton(
                        tooltip: 'Onayla',
                        icon: Icon(AppIcons.check(context)),
                        onPressed: confirmEnabled ? onConfirm : null,
                      ),
              ),
            ],
          ),
        ),
        Flexible(child: body),
      ],
    );
  }
}
