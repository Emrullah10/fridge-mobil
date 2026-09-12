import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/features/insights/application/insights_providers.dart';
import 'package:fridge_mobil/features/insights/presentation/insights_screen.dart';

void main() {
  group('insightsRangeFor', () {
    // BUG (2026-09-12 düzeltildi): "son 90 gün" seçildiğinde eskiden
    // `DateTime.now()` mikrosaniye hassasiyetinde okunuyordu — her çağrı
    // farklı bir `from` üretiyordu, bu da InsightsPeriod kimliğinin her
    // rebuild'de değişmesine ve sonsuz loading'e yol açıyordu. Bu test
    // aynı `now` verildiğinde (veya varsayılan olarak art arda çağrılarda)
    // sonucun DEĞİŞMEDİĞİNİ doğrular — regresyon bir daha sessizce
    // dönmesin diye.
    test('90 gün (case 2) art arda çağrılarda birebir aynı sonucu üretir', () {
      final first = insightsRangeFor(2);
      final second = insightsRangeFor(2);
      final third = insightsRangeFor(2);

      expect(first, equals(second));
      expect(second, equals(third));
    });

    test('90 gün: InsightsPeriod kimliği aynı `now` için stabil kalır', () {
      final now = DateTime.utc(2026, 9, 12, 14, 33, 12, 481);
      final rangeA = insightsRangeFor(2, now: now);
      final rangeB = insightsRangeFor(2, now: now);

      final periodA = InsightsPeriod(
        householdId: 'h1',
        from: rangeA.from,
        to: rangeA.to,
      );
      final periodB = InsightsPeriod(
        householdId: 'h1',
        from: rangeB.from,
        to: rangeB.to,
      );

      // Eskiden bu iki nesne EŞİT DEĞİLDİ (from mikrosaniyeye göre kayardı)
      // — FutureProvider.family her seferinde yeni bir instance açardı.
      expect(periodA, equals(periodB));
      expect(periodA.hashCode, equals(periodB.hashCode));
    });

    test('90 gün: from günün başına yuvarlanır, to bugün + 1 gündür', () {
      final now = DateTime.utc(2026, 9, 12, 23, 59, 59);
      final range = insightsRangeFor(2, now: now);

      expect(range.from, DateTime.utc(2026, 6, 14));
      expect(range.to, DateTime.utc(2026, 9, 13));
    });

    test(
      'bu ay (case 0): from/to null, backend içinde bulunulan ayı kullanır',
      () {
        final range = insightsRangeFor(0, now: DateTime.utc(2026, 9, 12));
        expect(range.from, isNull);
        expect(range.to, isNull);
      },
    );

    test(
      'geçen ay (case 1): sabit takvim ayı sınırları, saate bağlı değişmez',
      () {
        final rangeA = insightsRangeFor(
          1,
          now: DateTime.utc(2026, 9, 12, 1, 0),
        );
        final rangeB = insightsRangeFor(
          1,
          now: DateTime.utc(2026, 9, 12, 23, 0),
        );

        expect(rangeA, equals(rangeB));
        expect(rangeA.from, DateTime.utc(2026, 8, 1));
        expect(rangeA.to, DateTime.utc(2026, 9, 1));
      },
    );
  });
}
