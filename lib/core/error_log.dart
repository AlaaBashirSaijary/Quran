import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Errors the app ran into, kept on the phone only so the user can send
/// them to the developer when something goes wrong. Nothing is uploaded.
class ErrorLog {
  ErrorLog._(this._prefs);

  static const key = 'errors.log';
  static const _max = 50;
  static ErrorLog? _instance;

  static ErrorLog? get instance => _instance;

  final SharedPreferences _prefs;

  /// Starts recording uncaught errors, keeping the default reporting.
  static void install(SharedPreferences prefs) {
    final log = _instance = ErrorLog._(prefs);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      log.add(details.exception, details.stack);
      previous?.call(details);
    };
    final platform = WidgetsBinding.instance.platformDispatcher;
    final previousPlatform = platform.onError;
    platform.onError = (error, stack) {
      log.add(error, stack);
      return previousPlatform?.call(error, stack) ?? false;
    };
  }

  /// For tests.
  @visibleForTesting
  static ErrorLog attach(SharedPreferences prefs) =>
      _instance = ErrorLog._(prefs);

  List<String> get entries => _prefs.getStringList(key) ?? const [];

  void add(Object error, StackTrace? stack, {DateTime? now}) {
    final time = (now ?? DateTime.now()).toIso8601String().substring(0, 19);
    final frames = (stack?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(12)
        .join('\n');
    final entry = '$time  $error${frames.isEmpty ? '' : '\n$frames'}';
    final list = [...entries, entry];
    _prefs.setStringList(
      key,
      list.length > _max ? list.sublist(list.length - _max) : list,
    );
  }

  void clear() => _prefs.remove(key);

  /// The log as text to share, with the platform it came from.
  String report() => [
    'Tareeq Al-Jannah error log · ${defaultTargetPlatform.name}',
    ...entries,
  ].join('\n\n');
}
