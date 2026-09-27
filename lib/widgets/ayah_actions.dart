import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/player_bar.dart';
import '../core/index.dart';
import '../providers/settings_provider.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import '../screens/tafsir_screen.dart';
import '../share/share_card.dart';
import 'translation_text.dart';

/// What can be done with an ayah long-pressed on a mushaf page.
Future<void> showAyahActions(
  BuildContext context, {
  required int page,
  required int surah,
  required int ayah,
}) async {
  final quran = await QuranSearch.load();
  if (!context.mounted) return;
  final found = quran.ayahsOfSurah(surah).where((a) => a.number == ayah);
  if (found.isEmpty) return;
  final text = found.first;
  final reference = quranReference(getSurahNameArabic(surah), ayah);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final colorScheme = Theme.of(sheet).colorScheme;
      void act(VoidCallback action) {
        Navigator.pop(sheet);
        action();
      }

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheet).size.height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                '${surahTitle(surah)} · ${ayahLabel(ayah)}',
                style: TextStyle(
                  color: colorScheme.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${text.text} ﴿$ayah﴾',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppTheme.secondaryFontFamily,
                  fontSize: sheet.contentSize(22),
                  height: 1.8,
                  color: colorScheme.onSurface,
                ),
              ),
              TranslationText(ayahs: [(surah, ayah)]),
              const Divider(height: 24),
              ListTile(
                leading: Icon(Icons.menu_book_rounded, color: colorScheme.gold),
                title: Text(tr('التفسير', 'Tafsir')),
                onTap: () => act(
                  () => TafsirScreen.open(context, text.page, focusAyah: text),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.play_circle_outline_rounded,
                  color: colorScheme.gold,
                ),
                title: Text(
                  tr('الاستماع من هذه الآية', 'Listen from this ayah'),
                ),
                onTap: () =>
                    act(() => startRecitation(context, from: (surah, ayah))),
              ),
              ListTile(
                leading: Icon(Icons.ios_share_rounded, color: colorScheme.gold),
                title: Text(tr('مشاركة كصورة', 'Share as image')),
                onTap: () => act(
                  () => shareAsImage(
                    context,
                    text: text.text,
                    reference: reference,
                    quran: true,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: colorScheme.gold),
                title: Text(tr('نسخ الآية', 'Copy the ayah')),
                onTap: () => act(() {
                  Clipboard.setData(
                    ClipboardData(text: '${text.text}\n$reference'),
                  );
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(tr('نُسخت الآية', 'Ayah copied'))),
                    );
                }),
              ),
            ],
          ),
        ),
      );
    },
  );
}
