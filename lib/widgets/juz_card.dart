import 'package:flutter/material.dart';

import '../core/index.dart';
import '../screens/index_screen.dart';
import '../quran/quran.dart';
import 'horizontal_divider.dart';
import 'vertical_divider.dart';

const _divColor = Color.fromARGB(60, 201, 165, 76);
const vDiv = VerticalDiv(color: _divColor);
const hDiv = HorizontalDiv(color: _divColor);

class JuzCard extends StatelessWidget {
  const JuzCard({super.key, required this.juz, this.isTab = false});

  final int juz;
  final bool isTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 95,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomText(
                  '${AppConstant.juz} $juz',
                  fontSize: 24,
                  page: getJuzPage(juz),
                  isTab: isTab,
                  fontWeight: FontWeight.bold,
                ),
              ),
              vDiv,
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    hizbPart(1),
                    hDiv,
                    hizbPart(2),
                  ],
                ),
              ),
              vDiv,
              Expanded(
                  child: CustomText(
                '${getJuzPage(juz)}',
                page: getJuzPage(juz),
                isTab: isTab,
              ))
            ],
          ),
        ),
      ],
    );
  }

  Expanded hizbPart(int hizb) {
    return Expanded(
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: CustomText(
              '${AppConstant.hizb} ${getHizb(juz: juz, hizb: hizb)}',
              isTab: isTab,
              page: getHizbPage(
                getHizb(juz: juz, hizb: hizb),
              ),
            ),
          ),
          vDiv,
          Expanded(
            flex: 2,
            child: CustomText(
              'ربع',
              isTab: isTab,
              page: getHizbQuarterPage(
                getHizbQuarter(hizb: getHizb(juz: juz, hizb: hizb), quarter: 1),
              ),
            ),
          ),
          vDiv,
          Expanded(
            flex: 2,
            child: CustomText(
              'نصف',
              isTab: isTab,
              page: getHizbQuarterPage(
                getHizbQuarter(hizb: getHizb(juz: juz, hizb: hizb), quarter: 2),
              ),
            ),
          ),
          vDiv,
          Expanded(
            flex: 2,
            child: CustomText(
              '3 أرباع',
              isTab: isTab,
              page: getHizbQuarterPage(
                getHizbQuarter(hizb: getHizb(juz: juz, hizb: hizb), quarter: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomText extends StatelessWidget {
  const CustomText(this.text,
      {super.key,
      this.fontSize,
      required this.page,
      required this.isTab,
      this.fontWeight});

  final String text;
  final double? fontSize;
  final int page;
  final bool isTab;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: Size.infinite,
      ),
      onPressed: () => openQuranPage(context, page, isTab: isTab),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.secondaryFontFamily,
            fontSize: fontSize,
            color: colorScheme.juzCardText,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }
}
