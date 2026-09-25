import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quranapplication/azkar/azkar.dart';
import 'package:quranapplication/main.dart';
import 'package:quranapplication/prayer/prayer.dart';
import 'package:quranapplication/providers/ahadith_details_provider.dart';
import 'package:quranapplication/providers/bookmark.dart';
import 'package:quranapplication/providers/quran.dart';
import 'package:quranapplication/providers/reading_provider.dart';
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
      ChangeNotifierProxyProvider<Quran, ReadingProvider>(
        create: (_) => ReadingProvider(prefs),
        update: (_, quran, previous) => previous!..update(quran.currentPage),
      ),
      ChangeNotifierProvider(create: (_) => PrayerProvider(prefs)),
      ChangeNotifierProvider(create: (_) => SebhaProvider(prefs)),
      ChangeNotifierProvider(
        create: (_) => AhadithDetailsProvider()..loadHadithFile(),
      ),
    ],
    child: MyApp(prefs: prefs),
  );
}

void main() {
  testWidgets('first launch shows onboarding, then the main tabs', (
    tester,
  ) async {
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

  testWidgets('sebha counter screen counts taps and can undo', (tester) async {
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

    Future<SebhaProvider> fresh([Map<String, Object> values = const {}]) async {
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

    test(
      'today resets each day and the streak counts consecutive days',
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
      },
    );

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

  testWidgets('ahadith file parses into titled entries with no empty ones', (
    tester,
  ) async {
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

    testWidgets('several pages can be saved, and saving again removes', (
      tester,
    ) async {
      final (bookMark, prefs) = await fresh();
      await tester.pumpWidget(
        host((context) {
          bookMark.toggleCurrentPage(context);
        }),
      );

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

  group('Azkar', () {
    late List<AzkarCategory> categories;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      categories = await loadAzkar();
    });

    test('all categories load with their counts', () {
      expect(
        [for (final c in categories) c.id],
        [
          'morning',
          'evening',
          'afterPrayer',
          'sleep',
          'waking',
          'tasabeeh',
          'quranDuas',
          'prophetsDuas',
        ],
      );
      final morning = categories.first;
      expect(morning.items, hasLength(25));
      expect(morning.items.first.text, startsWith('أَصْبَحْنا'));
      for (final c in categories) {
        for (final d in c.items) {
          expect(d.count, greaterThan(0), reason: d.text);
          expect(d.text, isNot(contains('\u0640')), reason: 'no tatweel');
        }
      }
    });

    test(
      'progress counts down, is kept for the day, and resets next day',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        var now = DateTime(2026, 9, 25, 7);
        final morning = categories.first;
        final threeTimes = morning.items.indexWhere((d) => d.count == 3);

        final progress = AzkarProgress(prefs, morning, clock: () => now);
        expect(progress.tap(threeTimes), isFalse);
        expect(progress.tap(threeTimes), isFalse);
        expect(progress.tap(threeTimes), isTrue);
        expect(progress.isDone(threeTimes), isTrue);
        expect(progress.tap(threeTimes), isFalse, reason: 'already done');

        final later = AzkarProgress(prefs, morning, clock: () => now);
        expect(later.isDone(threeTimes), isTrue);

        now = now.add(const Duration(days: 1));
        final tomorrow = AzkarProgress(prefs, morning, clock: () => now);
        expect(tomorrow.remaining(threeTimes), 3);
        expect(tomorrow.doneCount, 0);
      },
    );

    test('suggests morning azkar before noon and evening ones after asr', () {
      expect(suggestedCategory(DateTime(2026, 1, 1, 6)), 'morning');
      expect(suggestedCategory(DateTime(2026, 1, 1, 17)), 'evening');
      expect(suggestedCategory(DateTime(2026, 1, 1, 13)), isNull);
      expect(suggestedCategory(DateTime(2026, 1, 1, 2)), isNull);
    });
  });

  group('Wird and khatma', () {
    late DateTime now;

    Future<ReadingProvider> fresh([
      Map<String, Object> values = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(values);
      return ReadingProvider(
        await SharedPreferences.getInstance(),
        clock: () => now,
      );
    }

    setUp(() => now = DateTime(2026, 9, 25, 20));

    test('a page counts as read when moving on to the next page', () async {
      final reading = await fresh()
        ..update(10);
      expect(reading.today, 0, reason: 'opening a page is not reading it');
      reading
        ..update(11)
        ..update(12);
      expect(reading.today, 2);
      expect([reading.isRead(10), reading.isRead(11)], [true, true]);
      expect(reading.isRead(12), isFalse, reason: 'still on it');

      reading
        ..update(300)
        ..update(5);
      expect(reading.today, 2, reason: 'jumps do not count');
    });

    test('daily goal, streak and saved progress', () async {
      final reading = await fresh()
        ..setGoal(2);
      for (final page in [1, 2, 3]) {
        reading.update(page);
      }
      expect(reading.goalMet, isTrue);
      expect(reading.streak, 1);

      now = now.add(const Duration(days: 1));
      final nextDay = ReadingProvider(reading.prefs, clock: () => now);
      expect(nextDay.today, 0);
      expect(nextDay.goal, 2);
      expect(nextDay.khatmaRead, 2);
      expect(nextDay.streak, 1, reason: 'yesterday still counts until today');
      expect(nextDay.lastDays(3), [0, 2, 0]);
    });

    test('estimates the days to finish at the goal pace', () async {
      final reading = await fresh()
        ..setGoal(20);
      expect(reading.daysToFinish, 31); // 604 pages at 20 a day
      reading.update(1);
      for (var page = 2; page <= 21; page++) {
        reading.update(page);
      }
      expect(reading.goalMet, isTrue);
      expect(reading.daysToFinish, 30); // 584 left, from tomorrow
    });

    test('reading the last page completes the khatma', () async {
      final reading = await fresh();
      for (var page = 1; page <= totalPages; page++) {
        reading.update(page);
      }
      expect(reading.khatmaRead, totalPages);
      expect(reading.khatmas, 1);
      reading.startNewKhatma();
      expect(reading.khatmaRead, 0);
      expect(reading.khatmas, 1);
    });
  });

  group('Prayer times', () {
    Future<PrayerProvider> at(City city, {String? method}) async {
      SharedPreferences.setMockInitialValues({});
      final prayer = PrayerProvider(await SharedPreferences.getInstance())
        ..setCity(city);
      if (method != null) prayer.setMethod(method);
      return prayer;
    }

    City city(String name) => cities.firstWhere((c) => c.name == name);

    test('no location until one is chosen', () async {
      SharedPreferences.setMockInitialValues({});
      final prayer = PrayerProvider(await SharedPreferences.getInstance());
      expect(prayer.hasLocation, isFalse);
    });

    test('times come in prayer order', () async {
      final prayer = await at(city('دمشق'));
      final times = prayer.timesOn(DateTime(2026, 9, 25));
      expect(
        [for (final t in times) t.name],
        ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'],
      );
      for (var i = 1; i < times.length; i++) {
        expect(times[i].time.isAfter(times[i - 1].time), isTrue);
      }
    });

    test('Umm al-Qura sets isha 90 minutes after maghrib', () async {
      final prayer = await at(city('مكة المكرمة'));
      expect(prayer.method.id, 'ummAlQura');
      final times = prayer.timesOn(DateTime(2026, 3, 10));
      expect(times[5].time.difference(times[4].time).inMinutes, 90);
    });

    test('dhuhr is near solar noon', () async {
      // At longitude 0 solar noon is 12:00 UTC give or take the equation
      // of time (under 17 minutes).
      final prayer = await at(const City('Greenwich', 51.48, 0, 'mwl'));
      final dhuhr = prayer.timesOn(DateTime(2026, 6, 21))[2].time.toUtc();
      final noon = DateTime.utc(2026, 6, 21, 12);
      expect(dhuhr.difference(noon).inMinutes.abs(), lessThan(17));
    });

    test('hanafi asr is later than shafi asr', () async {
      final prayer = await at(city('القاهرة'));
      final day = DateTime(2026, 9, 25);
      final shafi = prayer.timesOn(day)[3].time;
      prayer.setHanafiAsr(true);
      expect(prayer.timesOn(day)[3].time.isAfter(shafi), isTrue);
    });

    test('next prayer rolls over to tomorrow after isha', () async {
      final prayer = await at(city('دمشق'));
      final day = DateTime(2026, 9, 25);
      final isha = prayer.timesOn(day)[5].time;
      final next = prayer.nextPrayer(isha.add(const Duration(minutes: 1)));
      expect(next.name, 'الفجر');
      expect(next.time.isAfter(isha), isTrue);
    });

    test(
      'qibla direction matches the great-circle bearing to the Kaaba',
      () async {
        // Expected values computed separately with the initial-bearing formula.
        expect((await at(city('لندن'))).qibla, closeTo(118.99, 0.05));
        expect((await at(city('دمشق'))).qibla, closeTo(164.55, 0.05));
        final jakarta = await at(
          const City('Jakarta', -6.2088, 106.8456, 'mwl'),
        );
        expect(jakarta.qibla, closeTo(295.15, 0.05));
      },
    );

    test('knows when the location is at the Kaaba', () async {
      expect((await at(city('مكة المكرمة'))).nearKaaba, isTrue);
      expect((await at(city('جدة'))).nearKaaba, isFalse);
    });

    test('location and settings are saved', () async {
      final prayer = await at(city('القاهرة'))
        ..setHanafiAsr(true);
      final again = PrayerProvider(prayer.prefs);
      expect(again.placeName, 'القاهرة');
      expect(again.method.id, 'egyptian');
      expect(again.hanafiAsr, isTrue);
    });
  });
}
