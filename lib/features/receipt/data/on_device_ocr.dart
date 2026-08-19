import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Telefonda ML Kit ile fiş fotoğrafından ham metin çıkarır. Bedava, offline,
/// saniyeler içinde çalışır. Backend'e sadece metin gider — foto trafiği yok.
class OnDeviceOcr {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);
    return result.text;
  }

  /// Satırları y koordinatına (boundingBox.top) göre sıralı döndürür.
  /// Çok parçalı fiş çekiminde örtüşme tespiti satır hizasına dayanır —
  /// ML Kit'in blok sırası okuma sırasını garanti etmediği için `result.text`
  /// yerine bloklar/satırlar tek tek toplanıp y'ye göre yeniden dizilir.
  Future<List<String>> extractLines(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);
    final lines = result.blocks.expand((block) => block.lines).toList()
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    return lines.map((line) => line.text.trim()).where((text) => text.isNotEmpty).toList();
  }

  void dispose() => _recognizer.close();
}
