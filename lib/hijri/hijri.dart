import 'package:hijri/hijri_array.dart';
import 'package:hijri/hijri_calendar.dart';

class HijriDate {
  const HijriDate(this.day, this.month, this.year);

  final int day;
  final int month;
  final int year;

  String get monthName => arMonthNames[month]!;

  @override
  String toString() => '$day $monthName $year هـ';
}

/// The Hijri date (Umm al-Qura calendar) of [date]. [offset] shifts it by
/// whole days for places where the month starts by local moon sighting.
HijriDate hijriOf(DateTime date, {int offset = 0}) {
  final h = HijriCalendar.fromDate(
    DateTime(date.year, date.month, date.day).add(Duration(days: offset)),
  );
  return HijriDate(h.hDay, h.hMonth, h.hYear);
}

const _dayNames = {
  DateTime.saturday: 'السبت',
  DateTime.sunday: 'الأحد',
  DateTime.monday: 'الاثنين',
  DateTime.tuesday: 'الثلاثاء',
  DateTime.wednesday: 'الأربعاء',
  DateTime.thursday: 'الخميس',
  DateTime.friday: 'الجمعة',
};

String dayName(DateTime date) => _dayNames[date.weekday]!;

const _muharram = 1;
const _ramadan = 9;
const _shawwal = 10;
const _dhulHijjah = 12;

/// Days of note on [date]: Eids, Arafah, Ashura, Ramadan, and the
/// recommended fasts (white days, Mondays and Thursdays, six of Shawwal,
/// the first nine of Dhul Hijjah). Fasting suggestions are left out on the
/// Eids and the days of Tashreeq, when fasting is not allowed.
List<String> occasionsOn(DateTime date, {int offset = 0}) {
  final h = hijriOf(date, offset: offset);
  final notes = <String>[];

  final eidFitr = h.month == _shawwal && h.day == 1;
  final eidAdha = h.month == _dhulHijjah && h.day == 10;
  final tashreeq = h.month == _dhulHijjah && h.day >= 11 && h.day <= 13;
  final ramadan = h.month == _ramadan;

  if (eidFitr) notes.add('عيد الفطر المبارك');
  if (eidAdha) notes.add('عيد الأضحى المبارك');
  if (tashreeq) notes.add('من أيام التشريق');
  if (ramadan) notes.add('شهر رمضان المبارك');
  if (h.month == _dhulHijjah && h.day == 9) notes.add('يوم عرفة');
  if (h.month == _dhulHijjah && h.day <= 8) {
    notes.add('من العشر الأوائل من ذي الحجة');
  }
  if (h.month == _muharram && h.day == 9) notes.add('تاسوعاء');
  if (h.month == _muharram && h.day == 10) notes.add('يوم عاشوراء');

  final noFasting = eidFitr || eidAdha || tashreeq || ramadan;
  if (!noFasting) {
    if (h.day >= 13 && h.day <= 15) notes.add('من الأيام البيض');
    if (h.month == _shawwal && h.day > 1) notes.add('صيام الست من شوال');
    if (date.weekday == DateTime.monday) notes.add('صيام يوم الاثنين');
    if (date.weekday == DateTime.thursday) notes.add('صيام يوم الخميس');
  }
  return notes;
}
