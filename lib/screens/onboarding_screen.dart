import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../core/index.dart';
import '../main.dart';
import '../providers/settings_provider.dart';
import 'main_tabs_screen.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

List<_Slide> get _slides => [
  _Slide(
    Icons.menu_book_rounded,
    tr('اقرأ القرآن الكريم وتدبّره', 'Read and reflect on the Quran'),
    tr(
      'مصحف كامل يعمل دون إنترنت ويحفظ موضع قراءتك',
      'The complete mushaf, offline, remembering where you stopped',
    ),
  ),
  _Slide(
    Icons.format_quote_rounded,
    tr(
      'أحاديث الرسول صلى الله عليه وسلم',
      'The hadith of the Prophet (peace be upon him)',
    ),
    tr(
      'الأربعون النووية بين يديك في أي وقت',
      'Al-Nawawi’s Forty and more, whenever you need them',
    ),
  ),
  _Slide(
    Icons.favorite_rounded,
    tr('أذكار ليطمئن قلبك', 'Azkar to bring your heart peace'),
    tr(
      'سبحة إلكترونية تعينك على الذكر',
      'A tasbeeh counter to help you remember Allah',
    ),
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const seenKey = 'seenOnboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final pageController = PageController();
  int pageIndex = 0;

  bool get isLastPage => pageIndex == _slides.length - 1;

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.seenKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainTabsScreen()),
    );
  }

  Future<void> _switchLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SettingsProvider.languageKey,
      (isEnglish ? AppLanguage.ar : AppLanguage.en).name,
    );
    if (mounted) AppRoot.restart(context);
  }

  void _next() {
    if (isLastPage) {
      _finish();
    } else {
      pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _switchLanguage,
                  icon: Icon(Icons.translate_rounded, color: colorScheme.gold),
                  label: Text(
                    isEnglish ? AppLanguage.ar.label : AppLanguage.en.label,
                    style: TextStyle(color: colorScheme.gold),
                  ),
                ),
                TextButton(
                  onPressed: _finish,
                  child: Text(
                    tr('تخطَّ', 'Skip'),
                    style: TextStyle(color: colorScheme.gold),
                  ),
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => pageIndex = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                            border: Border.all(
                              color: colorScheme.gold,
                              width: 4,
                            ),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 84,
                            color: colorScheme.gold,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineMedium?.copyWith(
                            fontFamily: AppTheme.secondaryFontFamily,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SmoothPageIndicator(
              controller: pageController,
              count: _slides.length,
              effect: ExpandingDotsEffect(
                dotHeight: 8,
                dotWidth: 8,
                dotColor: colorScheme.div,
                activeDotColor: colorScheme.gold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    isLastPage ? tr('ابدأ', 'Start') : tr('التالي', 'Next'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
