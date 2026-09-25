import 'page_data.dart';
import 'surah_data.dart';

/// Whether the bookmarked page shows part of [surahNumber]: either the surah
/// the page opens with, or one that begins further down it.
bool isMarkedSurah(int? markPage, int surahNumber) {
  if (markPage == null) return false;
  return getSurahNumberByPage(markPage) == surahNumber ||
      getSurahFirstPage(surahNumber) == markPage;
}

String gethizbText(int page) {
  final currentPage = quranPages[page - 1];
  final hizb = currentPage.hizb;
  switch (currentPage.hizbQuarter % 4) {
    case 0:
      return '¾ الحزب $hizb';
    case 2:
      return '¼ الحزب $hizb';
    case 3:
      return '½ الحزب $hizb';
    default:
      return 'الحزب $hizb';
  }
}

String getSurahData(int surahNumber) {
  return '${getPlaceOfRevelation(surahNumber)}, آياتها ${getNumberOfAyahs(surahNumber)}';
}

String getSurahDataByPage(int page) {
  return '${getPlaceOfRevelationByPage(page)}, آياتها ${getNumberOfAyahsByPage(page)}';
}

String getSurahDataWithNameByPage(int page) {
  return 'سورة ${getSurahName(page)} (${getSurahDataByPage(page)})';
}

// simple methods
int getSurahNumberByPage(int page) {
  return quranPages[page - 1].surah;
}

String getSurahName(int page) {
  return getSurahNameArabic(getSurahNumberByPage(page));
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

String getPlaceOfRevelation(int surahNumber) {
  return surah[surahNumber - 1]['place'] as String;
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
