import 'dart:convert';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/language.dart';
import '../notifications/notification_settings.dart';
import '../prayer/prayer.dart';

/// A social app the prayer lock can cover.
class SocialApp {
  const SocialApp(this.package, this.name, {this.chosen = true});

  final String package;
  final String name;

  /// Whether it is covered before the user chooses.
  final bool chosen;
}

/// Apps the lock knows by package name. The user picks among those that
/// are installed.
const socialApps = [
  SocialApp('com.facebook.katana', 'Facebook'),
  SocialApp('com.facebook.lite', 'Facebook Lite'),
  SocialApp('com.facebook.orca', 'Messenger'),
  SocialApp('com.instagram.android', 'Instagram'),
  SocialApp('com.twitter.android', 'X (Twitter)'),
  SocialApp('com.zhiliaoapp.musically', 'TikTok'),
  SocialApp('com.ss.android.ugc.trill', 'TikTok'),
  SocialApp('com.snapchat.android', 'Snapchat'),
  SocialApp('com.whatsapp', 'WhatsApp'),
  SocialApp('com.whatsapp.w4b', 'WhatsApp Business'),
  SocialApp('org.telegram.messenger', 'Telegram'),
  SocialApp('com.pinterest', 'Pinterest'),
  SocialApp('com.reddit.frontpage', 'Reddit'),
  SocialApp('com.linkedin.android', 'LinkedIn'),
  SocialApp('com.discord', 'Discord'),
  SocialApp('com.viber.voip', 'Viber'),
  SocialApp('com.google.android.youtube', 'YouTube', chosen: false),
];

/// Minutes after the prayer time after which the lock ends by itself, if
/// the user has not said they finished.
const lockDurations = [15, 30, 45, 60];

/// Days of prayer times given to the lock. It cannot calculate them itself,
/// so it stops if the app is not opened for this long.
const lockDays = 10;

/// The user's choices for the prayer lock. Saved under `prayerlock.*`.
class PrayerLockSettings extends ChangeNotifier {
  PrayerLockSettings(this.prefs) {
    enabled = prefs.getBool('prayerlock.enabled') ?? false;
    minutes = prefs.getInt('prayerlock.minutes') ?? 30;
    for (final p in NotificationSettings.prayers) {
      _prayer[p] = prefs.getBool('prayerlock.${p.name}') ?? true;
    }
    final saved = prefs.getStringList('prayerlock.apps');
    _apps = saved?.toSet() ?? {
      for (final a in socialApps)
        if (a.chosen) a.package,
    };
  }

  final SharedPreferences prefs;
  final _prayer = <Prayer, bool>{};
  late Set<String> _apps;

  /// Off until the user turns it on.
  late bool enabled;

  /// See [lockDurations].
  late int minutes;

  bool prayerOn(Prayer prayer) => _prayer[prayer] ?? true;

  Set<String> get apps => {..._apps};

  bool appOn(String package) => _apps.contains(package);

  void setEnabled(bool value) {
    enabled = value;
    prefs.setBool('prayerlock.enabled', value);
    notifyListeners();
  }

  void setMinutes(int value) {
    minutes = value;
    prefs.setInt('prayerlock.minutes', value);
    notifyListeners();
  }

  void setPrayer(Prayer prayer, bool value) {
    _prayer[prayer] = value;
    prefs.setBool('prayerlock.${prayer.name}', value);
    notifyListeners();
  }

  void setApp(String package, bool value) {
    value ? _apps.add(package) : _apps.remove(package);
    prefs.setStringList('prayerlock.apps', _apps.toList()..sort());
    notifyListeners();
  }

  String get signature => [
    enabled,
    minutes,
    for (final p in NotificationSettings.prayers) prayerOn(p),
    (_apps.toList()..sort()).join(','),
  ].join('|');
}

/// What the native side reads (PrayerLock.kt): the choices and the coming
/// prayer times of the prayers that lock, as [name, epoch milliseconds].
Map<String, Object?> lockConfig(
  PrayerLockSettings settings,
  PrayerProvider prayer,
  DateTime now, {
  int days = lockDays,
}) {
  final today = DateTime(now.year, now.month, now.day);
  return {
    'enabled': settings.enabled && prayer.hasLocation,
    'maxMinutes': settings.minutes,
    'en': isEnglish,
    'apps': settings.apps.toList()..sort(),
    'times': [
      if (prayer.hasLocation)
        for (var d = 0; d < days; d++)
          for (final t in prayer.timesOn(today.add(Duration(days: d))))
            if (t.prayer != Prayer.sunrise && settings.prayerOn(t.prayer))
              [t.name, t.time.millisecondsSinceEpoch],
    ],
  };
}

/// The name of the prayer whose lock is on at [now], or null. The same rule
/// as the native side: the last prayer time passed less than [minutes]
/// ago, and the user has not finished since ([doneAt], epoch milliseconds).
String? activeLock(
  List<List<Object>> times,
  DateTime now,
  int minutes, {
  int doneAt = 0,
}) {
  final at = now.millisecondsSinceEpoch;
  String? name;
  var latest = 0;
  for (final t in times) {
    final time = t[1] as int;
    if (time <= at && time > latest) {
      latest = time;
      name = t[0] as String;
    }
  }
  if (name == null || at - latest >= minutes * 60000) return null;
  if (doneAt >= latest) return null;
  return name;
}

/// Gives the native side the choices and times. Does nothing useful off
/// Android, where the lock does not exist.
Future<void> syncPrayerLock(
  PrayerLockSettings settings,
  PrayerProvider prayer,
  DateTime now,
) => settings.prefs.setString(
  'prayerlock.config',
  jsonEncode(lockConfig(settings, prayer, now)),
);

class LockStatus {
  const LockStatus({this.serviceOn = false, this.active = false, this.prayer});

  /// The accessibility service is turned on in the phone's settings.
  final bool serviceOn;
  final bool active;
  final String? prayer;
}

/// The Android side of the lock (MainActivity.kt). Off Android, and in
/// tests, every call quietly does nothing.
class PrayerLockBridge {
  static const _channel = MethodChannel('tareeq/prayerlock');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<LockStatus> status() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('status');
      if (m == null) return const LockStatus();
      return LockStatus(
        serviceOn: m['serviceOn'] == true,
        active: m['active'] == true,
        prayer: m['prayer'] as String?,
      );
    } catch (_) {
      return const LockStatus();
    }
  }

  /// Which of [packages] are installed, or null when that is not known.
  static Future<List<String>?> installed(List<String> packages) async {
    try {
      final list = await _channel.invokeListMethod<String>('installed', packages);
      return list;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {}
  }

  static Future<void> openAccessibilitySettings() => _call('openSettings');
  static Future<void> openAppInfo() => _call('openAppInfo');

  /// "I prayed and read the azkar": ends the lock until the next prayer.
  static Future<void> done() => _call('done');

  /// Locks for a minute so the user can see it.
  static Future<void> test() => _call('test');
}
