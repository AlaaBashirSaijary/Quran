import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../content/library.dart';
import '../content/text_screens.dart';
import '../kids/garden_screen.dart' show WordGame;
import '../core/index.dart';
import 'book_library.dart';

/// The library: books of Islamic knowledge, downloaded when asked for.
class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = Provider.of<BookLibrary>(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('المكتبة', 'Library'))),
      body: !library.loaded
          ? const Center(child: CircularProgressIndicator())
          : library.books.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    'لا توجد كتب بعد. لا يُضاف كتاب إلا بعد التحقق من نصه '
                        'وترخيصه ومراجعته.',
                    'No books yet. A book is only added after its text, '
                        'licence and review have been checked.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.pageNumber),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (library.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      tr(
                        'تعذّر التنزيل. تحقق من الإنترنت وحاول مرة أخرى.',
                        'The download failed. Check your internet connection and try again.',
                      ),
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                for (final book in library.books) _BookTile(book: book),
              ],
            ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});

  final BookInfo book;

  void _about(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(book.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${tr('المؤلف', 'Author')}: ${book.author}'),
            const SizedBox(height: 6),
            Text('${tr('الطبعة', 'Edition')}: ${book.edition}'),
            const SizedBox(height: 6),
            Text('${tr('الترخيص', 'Licence')}: ${book.license}'),
            const SizedBox(height: 6),
            Text(
              '${tr('المراجعة', 'Reviewed by')}: ${book.reviewer} '
              '(${book.reviewedOn})',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('حسناً', 'OK')),
          ),
        ],
      ),
    );
  }

  /// Shows where to read a book whose text is not in the app.
  void _showLink(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(book.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                'هذا الكتاب يُقرأ على موقعه الأصلي. انسخ الرابط وافتحه في المتصفح.',
                'This book is read on its original website. Copy the link and open it in your browser.',
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              book.link!,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: book.link!));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('نُسخ الرابط', 'Link copied'))),
              );
            },
            child: Text(tr('نسخ الرابط', 'Copy link')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('إغلاق', 'Close')),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, BookLibrary library) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SectionListScreen(
        title: book.title,
        sections: library.sections(book.id),
        source: book.title,
        searchHint: tr('ابحث في الكتاب', 'Search the book (in Arabic)'),
        searchTexts: true,
      ),
    ),
  );

  void _practice(BuildContext context, BookLibrary library) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BookPracticeScreen(
        title: book.title,
        sections: library.sections(book.id),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final library = Provider.of<BookLibrary>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final installed = library.isInstalled(book.id);
    final busy = library.isBusy(book.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: Icon(Icons.menu_book_rounded, color: colorScheme.gold, size: 36),
        title: Text(
          book.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          book.size > 0
              ? '${book.author} · ${(book.size / 1048576).toStringAsFixed(1)} '
                    '${tr('ميغابايت', 'MB')}'
              : book.author,
        ),
        onTap: book.isLink
            ? () => _showLink(context)
            : installed
            ? () => _open(context, library)
            : busy
            ? null
            : () => library.install(book.id),
        trailing: busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: tr('عن الكتاب', 'About the book'),
                    icon: const Icon(Icons.info_outline_rounded),
                    onPressed: () => _about(context),
                  ),
                  if (book.isLink)
                    IconButton(
                      tooltip: tr('رابط الكتاب', 'Book link'),
                      icon: const Icon(Icons.open_in_new_rounded),
                      onPressed: () => _showLink(context),
                    )
                  else if (installed) ...[
                    IconButton(
                      tooltip: tr('تدرّب على الحفظ', 'Practise memorising'),
                      icon: const Icon(Icons.school_rounded),
                      onPressed: () => _practice(context, library),
                    ),
                    IconButton(
                      tooltip: tr('حذف من الهاتف', 'Remove from phone'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: book.asset != null
                          ? null
                          : () => library.remove(book.id),
                    ),
                  ] else
                    IconButton(
                      tooltip: tr('تنزيل', 'Download'),
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () => library.install(book.id),
                    ),
                ],
              ),
      ),
    );
  }
}


/// Practice for a book of verses or short texts: pick a section, then fill
/// in missing words or put the words back in order. The rounds are made from
/// the book's own text, so nothing new is written.
class BookPracticeScreen extends StatelessWidget {
  const BookPracticeScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final Future<List<TextSection>> sections;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('تدرّب: $title', 'Practise: $title'))),
      body: FutureBuilder<List<TextSection>>(
        future: sections,
        builder: (context, snapshot) {
          final list = snapshot.data;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final s in list)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    title: Text(
                      s.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      tr('${s.texts.length} نصاً', '${s.texts.length} texts'),
                    ),
                    trailing: Icon(
                      Icons.chevron_left_rounded,
                      color: colorScheme.gold,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _PracticeSection(section: s),
                      ),
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

class _PracticeSection extends StatefulWidget {
  const _PracticeSection({required this.section});

  final TextSection section;

  @override
  State<_PracticeSection> createState() => _PracticeSectionState();
}

class _PracticeSectionState extends State<_PracticeSection> {
  bool _fill = true;

  Future<void> _finished() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.star_rounded,
          size: 56,
          color: Theme.of(context).colorScheme.gold,
        ),
        content: Text(
          tr('أحسنت! أنهيتَ هذا الباب', 'Well done! You finished this section'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('حسناً', 'OK')),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final texts = [
      for (final t in widget.section.texts) t.replaceAll('\n', ' '),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.section.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text(tr('أكمل', 'Fill in'))),
                ButtonSegment(value: false, label: Text(tr('رتّب', 'Order'))),
              ],
              selected: {_fill},
              onSelectionChanged: (v) => setState(() => _fill = v.first),
            ),
          ),
          Expanded(
            child: WordGame(
              key: ValueKey(_fill),
              texts: texts,
              fill: _fill,
              onDone: _finished,
            ),
          ),
        ],
      ),
    );
  }
}
