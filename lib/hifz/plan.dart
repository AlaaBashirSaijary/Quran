import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/reading_provider.dart';
import '../quran/search.dart';

/// A piece of a surah to learn in one session: ayahs [from] to [to].
class PlanPortion {
  const PlanPortion(this.surah, this.from, this.to);

  final int surah;
  final int from;
  final int to;

  int get count => to - from + 1;

  @override
  bool operator ==(Object other) =>
      other is PlanPortion &&
      other.surah == surah &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(surah, from, to);

  String encode() => '$surah:$from:$to';

  static PlanPortion? decode(String value) {
    final p = value.split(':');
    if (p.length != 3) return null;
    final s = int.tryParse(p[0]), a = int.tryParse(p[1]), b = int.tryParse(p[2]);
    if (s == null || a == null || b == null) return null;
    return PlanPortion(s, a, b);
  }
}

/// Ready-made orders of surahs for a plan.
enum PlanScope {
  /// Juz Amma from An-Nas back to An-Naba, the usual way for beginners.
  juzAmmaBackwards,

  /// Juz Amma from An-Naba to An-Nas.
  juzAmmaForwards,

  /// The whole Quran from Al-Fatiha.
  wholeForwards,

  /// The whole Quran from An-Nas back to Al-Fatiha.
  wholeBackwards,
}

List<int> surahsOf(PlanScope scope) => switch (scope) {
  PlanScope.juzAmmaBackwards => [for (var s = 114; s >= 78; s--) s],
  PlanScope.juzAmmaForwards => [for (var s = 78; s <= 114; s++) s],
  PlanScope.wholeForwards => [for (var s = 1; s <= 114; s++) s],
  PlanScope.wholeBackwards => [for (var s = 114; s >= 1; s--) s],
};

/// How many sessions a plan of [surahs] takes at [perDay] ayahs a day. A
/// session never crosses the end of a surah, so a short surah is one session.
int sessionsFor(List<int> surahs, int perDay, List<int> counts) {
  var sessions = 0;
  for (final s in surahs) {
    sessions += (counts[s - 1] / perDay).ceil();
  }
  return sessions;
}

/// The memorisation plan: an order of surahs, a number of ayahs a day, and
/// how far the learner has got. A missed day does not skip anything: the
/// next session simply carries on, and the end date moves.
class HifzPlanProvider extends ChangeNotifier {
  HifzPlanProvider(
    this.prefs, {
    DateTime Function()? clock,
    List<int>? ayahCounts,
  }) : _clock = clock ?? DateTime.now,
       _counts = ayahCounts {
    final saved = prefs.getString('hifzplan.surahs');
    if (saved != null) {
      surahs = [
        for (final s in saved.split(','))
          if (int.tryParse(s) != null) int.parse(s),
      ];
    }
    perDay = prefs.getInt('hifzplan.perDay') ?? 3;
    done = prefs.getInt('hifzplan.done') ?? 0;
    startDay = prefs.getString('hifzplan.start');
    _days = {...?prefs.getStringList('hifzplan.days')};
    _reviewed = prefs.getString('hifzplan.reviewed');
    _history = [
      for (final v in prefs.getStringList('hifzplan.history') ?? const <String>[])
        ?PlanPortion.decode(v),
    ];
  }

  final SharedPreferences prefs;
  final DateTime Function() _clock;
  List<int>? _counts;

  /// The surahs in the order they are learnt; empty when there is no plan.
  List<int> surahs = const [];
  int perDay = 3;

  /// Ayahs learnt so far along the path.
  int done = 0;
  String? startDay;
  Set<String> _days = {};
  String? _reviewed;
  List<PlanPortion> _history = [];

  /// Reads the ayah counts from the Quran text, once it is loaded.
  Future<void> load() async {
    final quran = await QuranSearch.load();
    _counts = [for (var s = 1; s <= 114; s++) quran.ayahsOfSurah(s).length];
    notifyListeners();
  }

  bool get hasPlan => surahs.isNotEmpty;

