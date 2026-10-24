import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/reading_provider.dart';

/// How far a surah has grown in the child's garden. Each stage is a
/// different way of learning it, and a surah moves up at most once a day,
/// so learning is spread over days.
enum GrowthStage {
  /// Listen to the whole surah.
  seed,

  /// Repeat each ayah after the reciter.
  sprout,

  /// Fill in the missing words.
  plant,

  /// Put the words in order; reviewed again and again.
  tree,
}

/// The order surahs are planted in: Al-Fatiha, then juz Amma (surahs 78 to
/// 114) from the shortest to the longest.
List<int> gardenPath(int Function(int surah) ayahCount) {
  final surahs = [for (var s = 78; s <= 114; s++) s]
    ..sort((a, b) {
      final byLength = ayahCount(a).compareTo(ayahCount(b));
      return byLength != 0 ? byLength : b.compareTo(a);
    });
  return [1, ...surahs];
}

class _Growth {
  const _Growth(this.stage, this.day);

  final int stage;

  /// The day (yyyy-mm-dd) it last grew.
  final String? day;
}

/// The child's garden: one plant per surah, kept on the phone only.
class GardenProvider extends ChangeNotifier {
  GardenProvider(this.prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final saved = prefs.getString('garden.growth');
    if (saved != null) {
      try {
        _growth = (jsonDecode(saved) as Map<String, dynamic>).map((k, v) {
          final e = v as Map<String, dynamic>;
          return MapEntry(int.parse(k), _Growth(e['s'] as int, e['d'] as String?));
        });
      } catch (_) {
        _growth = {};
      }
    }
    final reviews = prefs.getString('garden.reviews');
    if (reviews != null) {
      try {
        _reviews = (jsonDecode(reviews) as Map<String, dynamic>).map(
          (k, v) => MapEntry(int.parse(k), v as int),
        );
      } catch (_) {
        _reviews = {};
      }
    }
    easy = prefs.getBool('garden.easy') ?? false;
  }

  final SharedPreferences prefs;
  final DateTime Function() _clock;

  Map<int, _Growth> _growth = {};
  Map<int, int> _reviews = {};

  /// The younger setting: fewer words hidden and shorter rounds.
  late bool easy;

  void setEasy(bool value) {
    easy = value;
    prefs.setBool('garden.easy', value);
    notifyListeners();
  }

  GrowthStage stageOf(int surah) => GrowthStage
      .values[(_growth[surah]?.stage ?? 0).clamp(0, GrowthStage.values.length - 1)];

  bool grewToday(int surah) =>
      _growth[surah]?.day == ReadingProvider.dayKey(_clock());

  /// Surahs that have become trees.
  int get trees =>
      _growth.values.where((g) => g.stage >= GrowthStage.tree.index).length;

  /// How many times [surah] was reviewed as a tree.
  int reviewsOf(int surah) => _reviews[surah] ?? 0;

  /// Moves [surah] up one stage, at most once a day. Returns the new stage,
  /// or null when it is already a tree or already grew today.
  GrowthStage? grow(int surah) {
    if (stageOf(surah) == GrowthStage.tree || grewToday(surah)) return null;
    final next = (_growth[surah]?.stage ?? 0) + 1;
    _growth[surah] = _Growth(next, ReadingProvider.dayKey(_clock()));
    _save();
    notifyListeners();
    return GrowthStage.values[next];
  }

  /// Counts a finished review round of a tree.
  void addReview(int surah) {
    _reviews[surah] = reviewsOf(surah) + 1;
    _save();
    notifyListeners();
  }

  void _save() {
    prefs
      ..setString(
        'garden.growth',
        jsonEncode({
          for (final e in _growth.entries)
            '${e.key}': {'s': e.value.stage, 'd': e.value.day},
        }),
      )
      ..setString(
        'garden.reviews',
        jsonEncode({for (final e in _reviews.entries) '${e.key}': e.value}),
      );
  }
}
