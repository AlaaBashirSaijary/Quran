import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const totalPages = 604;

/// Tracks the daily reading goal (wird) and the current khatma.
///
/// A page counts as read when the reader moves from it to the next page,
/// so jumping around from the index or search does not count as reading.
class ReadingProvider extends ChangeNotifier {
  ReadingProvider(this.prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    goal = prefs.getInt('wird.goal') ?? 5;
    khatmas = prefs.getInt('wird.khatmas') ?? 0;
    final saved = prefs.getString('wird.khatmaPages');
    _read = List.generate(
      totalPages,
      (i) => saved != null && saved.length == totalPages && saved[i] == '1',
    );
    final daily = prefs.getString('wird.daily');
    _daily = daily == null
        ? {}
        : (jsonDecode(daily) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int));
  }

  static const goalOptions = [1, 2, 5, 10, 20];

  final SharedPreferences prefs;
  final DateTime Function() _clock;

  late int goal;
  late int khatmas;
  late List<bool> _read;
  late Map<String, int> _daily;
  int? _lastPage;

  /// Called with the reader's page each time it changes.
  void update(int page) {
    final last = _lastPage;
    _lastPage = page;
    if (last != null && page == last + 1) {
      _markRead(last);
      if (page == totalPages) _markRead(page);
    }
  }

  static String dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  int get today => _daily[dayKey(_clock())] ?? 0;

  bool get goalMet => today >= goal;

  int get khatmaRead => _read.where((r) => r).length;

  double get khatmaProgress => khatmaRead / totalPages;

  bool isRead(int page) => _read[page - 1];

  /// Pages read on each of the last [days] days, oldest first.
  List<int> lastDays([int days = 7]) {
    final now = _clock();
    return [
      for (var i = days - 1; i >= 0; i--)
        _daily[dayKey(now.subtract(Duration(days: i)))] ?? 0,
    ];
  }

  /// Consecutive days, ending today or yesterday, on which the goal was met.
  int get streak {
    final now = _clock();
    var day = goalMet ? now : now.subtract(const Duration(days: 1));
    var count = 0;
    while ((_daily[dayKey(day)] ?? 0) >= goal) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Days left to finish the khatma at [goal] pages a day. Today counts as
  /// the first day unless today's goal is already met.
  int get daysToFinish {
    final left = totalPages - khatmaRead;
    if (left == 0) return 0;
    if (goalMet) return (left / goal).ceil();
    final afterToday = left - (goal - today);
    return afterToday <= 0 ? 1 : 1 + (afterToday / goal).ceil();
  }

  DateTime get estimatedFinish => _clock().add(
        Duration(days: goalMet ? daysToFinish : daysToFinish - 1),
      );

  void setGoal(int pages) {
    if (pages < 1) return;
    goal = pages;
    prefs.setInt('wird.goal', pages);
    notifyListeners();
  }

  void startNewKhatma() {
    _read = List.filled(totalPages, false);
    _save();
    notifyListeners();
  }

  void _markRead(int page) {
    if (page < 1 || page > totalPages) return;
    final key = dayKey(_clock());
    _daily[key] = (_daily[key] ?? 0) + 1;
    if (!_read[page - 1]) {
      _read[page - 1] = true;
      if (khatmaRead == totalPages) {
        khatmas++;
        prefs.setInt('wird.khatmas', khatmas);
      }
    }
    _save();
    notifyListeners();
  }

  void _save() {
    // Keep two months of daily counts.
    final cutoff = dayKey(_clock().subtract(const Duration(days: 60)));
    _daily.removeWhere((key, _) => key.compareTo(cutoff) < 0);
    prefs
      ..setString('wird.khatmaPages', _read.map((r) => r ? '1' : '0').join())
      ..setString('wird.daily', jsonEncode(_daily));
  }
}
