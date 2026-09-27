import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which reminders the user wants. Saved under `notify.*`.
class NotificationSettings extends ChangeNotifier {
  NotificationSettings(this.prefs) {
    for (final prayer in prayers) {
      _prayer[prayer] = prefs.getBool('notify.${prayer.name}') ?? true;
    }
    minutesBefore = prefs.getInt('notify.minutesBefore') ?? 0;
    morningAzkar = prefs.getBool('notify.morningAzkar') ?? true;
    eveningAzkar = prefs.getBool('notify.eveningAzkar') ?? true;
    wird = prefs.getBool('notify.wird') ?? true;
    wirdMinutes = prefs.getInt('notify.wirdMinutes') ?? 21 * 60;
    friday = prefs.getBool('notify.friday') ?? true;
  }

  static const prayers = [
    Prayer.fajr,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ];
  static const beforeOptions = [0, 5, 10, 15, 30];

  final SharedPreferences prefs;
  final _prayer = <Prayer, bool>{};

  /// Minutes before each prayer for an extra reminder; 0 means none.
  late int minutesBefore;
  late bool morningAzkar;
  late bool eveningAzkar;
  late bool wird;

  /// Time of the wird reminder, in minutes after midnight.
  late int wirdMinutes;

  /// Al-Kahf in the morning and du'a in the last hour of Friday.
  late bool friday;

  bool prayerEnabled(Prayer prayer) => _prayer[prayer] ?? false;

  void setPrayer(Prayer prayer, bool value) {
    _prayer[prayer] = value;
    prefs.setBool('notify.${prayer.name}', value);
    notifyListeners();
  }

  void setMinutesBefore(int value) {
    minutesBefore = value;
    prefs.setInt('notify.minutesBefore', value);
    notifyListeners();
  }

  void setMorningAzkar(bool value) {
    morningAzkar = value;
    prefs.setBool('notify.morningAzkar', value);
    notifyListeners();
  }

  void setEveningAzkar(bool value) {
    eveningAzkar = value;
    prefs.setBool('notify.eveningAzkar', value);
    notifyListeners();
  }

  void setWird(bool value) {
    wird = value;
    prefs.setBool('notify.wird', value);
    notifyListeners();
  }

  void setFriday(bool value) {
    friday = value;
    prefs.setBool('notify.friday', value);
    notifyListeners();
  }

  void setWirdMinutes(int value) {
    wirdMinutes = value;
    prefs.setInt('notify.wirdMinutes', value);
    notifyListeners();
  }

  /// Changes whenever anything that affects the schedule changes.
  String get signature => [
    for (final p in prayers) prayerEnabled(p) ? 1 : 0,
    minutesBefore,
    morningAzkar,
    eveningAzkar,
    wird,
    wirdMinutes,
    friday,
  ].join(',');
}
