import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/recitation.dart';
import '../core/index.dart';
import '../kids/garden_screen.dart' show WordGame;
import '../quran/quran.dart';
import '../quran/search.dart';
import 'hifz.dart';
import 'plan.dart';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String portionLabel(PlanPortion p) => p.from == p.to
    ? tr(
        'سورة ${getSurahNameArabic(p.surah)}، الآية ${p.from}',
        '${surahNameOf(p.surah)}, ayah ${p.from}',
      )
    : tr(
        'سورة ${getSurahNameArabic(p.surah)}، الآيات ${p.from} إلى ${p.to}',
        '${surahNameOf(p.surah)}, ayahs ${p.from} to ${p.to}',
      );

String scopeName(PlanScope scope) => switch (scope) {
  PlanScope.juzAmmaBackwards => tr(
    'جزء عمّ، من الناس إلى النبأ',
    'Juz Amma, from An-Nas to An-Naba',
  ),
  PlanScope.juzAmmaForwards => tr(
    'جزء عمّ، من النبأ إلى الناس',
    'Juz Amma, from An-Naba to An-Nas',
  ),
  PlanScope.wholeForwards => tr(
    'القرآن كاملاً، من الفاتحة',
    'The whole Quran, from Al-Fatiha',
  ),
  PlanScope.wholeBackwards => tr(
    'القرآن كاملاً، من الناس إلى الفاتحة',
    'The whole Quran, from An-Nas back to Al-Fatiha',
  ),
};

/// "My memorisation plan": today's portion, a review of the last ones, and
/// how far you have come. Without a plan it offers to make one.
class HifzPlanScreen extends StatelessWidget {
  const HifzPlanScreen({super.key});

