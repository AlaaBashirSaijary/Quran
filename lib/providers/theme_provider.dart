import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeProvider(this.prefs) {
    final saved = prefs.getString(_key);
    themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  static const _key = 'themeMode';

  final SharedPreferences prefs;

  // Follows the device setting until the user picks a mode.
  late ThemeMode themeMode;

  bool get isDarkMode {
    return switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
  }

  void toggleTheme(bool newValue) {
    themeMode = newValue ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    prefs.setString(_key, themeMode.name);
  }
}
