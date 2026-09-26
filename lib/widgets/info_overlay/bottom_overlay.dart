import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../../audio/player_bar.dart';
import '../../core/index.dart';
import '../../screens/tafsir_screen.dart';
import '../../providers/quran.dart';
import '../../screens/bookmarks_screen.dart';
import '../../providers/bookmark.dart';
import '../../providers/show_overlay_provider.dart';
import '../../providers/theme_provider.dart';
import '../custom_button.dart';
import '../custom_container.dart';
import '../go_to_page_popup.dart';
import '../horizontal_divider.dart';
import '../vertical_divider.dart';
import 'search_button.dart';

class BottomOverlay extends StatelessWidget {
  const BottomOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final bookMark = Provider.of<BookMarkProvider>(context);
    final themeListenFalse = Provider.of<ThemeProvider>(context, listen: false);
    final overlay = Provider.of<ShowOverlayProvider>(context, listen: false);

    void openBookmarks() {
      BookmarksScreen.open(context, isTab: false);
    }

    return CustomContainer(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Expanded(child: SearchButton()),
                const SizedBox(width: 10),
                CustomButton(
                  onPressed: () => bookMark.toggleCurrentPage(context),
                  text: bookMark.markButtonText,
                  onPrimary: Colors.white,
                  primary: bookMark.markButtonColor,
                  svgIcon: AppAsset.saveFilled,
                ),
              ],
            ),
          ),
          const HorizontalDiv(),
          SizedBox(
            height: 45,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextButton.icon(
                    onPressed: openBookmarks,
                    icon: SvgPicture.asset(AppAsset.saveFilled),
                    label: const FittedBox(
                      child: Text(AppConstant.bookmarks, style: textStyle),
                    ),
                  ),
                ),
                const VerticalDiv(),
                Expanded(
                  flex: 4,
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
                    label: const FittedBox(
                      child: Text(AppConstant.changePage, style: textStyle),
                    ),
                  ),
                ),
                const VerticalDiv(),
                IconButton(
                  tooltip: 'استماع للتلاوة',
                  icon: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    startRecitation(context);
                    Provider.of<ShowOverlayProvider>(
                      context,
                      listen: false,
                    ).hideOverlay();
                  },
                ),
                const VerticalDiv(),
                IconButton(
                  icon: SvgPicture.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? AppAsset.sun
                        : AppAsset.moon,
                  ),
                  onPressed: () {
                    themeListenFalse.toggleTheme(!themeListenFalse.isDarkMode);
                  },
                ),
              ],
            ),
          ),
          const HorizontalDiv(),
          SizedBox(
            height: 60,
            child: Row(
              children: [
                _Item(
                  icon: SvgPicture.asset(AppAsset.index),
                  label: AppConstant.index,
                  onTap: () => Navigator.of(context).pushNamed('/index'),
                ),
                const VerticalDiv(),
                _Item(
                  icon: SvgPicture.asset(AppAsset.part),
                  label: AppConstant.ajzaa,
                  onTap: () => Navigator.of(context).pushNamed('/juz-index'),
                ),
                const VerticalDiv(),
                _Item(
                  icon: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  label: 'التفسير',
                  onTap: () => TafsirScreen.open(
                    context,
                    Provider.of<Quran>(context, listen: false).currentPage,
                  ),
                ),
                const VerticalDiv(),
                _Item(
                  icon: SvgPicture.asset(AppAsset.hand),
                  label: AppConstant.douaa,
                  onTap: () => Navigator.of(context).pushNamed('/douaa'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const textStyle = TextStyle(color: Colors.white, fontSize: 15);

/// Icon above a label, for the row of four destinations.
class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.onTap});

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 22, child: icon),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(label, style: textStyle.copyWith(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
