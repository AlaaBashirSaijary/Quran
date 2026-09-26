import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/language.dart';

const juzCount = 30;

/// A khatma shared among several people without a server: the organizer
/// splits the thirty juz among the participants and shares a message with
/// a code line; everyone who pastes the message into the app sees the same
/// khatma, and progress travels back the same way.
class GroupKhatma {
  GroupKhatma({
    required this.id,
    required this.title,
    required this.names,
    required this.assignments,
    Set<int>? done,
    this.myName,
  }) : done = done ?? {};

  final String id;
  final String title;
  final List<String> names;

  /// For each juz (index 0 is juz 1), the index in [names] of who reads it.
  final List<int> assignments;

  /// Finished juz numbers (1 to 30).
  final Set<int> done;

  /// Which participant is using this phone, if chosen.
  String? myName;

  String nameOf(int juz) => names[assignments[juz - 1]];

  List<int> juzOf(String name) {
    final index = names.indexOf(name);
    return [
      for (var j = 1; j <= juzCount; j++)
        if (assignments[j - 1] == index) j,
    ];
  }

  bool get finished => done.length == juzCount;

  Map<String, Object?> toJson() => {
    'id': id,
    't': title,
    'n': names,
    'a': assignments,
    'd': done.toList()..sort(),
    if (myName != null) 'me': myName,
  };

  static GroupKhatma? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final names = (json['n'] as List).cast<String>();
      final assignments = (json['a'] as List).cast<int>();
      if (names.isEmpty ||
          assignments.length != juzCount ||
          assignments.any((a) => a < 0 || a >= names.length)) {
        return null;
      }
      return GroupKhatma(
        id: json['id'] as String,
        title: json['t'] as String,
        names: names,
        assignments: assignments,
        done: {
          for (final d in (json['d'] as List? ?? const []).cast<int>())
            if (d >= 1 && d <= juzCount) d,
        },
        myName: json['me'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Splits the thirty juz into consecutive runs, as evenly as possible, one
/// run per participant (at most thirty).
List<int> distributeJuz(int people) {
  final n = people.clamp(1, juzCount);
  return [for (var i = 0; i < juzCount; i++) i * n ~/ juzCount];
}

const _khatmaTag = 'khatma:v1:';
const _doneTag = 'khatma-done:';

/// The code line that carries a whole khatma inside a shared message.
String khatmaCode(GroupKhatma k) {
  final json = k.toJson()..remove('me');
  return _khatmaTag + base64Url.encode(utf8.encode(jsonEncode(json)));
}

/// The message the organizer shares: who reads which juz, then the code.
String khatmaMessage(GroupKhatma k) {
  final lines = <String>[
    tr('📖 ختمة جماعية: ${k.title}', '📖 Group khatma: ${k.title}'),
    '',
  ];
  for (var p = 0; p < k.names.length; p++) {
    final juz = k.juzOf(k.names[p]);
    if (juz.isEmpty) continue;
    final marks = juz.map((j) => k.done.contains(j) ? '$j ✓' : '$j').join('، ');
    lines.add('• ${k.names[p]}: ${tr('الجزء', 'Juz')} $marks');
  }
  lines
    ..add('')
    ..add(
      tr(
        'افتح تطبيق «طريق الجنة» ← الورد والختمة ← ختمة جماعية، والصق هذه الرسالة للانضمام.',
        'Open Tareeq Al-Jannah → Daily Reading & Khatma → Group khatma, and paste this message to join.',
      ),
    )
    ..add(khatmaCode(k));
  return lines.join('\n');
}

/// The message a participant shares after finishing [juz].
String doneMessage(GroupKhatma k, List<int> juz) {
  final list = juz.join('، ');
  return [
    tr(
      '✅ أتممت ${juz.length == 1 ? 'الجزء' : 'الأجزاء'} $list من ختمة «${k.title}»',
      '✅ I finished juz $list of the khatma “${k.title}”',
    ),
    '$_doneTag${k.id}:${juz.join(',')}',
  ].join('\n');
}

/// What a pasted message contained.
sealed class KhatmaMessage {
  const KhatmaMessage();
}

class KhatmaShared extends KhatmaMessage {
  const KhatmaShared(this.khatma);
  final GroupKhatma khatma;
}

class JuzDone extends KhatmaMessage {
  const JuzDone(this.id, this.juz);
  final String id;
  final List<int> juz;
}

/// Finds the khatma or progress code anywhere in [text], as it arrives
/// after being copied from a chat.
KhatmaMessage? parseKhatmaMessage(String text) {
  final shared = RegExp(
    '${RegExp.escape(_khatmaTag)}([A-Za-z0-9_=-]+)',
  ).firstMatch(text);
  if (shared != null) {
    try {
      final json = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(shared.group(1)!))),
      );
      final k = GroupKhatma.fromJson(json);
      if (k != null) return KhatmaShared(k);
    } catch (_) {
      // Fall through: not a valid code.
    }
  }
  final done = RegExp(
    '${RegExp.escape(_doneTag)}([A-Za-z0-9]+):([0-9,]+)',
  ).firstMatch(text);
  if (done != null) {
    final juz = [
      for (final p in done.group(2)!.split(','))
        if (int.tryParse(p) case final j? when j >= 1 && j <= juzCount) j,
    ];
    if (juz.isNotEmpty) return JuzDone(done.group(1)!, juz);
  }
  return null;
}

