import 'package:flutter/services.dart';

import 'quran.dart';

class Ayah {
  const Ayah({
    required this.surah,
    required this.number,
    required this.page,
    required this.text,
  });

  final int surah;
  final int number;
  final int page;

  /// Uthmani text, as printed in the mushaf.
  final String text;
}

class SearchResults {
  const SearchResults(this.surahs, this.ayahs, this.totalAyahs);

  final List<int> surahs;
  final List<Ayah> ayahs;

  /// Number of matching ayahs, which can be more than [ayahs] holds.
  final int totalAyahs;

  bool get isEmpty => surahs.isEmpty && ayahs.isEmpty;
}

final _marks = RegExp('[\u0610-\u061A\u064B-\u065F\u06D6-\u06E4\u06E8-\u06ED\u0640]');
final _alefs = RegExp('[\u0621\u0622\u0623\u0625\u0627\u0671]');
final _spaces = RegExp(r'\s+');

/// Reduces Arabic text to a bare form so that what people type matches the
/// Uthmani script: no diacritics, no alefs (Uthmani often writes them as a
/// small dagger alef or leaves them out, and hamza seats vary) and no spaces (Uthmani joins some
/// words that are written apart today, e.g. يَٰٓأَيُّهَا).
String normalizeArabic(String text) {
  return text
      .replaceAll(_marks, '')
      // Waw carrying a dagger alef is read as alef: ٱلصَّلَوٰةَ is الصلاة
      .replaceAll('\u0648\u0670', '')
      .replaceAll('\u0670', '')
      .replaceAll('\u06E5', '') // small waw: لَهُۥ
      .replaceAll(RegExp('[\u06E6\u06E7]'), '\u064A') // small yeh: إِبۡرَٰهِـۧمَ
      .replaceAll(_alefs, '')
      .replaceAll('\u0649', '\u064A') // ى -> ي
      .replaceAll('\u0629', '\u0647') // ة -> ه
      .replaceAll('\u0624', '\u0648') // ؤ -> و
      .replaceAll('\u0626', '\u064A') // ئ -> ي
      .replaceAll(_spaces, '');
}

class QuranSearch {
  QuranSearch._(this._ayahs, this._normalized);

  static Future<QuranSearch>? _instance;

  /// Loads the Quran text once and reuses it.
  static Future<QuranSearch> load() {
    return _instance ??= _load();
  }

  static Future<QuranSearch> _load() async {
    final file = await rootBundle.loadString('assets/quran_text.txt');
    final ayahs = <Ayah>[];
    for (final line in file.split('\n')) {
      if (line.isEmpty) continue;
      final parts = line.split('|');
      ayahs.add(Ayah(
        surah: int.parse(parts[0]),
        number: int.parse(parts[1]),
        page: int.parse(parts[2]),
        text: parts[3],
      ));
    }
    return QuranSearch._(ayahs, [for (final ayah in ayahs) _Words(ayah.text)]);
  }

  final List<Ayah> _ayahs;
  final List<_Words> _normalized;

  SearchResults search(String query, {int limit = 100}) {
    final needle = normalizeArabic(query);
    if (needle.length < 2) return const SearchResults([], [], 0);

    final surahs = [
      for (var surah = 1; surah <= 114; surah++)
        if (normalizeArabic(getSurahNameArabic(surah)).contains(needle)) surah,
    ];

    final ayahs = <Ayah>[];
    var total = 0;
    for (var i = 0; i < _ayahs.length; i++) {
      if (_normalized[i].matches(needle)) {
        total++;
        if (ayahs.length < limit) ayahs.add(_ayahs[i]);
      }
    }
    return SearchResults(surahs, ayahs, total);
  }
}

/// An ayah's normalized text, remembering where each word starts so that a
/// match can't begin in the middle of a word (once spaces are dropped,
/// نَسۡلُكُهُۥ فِي would otherwise contain الكهف).
class _Words {
  _Words(String text) {
    final buffer = StringBuffer();
    for (final word in text.split(_spaces)) {
      final normalized = normalizeArabic(word);
      if (normalized.isEmpty) continue;
      _starts.add(buffer.length);
      buffer.write(normalized);
    }
    _text = buffer.toString();
  }

  late final String _text;
  final _starts = <int>{};

  bool matches(String needle) {
    var index = _text.indexOf(needle);
    while (index != -1) {
      if (_starts.contains(index)) return true;
      index = _text.indexOf(needle, index + 1);
    }
    return false;
  }
}
