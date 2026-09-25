import 'package:flutter/material.dart';

import '../core/index.dart';

class DouaaScreen extends StatelessWidget {
  const DouaaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دُعَاءُ خَتْمِ القُرْآن'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                AppConstant.douaaKhatmQuran,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.secondaryFontFamily,
                  fontSize: 25,
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
