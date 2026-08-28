import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/onboarding_providers.dart';
import 'coach_tour.dart';

// Aynı anda tek tur. Kullanıcı sekmeler arasında hızlı geçerse (A'nın turu
// settleDelay'i beklerken B build olur) iki overlay üst üste binebilirdi.
bool _tourInFlight = false;

/// Ekranın `build`'i içinden çağrılır — hem `ConsumerWidget` hem
/// `ConsumerStatefulWidget` (ikisinde de `WidgetRef` ortak). Tur bayrağı
/// `false` ise (okundu, görülmedi) bir sonraki frame + kısa bir yerleşme payı
/// sonrası turu açar.
///
/// [settleDelay]: Scaffold'un FAB giriş animasyonu (~200ms) ve ilk veri
/// yüklemesi bitene kadar beklenir — aksi halde tur, hedefi hâlâ hareket
/// hâlindeyken açılır. Canlı rect takibi (coach_tour.dart `_track`) bunu
/// zaten toparlar; gecikme yalnızca ilk kareyi düzgün gösterir.
///
/// Adım listesi boşsa (hepsi hedefsiz optional — ör. yepyeni hesap, veri yok)
/// bayrak SET EDİLMEZ: tur bir sonraki ziyarette tekrar denenir.
void maybeStartCoachTour(
  BuildContext context,
  WidgetRef ref, {
  required CoachTourId id,
  required List<CoachStep> Function() buildSteps,
  Duration settleDelay = const Duration(milliseconds: 400),
}) {
  final seen = ref.watch(tourSeenProvider(id));
  if (seen != false || _tourInFlight) return; // null = prefs okunmadı, true = görüldü
  if (!TickerMode.valuesOf(context).enabled) return; // gizli sekme (IndexedStack) tur açmasın

  _tourInFlight = true;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await Future<void>.delayed(settleDelay);
      if (!context.mounted || !TickerMode.valuesOf(context).enabled) return;
      // Turun üstüne başka bir route açıldıysa (kullanıcı hemen bir detaya
      // girdiyse) turu bu ziyarette açma — bayrak set edilmediği için sonraki
      // girişte tekrar denenir.
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;

      final steps = buildSteps()
          .where((s) => !s.optional || resolveStepRect(s, context) != null)
          .toList();
      if (steps.isEmpty) return; // bayrak SET EDİLMEZ

      ref.read(tourSeenProvider(id).notifier).markSeen();
      await showCoachTour(context, steps: steps, onFinished: () {});
    } finally {
      _tourInFlight = false;
    }
  });
}
