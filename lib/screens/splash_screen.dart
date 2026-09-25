import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/index.dart';
import 'main_tabs_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final seenOnboarding =
          widget.prefs.getBool(OnboardingScreen.seenKey) ?? false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => seenOnboarding
              ? const MainTabsScreen()
              : const OnboardingScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColor.paper,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/splash.png', width: 160),
            const SizedBox(height: 24),
            const Text(
              'طريق الجنة',
              style: TextStyle(
                fontFamily: AppTheme.secondaryFontFamily,
                color: AppColor.green,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
