import 'package:flutter/material.dart';

import '../core/index.dart';
import '../providers/settings_provider.dart';

class DouaaScreen extends StatelessWidget {
  const DouaaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('دُعَاءُ خَتْمِ القُرْآن', 'Du‘a for Completing the Quran'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                AppConstant.douaaKhatmQuran,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.secondaryFontFamily,
                  fontSize: context.contentSize(25),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
