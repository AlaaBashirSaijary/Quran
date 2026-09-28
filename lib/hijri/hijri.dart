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
    DateTime(date.year, date.month, date.day + offset),
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
///
/// [weekly] includes the Monday and Thursday fasts.
List<String> occasionsOn(DateTime date, {int offset = 0, bool weekly = true}) {
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
    if (weekly && date.weekday == DateTime.monday) {
      notes.add(tr('صيام يوم الاثنين', 'Fasting on Monday'));
    }
    if (weekly && date.weekday == DateTime.thursday) {
      notes.add(tr('صيام يوم الخميس', 'Fasting on Thursday'));
    }
  }
  return notes;
}

/// The days of the Hijri month that [date] falls in.
List<DateTime> hijriMonthDays(DateTime date, {int offset = 0}) {
  var first = DateTime(date.year, date.month, date.day);
  while (hijriOf(first, offset: offset).day != 1) {
    first = DateTime(first.year, first.month, first.day - 1);
  }
  final month = hijriOf(first, offset: offset).month;
  return [
    for (
      var d = first;
      hijriOf(d, offset: offset).month == month;
      d = DateTime(d.year, d.month, d.day + 1)
    )
      d,
  ];
}

/// A recommended fast worth a reminder the evening before [date], or null.
///
/// The white days are announced once, before the 13th, and the six days
/// of Shawwal once, on the evening of Eid, rather than every day. Nothing
/// is suggested on the Eids, the days of Tashreeq or in Ramadan.
String? fastingReminderFor(
  DateTime date, {
  int offset = 0,
  bool weekly = true,
}) {
  final h = hijriOf(date, offset: offset);
  final eid =
      (h.month == _shawwal && h.day == 1) ||
      (h.month == _dhulHijjah && h.day == 10);
  final tashreeq = h.month == _dhulHijjah && h.day >= 11 && h.day <= 13;
  if (eid || tashreeq || h.month == _ramadan) return null;

  if (h.month == _dhulHijjah && h.day == 9) {
    return tr('غداً يوم عرفة', 'Tomorrow is the Day of Arafah');
  }
  if (h.month == _muharram && h.day == 10) {
    return tr('غداً يوم عاشوراء', 'Tomorrow is the Day of Ashura');
  }
  if (h.month == _muharram && h.day == 9) {
    return tr('غداً تاسوعاء، التاسع من محرم', 'Tomorrow is Tasu‘a, 9 Muharram');
  }
  if (h.day == 13) {
    return tr(
      'تبدأ غداً الأيام البيض (13 و14 و15)',
      'The White Days (13th–15th) begin tomorrow',
    );
  }
  if (h.month == _shawwal && h.day == 2) {
    return tr(
      'يمكنك من غد البدء بصيام الست من شوال',
      'From tomorrow you can fast the six days of Shawwal',
    );
  }
  if (weekly && date.weekday == DateTime.monday) {
    return tr(
      'غداً الاثنين، يُستحب صيامه',
      'Tomorrow is Monday, a sunnah fast',
    );
  }
  if (weekly && date.weekday == DateTime.thursday) {
    return tr(
      'غداً الخميس، يُستحب صيامه',
      'Tomorrow is Thursday, a sunnah fast',
    );
  }
  return null;
}
