import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageByteFormat;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quranapplication/audio/downloads.dart';
import 'package:quranapplication/share/share_card.dart';
import 'package:quranapplication/quran/ayah_regions.dart';
import 'package:quranapplication/quran/translation.dart';
import 'package:quranapplication/quran/tafsir_sources.dart';
import 'package:quranapplication/quran/translations.dart';
import 'package:quranapplication/notes/notes.dart';
import 'package:quranapplication/notes/notes_screen.dart';
import 'package:quranapplication/ramadan/ramadan.dart';
import 'package:quranapplication/hijri/calendar_screen.dart';
import 'package:quranapplication/core/error_log.dart';
import 'package:quranapplication/daily/daily.dart';
import 'package:quranapplication/screens/error_log_screen.dart';
import 'package:quranapplication/ramadan/imsakiya_screen.dart';
import 'package:quranapplication/screens/search_screen.dart';
import 'package:quranapplication/screens/main_tabs_screen.dart';
import 'package:quranapplication/widgets/quran_page.dart';
import 'package:quranapplication/widgets/quran_text_page.dart';

import 'package:quranapplication/content/library.dart';
import 'package:quranapplication/audio/recitation.dart';
import 'package:quranapplication/hifz/hifz.dart';
import 'package:quranapplication/hifz/plan.dart';
import 'package:quranapplication/hifz/plan_screens.dart';
import 'package:quranapplication/quran/tafsir.dart';
import 'package:quranapplication/hijri/hijri.dart';
import 'package:quranapplication/qibla/compass.dart';
import 'package:quranapplication/notifications/planner.dart';
import 'package:quranapplication/notifications/notification_service.dart';
import 'package:quranapplication/notifications/notification_settings.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quranapplication/azkar/azkar.dart';
import 'package:quranapplication/main.dart';
import 'package:quranapplication/core/language.dart';
import 'package:quranapplication/khatma/group_khatma.dart';
import 'package:quranapplication/screens/group_khatma_screen.dart';
import 'package:quranapplication/prayer/prayer.dart';
import 'package:quranapplication/harvest/harvest.dart';
import 'package:quranapplication/screens/home_header.dart';
import 'package:quranapplication/books/book_library.dart';
import 'package:quranapplication/books/books_screen.dart';
import 'package:quranapplication/kids/garden.dart';
import 'package:quranapplication/kids/garden_screen.dart';
import 'package:quranapplication/kids/kids_progress.dart';
import 'package:quranapplication/kids/word_games.dart';
import 'package:quranapplication/kids/kids_screen.dart';
import 'package:quranapplication/harvest/harvest_screen.dart';
import 'package:quranapplication/providers/ahadith_details_provider.dart';
import 'package:quranapplication/providers/bookmark.dart';
import 'package:quranapplication/providers/quran.dart';
import 'package:quranapplication/providers/reading_provider.dart';
import 'package:quranapplication/providers/theme_provider.dart';
import 'package:quranapplication/screens/settings_screen.dart';
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
  // Shared data is loaded once, for real: a first load started inside a
  // widget test's fake time would never finish, and it is cached.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await QuranSearch.load();
    await AyahRegions.load();
    await loadRiyad();
    await Translation.load();
  });

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

  group('Group khatma', () {
    Future<GroupKhatmaProvider> fresh() async {
      SharedPreferences.setMockInitialValues({});
      return GroupKhatmaProvider(
        await SharedPreferences.getInstance(),
        random: Random(1),
      );
    }

    test('the thirty juz are split into even consecutive runs', () {
      expect(distributeJuz(1), everyElement(0));
      final three = distributeJuz(3);
      expect(three.sublist(0, 10), everyElement(0));
      expect(three.sublist(10, 20), everyElement(1));
      expect(three.sublist(20), everyElement(2));
      final seven = distributeJuz(7);
      for (var i = 1; i < 30; i++) {
        expect(seven[i] - seven[i - 1], inInclusiveRange(0, 1));
      }
      final counts = [
        for (var p = 0; p < 7; p++) seven.where((a) => a == p).length,
      ];
      expect(counts.reduce(min), greaterThanOrEqualTo(4));
      expect(counts.reduce(max), lessThanOrEqualTo(5));
      expect(distributeJuz(40).toSet(), hasLength(30));
    });

    test(
      'a shared message lets another phone join, even inside chat text',
      () async {
        final organizer = await fresh();
        final k = organizer.create('ختمة العائلة', ['أحمد', 'مريم', 'Sara']);
        organizer.setDone(k, 3, true);
        final message = khatmaMessage(k);
        expect(message, contains('أحمد'));

        final member = await fresh();
        final pasted = '[26/09/2026, 20:01] Ahmad: $message\nthanks!';
        expect(member.import(pasted), ImportResult.joined);
        final joined = member.byId(k.id)!;
        expect(joined.title, 'ختمة العائلة');
        expect(joined.names, ['أحمد', 'مريم', 'Sara']);
        expect(joined.nameOf(30), 'Sara');
        expect(joined.done, {3});
        expect(joined.myName, isNull, reason: 'the organizer’s choice stays');

        member.setMyName(joined, 'مريم');
        expect(member.import(message), ImportResult.updated);
        expect(member.byId(k.id)!.myName, 'مريم');
        expect(member.khatmas, hasLength(1));
      },
    );

    test('progress messages mark juz done on the organizer’s phone', () async {
      final organizer = await fresh();
      final k = organizer.create('ختمة', ['أحمد', 'مريم']);
      final member = await fresh()
        ..import(khatmaMessage(k));
      final copy = member.byId(k.id)!;
      member
        ..setDone(copy, 16, true)
        ..setDone(copy, 17, true);

      final report = doneMessage(copy, [16, 17]);
      expect(organizer.import('Maryam: $report'), ImportResult.progress);
      expect(organizer.byId(k.id)!.done, {16, 17});

      expect((await fresh()).import(report), ImportResult.unknownKhatma);
      expect(organizer.import('السلام عليكم'), ImportResult.invalid);
      expect(organizer.import('khatma:v1:bm90LWpzb24'), ImportResult.invalid);
    });

    testWidgets('a khatma can be created from the screens', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final groups = GroupKhatmaProvider(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: groups,
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: GroupKhatmaListScreen(),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ختمة جديدة'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'ختمة رمضان');
      for (final name in ['أحمد', 'مريم']) {
        await tester.enterText(find.byType(TextField).at(1), name);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      }
      expect(find.text('الجزء 1–15'), findsOneWidget);
      expect(find.text('الجزء 16–30'), findsOneWidget);
      await tester.tap(find.text('إنشاء الختمة'));
      await tester.pumpAndSettle();

      expect(find.text('ختمة رمضان'), findsOneWidget);
      final k = groups.khatmas.single;
      expect(k.myName, 'أحمد');
      expect(k.juzOf('مريم'), hasLength(15));
    });

    test('khatmas are saved and reloaded', () async {
      final groups = await fresh();
      final k = groups.create('ختمة', ['أحمد', 'مريم'], myName: 'مريم')
        ..done.add(1);
      groups.reassign(k, 30, 0);
      final reloaded = GroupKhatmaProvider(groups.prefs).byId(k.id)!;
      expect(reloaded.myName, 'مريم');
      expect(reloaded.done, {1});
      expect(reloaded.nameOf(30), 'أحمد');
      expect(reloaded.juzOf('مريم'), [for (var j = 16; j <= 29; j++) j]);
    });
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
    expect(find.textContaining('Surah Al Fatiha'), findsOneWidget);
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

  testWidgets('volume keys count on the tasbeeh tab when chosen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'seenOnboarding': true,
      'sebha.volumeKeys': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final captures = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('tareeq/volume'),
      (call) async {
        captures.add(call.arguments);
        return null;
      },
    );
    await tester.pumpWidget(buildApp(prefs));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(captures, isNot(contains(true)), reason: 'not on the Quran tab');

    await tester.tap(find.text('السبحة').last);
    await tester.pumpAndSettle();
    expect(captures.last, isTrue);

    Future<void> press() =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'tareeq/volume',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('press'),
          ),
          (_) {},
        );
    await press();
    await press();
    await tester.pump();
    expect(prefs.getInt('sebha.count'), 2);
    expect(find.text('2'), findsWidgets);

    // A screen opened over the tabs gets its volume keys back.
    final navigator = Navigator.of(tester.element(find.byType(MainTabsScreen)));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    expect(captures.last, isFalse);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(captures.last, isTrue);

    await tester.tap(find.text('القرآن').last);
    await tester.pumpAndSettle();
    expect(captures.last, isFalse);
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
      expect(plan.length, lessThan(7 * 15));
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

    test('the chosen adhan sound is saved and gets its own channel', () async {
      final (_, settings) = await setup();
      expect(settings.adhanUri, isNull);
      expect(NotificationService.prayerChannel(null), 'prayer');

      const uri = 'content://media/external/audio/media/42';
      final before = settings.signature;
      settings.setAdhanSound(uri, 'أذان مكة');
      expect(settings.signature, isNot(before));
      final again = NotificationSettings(settings.prefs);
      expect([again.adhanUri, again.adhanTitle], [uri, 'أذان مكة']);

      final channel = NotificationService.prayerChannel(uri);
      expect(channel, startsWith('prayer_'));
      expect(NotificationService.prayerChannel(uri), channel, reason: 'stable');
      expect(NotificationService.prayerChannel('$uri/2'), isNot(channel));

      settings.setAdhanSound(null, null);
      expect(NotificationSettings(settings.prefs).adhanUri, isNull);
    });

    test(
      'Friday brings Al-Kahf in the morning and du‘a before Maghrib',
      () async {
        final (prayer, settings) = await setup();
        final friday = DateTime(2026, 10, 2);
        expect(friday.weekday, DateTime.friday);
        final plan = planNotifications(
          prayer: prayer,
          settings: settings,
          now: friday,
          wirdDoneToday: false,
          days: 1,
        );
        final times = {
          for (final t in prayer.timesOn(friday)) t.prayer: t.time,
        };
        final fridays = plan
            .where((n) => n.kind == ReminderKind.friday)
            .toList();
        expect(fridays, hasLength(2));
        expect(
          fridays.first.time,
          times[Prayer.sunrise]!.add(const Duration(hours: 2)),
        );
        expect(fridays.first.payload, openKahfPayload);
        expect(
          fridays.last.time,
          times[Prayer.maghrib]!.subtract(const Duration(hours: 1)),
        );

        final saturday = planNotifications(
          prayer: prayer,
          settings: settings,
          now: DateTime(2026, 10, 3),
          wirdDoneToday: false,
          days: 1,
        );
        expect(saturday.any((n) => n.kind == ReminderKind.friday), isFalse);

        settings.setFriday(false);
        expect(NotificationSettings(settings.prefs).friday, isFalse);
        final off = planNotifications(
          prayer: prayer,
          settings: settings,
          now: friday,
          wirdDoneToday: false,
          days: 1,
        );
        expect(off.any((n) => n.kind == ReminderKind.friday), isFalse);
      },
    );

    test('without a location Al-Kahf is still suggested at 10', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final plan = planNotifications(
        prayer: PrayerProvider(prefs),
        settings: NotificationSettings(prefs),
        now: DateTime(2026, 10, 2),
        wirdDoneToday: false,
        days: 1,
      );
      final friday = plan.where((n) => n.kind == ReminderKind.friday);
      expect(friday.single.time, DateTime(2026, 10, 2, 10));
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

  group('Error log', () {
    test('keeps the latest 50 errors with their stack', () async {
      SharedPreferences.setMockInitialValues({});
      final log = ErrorLog.attach(await SharedPreferences.getInstance());
      for (var i = 0; i < 55; i++) {
        log.add(
          StateError('boom $i'),
          StackTrace.fromString('#0 main (file.dart:1)\n#1 run (x.dart:2)'),
          now: DateTime(2026, 9, 27, 12, 0, i),
        );
      }
      expect(log.entries, hasLength(50));
      expect(log.entries.first, contains('boom 5'));
      expect(
        log.entries.last,
        startsWith('2026-09-27T12:00:54  Bad state: boom 54'),
      );
      expect(log.entries.last, contains('#1 run (x.dart:2)'));
      expect(log.report(), startsWith('Manhaj Hayah error log'));
      log.clear();
      expect(log.entries, isEmpty);
    });

    test('stays out of backups and survives a restore', () async {
      SharedPreferences.setMockInitialValues({'wird.goal': 5});
      final prefs = await SharedPreferences.getInstance();
      final log = ErrorLog.attach(prefs)..add('first', null);
      final backup = exportBackup(prefs);
      expect(backup, isNot(contains(ErrorLog.key)));
      log.add('second', null);
      await importBackup(prefs, backup);
      expect(prefs.getInt('wird.goal'), 5);
      expect(log.entries, hasLength(2));
    });

    testWidgets('can be read and cleared', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final log = ErrorLog.attach(await SharedPreferences.getInstance())
        ..add('Something broke', null);
      await tester.pumpWidget(const MaterialApp(home: ErrorLogScreen()));
      expect(find.textContaining('Something broke'), findsOneWidget);
      await tester.tap(find.byTooltip('مسح'));
      await tester.pump();
      expect(log.entries, isEmpty);
      expect(find.text('لا أخطاء مسجّلة'), findsOneWidget);
    });
  });

  group('Monthly harvest', () {
    final now = DateTime(2026, 10, 20, 20);

    test('adds up pages, azkar days and tasbeeh over the last 30 days', () async {
      SharedPreferences.setMockInitialValues({
        // Reading: 3 pages today, 5 yesterday and 4 the day before, a gap,
        // then 1 page eight days ago, and 9 pages 40 days ago (outside).
        'wird.goal': 5,
        'wird.daily':
            '{"2026-10-20":3,"2026-10-19":5,"2026-10-18":4,"2026-10-12":1,"2026-09-10":9}',
        // Azkar: one category done on two days, another not finished.
        'azkar.morning.2026-10-20': ['0', '0'],
        'azkar.morning.2026-10-19': ['0', '0'],
        'azkar.evening.2026-10-19': ['0', '2'],
        'azkar.morning.2026-8-1': ['0', '0'],
        // Tasbeeh taps per day.
        'sebha.dayLog': '{"2026-10-20":40,"2026-10-01":60,"2026-08-01":999}',
      });
      final prefs = await SharedPreferences.getInstance();
      final reading = ReadingProvider(prefs, clock: () => now);
      final sebha = SebhaProvider(prefs, clock: () => now);
      final h = Harvest.compute(reading, sebha, now: now);
      expect(h.days, 30);
      expect(h.pages, 13);
      expect(h.activeDays, 4);
      expect(h.goalDays, 1);
      expect(h.bestStreak, 3);
      expect(h.azkarDays, 2);
      expect(h.tasbeeh, 100);
      expect(h.khatmaPercent, 0);
      expect(h.isEmpty, isFalse);
    });

    test('an empty month is reported as empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final h = Harvest.compute(
        ReadingProvider(prefs, clock: () => now),
        SebhaProvider(prefs, clock: () => now),
        now: now,
      );
      expect(h.isEmpty, isTrue);
      expect(h.pages, 0);
    });

    test('the tasbeeh counts each day as it is tapped', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final sebha = SebhaProvider(prefs, clock: () => now)
        ..tap()
        ..tap();
      expect(sebha.dayLog['2026-10-20'], 2);
      final again = SebhaProvider(prefs, clock: () => now);
      expect(again.dayLog['2026-10-20'], 2);
    });

    testWidgets('the screen shows the card with the numbers', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ReadingProvider(prefs)),
            ChangeNotifierProvider(create: (_) => SebhaProvider(prefs)),
          ],
          child: const MaterialApp(home: HarvestScreen()),
        ),
      );
      expect(find.text('حصادي الشهري'), findsOneWidget);
      expect(find.textContaining('آخر 30 يوماً'), findsOneWidget);
      expect(find.text('منهج حياة'), findsOneWidget);
      expect(find.text('مشاركة الصورة'), findsOneWidget);
    });
  });

  group('Kids corner', () {
    final now = DateTime(2026, 10, 20, 9);

    test('a surah gives one star a day', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var clock = now;
      final kids = KidsProgress(prefs, clock: () => clock);
      expect(kids.totalStars, 0);
      expect(kids.earnToday(112), isTrue);
      expect(kids.earnToday(112), isFalse, reason: 'one star a day');
      expect(kids.earnedToday(112), isTrue);
      clock = now.add(const Duration(days: 1));
      expect(kids.earnedToday(112), isFalse);
      expect(kids.earnToday(112), isTrue);
      kids.addDhikrRound();
      expect(kids.starsFor(112), 2);
      expect(kids.totalStars, 3);
      final again = KidsProgress(prefs, clock: () => clock);
      expect(again.starsFor(112), 2);
      expect(again.dhikrRounds, 1);
    });

    test('every surah in the corner exists', () {
      expect(kidsSurahs.toSet().length, kidsSurahs.length);
      expect(kidsSurahs.every((s) => s >= 1 && s <= 114), isTrue);
    });

    testWidgets('the corner lists the surahs and the star count', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final kids = KidsProgress(prefs)..earnToday(kidsSurahs.first);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: kids,
          child: const MaterialApp(home: KidsCornerScreen()),
        ),
      );
      expect(find.text('ركن الصغار'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text(surahNameOf(kidsSurahs.first)), findsOneWidget);
    });

    testWidgets('a surah screen shows its ayahs and gives the star', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final quran = await tester.runAsync(QuranSearch.load);
      final first = quran!.ayahsOfSurah(112).first.text;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => KidsProgress(prefs)),
            ChangeNotifierProvider(create: (_) => RecitationProvider(prefs)),
          ],
          child: const MaterialApp(home: KidsSurahScreen(surah: 112)),
        ),
      );
      await tester.pump();
      expect(find.text(first), findsOneWidget);
      await tester.tap(find.text('قرأتُها، أعطني نجمة'));
      await tester.pump();
      expect(find.text('أخذتَ نجمة اليوم'), findsOneWidget);
    });
  });

  group('Quran tab header', () {
    testWidgets('shows where you left off and four shortcuts', (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var continued = false;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ReadingProvider(prefs)),
            ChangeNotifierProvider(create: (_) => HifzProvider(prefs)),
            ChangeNotifierProvider(create: (_) => KidsProgress(prefs)),
            ChangeNotifierProvider(create: (_) => SebhaProvider(prefs)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuranHomeHeader(
                surahName: 'البقرة',
                page: 12,
                onContinue: () => continued = true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('متابعة القراءة'), findsOneWidget);
      expect(find.textContaining('سورة البقرة'), findsOneWidget);
      for (final label in ['الورد', 'الحفظ', 'الصغار', 'حصادي']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('متابعة القراءة'));
      expect(continued, isTrue);
      await tester.tap(find.text('الصغار'));
      await tester.pumpAndSettle();
      expect(find.text('ركن الصغار'), findsWidgets);
    });
  });

  group('My garden', () {
    final now = DateTime(2026, 10, 20, 9);

    test('the path starts with Al-Fatiha, then juz Amma by length', () {
      final counts = {for (var s = 78; s <= 114; s++) s: 100 - s};
      final path = gardenPath((s) => s == 1 ? 7 : counts[s]!);
      expect(path.first, 1);
      expect(path.length, 38);
      expect(path.skip(1).first, 114, reason: 'the shortest comes first');
      expect(path.last, 78);
      expect(path.toSet().length, path.length);
    });

    test('a surah grows one stage a day, up to a tree', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var clock = now;
      final garden = GardenProvider(prefs, clock: () => clock);
      expect(garden.stageOf(112), GrowthStage.seed);
      expect(garden.grow(112), GrowthStage.sprout);
      expect(garden.grow(112), isNull, reason: 'once a day');
      expect(garden.grewToday(112), isTrue);
      clock = now.add(const Duration(days: 1));
      expect(garden.grewToday(112), isFalse);
      expect(garden.grow(112), GrowthStage.plant);
      clock = now.add(const Duration(days: 2));
      expect(garden.grow(112), GrowthStage.tree);
      expect(garden.trees, 1);
      clock = now.add(const Duration(days: 3));
      expect(garden.grow(112), isNull, reason: 'a tree is fully grown');
      garden.addReview(112);
      final again = GardenProvider(prefs, clock: () => clock);
      expect(again.stageOf(112), GrowthStage.tree);
      expect(again.reviewsOf(112), 1);
      expect(again.trees, 1);
      again.setEasy(true);
      expect(GardenProvider(prefs).easy, isTrue);
    });

    test('words, hidden words and samples', () {
      expect(wordsOf('  أ ب   ج '), ['أ', 'ب', 'ج']);
      expect(hiddenIndexes(7), {2, 5});
      expect(hiddenIndexes(8, easy: true), {3, 7});
      expect(hiddenIndexes(2), {1}, reason: 'at least one word');
      expect(sampleEvenly([1, 2, 3], 5), [1, 2, 3]);
      expect(sampleEvenly(List.generate(10, (i) => i), 5), [0, 2, 4, 6, 8]);
      expect(seededShuffle([1, 2, 3, 4, 5], 7), seededShuffle([1, 2, 3, 4, 5], 7));
    });

    test('a fill-in round accepts the blanks in order', () {
      final round = FillRound('أ ب ج د هـ و ز', seed: 1);
      expect(round.hidden, {2, 5});
      expect(round.options.toSet(), {'ج', 'و'});
      expect(round.tryPlace('و'), isFalse, reason: 'the first blank is ج');
      expect(round.done, isFalse);
      expect(round.tryPlace('ج'), isTrue);
      expect(round.isFilled(2), isTrue);
      expect(round.isFilled(5), isFalse);
      expect(round.tryPlace('و'), isTrue);
      expect(round.done, isTrue);
    });

    test('an order round accepts the words one after another', () {
      final round = OrderRound('أ ب ج', seed: 3);
      expect(round.options.toSet(), {'أ', 'ب', 'ج'});
      expect(round.tryPlace('ب'), isFalse);
      expect(round.tryPlace('أ'), isTrue);
      expect(round.tryPlace('ب'), isTrue);
      expect(round.placed, ['أ', 'ب']);
      expect(round.done, isFalse);
      expect(round.tryPlace('ج'), isTrue);
      expect(round.done, isTrue);
    });

    Widget app(SharedPreferences prefs, Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => KidsProgress(prefs)),
        ChangeNotifierProvider(create: (_) => GardenProvider(prefs)),
        ChangeNotifierProvider(create: (_) => HifzProvider(prefs)),
        ChangeNotifierProvider(create: (_) => RecitationProvider(prefs)),
      ],
      child: MaterialApp(home: home),
    );

    testWidgets('the garden lists the plots', (tester) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.runAsync(QuranSearch.load);
      await tester.pumpWidget(app(prefs, const GardenScreen()));
      await tester.pump();
      expect(find.text('حديقتي'), findsOneWidget);
      expect(find.textContaining('من 38'), findsOneWidget);
      expect(find.text(surahNameOf(1)), findsOneWidget);
    });

    testWidgets('finishing the first lesson grows the plant', (tester) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.runAsync(QuranSearch.load);
      await tester.pumpWidget(
        app(
          prefs,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LessonScreen(surah: 112),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('استمع'), findsOneWidget);
      await tester.tap(find.text('سمعتُها كاملة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('نمت نبتتك'), findsOneWidget);
      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();
      expect(GardenProvider(prefs).stageOf(112), GrowthStage.sprout);
    });
  });

  group('Book library', () {
    const pack =
        '{"sections":[{"title":"باب أول","texts":["نص أول","نص ثان"]}]}';
    final catalog = jsonEncode({
      'books': [
        {
          'id': 't1',
          'title': 'كتاب تجريبي',
          'author': 'مؤلف تجريبي',
          'edition': 'طبعة تجريبية',
          'license': 'ترخيص تجريبي',
          'reviewer': 'مراجع تجريبي',
          'reviewedOn': '2026-01-01',
          'url': 'https://example.test/t1.json',
          'size': 2048,
        },
        {
          // No reviewer: never listed.
          'id': 't2',
          'title': 'كتاب بلا مراجعة',
          'author': 'مؤلف',
          'edition': 'طبعة',
          'license': 'ترخيص',
          'reviewer': '',
          'reviewedOn': '',
          'url': 'https://example.test/t2.json',
        },
        {
          'id': 't4',
          'title': 'كتاب على موقعه',
          'author': 'مؤلف',
          'edition': 'موقع المصدر',
          'license': 'رابط فقط، لا يُنسخ نصه',
          'reviewer': 'مراجع',
          'reviewedOn': '2026-01-03',
          'link': 'https://example.test/book',
        },
        {
          'id': 't3',
          'title': 'كتاب مضمَّن',
          'author': 'مؤلف',
          'edition': 'طبعة',
          'license': 'ترخيص',
          'reviewer': 'مراجع',
          'reviewedOn': '2026-01-02',
          'asset': 'assets/library/t3.json',
        },
      ],
    });

    BookLibrary fresh(Directory dir, {http.Client? client}) => BookLibrary(
      client: client,
      catalog: () async => catalog,
      folder: () async => dir.path,
      assets: (_) async => pack,
    );

    test('only complete books are listed, bundled ones are installed', () async {
      final dir = Directory.systemTemp.createTempSync('books');
      addTearDown(() => dir.deleteSync(recursive: true));
      final library = fresh(dir);
      await library.load();
      expect(library.books.map((b) => b.id), ['t1', 't4', 't3']);
      expect(library.byId('t4')!.isLink, isTrue);
      expect(library.isInstalled('t4'), isFalse);
      expect(await library.install('t4'), isFalse, reason: 'nothing to download');
      expect(library.isInstalled('t1'), isFalse);
      expect(library.isInstalled('t3'), isTrue);
      final sections = await library.sections('t3');
      expect(sections.single.title, 'باب أول');
      expect(sections.single.texts, ['نص أول', 'نص ثان']);
    });

    test('a book is downloaded once and then read from the phone', () async {
      final dir = Directory.systemTemp.createTempSync('books');
      addTearDown(() => dir.deleteSync(recursive: true));
      var requests = 0;
      final library = fresh(
        dir,
        client: MockClient((request) async {
          requests++;
          return http.Response.bytes(utf8.encode(pack), 200);
        }),
      );
      await library.load();
      expect(await library.install('t1'), isTrue);
      expect(await library.install('t1'), isTrue);
      expect(requests, 1);
      expect(library.isInstalled('t1'), isTrue);
      final again = fresh(dir);
      await again.load();
      expect(again.isInstalled('t1'), isTrue);
      expect((await again.sections('t1')).single.texts.length, 2);
      await again.remove('t1');
      expect(again.isInstalled('t1'), isFalse);
      final last = fresh(dir);
      await last.load();
      expect(last.isInstalled('t1'), isFalse);
    });

    test('a response that is not a book is not kept', () async {
      final dir = Directory.systemTemp.createTempSync('books');
      addTearDown(() => dir.deleteSync(recursive: true));
      final library = fresh(
        dir,
        client: MockClient((request) async => http.Response('not a book', 200)),
      );
      await library.load();
      expect(await library.install('t1'), isFalse);
      expect(library.isInstalled('t1'), isFalse);
      expect(library.error, isNotNull);
      final again = fresh(dir);
      await again.load();
      expect(again.isInstalled('t1'), isFalse);
    });

    test('the bundled catalog lists Tuhfat al-Atfal with its source', () async {
      final json = jsonDecode(
        File('assets/library/catalog.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final books = [
        for (final b in (json['books'] as List).cast<Map<String, dynamic>>())
          BookInfo.fromJson(b),
      ];
      expect(books, hasLength(1));
      expect(books.single.complete, isTrue);
      expect(books.single.reviewer, contains('مقرئ مجاز'));
      final sections = parseBookPack(
        File(books.single.asset!).readAsStringSync(),
      );
      expect(sections.fold<int>(0, (sum, s) => sum + s.texts.length), 61);
    });

    testWidgets('a book can be practised: fill in, then finish', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: BookPracticeScreen(
            title: 'كتاب تجريبي',
            sections: Future.value(parseBookPack(pack)),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('باب أول'));
      await tester.pumpAndSettle();
      expect(find.text('أكمل الكلمات الناقصة'), findsOneWidget);
      await tester.tap(find.text('أول').last);
      await tester.pump();
      await tester.tap(find.text('أحسنت! التالية'));
      await tester.pump();
      await tester.tap(find.text('ثان').last);
      await tester.pump();
      await tester.tap(find.text('أحسنت! إنهاء'));
      await tester.pumpAndSettle();
      expect(find.textContaining('أنهيتَ هذا الباب'), findsOneWidget);
    });

    Widget screen(BookLibrary library) => ChangeNotifierProvider.value(
      value: library,
      child: const MaterialApp(home: BooksScreen()),
    );

    testWidgets('an empty library says why', (tester) async {
      final library = BookLibrary(
        catalog: () async => '{"books": []}',
        folder: () async => null,
      );
      await tester.runAsync(library.load);
      await tester.pumpWidget(screen(library));
      expect(find.text('المكتبة'), findsOneWidget);
      expect(find.textContaining('لا توجد كتب بعد'), findsOneWidget);
    });

    testWidgets('a listed book opens in the reader', (tester) async {
      final library = BookLibrary(
        catalog: () async => catalog,
        folder: () async => null,
        assets: (_) async => pack,
      );
      await tester.runAsync(library.load);
      await tester.pumpWidget(screen(library));
      expect(find.text('كتاب مضمَّن'), findsOneWidget);
      expect(find.text('كتاب تجريبي'), findsOneWidget);
      expect(find.text('كتاب بلا مراجعة'), findsNothing);
      await tester.tap(find.text('كتاب مضمَّن'));
      await tester.pumpAndSettle();
      expect(find.text('باب أول'), findsOneWidget);
    });

    testWidgets('a linked book shows its address and copies it', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final library = BookLibrary(
        catalog: () async => catalog,
        folder: () async => null,
        assets: (_) async => pack,
      );
      await tester.runAsync(library.load);
      await tester.pumpWidget(screen(library));
      await tester.tap(find.text('كتاب على موقعه'));
      await tester.pumpAndSettle();
      expect(find.text('https://example.test/book'), findsOneWidget);
      await tester.tap(find.text('نسخ الرابط'));
      await tester.pumpAndSettle();
      expect(copied, ['https://example.test/book']);
    });
  });

  group('Memorisation plan', () {
    // Three small surahs: 3, 4 and 7 ayahs, in the counts of surahs 1 to 3.
    final counts = [for (var s = 1; s <= 114; s++) s == 1 ? 7 : s == 2 ? 3 : s == 3 ? 4 : 5];
    final now = DateTime(2026, 10, 29, 9);

    Future<HifzPlanProvider> fresh([DateTime Function()? clock]) async {
      SharedPreferences.setMockInitialValues({});
      return HifzPlanProvider(
        await SharedPreferences.getInstance(),
        clock: clock ?? () => now,
        ayahCounts: counts,
      );
    }

    test('scopes list the surahs in order', () {
      expect(surahsOf(PlanScope.juzAmmaBackwards).first, 114);
      expect(surahsOf(PlanScope.juzAmmaBackwards).last, 78);
      expect(surahsOf(PlanScope.juzAmmaForwards).first, 78);
      expect(surahsOf(PlanScope.wholeForwards), hasLength(114));
      expect(surahsOf(PlanScope.wholeBackwards).first, 114);
    });

    test('a session never crosses the end of a surah', () async {
      final plan = await fresh();
      plan.create(surahs: [2, 3, 1], perDay: 3);
      expect(plan.next, const PlanPortion(2, 1, 3));
      expect(plan.completesSurah(plan.next!), isTrue);
      expect(plan.completeToday(), const PlanPortion(2, 1, 3));
      expect(plan.doneToday, isTrue);
      expect(plan.completeToday(), isNull, reason: 'one session a day');
      expect(plan.next, const PlanPortion(3, 1, 3));
      expect(plan.completesSurah(plan.next!), isFalse);
    });

    test('the plan moves on a day at a time and counts the sessions', () async {
      var clock = now;
      final plan = await fresh(() => clock);
      plan.create(surahs: [2, 3, 1], perDay: 3);
      // 3 ayahs -> 1 session; 4 -> 2 (3 + 1); 7 -> 3 (3 + 3 + 1).
      expect(plan.sessionsLeft, 6);
      expect(sessionsFor([2, 3, 1], 3, counts), 6);
      expect(plan.progress, 0);
      plan.completeToday();
      expect(plan.done, 3);
      expect(plan.sessionsLeft, 5);
      expect(plan.streak, 1);
      clock = now.add(const Duration(days: 1));
      expect(plan.doneToday, isFalse);
      expect(plan.streak, 1, reason: 'yesterday still counts');
      expect(plan.next, const PlanPortion(3, 1, 3));
      plan.completeToday();
      expect(plan.next, const PlanPortion(3, 4, 4));
      expect(plan.streak, 2);
      // A missed day carries on and the end moves.
      clock = now.add(const Duration(days: 3));
      expect(plan.streak, 0);
      expect(plan.next, const PlanPortion(3, 4, 4));
      expect(plan.estimatedEnd, DateTime(2026, 11, 1, 0, 0).add(const Duration(days: 3)));
    });

    test('finishing the path ends the plan', () async {
      var clock = now;
      final plan = await fresh(() => clock);
      plan.create(surahs: [2], perDay: 10);
      plan.completeToday();
      expect(plan.finished, isTrue);
      expect(plan.next, isNull);
      expect(plan.progress, 1);
    });

    test('the plan and its history are saved', () async {
      final plan = await fresh();
      plan.create(surahs: [2, 3], perDay: 2);
      plan.completeToday();
      plan.markReviewed();
      final again = HifzPlanProvider(plan.prefs, clock: () => now, ayahCounts: counts);
      expect(again.surahs, [2, 3]);
      expect(again.perDay, 2);
      expect(again.done, 2);
      expect(again.doneToday, isTrue);
      expect(again.recent(), [const PlanPortion(2, 1, 2)]);
      expect(again.reviewedToday, isTrue);
      again.clear();
      expect(again.hasPlan, isFalse);
      expect(HifzPlanProvider(plan.prefs, ayahCounts: counts).hasPlan, isFalse);
    });

    Widget app(SharedPreferences prefs, HifzPlanProvider plan, Widget home) =>
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: plan),
            ChangeNotifierProvider(create: (_) => HifzProvider(prefs)),
            ChangeNotifierProvider(create: (_) => RecitationProvider(prefs)),
          ],
          child: MaterialApp(home: home),
        );

    testWidgets('set up a plan, then do the first session', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.runAsync(QuranSearch.load);
      final quran = QuranSearch.loaded!;
      final real = HifzPlanProvider(
        prefs,
        ayahCounts: [for (var s = 1; s <= 114; s++) quran.ayahsOfSurah(s).length],
      );
      await tester.pumpWidget(app(prefs, real, const HifzPlanScreen()));
      await tester.pump();
      expect(find.text('ابدأ خطة'), findsOneWidget);
      await tester.tap(find.text('ابدأ خطة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('تنتهي الخطة بعد'), findsOneWidget);
      await tester.tap(find.text('ابدأ الخطة'));
      await tester.pumpAndSettle();
      expect(real.hasPlan, isTrue);
      expect(find.text('جلسة اليوم'), findsOneWidget);
      // An-Nas has 6 ayahs, learnt 3 at a time.
      expect(real.next, const PlanPortion(114, 1, 3));
      await tester.tap(find.text('ابدأ الجلسة'));
      await tester.pumpAndSettle();
      expect(find.text('التالي: اختبر نفسك'), findsOneWidget);
      await tester.tap(find.text('التالي: اختبر نفسك'));
      await tester.pumpAndSettle();
      expect(find.text('أكمل الكلمات الناقصة'), findsOneWidget);
    });
  });

  group('Settings about section', () {
    testWidgets('shows the developer credit and copies the contacts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
            ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      expect(find.textContaining('ألاء بشير سيجري'), findsWidgets);
      expect(find.text('شارك التطبيق'), findsOneWidget);
      expect(shareAppMessage(), contains(appLink));
      expect(appLink, contains('/get/'));
      await tester.ensureVisible(find.text(contactEmail));
      await tester.tap(find.text(contactEmail));
      await tester.pump();
      await tester.ensureVisible(find.text(contactTelegram));
      await tester.tap(find.text(contactTelegram));
      await tester.pump();
      expect(copied, [contactEmail, contactTelegram]);
    });
  });

  group('Ayah and hadith of the day', () {
    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test('every listed ayah exists and days take them in turn', () async {
      final quran = await QuranSearch.load();
      for (final (s, a) in dailyAyahs) {
        expect(
          a,
          lessThanOrEqualTo(quran.ayahsOfSurah(s).length),
          reason: '$s:$a',
        );
      }
      expect(dailyAyahs.toSet(), hasLength(dailyAyahs.length));
      final today = DateTime(2026, 9, 28);
      final tomorrow = DateTime(2026, 9, 29);
      expect(ayahOfDay(today), isNot(ayahOfDay(tomorrow)));
      expect(ayahOfDay(DateTime(2026, 9, 28, 23, 59)), ayahOfDay(today));
      expect(
        ayahOfDay(today.add(Duration(days: dailyAyahs.length))),
        ayahOfDay(today),
      );
      expect(ayahOfDayText(quran, today)!.surah, ayahOfDay(today).$1);
    });

    test('the hadith of the day is of moderate length', () async {
      final riyad = await loadRiyad();
      final (book, text) = hadithOfDay(riyad, DateTime(2026, 9, 28))!;
      expect(book, isNotEmpty);
      expect(text.length, inInclusiveRange(80, 450));
      expect(hadithOfDay(riyad, DateTime(2026, 9, 29))!.$2, isNot(text));
    });

    test('a morning notification carries the ayah', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final quran = await QuranSearch.load();
      final settings = NotificationSettings(prefs);
      List<PlannedNotification> plan() => planNotifications(
        prayer: PrayerProvider(prefs),
        settings: settings,
        now: DateTime(2026, 9, 28),
        wirdDoneToday: false,
        days: 1,
        ayahOfDay: (day) => ayahOfDayText(quran, day),
      );
      final daily = plan().singleWhere((n) => n.kind == ReminderKind.daily);
      expect(daily.time, DateTime(2026, 9, 28, 9));
      expect(
        daily.body,
        contains(ayahOfDayText(quran, DateTime(2026, 9, 28))!.text),
      );
      settings.setDailyAyah(false);
      expect(plan().any((n) => n.kind == ReminderKind.daily), isFalse);
    });
  });

  group('Voluntary fasts', () {
    // Dates checked against the hijri-converter (Umm al-Qura) package.
    test('the evening before a recommended fast gets a note', () {
      expect(fastingReminderFor(DateTime(2027, 5, 15)), 'غداً يوم عرفة');
      expect(fastingReminderFor(DateTime(2026, 6, 25)), 'غداً يوم عاشوراء');
      expect(fastingReminderFor(DateTime(2026, 6, 24)), contains('تاسوعاء'));
      expect(
        fastingReminderFor(DateTime(2026, 9, 24)),
        contains('الأيام البيض'),
      );
      expect(
        fastingReminderFor(DateTime(2027, 3, 10)),
        contains('الست من شوال'),
      );
      expect(fastingReminderFor(DateTime(2026, 9, 28)), contains('الاثنين'));
    });

    test('nothing on forbidden days, in Ramadan, or twice a week unasked', () {
      expect(
        fastingReminderFor(DateTime(2026, 9, 25)),
        isNull,
        reason: 'white 14',
      );
      expect(fastingReminderFor(DateTime(2027, 3, 9)), isNull, reason: 'Eid');
      expect(
        fastingReminderFor(DateTime(2027, 5, 17)),
        isNull,
        reason: 'Tashreeq',
      );
      expect(
        fastingReminderFor(DateTime(2027, 2, 8)),
        isNull,
        reason: 'Ramadan',
      );
      expect(fastingReminderFor(DateTime(2026, 9, 28), weekly: false), isNull);
    });

    test(
      'is planned after Isha the day before, and can be turned off',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final prayer = PrayerProvider(prefs)
          ..setCity(cities.firstWhere((c) => c.arabicName == 'دمشق'));
        final settings = NotificationSettings(prefs);
        List<PlannedNotification> plan() => planNotifications(
          prayer: prayer,
          settings: settings,
          now: DateTime(2026, 9, 27),
          wirdDoneToday: false,
          days: 1,
        );
        final fast = plan().where((n) => n.kind == ReminderKind.fasting);
        final isha = prayer.timesOn(DateTime(2026, 9, 27)).last.time;
        expect(fast.single.time, isha.add(const Duration(minutes: 30)));
        expect(fast.single.body, contains('الاثنين'));
        settings.setFastingWeekly(false);
        expect(plan().any((n) => n.kind == ReminderKind.fasting), isFalse);
        settings
          ..setFastingWeekly(true)
          ..setFasting(false);
        expect(plan().any((n) => n.kind == ReminderKind.fasting), isFalse);
        expect(NotificationSettings(prefs).fasting, isFalse);
      },
    );
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

    test('a range can be looped as a whole', () {
      const a = AyahAudio(1, 1, 'a');
      const b = AyahAudio(1, 2, 'b');
      final queue = RecitationQueue([a, b], repeat: 2, loops: 2);
      final played = [queue.current.ayah];
      while (queue.advance()) {
        played.add(queue.current.ayah);
      }
      expect(played, [1, 1, 2, 2, 1, 1, 2, 2]);
      expect(queue.loop, 3, reason: 'past the last pass');
    });

    test('a page plays the ayahs its image shows', () async {
      SharedPreferences.setMockInitialValues({});
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(request.url.path);
        final surah = int.parse(request.url.pathSegments[2]);
        final count = surah == 80 ? 42 : 29;
        return http.Response(
          jsonEncode({
            'code': 200,
            'data': {
              'ayahs': [
                for (var a = 1; a <= count; a++)
                  {
                    'numberInSurah': a,
                    'audio': 'https://cdn.test/$surah/$a.mp3',
                  },
              ],
            },
          }),
          200,
        );
      });
      final recitation = RecitationProvider(
        await SharedPreferences.getInstance(),
        client: client,
      );
      // In this mushaf 80:41-42 open page 586, before At-Takwir.
      final audio = await recitation.pageAudio(586);
      expect(audio.first.surah, 80);
      expect(audio.first.ayah, 41);
      expect(audio.first.url, 'https://cdn.test/80/41.mp3');
      expect(audio.last.ayah, 29);
      expect(audio, hasLength(31));
      final before = requests.length;
      await recitation.pageAudio(586);
      expect(requests.length, before, reason: 'surah links are cached');
    });

    testWidgets('the sleep timer stops the recitation', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final recitation = RecitationProvider(
        await SharedPreferences.getInstance(),
      );
      recitation.setSleepTimer(const Duration(minutes: 15));
      expect(recitation.sleepAt, isNotNull);
      await tester.pump(const Duration(minutes: 14));
      expect(recitation.sleepAt, isNotNull);
      await tester.pump(const Duration(minutes: 2));
      expect(recitation.sleepAt, isNull);
      expect(recitation.status, RecitationStatus.idle);
      recitation.setSleepTimer(const Duration(minutes: 5));
      recitation.setSleepTimer(null);
      expect(recitation.sleepAt, isNull);
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

  group('Hijri calendar', () {
    test('a month runs from its first to its last Hijri day', () {
      final ramadan = hijriMonthDays(DateTime(2027, 2, 20));
      expect(ramadan.first, DateTime(2027, 2, 8));
      expect(ramadan.last, DateTime(2027, 3, 8));
      expect(ramadan.map((d) => hijriOf(d).day), [
        for (var i = 1; i <= 29; i++) i,
      ]);
      final shifted = hijriMonthDays(DateTime(2027, 2, 20), offset: 1);
      expect(shifted.first, DateTime(2027, 2, 7));
    });

    test('weekly fasts can be left out of the day marks', () {
      final monday = DateTime(2026, 9, 28);
      expect(monday.weekday, DateTime.monday);
      expect(occasionsOn(monday), contains('صيام يوم الاثنين'));
      expect(
        occasionsOn(monday, weekly: false),
        isNot(contains('صيام يوم الاثنين')),
      );
    });

    testWidgets('shows the month and the notes of a tapped day', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(prefs),
          child: MaterialApp(
            home: HijriCalendarScreen(today: DateTime(2027, 2, 20)),
          ),
        ),
      );
      expect(find.text('رمضان 1448'), findsOneWidget);
      expect(find.text('8/2'), findsOneWidget);
      expect(find.text('8/3'), findsOneWidget);
      await tester.tap(find.text('8/2'));
      await tester.pump();
      expect(find.text('شهر رمضان المبارك'), findsOneWidget);

      await tester.tap(find.byTooltip('الشهر التالي'));
      await tester.pump();
      expect(find.text('شوال 1448'), findsOneWidget);
      await tester.tap(find.text('9/3'));
      await tester.pump();
      expect(find.text('عيد الفطر المبارك'), findsOneWidget);
    });
  });

  group('Ramadan', () {
    Future<PrayerProvider> damascus() async {
      SharedPreferences.setMockInitialValues({});
      return PrayerProvider(await SharedPreferences.getInstance())
        ..setCity(cities.firstWhere((c) => c.arabicName == 'دمشق'));
    }

    test('the days of Ramadan 1448 follow Umm al-Qura', () {
      // Checked against the hijri-converter (Umm al-Qura) Python package.
      final days = ramadanDays(DateTime(2026, 9, 27));
      expect(days.first, DateTime(2027, 2, 8));
      expect(days.last, DateTime(2027, 3, 8));
      expect(days, hasLength(29));
      expect(ramadanDays(DateTime(2027, 2, 20)), days);
      expect(
        ramadanDays(DateTime(2026, 9, 27), offset: 1).first,
        DateTime(2027, 2, 7),
      );
    });

    test('the countdown to Ramadan starts in the second half of Sha‘ban', () {
      expect(daysUntilRamadan(DateTime(2027, 2, 1)), 7);
      expect(daysUntilRamadan(DateTime(2027, 1, 1)), isNull);
      expect(daysUntilRamadan(DateTime(2027, 2, 10)), isNull);
    });

    test('suhoor ends at Fajr and iftar is at Maghrib', () async {
      final prayer = await damascus();
      final day = DateTime(2027, 2, 10);
      final t = fastingTimes(prayer, day);
      expect(t.fajr.difference(t.imsak), imsakBefore);
      expect(nextFastingMoment(prayer, DateTime(2027, 2, 10, 1)), (
        FastingMoment.suhoor,
        t.fajr,
      ));
      expect(nextFastingMoment(prayer, DateTime(2027, 2, 10, 12)), (
        FastingMoment.iftar,
        t.maghrib,
      ));
      final evening = nextFastingMoment(prayer, DateTime(2027, 2, 10, 22));
      expect(evening!.$1, FastingMoment.suhoor);
      expect(evening.$2, fastingTimes(prayer, DateTime(2027, 2, 11)).fajr);
      // The eve of Ramadan points to the first suhoor; the last night to none.
      expect(
        nextFastingMoment(prayer, DateTime(2027, 2, 7, 22))!.$2,
        fastingTimes(prayer, DateTime(2027, 2, 8)).fajr,
      );
      expect(nextFastingMoment(prayer, DateTime(2027, 3, 8, 22)), isNull);
      expect(nextFastingMoment(prayer, DateTime(2026, 9, 27, 12)), isNull);
    });

    test('a suhoor reminder comes before Fajr on fasting days only', () async {
      final prayer = await damascus();
      final settings = NotificationSettings(prayer.prefs);
      List<PlannedNotification> plan(DateTime day) => planNotifications(
        prayer: prayer,
        settings: settings,
        now: day,
        wirdDoneToday: false,
        days: 1,
      );
      final fajr = fastingTimes(prayer, DateTime(2027, 2, 10)).fajr;
      final suhoor = plan(
        DateTime(2027, 2, 10),
      ).where((n) => n.kind == ReminderKind.ramadan);
      expect(suhoor.single.time, fajr.subtract(suhoorBefore));
      expect(
        plan(DateTime(2026, 9, 26)).any((n) => n.kind == ReminderKind.ramadan),
        isFalse,
      );
      settings.setSuhoor(false);
      expect(
        plan(DateTime(2027, 2, 10)).any((n) => n.kind == ReminderKind.ramadan),
        isFalse,
      );
    });

    testWidgets('the timetable offers a juz-a-day khatma', (tester) async {
      final prayer = await damascus();
      final reading = ReadingProvider(prayer.prefs);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: prayer),
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(prayer.prefs),
            ),
            ChangeNotifierProvider.value(value: reading),
          ],
          child: const MaterialApp(home: ImsakiyaScreen()),
        ),
      );
      expect(find.text('ختمة رمضان'), findsOneWidget);
      expect(find.text('الإمساك'), findsOneWidget);
      await tester.tap(find.text('اعتماد'));
      await tester.pump();
      expect(reading.goal, 20);
    });
  });

  group('English translation', () {
    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test('covers every ayah and finds English words', () async {
      final translation = await Translation.load();
      final quran = await QuranSearch.load();
      for (var s = 1; s <= 114; s++) {
        final count = quran.ayahsOfSurah(s).length;
        expect(translation.of(s, count), isNotEmpty);
      }
      expect(
        translation.of(2, 255),
        startsWith('Allah - there is no deity except Him'),
      );
      final (found, total) = translation.search('Ever-Living Sustainer');
      expect(found, contains((2, 255)));
      expect(total, found.length);
      expect(translation.search('x').$2, 0);
      // Words match from their start, not inside other words.
      final (mercy, _) = translation.search('merci');
      expect(mercy, contains((1, 1)));
      expect(translation.search('ercif').$2, 0);
    });

    test('is shown by default only in the English interface', () async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(() => appLanguage = AppLanguage.ar);
      final settings = SettingsProvider(await SharedPreferences.getInstance());
      expect(settings.showTranslation, isFalse);
      appLanguage = AppLanguage.en;
      expect(settings.showTranslation, isTrue);
      settings.setShowTranslation(false);
      expect(settings.showTranslation, isFalse);
    });

    testWidgets('an English search finds ayahs by their meaning', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.runAsync(() async {
        await QuranSearch.load();
        await Translation.load();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(prefs)..setShowTranslation(true),
          child: const MaterialApp(home: SearchScreen()),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.enterText(
        find.byType(TextField),
        'Sustainer of all existence',
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(
        find.textContaining('the Ever-Living, the Sustainer'),
        findsWidgets,
      );
    });
  });

  test('backups made under the former name still restore', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await importBackup(
      prefs,
      jsonEncode({
        'app': 'tareeq-aljannah',
        'format': 1,
        'data': {
          'wird.goal': {'int': 10},
        },
      }),
    );
    expect(prefs.getInt('wird.goal'), 10);
    expect(exportBackup(prefs), contains('"app": "manhaj-hayah"'));
  });

  group('Reflection notes', () {
    test('are saved per ayah, newest first, and empty text removes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notes = NotesProvider(prefs)
        ..save(2, 255, ' عظمة الله ', now: DateTime(2026, 9, 1))
        ..save(1, 5, 'الاستعانة', now: DateTime(2026, 9, 2));
      expect(notes.of(2, 255)!.text, 'عظمة الله');
      expect(notes.all.map((n) => n.ayah), [5, 255]);

      final again = NotesProvider(prefs);
      expect(again.of(1, 5)!.updated, DateTime(2026, 9, 2));
      again.save(1, 5, '   ');
      expect(again.of(1, 5), isNull);
      expect(NotesProvider(prefs).all, hasLength(1));
    });

    test('travel in backups', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      NotesProvider(prefs).save(3, 8, 'دعاء الثبات');
      final backup = exportBackup(prefs);
      await prefs.clear();
      await importBackup(prefs, backup);
      expect(NotesProvider(prefs).of(3, 8)!.text, 'دعاء الثبات');
    });

    testWidgets('the notes screen lists and filters', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notes = NotesProvider(prefs)
        ..save(2, 255, 'آية الكرسي قبل النوم')
        ..save(94, 5, 'بعد العسر يسر');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notes,
          child: const MaterialApp(home: NotesScreen()),
        ),
      );
      expect(find.text('آية الكرسي قبل النوم'), findsOneWidget);
      expect(find.text('بعد العسر يسر'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'العسر');
      await tester.pump();
      expect(find.text('آية الكرسي قبل النوم'), findsNothing);
      expect(find.text('بعد العسر يسر'), findsOneWidget);
    });
  });

  group('More translations', () {
    test(
      'a language is downloaded once and then read from the phone',
      () async {
        final temp = Directory.systemTemp.createTempSync('translations');
        addTearDown(() => temp.deleteSync(recursive: true));
        var requests = 0;
        final quranJson = jsonEncode([
          for (var s = 1; s <= 114; s++)
            {
              'id': s,
              'verses': [
                {'id': 1, 'text': '...', 'translation': ' ترجمہ $s '},
              ],
            },
        ]);
        Translations make() => Translations(
          client: MockClient((request) async {
            requests++;
            expect(request.url.path, endsWith('/quran_ur.json'));
            return http.Response.bytes(utf8.encode(quranJson), 200);
          }),
          folder: Future.value(temp.path),
        );

        final first = make();
        expect(await first.isDownloaded('ur'), isFalse);
        expect(await first.load('ur'), isNull);
        final urdu = await first.download('ur');
        expect(urdu.of(2, 1), 'ترجمہ 2');
        expect(requests, 1);

        final later = make();
        // Asked for at the same time, the file is read once.
        final both = await Future.wait([later.load('ur'), later.load('ur')]);
        expect(identical(both[0], both[1]), isTrue);
        expect(await later.isDownloaded('ur'), isTrue);
        expect((await later.load('ur'))!.of(114, 1), 'ترجمہ 114');
        expect(requests, 1);
        expect(await later.isDownloaded('en'), isTrue, reason: 'bundled');
      },
    );

    test('a broken download is not kept', () async {
      final temp = Directory.systemTemp.createTempSync('translations');
      addTearDown(() => temp.deleteSync(recursive: true));
      final translations = Translations(
        client: MockClient((_) async => http.Response('[]', 200)),
        folder: Future.value(temp.path),
      );
      await expectLater(translations.download('fr'), throwsFormatException);
      expect(await translations.isDownloaded('fr'), isFalse);
    });

    test('Urdu reads right to left; unknown codes fall back to English', () {
      expect(translationLanguage('ur').direction, TextDirection.rtl);
      expect(translationLanguage('fr').direction, TextDirection.ltr);
      expect(translationLanguage('xx').code, 'en');
      expect(
        translationLanguages.map((l) => l.code).toSet(),
        hasLength(translationLanguages.length),
      );
    });
  });

  group('More tafsirs', () {
    test('an entry covers the ayahs up to the next one', () {
      final entries = parseSurahTafsir(
        jsonEncode([
          {'surah': '1', 'ayah': '1', 'text': 'first'},
          {'surah': 1, 'ayah': 3, 'text': ' third '},
          {'surah': 1, 'ayah': 4, 'text': ''},
          {'surah': 1, 'ayah': 6, 'text': 'sixth'},
        ]),
        1,
        7,
      );
      expect(
        [for (final e in entries) (e.from, e.to, e.text)],
        [(1, 2, 'first'), (3, 5, 'third'), (6, 7, 'sixth')],
      );
    });

    test('a surah is downloaded once, with a fallback mirror', () async {
      final temp = Directory.systemTemp.createTempSync('tafsir');
      addTearDown(() => temp.deleteSync(recursive: true));
      final requests = <String>[];
      MockClient client() => MockClient((request) async {
        requests.add(request.url.host);
        if (request.url.host.contains('jsdelivr')) {
          return http.Response('', 503);
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              for (var a = 1; a <= 7; a++)
                {'surah': 1, 'ayah': a, 'text': 'تفسير $a'},
            ]),
          ),
          200,
        );
      });
      final saadi = tafsirSource('saadi');
      final library = TafsirLibrary(
        client: client(),
        folder: Future.value(temp.path),
      );
      final entries = await library.surah(saadi, 1);
      expect(entries, hasLength(7));
      expect(entries[1].text, 'تفسير 2');
      expect(requests, ['cdn.jsdelivr.net', 'raw.githubusercontent.com']);

      // Another start reads the saved file without the network.
      requests.clear();
      final again = TafsirLibrary(
        client: client(),
        folder: Future.value(temp.path),
      );
      expect((await again.surah(saadi, 1)).last.text, 'تفسير 7');
      expect(requests, isEmpty);
    });

    test('a response that does not parse is not kept', () async {
      final temp = Directory.systemTemp.createTempSync('tafsir');
      addTearDown(() => temp.deleteSync(recursive: true));
      var good = false;
      final library = TafsirLibrary(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              good
                  ? jsonEncode([
                      {'surah': 1, 'ayah': 1, 'text': 'تفسير'},
                    ])
                  : '<html>error</html>',
            ),
            200,
          ),
        ),
        folder: Future.value(temp.path),
      );
      final saadi = tafsirSource('saadi');
      await expectLater(library.surah(saadi, 1), throwsA(anything));
      expect(temp.listSync(recursive: true).whereType<File>(), isEmpty);
      good = true;
      expect((await library.surah(saadi, 1)).single.text, 'تفسير');
    });

    test('the Muyassar stays bundled', () async {
      final muyassar = tafsirSource(null);
      expect(muyassar.bundled, isTrue);
      final entries = await TafsirLibrary(
        client: MockClient((_) async => throw StateError('no network')),
      ).surah(muyassar, 112);
      expect(entries, isNotEmpty);
    });
  });

  group('Ayahs on the mushaf page', () {
    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test(
      'every ayah is placed once, in reading order, inside the page',
      () async {
        final regions = await AyahRegions.load();
        final order = <(int, int)>[];
        for (var page = 1; page <= 604; page++) {
          for (final (surah, ayah) in regions.ayahsOn(page)) {
            order.add((surah, ayah));
            final rects = regions.rectsOf(page, surah, ayah);
            expect(rects, isNotEmpty, reason: '$surah:$ayah on page $page');
            for (final r in rects) {
              expect(r.left, greaterThanOrEqualTo(0));
              expect(r.right, lessThanOrEqualTo(1));
              expect(r.top, greaterThanOrEqualTo(0));
              expect(r.bottom, lessThanOrEqualTo(1));
              expect(r.width, greaterThan(0));
            }
          }
        }
        final quran = await QuranSearch.load();
        final expected = [
          for (var s = 1; s <= 114; s++)
            for (final a in quran.ayahsOfSurah(s)) (a.surah, a.number),
        ];
        expect(order, expected);
      },
    );

    test(
      'pages follow the mushaf: surahs begin where the index says',
      () async {
        final regions = await AyahRegions.load();
        for (var s = 1; s <= 114; s++) {
          final page = getSurahFirstPage(s);
          expect(regions.ayahsOn(page), contains((s, 1)), reason: 'surah $s');
        }
      },
    );

    test('a touch finds the ayah under it', () async {
      final regions = await AyahRegions.load();
      final rect = regions.rectsOf(586, 81, 1).first;
      expect(regions.ayahAt(586, rect.center), (81, 1));
      expect(regions.ayahAt(586, const Offset(0.5, 0.005)), isNull);
    });

    testWidgets('text mode shows the page’s ayahs with surah headers', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final quran = (await tester.runAsync(() async {
        await AyahRegions.load();
        return QuranSearch.load();
      }))!;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => RecitationProvider(prefs)),
            ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: QuranTextPage(page: 586)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('سورة التكوير'), findsOneWidget);
      // The basmala before At-Takwir, and the end of Abasa above it.
      expect(find.text(quran.ayahsOfSurah(1).first.text), findsOneWidget);
      final text = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((r) => r.text.toPlainText())
          .join('\n');
      expect(text, contains(quran.ayahsOfSurah(80)[40].text));
      expect(text, contains('${quran.ayahsOfSurah(81).last.text} ﴿٢٩﴾'));
    });

    testWidgets('double tap zooms the page in and out', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => RecitationProvider(prefs),
          child: const MaterialApp(
            home: Scaffold(body: QuranPage(pageIndex: 2)),
          ),
        ),
      );
      final viewer = find.byType(InteractiveViewer);
      Future<void> doubleTap() async {
        await tester.tap(viewer);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(viewer);
        await tester.pumpAndSettle();
      }

      expect(readerZoomed.value, isFalse);
      await doubleTap();
      expect(readerZoomed.value, isTrue);
      expect(
        tester
            .widget<InteractiveViewer>(viewer)
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        2,
      );
      await doubleTap();
      expect(readerZoomed.value, isFalse);
    });

    testWidgets('long-pressing an ayah opens its actions', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.runAsync(() async {
        await AyahRegions.load();
        await QuranSearch.load();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => RecitationProvider(prefs)),
            ChangeNotifierProvider(create: (_) => NotesProvider(prefs)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(child: QuranPage(pageIndex: 585)),
              ),
            ),
          ),
        ),
      );
      final page = tester.getRect(find.byType(QuranPage));
      final rect = AyahRegions.loaded!.rectsOf(586, 81, 1).first;
      await tester.longPressAt(
        Offset(
          page.left + rect.center.dx * page.width,
          page.top + rect.center.dy * page.height,
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('سورة التكوير · الآية 1'), findsOneWidget);
      expect(find.text('التفسير'), findsOneWidget);
      expect(find.text('مشاركة كصورة'), findsOneWidget);
    });
  });

  group('Share as image', () {
    test('Quran references cite the surah and ayahs in Arabic', () {
      expect(quranReference('البقرة', 255), 'سورة البقرة ﴿255﴾');
      expect(quranReference('البقرة', 285, 286), 'سورة البقرة ﴿285–286﴾');
      expect(quranReference('الإخلاص', 1, 1), 'سورة الإخلاص ﴿1﴾');
    });

    testWidgets('the card renders as a 1080-pixel-wide image', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShareCardScreen(
            text: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
            reference: 'سورة البقرة ﴿255﴾',
            quran: true,
          ),
        ),
      );
      expect(find.text('سورة البقرة ﴿255﴾'), findsOneWidget);
      expect(find.text('منهج حياة'), findsOneWidget);

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(
              of: find.byType(ShareCard),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      final width = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final png = await image.toByteData(format: ImageByteFormat.png);
        expect(png!.lengthInBytes, greaterThan(1000));
        final w = image.width;
        image.dispose();
        return w;
      });
      expect(width, 1080);

      await tester.tap(find.byIcon(Icons.light_mode_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    });
  });

  group('Saved recitations', () {
    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    late Directory temp;
    late List<String> requested;
    var failAudio = false;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('recitations');
      requested = [];
      failAudio = false;
    });
    tearDown(() => temp.deleteSync(recursive: true));

    MockClient client() => MockClient((request) async {
      final url = request.url.toString();
      requested.add(url);
      if (url.contains('/surah/1/ar.alafasy')) {
        return http.Response(
          jsonEncode({
            'code': 200,
            'data': {
              'number': 1,
              'ayahs': [
                for (var a = 1; a <= 7; a++)
                  {'numberInSurah': a, 'audio': 'https://cdn.test/$a.mp3'},
              ],
            },
          }),
          200,
        );
      }
      if (url.startsWith('https://cdn.test/')) {
        return failAudio
            ? http.Response('', 500)
            : http.Response.bytes([1, 2, 3, 4], 200);
      }
      return http.Response('', 404);
    });

    Future<AudioDownloads> downloads([
      Map<String, Object> prefs = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(prefs);
      final d = AudioDownloads(
        await SharedPreferences.getInstance(),
        client: client(),
        folder: Future.value(temp.path),
      );
      await d.ready;
      return d;
    }

    test('a surah is saved and page 1 then plays without internet', () async {
      final d = await downloads();
      await d.download('ar.alafasy', [1]);
      expect(d.isDownloaded('ar.alafasy', 1), isTrue);
      expect(d.progress, isEmpty);
      expect(File('${temp.path}/ar.alafasy/1/7.mp3').readAsBytesSync(), [
        1,
        2,
        3,
        4,
      ]);
      expect(await d.size(), 28);
      expect(d.localUri('ar.husary', 1, 1), isNull);

      requested.clear();
      final recitation = RecitationProvider(d.prefs, downloads: d);
      final audio = await recitation.pageAudio(1);
      expect(audio.map((a) => a.ayah), [1, 2, 3, 4, 5, 6, 7]);
      expect(audio.first.url, startsWith('file://'));
      expect(requested, isEmpty, reason: 'no network needed');

      await d.delete('ar.alafasy', 1);
      expect(d.isDownloaded('ar.alafasy', 1), isFalse);
      expect(Directory('${temp.path}/ar.alafasy/1').existsSync(), isFalse);
    });

    test('a failed download reports an error and saves nothing', () async {
      failAudio = true;
      final d = await downloads();
      await d.download('ar.alafasy', [1]);
      expect(d.isDownloaded('ar.alafasy', 1), isFalse);
      expect(d.error, isNotNull);
      expect(d.progress, isEmpty);
    });

    test(
      'downloads listed in a restored backup but missing are dropped',
      () async {
        final d = await downloads({
          'audio.downloads': ['ar.alafasy|1'],
        });
        expect(d.isDownloaded('ar.alafasy', 1), isFalse);
        expect(d.prefs.getStringList('audio.downloads'), isEmpty);
      },
    );
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
