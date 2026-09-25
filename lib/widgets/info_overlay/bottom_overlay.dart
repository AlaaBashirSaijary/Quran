import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../../core/index.dart';
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
            height: 45,
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/index');
                    },
                    icon: SvgPicture.asset(AppAsset.index),
                    label: const Text(AppConstant.index, style: textStyle),
                  ),
                ),
                const VerticalDiv(),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/juz-index');
                    },
                    icon: SvgPicture.asset(AppAsset.part),
                    label: const Text(AppConstant.ajzaa, style: textStyle),
                  ),
                ),
                const VerticalDiv(),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/douaa');
                    },
                    icon: SvgPicture.asset(AppAsset.hand),
                    label: const FittedBox(
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

const textStyle = TextStyle(color: Colors.white, fontSize: 15);
