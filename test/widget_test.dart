import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quranapplication/main.dart';
import 'package:quranapplication/providers/ahadith_details_provider.dart';
import 'package:quranapplication/providers/bookmark.dart';
import 'package:quranapplication/providers/quran.dart';
import 'package:quranapplication/providers/show_overlay_provider.dart';
import 'package:quranapplication/providers/theme_provider.dart';
import 'package:quranapplication/providers/toast.dart';
import 'package:quranapplication/quran/quran.dart';
import 'package:quranapplication/quran/search.dart';
import 'package:quranapplication/tabs/sebha_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget buildApp(SharedPreferences prefs) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
      ChangeNotifierProvider(create: (_) => ShowOverlayProvider()),
      ChangeNotifierProvider(create: (_) => Quran(prefs)),
      ChangeNotifierProxyProvider<Quran, BookMarkProvider>(
        create: (_) => BookMarkProvider(prefs),
        update: (_, quran, previous) => previous!..update(quran.currentPage),
      ),
      ChangeNotifierProxyProvider<Quran, ToastProvider>(
        create: (_) => ToastProvider(),
        update: (_, quran, previous) => previous!..update(quran.hizbQuarter),
      ),
      ChangeNotifierProvider(
        create: (_) => AhadithDetailsProvider()..loadHadithFile(),
      ),
    ],
    child: MyApp(prefs: prefs),
  );
}

void main() {
  testWidgets('first launch shows onboarding, then the main tabs',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildApp(prefs));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('التالي'), findsOneWidget);

    await tester.tap(find.text('تخطَّ'));
    await tester.pumpAndSettle();

    expect(find.text('فهرس السور'), findsOneWidget);
    expect(prefs.getBool('seenOnboarding'), isTrue);
  });

  testWidgets('sebha moves to the next zikr after 33 taps', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
          home: Directionality(
        textDirection: TextDirection.rtl,
        child: SebhaTab(),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('سبحان الله'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    for (var i = 0; i < 32; i++) {
      await tester.tap(find.text('من 33'));
    }
    await tester.pump();
    expect(find.text('32'), findsOneWidget);
    expect(find.text('سبحان الله'), findsOneWidget);

    await tester.tap(find.text('من 33'));
    await tester.pump();
    expect(find.text('الحمد لله'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('مجموع التسبيحات: 33'), findsOneWidget);
  });

  test('theme choice is saved and defaults to the system setting', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(ThemeProvider(prefs).themeMode, ThemeMode.system);

    ThemeProvider(prefs).toggleTheme(true);
    expect(ThemeProvider(prefs).themeMode, ThemeMode.dark);
  });

  testWidgets('ahadith file parses into titled entries with no empty ones',
      (tester) async {
    // An earlier test may have left a pending load of this file in the cache.
    rootBundle.evict('assets/ahadeth.txt');
    final provider = AhadithDetailsProvider();
    await tester.runAsync(provider.loadHadithFile);

    expect(provider.ahadithData, isNotEmpty);
    expect(provider.ahadithData.first.title, 'الحديث الأول');
    for (final hadith in provider.ahadithData) {
      expect(hadith.title, isNotEmpty);
      expect(hadith.content, isNotEmpty);
    }
  });

  test('page info names the surah that the page belongs to', () async {
    SharedPreferences.setMockInitialValues({'page': 50});
    final quran = Quran(await SharedPreferences.getInstance());

    // Page 50 opens Surah Al Imran (200 ayahs), not Al-Baqarah.
    expect(quran.surahName, 'آل عمران');
    expect(quran.surahData, startsWith('سورة آل عمران'));
    expect(quran.surahData, contains('200'));
  });

  group('Quran search', () {
    late QuranSearch search;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      search = await QuranSearch.load();
    });

    List<String> refs(String query) => [
          for (final ayah in search.search(query).ayahs)
            '${ayah.surah}:${ayah.number}',
        ];

    test('matches text typed in modern spelling', () {
      expect(refs('الحمد لله رب العالمين'), contains('1:2'));
      expect(refs('يا أيها الذين آمنوا'), contains('2:104'));
      expect(refs('وأقيموا الصلاة وآتوا الزكاة'), contains('2:43'));
      expect(refs('إبراهيم'), contains('2:124'));
      expect(refs('السماء'), contains('2:22'));
      expect(refs('الله لا إله إلا هو الحي القيوم'), ['2:255', '3:2']);
    });

    test('only matches from the start of a word', () {
      // نَسۡلُكُهُۥ فِي reads as ...لكهف... once spaces are dropped
      expect(refs('الكهف'), isNot(contains('15:12')));
      expect(refs('الكهف'), contains('18:9'));
    });

    test('finds surahs by name and points to their first page', () {
      final results = search.search('الكهف');
      expect(results.surahs, [18]);
      expect(getSurahFirstPage(18), 293);
    });

    test('knows the page of each ayah', () {
      final kursi = search.search('الحي القيوم لا تأخذه سنة').ayahs.single;
      expect([kursi.surah, kursi.number, kursi.page], [2, 255, 42]);
    });

    test('ignores queries shorter than two letters', () {
      expect(search.search('ا').isEmpty, isTrue);
    });
  });

  test('there is no bookmark until one is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final bookMark = BookMarkProvider(await SharedPreferences.getInstance())
      ..update(1);

    expect(bookMark.markPage, isNull);
    expect(bookMark.isMarkedPage, isFalse);
    expect(isMarkedSurah(bookMark.markPage, 1), isFalse);
  });

  test('a bookmark marks every surah on its page', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    BookMarkProvider(prefs)
      ..update(293)
      ..changeMark();

    // Page 293 ends Al-Isra and begins Al-Kahf.
    final markPage = BookMarkProvider(prefs).markPage;
    expect(markPage, 293);
    expect(isMarkedSurah(markPage, 17), isTrue);
    expect(isMarkedSurah(markPage, 18), isTrue);
    expect(isMarkedSurah(markPage, 19), isFalse);
  });
}
