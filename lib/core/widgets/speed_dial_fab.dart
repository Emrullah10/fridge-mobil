import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import '../haptics.dart';
import '../theme/app_theme.dart';

/// Bir speed-dial öğesi: ana FAB açılınca yay üzerinde beliren, etiketli
/// ikincil bir aksiyon.
class SpeedDialAction {
  const SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.heroTag,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Object? heroTag;
}

/// Ana FAB'a basınca öğelerin yay (fan) biçiminde açıldığı FAB menüsü.
///
/// `flutter_expandable_fab` paketini sarar — yay geometrisi, açılış
/// animasyonu, overlay ve iOS/Android davranışı paketten gelir; burada
/// yalnızca uygulamanın tema tokenlarına (AppRadius/colorScheme) ve coach
/// tour ihtiyacına (programatik açma, overlay'i bastırma) bağlanır.
///
/// Kullanan Scaffold'un `floatingActionButtonLocation: ExpandableFab.location`
/// vermesi ŞARTTIR (paketin gereksinimi).
class SpeedDialFab extends StatefulWidget {
  const SpeedDialFab({
    super.key,
    required this.actions,
    required this.icon,
    this.heroTag,
    this.fabKey,
  });

  /// Kullanan Scaffold'un `floatingActionButtonLocation` olarak vermesi
  /// gereken konum (paketin gereksinimi). Paket tipini ekranlara
  /// sızdırmamak için buradan yeniden sunuluyor.
  static final FloatingActionButtonLocation location = ExpandableFab.location;

  final List<SpeedDialAction> actions;
  final IconData icon;
  final Object? heroTag;

  /// Ana (tetikleyici) FAB'ın GlobalKey'i — coach tour bunu hedefleyebilsin
  /// diye dışarıdan verilir.
  final GlobalKey? fabKey;

  @override
  State<SpeedDialFab> createState() => SpeedDialFabState();
}

class SpeedDialFabState extends State<SpeedDialFab> {
  final _fabKey = GlobalKey<ExpandableFabState>();

  // Coach tour menüyü 1. adımda otomatik açtığında turun kendi %72
  // karartması zaten var — paketin overlay'ini geçici olarak kapatıyoruz ki
  // iki katman üst üste binmesin (bkz. open(suppressBarrier)).
  bool _suppressOverlay = false;

  bool get isOpen => _fabKey.currentState?.isOpen ?? false;

  /// Coach tour gibi dış çağıranlar menüyü programatik açıp kapatabilir.
  /// [suppressBarrier] true ise bu açılışta overlay (karartma) gösterilmez.
  void open({bool suppressBarrier = false}) {
    if (isOpen) return;
    if (suppressBarrier && !_suppressOverlay) {
      // Overlay'i kapatmak için önce yeniden build et, sonra aç — aksi halde
      // paket o karenin overlay'ini zaten göstermiş olur.
      setState(() => _suppressOverlay = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppHaptics.selection();
        _fabKey.currentState?.toggle();
      });
      return;
    }
    AppHaptics.selection();
    _fabKey.currentState?.toggle();
  }

  void close() {
    if (isOpen) {
      _fabKey.currentState?.toggle();
    }
    if (_suppressOverlay && mounted) {
      setState(() => _suppressOverlay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExpandableFab(
      key: _fabKey,
      type: ExpandableFabType.fan,
      fanAngle: 70,
      distance: 112,
      duration: const Duration(milliseconds: 260),
      // Etiketli satırlar kendi içinde hizalı dursun diye çocukların
      // dönme animasyonu kapalı — sadece yay üzerinde konumlanırlar.
      childrenAnimation: ExpandableFabAnimation.none,
      overlayStyle: _suppressOverlay
          ? null
          : ExpandableFabOverlayStyle(
              color: scheme.scrim.withValues(alpha: 0.45),
            ),
      openButtonBuilder: FloatingActionButtonBuilder(
        size: 56,
        builder: (context, onPressed, progress) => FloatingActionButton(
          key: widget.fabKey,
          heroTag: widget.heroTag,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          onPressed: onPressed,
          child: Icon(widget.icon),
        ),
      ),
      closeButtonBuilder: FloatingActionButtonBuilder(
        size: 56,
        builder: (context, onPressed, progress) => FloatingActionButton(
          heroTag: null,
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          onPressed: onPressed,
          child: const Icon(Icons.close_rounded),
        ),
      ),
      children: [
        for (final action in widget.actions)
          _SpeedDialItem(
            action: action,
            onTap: () => _fabKey.currentState?.toggle(),
          ),
      ],
    );
  }
}

/// Etiket (hap) + yuvarlak buton. Etiket solda, buton sağda — yay sol-yukarı
/// açıldığı için etiketler ekran içinde kalır.
class _SpeedDialItem extends StatelessWidget {
  const _SpeedDialItem({required this.action, required this.onTap});

  final SpeedDialAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    void handleTap() {
      onTap();
      action.onPressed();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: handleTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                action.label,
                style: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FloatingActionButton.small(
          heroTag: action.heroTag,
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          elevation: 2,
          onPressed: handleTap,
          child: Icon(action.icon),
        ),
      ],
    );
  }
}
