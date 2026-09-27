import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'planner.dart';
import '../core/language.dart';

/// Schedules the planned reminders with the system. Only Android and iOS
/// are supported; elsewhere every call is a no-op.
class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// The payload of the last tapped notification, until handled.
  final opened = ValueNotifier<String?>(null);

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
      onDidReceiveNotificationResponse: (response) =>
          opened.value = response.payload,
    );
    _ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      opened.value = launch!.notificationResponse?.payload;
    }
  }

  /// Sets up tap handling early, so a tap that launched the app is seen.
  Future<void> start() => _init();

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
        payload: n.payload,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  NotificationDetails _details(ReminderKind kind) {
    final (id, name) = switch (kind) {
      ReminderKind.prayer => ('prayer', tr('أوقات الصلاة', 'Prayer times')),
      ReminderKind.beforePrayer => (
        'before_prayer',
        tr('التذكير قبل الصلاة', 'Before the prayer'),
      ),
      ReminderKind.azkar => ('azkar', tr('تذكير الأذكار', 'Azkar reminders')),
      ReminderKind.wird => (
        'wird',
        tr('تذكير الورد', 'Daily reading reminders'),
      ),
      ReminderKind.friday => ('friday', tr('يوم الجمعة', 'Friday')),
      ReminderKind.ramadan => ('ramadan', tr('رمضان', 'Ramadan')),
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
