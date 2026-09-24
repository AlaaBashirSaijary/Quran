import 'package:flutter/material.dart';

import '../quran/quran.dart';
import 'invert_color.dart';

class QuranPage extends StatelessWidget {
  const QuranPage({Key? key, required this.pageIndex}) : super(key: key);

  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return InvertColor(
      isInvert: Theme.of(context).brightness == Brightness.dark,
      child: Image.asset(pageDir(pageIndex + 1)),
    );
  }
}
