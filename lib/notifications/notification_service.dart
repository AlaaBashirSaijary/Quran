import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'adhan_sound.dart';
import 'planner.dart';
import '../core/language.dart';

/// Schedules the planned reminders with the system. Only Android and iOS
/// are supported; elsewhere every call is a no-op.
class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _adhanUri;

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

  /// Sets up the plugin once. Returns false when notifications cannot work
  /// here (the plugin failed to start), so callers skip quietly.
  Future<bool> _init() async {
    if (_ready) return true;
    if (!supported) return false;
    try {
      await _setUp();
      return _ready = true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setUp() async {
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
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      opened.value = launch!.notificationResponse?.payload;
    }
  }

  /// Sets up tap handling early, so a tap that launched the app is seen.
  Future<void> start() async {
    await _init();
  }

  /// Asks for permission to notify (Android 13+, iOS). Returns false if
  /// the user refused.
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
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
    if (!await _init()) return true;
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  Future<void> requestExactTimes() async {
    if (!await _init()) return;
    await _android?.requestExactAlarmsPermission();
  }

  /// The notification channel of prayer times: one per chosen sound,
  /// since Android fixes a channel's sound once it exists.
  static String prayerChannel(String? adhanUri) =>
      adhanUri == null ? 'prayer' : 'prayer_${soundKey(adhanUri)}';

  /// Replaces every scheduled reminder with [planned]. Prayer times play
  /// [adhanUri] when given.
  Future<void> schedule(
    List<PlannedNotification> planned, {
    String? adhanUri,
  }) async {
    if (!await _init()) return;
    await _plugin.cancelAll();
    _adhanUri = adhanUri;
    // Remove the channels of sounds no longer chosen.
    final current = prayerChannel(adhanUri);
    for (final channel
        in await _android?.getNotificationChannels() ?? const []) {
      if (channel.id.startsWith('prayer') &&
          channel.id != current &&
          channel.id != 'prayer') {
        await _android?.deleteNotificationChannel(channelId: channel.id);
      }
    }
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
      ReminderKind.prayer => (
        prayerChannel(_adhanUri),
        _adhanUri == null
            ? tr('أوقات الصلاة', 'Prayer times')
            : tr('أوقات الصلاة (الأذان)', 'Prayer times (adhan)'),
      ),
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
      ReminderKind.fasting => (
        'fasting',
        tr('صيام التطوّع', 'Voluntary fasts'),
      ),
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
        sound: kind == ReminderKind.prayer && _adhanUri != null
            ? UriAndroidNotificationSound(_adhanUri!)
            : null,
      ),
      iOS: const DarwinNotificationDetails(presentSound: true),
    );
  }
}
