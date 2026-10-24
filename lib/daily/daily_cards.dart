import 'package:flutter/material.dart';

import '../content/library.dart';
import '../core/index.dart';
import '../providers/settings_provider.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import '../screens/index_screen.dart';
import '../share/share_card.dart';
import '../widgets/translation_text.dart';
import 'daily.dart';

/// The ayah of the day, on the Quran tab. Folded to two lines at first, to
/// keep the top of the tab short; the arrow opens the whole ayah.
class AyahOfDayCard extends StatefulWidget {
  const AyahOfDayCard({super.key});

  @override
  State<AyahOfDayCard> createState() => _AyahOfDayCardState();
}

class _AyahOfDayCardState extends State<AyahOfDayCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuranSearch>(
      future: QuranSearch.load(),
      initialData: QuranSearch.loaded,
      builder: (context, snapshot) {
        final quran = snapshot.data;
        final ayah = quran == null
            ? null
            : ayahOfDayText(quran, DateTime.now());
        if (ayah == null) return const SizedBox.shrink();
        final reference = quranReference(
          getSurahNameArabic(ayah.surah),
          ayah.number,
        );
        return _DailyCard(
          title: tr('آية اليوم', 'Ayah of the Day'),
          icon: Icons.auto_awesome_rounded,
          text: ayah.text,
          quran: true,
          caption: '${surahTitle(ayah.surah)} · ${ayahLabel(ayah.number)}',
          extra: _open
              ? TranslationText(ayahs: [(ayah.surah, ayah.number)])
              : null,
          maxLines: _open ? null : 2,
          expanded: _open,
          onToggle: () => setState(() => _open = !_open),
          onTap: () => openQuranPage(context, ayah.page, isTab: true),
          onShare: () => shareAsImage(
            context,
            text: ayah.text,
            reference: reference,
            quran: true,
          ),
        );
      },
    );
  }
}

/// The hadith of the day, on the hadith tab.
class HadithOfDayCard extends StatelessWidget {
  const HadithOfDayCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TextSection>>(
      future: loadRiyad(),
      builder: (context, snapshot) {
        final riyad = snapshot.data;
        final hadith = riyad == null
            ? null
            : hadithOfDay(riyad, DateTime.now());
        if (hadith == null) return const SizedBox.shrink();
        final (book, text) = hadith;
        return _DailyCard(
          title: tr('حديث اليوم', 'Hadith of the Day'),
          icon: Icons.format_quote_rounded,
          text: text,
          caption: 'رياض الصالحين · $book',
          onShare: () => shareAsImage(
            context,
            text: text,
            reference: 'رياض الصالحين · $book',
          ),
        );
      },
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.title,
    required this.icon,
    required this.text,
    required this.caption,
    required this.onShare,
    this.quran = false,
    this.extra,
    this.onTap,
    this.maxLines,
    this.expanded,
    this.onToggle,
  });

  final String title;
  final IconData icon;
  final String text;
  final String caption;
  final bool quran;
  final Widget? extra;
  final VoidCallback onShare;
  final VoidCallback? onTap;

  /// Lines of text to show, or all of it when null.
  final int? maxLines;

  /// When set, the header shows a fold/unfold arrow.
  final bool? expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.gold.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: colorScheme.gold, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: colorScheme.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (expanded != null)
                    IconButton(
                      tooltip: expanded!
                          ? tr('طيّ', 'Fold')
                          : tr('عرض الآية كاملة', 'Show the whole ayah'),
                      icon: Icon(
                        expanded!
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: colorScheme.gold,
                      ),
                      onPressed: onToggle,
                    ),
                  IconButton(
                    tooltip: tr('مشاركة كصورة', 'Share as image'),
                    icon: Icon(
                      Icons.ios_share_rounded,
                      size: 20,
                      color: colorScheme.gold,
                    ),
                    onPressed: onShare,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(
                  text,
                  maxLines: maxLines,
                  overflow: maxLines == null ? null : TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: quran ? AppTheme.secondaryFontFamily : null,
                    fontSize: context.contentSize(quran ? 21 : 16),
                    height: 1.8,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              ?extra,
              const SizedBox(height: 6),
              Text(
                caption,
                style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
