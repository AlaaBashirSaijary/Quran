import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/library.dart';
import '../content/text_screens.dart';
import '../core/index.dart';
import '../providers/ahadith_details_provider.dart';
import '../widgets/hadith_details.dart';

/// The forty hadith of al-Nawawi, with their explanations.
class NawawiScreen extends StatelessWidget {
  const NawawiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AhadithDetailsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('الأربعون النووية')),
      body: provider.ahadithData.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.ahadithData.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final hadith = provider.ahadithData[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      hadith.title,
                      style: const TextStyle(
                        fontFamily: AppTheme.secondaryFontFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_left_rounded,
                      color: colorScheme.gold,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HadithDetails(hadith: hadith),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class AhadithTab extends StatelessWidget {
  const AhadithTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأحاديث النبوية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BookCard(
            title: 'الأربعون النووية',
            subtitle: 'للإمام النووي',
            icon: Icons.format_quote_rounded,
            builder: (context) => const NawawiScreen(),
          ),
          _BookCard(
            title: 'الأربعون القدسية',
            subtitle: 'أحاديث يرويها النبي صلى الله عليه وسلم عن ربه',
            icon: Icons.auto_awesome_rounded,
            builder: (context) => FutureBuilder<List<String>>(
              future: loadQudsi(),
              builder: (context, snapshot) => snapshot.data == null
                  ? const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    )
                  : TextListScreen(
                      title: 'الأربعون القدسية',
                      texts: snapshot.data!,
                    ),
            ),
          ),
          _BookCard(
            title: 'رياض الصالحين',
            subtitle: 'للإمام النووي · 1896 حديثاً في 20 كتاباً',
            icon: Icons.local_florist_rounded,
            builder: (context) => SectionListScreen(
              title: 'رياض الصالحين',
              sections: loadRiyad(),
              searchHint: 'ابحث في الكتب والأحاديث',
              searchTexts: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'نصوص الأربعين القدسية ورياض الصالحين من sunnah.com',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.pageNumber,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Icon(icon, color: colorScheme.gold, size: 36),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.secondaryFontFamily,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
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
