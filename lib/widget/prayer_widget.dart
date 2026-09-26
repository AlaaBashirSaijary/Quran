import 'dart:convert';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../prayer/prayer.dart';

/// The Android home-screen widget (PrayerWidgetProvider.kt).
const _provider =
    'io.github.alaabashirsaijary.tareeqaljannah.PrayerWidgetProvider';

/// What the widget shows for the coming [days]: the place and each prayer
/// (sunrise excluded) as [name, epoch milliseconds]. The widget itself picks
/// the next one from the current time, so it stays right between app runs.
Map<String, Object?> prayerWidgetData(
  PrayerProvider prayer,
  DateTime now, {
  int days = 7,
}) {
  if (!prayer.hasLocation) return {'times': const <Object>[]};
  final today = DateTime(now.year, now.month, now.day);
  return {
    if (prayer.placeName != null) 'place': prayer.placeName,
    'times': [
      for (var d = 0; d < days; d++)
        for (final t in prayer.timesOn(today.add(Duration(days: d))))
          if (t.prayer != Prayer.sunrise)
            [t.name, t.time.millisecondsSinceEpoch],
    ],
  };
}

/// Sends the coming week's prayer times to the home-screen widget and asks
/// it to redraw at each prayer time. Does nothing off Android.
Future<void> updatePrayerWidget(PrayerProvider prayer, DateTime now) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final data = prayerWidgetData(prayer, now);
  try {
    await HomeWidget.saveWidgetData<String>('prayer_times', jsonEncode(data));
    await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    await HomeWidget.scheduleWidgetUpdates([
      for (final t in data['times']! as List)
        DateTime.fromMillisecondsSinceEpoch((t as List)[1] as int),
    ], qualifiedAndroidName: _provider);
  } catch (_) {
    // No widget support (e.g. in tests); the app works without it.
  }
}
