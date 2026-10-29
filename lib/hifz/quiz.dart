import 'dart:math';

import '../kids/word_games.dart';
import '../quran/search.dart';
import 'hifz.dart';

enum QuizKind { nextAyah, missingWord }

/// One multiple-choice question about a memorised surah.
class QuizQuestion {
  const QuizQuestion({
    required this.kind,
    required this.surah,
    required this.number,
    required this.prompt,
    required this.options,
    required this.answer,
  });

  final QuizKind kind;
  final int surah;

  /// The ayah the question is about.
  final int number;

  /// The ayah to read; for [QuizKind.missingWord] one word is replaced by
  /// [blank].
  final String prompt;
  final List<String> options;

  /// Index in [options] of the right choice.
  final int answer;
}

const blank = '＿＿＿';

const optionCount = 4;

/// Builds [count] questions over [surahs], taking the surahs in turn and
/// alternating the two kinds, so every surah gets asked about.
/// [ayahsOf] gives the ayahs of a surah in order; [seed] makes it repeatable.
List<QuizQuestion> buildQuiz(
  List<int> surahs,
  List<Ayah> Function(int surah) ayahsOf, {
  int count = 10,
  int seed = 0,
}) {
  if (surahs.isEmpty) return [];
  final random = Random(seed);
  final questions = <QuizQuestion>[];
  final asked = <String>{};
  var turn = 0;
  var misses = 0;
  while (questions.length < count && misses < count * 6) {
    final surah = surahs[turn % surahs.length];
    final first = (turn % surahs.length + turn ~/ surahs.length).isEven
        ? QuizKind.nextAyah
        : QuizKind.missingWord;
    turn++;
    final ayahs = ayahsOf(surah);
    QuizQuestion? ask(QuizKind kind) => kind == QuizKind.nextAyah
        ? _nextAyah(surah, ayahs, random, asked)
        : _missingWord(surah, ayahs, random, asked);
    // A surah too short for one kind (few ayahs to choose wrong ones from)
    // is asked the other way instead.
    final q =
        ask(first) ??
        ask(
          first == QuizKind.nextAyah
              ? QuizKind.missingWord
              : QuizKind.nextAyah,
        );
    if (q == null) {
      misses++;
      continue;
    }
    questions.add(q);
  }
  return questions;
}

/// Picks [optionCount] - 1 wrong choices from [pool], never equal to
/// [right] or each other, and returns them with the right one shuffled in.
({List<String> options, int answer}) _choices(
  String right,
  List<String> pool,
  Random random,
) {
  final wrong = <String>{};
  final shuffled = [...pool]..shuffle(random);
  for (final text in shuffled) {
    if (text == right) continue;
    wrong.add(text);
    if (wrong.length == optionCount - 1) break;
  }
  final options = [right, ...wrong]..shuffle(random);
  return (options: options, answer: options.indexOf(right));
}

QuizQuestion? _nextAyah(
  int surah,
  List<Ayah> ayahs,
  Random random,
  Set<String> asked,
) {
  if (ayahs.length < 2) return null;
  final starts = [
    for (var i = 0; i < ayahs.length - 1; i++)
      if (!asked.contains('n$surah:${ayahs[i].number}')) i,
  ];
  if (starts.isEmpty) return null;
  final i = starts[random.nextInt(starts.length)];
  final right = ayahs[i + 1].text;
  // Wrong choices come from the same surah, which is what makes it hard.
  final pool = [
    for (var j = 0; j < ayahs.length; j++)
      if (j != i && j != i + 1) ayahs[j].text,
  ];
  if (pool.length < optionCount - 1) return null;
  asked.add('n$surah:${ayahs[i].number}');
  final c = _choices(right, pool, random);
  return QuizQuestion(
    kind: QuizKind.nextAyah,
    surah: surah,
    number: ayahs[i].number,
    prompt: ayahs[i].text,
    options: c.options,
    answer: c.answer,
  );
}

QuizQuestion? _missingWord(
  int surah,
  List<Ayah> ayahs,
  Random random,
  Set<String> asked,
) {
  final candidates = [
    for (final a in ayahs)
      if (wordsOf(a.text).length >= 3 &&
          !asked.contains('w$surah:${a.number}'))
        a,
  ];
  if (candidates.isEmpty) return null;
  final ayah = candidates[random.nextInt(candidates.length)];
  final words = wordsOf(ayah.text);
  final hidden = random.nextInt(words.length);
  final right = words[hidden];
  final pool = [
    for (final a in ayahs)
      for (final w in wordsOf(a.text))
        if (w != right) w,
  ];
  if (pool.toSet().length < optionCount - 1) return null;
  asked.add('w$surah:${ayah.number}');
  final c = _choices(right, pool, random);
  return QuizQuestion(
    kind: QuizKind.missingWord,
    surah: surah,
    number: ayah.number,
    prompt: [
      for (var i = 0; i < words.length; i++) i == hidden ? blank : words[i],
    ].join(' '),
    options: c.options,
    answer: c.answer,
  );
}

/// Score of a quiz in progress.
class QuizSession {
  QuizSession(this.questions);

  final List<QuizQuestion> questions;
  final _correct = <int, int>{};
  final _asked = <int, int>{};
  int _index = 0;
  int? _chosen;

  int get index => _index;
  int? get chosen => _chosen;
  bool get answered => _chosen != null;
  bool get finished => _index >= questions.length;
  QuizQuestion get current => questions[_index];

  int get correct => _correct.values.fold(0, (a, b) => a + b);

  /// Records the choice for the current question. Returns whether it was
  /// right; a second answer to the same question is ignored.
  bool answer(int option) {
    if (finished || answered) return false;
    _chosen = option;
    final q = current;
    _asked[q.surah] = (_asked[q.surah] ?? 0) + 1;
    final right = option == q.answer;
    if (right) _correct[q.surah] = (_correct[q.surah] ?? 0) + 1;
    return right;
  }

  void next() {
    if (!answered) return;
    _index++;
    _chosen = null;
  }

  /// Surahs that were asked about, in the order of the quiz.
  List<int> get surahs => _asked.keys.toList();

  int askedOf(int surah) => _asked[surah] ?? 0;
  int correctOf(int surah) => _correct[surah] ?? 0;

  /// A surah is held when at least 70% of its questions were right.
  bool held(int surah) => correctOf(surah) >= askedOf(surah) * 0.7;

  /// Feeds the result into the review schedule: a surah that was not held
  /// comes back tomorrow, and one that was held moves up only when its
  /// review was due, so asking again and again does not push it away.
  void applyTo(HifzProvider hifz) {
    final due = hifz.due.map((e) => e.surah).toSet();
    for (final surah in surahs) {
      if (!hifz.isMemorised(surah)) continue;
      if (held(surah)) {
        if (due.contains(surah)) hifz.review(surah, good: true);
      } else {
        hifz.review(surah, good: false);
      }
    }
  }
}
