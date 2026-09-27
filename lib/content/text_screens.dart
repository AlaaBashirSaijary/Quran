import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/index.dart';
import '../providers/settings_provider.dart';
import '../quran/search.dart' show normalizeArabic;
import '../share/share_card.dart';
import 'library.dart';

/// Texts shown one per card, numbered, with copy on long press.
class TextListScreen extends StatelessWidget {
  const TextListScreen({
    super.key,
    required this.title,
    required this.texts,
    this.quranFont = false,
    this.source,
  });

  final String title;
  final List<String> texts;

  /// The book the texts come from, in Arabic, named on shared images.
  final String? source;

  /// Use the Uthmani font (for Quranic text).
  final bool quranFont;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: texts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, i) => TextCard(
          text: texts[i],
          number: texts.length > 1 ? i + 1 : null,
          quranFont: quranFont,
          shareReference: source == null
              ? null
              : texts.length > 1
              ? '$source (${i + 1})'
              : source,
        ),
      ),
    );
  }
}

class TextCard extends StatelessWidget {
  const TextCard({
    super.key,
    required this.text,
    this.number,
    this.caption,
    this.quranFont = false,
    this.shareReference,
  });

  final String text;
  final int? number;
  final String? caption;
  final bool quranFont;

  /// When set, a share button offers the text as an image citing this.
  final String? shareReference;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(tr('نُسخ النص', 'Text copied'))),
            );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (number != null ||
                  caption != null ||
                  shareReference != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [?caption, if (number != null) '$number'].join(' · '),
                        style: TextStyle(
                          color: colorScheme.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (shareReference case final reference?)
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
                          text: text,
                          reference: reference,
                          quran: quranFont,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                text,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: quranFont ? AppTheme.secondaryFontFamily : null,
                  fontSize: context.contentSize(quranFont ? 22 : 18),
                  height: 1.9,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list of titled sections (books or chapters) with a filter box.
class SectionListScreen extends StatefulWidget {
  const SectionListScreen({
    super.key,
    required this.title,
    required this.sections,
    this.source,
    this.searchHint,
    this.searchTexts = false,
  });

  final String title;
  final Future<List<TextSection>> sections;

  /// The book, in Arabic, named on shared images.
  final String? source;
  final String? searchHint;

  /// Also match the texts themselves, not only the titles.
  final bool searchTexts;

  @override
  State<SectionListScreen> createState() => _SectionListScreenState();
}

class _SectionListScreenState extends State<SectionListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<TextSection>>(
        future: widget.sections,
        builder: (context, snapshot) {
          final sections = snapshot.data;
          if (sections == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final needle = normalizeArabic(_query);
          final textHits = <(TextSection, int)>[];
          final titleHits = <TextSection>[];
          for (final s in sections) {
            if (needle.length < 2 ||
                normalizeArabic(s.title).contains(needle)) {
              titleHits.add(s);
            }
            if (widget.searchTexts && needle.length >= 2) {
              for (var i = 0; i < s.texts.length; i++) {
                if (normalizeArabic(s.texts[i]).contains(needle)) {
                  textHits.add((s, i));
                }
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText:
                      widget.searchHint ??
                      tr('ابحث في العناوين', 'Search the titles'),
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
              for (final s in titleHits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      title: Text(
                        s.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_count(s.texts.length)),
                      trailing: Icon(
                        Icons.chevron_left_rounded,
                        color: colorScheme.gold,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TextListScreen(
                            title: s.title,
                            texts: s.texts,
                            source: widget.source == null
                                ? null
                                : '${widget.source} · ${s.title}',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (textHits.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    tr(
                      'في النصوص (${textHits.length})',
                      'In the texts (${textHits.length})',
                    ),
                    style: TextStyle(color: colorScheme.pageNumber),
                  ),
                ),
                for (final (s, i) in textHits.take(100))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextCard(
                      text: s.texts[i],
                      caption: s.title,
                      number: i + 1,
                      shareReference: widget.source == null
                          ? null
                          : '${widget.source} · ${s.title} (${i + 1})',
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _count(int n) {
    if (isEnglish) return n == 1 ? '1 text' : '$n texts';
    if (n == 1) return 'نص واحد';
    if (n == 2) return 'نصّان';
    if (n <= 10) return '$n نصوص';
    return '$n نصاً';
  }
}

class NamesScreen extends StatelessWidget {
  const NamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('أسماء الله الحسنى', 'The Beautiful Names of Allah')),
      ),
      body: FutureBuilder<List<String>>(
        future: loadNames(),
        builder: (context, snapshot) {
          final names = snapshot.data;
          if (names == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
            ),
            itemCount: names.length + 1,
            itemBuilder: (context, i) {
              if (i == names.length) {
                return Center(
                  child: Text(
                    tr(
                      'القائمة المشهورة للأسماء الحسنى',
                      'The well-known list of the Beautiful Names',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.pageNumber,
                    ),
                  ),
                );
              }
              return Card(
                child: Stack(
                  children: [
                    PositionedDirectional(
                      top: 6,
                      start: 8,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(fontSize: 11, color: colorScheme.gold),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: FittedBox(
                          child: Text(
                            names[i],
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: AppTheme.secondaryFontFamily,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
