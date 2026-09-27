import 'package:adhan_dart/adhan_dart.dart';

import '../hijri/hijri.dart';
import '../prayer/prayer.dart';

const _ramadan = 9;
const _shaban = 8;

/// Imsak is shown this long before Fajr, as a precaution; the fast itself
/// begins at Fajr.
const imsakBefore = Duration(minutes: 10);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The calendar day [n] days after [d] (safe across daylight saving).
DateTime _next(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

bool isRamadan(DateTime date, {int offset = 0}) =>
    hijriOf(date, offset: offset).month == _ramadan;

/// The days of this Ramadan, or of the next one when it is not Ramadan.
List<DateTime> ramadanDays(DateTime today, {int offset = 0}) {
  var day = _day(today);
  // Back to the first day if we are inside Ramadan.
  while (isRamadan(_next(day, -1), offset: offset)) {
    day = _next(day, -1);
  }
  while (!isRamadan(day, offset: offset)) {
    day = _next(day, 1);
  }
  return [for (var d = day; isRamadan(d, offset: offset); d = _next(d, 1)) d];
}

/// Whole days until Ramadan begins, from the second half of Sha'ban; null
/// at other times (and during Ramadan).
int? daysUntilRamadan(DateTime today, {int offset = 0}) {
  final h = hijriOf(today, offset: offset);
  if (h.month != _shaban || h.day < 15) return null;
  return ramadanDays(
    today,
    offset: offset,
  ).first.difference(_day(today)).inDays;
}

class FastingTimes {
  const FastingTimes(this.day, this.imsak, this.fajr, this.maghrib);

  final DateTime day;
  final DateTime imsak;

  /// The end of suhoor and the start of the fast.
  final DateTime fajr;

  /// Iftar.
  final DateTime maghrib;
}

FastingTimes fastingTimes(PrayerProvider prayer, DateTime day) {
  final times = {for (final t in prayer.timesOn(day)) t.prayer: t.time};
  final fajr = times[Prayer.fajr]!;
  return FastingTimes(
    _day(day),
    fajr.subtract(imsakBefore),
    fajr,
    times[Prayer.maghrib]!,
  );
}

enum FastingMoment { suhoor, iftar }

/// What the fasting person is waiting for now, during Ramadan: the end of
/// suhoor (Fajr) or iftar (Maghrib), and when.
(FastingMoment, DateTime)? nextFastingMoment(
  PrayerProvider prayer,
  DateTime now, {
  int offset = 0,
}) {
  final today = fastingTimes(prayer, now);
  if (isRamadan(now, offset: offset)) {
    if (now.isBefore(today.fajr)) return (FastingMoment.suhoor, today.fajr);
    if (now.isBefore(today.maghrib)) {
      return (FastingMoment.iftar, today.maghrib);
    }
  }
  final tomorrow = _next(now, 1);
  if (isRamadan(tomorrow, offset: offset)) {
    return (FastingMoment.suhoor, fastingTimes(prayer, tomorrow).fajr);
  }
  return null;
}
