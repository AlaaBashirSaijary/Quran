import 'package:flutter/material.dart';

import '../quran/quran.dart';
import 'invert_color.dart';
import '../core/language.dart';

class QuranPage extends StatelessWidget {
  const QuranPage({super.key, required this.pageIndex});

  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return InvertColor(
      isInvert: Theme.of(context).brightness == Brightness.dark,
      child: Image.asset(
        pageDir(pageIndex + 1),
        semanticLabel: tr(
          'صفحة ${pageIndex + 1} من المصحف',
          'Mushaf page ${pageIndex + 1}',
        ),
      ),
    );
  }
}
