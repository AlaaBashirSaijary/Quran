import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../quran/ayah_regions.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import '../screens/index_screen.dart';
import 'notes.dart';

/// Edits the note on an ayah (an empty note removes it).
Future<void> editAyahNote(BuildContext context, int surah, int ayah) async {
  final notes = Provider.of<NotesProvider>(context, listen: false);
  final controller = TextEditingController(
    text: notes.of(surah, ayah)?.text ?? '',
  );
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        '${tr('تدبّر', 'Reflection')}: '
        '${surahTitle(surah)} · ${ayahLabel(ayah)}',
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 3,
        maxLines: 10,
        decoration: InputDecoration(
          hintText: tr(
            'ما الذي استوقفك في هذه الآية؟',
            'What in this ayah stayed with you?',
          ),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppConstant.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(tr('حفظ', 'Save')),
        ),
      ],
    ),
  );
  disposeAfterDialog([controller]);
  if (text != null) notes.save(surah, ayah, text);
}

/// Every reflection written, newest first, with a filter.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotesScreen()),
    );
  }

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final notes = Provider.of<NotesProvider>(context).all;
    final colorScheme = Theme.of(context).colorScheme;
    final quran = QuranSearch.loaded;
    final needle = normalizeArabic(_query.toLowerCase());
    final shown = [
      for (final n in notes)
        if (needle.length < 2 ||
            normalizeArabic(n.text.toLowerCase()).contains(needle))
          n,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(tr('ملاحظات التدبّر', 'Reflections'))),
      body: notes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    'لا ملاحظات بعد. اضغط مطوّلاً على آية في المصحف ثم «ملاحظة تدبّر».',
                    'No reflections yet. Long-press an ayah in the mushaf, then “Reflection note”.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.pageNumber),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: tr('ابحث في ملاحظاتك', 'Search your notes'),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colorScheme.gold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final n in shown)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        final page =
                            AyahRegions.loaded?.pageOf(n.surah, n.ayah) ??
                            getSurahFirstPage(n.surah);
                        openQuranPage(context, page, isTab: true);
                      },
                      onLongPress: () => editAyahNote(context, n.surah, n.ayah),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${surahTitle(n.surah)} · ${ayahLabel(n.ayah)}',
                              style: TextStyle(
                                color: colorScheme.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (quran != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                quran.ayahsOfSurah(n.surah)[n.ayah - 1].text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: AppTheme.secondaryFontFamily,
                                  fontSize: 18,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(n.text),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
