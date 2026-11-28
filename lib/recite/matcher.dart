import '../kids/word_games.dart' show wordsOf;
import '../quran/search.dart';

/// A word of the passage being recited.
class ReciteWord {
  const ReciteWord({
    required this.surah,
    required this.ayah,
    required this.number,
    required this.text,
    required this.norm,
  });

  final int surah;
  final int ayah;

  /// Counted from 1 in the ayah.
  final int number;

  /// As written in the mushaf.
  final String text;

  /// The bare form used to compare with what was heard.
  final String norm;
}

/// The words of [ayahs], in order.
List<ReciteWord> reciteWords(List<Ayah> ayahs) => [
  for (final a in ayahs)
    for (final (i, w) in wordsOf(a.text).indexed)
      ReciteWord(
        surah: a.surah,
        ayah: a.number,
        number: i + 1,
        text: w,
        norm: normalizeArabic(w),
      ),
];

/// What was heard, as bare words.
List<String> heardWords(String text) => [
  for (final w in wordsOf(text))
    if (normalizeArabic(w).isNotEmpty) normalizeArabic(w),
];

int _distance(String a, String b) {
  if (a == b) return 0;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final row = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      row[j] = [
        previous[j] + 1,
        row[j - 1] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = row;
  }
  return previous[b.length];
}

/// Whether the heard word is the expected one. A speech model may mis-spell
/// a long word by a letter, so those get a little room; short words, where
/// one letter makes another word, must be exact.
bool wordsMatch(String expected, String heard) {
  if (expected == heard) return true;
  final shortest = expected.length < heard.length ? expected.length : heard.length;
  if (shortest < 5) return false;
  final allowed = expected.length >= 9 ? 2 : 1;
  return _distance(expected, heard) <= allowed;
}

enum MistakeKind {
  /// Another word was said instead.
  wrong,

  /// The word was left out.
  skipped,
}

class ReciteMistake {
  const ReciteMistake({required this.word, required this.heard, required this.kind});

  final ReciteWord word;

  /// The word heard in its place (empty when it was left out).
  final String heard;
  final MistakeKind kind;
}

enum _Op { match, wrong, skipped, extra }

class _Step {
  const _Step(this.op, this.expected, this.heard);

  final _Op op;

  /// Index in the expected window, or -1 for an extra word.
  final int expected;

  /// Index of the heard word, or -1 for a skipped word.
  final int heard;
}

class _Alignment {
  const _Alignment(this.reached, this.steps);

  /// How many expected words the heard words get to.
  final int reached;
  final List<_Step> steps;
}

// A word that fits nothing is more likely a wrong word than noise, so an
// extra word costs more than a wrong one (but less than a wrong word plus
// a left-out one).
const _extraCost = 1.4;

/// Lines up what was heard with the expected words from the start of the
/// window. The end of the window is free: the reciter is not done yet.
_Alignment _align(List<String> heard, List<ReciteWord> expected) {
  final n = heard.length;
  final m = expected.length;
  final inf = 1e9;
  final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, inf));
  final back = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  cost[0][0] = 0;
  // back: 1 match/wrong, 2 skipped, 3 extra, 4 two heard for one expected,
  // 5 one heard for two expected
  for (var i = 0; i <= n; i++) {
    for (var j = 0; j <= m; j++) {
      final here = cost[i][j];
      if (here >= inf) continue;
      void go(int ni, int nj, double c, int how) {
        if (ni > n || nj > m) return;
        if (here + c < cost[ni][nj] - 1e-9) {
          cost[ni][nj] = here + c;
          back[ni][nj] = how;
        }
      }

      if (i < n && j < m) {
        go(i + 1, j + 1, wordsMatch(expected[j].norm, heard[i]) ? 0 : 1, 1);
      }
      if (j < m) go(i, j + 1, 1, 2);
      if (i < n) go(i + 1, j, _extraCost, 3);
      if (i + 1 < n && j < m && wordsMatch(expected[j].norm, heard[i] + heard[i + 1])) {
        go(i + 2, j + 1, 0, 4);
      }
      if (i < n && j + 1 < m && wordsMatch(expected[j].norm + expected[j + 1].norm, heard[i])) {
        go(i + 1, j + 2, 0, 5);
      }
    }
  }
  var end = 0;
  for (var j = 0; j <= m; j++) {
    if (cost[n][j] < cost[n][end] - 1e-9) end = j;
  }
  final steps = <_Step>[];
  var i = n;
  var j = end;
  while (i > 0 || j > 0) {
    switch (back[i][j]) {
      case 1:
        steps.add(_Step(wordsMatch(expected[j - 1].norm, heard[i - 1]) ? _Op.match : _Op.wrong, j - 1, i - 1));
        i--;
        j--;
      case 2:
        steps.add(_Step(_Op.skipped, j - 1, -1));
        j--;
      case 3:
        steps.add(_Step(_Op.extra, -1, i - 1));
        i--;
      case 4:
        steps.add(_Step(_Op.match, j - 1, i - 2));
        i -= 2;
        j--;
      case 5:
        steps.add(_Step(_Op.match, j - 1, i - 1));
        steps.add(_Step(_Op.match, j - 2, i - 1));
        i--;
        j -= 2;
      default:
        i = 0;
        j = 0;
    }
  }
  return _Alignment(end, steps.reversed.toList());
}

