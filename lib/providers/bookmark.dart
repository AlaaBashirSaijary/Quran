import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/index.dart';

class BookMarkProvider extends ChangeNotifier {
  final SharedPreferences prefs;

  late int currentPage;

  /// The saved page, or null until the user saves a bookmark.
  int? markPage;

  BookMarkProvider(this.prefs) {
    markPage = prefs.getInt('mark');
  }

  void update(int newPage) {
    currentPage = newPage;
    notifyListeners();
  }

  bool get isMarkedPage => currentPage == markPage;

  String get markButtonText {
    return isMarkedPage ? AppConstant.saved : AppConstant.saveBookmark;
  }

  Color get markButtonColor {
    return isMarkedPage ? AppColor.gold : Colors.transparent;
  }

  void changeMark() {
    markPage = currentPage;
    notifyListeners();
    prefs.setInt('mark', currentPage);
  }

  /// Returns the bookmarked page, or tells the user there is none yet.
  int? markPageOrNotify(BuildContext context) {
    if (markPage == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppConstant.noBookmarkYet)),
        );
    }
    return markPage;
  }
}
