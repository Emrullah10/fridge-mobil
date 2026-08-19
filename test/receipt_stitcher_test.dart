import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mobil/features/receipt/data/receipt_stitcher.dart';

void main() {
  group('stitchPages', () {
    test('tek parça aynen çıkar (kısa fiş regresyonu)', () {
      final result = stitchPages([
        ['MIGROS', 'EKMEK TAM BUGDAY', 'SUT 1LT', 'TOPLAM: 45,90'],
      ]);

      expect(result.lines, ['MIGROS', 'EKMEK TAM BUGDAY', 'SUT 1LT', 'TOPLAM: 45,90']);
      expect(result.overlapFound, isFalse);
      expect(result.duplicatesRemoved, 0);
    });

    test('temiz örtüşme: tekrar eden satırlar tam olarak bir kez kalır', () {
      final page1 = ['MIGROS TICARET A.S.', 'EKMEK TAM BUGDAY', 'SUT 1LT', 'YOGURT 500G'];
      final page2 = ['SUT 1LT', 'YOGURT 500G', 'PEYNIR 400G', 'TOPLAM: 120,50'];

      final result = stitchPages([page1, page2]);

      expect(result.overlapFound, isTrue);
      expect(result.duplicatesRemoved, 2);
      expect(result.lines, [
        'MIGROS TICARET A.S.',
        'EKMEK TAM BUGDAY',
        'SUT 1LT',
        'YOGURT 500G',
        'PEYNIR 400G',
        'TOPLAM: 120,50',
      ]);
    });

    test('örtüşme yok: hiçbir satır kaybolmaz, overlapFound false', () {
      final page1 = ['MIGROS', 'EKMEK TAM BUGDAY', 'SUT 1LT'];
      final page2 = ['PEYNIR 400G', 'ZEYTIN 250G', 'TOPLAM: 88,00'];

      final result = stitchPages([page1, page2]);

      expect(result.overlapFound, isFalse);
      expect(result.duplicatesRemoved, 0);
      expect(result.lines, [
        'MIGROS',
        'EKMEK TAM BUGDAY',
        'SUT 1LT',
        'PEYNIR 400G',
        'ZEYTIN 250G',
        'TOPLAM: 88,00',
      ]);
    });

    test('OCR gürültüsüyle örtüşme (bir harf farklı) yine yakalanır', () {
      final page1 = ['MIGROS TICARET', 'EKMEK TAM BUGDAY', 'SUT 1LT'];
      // "EKMEK TAM BUGDAY" -> "EKMEK TAM BUGOAY" gibi OCR kaymasını simüle et.
      final page2 = ['EKMEK TAM BUGOAY', 'SUT 1LT', 'YOGURT 500G', 'TOPLAM: 99,00'];

      final result = stitchPages([page1, page2]);

      expect(result.overlapFound, isTrue);
      expect(result.lines, [
        'MIGROS TICARET',
        'EKMEK TAM BUGDAY',
        'SUT 1LT',
        'YOGURT 500G',
        'TOPLAM: 99,00',
      ]);
    });

    test('gerçek tekrar korunur: tek satırlık yanlış çapa örtüşme sanılmaz', () {
      // Aynı üründen 2 adet alınmış, fiş üzerinde "EKMEK" iki kez geçiyor.
      // Bu tek satırlık eşleşme örtüşme çapası olarak KABUL EDİLMEMELİ.
      final page1 = ['MIGROS', 'EKMEK'];
      final page2 = ['EKMEK', 'SUT 1LT', 'TOPLAM: 30,00'];

      final result = stitchPages([page1, page2]);

      expect(result.overlapFound, isFalse);
      expect(result.duplicatesRemoved, 0);
      expect(result.lines, ['MIGROS', 'EKMEK', 'EKMEK', 'SUT 1LT', 'TOPLAM: 30,00']);
    });

    test('üç parça: ardışık örtüşmeler ayrı ayrı bulunur', () {
      final page1 = ['MIGROS', 'EKMEK TAM BUGDAY', 'SUT 1LT'];
      final page2 = ['EKMEK TAM BUGDAY', 'SUT 1LT', 'YOGURT 500G', 'PEYNIR 400G'];
      final page3 = ['YOGURT 500G', 'PEYNIR 400G', 'ZEYTIN 250G', 'TOPLAM: 150,00'];

      final result = stitchPages([page1, page2, page3]);

      expect(result.overlapFound, isTrue);
      expect(result.lines, [
        'MIGROS',
        'EKMEK TAM BUGDAY',
        'SUT 1LT',
        'YOGURT 500G',
        'PEYNIR 400G',
        'ZEYTIN 250G',
        'TOPLAM: 150,00',
      ]);
    });

    test('boş parçalar filtrelenir', () {
      final result = stitchPages([
        ['MIGROS', 'EKMEK TAM BUGDAY'],
        <String>[],
        ['SUT 1LT', 'TOPLAM: 40,00'],
      ]);

      expect(result.lines, ['MIGROS', 'EKMEK TAM BUGDAY', 'SUT 1LT', 'TOPLAM: 40,00']);
    });

    test('tamamen boş girdi', () {
      final result = stitchPages([]);

      expect(result.lines, isEmpty);
      expect(result.overlapFound, isFalse);
    });
  });
}
