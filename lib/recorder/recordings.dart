import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_store.dart';
import '../core/language.dart';

/// A voice recording kept on the phone.
class Recording {
  const Recording({
    required this.file,
    required this.title,
    required this.at,
    required this.millis,
  });

  /// File name inside the recordings folder.
  final String file;
  final String title;
  final DateTime at;
  final int millis;

  Duration get length => Duration(milliseconds: millis);

  Recording withTitle(String title) =>
      Recording(file: file, title: title, at: at, millis: millis);

  Map<String, Object> toJson() => {
    'file': file,
    'title': title,
    'at': at.millisecondsSinceEpoch,
    'ms': millis,
  };

  factory Recording.fromJson(Map<String, dynamic> j) => Recording(
    file: j['file'] as String,
    title: j['title'] as String,
    at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
    millis: j['ms'] as int,
  );
}

/// The microphone, behind a small interface so the rest can be tested.
abstract class VoiceRecorder {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<void> stop();
  void dispose();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
    path: path,
  );

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  void dispose() => _recorder.dispose();
}

/// Hands a recording to the phone's share sheet (WhatsApp, Telegram, mail…).
typedef RecordingSharer = Future<void> Function(Uint8List bytes, String name, String title);

Future<void> shareRecordingFile(Uint8List bytes, String name, String title) =>
    SharePlus.instance.share(
      ShareParams(
        title: title,
        subject: title,
        files: [XFile.fromData(bytes, mimeType: 'audio/mp4', name: name)],
        fileNameOverrides: [name],
      ),
    );

/// The user's own voice recordings: record, play, rename, delete and share.
class Recordings extends ChangeNotifier {
  Recordings(
    this.prefs, {
    Future<String?>? folder,
    VoiceRecorder? recorder,
    RecordingSharer? sharer,
    DateTime Function()? clock,
  }) : _folderFuture = folder ?? dataFolder('recordings'),
       _recorder = recorder ?? DeviceVoiceRecorder(),
       _sharer = sharer ?? shareRecordingFile,
       _clock = clock ?? DateTime.now;

  static const _key = 'recordings.v1';

  final SharedPreferences prefs;
  final Future<String?> _folderFuture;
  final VoiceRecorder _recorder;
  final RecordingSharer _sharer;
  final DateTime Function() _clock;

  String? _folder;
  var _items = <Recording>[];

  /// Newest first.
  List<Recording> get items => List.unmodifiable(_items);

  /// Whether recording can work here (not on the web).
  bool get supported => _folder != null;

  bool recording = false;
  Duration elapsed = Duration.zero;
  String? error;
  Timer? _ticker;
  String? _currentFile;
  DateTime? _startedAt;

