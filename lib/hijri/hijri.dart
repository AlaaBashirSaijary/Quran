import 'package:hijri/hijri_array.dart';
import 'package:hijri/hijri_calendar.dart';
import '../core/language.dart';

class HijriDate {
  const HijriDate(this.day, this.month, this.year);

  final int day;
  final int month;
  final int year;

  String get monthName => isEnglish ? monthNames[month]! : arMonthNames[month]!;

  @override
  String toString() =>
      tr('$day $monthName $year هـ', '$day $monthName $year AH');
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

String dayName(DateTime date) =>
    isEnglish ? wdNames[date.weekday]! : _dayNames[date.weekday]!;

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

  if (eidFitr) notes.add(tr('عيد الفطر المبارك', 'Eid al-Fitr'));
  if (eidAdha) notes.add(tr('عيد الأضحى المبارك', 'Eid al-Adha'));
  if (tashreeq) notes.add(tr('من أيام التشريق', 'One of the days of Tashreeq'));
  if (ramadan) {
    notes.add(tr('شهر رمضان المبارك', 'The blessed month of Ramadan'));
  }
  if (h.month == _dhulHijjah && h.day == 9) {
    notes.add(tr('يوم عرفة', 'The Day of Arafah'));
  }
  if (h.month == _dhulHijjah && h.day <= 8) {
    notes.add(
      tr(
        'من العشر الأوائل من ذي الحجة',
        'One of the first ten days of Dhul Hijjah',
      ),
    );
  }
  if (h.month == _muharram && h.day == 9) {
    notes.add(tr('تاسوعاء', 'Tasu‘a (9 Muharram)'));
  }
  if (h.month == _muharram && h.day == 10) {
    notes.add(tr('يوم عاشوراء', 'The Day of Ashura'));
  }

  final noFasting = eidFitr || eidAdha || tashreeq || ramadan;
  if (!noFasting) {
    if (h.day >= 13 && h.day <= 15) {
      notes.add(tr('من الأيام البيض', 'One of the White Days (fasting 13–15)'));
    }
    if (h.month == _shawwal && h.day > 1) {
      notes.add(tr('صيام الست من شوال', 'Fasting six days of Shawwal'));
    }
    if (date.weekday == DateTime.monday) {
      notes.add(tr('صيام يوم الاثنين', 'Fasting on Monday'));
    }
    if (date.weekday == DateTime.thursday) {
      notes.add(tr('صيام يوم الخميس', 'Fasting on Thursday'));
    }
  }
  return notes;
}
