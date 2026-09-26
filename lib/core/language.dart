import 'package:flutter/widgets.dart';

/// The language of the app's interface. Religious texts (the Quran,
/// hadith, azkar and du'a) are always shown in Arabic.
enum AppLanguage {
  ar('العربية', TextDirection.rtl),
  en('English', TextDirection.ltr);

  const AppLanguage(this.label, this.direction);

  final String label;
  final TextDirection direction;

  Locale get locale => Locale(name);

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.name == code, orElse: () => ar);
}

/// Set by AppRoot from the saved setting; the app is rebuilt from the root
/// when it changes, so every label is read again.
AppLanguage appLanguage = AppLanguage.ar;

bool get isEnglish => appLanguage == AppLanguage.en;

/// The interface text in the current language.
String tr(String ar, String en) => isEnglish ? en : ar;
