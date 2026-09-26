import 'package:quranapplication/content/library.dart';
import 'package:quranapplication/audio/recitation.dart';
import 'package:quranapplication/hifz/hifz.dart';
import 'package:quranapplication/quran/tafsir.dart';
import 'package:quranapplication/hijri/hijri.dart';
import 'package:quranapplication/qibla/compass.dart';
import 'package:quranapplication/notifications/planner.dart';
import 'package:quranapplication/notifications/notification_settings.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quranapplication/azkar/azkar.dart';
import 'package:quranapplication/main.dart';
import 'package:quranapplication/core/language.dart';
import 'package:quranapplication/prayer/prayer.dart';
import 'package:quranapplication/providers/ahadith_details_provider.dart';
import 'package:quranapplication/providers/bookmark.dart';
import 'package:quranapplication/providers/quran.dart';
import 'package:quranapplication/providers/reading_provider.dart';
import 'package:quranapplication/providers/theme_provider.dart';
import 'package:quranapplication/quran/quran.dart';
import 'package:quranapplication/quran/search.dart';
import 'package:quranapplication/providers/sebha_provider.dart';
import 'package:quranapplication/settings/backup.dart';
import 'package:quranapplication/providers/settings_provider.dart';
import 'package:quranapplication/tabs/sebha_tab.dart';
import 'package:quranapplication/widget/prayer_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget buildApp(SharedPreferences prefs) => AppRoot(prefs: prefs);

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

  testWidgets('the interface can be switched to English', (tester) async {
    SharedPreferences.setMockInitialValues({
      'seenOnboarding': true,
      SettingsProvider.languageKey: 'en',
    });
    addTearDown(() => appLanguage = AppLanguage.ar);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(buildApp(prefs));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Surah Index'), findsOneWidget);
    expect(find.text('Al Fatiha'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Surah Index'))),
      TextDirection.ltr,
    );

    await tester.tap(find.text('Tasbeeh').last);
    await tester.pumpAndSettle();
    // The dhikr itself stays in Arabic.
    expect(find.text('سبحان الله'), findsWidgets);
    expect(find.text('of 33'), findsOneWidget);
  });

  test('prayer and place names follow the interface language', () async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => appLanguage = AppLanguage.ar);
    final prayer = PrayerProvider(await SharedPreferences.getInstance())
      ..setCity(cities.firstWhere((c) => c.arabicName == 'دمشق'));
    final day = DateTime(2026, 9, 25);
    expect(prayer.placeName, 'دمشق');
    expect(prayer.timesOn(day).first.name, 'الفجر');
    appLanguage = AppLanguage.en;
    expect(prayer.placeName, 'Damascus');
    expect(prayer.timesOn(day).first.name, 'Fajr');
    expect(prayer.method.name, 'Muslim World League');
  });

  testWidgets('main screens label their tap targets for screen readers', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'seenOnboarding': true});
    final prefs = await SharedPreferences.getInstance();
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(buildApp(prefs));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    for (final tab in ['القرآن', 'الأذكار', 'السبحة', 'الأحاديث', 'الصلاة']) {
      final item = find.text(tab);
      if (item.evaluate().isEmpty) continue;
      await tester.tap(item.last);
      await tester.pumpAndSettle();
      await expectLater(
        tester,
        meetsGuideline(labeledTapTargetGuideline),
        reason: tab,
      );
    }
    handle.dispose();
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

    City city(String name) => cities.firstWhere((c) => c.arabicName == name);

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
      final prayer = await at(
        const City('Greenwich', 'Greenwich', 51.48, 0, 'mwl'),
      );
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

    test('home widget gets five prayers a day for a week', () async {
      final prayer = await at(city('دمشق'));
      final now = DateTime(2026, 9, 25, 13);
      final data = prayerWidgetData(prayer, now);
      expect(data['place'], 'دمشق');
      final times = data['times']! as List;
      expect(times, hasLength(35));
      expect(times.map((t) => (t as List)[0]).take(5), [
        'الفجر',
        'الظهر',
        'العصر',
        'المغرب',
        'العشاء',
      ]);
      final millis = [for (final t in times) (t as List)[1] as int];
      for (var i = 1; i < millis.length; i++) {
        expect(millis[i], greaterThan(millis[i - 1]));
      }
      expect(
        millis.first,
        prayer.timesOn(now).first.time.millisecondsSinceEpoch,
      );
    });

    test('home widget has no times without a location', () async {
      SharedPreferences.setMockInitialValues({});
      final prayer = PrayerProvider(await SharedPreferences.getInstance());
      expect(prayerWidgetData(prayer, DateTime(2026, 9, 25))['times'], isEmpty);
    });

    test(
      'qibla direction matches the great-circle bearing to the Kaaba',
      () async {
        // Expected values computed separately with the initial-bearing formula.
        expect((await at(city('لندن'))).qibla, closeTo(118.99, 0.05));
        expect((await at(city('دمشق'))).qibla, closeTo(164.55, 0.05));
        final jakarta = await at(
          const City('Jakarta', 'Jakarta', -6.2088, 106.8456, 'mwl'),
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

  group('Settings and backup', () {
    testWidgets('content text follows the chosen size', (tester) async {
      SharedPreferences.setMockInitialValues({'settings.textScale': 1.5});
      final prefs = await SharedPreferences.getInstance();
      late double size;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(prefs),
          child: Builder(
            builder: (context) {
              size = context.contentSize(20);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(size, 30);
    });

    test('text size is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(SettingsProvider(prefs).textScale, 1.0);
      SettingsProvider(prefs).setTextScale(1.3);
      expect(SettingsProvider(prefs).textScale, 1.3);
    });

    test('a backup restores every kind of saved value', () async {
      SharedPreferences.setMockInitialValues({
        'bookmarks': ['50|1000', '293|2000'],
        'wird.goal': 10,
        'settings.textScale': 1.15,
        'prayer.hanafi': true,
        'prayer.place': 'دمشق',
      });
      final prefs = await SharedPreferences.getInstance();
      final backup = exportBackup(prefs, now: DateTime(2026, 9, 26));

      await prefs.clear();
      await prefs.setInt('sebha.total', 999);
      final restored = await importBackup(prefs, backup);

      expect(restored, 5);
      expect(prefs.getStringList('bookmarks'), ['50|1000', '293|2000']);
      expect(prefs.getInt('wird.goal'), 10);
      expect(prefs.getDouble('settings.textScale'), 1.15);
      expect(prefs.getBool('prayer.hanafi'), isTrue);
      expect(prefs.getString('prayer.place'), 'دمشق');
      expect(
        prefs.getInt('sebha.total'),
        isNull,
        reason: 'replaced, not merged',
      );
      expect(BookMarkProvider(prefs).pages, {50, 293});
    });

    test('a file that is not a backup changes nothing', () async {
      SharedPreferences.setMockInitialValues({'wird.goal': 5});
      final prefs = await SharedPreferences.getInstance();
      for (final bad in [
        'not json',
        '{"app": "other", "data": {}}',
        '{"app": "tareeq-aljannah", "format": 99, "data": {}}',
      ]) {
        await expectLater(
          importBackup(prefs, bad),
          throwsA(isA<BackupException>()),
        );
      }
      expect(prefs.getInt('wird.goal'), 5);
    });
  });

  group('Reminders', () {
    Future<(PrayerProvider, NotificationSettings)> setup([
      Map<String, Object> values = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(values);
      final prefs = await SharedPreferences.getInstance();
      final prayer = PrayerProvider(prefs)
        ..setCity(cities.firstWhere((c) => c.arabicName == 'دمشق'));
      return (prayer, NotificationSettings(prefs));
    }

    test('a full day has 5 prayers, 2 azkar and the wird', () async {
      final (prayer, settings) = await setup();
      final day = DateTime(2026, 9, 26);
      final plan = planNotifications(
        prayer: prayer,
        settings: settings,
        now: day,
        wirdDoneToday: false,
        days: 1,
      );
      expect(plan.where((n) => n.kind == ReminderKind.prayer), hasLength(5));
      expect(plan.where((n) => n.kind == ReminderKind.azkar), hasLength(2));
      expect(plan.where((n) => n.kind == ReminderKind.wird), hasLength(1));

      final times = {for (final t in prayer.timesOn(day)) t.prayer: t.time};
      final morning = plan.firstWhere((n) => n.title == 'أذكار الصباح');
      expect(
        morning.time,
        times[Prayer.fajr]!.add(const Duration(minutes: 20)),
      );
      final wird = plan.firstWhere((n) => n.kind == ReminderKind.wird);
      expect(wird.time, DateTime(2026, 9, 26, 21));
    });

    test('a week of reminders has unique ids and only future times', () async {
      final (prayer, settings) = await setup();
      settings.setMinutesBefore(10);
      final now = DateTime(2026, 9, 26, 13);
      final plan = planNotifications(
        prayer: prayer,
        settings: settings,
        now: now,
        wirdDoneToday: false,
      );
      expect(plan.map((n) => n.id).toSet(), hasLength(plan.length));
      expect(plan.every((n) => n.time.isAfter(now)), isTrue);
      expect(plan.length, lessThan(7 * 13 + 1));
      final before = plan.firstWhere(
        (n) => n.kind == ReminderKind.beforePrayer,
      );
      expect(before.title, contains('10 دقائق'));
    });

    test('choices are respected and saved', () async {
      final (prayer, settings) = await setup();
      settings
        ..setPrayer(Prayer.fajr, false)
        ..setMorningAzkar(false)
        ..setWird(false);
      final plan = planNotifications(
        prayer: prayer,
        settings: settings,
        now: DateTime(2026, 9, 26),
        wirdDoneToday: false,
        days: 1,
      );
      expect(plan.any((n) => n.title.contains('الفجر')), isFalse);
      expect(plan.any((n) => n.title == 'أذكار الصباح'), isFalse);
      expect(plan.any((n) => n.kind == ReminderKind.wird), isFalse);

      final again = NotificationSettings(settings.prefs);
      expect(again.prayerEnabled(Prayer.fajr), isFalse);
      expect(again.prayerEnabled(Prayer.dhuhr), isTrue);
    });

    test('no wird reminder today once the goal is met', () async {
      final (prayer, settings) = await setup();
      final plan = planNotifications(
        prayer: prayer,
        settings: settings,
        now: DateTime(2026, 9, 26, 8),
        wirdDoneToday: true,
        days: 2,
      );
      final wird = plan.where((n) => n.kind == ReminderKind.wird).toList();
      expect(wird, hasLength(1));
      expect(wird.single.time.day, 27);
    });

    test('without a location only the wird reminder is planned', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final plan = planNotifications(
        prayer: PrayerProvider(prefs),
        settings: NotificationSettings(prefs),
        now: DateTime(2026, 9, 26),
        wirdDoneToday: false,
        days: 1,
      );
      expect(plan.map((n) => n.kind), [ReminderKind.wird]);
    });

    test('minutes read naturally', () {
      expect(minutesLabel(5), '5 دقائق');
      expect(minutesLabel(30), '30 دقيقة');
    });
  });

  group('Hijri calendar', () {
    test('matches known Umm al-Qura dates', () {
      final newYear = hijriOf(DateTime(2023, 7, 19));
      expect([newYear.day, newYear.month, newYear.year], [1, 1, 1445]);
      final eid = hijriOf(DateTime(2023, 4, 21));
      expect([eid.day, eid.month, eid.year], [1, 10, 1444]);
      expect(eid.toString(), '1 شوال 1444 هـ');
    });

    test('an offset shifts the date by whole days', () {
      final before = hijriOf(DateTime(2023, 7, 19), offset: -1);
      expect([before.month, before.year], [12, 1444]);
      expect(
        before.day,
        greaterThanOrEqualTo(29),
        reason: 'last day of the month',
      );
      final after = hijriOf(DateTime(2023, 7, 19), offset: 1);
      expect([after.day, after.month, after.year], [2, 1, 1445]);
    });

    test('marks the days of note', () {
      expect(occasionsOn(DateTime(2023, 4, 21)), contains('عيد الفطر المبارك'));
      expect(
        occasionsOn(DateTime(2023, 4, 21)),
        isNot(contains('صيام الست من شوال')),
        reason: 'no fasting on Eid',
      );
      // 9 Dhul Hijjah 1444 was 27 June 2023.
      expect(occasionsOn(DateTime(2023, 6, 27)), contains('يوم عرفة'));
      // 10 Muharram 1445 was 28 July 2023.
      expect(occasionsOn(DateTime(2023, 7, 28)), contains('يوم عاشوراء'));
    });

    test('no fasting suggestions in the days of Tashreeq', () {
      // 13 Dhul Hijjah 1444: a white day, but also Tashreeq.
      final notes = occasionsOn(DateTime(2023, 7, 1));
      expect(notes, contains('من أيام التشريق'));
      expect(notes, isNot(contains('من الأيام البيض')));
    });

    test('Mondays and Thursdays outside Ramadan', () {
      expect(occasionsOn(DateTime(2026, 9, 28)), contains('صيام يوم الاثنين'));
      expect(occasionsOn(DateTime(2026, 10, 1)), contains('صيام يوم الخميس'));
      expect(dayName(DateTime(2026, 9, 26)), 'السبت');
    });
  });

  group('Qibla compass', () {
    const flat = (0.0, 0.0, 9.8);

    test('reads north and east with the phone flat', () {
      // Field pointing along the phone's top edge (and down, as in the
      // northern hemisphere): facing north.
      expect(headingFrom(flat, (0, 20, -40)), closeTo(0, 0.001));
      // North to the phone's left: facing east.
      expect(headingFrom(flat, (-20, 0, -40)), closeTo(90, 0.001));
      expect(headingFrom(flat, (0, -20, -40)), closeTo(180, 0.001));
      expect(headingFrom(flat, (20, 0, -40)), closeTo(270, 0.001));
    });

    test('ignores tilt towards the user', () {
      // Phone tilted 30° up, still facing north.
      final g = (0.0, 9.8 * 0.5, 9.8 * 0.866);
      expect(headingFrom(g, (0, 20, -40)), closeTo(0, 0.001));
    });

    test('no reading without gravity', () {
      expect(headingFrom((0, 0, 0), (0, 20, -40)), isNull);
    });

    test('turn direction takes the short way round', () {
      expect(turnTowards(10, 350), 20);
      expect(turnTowards(350, 10), -20);
      expect(turnTowards(165, 165), 0);
    });

    test('smoothing crosses 0 degrees without spinning', () {
      final smoother = AngleSmoother(factor: 0.5);
      smoother.add(350);
      expect(smoother.add(10), closeTo(0, 0.001));
    });
  });

  group('Tafsir', () {
    late Tafsir tafsir;
    late QuranSearch quran;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tafsir = await Tafsir.load();
      quran = await QuranSearch.load();
    });

    test('has Al-Muyassar text for known ayahs', () {
      expect(tafsir.of(1, 2).text, startsWith('الثناء على الله بصفاته'));
      expect(tafsir.of(114, 6).text, isNotEmpty);
    });

    test('the ﷺ ligature, missing from the fonts, is spelled out', () {
      expect(tafsir.of(1, 7).text, isNot(contains('\uFDFA')));
      expect(tafsir.of(1, 7).text, contains('رسول الله صلى الله عليه وسلم'));
    });

    test('every ayah of the Quran has a tafsir', () {
      for (var page = 1; page <= 604; page++) {
        for (final ayah in quran.ayahsOnPage(page)) {
          expect(
            tafsir.of(ayah.surah, ayah.number).covers(ayah.surah, ayah.number),
            isTrue,
          );
        }
      }
    });

    test('a page lists each explanation once, covering all its ayahs', () {
      final ayahs = quran.ayahsOnPage(1);
      expect(ayahs, hasLength(7));
      final groups = tafsir.forAyahs(ayahs);
      expect(groups.expand((g) => g.$2), hasLength(7));
      expect(groups.map((g) => g.$1).toSet(), hasLength(groups.length));
      for (final (entry, covered) in groups) {
        for (final a in covered) {
          expect(entry.covers(a.surah, a.number), isTrue);
        }
      }
    });

    test('ayahs explained together share one entry', () {
      // Find any multi-ayah entry and check both ayahs resolve to it.
      final page = quran.ayahsOnPage(2);
      final grouped = tafsir.forAyahs(page).where((g) => g.$1.to > g.$1.from);
      for (final (entry, _) in grouped) {
        expect(
          identical(
            tafsir.of(entry.surah, entry.from),
            tafsir.of(entry.surah, entry.to),
          ),
          isTrue,
        );
      }
    });
  });

  group('Memorisation review', () {
    late DateTime now;

    Future<HifzProvider> fresh() async {
      SharedPreferences.setMockInitialValues({});
      return HifzProvider(
        await SharedPreferences.getInstance(),
        clock: () => now,
      );
    }

    setUp(() => now = DateTime(2026, 9, 26, 10));

    test('a new surah is first due tomorrow', () async {
      final hifz = await fresh()
        ..add(67);
      expect(hifz.isMemorised(67), isTrue);
      expect(hifz.due, isEmpty);
      now = now.add(const Duration(days: 1));
      expect(hifz.due.map((e) => e.surah), [67]);
    });

    test('good reviews space out: 1, 3, 7, 14, 30, then 60 days', () async {
      final hifz = await fresh()
        ..add(18);
      final gaps = <int>[];
      now = now.add(const Duration(days: 1));
      for (var i = 0; i < 7; i++) {
        hifz.review(18, good: true);
        final due = hifz.entry(18)!.due;
        final today = DateTime(now.year, now.month, now.day);
        gaps.add(due.difference(today).inDays);
        now = due.add(const Duration(hours: 10));
      }
      expect(gaps, [1, 3, 7, 14, 30, 60, 60]);
    });

    test('a weak review brings the surah back tomorrow', () async {
      final hifz = await fresh()
        ..add(36);
      now = now.add(const Duration(days: 1));
      hifz
        ..review(36, good: true)
        ..review(36, good: true)
        ..review(36, good: false);
      final today = DateTime(now.year, now.month, now.day);
      expect(hifz.entry(36)!.due.difference(today).inDays, 1);
      expect(hifz.entry(36)!.level, 0);
    });

    test('the schedule is saved and overdue surahs come first', () async {
      final hifz = await fresh()
        ..add(1)
        ..add(2);
      now = now.add(const Duration(days: 1));
      hifz.review(2, good: false); // due again tomorrow
      now = now.add(const Duration(days: 2));
      final again = HifzProvider(hifz.prefs, clock: () => now);
      expect(again.due.map((e) => e.surah), [1, 2]);
      again.remove(1);
      expect(
        HifzProvider(hifz.prefs, clock: () => now).isMemorised(1),
        isFalse,
      );
    });
  });

  group('Recitation', () {
    // Shapes of the alquran.cloud responses the app reads.
    const pageBody = '''
{"code":200,"status":"OK","data":{"number":1,"ayahs":[
 {"number":1,"audio":"https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3",
  "text":"...","surah":{"number":1,"name":"سُورَةُ ٱلْفَاتِحَةِ"},"numberInSurah":1,"page":1},
 {"number":2,"audio":"https://cdn.islamic.network/quran/audio/128/ar.alafasy/2.mp3",
  "text":"...","surah":{"number":1,"name":"سُورَةُ ٱلْفَاتِحَةِ"},"numberInSurah":2,"page":1}
]}}''';
    const editionsBody = '''
{"code":200,"status":"OK","data":[
 {"identifier":"ar.alafasy","language":"ar","name":"مشاري العفاسي","format":"audio","type":"versebyverse"},
 {"identifier":"en.walk","language":"en","name":"Ibrahim Walk","format":"audio","type":"versebyverse"}
]}''';

    test('reads the ayahs and audio links of a page', () {
      final ayahs = parsePageAudio(pageBody);
      expect(ayahs.map((a) => '${a.surah}:${a.ayah}'), ['1:1', '1:2']);
      expect(ayahs.first.url, endsWith('/ar.alafasy/1.mp3'));
    });

    test('keeps only Arabic recitations', () {
      expect(parseReciters(editionsBody).map((r) => r.id), ['ar.alafasy']);
    });

    test('rejects an error response', () {
      expect(
        () => parsePageAudio('{"code":404,"status":"NOT FOUND","data":"x"}'),
        throwsFormatException,
      );
    });

    test('plays each ayah once, or repeats it', () {
      const ayahs = [AyahAudio(1, 1, 'a'), AyahAudio(1, 2, 'b')];
      final once = RecitationQueue(ayahs);
      final order = [once.current.ayah];
      while (once.advance()) {
        order.add(once.current.ayah);
      }
      expect(order, [1, 2]);

      final thrice = RecitationQueue(ayahs, repeat: 3);
      final repeated = [thrice.current.ayah];
      while (thrice.advance()) {
        repeated.add(thrice.current.ayah);
      }
      expect(repeated, [1, 1, 1, 2, 2, 2]);
    });

    test('reciter and options are saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final recitation = RecitationProvider(prefs);
      expect(recitation.reciterId, 'ar.alafasy');
      recitation
        ..setReciter('ar.husary')
        ..setRepeat(3)
        ..setContinuous(false);
      final again = RecitationProvider(prefs);
      expect(again.reciter.name, 'محمود خليل الحصري');
      expect([again.repeat, again.continuous], [3, false]);
    });
  });

  group('Hadith and du\'a library', () {
    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test(
      'Riyad as-Salihin has 1896 hadiths in 20 books, Miscellany first',
      () async {
        final books = await loadRiyad();
        expect(books, hasLength(20));
        expect(books.fold<int>(0, (n, b) => n + b.texts.length), 1896);
        expect(books.first.title, 'كتاب المقدمات');
        expect(books.first.texts.first, contains('إنما الأعمال بالنيات'));
        for (final b in books) {
          for (final t in b.texts) {
            expect(t, isNot(contains('\u200f')));
            expect(t, isNot(contains('\u0640')));
          }
        }
      },
    );

    test('forty hadith qudsi', () async {
      expect(await loadQudsi(), hasLength(40));
    });

    test(
      'occasion du\'as leave out the daily azkar and the introduction',
      () async {
        final all = await loadHisn();
        final occasions = await loadOccasionDuas();
        expect(all, hasLength(134));
        final titles = occasions.map((s) => s.title).toSet();
        expect(titles, contains('دعاء السفر'));
        expect(titles, contains('دعاء الكرب'));
        expect(titles, isNot(contains('المقدمة')));
        expect(titles, isNot(contains('أذكار الصباح والمساء')));
        expect(occasions.length, all.length - 5);
      },
    );

    test('ruqyah has the Quranic passages and the prophetic words', () async {
      final ruqyah = await loadRuqyah();
      expect(ruqyah, hasLength(ruqyahPassages.length + 4));
      expect(ruqyah.first.title, 'سورة الفاتحة');
      expect(ruqyah.first.texts.single, contains('﴿7﴾'));
      expect(ruqyah[1].title, 'سورة البقرة · الآية 255');
      expect(ruqyah[2].title, 'سورة البقرة · الآيتان 285–286');
      expect(ruqyah.last.texts, isNotEmpty);
    });

    test('ninety-nine distinct names with corrected diacritics', () async {
      final names = await loadNames();
      expect(names, hasLength(99));
      expect(names.toSet(), hasLength(99));
      expect(names, contains('ٱلرَّافِعُ'));
      expect(
        names.any((n) => n.contains('ٱلْرَّ') || n.contains('ٱلْشَّ')),
        isFalse,
      );
    });
  });
}
