import 'package:flutter/material.dart';

// Main Colors (Primary and Secondary)
class AppColor {
  const AppColor._();

  // Deep green
  static const green = Color(0xFF1F5E3B);
  static const greenDark = Color(0xFF14432A);
  static const greenLight = Color(0xFF8FD1A9);

  // Gold
  static const gold = Color(0xFFC9A54C);
  static const goldLight = Color(0xFFE0C27A);

  // Backgrounds
  static const cream = Color(0xFFFBF7EE);
  static const paper = Color(0xFFFFFDF6);
  static const night = Color(0xFF101915);
  static const nightSurface = Color(0xFF18241E);
}

// Further Color Cutomization
extension CustomColorScheme on ColorScheme {
  bool get _isLight => brightness == Brightness.light;

  Color get gold => _isLight ? AppColor.gold : AppColor.goldLight;

  // Background behind the Quran page
  Color get scaffold => _isLight ? AppColor.paper : const Color(0xFF121A16);

  // Background around the page on wide (landscape / tablet) screens
  Color get scaffoldBg =>
      _isLight ? const Color(0xFFF1EBDD) : const Color(0xFF0B110E);

  Color get infoText => _isLight ? const Color(0xFF8A6D2B) : AppColor.goldLight;

  Color get appBar => _isLight ? AppColor.green : const Color(0xFF0E1A14);

  // Floating panels shown on top of the Quran page
  Color get overlay => _isLight ? AppColor.green : const Color(0xFF0E1A14);

  Color get pageNumber =>
      _isLight ? const Color(0x7B000000) : const Color(0x92FFFFFF);

  Color get div => _isLight
      ? const Color.fromARGB(40, 31, 94, 59)
      : const Color.fromARGB(55, 255, 255, 255);

  Color get juzCardText =>
      _isLight ? const Color(0xFF1F3A2B) : const Color(0xFFECECEC);

  Color get surahNumber => gold;
}
