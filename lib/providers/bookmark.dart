import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/index.dart';

class Bookmark {
  const Bookmark({required this.page, required this.savedAt});

  final int page;
  final DateTime savedAt;

  String encode() => '$page|${savedAt.millisecondsSinceEpoch}';

  static Bookmark? decode(String value) {
    final parts = value.split('|');
    final page = int.tryParse(parts.first);
    if (page == null || page < 1 || page > 604) return null;
    final millis = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return Bookmark(
      page: page,
      savedAt: DateTime.fromMillisecondsSinceEpoch(millis ?? 0),
    );
  }
}

class BookMarkProvider extends ChangeNotifier {
  BookMarkProvider(this.prefs) {
    _bookmarks = (prefs.getStringList(_key) ?? const <String>[])
        .map(Bookmark.decode)
        .whereType<Bookmark>()
        .toList();
    // Earlier versions kept a single bookmark as an int.
    final legacy = prefs.getInt(_legacyKey);
    if (legacy != null) {
      if (!_bookmarks.any((b) => b.page == legacy)) {
        _bookmarks.add(Bookmark(page: legacy, savedAt: DateTime.now()));
      }
      prefs.remove(_legacyKey);
      _save();
    }
  }

  static const _key = 'bookmarks';
  static const _legacyKey = 'mark';

  final SharedPreferences prefs;

  late int currentPage;

  late List<Bookmark> _bookmarks;

  /// Newest first.
  List<Bookmark> get bookmarks =>
      [..._bookmarks]..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  Set<int> get pages => {for (final b in _bookmarks) b.page};

  bool isBookmarked(int page) => _bookmarks.any((b) => b.page == page);

  void update(int newPage) {
    currentPage = newPage;
    notifyListeners();
  }

  bool get isMarkedPage => isBookmarked(currentPage);

  String get markButtonText {
    return isMarkedPage ? AppConstant.saved : AppConstant.saveBookmark;
  }

  Color get markButtonColor {
    return isMarkedPage ? AppColor.gold : Colors.transparent;
  }

  /// Saves the current page, or removes it if it is already saved.
  void toggleCurrentPage(BuildContext context) {
    final page = currentPage;
    if (isBookmarked(page)) {
      final removed = _bookmarks.firstWhere((b) => b.page == page);
      remove(page);
      _notify(
        context,
        AppConstant.bookmarkRemoved,
        undo: () => restore(removed),
      );
    } else {
      _bookmarks.add(Bookmark(page: page, savedAt: DateTime.now()));
      _save();
      notifyListeners();
      _notify(context, AppConstant.bookmarkSaved);
    }
  }

  void remove(int page) {
    _bookmarks.removeWhere((b) => b.page == page);
    _save();
    notifyListeners();
  }

  void restore(Bookmark bookmark) {
    if (isBookmarked(bookmark.page)) return;
    _bookmarks.add(bookmark);
    _save();
    notifyListeners();
  }

  void _save() {
    prefs.setStringList(_key, [for (final b in _bookmarks) b.encode()]);
  }

  void _notify(BuildContext context, String message, {VoidCallback? undo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          action: undo == null
              ? null
              : SnackBarAction(label: AppConstant.undo, onPressed: undo),
        ),
      );
  }
}
