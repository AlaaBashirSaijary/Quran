import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/app_extension.dart';
import 'search.dart';

/// Tafsir of one ayah, or of consecutive ayahs explained together.
class TafsirEntry {
  const TafsirEntry(this.surah, this.from, this.to, this.text);

  final int surah;
  final int from;
  final int to;
  final String text;

  bool covers(int surah, int ayah) =>
      surah == this.surah && ayah >= from && ayah <= to;
}

class Tafsir {
  Tafsir._(this._bySurah);

  static Tafsir? _cached;

  /// Al-Tafsir al-Muyassar, bundled in assets/tafsir_muyassar.json as, for
  /// each surah, a list of [first ayah, last ayah, text].
  static Future<Tafsir> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final file = await rootBundle.loadString(
      'assets/tafsir_muyassar.json',
      cache: false,
    );
    final data = jsonDecode(file) as List;
    return _cached = Tafsir._([
      for (var s = 0; s < data.length; s++)
        [
          for (final g in data[s] as List)
            TafsirEntry(
              s + 1,
              g[0] as int,
              g[1] as int,
              expandLigatures(g[2] as String),
            ),
        ],
    ]);
  }

  final List<List<TafsirEntry>> _bySurah;

  List<TafsirEntry> ofSurah(int surah) => _bySurah[surah - 1];

  TafsirEntry of(int surah, int ayah) =>
      _bySurah[surah - 1].firstWhere((e) => e.covers(surah, ayah));

  /// The tafsir entries for [ayahs], each once, with the ayahs it covers.
  List<(TafsirEntry, List<Ayah>)> forAyahs(List<Ayah> ayahs) {
    final result = <(TafsirEntry, List<Ayah>)>[];
    for (final ayah in ayahs) {
      final entry = of(ayah.surah, ayah.number);
      if (result.isNotEmpty && identical(result.last.$1, entry)) {
        result.last.$2.add(ayah);
      } else {
        result.add((entry, [ayah]));
      }
    }
    return result;
  }
}
