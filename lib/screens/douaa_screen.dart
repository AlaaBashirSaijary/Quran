import 'package:flutter/material.dart';

import '../core/index.dart';

class DouaaScreen extends StatelessWidget {
  const DouaaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pinkAccent,
        title: const Text(
          'دُعَاءُ خَتْمِ القُرْآن',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 30,
            color: Colors.white
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: const [
          Text(
            AppConstant.douaaKhatmQuran,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.secondaryFontFamily,
              fontSize: 25,
              // height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
