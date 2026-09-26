import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'planner.dart';

/// Schedules the planned reminders with the system. Only Android and iOS
/// are supported; elsewhere every call is a no-op.
class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _init() async {
    if (_ready || !supported) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone: keep UTC offsets correct by scheduling in UTC.
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks for permission to notify (Android 13+, iOS). Returns false if
  /// the user refused.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await _init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true) ??
        false;
  }

  /// Whether reminders can fire at the exact minute (Android 12+ asks the
  /// user for this separately).
  Future<bool> canUseExactTimes() async {
    if (!supported || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    await _init();
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  Future<void> requestExactTimes() async {
    if (!supported) return;
    await _init();
    await _android?.requestExactAlarmsPermission();
  }

  /// Replaces every scheduled reminder with [planned].
  Future<void> schedule(List<PlannedNotification> planned) async {
    if (!supported) return;
    await _init();
    await _plugin.cancelAll();
    final exact = await canUseExactTimes();
    for (final n in planned) {
      await _plugin.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        scheduledDate: tz.TZDateTime.from(n.time, tz.local),
        notificationDetails: _details(n.kind),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  NotificationDetails _details(ReminderKind kind) {
    final (id, name) = switch (kind) {
      ReminderKind.prayer => ('prayer', 'أوقات الصلاة'),
      ReminderKind.beforePrayer => ('before_prayer', 'التذكير قبل الصلاة'),
      ReminderKind.azkar => ('azkar', 'تذكير الأذكار'),
      ReminderKind.wird => ('wird', 'تذكير الورد'),
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        name,
        importance: kind == ReminderKind.prayer
            ? Importance.high
            : Importance.defaultImportance,
        priority: kind == ReminderKind.prayer
            ? Priority.high
            : Priority.defaultPriority,
        category: kind == ReminderKind.prayer
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(presentSound: true),
    );
  }
}
