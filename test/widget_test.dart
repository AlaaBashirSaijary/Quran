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
import 'package:quranapplication/providers/sebha_provider.dart';
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
      ChangeNotifierProvider(create: (_) => SebhaProvider(prefs)),
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

  testWidgets('sebha counter screen counts taps and can undo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SebhaProvider(prefs),
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SebhaTab(),
          ),
        ),
      ),
    );

    expect(find.text('من 33'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('من 33'));
    }
    await tester.pump();
    expect(find.text('3'), findsWidgets);

    await tester.tap(find.text('تراجع'));
    await tester.pump();
    expect(find.text('2'), findsWidgets);
  });

  group('Sebha', () {
    late DateTime now;

    Future<SebhaProvider> fresh([
      Map<String, Object> values = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(values);
      return SebhaProvider(
        await SharedPreferences.getInstance(),
        clock: () => now,
      );
    }

    setUp(() => now = DateTime(2026, 9, 25, 10));

    test('counts to the target, then starts a new round', () async {
      final sebha = await fresh();
      expect(sebha.selected.text, 'سبحان الله');
      for (var i = 0; i < 32; i++) {
        expect(sebha.tap(), isFalse);
      }
      expect(sebha.count, 32);
      expect(sebha.tap(), isTrue, reason: 'the 33rd tap reaches the target');
      expect(sebha.count, 0);
      expect(sebha.rounds, 1);
      expect(sebha.today, 33);
      expect(sebha.todayCountFor('subhan'), 33);
    });

    test('after-prayer mode goes 33, 33, 33, then the tahleel once', () async {
      final sebha = await fresh()
        ..setMode(SebhaMode.afterPrayer);
      final seen = <String>[];
      for (var i = 0; i < 100; i++) {
        seen.add(sebha.currentText);
        sebha.tap();
      }
      expect(seen.where((t) => t == 'سبحان الله').length, 33);
      expect(seen.where((t) => t == 'الحمد لله').length, 33);
      expect(seen.where((t) => t == 'الله أكبر').length, 33);
      expect(seen.last, startsWith('لا إله إلا الله وحده'));
      expect(sebha.afterPrayerDone, isTrue);
      expect(sebha.total, 100);
    });

    test('custom azkar and targets are saved', () async {
      final sebha = await fresh();
      sebha.addZikr('رب اغفر لي', 7);
      expect(sebha.selected.text, 'رب اغفر لي');
      sebha.setTarget('akbar', 34);

      final again = SebhaProvider(sebha.prefs, clock: () => now);
      expect(again.selected.text, 'رب اغفر لي');
      expect(again.selected.target, 7);
      expect(again.azkar.firstWhere((z) => z.id == 'akbar').target, 34);

      again.removeZikr(again.selected.id);
      expect(again.azkar.any((z) => z.text == 'رب اغفر لي'), isFalse);
    });

    test('built-in azkar cannot be removed', () async {
      final sebha = await fresh();
      sebha.removeZikr('subhan');
      expect(sebha.azkar.length, defaultAzkar.length);
    });

    test('today resets each day and the streak counts consecutive days',
        () async {
      final sebha = await fresh();
      sebha.tap();
      expect([sebha.today, sebha.streak], [1, 1]);

      now = now.add(const Duration(days: 1));
      sebha.tap();
      sebha.tap();
      expect([sebha.today, sebha.streak, sebha.total], [2, 2, 3]);

      now = now.add(const Duration(days: 2));
      final later = SebhaProvider(sebha.prefs, clock: () => now);
      expect([later.today, later.streak], [0, 0], reason: 'a day was missed');
      later.tap();
      expect([later.today, later.streak, later.total], [1, 1, 4]);
    });

    test('undo takes back the last tap', () async {
      final sebha = await fresh();
      sebha
        ..tap()
        ..tap()
        ..undo();
      expect([sebha.count, sebha.today, sebha.total], [1, 1, 1]);
    });
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

  group('Bookmarks', () {
    Future<(BookMarkProvider, SharedPreferences)> fresh([
      Map<String, Object> values = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(values);
      final prefs = await SharedPreferences.getInstance();
      return (BookMarkProvider(prefs), prefs);
    }

    Widget host(void Function(BuildContext) onTap) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => onTap(context),
                child: const Text('tap'),
              ),
            ),
          ),
        );

    test('start empty', () async {
      final (bookMark, _) = await fresh();
      bookMark.update(1);
      expect(bookMark.bookmarks, isEmpty);
      expect(bookMark.isMarkedPage, isFalse);
      expect(isMarkedSurah(bookMark.pages, 1), isFalse);
    });

    testWidgets('several pages can be saved, and saving again removes',
        (tester) async {
      final (bookMark, prefs) = await fresh();
      await tester.pumpWidget(host((context) {
        bookMark.toggleCurrentPage(context);
      }));

      for (final page in [50, 293, 604]) {
        bookMark.update(page);
        await tester.tap(find.text('tap'));
      }
      expect(bookMark.pages, {50, 293, 604});
      expect(BookMarkProvider(prefs).pages, {50, 293, 604}, reason: 'saved');

      bookMark.update(293);
      await tester.tap(find.text('tap'));
      expect(bookMark.pages, {50, 604});
      expect(BookMarkProvider(prefs).pages, {50, 604});
    });

    test('newest bookmark comes first', () async {
      final (bookMark, _) = await fresh({
        'bookmarks': ['10|1000', '20|3000', '30|2000'],
      });
      expect([for (final b in bookMark.bookmarks) b.page], [20, 30, 10]);
    });

    test('the single bookmark of older versions is kept', () async {
      final (bookMark, prefs) = await fresh({'mark': 77});
      expect(bookMark.pages, {77});
      expect(prefs.getInt('mark'), isNull);
      expect(BookMarkProvider(prefs).pages, {77});
    });

    test('a bookmark marks every surah on its page', () async {
      // Page 293 ends Al-Isra and begins Al-Kahf.
      expect(isMarkedSurah({293}, 17), isTrue);
      expect(isMarkedSurah({293}, 18), isTrue);
      expect(isMarkedSurah({293}, 19), isFalse);
      expect(isMarkedSurah({1, 604}, 114), isTrue);
    });
  });
}
