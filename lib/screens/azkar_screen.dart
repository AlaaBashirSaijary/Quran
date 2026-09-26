import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../azkar/azkar.dart';
import '../content/library.dart';
import '../content/text_screens.dart';
import '../core/index.dart';
import '../providers/settings_provider.dart';

class AzkarScreen extends StatefulWidget {
  const AzkarScreen({super.key});

  @override
  State<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends State<AzkarScreen> {
  final _categories = loadAzkar();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('الأذكار', 'Azkar'))),
      body: FutureBuilder<List<AzkarCategory>>(
        future: _categories,
        builder: (context, snapshot) {
          final categories = snapshot.data;
          if (categories == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final suggested = suggestedCategory(DateTime.now());
          final highlight = categories
              .where((c) => c.id == suggested)
              .firstOrNull;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (highlight != null) ...[
                _SuggestedCard(category: highlight),
                const SizedBox(height: 16),
              ],
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  for (final category in categories)
                    _CategoryTile(category: category),
                ],
              ),
              const SizedBox(height: 16),
              _LinkTile(
                icon: Icons.volunteer_activism_rounded,
                title: tr('أدعية المناسبات', 'Du‘as for Occasions'),
                subtitle: tr(
                  'السفر، المطر، الكرب، المرض، المسجد، الطعام وغيرها',
                  'Travel, rain, distress, illness, the mosque, food and more',
                ),
                builder: (context) => SectionListScreen(
                  title: tr('أدعية المناسبات', 'Du‘as for Occasions'),
                  sections: loadOccasionDuas(),
                  searchHint: tr(
                    'ابحث عن مناسبة أو دعاء',
                    'Search for an occasion or du‘a',
                  ),
                  searchTexts: true,
                ),
              ),
              _LinkTile(
                icon: Icons.shield_moon_rounded,
                title: tr('الرقية الشرعية', 'Ruqyah'),
                subtitle: tr(
                  'من القرآن الكريم والسنة النبوية',
                  'From the Quran and the Sunnah',
                ),
                builder: (context) => FutureBuilder<List<TextSection>>(
                  future: loadRuqyah(),
                  builder: (context, snapshot) {
                    final sections = snapshot.data;
                    if (sections == null) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Scaffold(
                      appBar: AppBar(
                        title: Text(tr('الرقية الشرعية', 'Ruqyah')),
                      ),
                      body: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final (i, s) in sections.indexed)
                            for (final text in s.texts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextCard(
                                  text: text,
                                  caption: s.title,
                                  quranFont: i < ruqyahPassages.length,
                                ),
                              ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _LinkTile(
                icon: Icons.star_rounded,
                title: tr('أسماء الله الحسنى', 'The Beautiful Names of Allah'),
                subtitle: tr('تسعة وتسعون اسماً', 'Ninety-nine names'),
                builder: (context) => const NamesScreen(),
              ),
              const SizedBox(height: 16),
              Text(
                tr(
                  'المصدر: حصن المسلم (islambook.com)',
                  'Source: Hisn al-Muslim (islambook.com)',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.pageNumber,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

void _open(BuildContext context, AzkarCategory category) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AzkarCategoryScreen(category: category),
    ),
  );
}

class _SuggestedCard extends StatelessWidget {
  const _SuggestedCard({required this.category});

  final AzkarCategory category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.brightness == Brightness.light
          ? AppColor.green
          : AppColor.nightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.gold.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, category),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(category.icon, color: colorScheme.gold, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('وقتها الآن', 'Now is their time'),
                      style: TextStyle(color: colorScheme.gold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.label,
                      style: const TextStyle(
                        fontFamily: AppTheme.secondaryFontFamily,
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: colorScheme.gold),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final AzkarCategory category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, category),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, color: colorScheme.gold, size: 34),
              const SizedBox(height: 8),
              Text(
                category.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: colorScheme.juzCardText,
                ),
              ),
              Text(
                _countLabel(category.items.length),
                style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AzkarCategoryScreen extends StatefulWidget {
  const AzkarCategoryScreen({super.key, required this.category});

  final AzkarCategory category;

  @override
  State<AzkarCategoryScreen> createState() => _AzkarCategoryScreenState();
}

class _AzkarCategoryScreenState extends State<AzkarCategoryScreen> {
  AzkarProgress? _progress;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _progress = AzkarProgress(prefs, widget.category));
    });
  }

  void _tap(int index) {
    final progress = _progress!;
    if (progress.isDone(index)) return;
    final finished = progress.tap(index);
    HapticFeedback.selectionClick();
    setState(() {});
    if (finished && progress.allDone) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'أتممت ${widget.category.label}، تقبّل الله',
                'You finished ${widget.category.label}. May Allah accept it.',
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final items = widget.category.items;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.label),
        actions: [
          IconButton(
            tooltip: tr('البدء من جديد', 'Start over'),
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: progress == null ? null : () => setState(progress.reset),
          ),
        ],
        bottom: progress == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: progress.doneCount / items.length,
                  color: colorScheme.gold,
                  backgroundColor: Colors.white24,
                  minHeight: 4,
                ),
              ),
      ),
      body: progress == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _DhikrCard(
                dhikr: items[index],
                remaining: progress.remaining(index),
                onTap: () => _tap(index),
              ),
            ),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({
    required this.dhikr,
    required this.remaining,
    required this.onTap,
  });

  final Dhikr dhikr;
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final done = remaining == 0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: done ? 0.55 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  dhikr.text,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: context.contentSize(19),
                    height: 1.9,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (dhikr.virtue != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    dhikr.virtue!,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: context.contentSize(13),
                      height: 1.6,
                      color: colorScheme.gold,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      dhikr.count == 1
                          ? tr('مرة واحدة', 'Once')
                          : tr(
                              'التكرار: ${dhikr.count}',
                              'Repeat: ${dhikr.count}',
                            ),
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.pageNumber,
                      ),
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: done ? colorScheme.gold : colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: done
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            )
                          : Text(
                              '$remaining',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Arabic counting: 3 to 10 take the plural, 11 and up the singular.
String _countLabel(int n) =>
    isEnglish ? '$n azkar' : (n <= 10 ? '$n أذكار' : '$n ذكراً');

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: colorScheme.gold, size: 32),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle),
          trailing: Icon(Icons.chevron_left_rounded, color: colorScheme.gold),
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: builder)),
        ),
      ),
    );
  }
}
