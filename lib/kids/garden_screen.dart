import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/recitation.dart';
import '../core/index.dart';
import '../hifz/hifz.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import 'garden.dart';
import 'kids_progress.dart';
import 'word_games.dart';

IconData stageIcon(GrowthStage stage) => switch (stage) {
  GrowthStage.seed => Icons.grain_rounded,
  GrowthStage.sprout => Icons.eco_rounded,
  GrowthStage.plant => Icons.local_florist_rounded,
  GrowthStage.tree => Icons.park_rounded,
};

String stageName(GrowthStage stage) => switch (stage) {
  GrowthStage.seed => tr('بذرة: استمع', 'Seed: listen'),
  GrowthStage.sprout => tr('برعم: كرّر', 'Sprout: repeat'),
  GrowthStage.plant => tr('نبتة: أكمل الكلمات', 'Plant: fill the words'),
  GrowthStage.tree => tr('شجرة: رتّب وراجع', 'Tree: order and review'),
};

/// "My garden": one plant for each surah on the path. A surah grows from a
/// seed to a tree, one stage a day, each stage a different way of learning.
class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
  late final Future<QuranSearch> _quran = QuranSearch.load();
  List<int>? _path;

  @override
  Widget build(BuildContext context) {
    final garden = Provider.of<GardenProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('حديقتي', 'My garden'))),
      body: FutureBuilder<QuranSearch>(
        future: _quran,
        initialData: QuranSearch.loaded,
        builder: (context, snap) {
          final quran = snap.data;
          if (quran == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final path = _path ??= gardenPath(
            (s) => quran.ayahsOfSurah(s).length,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.park_rounded, color: colorScheme.gold, size: 40),
                  const SizedBox(width: 8),
                  Text(
                    tr(
                      '${garden.trees} من ${path.length} أشجار',
                      '${garden.trees} of ${path.length} trees',
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(tr('٤–٦ سنوات', 'Ages 4–6')),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(tr('٧–١٢ سنة', 'Ages 7–12')),
                    ),
                  ],
                  selected: {garden.easy},
                  onSelectionChanged: (v) => garden.setEasy(v.first),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'تنمو السورة مرحلة واحدة كل يوم، فعُدْ كل يوم.',
                  'A surah grows one stage a day, so come back every day.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.pageNumber),
              ),
              const SizedBox(height: 12),
              for (final surah in path)
                _PlotTile(
                  surah: surah,
                  ayahCount: quran.ayahsOfSurah(surah).length,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlotTile extends StatelessWidget {
  const _PlotTile({required this.surah, required this.ayahCount});

  final int surah;
  final int ayahCount;

  @override
  Widget build(BuildContext context) {
    final garden = Provider.of<GardenProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final stage = garden.stageOf(surah);
    final done = garden.grewToday(surah);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LessonScreen(surah: surah)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.gold.withValues(alpha: 0.2),
                child: Icon(stageIcon(stage), color: colorScheme.gold, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surahNameOf(surah),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      stageName(stage),
                      style: TextStyle(color: colorScheme.pageNumber),
                    ),
                  ],
                ),
              ),
              Text(
                tr('$ayahCount آيات', '$ayahCount ayahs'),
                style: TextStyle(color: colorScheme.pageNumber, fontSize: 12),
              ),
              if (done) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, color: colorScheme.gold),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One surah's lesson, for the stage it has reached.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.surah});

  final int surah;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late final Future<QuranSearch> _quran = QuranSearch.load();
  late final GrowthStage _stage;

  @override
  void initState() {
    super.initState();
    _stage = Provider.of<GardenProvider>(
      context,
      listen: false,
    ).stageOf(widget.surah);
  }

  Future<void> _complete() async {
    final garden = Provider.of<GardenProvider>(context, listen: false);
    final kids = Provider.of<KidsProgress>(context, listen: false);
    final hifz = Provider.of<HifzProvider>(context, listen: false);
    final surah = widget.surah;
    String message;
    IconData icon = Icons.star_rounded;
    if (_stage == GrowthStage.tree) {
      garden.addReview(surah);
      if (!hifz.isMemorised(surah)) {
        hifz.add(surah);
      } else if (hifz.due.any((e) => e.surah == surah)) {
        hifz.review(surah, good: true);
      }
      message = tr('أحسنت! راجعتَ السورة', 'Well done! You reviewed the surah');
    } else {
      final next = garden.grow(surah);
      if (next == null) {
        message = tr(
          'أحسنت! عُدْ غداً لتنمو نبتتك',
          'Well done! Come back tomorrow to grow your plant',
        );
      } else {
        icon = stageIcon(next);
        message = tr('نمت نبتتك! ${stageName(next)}', 'It grew! ${stageName(next)}');
        if (next == GrowthStage.tree && !hifz.isMemorised(surah)) {
          hifz.add(surah);
        }
      }
    }
    kids.earnToday(surah);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(icon, size: 56, color: Theme.of(context).colorScheme.gold),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('حسناً', 'OK')),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final recitation = Provider.of<RecitationProvider>(context, listen: false);
    final garden = Provider.of<GardenProvider>(context, listen: false);
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
            final quran = snap.data;
            if (quran == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final ayahs = quran.ayahsOfSurah(widget.surah);
            return Column(
              children: [
                _StageBar(current: _stage),
                Expanded(
                  child: switch (_stage) {
                    GrowthStage.seed => _ListenStage(
                      surah: widget.surah,
                      ayahs: ayahs,
                      onDone: _complete,
                    ),
                    GrowthStage.sprout => _RepeatStage(
                      surah: widget.surah,
                      ayahs: ayahs,
                      onDone: _complete,
                    ),
                    GrowthStage.plant => WordGame(
                      ayahs: sampleEvenly(ayahs, garden.easy ? 3 : 5),
                      fill: true,
                      easy: garden.easy,
                      onDone: _complete,
                    ),
                    GrowthStage.tree => WordGame(
                      ayahs: sampleEvenly(ayahs, garden.easy ? 2 : 4),
                      fill: false,
                      easy: garden.easy,
                      onDone: _complete,
                    ),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.current});

  final GrowthStage current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final s in GrowthStage.values)
                Icon(
                  stageIcon(s),
                  size: s == current ? 40 : 26,
                  color: s == current
                      ? colorScheme.gold
                      : colorScheme.pageNumber.withValues(alpha: 0.5),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            stageName(current),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

Widget _ayahBox(BuildContext context, String text, {bool active = false}) {
  final colorScheme = Theme.of(context).colorScheme;
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
      text,
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      style: const TextStyle(
        fontFamily: AppTheme.secondaryFontFamily,
        fontSize: 30,
        height: 2,
      ),
    ),
  );
}

/// Stage 1: listen to the whole surah.
class _ListenStage extends StatelessWidget {
  const _ListenStage({
    required this.surah,
    required this.ayahs,
    required this.onDone,
  });

  final int surah;
  final List<Ayah> ayahs;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final recitation = Provider.of<RecitationProvider>(context);
    final current = recitation.current;
    final playing =
        recitation.status == RecitationStatus.playing ||
        recitation.status == RecitationStatus.loading;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final a in ayahs)
                _ayahBox(
                  context,
                  a.text,
                  active:
                      playing &&
                      current != null &&
                      current.surah == surah &&
                      current.ayah == a.number,
                ),
            ],
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
                if (recitation.status == RecitationStatus.error &&
                    recitation.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      recitation.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                  ),
                  onPressed: () => playing
                      ? recitation.stop()
                      : recitation.playRange(surah, 1, ayahs.length),
                  icon: Icon(
                    playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 32,
                  ),
                  label: Text(
                    playing ? tr('إيقاف', 'Stop') : tr('استمع', 'Listen'),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: onDone,
                  child: Text(tr('سمعتُها كاملة', 'I listened to all of it')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Stage 2: repeat each ayah after the reciter.
class _RepeatStage extends StatefulWidget {
  const _RepeatStage({
    required this.surah,
    required this.ayahs,
    required this.onDone,
  });

  final int surah;
  final List<Ayah> ayahs;
  final VoidCallback onDone;

  @override
  State<_RepeatStage> createState() => _RepeatStageState();
}

class _RepeatStageState extends State<_RepeatStage> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final recitation = Provider.of<RecitationProvider>(context, listen: false);
    final ayah = widget.ayahs[_i];
    final last = _i == widget.ayahs.length - 1;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              'الآية ${_i + 1} من ${widget.ayahs.length}',
              'Ayah ${_i + 1} of ${widget.ayahs.length}',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(child: _ayahBox(context, ayah.text)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
            onPressed: () => recitation.playRange(
              widget.surah,
              ayah.number,
              ayah.number,
              times: 3,
            ),
            icon: const Icon(Icons.replay_rounded, size: 30),
            label: Text(
              tr('استمع ثلاث مرات وكرّر معه', 'Listen three times and repeat'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () {
              recitation.stop();
              if (last) {
                widget.onDone();
              } else {
                setState(() => _i++);
              }
            },
            child: Text(
              last ? tr('أنهيتُ التكرار', 'I finished') : tr('الآية التالية', 'Next ayah'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stages 3 and 4: word games on a few ayahs of the surah. [fill] hides
/// some words for the child to put back; otherwise all the words come
/// shuffled and go back in order.
class WordGame extends StatefulWidget {
  const WordGame({
    super.key,
    required this.ayahs,
    required this.fill,
    required this.onDone,
    this.easy = false,
  });

  final List<Ayah> ayahs;
  final bool fill;
  final bool easy;
  final VoidCallback onDone;

  @override
  State<WordGame> createState() => _WordGameState();
}

class _WordGameState extends State<WordGame> {
  int _i = 0;
  late FillRound _fill;
  late OrderRound _order;
  final _used = <int>{};
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final ayah = widget.ayahs[_i];
    final seed = ayah.surah * 1000 + ayah.number;
    if (widget.fill) {
      _fill = FillRound(ayah.text, easy: widget.easy, seed: seed);
    } else {
      _order = OrderRound(ayah.text, seed: seed);
    }
    _used.clear();
    _wrong = false;
  }

  bool get _roundDone => widget.fill ? _fill.done : _order.done;

  List<String> get _options => widget.fill ? _fill.options : _order.options;

  void _pick(int index) {
    final word = _options[index];
    final ok = widget.fill ? _fill.tryPlace(word) : _order.tryPlace(word);
    setState(() {
      _wrong = !ok;
      if (ok) _used.add(index);
    });
  }

  void _next() {
    if (_i == widget.ayahs.length - 1) {
      widget.onDone();
    } else {
      setState(() {
        _i++;
        _start();
      });
    }
  }

  Widget _word(BuildContext context, String text, {Color? color}) => Text(
    text,
    style: TextStyle(
      fontFamily: AppTheme.secondaryFontFamily,
      fontSize: 30,
      height: 2,
      color: color,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = _options;
    final Widget sentence;
    if (widget.fill) {
      sentence = Wrap(
        textDirection: TextDirection.rtl,
        alignment: WrapAlignment.center,
        spacing: 10,
        children: [
          for (var k = 0; k < _fill.words.length; k++)
            if (_fill.isBlank(k) && !_fill.isFilled(k))
              Container(
                width: 64,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.gold, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              )
            else
              _word(
                context,
                _fill.words[k],
                color: _fill.isBlank(k) ? colorScheme.gold : null,
              ),
        ],
      );
    } else {
      sentence = Wrap(
        textDirection: TextDirection.rtl,
        alignment: WrapAlignment.center,
        spacing: 10,
        children: [
          for (final w in _order.placed) _word(context, w, color: colorScheme.gold),
          if (!_order.done)
            Container(
              width: 64,
              height: 40,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.gold, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              '${_i + 1} من ${widget.ayahs.length}',
              '${_i + 1} of ${widget.ayahs.length}',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.fill
                ? tr('أكمل الكلمات الناقصة', 'Fill in the missing words')
                : tr('رتّب الكلمات', 'Put the words in order'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(child: SingleChildScrollView(child: sentence)),
          if (_wrong)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tr('حاول مرة أخرى', 'Try again'),
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error, fontSize: 18),
              ),
            ),
          if (_roundDone)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _next,
              child: Text(
                _i == widget.ayahs.length - 1
                    ? tr('أحسنت! إنهاء', 'Well done! Finish')
                    : tr('أحسنت! التالية', 'Well done! Next'),
                style: const TextStyle(fontSize: 20),
              ),
            )
          else
            Wrap(
              textDirection: TextDirection.rtl,
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var k = 0; k < options.length; k++)
                  if (!_used.contains(k))
                    ActionChip(
                      label: Text(
                        options[k],
                        style: const TextStyle(
                          fontFamily: AppTheme.secondaryFontFamily,
                          fontSize: 26,
                        ),
                      ),
                      onPressed: () => _pick(k),
                    ),
              ],
            ),
        ],
      ),
    );
  }
}
