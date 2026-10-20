import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/recitation.dart';
import '../core/index.dart';
import '../providers/sebha_provider.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import 'kids_progress.dart';

/// A card on the Quran tab that opens the kids' corner.
class KidsCard extends StatelessWidget {
  const KidsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(Icons.child_care_rounded, color: colorScheme.gold, size: 36),
        title: Text(
          tr('ركن الصغار', 'Kids\' corner'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          tr(
            'سور قصيرة بالصوت والتكرار، وتسبيح بنجوم',
            'Short surahs with audio and repetition, and a tasbeeh with stars',
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const KidsCornerScreen()),
        ),
      ),
    );
  }
}

/// Big, colourful buttons for children: pick a surah to listen to and read,
/// or count a little tasbeeh, and collect stars.
class KidsCornerScreen extends StatelessWidget {
  const KidsCornerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = Provider.of<KidsProgress>(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('ركن الصغار', 'Kids\' corner'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Icon(Icons.star_rounded, color: colorScheme.gold, size: 64),
                Text(
                  '${progress.totalStars}',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  tr('نجومك', 'Your stars'),
                  style: TextStyle(color: colorScheme.pageNumber),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _BigButton(
            icon: Icons.touch_app_rounded,
            title: tr('سبّح وخذ نجمة', 'Count and get a star'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const KidsTasbeehScreen()),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('اختر سورة', 'Pick a surah'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final surah in kidsSurahs) ...[
            _BigButton(
              icon: Icons.menu_book_rounded,
              title: surahNameOf(surah),
              stars: progress.starsFor(surah),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => KidsSurahScreen(surah: surah),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.title,
    required this.onTap,
    this.stars,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int? stars;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.gold, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (stars != null && stars! > 0) ...[
                Icon(Icons.star_rounded, color: colorScheme.gold, size: 28),
                const SizedBox(width: 4),
                Text('$stars', style: const TextStyle(fontSize: 20)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One surah in large type: listen to it ayah by ayah, repeat it, and take
/// today's star.
class KidsSurahScreen extends StatefulWidget {
  const KidsSurahScreen({super.key, required this.surah});

  final int surah;

  @override
  State<KidsSurahScreen> createState() => _KidsSurahScreenState();
}

class _KidsSurahScreenState extends State<KidsSurahScreen> {
  late final Future<QuranSearch> _quran = QuranSearch.load();
  bool _repeat3 = false;

  @override
  Widget build(BuildContext context) {
    final recitation = Provider.of<RecitationProvider>(context);
    final progress = Provider.of<KidsProgress>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final current = recitation.current;
    final playing = recitation.status == RecitationStatus.playing ||
        recitation.status == RecitationStatus.loading;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) recitation.stop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(surahNameOf(widget.surah))),
        body: FutureBuilder<QuranSearch>(
          future: _quran,
          initialData: QuranSearch.loaded,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final ayahs = snap.data!.ayahsOfSurah(widget.surah);
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: ayahs.length,
                    itemBuilder: (context, i) {
                      final ayah = ayahs[i];
                      final active = playing &&
                          current != null &&
                          current.surah == widget.surah &&
                          current.ayah == ayah.number;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: active
                              ? colorScheme.gold.withValues(alpha: 0.25)
                              : colorScheme.div.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          ayah.text,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontFamily: AppTheme.secondaryFontFamily,
                            fontSize: 30,
                            height: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (recitation.error != null &&
                            recitation.status == RecitationStatus.error)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              recitation.error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(60),
                          ),
                          onPressed: () => playing
                              ? recitation.stop()
                              : recitation.playRange(
                                  widget.surah,
                                  1,
                                  ayahs.length,
                                  times: _repeat3 ? 3 : 1,
                                ),
                          icon: Icon(
                            playing
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            size: 32,
                          ),
                          label: Text(
                            playing
                                ? tr('إيقاف', 'Stop')
                                : tr('استمع', 'Listen'),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            tr('كرّر السورة ٣ مرات', 'Repeat the surah 3 times'),
                          ),
                          value: _repeat3,
                          onChanged: (v) => setState(() => _repeat3 = v),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: progress.earnedToday(widget.surah)
                              ? null
                              : () {
                                  progress.earnToday(widget.surah);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        tr('أحسنت! نجمة جديدة', 'Well done! A new star'),
                                      ),
                                    ),
                                  );
                                },
                          icon: Icon(Icons.star_rounded, color: colorScheme.gold),
                          label: Text(
                            progress.earnedToday(widget.surah)
                                ? tr('أخذتَ نجمة اليوم', 'Today\'s star is taken')
                                : tr('قرأتُها، أعطني نجمة', 'I read it, give me a star'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A little tasbeeh: tap the big button ten times for a star. It does not
/// touch the main tasbeeh counts.
class KidsTasbeehScreen extends StatefulWidget {
  const KidsTasbeehScreen({super.key});

  @override
  State<KidsTasbeehScreen> createState() => _KidsTasbeehScreenState();
}

class _KidsTasbeehScreenState extends State<KidsTasbeehScreen> {
  static const _target = 10;
  int _chosen = 0;
  int _count = 0;

  void _tap(KidsProgress progress) {
    setState(() => _count++);
    if (_count >= _target) {
      progress.addDhikrRound();
      setState(() => _count = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('أحسنت! نجمة جديدة', 'Well done! A new star')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = Provider.of<KidsProgress>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final words = defaultAzkar.take(3).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('سبّح وخذ نجمة', 'Count and get a star'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < words.length; i++)
                  ChoiceChip(
                    label: Text(
                      words[i].text,
                      style: const TextStyle(fontSize: 18),
                    ),
                    selected: _chosen == i,
                    onSelected: (_) => setState(() {
                      _chosen = i;
                      _count = 0;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              words[_chosen].text,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$_count / $_target',
              style: TextStyle(fontSize: 22, color: colorScheme.pageNumber),
            ),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () => _tap(progress),
                  child: AnimatedScale(
                    scale: 1 + (_count % 2) * 0.06,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.gold,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.star_rounded,
                          size: 110,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              tr('النجوم: ${progress.totalStars}', 'Stars: ${progress.totalStars}'),
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
