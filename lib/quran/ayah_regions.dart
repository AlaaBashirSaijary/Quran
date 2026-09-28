import 'dart:convert';

import 'package:flutter/services.dart';

/// Where each ayah sits on each mushaf page, as fractions of the page, so a
/// touch can be matched to an ayah and an ayah highlighted.
///
/// Built from the page images by tool/build_ayah_regions.py.
class AyahRegions {
  AyahRegions._(this._pages);

  static AyahRegions? _instance;
  static Future<AyahRegions>? _loading;

  /// Loaded once and kept.
  static AyahRegions? get loaded => _instance;

  static Future<AyahRegions> load() => _loading ??= () async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/ayah_regions.json'))
            as Map<String, dynamic>;
    final lines = (json['lines'] as List).cast<num>();
    final special = (json['special'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(int.parse(k), (v as List).cast<num>()),
    );
    final half = (json['halfHeight'] as num).toDouble();
    final pages = json['pages'] as List;
    return _instance = AyahRegions._([
      for (var p = 0; p < pages.length; p++)
        [
          for (final a in pages[p] as List)
            _AyahArea(a[0] as int, a[1] as int, [
              for (var i = 0; i < (a[2] as List).length; i += 3)
                _rect(
                  (special[p + 1] ?? lines)[(a[2] as List)[i] as int],
                  half,
                  (a[2] as List)[i + 1] as int,
                  (a[2] as List)[i + 2] as int,
                ),
            ]),
        ],
    ]);
  }();

  static Rect _rect(num line, double half, int left, int right) =>
      Rect.fromLTRB(left / 1000, line - half, right / 1000, line + half);

  final List<List<_AyahArea>> _pages;

  /// The ayah at [point] (fractions of the page's width and height).
  (int surah, int ayah)? ayahAt(int page, Offset point) {
    for (final a in _pages[page - 1]) {
      if (a.rects.any((r) => r.contains(point))) return (a.surah, a.ayah);
    }
    return null;
  }

  /// The areas [ayah] covers on [page], empty if it is not there.
  List<Rect> rectsOf(int page, int surah, int ayah) {
    for (final a in _pages[page - 1]) {
      if (a.surah == surah && a.ayah == ayah) return a.rects;
    }
    return const [];
  }

  late final Map<(int, int), int> _pageOf = {
    for (var p = 0; p < _pages.length; p++)
      for (final a in _pages[p]) (a.surah, a.ayah): p + 1,
  };

  /// The page [ayah] of [surah] is on, in this mushaf.
  int? pageOf(int surah, int ayah) => _pageOf[(surah, ayah)];

  /// The ayahs on [page] in reading order.
  List<(int, int)> ayahsOn(int page) => [
    for (final a in _pages[page - 1]) (a.surah, a.ayah),
  ];
}

class _AyahArea {
  const _AyahArea(this.surah, this.ayah, this.rects);

  final int surah;
  final int ayah;
  final List<Rect> rects;
}
