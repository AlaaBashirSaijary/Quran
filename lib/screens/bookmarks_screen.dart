import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../providers/bookmark.dart';
import '../quran/page_data.dart';
import '../quran/quran.dart';
import 'index_screen.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key, this.isTab = false});

  /// Opened from the main tabs rather than from inside the reader.
  final bool isTab;

  static void open(BuildContext context, {required bool isTab}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookmarksScreen(isTab: isTab)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BookMarkProvider>(context);
    final bookmarks = provider.bookmarks;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstant.bookmarks)),
      body: bookmarks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_border_rounded,
                      size: 72,
                      color: colorScheme.gold,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppConstant.noBookmarksYet,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.pageNumber),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookmarks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                return Dismissible(
                  key: ValueKey(bookmark.page),
                  background: _deleteBackground(context),
                  onDismissed: (_) => _remove(context, provider, bookmark),
                  child: _BookmarkCard(
                    bookmark: bookmark,
                    onTap: () =>
                        openQuranPage(context, bookmark.page, isTab: isTab),
                    onDelete: () => _remove(context, provider, bookmark),
                  ),
                );
              },
            ),
    );
  }

  void _remove(
    BuildContext context,
    BookMarkProvider provider,
    Bookmark bookmark,
  ) {
    provider.remove(bookmark.page);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(AppConstant.bookmarkRemoved),
          action: SnackBarAction(
            label: AppConstant.undo,
            onPressed: () => provider.restore(bookmark),
          ),
        ),
      );
  }

  Widget _deleteBackground(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({
    required this.bookmark,
    required this.onTap,
    required this.onDelete,
  });

  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final page = quranPages[bookmark.page - 1];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
        onTap: onTap,
        leading: Icon(Icons.bookmark_rounded, color: colorScheme.gold),
        title: Text(
          'سورة ${getSurahName(bookmark.page)}',
          style: const TextStyle(
            fontFamily: AppTheme.secondaryFontFamily,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${AppConstant.page} ${bookmark.page} · ${AppConstant.juz} ${page.juz}'
          ' · ${_formatDate(bookmark.savedAt)}',
          style: TextStyle(color: colorScheme.pageNumber, fontSize: 13),
        ),
        trailing: IconButton(
          tooltip: 'حذف',
          icon: const Icon(Icons.close_rounded),
          onPressed: onDelete,
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final days = today.difference(day).inDays;
    if (days == 0) return 'اليوم';
    if (days == 1) return 'أمس';
    return '${date.year}/${date.month}/${date.day}';
  }
}
