import 'package:adhan_dart/adhan_dart.dart';

import '../prayer/prayer.dart';
import 'notification_settings.dart';
import '../core/language.dart';

enum ReminderKind { prayer, beforePrayer, azkar, wird }

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.time,
    required this.title,
    required this.body,
    required this.kind,
  });

  final int id;

  /// Local time.
  final DateTime time;
  final String title;
  final String body;
  final ReminderKind kind;

  @override
  String toString() => '$id $time $title';
}

/// Slots per day; a notification's id is day * [_slots] + slot.
const _slots = 20;

/// The notifications to schedule for [days] days starting today, given the
/// prayer times and the user's choices. Only times after [now] are kept.
///
/// [wirdDoneToday] drops today's wird reminder once the goal is met.
List<PlannedNotification> planNotifications({
  required PrayerProvider prayer,
  required NotificationSettings settings,
  required DateTime now,
  required bool wirdDoneToday,
  int days = 7,
}) {
  final planned = <PlannedNotification>[];
  final today = DateTime(now.year, now.month, now.day);

  for (var day = 0; day < days; day++) {
    final date = today.add(Duration(days: day));
    final base = day * _slots;

    if (prayer.hasLocation) {
      final times = {for (final t in prayer.timesOn(date)) t.prayer: t};

      for (final (i, p) in NotificationSettings.prayers.indexed) {
        if (!settings.prayerEnabled(p)) continue;
        final t = times[p]!;
        planned.add(
          PlannedNotification(
            id: base + i,
            time: t.time,
            title: tr(
              'حان الآن وقت صلاة ${t.name}',
              'It is time for ${t.name}',
            ),
            body: prayer.placeName == null
                ? tr('حيّ على الصلاة', 'Come to prayer')
                : tr(
                    'حيّ على الصلاة · ${prayer.placeName}',
                    'Come to prayer · ${prayer.placeName}',
                  ),
            kind: ReminderKind.prayer,
          ),
        );
        if (settings.minutesBefore > 0) {
          planned.add(
            PlannedNotification(
              id: base + 5 + i,
              time: t.time.subtract(Duration(minutes: settings.minutesBefore)),
              title: tr(
                'صلاة ${t.name} بعد ${minutesLabel(settings.minutesBefore)}',
                '${t.name} in ${minutesLabel(settings.minutesBefore)}',
              ),
              body: tr('استعد للصلاة', 'Get ready for the prayer'),
              kind: ReminderKind.beforePrayer,
            ),
          );
        }
      }

      if (settings.morningAzkar) {
        planned.add(
          PlannedNotification(
            id: base + 10,
            time: times[Prayer.fajr]!.time.add(const Duration(minutes: 20)),
            title: tr('أذكار الصباح', 'Morning azkar'),
            body: tr(
              'حصّن يومك بأذكار الصباح',
              'Begin your day with the morning azkar',
            ),
            kind: ReminderKind.azkar,
          ),
        );
      }
      if (settings.eveningAzkar) {
        planned.add(
          PlannedNotification(
            id: base + 11,
            time: times[Prayer.asr]!.time.add(const Duration(minutes: 20)),
            title: tr('أذكار المساء', 'Evening azkar'),
            body: tr('لا تنسَ أذكار المساء', 'Do not forget the evening azkar'),
            kind: ReminderKind.azkar,
          ),
        );
      }
    }

    if (settings.wird && !(day == 0 && wirdDoneToday)) {
      planned.add(
        PlannedNotification(
          id: base + 12,
          time: date.add(Duration(minutes: settings.wirdMinutes)),
          title: tr('وردك من القرآن', 'Your daily Quran reading'),
          body: tr(
            'لم تُتمّ وردك اليوم بعد، ولو صفحة واحدة',
            'You have not finished today’s reading yet — even one page counts',
          ),
          kind: ReminderKind.wird,
        ),
      );
    }
  }

  return [
    for (final n in planned)
      if (n.time.isAfter(now)) n,
  ]..sort((a, b) => a.time.compareTo(b.time));
}

/// "5 دقائق", "15 دقيقة".
String minutesLabel(int n) =>
    isEnglish ? '$n minutes' : (n <= 10 ? '$n دقائق' : '$n دقيقة');
