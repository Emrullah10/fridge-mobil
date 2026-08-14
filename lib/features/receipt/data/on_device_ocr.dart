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

  void dispose() => _recognizer.close();
}
