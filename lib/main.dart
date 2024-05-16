import 'package:flutter/material.dart';
import 'package:quranapplication/providers/bookmark.dart';
import 'package:quranapplication/providers/my_provider.dart';
import 'package:quranapplication/providers/theme_provider.dart';
import 'package:quranapplication/providers/toast.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quranapplication/screens/homeScreenmain.dart';
import 'package:quranapplication/screens/home_screen.dart';
import 'package:quranapplication/splassh_screen.dart';
import 'package:quranapplication/tabs/ahadeth_tab.dart';
import 'package:quranapplication/widgets/hadith_details.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/index.dart';
import 'model/hadith_model.dart';
import 'providers/quran.dart';
import 'providers/show_overlay_provider.dart';
import 'screens/douaa_screen.dart';
import 'screens/index_screen.dart';
import 'screens/juz_index_screen.dart';
import 'screens/search_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (context) => ThemeProvider(),
        ),
        ChangeNotifierProvider<ShowOverlayProvider>(
          create: (context) => ShowOverlayProvider(),
        ),
        ChangeNotifierProvider<Quran>(
          create: (context) => Quran(prefs),
        ),
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
  ChangeNotifierProvider<MyProvider>(
  create: (context) => MyProvider(),)
      ],

      child: const MyApp(),
    ),);

}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Quran App',
          theme: AppTheme.lightThemeData,
          darkTheme: AppTheme.darkThemeData,
          themeMode: theme.themeMode,
          home:  SplashScreen(),
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
