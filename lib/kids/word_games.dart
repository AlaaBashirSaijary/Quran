import 'dart:math';

/// The words of an ayah, split on spaces.
List<String> wordsOf(String ayah) =>
    ayah.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Which words to hide in a fill-in round: every third word (every fourth
/// for the younger setting), and always at least one.
Set<int> hiddenIndexes(int count, {bool easy = false}) {
  if (count <= 0) return {};
  final step = easy ? 4 : 3;
  final hidden = {
    for (var i = 0; i < count; i++)
      if (i % step == step - 1) i,
  };
  return hidden.isEmpty ? {count - 1} : hidden;
}

/// A few ayahs spread across the surah, so a round stays short.
List<T> sampleEvenly<T>(List<T> items, int max) {
  if (items.length <= max) return [...items];
  return [for (var i = 0; i < max; i++) items[(i * items.length) ~/ max]];
}

/// A stable shuffle, so the same ayah always shows its words the same way.
List<T> seededShuffle<T>(List<T> items, int seed) =>
    [...items]..shuffle(Random(seed));

/// "Fill in the missing words": some words are blanks, and the child picks
/// the right words from a shuffled set.
class FillRound {
  FillRound(String ayah, {bool easy = false, int seed = 0})
    : words = wordsOf(ayah) {
    hidden = hiddenIndexes(words.length, easy: easy);
    options = seededShuffle([for (final i in hidden.toList()..sort()) words[i]], seed);
    _blanks = hidden.toList()..sort();
  }

  final List<String> words;
  late final Set<int> hidden;

  /// The words offered, shuffled.
  late final List<String> options;
  late final List<int> _blanks;
  int _filled = 0;

  /// How many blanks are filled, from the first.
  int get filled => _filled;

  bool get done => _filled >= _blanks.length;

  bool isBlank(int index) => hidden.contains(index);

  /// Whether the blank at [index] has been filled.
  bool isFilled(int index) {
    final k = _blanks.indexOf(index);
    return k >= 0 && k < _filled;
  }

  /// Offers [word] for the next blank. Returns whether it was right.
  bool tryPlace(String word) {
    if (done) return false;
    if (words[_blanks[_filled]] != word) return false;
    _filled++;
    return true;
  }
}

/// "Put the words in order": the words come shuffled and the child taps
/// them in the order of the ayah.
class OrderRound {
  OrderRound(String ayah, {int seed = 0}) : words = wordsOf(ayah) {
    options = seededShuffle(words, seed);
  }

  final List<String> words;
  late final List<String> options;
  int _next = 0;

  /// The words placed so far, in order.
  List<String> get placed => words.take(_next).toList();

  bool get done => _next >= words.length;

  /// Offers [word] as the next one. Returns whether it was right.
  bool tryPlace(String word) {
    if (done) return false;
    if (words[_next] != word) return false;
    _next++;
    return true;
  }
}
