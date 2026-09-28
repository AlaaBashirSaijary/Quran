import '../content/library.dart';
import '../quran/search.dart';

/// Short, self-contained ayahs of reminder and du'a, one a day in turn.
/// (surah, ayah); the text always comes from the bundled mushaf text.
const dailyAyahs = [
  (2, 152),
  (2, 186),
  (2, 201),
  (2, 255),
  (2, 286),
  (3, 8),
  (3, 26),
  (3, 133),
  (3, 159),
  (3, 190),
  (4, 110),
  (6, 162),
  (7, 56),
  (7, 199),
  (9, 51),
  (13, 28),
  (14, 7),
  (14, 41),
  (16, 97),
  (16, 128),
  (17, 23),
  (17, 24),
  (17, 80),
  (20, 25),
  (20, 114),
  (21, 87),
  (23, 118),
  (24, 35),
  (25, 63),
  (25, 74),
  (28, 24),
  (29, 69),
  (33, 41),
  (39, 10),
  (39, 53),
  (40, 60),
  (41, 34),
  (42, 43),
  (49, 10),
  (49, 13),
  (50, 16),
  (59, 10),
  (59, 22),
  (64, 11),
  (67, 2),
  (93, 5),
  (94, 5),
  (99, 7),
  (112, 1),
];

/// Days since 1 January 2000, the same for everyone on a given date.
int _dayNumber(DateTime date) => DateTime.utc(
  date.year,
  date.month,
  date.day,
).difference(DateTime.utc(2000)).inDays;

(int, int) ayahOfDay(DateTime date) =>
    dailyAyahs[_dayNumber(date) % dailyAyahs.length];

Ayah? ayahOfDayText(QuranSearch quran, DateTime date) {
  final (surah, number) = ayahOfDay(date);
  final ayahs = quran.ayahsOfSurah(surah);
  return number <= ayahs.length ? ayahs[number - 1] : null;
}

/// A hadith of Riyad as-Salihin for [date]: one of moderate length, taken
/// in turn, with the name of its book.
(String book, String text)? hadithOfDay(
  List<TextSection> riyad,
  DateTime date,
) {
  final pool = [
    for (final book in riyad)
      for (final text in book.texts)
        if (text.length >= 80 && text.length <= 450) (book.title, text),
  ];
  if (pool.isEmpty) return null;
  return pool[_dayNumber(date) % pool.length];
}
