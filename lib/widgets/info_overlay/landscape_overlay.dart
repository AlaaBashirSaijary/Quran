import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:quranapplication/providers/bookmark.dart';
import 'package:quranapplication/providers/theme_provider.dart';
import 'package:quranapplication/widgets/custom_container.dart';
import 'package:provider/provider.dart';

import '../../audio/player_bar.dart';
import '../../core/index.dart';
import '../../screens/tafsir_screen.dart';
import '../../screens/bookmarks_screen.dart';
import '../../providers/quran.dart';
import '../../providers/show_overlay_provider.dart';
import '../go_to_page_popup.dart';
import '../horizontal_divider.dart';
import '../vertical_divider.dart';
import 'info_text.dart';

class LandscapeOverlay extends StatelessWidget {
  const LandscapeOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final quran = Provider.of<Quran>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final bookMark = Provider.of<BookMarkProvider>(context);
    final overlay = Provider.of<ShowOverlayProvider>(context, listen: false);

    const textStyle = TextStyle(color: Colors.white, fontSize: 15);

    void openBookmarks() {
      BookmarksScreen.open(context, isTab: false);
    }

    return CustomContainer(
      child: Column(
        children: [
          Row(
            children: [
              InfoText(
                text: '${AppConstant.page} ${quran.currentPage}',
                svgIcon: AppAsset.page,
              ),
              const SizedBox(width: 5),
              InfoText(
                text: '${AppConstant.juz} ${quran.juz}',
                svgIcon: AppAsset.part,
              ),
              const SizedBox(width: 5),
              InfoText(text: quran.hizbText),
              const SizedBox(width: 5),
              InfoText(text: quran.surahData, svgIcon: AppAsset.book),
              const Spacer(),
              IconButton(
                tooltip: tr('استماع للتلاوة', 'Listen'),
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  startRecitation(context);
                  overlay.hideOverlay();
                },
              ),
              IconButton(
                tooltip: bookMark.isMarkedPage
                    ? tr('إزالة العلامة المرجعية', 'Remove bookmark')
                    : tr('إضافة علامة مرجعية', 'Add bookmark'),
                icon: SvgPicture.asset(
                  bookMark.isMarkedPage ? AppAsset.saveFilled : AppAsset.save,
                ),
                onPressed: () => bookMark.toggleCurrentPage(context),
              ),
              IconButton(
                tooltip: tr('البحث في القرآن', 'Search the Quran'),
                icon: SvgPicture.asset(AppAsset.search),
                onPressed: () {
                  Navigator.pushNamed(context, '/search');
                },
              ),
              IconButton(
                tooltip: Theme.of(context).brightness == Brightness.dark
                    ? tr('الوضع النهاري', 'Light mode')
                    : tr('الوضع الليلي', 'Dark mode'),
                icon: SvgPicture.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? AppAsset.sun
                      : AppAsset.moon,
                ),
                onPressed: () => theme.toggleTheme(!theme.isDarkMode),
              ),
            ],
          ),
          const HorizontalDiv(),
          SizedBox(
            height: 45,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextButton.icon(
                    onPressed: openBookmarks,
                    icon: SvgPicture.asset(AppAsset.saveFilled),
                    label: FittedBox(
                      child: Text(AppConstant.bookmarks, style: textStyle),
                    ),
                  ),
                ),
                const VerticalDiv(),
                Expanded(
                  flex: 3,
                  child: TextButton.icon(
                    onPressed: () {
                      showDialog(
                        barrierDismissible: true,
                        context: context,
                        builder: (context) => const GoToPagePopup(),
                      );
                      overlay.toggleisShowOverlay();
                    },
                    icon: SvgPicture.asset(AppAsset.page),
                    label: Text(AppConstant.changePage, style: textStyle),
                  ),
                ),
                const VerticalDiv(),
                Expanded(
                  flex: 2,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/index');
                    },
                    icon: SvgPicture.asset(AppAsset.index),
                    label: Text(AppConstant.index, style: textStyle),
                  ),
                ),
                const VerticalDiv(),
                Expanded(
                  flex: 2,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/juz-index');
                    },
                    icon: SvgPicture.asset(AppAsset.part),
                    label: Text(AppConstant.ajzaa, style: textStyle),
                  ),
                ),
                const VerticalDiv(),
                Expanded(
                  flex: 2,
                  child: TextButton.icon(
                    onPressed: () => TafsirScreen.open(
                      context,
                      Provider.of<Quran>(context, listen: false).currentPage,
                    ),
                    icon: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: FittedBox(
                      child: Text(tr('التفسير', 'Tafsir'), style: textStyle),
                    ),
                  ),
                ),
                const VerticalDiv(),
                Expanded(
                  flex: 2,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/douaa');
                    },
                    icon: SvgPicture.asset(AppAsset.hand),
                    label: FittedBox(
                      child: FittedBox(
                        child: Text(AppConstant.douaa, style: textStyle),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
