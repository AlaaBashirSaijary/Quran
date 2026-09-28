import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AyahNote {
  const AyahNote(this.surah, this.ayah, this.text, this.updated);

  final int surah;
  final int ayah;
  final String text;
  final DateTime updated;
}

/// The reader's reflections on ayahs, one note per ayah. Saved with the
/// rest of the app's data, so backups include them.
class NotesProvider extends ChangeNotifier {
  NotesProvider(this.prefs) {
    final saved = prefs.getString(_key);
    if (saved == null) return;
    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      for (final MapEntry(:key, :value) in json.entries) {
        final parts = key.split(':');
        final note = value as Map<String, dynamic>;
        _notes[(int.parse(parts[0]), int.parse(parts[1]))] = AyahNote(
          int.parse(parts[0]),
          int.parse(parts[1]),
          note['text'] as String,
          DateTime.parse(note['updated'] as String),
        );
      }
    } catch (_) {
      // A damaged value: start empty rather than fail.
    }
  }

  static const _key = 'notes.ayahs';

  final SharedPreferences prefs;
  final _notes = <(int, int), AyahNote>{};

  AyahNote? of(int surah, int ayah) => _notes[(surah, ayah)];

  /// All notes, the most recently written first.
  List<AyahNote> get all =>
      _notes.values.toList()..sort((a, b) => b.updated.compareTo(a.updated));

  /// Saves [text] for the ayah; empty text removes the note.
  void save(int surah, int ayah, String text, {DateTime? now}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _notes.remove((surah, ayah));
    } else {
      _notes[(surah, ayah)] = AyahNote(
        surah,
        ayah,
        trimmed,
        now ?? DateTime.now(),
      );
    }
    prefs.setString(
      _key,
      jsonEncode({
        for (final n in _notes.values)
          '${n.surah}:${n.ayah}': {
            'text': n.text,
            'updated': n.updated.toIso8601String(),
          },
      }),
    );
    notifyListeners();
  }
}
