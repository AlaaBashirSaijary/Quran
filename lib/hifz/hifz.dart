import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Days until the next review after each successful one.
const reviewIntervals = [1, 3, 7, 14, 30, 60];

class HifzEntry {
  const HifzEntry({
    required this.surah,
    required this.level,
    required this.due,
    this.lastReview,
  });

  final int surah;

  /// Successful reviews in a row, capped at the last interval.
  final int level;

  /// Day the next review is due (local midnight).
  final DateTime due;
  final DateTime? lastReview;

  String encode() =>
      '$surah|$level|${_day(due)}|${lastReview == null ? '' : _day(lastReview!)}';

  static HifzEntry? decode(String value) {
    final p = value.split('|');
    if (p.length < 3) return null;
    final surah = int.tryParse(p[0]);
    final level = int.tryParse(p[1]);
    final due = DateTime.tryParse(p[2]);
    if (surah == null || level == null || due == null) return null;
    return HifzEntry(
      surah: surah,
      level: level,
      due: due,
      lastReview: p.length > 3 && p[3].isNotEmpty
          ? DateTime.tryParse(p[3])
          : null,
    );
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Memorised surahs and their spaced review schedule.
class HifzProvider extends ChangeNotifier {
  HifzProvider(this.prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    for (final value in prefs.getStringList(_key) ?? const <String>[]) {
      final entry = HifzEntry.decode(value);
      if (entry != null) _entries[entry.surah] = entry;
    }
  }

  static const _key = 'hifz.surahs';

  final SharedPreferences prefs;
  final DateTime Function() _clock;
  final _entries = <int, HifzEntry>{};

  DateTime get _today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  bool isMemorised(int surah) => _entries.containsKey(surah);

  HifzEntry? entry(int surah) => _entries[surah];

  /// All memorised surahs in mushaf order.
  List<HifzEntry> get all =>
      _entries.values.toList()..sort((a, b) => a.surah.compareTo(b.surah));

  /// Surahs whose review is due today or overdue, most overdue first.
  List<HifzEntry> get due =>
      _entries.values.where((e) => !e.due.isAfter(_today)).toList()
        ..sort((a, b) => a.due.compareTo(b.due));

  /// Adds a memorised surah; its first review is tomorrow.
  void add(int surah) {
    if (isMemorised(surah)) return;
    _entries[surah] = HifzEntry(
      surah: surah,
      level: 0,
      due: _today.add(const Duration(days: 1)),
    );
    _save();
  }

  void remove(int surah) {
    if (_entries.remove(surah) != null) _save();
  }

  /// Records a review. A good one moves to the next, longer interval; a
  /// weak one brings the surah back tomorrow.
  void review(int surah, {required bool good}) {
    final current = _entries[surah];
    if (current == null) return;
    final level = good
        ? (current.level + 1).clamp(0, reviewIntervals.length - 1)
        : 0;
    final days = good ? reviewIntervals[current.level] : 1;
    _entries[surah] = HifzEntry(
      surah: surah,
      level: level,
      due: _today.add(Duration(days: days)),
      lastReview: _today,
    );
    _save();
  }

  void _save() {
    prefs.setStringList(_key, [for (final e in all) e.encode()]);
    notifyListeners();
  }
}
