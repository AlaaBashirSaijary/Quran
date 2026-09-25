import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dhikr {
  const Dhikr({
    required this.text,
    required this.count,
    this.virtue,
    this.reference,
  });

  final String text;

  /// How many times it is said.
  final int count;
  final String? virtue;
  final String? reference;
}

class AzkarCategory {
  const AzkarCategory({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<Dhikr> items;

  IconData get icon => switch (id) {
        'morning' => Icons.wb_sunny_rounded,
        'evening' => Icons.nights_stay_rounded,
        'afterPrayer' => Icons.mosque_rounded,
        'sleep' => Icons.bedtime_rounded,
        'waking' => Icons.alarm_rounded,
        'tasabeeh' => Icons.auto_awesome_rounded,
        'quranDuas' => Icons.menu_book_rounded,
        _ => Icons.volunteer_activism_rounded,
      };
}

List<AzkarCategory>? _azkar;

/// Loads the azkar of Hisn al-Muslim bundled in assets/azkar.json. Only a
/// finished load is cached, so an interrupted one is simply retried.
Future<List<AzkarCategory>> loadAzkar() async {
  final cached = _azkar;
  if (cached != null) return cached;
  final file = await rootBundle.loadString('assets/azkar.json', cache: false);
  return _azkar = [
    for (final category in jsonDecode(file) as List)
      AzkarCategory(
        id: category['id'] as String,
        title: category['title'] as String,
        items: [
          for (final item in category['items'] as List)
            Dhikr(
              text: item['text'] as String,
              count: item['count'] as int,
              virtue: item['virtue'] as String?,
              reference: item['reference'] as String?,
            ),
        ],
      ),
  ];
}

/// Which category suits the time of day: morning azkar until noon,
/// evening azkar from mid-afternoon until late night.
String? suggestedCategory(DateTime now) {
  if (now.hour >= 4 && now.hour < 12) return 'morning';
  if (now.hour >= 15 && now.hour < 23) return 'evening';
  return null;
}

/// Remembers how many repetitions of each dhikr are left today, so the
/// progress survives leaving the screen and starts fresh the next day.
class AzkarProgress {
  AzkarProgress(this.prefs, this.category, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    final saved = prefs.getStringList(_key);
    _remaining = saved != null && saved.length == category.items.length
        ? [for (final value in saved) int.tryParse(value) ?? 0]
        : [for (final item in category.items) item.count];
  }

  final SharedPreferences prefs;
  final AzkarCategory category;
  final DateTime Function() _clock;
  late List<int> _remaining;

  String get _key {
    final now = _clock();
    return 'azkar.${category.id}.${now.year}-${now.month}-${now.day}';
  }

  int remaining(int index) => _remaining[index];

  bool isDone(int index) => _remaining[index] == 0;

  int get doneCount => _remaining.where((r) => r == 0).length;

  bool get allDone => doneCount == _remaining.length;

  /// Counts one repetition. Returns true when this dhikr is now complete.
  bool tap(int index) {
    if (_remaining[index] == 0) return false;
    _remaining[index]--;
    _save();
    return _remaining[index] == 0;
  }

  void reset() {
    _remaining = [for (final item in category.items) item.count];
    _save();
  }

  void _save() {
    prefs.setStringList(_key, [for (final r in _remaining) '$r']);
  }
}
