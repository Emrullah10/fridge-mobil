import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/adaptive.dart';

/// Tek barkod okutur ve okunan kodu (String) geri döndürür. Ürün çözümü
/// (katalog / Open Food Facts) çağıran ekranda yapılır.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere(
          (v) => v != null && v.trim().isNotEmpty,
          orElse: () => null,
        );
    if (code == null) return;
    _handled = true;
    Navigator.of(context).pop(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barkod Okut'),
        actions: [
          IconButton(
            tooltip: 'Fener',
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Kamerayı değiştir',
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // Kamera izni reddedilince (ya da cihazda kamera yoksa)
            // errorBuilder verilmezse mobile_scanner varsayılanı devreye
            // girer: sessiz siyah ekran, açıklama yok, çıkış yolu yok.
            errorBuilder: (context, error) => _ScannerError(
              error: error,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
          // Basit hedef çerçevesi.
          Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          ),
          Positioned(
            bottom: AppSpacing.xl,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Text(
              'Ürünün barkodunu çerçeveye hizala',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                backgroundColor: Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kamera izni reddedildiğinde veya cihaz taramayı desteklemediğinde
/// gösterilen dolgu ekranı. Tam "Ayarlar'a git" yönlendirmesi
/// `permission_handler` bağımlılığı gerektirir (bkz. plan Faz E1); bu
/// turda kullanıcının en azından NEDEN çalışmadığını anlayıp ekrandan
/// çıkabilmesi sağlanıyor — sessiz siyah ekran yerine.
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error, required this.onClose});

  final MobileScannerException error;
  final VoidCallback onClose;

  String _message(BuildContext context) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return isCupertino(context)
            ? 'Kamera izni verilmedi. Ayarlar > Elde yolundan kamera iznini aç.'
            : 'Kamera izni verilmedi. Ayarlar > Uygulamalar > Elde yolundan kamera iznini aç.';
      case MobileScannerErrorCode.unsupported:
        return 'Bu cihazda barkod tarama desteklenmiyor.';
      default:
        return 'Kamera açılamadı: ${error.errorCode.message}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_rounded,
                color: Colors.white70,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _message(context),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: onClose,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                child: const Text('Kapat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
