import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/text_screens.dart';
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
        onTap: installed
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
                  installed
                      ? IconButton(
                          tooltip: tr('حذف من الهاتف', 'Remove from phone'),
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: book.asset != null
                              ? null
                              : () => library.remove(book.id),
                        )
                      : IconButton(
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