/// A recitation in progress: follows what is heard along the words, and
/// stops at the first mistake until the reciter goes on.
class ReciteSession {
  ReciteSession(this.words, {this.basmala = const []});

  final List<ReciteWord> words;

  /// The words of the basmala, which may open a surah without being part of
  /// it. Empty when the passage does not begin with a surah.
  final List<String> basmala;

  /// Every word before this one has been recited right.
  int position = 0;

  /// The mistake the recitation stopped at, until [resume].
  ReciteMistake? pending;

  /// Every mistake of this session, in order.
  final mistakes = <ReciteMistake>[];

  int _base = 0;
  static const _lookAhead = 8;

  /// A mistake seen in a partial result, waiting to be seen again in the
  /// next one before it counts: a guess made from half a phrase is often
  /// wrong, and a false stop is worse than a slow one.
  String? _candidate;

  bool get finished => position >= words.length;

  /// How many words were recited right.
  int get recited => position;

  /// Takes what the recogniser has heard so far in the current utterance
  /// (all of it since the last pause). The last word of a partial result may
  /// still change, so it is not judged until more comes, or the result is
  /// final.
  void hear(List<String> heard, {required bool isFinal}) {
    if (pending != null || finished) return;
    var tokens = isFinal || heard.isEmpty ? heard : heard.sublist(0, heard.length - 1);
    if (_base == 0 && basmala.isNotEmpty) tokens = _withoutBasmala(tokens);
    if (tokens.isEmpty) {
      if (isFinal) _base = position;
      return;
    }
    final end = (_base + tokens.length + _lookAhead).clamp(0, words.length);
    final window = words.sublist(_base, end);
    final a = _align(tokens, window);
    final firstBad = a.steps.indexWhere((s) => s.op == _Op.wrong || s.op == _Op.skipped);
    if (firstBad >= 0) {
      final bad = a.steps[firstBad];
      if (!isFinal) {
        final key = '${bad.op}:${bad.expected}:${bad.heard >= 0 ? tokens[bad.heard] : ''}';
        if (key != _candidate) {
          // Seen for the first time: move up to it, but do not stop yet.
          _candidate = key;
          position = _base + bad.expected;
          return;
        }
      }
      _candidate = null;
      position = _base + bad.expected;
      final wrongOne = bad.op == _Op.wrong;
      pending = ReciteMistake(
        word: window[bad.expected],
        heard: wrongOne ? tokens[bad.heard] : '',
        kind: wrongOne ? MistakeKind.wrong : MistakeKind.skipped,
      );
      mistakes.add(pending!);
      // The other words left out in a row are mistakes as well.
      for (final s in a.steps.skip(firstBad + 1)) {
        if (s.op != _Op.skipped) break;
        mistakes.add(ReciteMistake(word: window[s.expected], heard: '', kind: MistakeKind.skipped));
      }
      return;
    }
    _candidate = null;
    if (a.reached == 0 && isFinal && tokens.length >= 2) {
      // Words that fit nothing of the passage.
      pending = ReciteMistake(word: words[_base], heard: tokens.first, kind: MistakeKind.wrong);
      mistakes.add(pending!);
      return;
    }
    position = _base + a.reached;
    if (isFinal) _base = position;
  }

  /// How far the words heard so far reach, counting the last, unsettled one
  /// too, without judging anything or changing the session. For showing
  /// progress at once while the real decision waits.
  int preview(List<String> heard) {
    if (pending != null || finished || heard.isEmpty) return position;
    var tokens = heard;
    if (_base == 0 && basmala.isNotEmpty) tokens = _withoutBasmala(tokens);
    if (tokens.isEmpty) return position;
    final end = (_base + tokens.length + _lookAhead).clamp(0, words.length);
    final a = _align(tokens, words.sublist(_base, end));
    final firstBad = a.steps.indexWhere((s) => s.op == _Op.wrong || s.op == _Op.skipped);
    final reach = _base + (firstBad >= 0 ? a.steps[firstBad].expected : a.reached);
    return reach > position ? reach : position;
  }

  /// The reciter goes on from the word where it stopped.
  void resume() {
    pending = null;
    _candidate = null;
    _base = position;
  }

  List<String> _withoutBasmala(List<String> tokens) {
    var k = 0;
    while (k < tokens.length && k < basmala.length && wordsMatch(basmala[k], tokens[k])) {
      k++;
    }
    return tokens.sublist(k);
  }
}
