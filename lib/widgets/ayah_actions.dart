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
import 'package:provider/provider.dart';
import '../notes/notes.dart';
import '../notes/notes_screen.dart';

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
              if (Provider.of<NotesProvider>(sheet).of(surah, ayah)
                  case final note?)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.edit_note_rounded, color: colorScheme.gold),
                      const SizedBox(width: 8),
                      Expanded(child: Text(note.text)),
                    ],
                  ),
                ),
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
                leading: Icon(Icons.edit_note_rounded, color: colorScheme.gold),
                title: Text(tr('ملاحظة تدبّر', 'Reflection note')),
                onTap: () => act(() => editAyahNote(context, surah, ayah)),
              ),
              ListTile(
                leading: Icon(Icons.repeat_rounded, color: colorScheme.gold),
                title: Text(
                  tr('تكرار مقطع للحفظ', 'Repeat a passage to memorize'),
                ),
                onTap: () async {
                  Navigator.pop(sheet);
                  final choice = await _askRange(
                    context,
                    surah,
                    ayah,
                    quran.ayahsOfSurah(surah).length,
                  );
                  if (choice != null && context.mounted) {
                    startRange(
                      context,
                      surah,
                      ayah,
                      choice.$1,
                      times: choice.$2,
                    );
                  }
                },
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

/// Asks up to which ayah, and how many times, to repeat from [from].
Future<(int, int)?> _askRange(
  BuildContext context,
  int surah,
  int from,
  int count,
) {
  var to = (from + 4).clamp(from, count);
  var times = 3;
  return showDialog<(int, int)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(tr('تكرار مقطع للحفظ', 'Repeat a passage')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                '${surahTitle(surah)}: من الآية $from إلى الآية $to',
                '${surahTitle(surah)}: ayahs $from to $to',
              ),
            ),
            if (count > from)
              Slider(
                value: to.toDouble(),
                min: from.toDouble(),
                max: count.toDouble(),
                divisions: count - from,
                label: '$to',
                onChanged: (v) => setState(() => to = v.round()),
              ),
            const SizedBox(height: 8),
            Text(tr('عدد مرات التكرار', 'Times')),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final n in const [1, 3, 5, 10, 20])
                  ChoiceChip(
                    label: Text('$n'),
                    selected: times == n,
                    onSelected: (_) => setState(() => times = n),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppConstant.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (to, times)),
            child: Text(tr('ابدأ', 'Start')),
          ),
        ],
      ),
    ),
  );
}
