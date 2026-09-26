import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../hifz/hifz.dart';
import '../providers/settings_provider.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import '../widgets/surah_number.dart';

/// Quran tab card: how many memorised surahs are due for review.
class HifzCard extends StatelessWidget {
  const HifzCard({super.key});

  @override
  Widget build(BuildContext context) {
    final hifz = Provider.of<HifzProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final due = hifz.due.length;
    final total = hifz.all.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          Icons.psychology_rounded,
          color: colorScheme.gold,
          size: 36,
        ),
        title: Text(
          'الحفظ والمراجعة',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.juzCardText,
          ),
        ),
        subtitle: Text(
          total == 0
              ? 'أضف السور التي تحفظها ليذكّرك التطبيق بمراجعتها'
              : due == 0
              ? 'لا مراجعة اليوم · المحفوظ: ${_surahs(total)}'
              : 'للمراجعة اليوم: ${_surahs(due)}',
          style: TextStyle(
            color: due > 0 ? colorScheme.primary : colorScheme.pageNumber,
            fontSize: 13,
          ),
        ),
        trailing: Icon(Icons.chevron_left_rounded, color: colorScheme.gold),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HifzScreen()),
        ),
      ),
    );
  }
}

class HifzScreen extends StatelessWidget {
  const HifzScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hifz = Provider.of<HifzProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final due = hifz.due;
    final later = hifz.all.where((e) => !due.contains(e)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('الحفظ والمراجعة')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSurah(context, hifz),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة سورة'),
      ),
      body: hifz.all.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology_rounded,
                      size: 72,
                      color: colorScheme.gold,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'أضف السور التي حفظتها، وسيذكّرك التطبيق بمراجعة كل سورة '
                      'على فترات تتباعد كلما أتقنتها: بعد يوم، ثم ثلاثة أيام، '
                      'ثم أسبوع، ثم أسبوعين، ثم شهر، ثم شهرين.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.pageNumber),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (due.isNotEmpty) ...[
                  _Heading('للمراجعة اليوم (${due.length})'),
                  for (final e in due) _EntryTile(entry: e, isDue: true),
                  const SizedBox(height: 16),
                ],
                if (later.isNotEmpty) ...[
                  const _Heading('المراجعات القادمة'),
                  for (final e in later) _EntryTile(entry: e, isDue: false),
                ],
              ],
            ),
    );
  }

  Future<void> _addSurah(BuildContext context, HifzProvider hifz) async {
    final surah = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          itemCount: 114,
          itemBuilder: (context, i) {
            final surah = i + 1;
            final added = hifz.isMemorised(surah);
            return ListTile(
              enabled: !added,
              leading: SurahNumber(number: surah),
              title: Text('سورة ${getSurahNameArabic(surah)}'),
              trailing: added ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(context, surah),
            );
          },
        ),
      ),
    );
    if (surah != null) hifz.add(surah);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.secondaryFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.isDue});

  final HifzEntry entry;
  final bool isDue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hifz = Provider.of<HifzProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: SurahNumber(number: entry.surah),
          title: Text(
            'سورة ${getSurahNameArabic(entry.surah)}',
            style: const TextStyle(
              fontFamily: AppTheme.secondaryFontFamily,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            isDue ? 'حان وقت مراجعتها' : 'المراجعة: ${_date(entry.due)}',
            style: TextStyle(
              color: isDue ? colorScheme.gold : colorScheme.pageNumber,
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'remove') hifz.remove(entry.surah);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'remove', child: Text('إزالة من المحفوظ')),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HifzReviewScreen(surah: entry.surah),
            ),
          ),
        ),
      ),
    );
  }
}

/// Recite a surah from memory: each ayah shows only its first word until
/// tapped, then rate the review.
class HifzReviewScreen extends StatefulWidget {
  const HifzReviewScreen({super.key, required this.surah});

  final int surah;

  @override
  State<HifzReviewScreen> createState() => _HifzReviewScreenState();
}

class _HifzReviewScreenState extends State<HifzReviewScreen> {
  final _ayahs = QuranSearch.load();
  final _revealed = <int>{};
  bool _hideWords = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hifz = Provider.of<HifzProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('مراجعة سورة ${getSurahNameArabic(widget.surah)}'),
        actions: [
          IconButton(
            tooltip: _hideWords ? 'إظهار الكل' : 'إخفاء الكلمات',
            icon: Icon(
              _hideWords
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
            ),
            onPressed: () => setState(() {
              _hideWords = !_hideWords;
              _revealed.clear();
            }),
          ),
        ],
      ),
      body: FutureBuilder<QuranSearch>(
        future: _ayahs,
        builder: (context, snapshot) {
          final quran = snapshot.data;
          if (quran == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final ayahs = quran.ayahsOfSurah(widget.surah);
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ayahs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final ayah = ayahs[i];
              final hidden = _hideWords && !_revealed.contains(ayah.number);
              final words = ayah.text.split(' ');
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() {
                    if (!_revealed.remove(ayah.number)) {
                      _revealed.add(ayah.number);
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: hidden
                                ? '${words.first} ${words.length > 1 ? '…' : ''}'
                                : ayah.text,
                          ),
                          TextSpan(
                            text: ' ﴿${ayah.number}﴾',
                            style: TextStyle(color: colorScheme.gold),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontFamily: AppTheme.secondaryFontFamily,
                        fontSize: context.contentSize(22),
                        height: 1.9,
                        color: hidden
                            ? colorScheme.pageNumber
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    hifz.review(widget.surah, good: false);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('تحتاج مراجعة'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    hifz.review(widget.surah, good: true);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('أتقنتها'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _surahs(int n) {
  if (n == 1) return 'سورة واحدة';
  if (n == 2) return 'سورتان';
  if (n <= 10) return '$n سور';
  return '$n سورة';
}

String _date(DateTime d) => '${d.year}/${d.month}/${d.day}';
