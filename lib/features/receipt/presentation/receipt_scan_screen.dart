import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../application/receipt_providers.dart';
import '../data/on_device_ocr.dart';
import '../data/receipt_repository.dart';
import 'receipt_review_screen.dart';

enum _ScanStep { idle, capturing, extractingText, uploading, waitingForResult }

class ReceiptScanScreen extends ConsumerStatefulWidget {
  const ReceiptScanScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends ConsumerState<ReceiptScanScreen> {
  final _picker = ImagePicker();
  final _ocr = OnDeviceOcr();
  _ScanStep _step = _ScanStep.idle;
  String? _errorMessage;

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  String _stepLabel(_ScanStep step) {
    switch (step) {
      case _ScanStep.capturing:
        return 'Fotoğraf seçiliyor...';
      case _ScanStep.extractingText:
        return 'Fiş okunuyor...';
      case _ScanStep.uploading:
        return 'Gönderiliyor...';
      case _ScanStep.waitingForResult:
        return 'Ürünler eşleştiriliyor...';
      case _ScanStep.idle:
        return '';
    }
  }

  Future<void> _scanReceipt(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _step = _ScanStep.capturing;
    });

    try {
      final photo = await _picker.pickImage(source: source, imageQuality: 90);
      if (photo == null) {
        setState(() => _step = _ScanStep.idle);
        return;
      }

      setState(() => _step = _ScanStep.extractingText);
      final rawText = await _ocr.extractText(photo.path);

      if (rawText.trim().isEmpty) {
        setState(() {
          _step = _ScanStep.idle;
          _errorMessage = 'Fişte metin bulunamadı. Daha net bir fotoğraf dene.';
        });
        return;
      }

      setState(() => _step = _ScanStep.uploading);
      final scanId = await ref
          .read(receiptRepositoryProvider)
          .uploadScanText(widget.householdId, rawText);

      setState(() => _step = _ScanStep.waitingForResult);
      final result = await _pollUntilReady(scanId);

      if (!mounted) return;
      setState(() => _step = _ScanStep.idle);

      if (result.status == 'failed') {
        setState(() => _errorMessage = 'Fiş işlenemedi. Tekrar dene.');
        return;
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(
            householdId: widget.householdId,
            scanId: scanId,
            lineItems: result.lineItems,
          ),
        ),
      );
    } catch (error) {
      setState(() {
        _step = _ScanStep.idle;
        _errorMessage = 'Bir şeyler ters gitti: $error';
      });
    }
  }

  /// scan-text hemen 202 dönüyor, gerçek işleme arka plandaki worker'da
  /// oluyor (SCAN_WORKER_INTERVAL_MS=5000 ile alınıyor, sonra Ollama
  /// çağrısı: gemma3:12b modeliyle tek satır tahmini ~55sn sürebiliyor,
  /// bkz. .env OLLAMA_MODEL). Süre duvar-saati bazlı — sabit deneme sayısı
  /// yerine, çünkü model değişince (qwen2.5 -> gemma3:12b) eski 20×500ms=10sn
  /// limiti yetersiz kalıp "zaman aşımı" hatası veriyordu.
  Future<ReceiptScanResult> _pollUntilReady(String scanId) async {
    final repo = ref.read(receiptRepositoryProvider);
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      final result = await repo.getScan(widget.householdId, scanId);
      if (result.status == 'review_pending' || result.status == 'failed') {
        return result;
      }
      await Future.delayed(const Duration(milliseconds: 750));
    }
    throw Exception('Fiş işlenmesi beklenenden uzun sürdü, lütfen tekrar dene');
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _step != _ScanStep.idle;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Fiş Tara')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy) ...[
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(_stepLabel(_step), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ] else ...[
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.receipt_long_rounded, size: 48, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Fişi Tara',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Fişi düz bir zemine koy ve net bir fotoğraf çek.\nÜrünler otomatik olarak okunacak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 240,
                  child: FilledButton.icon(
                    onPressed: () => _scanReceipt(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Fotoğraf Çek'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: 240,
                  child: OutlinedButton.icon(
                    onPressed: () => _scanReceipt(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeriden Seç'),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
