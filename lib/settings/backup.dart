import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../core/error_log.dart';
import '../core/language.dart';

const _app = 'manhaj-hayah';

/// Backups made before the app was renamed.
const _formerApp = 'tareeq-aljannah';
const _format = 1;

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything the app saves (bookmarks, khatma, sebha, azkar progress,
/// prayer and reading settings) as a JSON document.
String exportBackup(SharedPreferences prefs, {DateTime? now}) {
  final data = <String, Object?>{};
  for (final key in prefs.getKeys()) {
    // The error log belongs to this phone, not to the user's data.
    if (key == ErrorLog.key) continue;
    final value = prefs.get(key);
    data[key] = switch (value) {
      bool() => {'bool': value},
      int() => {'int': value},
      double() => {'double': value},
      String() => {'string': value},
      List() => {'list': value.cast<String>()},
      _ => null,
    };
  }
  data.removeWhere((_, value) => value == null);
  return const JsonEncoder.withIndent(' ').convert({
    'app': _app,
    'format': _format,
    'created': (now ?? DateTime.now()).toIso8601String(),
    'data': data,
  });
}

/// Replaces the saved data with the contents of a backup made by
/// [exportBackup]. Nothing is changed if the file is not a valid backup.
Future<int> importBackup(SharedPreferences prefs, String json) async {
  final Map<String, dynamic> backup;
  try {
    backup = jsonDecode(json) as Map<String, dynamic>;
  } catch (_) {
    throw BackupException(
      tr('الملف ليس نسخة احتياطية صالحة.', 'The file is not a valid backup.'),
    );
  }
  if ((backup['app'] != _app && backup['app'] != _formerApp) ||
      backup['data'] is! Map) {
    throw BackupException(
      tr(
        'هذا الملف ليس نسخة احتياطية من منهج حياة.',
        'This file is not a Manhaj Hayah backup.',
      ),
    );
  }
  if ((backup['format'] as int? ?? 0) > _format) {
    throw BackupException(
      tr(
        'النسخة الاحتياطية من إصدار أحدث من التطبيق. حدّث التطبيق أولاً.',
        'The backup is from a newer version of the app. Update the app first.',
      ),
    );
  }

  // Validate everything before touching the current data.
  final entries = <String, Object>{};
  for (final MapEntry(:key, :value) in (backup['data'] as Map).entries) {
    if (value is! Map || value.length != 1) continue;
    final MapEntry(key: type, value: v) = value.entries.first;
    final parsed = switch (type) {
      'bool' when v is bool => v,
      'int' when v is int => v,
      'double' when v is num => v.toDouble(),
      'string' when v is String => v,
      'list' when v is List => v.whereType<String>().toList(),
      _ => null,
    };
    if (parsed != null) entries[key as String] = parsed;
  }

  final errors = prefs.getStringList(ErrorLog.key);
  await prefs.clear();
  if (errors != null) await prefs.setStringList(ErrorLog.key, errors);
  entries.remove(ErrorLog.key);
  for (final MapEntry(:key, :value) in entries.entries) {
    switch (value) {
      case bool():
        await prefs.setBool(key, value);
      case int():
        await prefs.setInt(key, value);
      case double():
        await prefs.setDouble(key, value);
      case String():
        await prefs.setString(key, value);
      case List<String>():
        await prefs.setStringList(key, value);
    }
  }
  return entries.length;
}
