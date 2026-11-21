import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'matcher.dart';

/// One word the reciter keeps getting wrong.
class LoggedMistake {
  const LoggedMistake({
    required this.surah,
    required this.ayah,
    required this.number,
    required this.text,
    required this.count,
    required this.last,
    required this.heard,
    required this.skipped,
  });

  final int surah;
  final int ayah;

  /// The word's place in the ayah, from 1.
  final int number;

  /// The word as written in the mushaf.
  final String text;

  /// How many times it went wrong.
  final int count;
  final DateTime last;

  /// What was said instead the last time (empty if it was left out).
  final String heard;

  /// Whether the last time it was left out.
  final bool skipped;

  String get key => '$surah:$ayah:$number';

  Map<String, Object> toJson() => {
    's': surah,
    'a': ayah,
    'n': number,
    't': text,
    'c': count,
    'l': last.millisecondsSinceEpoch,
    'h': heard,
    'k': skipped,
  };

  static LoggedMistake? fromJson(Object? j) {
    if (j is! Map) return null;
    try {
      return LoggedMistake(
        surah: j['s'] as int,
        ayah: j['a'] as int,
        number: j['n'] as int,
        text: j['t'] as String,
        count: j['c'] as int,
        last: DateTime.fromMillisecondsSinceEpoch(j['l'] as int),
        heard: j['h'] as String,
        skipped: j['k'] as bool,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The mistakes made in recitations, kept so the reciter can go back to
/// the words that trip them. Saved under `recite.mistakes`.
class MistakeLog extends ChangeNotifier {
  MistakeLog(this.prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          final m = LoggedMistake.fromJson(j);
          if (m != null) _entries[m.key] = m;
        }
      } catch (_) {
        // A damaged list starts again.
      }
    }
  }

  static const _key = 'recite.mistakes';
  static const _max = 500;

  final SharedPreferences prefs;
  final DateTime Function() _clock;
  final _entries = <String, LoggedMistake>{};

  /// Most often wrong first, then the latest.
  List<LoggedMistake> get all =>
      _entries.values.toList()..sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : b.last.compareTo(a.last);
      });

  /// The surahs with mistakes, in mushaf order.
  List<int> get surahs => (_entries.values.map((m) => m.surah).toSet().toList()..sort());

  List<LoggedMistake> ofSurah(int surah) =>
      all.where((m) => m.surah == surah).toList()
        ..sort((a, b) => a.ayah != b.ayah ? a.ayah.compareTo(b.ayah) : a.number.compareTo(b.number));

  int get total => _entries.values.fold(0, (a, m) => a + m.count);

  bool get isEmpty => _entries.isEmpty;

  void record(ReciteMistake mistake) {
    final w = mistake.word;
    final key = '${w.surah}:${w.ayah}:${w.number}';
    final before = _entries[key];
    _entries[key] = LoggedMistake(
      surah: w.surah,
      ayah: w.ayah,
      number: w.number,
      text: w.text,
      count: (before?.count ?? 0) + 1,
      last: _clock(),
      heard: mistake.heard,
      skipped: mistake.kind == MistakeKind.skipped,
    );
    if (_entries.length > _max) {
      final oldest = (_entries.values.toList()..sort((a, b) => a.last.compareTo(b.last))).first;
      _entries.remove(oldest.key);
    }
    _save();
  }

  /// The reciter got the word right: it counts one less, and goes when
  /// there is none left.
  void forgive(LoggedMistake m) {
    final current = _entries[m.key];
    if (current == null) return;
    if (current.count <= 1) {
      _entries.remove(m.key);
    } else {
      _entries[m.key] = LoggedMistake(
        surah: current.surah,
        ayah: current.ayah,
        number: current.number,
        text: current.text,
        count: current.count - 1,
        last: current.last,
        heard: current.heard,
        skipped: current.skipped,
      );
    }
    _save();
  }

  void remove(LoggedMistake m) {
    if (_entries.remove(m.key) != null) _save();
  }

  void clear() {
    _entries.clear();
    _save();
  }

  void _save() {
    prefs.setString(_key, jsonEncode([for (final m in _entries.values) m.toJson()]));
    notifyListeners();
  }
}