enum ImportResult { joined, updated, progress, unknownKhatma, invalid }

class GroupKhatmaProvider extends ChangeNotifier {
  GroupKhatmaProvider(this.prefs, {Random? random})
    : _random = random ?? Random() {
    for (final value in prefs.getStringList(_key) ?? const <String>[]) {
      try {
        final k = GroupKhatma.fromJson(jsonDecode(value));
        if (k != null) khatmas.add(k);
      } catch (_) {
        // Skip a damaged entry.
      }
    }
  }

  static const _key = 'khatma.groups';

  final SharedPreferences prefs;
  final Random _random;
  final khatmas = <GroupKhatma>[];

  GroupKhatma? byId(String id) {
    for (final k in khatmas) {
      if (k.id == id) return k;
    }
    return null;
  }

  GroupKhatma create(String title, List<String> names, {String? myName}) {
    final id = List.generate(
      10,
      (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
    ).join();
    final people = names.take(juzCount).toList();
    final k = GroupKhatma(
      id: id,
      title: title,
      names: people,
      assignments: distributeJuz(people.length),
      myName: myName,
    );
    khatmas.insert(0, k);
    _save();
    return k;
  }

  /// Joins or updates a shared khatma, or records reported progress.
  ImportResult import(String text) {
    final message = parseKhatmaMessage(text);
    switch (message) {
      case KhatmaShared(:final khatma):
        final existing = byId(khatma.id);
        if (existing == null) {
          khatmas.insert(0, khatma);
          _save();
          return ImportResult.joined;
        }
        final updated = GroupKhatma(
          id: existing.id,
          title: khatma.title,
          names: khatma.names,
          assignments: khatma.assignments,
          done: {...existing.done, ...khatma.done},
          myName: khatma.names.contains(existing.myName)
              ? existing.myName
              : null,
        );
        khatmas[khatmas.indexOf(existing)] = updated;
        _save();
        return ImportResult.updated;
      case JuzDone(:final id, :final juz):
        final k = byId(id);
        if (k == null) return ImportResult.unknownKhatma;
        k.done.addAll(juz);
        _save();
        return ImportResult.progress;
      case null:
        return ImportResult.invalid;
    }
  }

  void setDone(GroupKhatma k, int juz, bool value) {
    value ? k.done.add(juz) : k.done.remove(juz);
    _save();
  }

  void setMyName(GroupKhatma k, String? name) {
    k.myName = name;
    _save();
  }

  void reassign(GroupKhatma k, int juz, int person) {
    k.assignments[juz - 1] = person;
    _save();
  }

  void remove(GroupKhatma k) {
    khatmas.remove(k);
    _save();
  }

  void _save() {
    prefs.setStringList(_key, [
      for (final k in khatmas) jsonEncode(k.toJson()),
    ]);
    notifyListeners();
  }
}
