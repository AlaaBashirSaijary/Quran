import 'package:flutter/material.dart';

import '../core/index.dart';
import 'bookmarks_screen.dart';
import '../widgets/horizontal_divider.dart';
import '../widgets/juz_card.dart';

class JuzIndexScreen extends StatelessWidget {
  const JuzIndexScreen({super.key, this.isTab = false});

  /// Opened from the main tabs rather than from inside the reader.
  final bool isTab;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstant.ajzaa),
        actions: [
          IconButton(
            tooltip: AppConstant.bookmarks,
            icon: const Icon(Icons.bookmarks_rounded),
            onPressed: () => BookmarksScreen.open(context, isTab: isTab),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: 30,
        separatorBuilder: (context, index) {
          return HorizontalDiv(color: colorScheme.div, thickness: 2);
        },
        itemBuilder: (BuildContext context, int index) {
          return JuzCard(juz: index + 1, isTab: isTab);
        },
      ),
    );
  }
}
