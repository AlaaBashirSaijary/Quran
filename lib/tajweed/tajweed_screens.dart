import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import 'lessons.dart';

const _ayahFont = TextStyle(
  fontFamily: AppTheme.secondaryFontFamily,
  fontSize: 26,
  height: 2,
);

/// The words of an example in the mushaf script, with the word in question
/// in the accent colour.
class ExamplePhrase extends StatelessWidget {
  const ExamplePhrase({
    super.key,
    required this.example,
    required this.quran,
    this.showWhere = true,
  });

  final TajweedExample example;
  final QuranSearch quran;
  final bool showWhere;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final words = example.words(quran);
    if (words == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              for (var i = 0; i < words.length; i++) ...[
                TextSpan(
                  text: words[i],
                  style: i == example.focusIndex
                      ? TextStyle(
                          color: colorScheme.gold,
                          fontWeight: FontWeight.bold,
                        )
                      : null,
                ),
                if (i < words.length - 1) const TextSpan(text: ' '),
              ],
            ],
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: _ayahFont,
        ),
        if (showWhere)
          Text(
            tr(
              'سورة ${getSurahNameArabic(example.surah)}، الآية ${example.ayah}',
              '${surahNameOf(example.surah)}, ayah ${example.ayah}',
            ),
            style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
          ),
      ],
    );
  }
}

/// "Tajweed lessons": the subjects, with the best quiz result of each.
class TajweedLessonsScreen extends StatefulWidget {
  const TajweedLessonsScreen({super.key});

  @override
  State<TajweedLessonsScreen> createState() => _TajweedLessonsScreenState();
}

class _TajweedLessonsScreenState extends State<TajweedLessonsScreen> {
  late final Future<TajweedPack> _pack = loadTajweedPack();
  late final Future<QuranSearch> _quran = QuranSearch.load();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = Provider.of<TajweedProgress>(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('دروس التجويد', 'Tajweed lessons'))),
      body: FutureBuilder<TajweedPack>(
        future: _pack,
        builder: (context, snap) {
          final pack = snap.data;
          if (pack == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final lesson in pack.lessons)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Icon(
                      Icons.record_voice_over_rounded,
                      color: colorScheme.gold,
                      size: 32,
                    ),
                    title: Text(
                      lesson.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      progress.best(lesson.id) == null
                          ? tr(
                              '${lesson.rules.length} أحكام · لم تختبر نفسك بعد',
                              '${lesson.rules.length} rules · no quiz taken yet',
                            )
                          : tr(
                              '${lesson.rules.length} أحكام · أفضل نتيجة ${progress.best(lesson.id)}%',
                              '${lesson.rules.length} rules · best ${progress.best(lesson.id)}%',
                            ),
                    ),
                    trailing: Icon(
                      Icons.chevron_left_rounded,
                      color: colorScheme.gold,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TajweedLessonScreen(lesson: lesson, quran: _quran),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _SourceCard(pack: pack),
            ],
          );
        },
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.pack});

  final TajweedPack pack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 12.5, color: colorScheme.pageNumber, height: 1.6);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.div.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('المصادر والمراجعة', 'Sources and review'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          for (final s in pack.sources)
            SelectableText(
              s.url == null ? '• ${s.name}' : '• ${s.name}\n  ${s.url}',
              style: style,
            ),
          const SizedBox(height: 6),
          Text('${tr('الترخيص', 'Licence')}: ${pack.license}', style: style),
          Text(
            '${tr('المراجعة', 'Review')}: ${pack.reviewer} (${pack.reviewedOn})',
            style: style,
          ),
        ],
      ),
    );
  }
}

class TajweedLessonScreen extends StatelessWidget {
  const TajweedLessonScreen({
    super.key,
    required this.lesson,
    required this.quran,
  });

  final TajweedLesson lesson;
  final Future<QuranSearch> quran;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TajweedQuizScreen(lesson: lesson, quran: quran),
          ),
        ),
        icon: const Icon(Icons.quiz_rounded),
        label: Text(tr('اختبر نفسك', 'Test yourself')),
      ),
      body: FutureBuilder<QuranSearch>(
        future: quran,
        initialData: QuranSearch.loaded,
        builder: (context, snap) {
          final q = snap.data;
          if (q == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(lesson.intro, style: const TextStyle(fontSize: 16, height: 1.8)),
              const SizedBox(height: 12),
              for (final rule in lesson.rules)
                _RuleCard(rule: rule, examples: lesson.examplesOf(rule.id), quran: q),
              for (final note in lesson.notes) _NoteCard(note: note, quran: q),
              if (lesson.tuhfat.isNotEmpty)
                Card(
                  child: ExpansionTile(
                    title: Text(
                      tr('أبيات تحفة الأطفال في هذا الباب', 'Verses of Tuhfat al-Atfal on this subject'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      for (final line in lesson.tuhfat)
                        Text(
                          line,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.secondaryFontFamily,
                            fontSize: 20,
                            height: 1.9,
                            color: colorScheme.onSurface,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.examples, required this.quran});

  final TajweedRule rule;
  final List<TajweedExample> examples;
  final QuranSearch quran;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final letters = rule.letterList;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rule.name,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: colorScheme.gold,
              ),
            ),
            const SizedBox(height: 6),
            Text(rule.definition, style: const TextStyle(fontSize: 15.5, height: 1.7)),
            if (letters.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final l in letters)
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.div.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(l, style: const TextStyle(fontSize: 20)),
                    ),
                ],
              ),
            ] else if (rule.letters.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${tr('حروفه', 'Letters')}: ${rule.letters}',
                style: TextStyle(color: colorScheme.pageNumber),
              ),
            ],
            if (rule.mnemonic.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                rule.mnemonic,
                style: TextStyle(
                  fontFamily: AppTheme.secondaryFontFamily,
                  fontSize: 18,
                  color: colorScheme.pageNumber,
                ),
              ),
            ],
            if (rule.tip.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                rule.tip,
                style: TextStyle(fontSize: 13.5, height: 1.6, color: colorScheme.pageNumber),
              ),
            ],
            if (examples.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                tr('أمثلة من المصحف', 'Examples from the mushaf'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final e in examples)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ExamplePhrase(example: e, quran: quran),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.quran});

  final TajweedNote note;
  final QuranSearch quran;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(note.text, style: const TextStyle(fontSize: 15, height: 1.7)),
            for (final e in note.examples)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ExamplePhrase(example: e, quran: quran),
              ),
          ],
        ),
      ),
    );
  }
}