  Future<void> load() async {
    _folder = await _folderFuture;
    final raw = prefs.getString(_key);
    final list = <Recording>[];
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          final r = Recording.fromJson(j as Map<String, dynamic>);
          // A recording whose file is gone is forgotten.
          if (_folder != null && await fileExists('$_folder/${r.file}')) list.add(r);
        }
      } catch (_) {}
    }
    _items = list..sort((a, b) => b.at.compareTo(a.at));
    notifyListeners();
  }

  Future<void> _save() =>
      prefs.setString(_key, jsonEncode([for (final r in _items) r.toJson()]));

  String _pathOf(Recording r) => '$_folder/${r.file}';

  /// Starts recording. Returns false when the microphone is not allowed or
  /// recording is not possible.
  Future<bool> start() async {
    if (recording || !supported) return false;
    error = null;
    await stopPlayback();
    try {
      if (!await _recorder.hasPermission()) {
        error = tr(
          'لم يُسمح باستخدام الميكروفون. فعّله من إعدادات التطبيق.',
          'The microphone is not allowed. Turn it on in the app settings.',
        );
        notifyListeners();
        return false;
      }
      final now = _clock();
      _currentFile = 'rec-${now.millisecondsSinceEpoch}.m4a';
      _startedAt = now;
      // Makes sure the folder exists before the recorder writes into it.
      await appendFile('$_folder/$_currentFile', const []);
      await _recorder.start('$_folder/$_currentFile');
      recording = true;
      elapsed = Duration.zero;
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        elapsed = _clock().difference(_startedAt!);
        notifyListeners();
      });
      notifyListeners();
      return true;
    } catch (e) {
      error = tr('تعذّر بدء التسجيل.', 'Could not start recording.');
      await _discardCurrent();
      notifyListeners();
      return false;
    }
  }

  Future<void> _discardCurrent() async {
    _ticker?.cancel();
    recording = false;
    final file = _currentFile;
    _currentFile = null;
    if (file != null) await deleteFile('$_folder/$file');
  }

  /// Stops and keeps the recording. Returns it, or null when nothing was
  /// recorded.
  Future<Recording?> stop() async {
    if (!recording) return null;
    _ticker?.cancel();
    final file = _currentFile!;
    final millis = _clock().difference(_startedAt!).inMilliseconds;
    recording = false;
    _currentFile = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    // Under half a second, or an empty file, is a slip of the finger.
    if (millis < 500 || await fileLength('$_folder/$file') == 0) {
      await deleteFile('$_folder/$file');
      notifyListeners();
      return null;
    }
    final at = _startedAt!;
    final r = Recording(file: file, title: defaultTitle(at), at: at, millis: millis);
    _items = [r, ..._items];
    await _save();
    notifyListeners();
    return r;
  }

  /// "تسجيل 27/11 10:05" style name.
  static String defaultTitle(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return tr(
      'تسجيل ${at.day}/${at.month} ${two(at.hour)}:${two(at.minute)}',
      'Recording ${at.day}/${at.month} ${two(at.hour)}:${two(at.minute)}',
    );
  }

  Future<void> rename(Recording r, String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    _items = [for (final x in _items) x.file == r.file ? x.withTitle(t) : x];
    await _save();
    notifyListeners();
  }

  Future<void> delete(Recording r) async {
    if (playingFile == r.file) await stopPlayback();
    await deleteFile(_pathOf(r));
    _items = [for (final x in _items) if (x.file != r.file) x];
    await _save();
    notifyListeners();
  }

  /// Sends the recording to another app. Returns false if it failed.
  Future<bool> share(Recording r) async {
    try {
      final bytes = await readBytes(_pathOf(r));
      if (bytes == null) return false;
      await _sharer(bytes, '${_safeName(r.title)}.m4a', r.title);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _safeName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), '-').trim();
    return cleaned.isEmpty ? 'recording' : cleaned;
  }

  // Playback.

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _sub;
  String? playingFile;
  bool playing = false;

  Future<void> play(Recording r) async {
    if (recording) return;
    try {
      final player = _player ??= _newPlayer();
      if (playingFile != r.file) {
        await player.setFilePath(_pathOf(r));
        playingFile = r.file;
      }
      unawaited(player.play());
    } catch (_) {
      playingFile = null;
      error = tr('تعذّر تشغيل التسجيل.', 'Could not play the recording.');
    }
    notifyListeners();
  }

  AudioPlayer _newPlayer() {
    final player = AudioPlayer();
    _sub = player.playerStateStream.listen((s) {
      playing = s.playing && s.processingState != ProcessingState.completed;
      if (s.processingState == ProcessingState.completed) {
        playingFile = null;
        player.stop();
      }
      notifyListeners();
    });
    return player;
  }

  Future<void> toggle(Recording r) async {
    if (playingFile == r.file && playing) {
      await _player?.pause();
      notifyListeners();
    } else {
      await play(r);
    }
  }

  Future<void> stopPlayback() async {
    playingFile = null;
    playing = false;
    await _player?.stop();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    _player?.dispose();
    _recorder.dispose();
    super.dispose();
  }
}
