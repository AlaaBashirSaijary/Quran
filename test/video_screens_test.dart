// Renders many real screens of the app to PNG files, for the promo video.
//
//   VIDEO_FRAMES=<dir> TZ=Asia/Riyadh flutter test test/video_screens_test.dart
//
// The screens come from the app itself with example data (a few
// bookmarks, notes and memorised surahs) so they show the app in use.
// Skipped in ordinary test runs.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quranapplication/hifz/hifz.dart';
import 'package:quranapplication/hijri/calendar_screen.dart';
import 'package:quranapplication/khatma/group_khatma.dart';
import 'package:quranapplication/main.dart';
import 'package:quranapplication/notes/notes.dart';
import 'package:quranapplication/quran/ayah_regions.dart';
import 'package:quranapplication/quran/search.dart';
import 'package:quranapplication/content/library.dart';
import 'package:quranapplication/ramadan/imsakiya_screen.dart';
import 'package:quranapplication/screens/bookmarks_screen.dart';
import 'package:quranapplication/screens/douaa_screen.dart';
import 'package:quranapplication/screens/group_khatma_screen.dart';
import 'package:quranapplication/screens/hifz_screen.dart';
import 'package:quranapplication/screens/juz_index_screen.dart';
import 'package:quranapplication/screens/search_screen.dart';
import 'package:quranapplication/screens/settings_screen.dart';
import 'package:quranapplication/screens/wird_screen.dart';
import 'package:quranapplication/share/share_card.dart';
import 'package:quranapplication/notes/notes_screen.dart';
import 'package:quranapplication/widgets/quran_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _out = Platform.environment['VIDEO_FRAMES'];

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(
        File(f).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }

  await family('diodrum', [
    for (final w in ['Regular', 'Medium', 'Semibold', 'Bold'])
      'assets/fonts/DiodrumArabic-$w.ttf',
  ]);
  await family('uthmanic', [
    'assets/fonts/UthmanicHafs-Regular.ttf',
    'assets/fonts/UthmanicHafs-Bold.ttf',
  ]);
  // Stands in for the system font a phone falls back to for the ornate
  // verse brackets, which the app's own fonts lack.
  const ornament = '/usr/share/fonts/truetype/freefont/FreeSerif.ttf';
  if (File(ornament).existsSync()) await family('ornament', [ornament]);
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  await family('MaterialIcons', [
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

const _base = {
  'seenOnboarding': true,
  'prayer.lat': 21.4225,
  'prayer.lng': 39.8262,
  'prayer.place': 'مكة المكرمة',
  'prayer.method': 'ummAlQura',
  'wird.goal': 5,
  'sebha.count': 21,
  'page': 586,
};

class _Rig {
  _Rig(this.tester);

  final WidgetTester tester;
  final key = GlobalKey();
  late SharedPreferences prefs;

  Future<void> start(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues({..._base, ...values});
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: AppRoot(prefs: prefs),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  BuildContext get context => tester.element(find.byType(Scaffold).first);

  NavigatorState get navigator =>
      tester.state<NavigatorState>(find.byType(Navigator).first);

  Future<void> settle() async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> shot(String name) async {
    await settle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      Directory(_out!).createSync(recursive: true);
      File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> push(Widget screen) async {
    navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
    await settle();
  }

  Future<void> toRoot() async {
    navigator.popUntil((route) => route.isFirst);
    await settle();
  }

  Future<void> back() async {
    navigator.pop();
    await settle();
  }

  Future<void> tab(String label) async {
    await tester.tap(find.text(label).last);
    await settle();
  }
}

/// One failing screen should not lose the others.
Future<void> _step(String name, Future<void> Function() body) async {
  try {
    await body();
    // ignore: avoid_print
    print('captured $name');
  } catch (e) {
    // ignore: avoid_print
    print('FAILED $name: $e');
  }
}

void main() {
  final enabled = _out != null;

  Future<void> prepare(WidgetTester tester) async {
    await tester.runAsync(() async {
      await _loadFonts();
      await QuranSearch.load();
      await AyahRegions.load();
      await loadRiyad();
    });
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('Arabic screens', skip: !enabled, (tester) async {
    await prepare(tester);
    final rig = _Rig(tester);
    final now = DateTime.now().millisecondsSinceEpoch;
    await rig.start({
      'bookmarks': ['586|$now', '50|$now', '255|$now', '1|$now'],
    });

    await _step('index', () async => rig.shot('v01-index'));

    await _step('mushaf', () async {
      await tester.tap(find.text('متابعة القراءة'));
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pump(const Duration(seconds: 2));
      await rig.shot('v02-mushaf');
    });

    await _step('ayah menu and tafsir', () async {
      final page = tester.getRect(find.byType(QuranPage).first);
      final rect = AyahRegions.loaded!.rectsOf(586, 81, 1).first;
      await tester.longPressAt(
        Offset(
          page.left + rect.center.dx * page.width,
          page.top + rect.center.dy * page.height,
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await rig.settle();
      await rig.shot('v03-ayah-menu');
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('التفسير'),
        ),
      );
      await rig.settle();
      await rig.shot('v04-tafsir');
      await rig.back();
    });

    await _step('back to index', () async {
      // Close whatever is open until the index is showing.
      for (var i = 0; i < 4 && find.text('متابعة القراءة').evaluate().isEmpty; i++) {
        await rig.back();
      }
    });

    await _step('text mode', () async {
      rig.prefs.setBool('reader.textMode', true);
      await tester.tap(find.text('متابعة القراءة'));
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pump(const Duration(seconds: 2));
      await rig.shot('v05-text-mode');
      rig.prefs.setBool('reader.textMode', false);
      await rig.back();
    });

    await _step('search', () async {
      await rig.push(const SearchScreen());
      await tester.enterText(find.byType(TextField).first, 'الرحمن');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await rig.shot('v06-search');
      await rig.back();
    });

    await _step('juz', () async {
      await rig.push(const JuzIndexScreen());
      await rig.shot('v07-juz');
      await rig.back();
    });

    await _step('bookmarks', () async {
      await rig.push(const BookmarksScreen());
      await rig.shot('v08-bookmarks');
      await rig.back();
    });

    await _step('notes', () async {
      final ctx = rig.context;
      final notes = ctx.read<NotesProvider>();
      notes.save(94, 5, 'بعد كل ضيق فرَج قريب، فلا أيأس.');
      notes.save(2, 255, 'أقرؤها قبل النوم كل ليلة.');
      notes.save(103, 3, 'الصبر والتواصي بالحق: عملٌ لا كلام فقط.');
      await rig.push(const NotesScreen());
      await rig.shot('v09-notes');
      await rig.back();
    });

    await _step('hifz', () async {
      final hifz = rig.context.read<HifzProvider>();
      for (final s in [112, 113, 114, 67, 78]) {
        hifz.add(s);
      }
      await rig.push(const HifzScreen());
      await rig.shot('v10-hifz');
      await rig.back();
    });

    await _step('wird', () async {
      await rig.push(const WirdScreen());
      await rig.shot('v11-wird');
      await rig.back();
    });

    await _step('prayer', () async {
      await rig.toRoot();
      await rig.tab('الصلاة');
      await rig.shot('v12-prayer');
    });

    await _step('hijri calendar', () async {
      await rig.push(const HijriCalendarScreen());
      await rig.shot('v13-hijri');
      await rig.back();
    });

    await _step('imsakiya', () async {
      await rig.push(const ImsakiyaScreen());
      await rig.shot('v14-imsakiya');
      await rig.back();
    });

    await _step('azkar', () async {
      await rig.toRoot();
      await rig.tab('الأذكار');
      await rig.shot('v15-azkar');
      await tester.tap(find.text('أذكار الصباح'));
      await rig.settle();
      await rig.shot('v16-azkar-category');
      await rig.back();
    });

    await _step('douaa', () async {
      await rig.push(const DouaaScreen());
      await rig.shot('v17-douaa');
      await rig.back();
    });

    await _step('tasbeeh', () async {
      await rig.toRoot();
      await rig.tab('السبحة');
      await rig.shot('v18-tasbeeh');
    });

    await _step('hadith', () async {
      await rig.toRoot();
      await rig.tab('الأحاديث');
      await rig.shot('v19-hadith');
    });

    await _step('group khatma', () async {
      final groups = rig.context.read<GroupKhatmaProvider>();
      final k = groups.create('ختمة رمضان', [
        'أحمد',
        'سارة',
        'عمر',
        'مريم',
        'يوسف',
      ], myName: 'سارة');
      for (final juz in [1, 2, 3, 7, 8, 12]) {
        groups.setDone(k, juz, true);
      }
      await rig.push(GroupKhatmaScreen(id: k.id));
      await rig.shot('v20-group-khatma');
      await rig.back();
    });

    await _step('settings', () async {
      await rig.push(const SettingsScreen());
      await rig.shot('v21-settings');
      await rig.back();
    });
  });

  testWidgets('Night mode', skip: !enabled, (tester) async {
    await prepare(tester);
    final rig = _Rig(tester);
    await rig.start({'themeMode': 'dark'});
    await _step('night index', () async => rig.shot('n01-index'));
    await _step('night mushaf', () async {
      await tester.tap(find.text('متابعة القراءة'));
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pump(const Duration(seconds: 2));
      await rig.shot('n02-mushaf');
      await rig.back();
    });
    await _step('night prayer', () async {
      await rig.toRoot();
      await rig.tab('الصلاة');
      await rig.shot('n03-prayer');
    });
  });

  testWidgets('English interface', skip: !enabled, (tester) async {
    await prepare(tester);
    final rig = _Rig(tester);
    await rig.start({'settings.language': 'en'});
    await _step('english index', () async => rig.shot('e01-index'));
    await _step('english prayer', () async {
      await rig.toRoot();
      await rig.tab('Prayer');
      await rig.shot('e02-prayer');
    });
    await _step('english tasbeeh', () async {
      await rig.toRoot();
      await rig.tab('Tasbeeh');
      await rig.shot('e03-tasbeeh');
    });
  });

  testWidgets('Share card', skip: !enabled, (tester) async {
    await prepare(tester);
    final cardKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'diodrum',
          fontFamilyFallback: const ['ornament'],
        ),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: cardKey,
              child: const ShareCard(
                text: 'إِنَّ مَعَ ٱلۡعُسۡرِ يُسۡرٗا',
                reference: 'سورة الشرح ﴿6﴾',
                quran: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      final boundary =
          cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 6);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      Directory(_out!).createSync(recursive: true);
      File('$_out/v22-share-card.png').writeAsBytesSync(
        png!.buffer.asUint8List(),
      );
    });
  });
}