/// The quiz of a lesson: a verse with one word in colour, and the rules to
/// choose from.
class TajweedQuizScreen extends StatefulWidget {
  const TajweedQuizScreen({super.key, required this.lesson, required this.quran});

  final TajweedLesson lesson;
  final Future<QuranSearch> quran;

  @override
  State<TajweedQuizScreen> createState() => _TajweedQuizScreenState();
}

class _TajweedQuizScreenState extends State<TajweedQuizScreen> {
  late TajweedQuiz _quiz = _new();
  bool _saved = false;

  TajweedQuiz _new() => TajweedQuiz(
    widget.lesson,
    seed: DateTime.now().microsecondsSinceEpoch,
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lesson = widget.lesson;
    return Scaffold(
      appBar: AppBar(title: Text(tr('اختبار: ${lesson.title}', 'Quiz: ${lesson.title}'))),
      body: FutureBuilder<QuranSearch>(
        future: widget.quran,
        initialData: QuranSearch.loaded,
        builder: (context, snap) {
          final q = snap.data;
          if (q == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_quiz.finished) return _result(context, colorScheme);
          final example = _quiz.current;
          return Column(
            children: [
              LinearProgressIndicator(value: _quiz.index / _quiz.total),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      tr(
                        'السؤال ${_quiz.index + 1} من ${_quiz.total}',
                        'Question ${_quiz.index + 1} of ${_quiz.total}',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.pageNumber),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lesson.question,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.div.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ExamplePhrase(example: example, quran: q),
                    ),
                    const SizedBox(height: 16),
                    for (final rule in lesson.rules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _choice(rule, example),
                      ),
                    if (_quiz.answered) ...[
                      const SizedBox(height: 4),
                      Text(
                        lesson.rule(example.rule)?.definition ?? '',
                        style: TextStyle(height: 1.7, color: colorScheme.pageNumber),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _quiz.answered ? () => setState(_quiz.next) : null,
                    child: Text(
                      _quiz.index == _quiz.total - 1
                          ? tr('عرض النتيجة', 'See the result')
                          : tr('التالي', 'Next'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _choice(TajweedRule rule, TajweedExample example) {
    final answered = _quiz.answered;
    final right = answered && rule.id == example.rule;
    final wrong = answered && rule.id == _quiz.chosen && !right;
    final color = right
        ? Colors.green
        : wrong
        ? Colors.red
        : Theme.of(context).colorScheme.outlineVariant;
    return Material(
      color: right || wrong ? color.withValues(alpha: 0.15) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: answered ? null : () => setState(() => _quiz.answer(rule.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(child: Text(rule.name, style: const TextStyle(fontSize: 17))),
              if (right) const Icon(Icons.check_circle_rounded, color: Colors.green),
              if (wrong) const Icon(Icons.cancel_rounded, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _result(BuildContext context, ColorScheme colorScheme) {
    if (!_saved) {
      _saved = true;
      final progress = Provider.of<TajweedProgress>(context, listen: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) progress.record(widget.lesson.id, _quiz.correct, _quiz.total);
      });
    }
    final good = _quiz.correct >= _quiz.total * 0.7;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(
          good ? Icons.emoji_events_rounded : Icons.menu_book_rounded,
          size: 72,
          color: colorScheme.gold,
        ),
        Text(
          '${_quiz.correct} / ${_quiz.total}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
        Text(
          good
              ? tr('أحسنت! فهمتَ هذا الدرس', 'Well done! You have understood this lesson')
              : tr('راجع الدرس ثم أعد المحاولة', 'Review the lesson and try again'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => setState(() {
            _quiz = _new();
            _saved = false;
          }),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(tr('اختبار جديد', 'Another quiz')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => Navigator.pop(context),
          child: Text(tr('العودة إلى الدرس', 'Back to the lesson')),
        ),
      ],
    );
  }
}
