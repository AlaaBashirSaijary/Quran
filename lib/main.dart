import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/downloads.dart';
import 'audio/recitation.dart';
import 'core/error_log.dart';
import 'core/index.dart';
import 'hifz/hifz.dart';
import 'khatma/group_khatma.dart';
import 'notifications/notification_settings.dart';
import 'prayer/prayer.dart';
import 'providers/ahadith_details_provider.dart';
import 'providers/bookmark.dart';
import 'providers/quran.dart';
import 'providers/reading_provider.dart';
import 'providers/sebha_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/show_overlay_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/toast.dart';
import 'screens/douaa_screen.dart';
import 'screens/index_screen.dart';
import 'screens/juz_index_screen.dart';
import 'screens/search_screen.dart';
import 'screens/splash_screen.dart';
import 'notes/notes.dart';

/// Lets screens know when another screen covers them.
final routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  ErrorLog.install(prefs);

  runApp(AppRoot(prefs: prefs));
}

/// Builds the providers from saved data. [restart] rebuilds them, which is
/// how a restored backup takes effect without closing the app.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.prefs});

  final SharedPreferences prefs;

  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_AppRootState>()?.restart();
  }

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  Key _key = UniqueKey();

  void restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) {
    final prefs = widget.prefs;
    appLanguage = AppLanguage.fromCode(
      prefs.getString(SettingsProvider.languageKey),
    );
    return KeyedSubtree(
      key: _key,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(
            create: (context) => ThemeProvider(prefs),
          ),
          ChangeNotifierProvider<SettingsProvider>(
            create: (context) => SettingsProvider(prefs),
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
          ChangeNotifierProvider<NotificationSettings>(
            create: (context) => NotificationSettings(prefs),
          ),
          ChangeNotifierProvider<HifzProvider>(
            create: (context) => HifzProvider(prefs),
          ),
          ChangeNotifierProvider<NotesProvider>(
            create: (context) => NotesProvider(prefs),
          ),
          ChangeNotifierProvider<GroupKhatmaProvider>(
            create: (context) => GroupKhatmaProvider(prefs),
          ),
          ChangeNotifierProvider<AudioDownloads>(
            create: (context) => AudioDownloads(prefs),
          ),
          ChangeNotifierProvider<RecitationProvider>(
            create: (context) => RecitationProvider(
              prefs,
              downloads: context.read<AudioDownloads>(),
            ),
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
          title: tr('منهج حياة', 'Manhaj Hayah'),
          theme: AppTheme.lightThemeData,
          darkTheme: AppTheme.darkThemeData,
          themeMode: theme.themeMode,
          home: SplashScreen(prefs: prefs),
          navigatorObservers: [routeObserver],
          localizationsDelegates: const [
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [for (final l in AppLanguage.values) l.locale],
          locale: appLanguage.locale,
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
