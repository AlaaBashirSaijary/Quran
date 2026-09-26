import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reading preferences that apply across the app's text content
/// (hadith, azkar, du'a, search results and tafsir).
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this.prefs) {
    textScale = prefs.getDouble(_scaleKey) ?? 1.0;
    hijriOffset = prefs.getInt(_hijriKey) ?? 0;
  }

  static const _scaleKey = 'settings.textScale';
  static const _hijriKey = 'settings.hijriOffset';
  static const scales = [0.85, 1.0, 1.15, 1.3, 1.5];

  final SharedPreferences prefs;
  late double textScale;

  /// Days added to the Umm al-Qura date where the month begins by local
  /// moon sighting (-2 to 2).
  late int hijriOffset;

  void setHijriOffset(int value) {
    hijriOffset = value.clamp(-2, 2);
    prefs.setInt(_hijriKey, hijriOffset);
    notifyListeners();
  }

  void setTextScale(double value) {
    textScale = value;
    prefs.setDouble(_scaleKey, value);
    notifyListeners();
  }
}

extension ContentText on BuildContext {
  /// Scales a content font size by the reader's chosen text size.
  double contentSize(double size) {
    try {
      return size * Provider.of<SettingsProvider>(this).textScale;
    } on ProviderNotFoundException {
      return size;
    }
  }
}
