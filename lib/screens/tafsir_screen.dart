import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../providers/settings_provider.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import '../quran/ayah_regions.dart';
import '../quran/tafsir.dart';
import '../quran/tafsir_sources.dart';
import '../share/share_card.dart';
import '../widgets/translation_text.dart';

/// The chosen tafsir for the ayahs on one mushaf page.
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
  /// The page as this mushaf's images show it (a search result's page
  /// number follows another edition on a few pages).
  late int _page = _imagePage(widget.page, widget.focusAyah);
  late final int _focusPage = _page;
  late Future<List<(TafsirEntry, List<Ayah>)>> _groups;
  TafsirSource? _source;
  final _focusKey = GlobalKey();

  static int _imagePage(int page, Ayah? focus) {
    final regions = AyahRegions.loaded;
    if (focus == null || regions == null) return page;
    return regions.pageOf(focus.surah, focus.number) ?? page;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final source = tafsirSource(
      Provider.of<SettingsProvider>(context).tafsirSourceId,
    );
    if (source.id != _source?.id) {
      _source = source;
      _load();
    }
  }

  void _load() {
    final source = _source!;
    final page = _page;
    _groups = () async {
      final regions = await AyahRegions.load();
      final quran = await QuranSearch.load();
      final ayahs = [
        for (final (s, a) in regions.ayahsOn(page))
          quran.ayahsOfSurah(s)[a - 1],
      ];
      return TafsirLibrary.instance.forAyahs(source, ayahs);
    }();
  }

  void _go(int page) {
    if (page < 1 || page > 604) return;
    setState(() {
      _page = page;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = Provider.of<SettingsProvider>(context);
    final source = _source!;

    return Scaffold(
      appBar: AppBar(
        title: Text('${source.name} · ${AppConstant.page} $_page'),
        actions: [
          PopupMenuButton<String>(
            tooltip: tr('اختيار التفسير', 'Choose the tafsir'),
            icon: const Icon(Icons.library_books_rounded),
            initialValue: source.id,
            onSelected: settings.setTafsirSource,
            itemBuilder: (context) => [
              for (final s in tafsirSources)
                CheckedPopupMenuItem(
                  value: s.id,
                  checked: s.id == source.id,
                  child: Text(s.name),
                ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<(TafsirEntry, List<Ayah>)>>(
        future: _groups,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(
                        'يُحمَّل ${source.name} سورةً سورةً عند أول فتح ثم يبقى على هاتفك. تعذّر التحميل الآن؛ تحقق من الإنترنت.',
                        '${source.name} downloads a surah at a time the first time it is opened, then stays on your phone. It could not be downloaded now; check your internet connection.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(_load),
                      child: Text(tr('إعادة المحاولة', 'Retry')),
                    ),
                  ],
                ),
              ),
            );
          }
          final groups = snapshot.data;
          if (groups == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final focus = widget.focusAyah;
          if (focus != null && _page == _focusPage) {
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
                        _page == _focusPage &&
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
