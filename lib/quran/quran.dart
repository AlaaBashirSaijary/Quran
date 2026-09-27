import 'page_data.dart';
import 'surah_data.dart';
import '../core/language.dart';

/// Whether a bookmarked page shows part of [surahNumber]: either the surah
/// the page opens with, or one that begins further down it.
bool isMarkedSurah(Set<int> markPages, int surahNumber) {
  return markPages.any(
    (page) =>
        getSurahNumberByPage(page) == surahNumber ||
        getSurahFirstPage(surahNumber) == page,
  );
}

String gethizbText(int page) {
  final currentPage = quranPages[page - 1];
  final hizb = currentPage.hizb;
  switch (currentPage.hizbQuarter % 4) {
    case 0:
      return tr('¾ الحزب $hizb', '¾ Hizb $hizb');
    case 2:
      return tr('¼ الحزب $hizb', '¼ Hizb $hizb');
    case 3:
      return tr('½ الحزب $hizb', '½ Hizb $hizb');
    default:
      return tr('الحزب $hizb', 'Hizb $hizb');
  }
}

String getSurahData(int surahNumber) {
  return tr(
    '${getPlaceOfRevelation(surahNumber)}, آياتها ${getNumberOfAyahs(surahNumber)}',
    '${getPlaceOfRevelation(surahNumber)}, ${getNumberOfAyahs(surahNumber)} ayahs',
  );
}

String getSurahDataByPage(int page) {
  return tr(
    '${getPlaceOfRevelationByPage(page)}, آياتها ${getNumberOfAyahsByPage(page)}',
    '${getPlaceOfRevelationByPage(page)}, ${getNumberOfAyahsByPage(page)} ayahs',
  );
}

String getSurahDataWithNameByPage(int page) {
  return '${surahTitle(getSurahNumberByPage(page))} (${getSurahDataByPage(page)})';
}

// simple methods
int getSurahNumberByPage(int page) {
  return quranPages[page - 1].surah;
}

String getSurahName(int page) {
  return surahNameOf(getSurahNumberByPage(page));
}

int getNumberOfAyahsByPage(int page) {
  return surah[getSurahNumberByPage(page) - 1]['aya'] as int;
}

int getNumberOfAyahs(int surahNumber) {
  return surah[surahNumber - 1]['aya'] as int;
}

String getSurahNameArabic(int surahNumber) {
  return surah[surahNumber - 1]['arabic'] as String;
}

/// The surah's name in the interface language (transliterated in English).
String surahNameOf(int surahNumber) => isEnglish
    ? surah[surahNumber - 1]['name'] as String
    : getSurahNameArabic(surahNumber);

/// The surah's name translated, e.g. "The Opening".
String surahNameEnglish(int surahNumber) =>
    surah[surahNumber - 1]['english'] as String;

/// "سورة الفاتحة" or "Surah Al Fatiha".
String surahTitle(int surahNumber) => tr(
  'سورة ${getSurahNameArabic(surahNumber)}',
  'Surah ${surahNameOf(surahNumber)}',
);

/// "الآية 5" or "Ayah 5".
String ayahLabel(int ayah) => tr('الآية $ayah', 'Ayah $ayah');

String getPlaceOfRevelation(int surahNumber) {
  final place = surah[surahNumber - 1]['place'] as String;
  return isEnglish ? (place == 'مكية' ? 'Meccan' : 'Medinan') : place;
}

String getPlaceOfRevelationByPage(int page) {
  return getPlaceOfRevelation(getSurahNumberByPage(page));
}

int getSurahFirstPage(int surahNumber) {
  return surahFirstPages[surahNumber - 1];
}

int getHizbQuarter({required int hizb, required int quarter}) {
  return (hizb - 1) * 4 + quarter + 1;
}

int getHizb({required int juz, required int hizb}) {
  return (juz - 1) * 2 + hizb;
}

int getHizbQuarterPage(int quarter) {
  return quranPages.indexWhere((page) => page.hizbQuarter == quarter) + 1;
}

int getJuzPage(int juz) {
  return quranPages.indexWhere((page) => page.juz == juz) + 1;
}

int getHizbPage(int hizb) {
  return quranPages.indexWhere((page) => page.hizb == hizb) + 1;
}

String pageDir(int number) {
  return 'assets/quran-images/page${formattedPageNumber(number)}.png';
}

String formattedPageNumber(int number) {
  if (number < 10) return '00$number';
  if (number < 100) return '0$number';
  return '$number';
}

/// Page on which each surah begins, indexed by surah number - 1. Most
/// surahs begin partway down a page, so this can't be derived from
/// [quranPages], which only records the surah a page opens with.
const surahFirstPages = [
  1,
  2,
  50,
  77,
  106,
  128,
  151,
  177,
  187,
  208,
  221,
  235,
  249,
  255,
  262,
  267,
  282,
  293,
  305,
  312,
  322,
  332,
  342,
  350,
  359,
  367,
  377,
  385,
  396,
  404,
  411,
  415,
  418,
  428,
  434,
  440,
  446,
  453,
  458,
  467,
  477,
  483,
  489,
  496,
  499,
  502,
  507,
  511,
  515,
  518,
  520,
  523,
  526,
  528,
  531,
  534,
  537,
  542,
  545,
  549,
  551,
  553,
  554,
  556,
  558,
  560,
  562,
  564,
  566,
  568,
  570,
  572,
  574,
  575,
  577,
  578,
  580,
  582,
  583,
  585,
  586,
  587,
  587,
  589,
  590,
  591,
  591,
  592,
  593,
  594,
  595,
  595,
  596,
  596,
  597,
  597,
  598,
  598,
  599,
  599,
  600,
  600,
  601,
  601,
  601,
  602,
  602,
  602,
  603,
  603,
  603,
  604,
  604,
  604,
];
