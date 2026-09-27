import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/language.dart';
import 'audio_store.dart';
import 'recitation.dart';

/// Parses `GET /v1/surah/{surah}/{reciter}`: each ayah's number in the
/// surah and its audio URL.
List<(int, String)> parseSurahAudio(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  if (json['code'] != 200) throw const FormatException('bad response');
  final ayahs = (json['data'] as Map<String, dynamic>)['ayahs'] as List;
  return [
    for (final a in ayahs.cast<Map<String, dynamic>>())
      (a['numberInSurah'] as int, a['audio'] as String),
  ];
}

/// Recitations saved on the phone, a whole surah at a time, so they play
/// without internet.
class AudioDownloads extends ChangeNotifier {
  AudioDownloads(this.prefs, {http.Client? client, Future<String?>? folder})
    : _client = client ?? http.Client() {
    _saved.addAll(prefs.getStringList(_key) ?? const []);
    _ready = _init(folder ?? audioFolder());
  }

  static const _key = 'audio.downloads';

  final SharedPreferences prefs;
  final http.Client _client;
  final _saved = <String>{};
  late final Future<void> _ready;
  String? _folder;

  /// Surahs waiting or downloading, with the share done so far (0 to 1).
  final progress = <(String, int), double>{};
  (String, int)? _cancelling;
  String? error;

  /// Whether downloads are possible here (not on the web).
  bool get supported => _folder != null;

  Future<void> get ready => _ready;

  Future<void> _init(Future<String?> folder) async {
    _folder = await folder;
    // A restored backup lists downloads whose files are not on this phone.
    final missing = <String>[];
    for (final entry in _saved) {
      final (reciter, surah) = _split(entry);
      if (_folder == null || !await fileExists(_path(reciter, surah, 1))) {
        missing.add(entry);
      }
    }
    if (missing.isNotEmpty) {
      _saved.removeAll(missing);
      _persist();
    }
    notifyListeners();
  }

  static String _entry(String reciter, int surah) => '$reciter|$surah';

  static (String, int) _split(String entry) {
    final i = entry.lastIndexOf('|');
    return (entry.substring(0, i), int.parse(entry.substring(i + 1)));
  }

  String _path(String reciter, int surah, int ayah) =>
      '$_folder/$reciter/$surah/$ayah.mp3';

  bool isDownloaded(String reciter, int surah) =>
      _saved.contains(_entry(reciter, surah));

  Set<int> downloadedSurahs(String reciter) => {
    for (final e in _saved)
      if (_split(e).$1 == reciter) _split(e).$2,
  };

  /// The saved file for an ayah, as a URI the player accepts, if its surah
  /// has been downloaded.
  String? localUri(String reciter, int surah, int ayah) {
    if (_folder == null || !isDownloaded(reciter, surah)) return null;
    return Uri.file(_path(reciter, surah, ayah)).toString();
  }

  /// Downloads [surahs] for [reciter] one after another.
  Future<void> download(String reciter, Iterable<int> surahs) async {
    await _ready;
    if (!supported) return;
    final wanted = [
      for (final s in surahs)
        if (!isDownloaded(reciter, s) && !progress.containsKey((reciter, s))) s,
    ];
    if (wanted.isEmpty) return;
    final idle = progress.isEmpty;
    for (final s in wanted) {
      progress[(reciter, s)] = 0;
    }
    error = null;
    notifyListeners();
    if (idle) await _run();
  }

  Future<void> _run() async {
    while (progress.isNotEmpty) {
      final (reciter, surah) = progress.keys.first;
      try {
        await _downloadSurah(reciter, surah);
      } catch (_) {
        if (_cancelling != (reciter, surah)) {
          error = tr(
            'توقف التحميل. تحقق من الإنترنت وحاول مرة أخرى.',
            'The download stopped. Check your internet connection and try again.',
          );
          progress.clear();
          notifyListeners();
          return;
        }
      }
      _cancelling = null;
      progress.remove((reciter, surah));
      notifyListeners();
    }
  }

  Future<void> _downloadSurah(String reciter, int surah) async {
    final res = await _client
        .get(Uri.parse('$recitationApi/surah/$surah/$reciter'))
        .timeout(const Duration(seconds: 30));
    final ayahs = parseSurahAudio(res.body);
    for (var i = 0; i < ayahs.length; i++) {
      if (_cancelling == (reciter, surah)) throw StateError('cancelled');
      final (ayah, url) = ayahs[i];
      final path = _path(reciter, surah, ayah);
      if (!await fileExists(path)) {
        final audio = await _client
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 60));
        if (audio.statusCode != 200) {
          throw StateError('HTTP ${audio.statusCode}');
        }
        await writeFile(path, audio.bodyBytes);
      }
      progress[(reciter, surah)] = (i + 1) / ayahs.length;
      notifyListeners();
    }
    _saved.add(_entry(reciter, surah));
    _persist();
  }

  /// Stops a waiting or running download of [surah].
  void cancel(String reciter, int surah) {
    if (!progress.containsKey((reciter, surah))) return;
    if (progress.keys.first == (reciter, surah)) {
      _cancelling = (reciter, surah);
    } else {
      progress.remove((reciter, surah));
      notifyListeners();
    }
  }

  Future<void> delete(String reciter, int surah) async {
    await _ready;
    _saved.remove(_entry(reciter, surah));
    _persist();
    notifyListeners();
    if (_folder != null) await deleteFolder('$_folder/$reciter/$surah');
  }

  Future<void> deleteAll() async {
    await _ready;
    _saved.clear();
    _persist();
    notifyListeners();
    if (_folder != null) await deleteFolder(_folder!);
  }

  /// Space the downloads take, in bytes.
  Future<int> size() async {
    await _ready;
    return _folder == null ? 0 : folderSize(_folder!);
  }

  void _persist() => prefs.setStringList(_key, _saved.toList()..sort());
}
