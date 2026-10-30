import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../kids/word_games.dart';
import '../quran/search.dart';

class TajweedRule {
  const TajweedRule({
    required this.id,
    required this.name,
    required this.definition,
    required this.letters,
    required this.mnemonic,
    required this.tip,
  });

  final String id;
  final String name;
  final String definition;

  /// The letters of the rule, separated by spaces; or a sentence.
  final String letters;
  final String mnemonic;
  final String tip;

  /// The letters one by one, when [letters] is a plain list of letters.
  List<String> get letterList {
    final parts = letters.split(' ').where((p) => p.isNotEmpty).toList();
    return parts.isNotEmpty && parts.every((p) => p.runes.length == 1)
        ? parts
        : const [];
  }
}

/// A place in the mushaf that shows a rule: words [from] to [to] of the
/// ayah (counted from 1), with the word [focus] being the one in question.
class TajweedExample {
  const TajweedExample({
    required this.rule,
    required this.surah,
    required this.ayah,
    required this.from,
    required this.to,
    required this.focus,
    this.letter,
  });

  final String rule;
  final int surah;
  final int ayah;
  final int from;
  final int to;
  final int focus;

  /// For lessons on letters (places of articulation, qualities): the letter
  /// itself, with no ayah.
  final String? letter;

  /// The words of the example, from the Quran text, or null if the ayah or
  /// the words are not there. A letter example gives the letter.
  List<String>? words(QuranSearch quran) {
    if (letter != null) return [letter!];
    for (final a in quran.ayahsOfSurah(surah)) {
      if (a.number != ayah) continue;
      final all = wordsOf(a.text);
      if (from < 1 || to > all.length || from > to) return null;
      return all.sublist(from - 1, to);
    }
    return null;
  }

  /// Index in [words] of the word in question.
  int get focusIndex => focus - from;
}

class TajweedNote {
  const TajweedNote({
    required this.title,
    required this.text,
    required this.examples,
  });

  final String title;
  final String text;
  final List<TajweedExample> examples;
}

class TajweedLesson {
  const TajweedLesson({
    required this.id,
    required this.title,
    required this.intro,
    required this.question,
    required this.rules,
    required this.examples,
    required this.notes,
    required this.tuhfat,
  });

  final String id;
  final String title;
  final String intro;

  /// What the quiz asks about the highlighted word.
  final String question;
  final List<TajweedRule> rules;
  final List<TajweedExample> examples;
  final List<TajweedNote> notes;

  /// The lines of Tuhfat al-Atfal on this subject, from the library.
  final List<String> tuhfat;

  TajweedRule? rule(String id) {
    for (final r in rules) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<TajweedExample> examplesOf(String ruleId) => [
    for (final e in examples)
      if (e.rule == ruleId) e,
  ];
}

class TajweedSource {
  const TajweedSource(this.name, this.url);

  final String name;
  final String? url;
}

class TajweedPack {
  const TajweedPack({
    required this.title,
    required this.reviewer,
    required this.reviewedOn,
    required this.license,
    required this.sources,
    required this.lessons,
  });

