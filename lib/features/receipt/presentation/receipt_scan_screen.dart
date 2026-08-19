import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../application/receipt_providers.dart';
import '../data/on_device_ocr.dart';
import '../data/receipt_stitcher.dart';

enum _ScanStep { idle, capturing, extractingText, uploading }

class _CapturedPart {
  _CapturedPart({required this.imagePath, required this.lines});
  final String imagePath;
  final List<String> lines;
}

class ReceiptScanScreen extends ConsumerStatefulWidget {
  const ReceiptScanScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends ConsumerState<ReceiptScanScreen> {
  final _picker = ImagePicker();
  final _ocr = OnDeviceOcr();
  final _parts = <_CapturedPart>[];
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

  Future<void> _capturePart(ImageSource source) async {
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
      final lines = await _ocr.extractLines(photo.path);

      if (lines.isEmpty) {
        setState(() {
          _step = _ScanStep.idle;
          _errorMessage = 'Fişte metin bulunamadı. Daha net bir fotoğraf dene.';
        });
        return;
      }

      setState(() {
        _parts.add(_CapturedPart(imagePath: photo.path, lines: lines));
        _step = _ScanStep.idle;
      });
    } on PlatformException catch (error) {
      setState(() {
        _step = _ScanStep.idle;
        _errorMessage = error.code == 'camera_access_denied'
            ? 'Kamera izni verilmedi. Fişi taramak için Ayarlar > Uygulamalar > Fridge yolundan kamera iznini aç.'
            : 'Bir şeyler ters gitti: ${error.message ?? error.code}';
      });
    } catch (error) {
      setState(() {
        _step = _ScanStep.idle;
        _errorMessage = 'Bir şeyler ters gitti: $error';
      });
    }
  }

  void _removePart(int index) {
    setState(() => _parts.removeAt(index));
  }

  Future<void> _finish() async {
    if (_parts.isEmpty) return;

    final stitched = stitchPages(_parts.map((p) => p.lines).toList());

    if (!stitched.overlapFound && _parts.length > 1) {
      final proceed = await _confirmNoOverlap();
      if (proceed != true) return;
    }

    final rawText = stitched.lines.join('\n');

    setState(() {
      _errorMessage = null;
      _step = _ScanStep.uploading;
    });

    try {
      final scanId = await ref
          .read(receiptRepositoryProvider)
          .uploadScanText(widget.householdId, rawText);

      // Asıl işleme (Gemini) uzun sürebiliyor — kullanıcıyı burada
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

  Future<bool?> _confirmNoOverlap() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Örtüşme bulunamadı'),
        content: const Text(
          'Parçalar arasında örtüşme bulunamadı, listede tekrar eden ürünler olabilir. '
          'Yine de devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Geri dön'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yine de gönder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _step != _ScanStep.idle;
    final hasParts = _parts.isNotEmpty;
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
                    Text(
                      hasParts ? 'Fiş Tara' : 'Fişi Tara',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      hasParts
                          ? 'Fiş uzunsa bir sonraki parçayı, öncekinin son birkaç satırı görünecek şekilde çek.'
                          : 'Fişi düz bir zemine koy ve net bir fotoğraf çek.\nÜrünler otomatik olarak okunacak.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    if (hasParts) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _PartsStrip(parts: _parts, onRemove: _removePart),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: () => _capturePart(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(hasParts ? 'Parça Ekle' : 'Fotoğraf Çek'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => _capturePart(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeriden Seç'),
                    ),
                    if (hasParts) ...[
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        onPressed: _finish,
                        icon: const Icon(Icons.check_rounded),
                        label: Text('Bitti (${_parts.length} parça)'),
                      ),
                    ],
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

class _PartsStrip extends StatelessWidget {
  const _PartsStrip({required this.parts, required this.onRemove});

  final List<_CapturedPart> parts;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: parts.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.input),
                child: Image.file(
                  File(parts[index].imagePath),
                  width: 72,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, size: 16, color: colorScheme.onError),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