  bool get ready => _counts != null;

  int ayahCount(int surah) => _counts![surah - 1];

  int get totalAyahs => surahs.fold(0, (sum, s) => sum + ayahCount(s));

  double get progress => hasPlan && ready ? done / totalAyahs : 0;

  bool get finished => hasPlan && ready && done >= totalAyahs;

  String get _today => ReadingProvider.dayKey(_clock());

  bool get doneToday => _days.contains(_today);

  /// Days on which a session was completed.
  int get daysCompleted => _days.length;

  /// Consecutive days with a completed session, counting from today, or
  /// from yesterday when today's session is not done yet.
  int get streak {
    var day = _clock();
    if (!doneToday) day = day.subtract(const Duration(days: 1));
    var n = 0;
    while (_days.contains(ReadingProvider.dayKey(day))) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// The next portion to learn, or null when the plan is finished.
  PlanPortion? get next {
    if (!hasPlan || !ready || finished) return null;
    var offset = done;
    for (final s in surahs) {
      final n = ayahCount(s);
      if (offset < n) return PlanPortion(s, offset + 1, (offset + perDay).clamp(1, n));
      offset -= n;
    }
    return null;
  }

  /// Whether finishing [portion] completes its surah.
  bool completesSurah(PlanPortion portion) => portion.to == ayahCount(portion.surah);

  /// Sessions still to do, including the next one.
  int get sessionsLeft {
    if (!hasPlan || !ready) return 0;
    var skip = done;
    var sessions = 0;
    for (final s in surahs) {
      final n = ayahCount(s);
      if (skip >= n) {
        skip -= n;
        continue;
      }
      sessions += ((n - skip) / perDay).ceil();
      skip = 0;
    }
    return sessions;
  }

  /// When the last session falls if one is done every day from now on.
  DateTime get estimatedEnd {
    final left = sessionsLeft;
    final today = _clock();
    final days = doneToday ? left : (left - 1).clamp(0, left);
    return DateTime(today.year, today.month, today.day + days);
  }

  /// Starts a plan, replacing any earlier one.
  void create({required List<int> surahs, required int perDay}) {
    assert(surahs.isNotEmpty && perDay >= 1);
    this.surahs = [...surahs];
    this.perDay = perDay;
    done = 0;
    startDay = _today;
    _days = {};
    _reviewed = null;
    _history = [];
    _save();
    notifyListeners();
  }

  /// Removes the plan.
  void clear() {
    surahs = const [];
    done = 0;
    startDay = null;
    _days = {};
    _reviewed = null;
    _history = [];
    _save();
    notifyListeners();
  }

  /// Records today's session as done and moves on. Returns the portion, or
  /// null when there was nothing to do (finished, or already done today).
  PlanPortion? completeToday() {
    final portion = next;
    if (portion == null || doneToday) return null;
    done += portion.count;
    _days.add(_today);
    _history = [portion, ..._history].take(20).toList();
    _save();
    notifyListeners();
    return portion;
  }

  /// The portions learnt most recently, newest first, for review.
  List<PlanPortion> recent([int n = 5]) => _history.take(n).toList();

  bool get reviewedToday => _reviewed == _today;

  void markReviewed() {
    _reviewed = _today;
    prefs.setString('hifzplan.reviewed', _today);
    notifyListeners();
  }

  void _save() {
    prefs
      ..setString('hifzplan.surahs', surahs.join(','))
      ..setInt('hifzplan.perDay', perDay)
      ..setInt('hifzplan.done', done)
      ..setStringList('hifzplan.days', _days.toList())
      ..setStringList('hifzplan.history', [for (final p in _history) p.encode()]);
    if (startDay != null) {
      prefs.setString('hifzplan.start', startDay!);
    } else {
      prefs.remove('hifzplan.start');
    }
    if (_reviewed != null) {
      prefs.setString('hifzplan.reviewed', _reviewed!);
    } else {
      prefs.remove('hifzplan.reviewed');
    }
  }
}
