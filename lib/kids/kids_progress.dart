import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/reading_provider.dart';

/// The short surahs shown in the kids' corner, shortest and most familiar
/// first. Only their numbers are chosen here: the text, the audio and the
/// names all come from the app's own Quran data.
const kidsSurahs = [
  108,
  112,
  113,
  114,
  110,
  103,
  105,
  106,
  107,
  109,
  111,
  104,
  1,
];

/// Stars a child has earned: one per surah per day for reading it, and one
/// for each completed round of the little tasbeeh. Kept on the phone only.
class KidsProgress extends ChangeNotifier {
  KidsProgress(this.prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final saved = prefs.getString('kids.surahDays');
    if (saved != null) {
      try {
        _surahDays = (jsonDecode(saved) as Map<String, dynamic>).map(
          (k, v) => MapEntry(int.parse(k), {for (final d in v as List) '$d'}),
        );
      } catch (_) {
        _surahDays = {};
      }
    }
    dhikrRounds = prefs.getInt('kids.dhikrRounds') ?? 0;
  }

  final SharedPreferences prefs;
  final DateTime Function() _clock;

  Map<int, Set<String>> _surahDays = {};
  late int dhikrRounds;

  /// Stars earned for [surah] (one for each different day).
  int starsFor(int surah) => _surahDays[surah]?.length ?? 0;

  /// Whether [surah] already earned today's star.
  bool earnedToday(int surah) =>
      _surahDays[surah]?.contains(ReadingProvider.dayKey(_clock())) ?? false;

  int get totalStars =>
      _surahDays.values.fold(0, (sum, days) => sum + days.length) +
      dhikrRounds;

  /// Gives [surah] its star for today. Returns false if it already has it.
  bool earnToday(int surah) {
    if (earnedToday(surah)) return false;
    (_surahDays[surah] ??= {}).add(ReadingProvider.dayKey(_clock()));
    prefs.setString(
      'kids.surahDays',
      jsonEncode({
        for (final e in _surahDays.entries) '${e.key}': e.value.toList(),
      }),
    );
    notifyListeners();
    return true;
  }

  /// A star for finishing a round of the little tasbeeh.
  void addDhikrRound() {
    dhikrRounds++;
    prefs.setInt('kids.dhikrRounds', dhikrRounds);
    notifyListeners();
  }
}
