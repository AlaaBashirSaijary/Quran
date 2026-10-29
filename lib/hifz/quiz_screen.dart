import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import 'hifz.dart';
import 'quiz.dart';

const _quizLength = 10;

/// "Test what I know": questions about the surahs marked as memorised.
/// The result goes into the review schedule.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final Future<QuranSearch> _quran = QuranSearch.load();
  bool _dueOnly = false;
  QuizSession? _session;
  bool _applied = false;

  void _start(QuranSearch quran, HifzProvider hifz) {
    final entries = _dueOnly ? hifz.due : hifz.all;
    final surahs = [for (final e in entries) e.surah]..shuffle();
    setState(() {
      _applied = false;
      _session = QuizSession(
        buildQuiz(
          surahs,
          quran.ayahsOfSurah,
          count: _quizLength,
          seed: DateTime.now().microsecondsSinceEpoch,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hifz = Provider.of<HifzProvider>(context);
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: Text(tr('اختبر محفوظي', 'Test my memorisation'))),
      body: FutureBuilder<QuranSearch>(
        future: _quran,
        initialData: QuranSearch.loaded,
        builder: (context, snap) {
          final quran = snap.data;
          if (quran == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (hifz.all.isEmpty) return const _NothingToTest();
          if (session == null) return _intro(quran, hifz);
          if (session.finished) {
            if (!_applied) {
              _applied = true;
              // The schedule changes the screen's own provider, so wait for
              // this frame to finish.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) session.applyTo(hifz);
              });
            }
            return _Result(
              session: session,
              onAgain: () => _start(quran, hifz),
            );
          }
          return _Question(
            key: ValueKey(session.index),
            session: session,
            onChanged: () => setState(() {}),
          );
        },
      ),
    );
  }

  Widget _intro(QuranSearch quran, HifzProvider hifz) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDue = hifz.due.isNotEmpty;
    if (!hasDue) _dueOnly = false;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(Icons.quiz_rounded, size: 72, color: colorScheme.gold),
        const SizedBox(height: 12),
        Text(
          tr(
            'عشرة أسئلة من السور التي حفظتها: أكمل الكلمة الناقصة، واختر الآية التي تأتي بعد الآية المعروضة.',
            'Ten questions from the surahs you know: fill in the missing word, and choose the ayah that comes next.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 20),
        if (hasDue)
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(
                  tr(
                    'المستحقة اليوم (${hifz.due.length})',
                    'Due today (${hifz.due.length})',
                  ),
                ),
              ),
              ButtonSegment(
                value: false,
                label: Text(
                  tr('كل محفوظي (${hifz.all.length})', 'All (${hifz.all.length})'),
                ),
              ),
            ],
            selected: {_dueOnly},
            onSelectionChanged: (v) => setState(() => _dueOnly = v.first),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: () => _start(quran, hifz),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(tr('ابدأ الاختبار', 'Start the test')),
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            'النتيجة تدخل في جدول المراجعة: السورة التي تتعثر بها تعود غداً.',
            'The result goes into your review schedule: a surah you stumble on comes back tomorrow.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.pageNumber, fontSize: 13),
        ),
      ],
    );
  }
}

class _NothingToTest extends StatelessWidget {
  const _NothingToTest();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          tr(
            'أضف سورة إلى «الحفظ والمراجعة» أولاً، ثم نختبرك فيها.',
            'Add a surah to Memorization first, then we can test you on it.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({super.key, required this.session, required this.onChanged});

  final QuizSession session;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final q = session.current;
    final isNext = q.kind == QuizKind.nextAyah;
    const ayahStyle = TextStyle(
      fontFamily: AppTheme.secondaryFontFamily,
      fontSize: 26,
      height: 2,
    );
    return Column(
      children: [
        LinearProgressIndicator(value: session.index / session.questions.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                tr(
                  'السؤال ${session.index + 1} من ${session.questions.length} · سورة ${getSurahNameArabic(q.surah)}',
                  'Question ${session.index + 1} of ${session.questions.length} · ${surahNameOf(q.surah)}',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.pageNumber),
              ),
              const SizedBox(height: 12),
              Text(
                isNext
                    ? tr('ما الآية التي تأتي بعد هذه؟', 'Which ayah comes next?')
                    : tr('ما الكلمة الناقصة؟', 'Which word is missing?'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.div.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  q.prompt,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: ayahStyle,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < q.options.length; i++)
                _Option(
                  text: q.options[i],
                  large: !isNext,
                  state: !session.answered
                      ? _OptionState.idle
                      : i == q.answer
                      ? _OptionState.right
                      : i == session.chosen
                      ? _OptionState.wrong
                      : _OptionState.idle,
                  onTap: session.answered
                      ? null
                      : () {
                          session.answer(i);
                          onChanged();
                        },
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: session.answered
                  ? () {
                      session.next();
                      onChanged();
                    }
                  : null,
              child: Text(
                session.index == session.questions.length - 1
                    ? tr('عرض النتيجة', 'See the result')
                    : tr('التالي', 'Next'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _OptionState { idle, right, wrong }

class _Option extends StatelessWidget {
  const _Option({
    required this.text,
    required this.large,
    required this.state,
    required this.onTap,
  });

  final String text;
  final bool large;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (state) {
      _OptionState.right => Colors.green,
      _OptionState.wrong => Colors.red,
      _OptionState.idle => colorScheme.outlineVariant,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: state == _OptionState.idle
            ? Colors.transparent
            : color.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.secondaryFontFamily,
                      fontSize: large ? 28 : 22,
                      height: 1.9,
                    ),
                  ),
                ),
                if (state == _OptionState.right)
                  const Icon(Icons.check_circle_rounded, color: Colors.green),
                if (state == _OptionState.wrong)
                  const Icon(Icons.cancel_rounded, color: Colors.red),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.session, required this.onAgain});

  final QuizSession session;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = session.questions.length;
    final score = session.correct;
    final headline = score == total
        ? tr('ما شاء الله! كلها صحيحة', 'Mashallah! All correct')
        : score >= total * 0.7
        ? tr('أحسنت، حفظك متين', 'Well done, your memorisation is solid')
        : tr('تحتاج إلى مراجعة', 'You need a little review');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(
          score >= total * 0.7 ? Icons.emoji_events_rounded : Icons.menu_book_rounded,
          size: 72,
          color: colorScheme.gold,
        ),
        const SizedBox(height: 8),
        Text(
          '$score / $total',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 20),
        for (final surah in session.surahs)
          Card(
            child: ListTile(
              leading: Icon(
                session.held(surah)
                    ? Icons.check_circle_rounded
                    : Icons.replay_rounded,
                color: session.held(surah) ? Colors.green : Colors.orange,
              ),
              title: Text(
                tr(
                  'سورة ${getSurahNameArabic(surah)}',
                  surahNameOf(surah),
                ),
              ),
              subtitle: Text(
                session.held(surah)
                    ? tr('متقنة', 'Held')
                    : tr('تعود للمراجعة غداً', 'Back for review tomorrow'),
              ),
              trailing: Text(
                '${session.correctOf(surah)} / ${session.askedOf(surah)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: onAgain,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(tr('اختبار جديد', 'Another test')),
        ),
      ],
    );
  }
}
