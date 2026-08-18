import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Fiş işleme (Ollama) tek satır tahmininde bile 30-100sn sürebiliyor —
/// kullanıcıyı bu süre boyunca ekranda kilitlemek yerine tarama ekranından
/// hemen çıkılıyor ve işlem burada, widget ömründen bağımsız devam ediyor.
/// Household başına en fazla bir bekleyen tarama tutulur; ev ekranı bunu
/// izleyip hazır/başarısız olduğunda banner gösterir.
class PendingReceiptScanNotifier extends StateNotifier<PendingReceiptScan?> {
  PendingReceiptScanNotifier(this._repo, this._householdId) : super(null);

  final ReceiptRepository _repo;
  final String _householdId;

  Future<void> start(String scanId) async {
    state = PendingReceiptScan(
      scanId: scanId,
      status: PendingScanStatus.processing,
    );
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final result = await _repo.getScan(_householdId, scanId);
        if (result.status == 'review_pending') {
          state = PendingReceiptScan(
            scanId: scanId,
            status: PendingScanStatus.ready,
            result: result,
          );
          return;
        }
        if (result.status == 'failed') {
          state = PendingReceiptScan(
            scanId: scanId,
            status: PendingScanStatus.failed,
          );
          return;
        }
      } catch (_) {
        // Geçici ağ hatası — bir sonraki denemede düzelebilir, sessizce devam.
      }
      await Future.delayed(const Duration(milliseconds: 750));
    }
    state = PendingReceiptScan(
      scanId: scanId,
      status: PendingScanStatus.failed,
    );
  }

  void clear() => state = null;
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
