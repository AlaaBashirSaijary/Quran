import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verse-by-verse recitations from the alquran.cloud API (Islamic Network).
const _api = 'https://api.alquran.cloud/v1';

class Reciter {
  const Reciter(this.id, this.name);

  final String id;
  final String name;
}

/// Used until (or if) the full list can be fetched.
const defaultReciters = [
  Reciter('ar.alafasy', 'مشاري راشد العفاسي'),
  Reciter('ar.husary', 'محمود خليل الحصري'),
  Reciter('ar.minshawi', 'محمد صديق المنشاوي'),
  Reciter('ar.abdulbasitmurattal', 'عبد الباسط عبد الصمد (مرتل)'),
  Reciter('ar.abdurrahmaansudais', 'عبد الرحمن السديس'),
  Reciter('ar.mahermuaiqly', 'ماهر المعيقلي'),
  Reciter('ar.saoodshuraym', 'سعود الشريم'),
];

class AyahAudio {
  const AyahAudio(this.surah, this.ayah, this.url);

  final int surah;
  final int ayah;
  final String url;
}

/// Parses `GET /v1/page/{page}/{reciter}`.
List<AyahAudio> parsePageAudio(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  if (json['code'] != 200) throw const FormatException('bad response');
  final ayahs = (json['data'] as Map<String, dynamic>)['ayahs'] as List;
  return [
    for (final a in ayahs.cast<Map<String, dynamic>>())
      AyahAudio(
        (a['surah'] as Map<String, dynamic>)['number'] as int,
        a['numberInSurah'] as int,
        a['audio'] as String,
      ),
  ];
}

/// Parses `GET /v1/edition?format=audio&type=versebyverse`, keeping the
/// Arabic recitations.
List<Reciter> parseReciters(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final list = (json['data'] as List).cast<Map<String, dynamic>>();
  return [
    for (final e in list)
      if (e['language'] == 'ar' && e['format'] == 'audio')
        Reciter(e['identifier'] as String, e['name'] as String),
  ];
}

/// Which ayah plays next, repeating each one [repeat] times.
class RecitationQueue {
  RecitationQueue(this.items, {this.repeat = 1});

  final List<AyahAudio> items;
  final int repeat;
  int index = 0;
  int _played = 0;

  AyahAudio get current => items[index];

  /// Moves on after the current ayah finished. Returns false at the end.
  bool advance() {
    _played++;
    if (_played < repeat) return true;
    _played = 0;
    index++;
    return index < items.length;
  }
}

enum RecitationStatus { idle, loading, playing, paused, error }

/// Plays the ayahs of a mushaf page one after another, optionally
/// continuing with the following pages.
class RecitationProvider extends ChangeNotifier {
  RecitationProvider(this.prefs) {
    reciterId = prefs.getString('audio.reciter') ?? defaultReciters.first.id;
    repeat = prefs.getInt('audio.repeat') ?? 1;
    continuous = prefs.getBool('audio.continuous') ?? true;
  }

  final SharedPreferences prefs;
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _sub;
  RecitationQueue? _queue;
  List<Reciter> reciters = defaultReciters;

  late String reciterId;
  late int repeat;
  late bool continuous;

  RecitationStatus status = RecitationStatus.idle;
  int? page;
  String? error;

  /// Called when playback moves on to [page], so the reader can follow.
  void Function(int page)? onPageChanged;

  AyahAudio? get current => _queue?.current;

  Reciter get reciter => reciters.firstWhere(
    (r) => r.id == reciterId,
    orElse: () => Reciter(reciterId, reciterId),
  );

  AudioPlayer get _audio {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _sub = player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _next();
    });
    return _player = player;
  }

  Future<void> loadReciters() async {
    try {
      final res = await http.get(
        Uri.parse('$_api/edition?format=audio&type=versebyverse'),
      );
      final list = parseReciters(res.body);
      if (list.isNotEmpty) {
        reciters = list;
        notifyListeners();
      }
    } catch (_) {
      // Keep the built-in list.
    }
  }

  Future<void> playPage(int page) async {
    this.page = page;
    status = RecitationStatus.loading;
    error = null;
    notifyListeners();
    try {
      final res = await http
          .get(Uri.parse('$_api/page/$page/$reciterId'))
          .timeout(const Duration(seconds: 20));
      _queue = RecitationQueue(parsePageAudio(res.body), repeat: repeat);
      await _playCurrent();
    } catch (_) {
      status = RecitationStatus.error;
      error = 'تعذّر التشغيل، تحقق من الإنترنت';
      notifyListeners();
    }
  }

  Future<void> _playCurrent() async {
    final queue = _queue;
    if (queue == null) return;
    await _audio.setUrl(queue.current.url);
    status = RecitationStatus.playing;
    notifyListeners();
    unawaited(_audio.play());
  }

  Future<void> _next() async {
    final queue = _queue;
    if (queue == null || status != RecitationStatus.playing) return;
    if (queue.advance()) {
      await _playCurrent();
      return;
    }
    final finished = page;
    if (continuous && finished != null && finished < 604) {
      onPageChanged?.call(finished + 1);
      await playPage(finished + 1);
    } else {
      await stop();
    }
  }

  Future<void> toggle() async {
    if (status == RecitationStatus.playing) {
      status = RecitationStatus.paused;
      notifyListeners();
      await _player?.pause();
    } else if (status == RecitationStatus.paused) {
      status = RecitationStatus.playing;
      notifyListeners();
      unawaited(_player?.play());
    }
  }

  Future<void> stop() async {
    status = RecitationStatus.idle;
    _queue = null;
    page = null;
    notifyListeners();
    await _player?.stop();
  }

  void setReciter(String id) {
    reciterId = id;
    prefs.setString('audio.reciter', id);
    notifyListeners();
    final current = page;
    if (status != RecitationStatus.idle && current != null) playPage(current);
  }

  void setRepeat(int value) {
    repeat = value;
    prefs.setInt('audio.repeat', value);
    notifyListeners();
  }

  void setContinuous(bool value) {
    continuous = value;
    prefs.setBool('audio.continuous', value);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
