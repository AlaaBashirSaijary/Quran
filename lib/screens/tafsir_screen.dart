import 'package:flutter/material.dart';

import '../core/index.dart';
import '../providers/settings_provider.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import '../quran/tafsir.dart';
import '../share/share_card.dart';
import '../widgets/translation_text.dart';

/// Al-Tafsir al-Muyassar for the ayahs on one mushaf page.
class TafsirScreen extends StatefulWidget {
  const TafsirScreen({super.key, required this.page, this.focusAyah});

  final int page;

  /// Scroll to this ayah's tafsir, e.g. when opened from a search result.
  final Ayah? focusAyah;

  static void open(BuildContext context, int page, {Ayah? focusAyah}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TafsirScreen(page: page, focusAyah: focusAyah),
      ),
    );
  }

  @override
  State<TafsirScreen> createState() => _TafsirScreenState();
}

class _TafsirScreenState extends State<TafsirScreen> {
  late int _page = widget.page;
  late final Future<(QuranSearch, Tafsir)> _data = Future.wait([
    QuranSearch.load(),
    Tafsir.load(),
  ]).then((r) => (r[0] as QuranSearch, r[1] as Tafsir));
  final _focusKey = GlobalKey();

  void _go(int page) {
    if (page < 1 || page > 604) return;
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(
            'التفسير الميسر · ${AppConstant.page} $_page',
            'Tafsir al-Muyassar · ${AppConstant.page} $_page',
          ),
        ),
      ),
      body: FutureBuilder(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final (quran, tafsir) = data;
          final groups = tafsir.forAyahs(quran.ayahsOnPage(_page));
          final focus = widget.focusAyah;
          if (focus != null && _page == widget.page) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final target = _focusKey.currentContext;
              if (target != null) Scrollable.ensureVisible(target);
            });
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  key: PageStorageKey(_page),
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final (entry, ayahs) = groups[index];
                    final isFocus =
                        focus != null &&
                        _page == widget.page &&
                        ayahs.any(
                          (a) =>
                              a.surah == focus.surah &&
                              a.number == focus.number,
                        );
                    return _TafsirCard(
                      key: isFocus ? _focusKey : null,
                      entry: entry,
                      ayahs: ayahs,
                      highlight: isFocus,
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      // RTL: the next page is to the left, like a book.
                      TextButton.icon(
                        onPressed: _page > 1 ? () => _go(_page - 1) : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: Text(tr('السابقة', 'Previous')),
                      ),
                      const Spacer(),
                      Text(
                        '${AppConstant.page} $_page',
                        style: TextStyle(color: colorScheme.pageNumber),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _page < 604 ? () => _go(_page + 1) : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: Text(tr('التالية', 'Next')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TafsirCard extends StatelessWidget {
  const _TafsirCard({
    super.key,
    required this.entry,
    required this.ayahs,
    required this.highlight,
  });

  final TafsirEntry entry;
  final List<Ayah> ayahs;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surahName = surahNameOf(entry.surah);
    final range = entry.from == entry.to
        ? tr('الآية ${entry.from}', 'Ayah ${entry.from}')
        : tr(
            'الآيات ${entry.from}–${entry.to}',
            'Ayahs ${entry.from}–${entry.to}',
          );

    return Card(
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.gold, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('سورة $surahName · $range', 'Surah $surahName · $range'),
                    style: TextStyle(
                      color: colorScheme.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: tr('مشاركة كصورة', 'Share as image'),
                  icon: Icon(
                    Icons.ios_share_rounded,
                    size: 20,
                    color: colorScheme.gold,
                  ),
                  onPressed: () => shareAsImage(
                    context,
                    text: ayahs.map((a) => '${a.text} ﴿${a.number}﴾').join(' '),
                    reference: quranReference(
                      getSurahNameArabic(entry.surah),
                      ayahs.first.number,
                      ayahs.last.number,
                    ),
                    quran: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ayahs.map((a) => '${a.text} ﴿${a.number}﴾').join(' '),
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.secondaryFontFamily,
                fontSize: context.contentSize(22),
                height: 1.9,
                color: colorScheme.primary,
              ),
            ),
            TranslationText(
              ayahs: [for (final a in ayahs) (a.surah, a.number)],
            ),
            Divider(color: colorScheme.div, height: 24),
            Text(
              entry.text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: context.contentSize(17),
                height: 1.9,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