  Future<void> _change(BuildContext context, HifzPlanProvider plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('تغيير الخطة', 'Change the plan')),
        content: Text(
          tr(
            'تُحذف الخطة الحالية وتقدّمها، وتبدأ خطة جديدة. السور التي أضفتها إلى المراجعة تبقى.',
            'The current plan and its progress are removed and a new one starts. Surahs already in your review stay.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('تغيير', 'Change')),
          ),
        ],
      ),
    );
    if (ok == true) {
      plan.clear();
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlanSetupScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = Provider.of<HifzPlanProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('خطة الحفظ', 'Memorisation plan')),
        actions: [
          if (plan.hasPlan)
            IconButton(
              tooltip: tr('تغيير الخطة', 'Change the plan'),
              icon: const Icon(Icons.edit_calendar_rounded),
              onPressed: () => _change(context, plan),
            ),
        ],
      ),
      body: !plan.ready
          ? const Center(child: CircularProgressIndicator())
          : !plan.hasPlan
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_note_rounded, size: 72, color: colorScheme.gold),
                    const SizedBox(height: 12),
                    Text(
                      tr(
                        'ضع خطة لحفظ القرآن: اختر ما تحفظه وكم آية في اليوم، وسيقترح عليك التطبيق جلسة كل يوم، '
                            'وتُضاف كل سورة تكملها إلى مراجعة الحفظ.',
                        'Make a plan to memorise the Quran: choose what to learn and how many ayahs a day. The app suggests a session each day and adds every finished surah to your reviews.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.pageNumber),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PlanSetupScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tr('ابدأ خطة', 'Start a plan')),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProgressCard(plan: plan),
                const SizedBox(height: 12),
                _TodayCard(plan: plan),
                const SizedBox(height: 12),
                _ReviewCard(plan: plan),
              ],
            ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.plan});

  final HifzPlanProvider plan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = (plan.progress * 100).floor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(
                'تقدّمك: ${plan.done} من ${plan.totalAyahs} آية ($pct٪)',
                'Progress: ${plan.done} of ${plan.totalAyahs} ayahs ($pct%)',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: plan.progress,
                minHeight: 12,
                color: colorScheme.gold,
                backgroundColor: colorScheme.div,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              plan.finished
                  ? tr('أتممت الخطة. بارك الله فيك', 'You finished the plan.')
                  : tr(
                      '${plan.perDay} آيات في اليوم · تنتهي نحو ${_date(plan.estimatedEnd)} إن أنجزت جلسة كل يوم',
                      '${plan.perDay} ayahs a day · ends around ${_date(plan.estimatedEnd)} if you do a session every day',
                    ),
              style: TextStyle(color: colorScheme.pageNumber),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'أيام الإنجاز: ${plan.daysCompleted} · الأيام المتتالية: ${plan.streak}',
                'Days done: ${plan.daysCompleted} · Streak: ${plan.streak}',
              ),
              style: TextStyle(color: colorScheme.gold),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.plan});

  final HifzPlanProvider plan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final next = plan.next;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              plan.doneToday
                  ? tr('أنجزتَ جلسة اليوم ✓', 'Today\'s session is done ✓')
                  : tr('جلسة اليوم', 'Today\'s session'),
              style: TextStyle(
                color: colorScheme.gold,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (next == null)
              Text(tr('لا شيء متبقٍّ.', 'Nothing left.'))
            else ...[
              Text(
                plan.doneToday
                    ? tr('الجلسة القادمة: ${portionLabel(next)}', 'Next: ${portionLabel(next)}')
                    : portionLabel(next),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (!plan.doneToday) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlanSessionScreen(portion: next),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(tr('ابدأ الجلسة', 'Start the session')),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.plan});

  final HifzPlanProvider plan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recitation = Provider.of<RecitationProvider>(context, listen: false);
    final recent = plan.recent();
    if (recent.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('راجع ما حفظته مؤخراً', 'Review what you learnt lately'),
              style: TextStyle(
                color: colorScheme.gold,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            for (final p in recent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(portionLabel(p)),
                trailing: IconButton(
                  tooltip: tr('استمع', 'Listen'),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  onPressed: () => recitation.playRange(p.surah, p.from, p.to),
                ),
              ),
            const SizedBox(height: 6),
            plan.reviewedToday
                ? Text(
                    tr('راجعتَ اليوم ✓', 'Reviewed today ✓'),
                    style: TextStyle(color: colorScheme.gold),
                  )
                : OutlinedButton(
                    onPressed: () {
                      recitation.stop();
                      plan.markReviewed();
                    },
                    child: Text(tr('راجعتُها اليوم', 'I reviewed them today')),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Choosing what to memorise and how much a day.
class PlanSetupScreen extends StatefulWidget {
  const PlanSetupScreen({super.key});

  @override
  State<PlanSetupScreen> createState() => _PlanSetupScreenState();
}

class _PlanSetupScreenState extends State<PlanSetupScreen> {
  PlanScope _scope = PlanScope.juzAmmaBackwards;
  int _perDay = 3;

  @override
  Widget build(BuildContext context) {
    final plan = Provider.of<HifzPlanProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final counts = plan.ready
        ? [for (var s = 1; s <= 114; s++) plan.ayahCount(s)]
        : null;
    final sessions = counts == null
        ? 0
        : sessionsFor(surahsOf(_scope), _perDay, counts);
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + (sessions - 1).clamp(0, sessions));
    return Scaffold(
      appBar: AppBar(title: Text(tr('خطة جديدة', 'New plan'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr('ماذا تريد أن تحفظ؟', 'What do you want to memorise?'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          RadioGroup<PlanScope>(
            groupValue: _scope,
            onChanged: (v) {
              if (v != null) setState(() => _scope = v);
            },
            child: Column(
              children: [
                for (final s in PlanScope.values)
                  RadioListTile<PlanScope>(
                    value: s,
                    title: Text(scopeName(s)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('كم آية في اليوم؟', 'How many ayahs a day?'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final n in const [1, 2, 3, 5, 10])
                ChoiceChip(
                  label: Text('$n'),
                  selected: _perDay == n,
                  onSelected: (_) => setState(() => _perDay = n),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              'تنتهي الخطة بعد $sessions جلسة، أي نحو ${_date(end)} إن أنجزت جلسة كل يوم. '
                  'ولا تعبر الجلسة نهاية السورة، فالسورة القصيرة جلسة واحدة. '
                  'وإن فاتك يوم فلا يضيع شيء: تكمل من حيث وقفت ويتأخر الموعد.',
              'The plan takes $sessions sessions, ending around ${_date(end)} if you do one every day. A session never crosses the end of a surah. If you miss a day nothing is lost: you carry on and the end date moves.',
            ),
            style: TextStyle(color: colorScheme.pageNumber),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: !plan.ready
                ? null
                : () {
                    plan.create(surahs: surahsOf(_scope), perDay: _perDay);
                    Navigator.pop(context);
                  },
            child: Text(tr('ابدأ الخطة', 'Start the plan')),
          ),
        ],
      ),
    );
  }
}

/// One session: listen to today's portion, then test yourself on it.
class PlanSessionScreen extends StatefulWidget {
  const PlanSessionScreen({super.key, required this.portion});

  final PlanPortion portion;

  @override
  State<PlanSessionScreen> createState() => _PlanSessionScreenState();
}

class _PlanSessionScreenState extends State<PlanSessionScreen> {
  late final Future<QuranSearch> _quran = QuranSearch.load();
  int _step = 0;

  List<Ayah> _ayahs(QuranSearch quran) => [
    for (final a in quran.ayahsOfSurah(widget.portion.surah))
      if (a.number >= widget.portion.from && a.number <= widget.portion.to) a,
  ];

  Future<void> _complete() async {
    final plan = Provider.of<HifzPlanProvider>(context, listen: false);
    final hifz = Provider.of<HifzProvider>(context, listen: false);
    final portion = widget.portion;
    final finishes = plan.completesSurah(portion);
    plan.completeToday();
    var added = false;
    if (finishes && !hifz.isMemorised(portion.surah)) {
      hifz.add(portion.surah);
      added = true;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.star_rounded,
          size: 56,
          color: Theme.of(context).colorScheme.gold,
        ),
        content: Text(
          added
              ? tr(
                  'أحسنت! أتممتَ سورة ${getSurahNameArabic(portion.surah)} وأُضيفت إلى مراجعة الحفظ.',
                  'Well done! You finished ${surahNameOf(portion.surah)} and it was added to your reviews.',
                )
              : tr('أحسنت! أنجزتَ جلسة اليوم.', 'Well done! Today\'s session is done.'),
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
    final recitation = Provider.of<RecitationProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final portion = widget.portion;
    final playing =
        recitation.status == RecitationStatus.playing ||
        recitation.status == RecitationStatus.loading;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) recitation.stop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(portionLabel(portion))),
        body: FutureBuilder<QuranSearch>(
          future: _quran,
          initialData: QuranSearch.loaded,
          builder: (context, snap) {
            final quran = snap.data;
            if (quran == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final ayahs = _ayahs(quran);
            if (_step == 1) {
              return WordGame(
                texts: [for (final a in ayahs) a.text],
                fill: true,
                onDone: _complete,
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    tr(
                      'استمع واقرأ مع القارئ حتى تثبت الآيات',
                      'Listen and read along until the ayahs stay',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.pageNumber),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final a in ayahs)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.div.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            a.text,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontFamily: AppTheme.secondaryFontFamily,
                              fontSize: 28,
                              height: 2,
                            ),
                          ),
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
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                          onPressed: () => playing
                              ? recitation.stop()
                              : recitation.playRange(
                                  portion.surah,
                                  portion.from,
                                  portion.to,
                                  times: 3,
                                ),
                          icon: Icon(
                            playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            playing
                                ? tr('إيقاف', 'Stop')
                                : tr('استمع ثلاث مرات', 'Listen three times'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: () {
                            recitation.stop();
                            setState(() => _step = 1);
                          },
                          child: Text(tr('التالي: اختبر نفسك', 'Next: test yourself')),
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
