import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../providers/bookmark.dart';
import '../widgets/horizontal_divider.dart';
import '../widgets/juz_card.dart';
import 'index_screen.dart';

class JuzIndexScreen extends StatelessWidget {
  const JuzIndexScreen({Key? key, this.isTab = false}) : super(key: key);

  /// Opened from the main tabs rather than from inside the reader.
  final bool isTab;

  @override
  Widget build(BuildContext context) {
    final bookMark = Provider.of<BookMarkProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstant.ajzaa),
        actions: [
          IconButton(
            tooltip: AppConstant.goToBookMark,
            icon: const Icon(Icons.bookmark_rounded),
            onPressed: () =>
                openQuranPage(context, bookMark.markPage, isTab: isTab),
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
