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
      appBar: AppBar(
        title: Text(tr('الأربعون النووية', 'Al-Nawawi’s Forty Hadith')),
      ),
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
      appBar: AppBar(title: Text(tr('الأحاديث النبوية', 'Hadith'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BookCard(
            title: tr('الأربعون النووية', 'Al-Nawawi’s Forty Hadith'),
            subtitle: tr('للإمام النووي', 'By Imam al-Nawawi'),
            icon: Icons.format_quote_rounded,
            builder: (context) => const NawawiScreen(),
          ),
          _BookCard(
            title: tr('الأربعون القدسية', 'Forty Hadith Qudsi'),
            subtitle: tr(
              'أحاديث يرويها النبي صلى الله عليه وسلم عن ربه',
              'Hadith the Prophet (peace be upon him) narrated from his Lord',
            ),
            icon: Icons.auto_awesome_rounded,
            builder: (context) => FutureBuilder<List<String>>(
              future: loadQudsi(),
              builder: (context, snapshot) => snapshot.data == null
                  ? const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    )
                  : TextListScreen(
                      title: tr('الأربعون القدسية', 'Forty Hadith Qudsi'),
                      texts: snapshot.data!,
                    ),
            ),
          ),
          _BookCard(
            title: tr('رياض الصالحين', 'Riyad as-Salihin'),
            subtitle: tr(
              'للإمام النووي · 1896 حديثاً في 20 كتاباً',
              'By Imam al-Nawawi · 1896 hadith in 20 books',
            ),
            icon: Icons.local_florist_rounded,
            builder: (context) => SectionListScreen(
              title: tr('رياض الصالحين', 'Riyad as-Salihin'),
              sections: loadRiyad(),
              searchHint: tr(
                'ابحث في الكتب والأحاديث',
                'Search the books and hadith (in Arabic)',
              ),
              searchTexts: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'نصوص الأربعين القدسية ورياض الصالحين من sunnah.com',
              'Texts of the Forty Qudsi and Riyad as-Salihin from sunnah.com',
            ),
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
