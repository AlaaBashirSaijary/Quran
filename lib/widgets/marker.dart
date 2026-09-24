import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:quranapplication/providers/bookmark.dart';
import 'package:provider/provider.dart';
import '../core/index.dart';

class Marker extends StatelessWidget {
  const Marker({Key? key, this.left = 20, this.alwaysShow = false})
      : super(key: key);

  final double left;

  /// Show even when the reader is not on the bookmarked page.
  final bool alwaysShow;

  @override
  Widget build(BuildContext context) {
    final bookMark = Provider.of<BookMarkProvider>(context);

    if (alwaysShow || bookMark.isMarkedPage) {
      return Positioned(
        left: left,
        top: 0,
        child: SvgPicture.asset(AppAsset.mark),
      );
    }
    return const SizedBox.shrink();
  }
}
