import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../quran/quran.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../quran/page_data.dart';

class Quran extends ChangeNotifier {
  late int currentPage;
  final SharedPreferences prefs;

  Quran(this.prefs) {
    currentPage = prefs.getInt('page') ?? 1;
  }

  final carouselController = CarouselSliderController();

  int get surahNumber => quranPages[currentPage - 1].surah;

  String get surahName => getSurahNameArabic(surahNumber);

  int get juz => quranPages[currentPage - 1].juz;

  int get hizb => quranPages[currentPage - 1].hizb;

  int get hizbQuarter => quranPages[currentPage - 1].hizbQuarter;

  bool get isRightPage => currentPage % 2 != 0;

  String get hizbText => gethizbText(currentPage);

  String get surahData => getSurahDataWithNameByPage(currentPage);

  /// Jumps the open reader to [page] (1 to 604).
  void goToPage(int page) {
    carouselController.jumpToPage(page - 1);
  }

  /// Sets the page the reader opens on, for when no reader is open yet.
  void openAtPage(int page) {
    changePage(page - 1);
  }

  void changePage(int newIndex) {
    currentPage = newIndex + 1;
    notifyListeners();
    prefs.setInt('page', newIndex + 1);
  }
}
