import 'package:flutter/material.dart';
import 'app_color.dart';

class AppTheme {
  static const fontFamily = 'diodrum';
  static const secondaryFontFamily = 'uthmanic';

  static ThemeData lightThemeData = themeData(lightColorScheme);
  static ThemeData darkThemeData = themeData(darkColorScheme);

  static ThemeData themeData(ColorScheme colorScheme) {
    final onBg = colorScheme.onSurface;
    final isLight = colorScheme.brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: isLight ? AppColor.cream : AppColor.night,
      appBarTheme: AppBarTheme(
        toolbarHeight: 56,
        centerTitle: true,
        backgroundColor: colorScheme.appBar,
        foregroundColor: Colors.white,
        titleTextStyle: _textTheme.headlineSmall!.copyWith(
          fontFamily: secondaryFontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Colors.white,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: isLight ? Colors.white : AppColor.nightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.div),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? Colors.white : AppColor.nightSurface,
        indicatorColor: colorScheme.gold.withValues(alpha: 0.25),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : onBg.withValues(alpha: 0.6),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: states.contains(WidgetState.selected)
                ? _bold
                : _medium,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : onBg.withValues(alpha: 0.6),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: _bold,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontWeight: _bold, fontSize: 48, color: onBg),
        displayMedium: TextStyle(fontWeight: _bold, fontSize: 38, color: onBg),
        displaySmall:
            TextStyle(fontWeight: _semiBold, fontSize: 32, color: onBg),
        headlineMedium:
            TextStyle(fontWeight: _semiBold, fontSize: 24, color: onBg),
        headlineSmall: TextStyle(fontWeight: _medium, fontSize: 20, color: onBg),
        titleLarge: TextStyle(fontWeight: _semiBold, fontSize: 18, color: onBg),
        titleMedium: TextStyle(fontWeight: _medium, fontSize: 16, color: onBg),
        //
        bodyLarge: TextStyle(fontWeight: _regular, fontSize: 16, color: onBg),
        bodyMedium: TextStyle(fontWeight: _medium, fontSize: 16, color: onBg),
        //
        bodySmall: TextStyle(fontWeight: _regular, fontSize: 14, color: onBg),
        labelLarge: const TextStyle(fontWeight: _bold, fontSize: 16),
        //
      ),
    );
  }

  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: AppColor.green,
    primary: AppColor.green,
    onPrimary: Colors.white,
    secondary: AppColor.gold,
    onSecondary: Colors.white,
    surface: AppColor.cream,
    brightness: Brightness.light,
  );

  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: AppColor.green,
    primary: AppColor.greenLight,
    onPrimary: AppColor.greenDark,
    secondary: AppColor.goldLight,
    onSecondary: AppColor.night,
    surface: AppColor.night,
    brightness: Brightness.dark,
  );

  static const _regular = FontWeight.w400;
  static const _medium = FontWeight.w500;
  static const _semiBold = FontWeight.w600;
  static const _bold = FontWeight.w700;

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontWeight: _bold, fontSize: 72),
    displayMedium: TextStyle(fontWeight: _bold, fontSize: 48),
    displaySmall: TextStyle(fontWeight: _semiBold, fontSize: 32),
    headlineMedium: TextStyle(fontWeight: _semiBold, fontSize: 24),
    headlineSmall: TextStyle(fontWeight: _medium, fontSize: 18),
    titleLarge: TextStyle(fontWeight: _regular, fontSize: 16),
    //
    titleMedium: TextStyle(fontWeight: _medium, fontSize: 16.0),
    titleSmall: TextStyle(fontWeight: _medium, fontSize: 14.0),
    //
    bodyLarge: TextStyle(fontWeight: _regular, fontSize: 16),
    bodyMedium: TextStyle(fontWeight: _medium, fontSize: 16),
    //
    bodySmall: TextStyle(fontWeight: _semiBold, fontSize: 16),
    labelLarge: TextStyle(fontWeight: _semiBold, fontSize: 18.0),
  );
}
