// Renders the main screens to PNG files for the README.
//
//   SCREENSHOTS=1 TZ=Asia/Riyadh flutter test test/screenshots_test.dart
//
// (the time zone of Makkah, whose prayer times are shown)
// writes docs/screenshots/*.png (CI uploads them as the "screenshots"
// artifact). Skipped in ordinary test runs.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quranapplication/main.dart';
import 'package:quranapplication/share/share_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _enabled = Platform.environment['SCREENSHOTS'] == '1';
const _out = 'docs/screenshots';

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
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  await family('MaterialIcons', [
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  // Let images decode and animations finish.
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory(_out).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('screenshots', skip: !_enabled, (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'seenOnboarding': true,
      'prayer.lat': 21.4225,
      'prayer.lng': 39.8262,
      'prayer.place': 'مكة المكرمة',
      'prayer.method': 'ummAlQura',
      'wird.goal': 5,
      'sebha.count': 21,
    });
    final prefs = await SharedPreferences.getInstance();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: AppRoot(prefs: prefs),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await _shot(tester, key, '1-quran');

    await tester.tap(find.text('الصلاة').last);
    await tester.pumpAndSettle();
    await _shot(tester, key, '2-prayer');

    await tester.tap(find.text('الأذكار').last);
    await tester.pumpAndSettle();
    await _shot(tester, key, '3-azkar');

    await tester.tap(find.text('السبحة').last);
    await tester.pumpAndSettle();
    await _shot(tester, key, '4-tasbeeh');

    await tester.tap(find.text('القرآن').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('متابعة القراءة'));
    await tester.pump(const Duration(seconds: 1));
    // Let the hizb toast fade.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump(const Duration(seconds: 2));
    await _shot(tester, key, '5-mushaf');

    // The same page read as text.
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();
    prefs.setBool('reader.textMode', true);
    await tester.tap(find.text('متابعة القراءة'));
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump(const Duration(seconds: 2));
    await _shot(tester, key, '7-text-mode');

    // A shared-ayah card on its own.
    final cardKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
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
    await _shot(tester, cardKey, '6-share-card');
  });
}