  final String title;
  final String reviewer;
  final String reviewedOn;
  final String license;
  final List<TajweedSource> sources;
  final List<TajweedLesson> lessons;
}

const tajweedAsset = 'assets/library/tajweed-lessons.json';

Future<TajweedPack> loadTajweedPack() async =>
    parseTajweedPack(await rootBundle.loadString(tajweedAsset));

TajweedExample _example(Map<String, dynamic> m) => TajweedExample(
  rule: m['rule'] as String,
  surah: m['surah'] as int,
  ayah: m['ayah'] as int,
  from: m['from'] as int,
  to: m['to'] as int,
  focus: m['focus'] as int,
  letter: m['letter'] as String?,
);

TajweedPack parseTajweedPack(String source) {
  final m = jsonDecode(source) as Map<String, dynamic>;
  return TajweedPack(
    title: m['title'] as String,
    reviewer: m['reviewer'] as String,
    reviewedOn: m['reviewedOn'] as String,
    license: m['license'] as String,
    sources: [
      for (final s in m['sources'] as List)
        TajweedSource(
          (s as Map<String, dynamic>)['name'] as String,
          s['url'] as String?,
        ),
    ],
    lessons: [
      for (final l in m['lessons'] as List)
        TajweedLesson(
          id: (l as Map<String, dynamic>)['id'] as String,
          title: l['title'] as String,
          intro: l['intro'] as String,
          question: l['question'] as String,
          rules: [
            for (final r in l['rules'] as List)
              TajweedRule(
                id: (r as Map<String, dynamic>)['id'] as String,
                name: r['name'] as String,
                definition: r['definition'] as String,
                letters: r['letters'] as String,
                mnemonic: r['mnemonic'] as String,
                tip: r['tip'] as String,
              ),
          ],
          examples: [
            for (final e in l['examples'] as List)
              _example(e as Map<String, dynamic>),
          ],
          notes: [
            for (final n in l['notes'] as List)
              TajweedNote(
                title: (n as Map<String, dynamic>)['title'] as String,
                text: n['text'] as String,
                examples: [
                  for (final e in n['examples'] as List)
                    _example(e as Map<String, dynamic>),
                ],
              ),
          ],
          tuhfat: [for (final t in l['tuhfat'] as List) t as String],
        ),
    ],
  );
}

/// Questions of a lesson's quiz: some of its examples, each asking which of
/// the lesson's rules applies.
class TajweedQuiz {
  TajweedQuiz(this.lesson, {int count = 8, int seed = 0})
    : examples = _choose(lesson, count, seed);

  final TajweedLesson lesson;
  final List<TajweedExample> examples;

  /// The rules the quiz offers as answers: those it asks about.
  List<TajweedRule> get options => [
    for (final r in lesson.rules)
      if (lesson.examplesOf(r.id).isNotEmpty) r,
  ];
  int _index = 0;
  int _correct = 0;
  String? _chosen;

  static List<TajweedExample> _choose(TajweedLesson lesson, int count, int seed) {
    final random = Random(seed);
    // Take them rule by rule in turn so every rule is asked about.
    final byRule = [
      for (final r in lesson.rules)
        if (lesson.examplesOf(r.id).isNotEmpty)
          lesson.examplesOf(r.id)..shuffle(random),
    ];
    final out = <TajweedExample>[];
    for (var round = 0; out.length < count; round++) {
      var any = false;
      for (final list in byRule) {
        if (round < list.length && out.length < count) {
          out.add(list[round]);
          any = true;
        }
      }
      if (!any) break;
    }
    return out..shuffle(random);
  }

  int get index => _index;
  int get correct => _correct;
  int get total => examples.length;
  bool get finished => _index >= examples.length;
  bool get answered => _chosen != null;
  String? get chosen => _chosen;
  TajweedExample get current => examples[_index];

  /// Records the answer (a rule id). Returns whether it was right; a second
  /// answer to the same question is ignored.
  bool answer(String ruleId) {
    if (finished || answered) return false;
    _chosen = ruleId;
    final right = ruleId == current.rule;
    if (right) _correct++;
    return right;
  }

  void next() {
    if (!answered) return;
    _index++;
    _chosen = null;
  }
}

/// Best quiz result of each lesson, as a percentage.
class TajweedProgress extends ChangeNotifier {
  TajweedProgress(this.prefs);

  final SharedPreferences prefs;

  static String _key(String lesson) => 'tajweed.best.$lesson';

  /// The best result of [lesson], or null if it was never taken.
  int? best(String lesson) => prefs.getInt(_key(lesson));

  void record(String lesson, int correct, int total) {
    if (total == 0) return;
    final percent = (correct * 100 / total).round();
    if (percent > (best(lesson) ?? -1)) {
      prefs.setInt(_key(lesson), percent);
      notifyListeners();
    }
  }
}
