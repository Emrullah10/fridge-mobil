/// Çok parçalı fiş çekiminde parçaların OCR satırlarını tek bir listeye
/// birleştirir. Saf Dart — Flutter/ML Kit bağımlılığı yok, birim testi
/// gerçek fotoğraf gerektirmeden çalışır.
library;

/// Birleştirme sonucu: nihai satır listesi + kullanıcıya gösterilecek
/// durum bilgisi.
class StitchResult {
  const StitchResult({
    required this.lines,
    required this.overlapFound,
    required this.duplicatesRemoved,
  });

  final List<String> lines;

  /// Parçalar arasında en az bir örtüşme çapası bulunduysa true. false ise
  /// hiçbir satır silinmemiştir (kayıp yerine fazlalık tercih edilir) ve
  /// UI kullanıcıyı "tekrar eden ürün olabilir" diye uyarmalı.
  final bool overlapFound;

  final int duplicatesRemoved;
}

/// Örtüşme çapası aranırken denenecek en büyük satır sayısı. Fiş başına
/// birkaç fotoğraf ve ~40 satır düşünüldüğünde örtüşme bandı bundan uzun
/// olmaz; üst sınır sonsuz döngü riskini de önler.
const _maxAnchorLines = 12;

/// k>=2 satırlık çapalarda her satırın normalize uzunluğu için minimum
/// eşik. Kısa satırlar (örn. "SUT", "SEK") başka ürünlerle çakışıp yanlış
/// pozitif örtüşme üretebilir — turkish-brands.js'teki aynı derse paralel:
/// kısa string'lerde bulanık/gevşek eşleşme kapalı tutulur.
const _minAnchorLineLength = 5;

/// k=1 (tek satırlık) çapalarda gereken minimum normalize uzunluk. Tek
/// satırlık örtüşme riskli — fişte "EKMEK" gibi kısa, genel bir ürün adı
/// gerçekten iki kez geçebilir. Bu yüzden tek satırlık çapa yalnızca yeterince
/// uzun/özgün satırlarda (çoğunlukla çok kelimeli satırlar) kabul edilir.
const _minSingleAnchorLineLength = 8;

String _normalize(String line) {
  final upper = line.toUpperCase();
  final buffer = StringBuffer();
  for (final rune in upper.runes) {
    final char = String.fromCharCode(rune);
    if (RegExp(r'[A-ZÇĞİÖŞÜ0-9]').hasMatch(char)) {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// İki normalize satırın "aynı" sayılıp sayılmayacağını belirler. OCR aynı
/// satırı iki fotoğrafta birebir aynı okumayabilir (tek harf kayması gibi),
/// bu yüzden tam eşitlik yerine uzunlukla orantılı küçük bir tolerans
/// kullanılır.
bool _linesMatch(String a, String b) {
  if (a == b) return true;
  if (a.isEmpty || b.isEmpty) return false;
  final maxLen = a.length > b.length ? a.length : b.length;
  final maxDistance = maxLen >= 8 ? 2 : 1;
  return _levenshtein(a, b) <= maxDistance;
}

int _levenshtein(String a, String b) {
  final la = a.length;
  final lb = b.length;
  if (la == 0) return lb;
  if (lb == 0) return la;
  var prev = List<int>.generate(lb + 1, (j) => j);
  var curr = List<int>.filled(lb + 1, 0);
  for (var i = 1; i <= la; i++) {
    curr[0] = i;
    for (var j = 1; j <= lb; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((v, e) => v < e ? v : e);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[lb];
}

/// İki ardışık parçanın sınırındaki örtüşmeyi bulur: `prevLines`'ın
/// sonundaki K satırın `nextLines`'ın başındaki K satıra eşit olduğu en
/// büyük K. K yukarıdan aşağı denenir, ilk tutan kazanır. En az 2 satırlık
/// çapa şart — tek satırlık eşleşme kabul edilmez, çünkü fişte aynı ürün
/// adı (örn. "EKMEK") gerçekten iki kez geçebilir ve tek satırlık çapa bu
/// gerçek tekrarı örtüşme sanıp veri siler.
int _findOverlap(List<String> prevLines, List<String> nextLines) {
  final maxK = [
    _maxAnchorLines,
    prevLines.length,
    nextLines.length,
  ].reduce((v, e) => v < e ? v : e);

  for (var k = maxK; k >= 1; k--) {
    final tail = prevLines.sublist(prevLines.length - k);
    final head = nextLines.sublist(0, k);
    final threshold = k == 1 ? _minSingleAnchorLineLength : _minAnchorLineLength;

    var allMatch = true;
    var hasAnchorLine = false;
    for (var i = 0; i < k; i++) {
      final normTail = _normalize(tail[i]);
      final normHead = _normalize(head[i]);
      if (normTail.length >= threshold || normHead.length >= threshold) {
        hasAnchorLine = true;
      }
      if (!_linesMatch(normTail, normHead)) {
        allMatch = false;
        break;
      }
    }
    if (allMatch && hasAnchorLine) return k;
  }
  return 0;
}

/// Birden fazla fotoğraftan gelen satır listelerini tek bir listede
/// birleştirir. Parçalar çekim sırasına göre (fişin üstünden altına)
/// verilmelidir.
StitchResult stitchPages(List<List<String>> pages) {
  final nonEmptyPages = pages.where((p) => p.isNotEmpty).toList();
  if (nonEmptyPages.isEmpty) {
    return const StitchResult(lines: [], overlapFound: false, duplicatesRemoved: 0);
  }
  if (nonEmptyPages.length == 1) {
    return StitchResult(lines: nonEmptyPages.first, overlapFound: false, duplicatesRemoved: 0);
  }

  final result = <String>[...nonEmptyPages.first];
  var overlapFound = false;
  var duplicatesRemoved = 0;

  for (var i = 1; i < nonEmptyPages.length; i++) {
    final prevTail = result;
    final nextPage = nonEmptyPages[i];
    final overlapLen = _findOverlap(prevTail, nextPage);
    if (overlapLen > 0) {
      overlapFound = true;
      duplicatesRemoved += overlapLen;
      result.addAll(nextPage.sublist(overlapLen));
    } else {
      result.addAll(nextPage);
    }
  }

  return StitchResult(lines: result, overlapFound: overlapFound, duplicatesRemoved: duplicatesRemoved);
}
