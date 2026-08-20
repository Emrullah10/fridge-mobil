import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/application/auth_providers.dart';
import '../data/receipt_repository.dart';

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  return ReceiptRepository(ref.watch(apiClientProvider));
});

enum PendingScanStatus { processing, ready, failed }

class PendingReceiptScan {
  const PendingReceiptScan({
    required this.scanId,
    required this.status,
    this.result,
  });
  final String scanId;
  final PendingScanStatus status;
  final ReceiptScanResult? result;
}

String _prefsKey(String householdId) => 'pending_scan_id:$householdId';

/// Fiş işleme (Gemini API) tek satır tahmininde bile 30-100sn sürebiliyor —
/// kullanıcıyı bu süre boyunca ekranda kilitlemek yerine tarama ekranından
/// hemen çıkılıyor ve işlem burada, widget ömründen bağımsız devam ediyor.
/// Household başına en fazla bir bekleyen tarama tutulur; ev ekranı bunu
/// izleyip hazır/başarısız olduğunda banner gösterir.
///
/// ÖNEMLİ: sabit bir zaman aşımı YOK — backend'in kendi süresi ne kadar
/// sürerse sürsün burada bekleniyor. Eskiden 90sn'lik sabit bir sınır vardı;
/// backend işlemi 90sn'den uzun sürdüğünde (yorumun kendisi 30-100sn diyordu)
/// mobil taraf sonucu "başarısız" sayıyordu — oysa backend'de tarama başarıyla
/// 'review_pending' olmuş oluyordu ve kullanıcı ona bir daha asla erişemiyordu
/// (fiş geçmişi ekranı yoktu). Bkz. .wolf/buglog.json bug-XXX.
///
/// scanId, uygulama arka planda öldürülse bile kaybolmasın diye
/// SharedPreferences'a yazılır; ev ekranı açıldığında `restore()` ile geri
/// yüklenip polling kaldığı yerden devam eder.
class PendingReceiptScanNotifier extends StateNotifier<PendingReceiptScan?> {
  PendingReceiptScanNotifier(this._repo, this._householdId) : super(null) {
    _restore();
  }

  final ReceiptRepository _repo;
  final String _householdId;
  bool _polling = false;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final scanId = prefs.getString(_prefsKey(_householdId));
    if (scanId != null) {
      start(scanId, persist: false);
    }
  }

  Future<void> start(String scanId, {bool persist = true}) async {
    if (_polling) return;
    _polling = true;
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey(_householdId), scanId);
    }
    state = PendingReceiptScan(
      scanId: scanId,
      status: PendingScanStatus.processing,
    );
    // Kademeli aralık: ilk denemeler sık (backend genelde birkaç saniyede
    // biter), sonra seyrekleşir — hem hızlı yanıt hem daha az istek.
    var delayMs = 1000;
    while (true) {
      try {
        final result = await _repo.getScan(_householdId, scanId);
        if (result.status == 'review_pending' || result.status == 'completed') {
          state = PendingReceiptScan(
            scanId: scanId,
            status: PendingScanStatus.ready,
            result: result,
          );
          _polling = false;
          return;
        }
        if (result.status == 'failed') {
          state = PendingReceiptScan(
            scanId: scanId,
            status: PendingScanStatus.failed,
          );
          await _forgetPersisted();
          _polling = false;
          return;
        }
      } catch (_) {
        // Geçici ağ hatası — bir sonraki denemede düzelebilir, sessizce devam.
      }
      await Future.delayed(Duration(milliseconds: delayMs));
      delayMs = delayMs >= 3000 ? 3000 : delayMs + 500;
    }
  }

  Future<void> _forgetPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(_householdId));
  }

  // Sonuç gerçekten tüketildiğinde (kullanıcı incelemeyi TAMAMLADIĞINDA)
  // çağrılır — yarım bırakılan bir inceleme banner'ı silmemeli, aksi halde
  // scan review_pending'de asılı kalıp bir daha erişilemez olur.
  void clear() {
    state = null;
    _forgetPersisted();
  }

  // Kullanıcı hazır bildirimini görüp ekrandan çıktığında (henüz tamamlamadan)
  // state'i canlı tutar ama persisted kaydı silmez.
  void dismissWithoutClearing() => state = null;
}

final pendingReceiptScanProvider =
    StateNotifierProvider.family<
      PendingReceiptScanNotifier,
      PendingReceiptScan?,
      String
    >(
      (ref, householdId) => PendingReceiptScanNotifier(
        ref.watch(receiptRepositoryProvider),
        householdId,
      ),
    );
