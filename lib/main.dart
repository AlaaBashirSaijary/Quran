import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/index.dart';
import 'prayer/prayer.dart';
import 'providers/ahadith_details_provider.dart';
import 'providers/bookmark.dart';
import 'providers/quran.dart';
import 'providers/reading_provider.dart';
import 'providers/sebha_provider.dart';
import 'providers/show_overlay_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/toast.dart';
import 'screens/douaa_screen.dart';
import 'screens/index_screen.dart';
import 'screens/juz_index_screen.dart';
import 'screens/search_screen.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (context) => ThemeProvider(prefs),
        ),
        ChangeNotifierProvider<ShowOverlayProvider>(
          create: (context) => ShowOverlayProvider(),
        ),
        ChangeNotifierProvider<Quran>(create: (context) => Quran(prefs)),
        ChangeNotifierProxyProvider<Quran, BookMarkProvider>(
          create: (context) => BookMarkProvider(prefs),
          update: (context, value, previous) =>
              previous!..update(value.currentPage),
        ),
        ChangeNotifierProxyProvider<Quran, ToastProvider>(
          create: (context) => ToastProvider(),
          update: (context, value, previous) =>
              previous!..update(value.hizbQuarter),
        ),
        ChangeNotifierProxyProvider<Quran, ReadingProvider>(
          create: (context) => ReadingProvider(prefs),
          update: (context, value, previous) =>
              previous!..update(value.currentPage),
        ),
        ChangeNotifierProvider<PrayerProvider>(
          create: (context) => PrayerProvider(prefs),
        ),
        ChangeNotifierProvider<SebhaProvider>(
          create: (context) => SebhaProvider(prefs),
        ),
        ChangeNotifierProvider<AhadithDetailsProvider>(
          create: (context) => AhadithDetailsProvider()..loadHadithFile(),
        ),
      ],
      child: MyApp(prefs: prefs),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'طريق الجنة',
          theme: AppTheme.lightThemeData,
          darkTheme: AppTheme.darkThemeData,
          themeMode: theme.themeMode,
          home: SplashScreen(prefs: prefs),
          localizationsDelegates: const [
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale("ar", "AE")],
          locale: const Locale("ar", "AE"),
          routes: {
            '/index': (context) => const IndexScreen(),
            '/juz-index': (context) => const JuzIndexScreen(),
            '/douaa': (context) => const DouaaScreen(),
            '/search': (context) => const SearchScreen(),
          },
        );
      },
    );
  }
}
