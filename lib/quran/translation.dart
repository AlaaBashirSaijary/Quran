import 'dart:convert';

import 'package:flutter/services.dart';

/// The Saheeh International English translation of the meanings of the
/// Quran (tanzil.net), bundled in assets/translation_en.json.
class Translation {
  Translation._(this._surahs)
    : _lower = [
        for (final s in _surahs) [for (final a in s) a.toLowerCase()],
      ];

  static Future<Translation>? _loading;
  static Translation? _instance;

  static Translation? get loaded => _instance;

  static Future<Translation> load() => _loading ??= () async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/translation_en.json'))
            as Map<String, dynamic>;
    return _instance = Translation._([
      for (final s in json['surahs'] as List) (s as List).cast<String>(),
    ]);
  }();

  final List<List<String>> _surahs;
  final List<List<String>> _lower;

  String of(int surah, int ayah) => _surahs[surah - 1][ayah - 1];

  /// Ayahs whose translation has a word starting with each word of
  /// [query], ignoring case: up to [limit] of them, and how many in all.
  (List<(int, int)>, int) search(String query, {int limit = 100}) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 2)
        .toList();
    if (words.isEmpty) return (const [], 0);
    final patterns = [for (final w in words) RegExp('\\b${RegExp.escape(w)}')];
    final found = <(int, int)>[];
    var total = 0;
    for (var s = 0; s < _lower.length; s++) {
      for (var a = 0; a < _lower[s].length; a++) {
        if (patterns.every((p) => p.hasMatch(_lower[s][a]))) {
          total++;
          if (found.length < limit) found.add((s + 1, a + 1));
        }
      }
    }
    return (found, total);
  }
}
