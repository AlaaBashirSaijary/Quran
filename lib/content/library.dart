import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/app_extension.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import '../core/language.dart';

/// A titled group of texts: a book of hadith, or a chapter of du'a.
class TextSection {
  const TextSection(this.title, this.texts);

  final String title;
  final List<String> texts;
}

final _cache = <String, Object>{};

Future<T> _load<T>(String asset, T Function(dynamic json) parse) async {
  final cached = _cache[asset];
  if (cached != null) return cached as T;
  final text = await rootBundle.loadString(asset, cache: false);
  final result = parse(jsonDecode(expandLigatures(text)));
  _cache[asset] = result as Object;
  return result;
}

/// Riyad as-Salihin by Imam al-Nawawi (sunnah.com, via hadith-json).
Future<List<TextSection>> loadRiyad() =>
    _load('assets/content/riyad.json', (json) {
      return [
        for (final b in json['books'] as List)
          TextSection(b['title'] as String, (b['hadiths'] as List).cast()),
      ];
    });

/// The forty hadith qudsi (sunnah.com, via hadith-json).
Future<List<String>> loadQudsi() => _load(
  'assets/content/qudsi40.json',
  (json) => (json['hadiths'] as List).cast<String>(),
);

/// Every chapter of Hisn al-Muslim.
Future<List<TextSection>> loadHisn() =>
    _load('assets/content/hisn.json', (json) {
      return [
        for (final c in json as List)
          TextSection(c['title'] as String, (c['items'] as List).cast()),
      ];
    });

/// The well-known list of the ninety-nine names.
Future<List<String>> loadNames() =>
    _load('assets/content/names.json', (json) => (json as List).cast<String>());

/// Chapters of Hisn al-Muslim already shown in the azkar categories.
const _alreadyInAzkar = {
  'أذكار الصباح والمساء',
  'أذكار النوم',
  'أذكار الاستيقاظ من النوم',
  'الأذكار بعد السلام من الصلاة',
};

/// Hisn al-Muslim chapters for occasions, without the introduction and the
/// daily azkar that have their own screens.
Future<List<TextSection>> loadOccasionDuas() async => [
  for (final s in await loadHisn())
    if (s.title != 'المقدمة' && !_alreadyInAzkar.contains(s.title)) s,
];

/// Quranic passages read in ruqyah: Al-Fatiha, Ayat al-Kursi, the last two
/// ayahs of Al-Baqarah, and the three Quls. (surah, first ayah, last ayah)
const ruqyahPassages = [
  (1, 1, 7),
  (2, 255, 255),
  (2, 285, 286),
  (112, 1, 4),
  (113, 1, 5),
  (114, 1, 6),
];

/// Hisn al-Muslim chapters with the Prophet's words of ruqyah.
const _ruqyahChapters = [
  'ما يعوذ به الأولاد',
  'الدعاء للمريض في عيادته',
  'ما يقول من أحس وجعاً في جسده',
  'دعاء من خشي أن يصيب شيئاً بعينه',
];

/// Ruqyah from the Quran (text from the app's Uthmani mushaf text) and from
/// the Sunnah (Hisn al-Muslim).
Future<List<TextSection>> loadRuqyah() async {
  final quran = await QuranSearch.load();
  final hisn = await loadHisn();
  return [
    for (final (surah, from, to) in ruqyahPassages)
      TextSection(
        from == 1 && to == quran.ayahsOfSurah(surah).length
            ? surahTitle(surah)
            : '${surahTitle(surah)} · '
                  '${from == to ? ayahLabel(from) : tr('الآيتان $from–$to', 'Ayahs $from–$to')}',
        [
          [
            for (final a in quran.ayahsOfSurah(surah))
              if (a.number >= from && a.number <= to) '${a.text} ﴿${a.number}﴾',
          ].join(' '),
        ],
      ),
    for (final s in hisn)
      if (_ruqyahChapters.contains(s.title)) s,
  ];
}
