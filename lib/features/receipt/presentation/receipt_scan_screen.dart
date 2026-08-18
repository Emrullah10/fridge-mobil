import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../application/receipt_providers.dart';
import '../data/on_device_ocr.dart';

enum _ScanStep { idle, capturing, extractingText, uploading }

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

      // Asıl işleme (Ollama) 30-100sn sürebiliyor — kullanıcıyı burada
      // bekletmek yerine hemen çıkıyoruz. `start` fire-and-forget: widget
      // kapansa bile provider household'a bağlı olduğu için devam eder, ev
      // ekranı sonucu banner ile gösterir (bkz. household_home_screen.dart).
      if (!mounted) return;
      ref
          .read(pendingReceiptScanProvider(widget.householdId).notifier)
          .start(scanId);
      Navigator.of(context).pop();
    } catch (error) {
      setState(() {
        _step = _ScanStep.idle;
        _errorMessage = 'Bir şeyler ters gitti: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _step != _ScanStep.idle;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Fiş Tara')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: formMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isBusy) ...[
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _stepLabel(_step),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ] else ...[
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          size: 48,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Fişi Tara', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Fişi düz bir zemine koy ve net bir fotoğraf çek.\nÜrünler otomatik olarak okunacak.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: () => _scanReceipt(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Fotoğraf Çek'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => _scanReceipt(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeriden Seç'),
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
        ),
      ),
    );
  }
}
