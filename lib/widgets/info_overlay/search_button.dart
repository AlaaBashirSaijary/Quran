import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../core/index.dart';

class SearchButton extends StatelessWidget {
  const SearchButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pushNamed(context, '/search');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.gold,
        foregroundColor: AppColor.greenDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            AppConstant.searchAyah,
            style: TextStyle(
              color: AppColor.greenDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          SvgPicture.asset(
            AppAsset.search,
            colorFilter: const ColorFilter.mode(
              AppColor.greenDark,
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}
