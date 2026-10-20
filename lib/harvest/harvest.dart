import '../providers/reading_provider.dart';
import '../providers/sebha_provider.dart';

/// The last [days] days of activity, gathered from what the app already
/// keeps on the phone: pages read, azkar completed and tasbeeh taps.
class Harvest {
  const Harvest({
    required this.days,
    required this.pages,
    required this.activeDays,
    required this.goalDays,
    required this.bestStreak,
    required this.azkarDays,
    required this.tasbeeh,
    required this.khatmaPercent,
    required this.khatmas,
  });

  final int days;

  /// Pages read in the period.
  final int pages;

  /// Days on which at least one page was read.
  final int activeDays;

  /// Days on which the daily reading goal was met.
  final int goalDays;

  /// Longest run of consecutive days with some reading.
  final int bestStreak;

  /// Days on which at least one azkar category was completed.
  final int azkarDays;

  /// Tasbeeh taps in the period (counted from when this feature arrived).
  final int tasbeeh;

  /// Progress of the current khatma, 0 to 100.
  final int khatmaPercent;

  /// Khatmas completed so far.
  final int khatmas;

  bool get isEmpty => pages == 0 && azkarDays == 0 && tasbeeh == 0;

  static final _azkarKey = RegExp(r'^azkar\..+\.(\d{4})-(\d{1,2})-(\d{1,2})$');

  /// Summarises the [days] days ending on [now] (today by default).
  static Harvest compute(
    ReadingProvider reading,
    SebhaProvider sebha, {
    DateTime? now,
    int days = 30,
  }) {
    final end = now ?? DateTime.now();
    final last = DateTime(end.year, end.month, end.day);
    final first = DateTime(last.year, last.month, last.day - (days - 1));

    final daily = reading.lastDays(days);
    var pages = 0, active = 0, goalDays = 0, best = 0, run = 0;
    for (final n in daily) {
      pages += n;
      if (n > 0) {
        active++;
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
      if (n >= reading.goal) goalDays++;
    }

    final done = <String>{};
    for (final key in reading.prefs.getKeys()) {
      final m = _azkarKey.firstMatch(key);
      if (m == null) continue;
      final date = DateTime(
        int.parse(m[1]!),
        int.parse(m[2]!),
        int.parse(m[3]!),
      );
      if (date.isBefore(first) || date.isAfter(last)) continue;
      try {
        final values = reading.prefs.getStringList(key);
        if (values != null &&
            values.isNotEmpty &&
            values.every((v) => v == '0')) {
          done.add('${date.year}-${date.month}-${date.day}');
        }
      } catch (_) {
        // Not a progress list: ignore.
      }
    }

    var taps = 0;
    final log = sebha.dayLog;
    for (var i = 0; i < days; i++) {
      final d = DateTime(last.year, last.month, last.day - i);
      taps += log[ReadingProvider.dayKey(d)] ?? 0;
    }

    return Harvest(
      days: days,
      pages: pages,
      activeDays: active,
      goalDays: goalDays,
      bestStreak: best,
      azkarDays: done.length,
      tasbeeh: taps,
      khatmaPercent: (reading.khatmaProgress * 100).round(),
      khatmas: reading.khatmas,
    );
  }
}
