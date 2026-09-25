import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../core/index.dart';

class SurahNumber extends StatelessWidget {
  const SurahNumber({super.key, required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        SvgPicture.asset(
          AppAsset.surahNumber,
          colorFilter: ColorFilter.mode(colorScheme.gold, BlendMode.srcIn),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            number.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.juzCardText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
