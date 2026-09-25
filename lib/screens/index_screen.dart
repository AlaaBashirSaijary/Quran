import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quranapplication/providers/bookmark.dart';
import 'package:quranapplication/screens/home_screen.dart';
import 'package:quranapplication/widgets/horizontal_divider.dart';
import 'package:quranapplication/widgets/marker.dart';

import '../core/index.dart';
import 'bookmarks_screen.dart';
import '../providers/quran.dart';
import '../providers/show_overlay_provider.dart';
import '../quran/quran.dart';
import '../widgets/surah_number.dart';
import 'juz_index_screen.dart';
import 'search_screen.dart';

/// Opens the Quran reader at [page].
///
/// From a tab there is no reader underneath, so a new one is pushed. From
/// inside the reader the current one jumps to the page and this screen closes.
void openQuranPage(BuildContext context, int page, {required bool isTab}) {
  final quran = Provider.of<Quran>(context, listen: false);
  if (isTab) {
    quran.openAtPage(page);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  } else {
    quran.goToPage(page);
    Provider.of<ShowOverlayProvider>(context, listen: false).hideOverlay();
    Navigator.pop(context);
  }
}

class IndexScreen extends StatelessWidget {
  const IndexScreen({super.key, this.isTab = false});

  final bool isTab;

  @override
  Widget build(BuildContext context) {
    final quran = Provider.of<Quran>(context);
    final bookMark = Provider.of<BookMarkProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstant.surahIndex),
        actions: [
          IconButton(
            tooltip: AppConstant.bookmarks,
            icon: const Icon(Icons.bookmarks_rounded),
            onPressed: () => BookmarksScreen.open(context, isTab: isTab),
          ),
          if (isTab)
            IconButton(
              tooltip: AppConstant.searchAyah,
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchScreen(isTab: true),
                  ),
                );
              },
            ),
          if (isTab)
            IconButton(
              tooltip: AppConstant.ajzaa,
              icon: const Icon(Icons.view_list_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const JuzIndexScreen(isTab: true),
                  ),
                );
              },
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (isTab)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _ContinueReadingCard(
                  surahName: quran.surahName,
                  page: quran.currentPage,
                  onTap: () =>
                      openQuranPage(context, quran.currentPage, isTab: true),
                ),
              ),
            ),
          SliverList.separated(
            itemCount: 114,
            separatorBuilder: (context, index) {
              return HorizontalDiv(color: colorScheme.div);
            },
            itemBuilder: (BuildContext context, int index) {
              final surahNumber = index + 1;
              final page = getSurahFirstPage(surahNumber);
              return Stack(
                children: [
                  ListTile(
                    onTap: () => openQuranPage(context, page, isTab: isTab),
                    visualDensity: const VisualDensity(horizontal: -3),
                    leading: SurahNumber(number: surahNumber),
                    title: Text(
                      getSurahNameArabic(surahNumber),
                      style: TextStyle(
                        fontFamily: AppTheme.secondaryFontFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: colorScheme.juzCardText,
                      ),
                    ),
                    subtitle: Text(
                      getSurahData(surahNumber),
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.pageNumber,
                      ),
                    ),
                    trailing: Text(
                      '$page',
                      style: TextStyle(
                        fontSize: 18,
                        color: colorScheme.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isMarkedSurah(bookMark.pages, surahNumber))
                    const Marker(left: 60, alwaysShow: true),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({
    required this.surahName,
    required this.page,
    required this.onTap,
  });

  final String surahName;
  final int page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    return Material(
      color: isLight ? AppColor.green : AppColor.nightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.gold.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: colorScheme.gold, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'متابعة القراءة',
                      style: TextStyle(color: colorScheme.gold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'سورة $surahName',
                      style: const TextStyle(
                        fontFamily: AppTheme.secondaryFontFamily,
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${AppConstant.page} $page',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: colorScheme.gold),
            ],
          ),
        ),
      ),
    );
  }
}
