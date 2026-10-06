import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/language.dart';
import '../quran/page_images.dart';

/// Reading preferences that apply across the app's text content
/// (hadith, azkar, du'a, search results and tafsir).
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this.prefs) {
    textScale = prefs.getDouble(_scaleKey) ?? 1.0;
    hijriOffset = prefs.getInt(_hijriKey) ?? 0;
  }

  static const languageKey = 'settings.language';
  static const _translationKey = 'settings.translation';
  static const _textModeKey = 'reader.textMode';
  static const _tafsirKey = 'tafsir.source';
  static const _translationLangKey = 'settings.translationLang';
  static const _scaleKey = 'settings.textScale';
  static const _hijriKey = 'settings.hijriOffset';
  static const scales = [0.85, 1.0, 1.15, 1.3, 1.5];

  final SharedPreferences prefs;
  late double textScale;

  /// Days added to the Umm al-Qura date where the month begins by local
  /// moon sighting (-2 to 2).
  late int hijriOffset;

  AppLanguage get language =>
      AppLanguage.fromCode(prefs.getString(languageKey));

  /// Saves the interface language. The caller rebuilds the app
  /// (AppRoot.restart) for it to take effect.
  Future<void> setLanguage(AppLanguage value) =>
      prefs.setString(languageKey, value.name);

  /// Show the English translation of the meanings beside the Quranic text.
  /// On by default in the English interface.
  bool get showTranslation => prefs.getBool(_translationKey) ?? isEnglish;

  void setShowTranslation(bool value) {
    prefs.setBool(_translationKey, value);
    notifyListeners();
  }

  /// Read the mushaf as text instead of page images.
  // The light build ships without the mushaf images, so it opens in text
  // mode, which works offline from the first launch.
  bool get textMode => prefs.getBool(_textModeKey) ?? kLite;

  void setTextMode(bool value) {
    prefs.setBool(_textModeKey, value);
    notifyListeners();
  }

  /// The language of the translation of the meanings (see
  /// translationLanguages); English unless another was downloaded.
  String get translationLang => prefs.getString(_translationLangKey) ?? 'en';

  void setTranslationLang(String code) {
    prefs.setString(_translationLangKey, code);
    notifyListeners();
  }

  /// The tafsir shown (see tafsirSources).
  String? get tafsirSourceId => prefs.getString(_tafsirKey);

  void setTafsirSource(String id) {
    prefs.setString(_tafsirKey, id);
    notifyListeners();
  }

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
