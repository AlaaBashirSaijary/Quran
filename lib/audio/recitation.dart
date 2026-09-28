import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/language.dart';
import '../quran/ayah_regions.dart';
import 'downloads.dart';

/// Verse-by-verse recitations from the alquran.cloud API (Islamic Network).
const recitationApi = 'https://api.alquran.cloud/v1';

class Reciter {
  const Reciter(this.id, this.arabicName, this.englishName);

  final String id;
  final String arabicName;
  final String englishName;

  String get name => tr(arabicName, englishName);
}

/// Used until (or if) the full list can be fetched.
const defaultReciters = [
  Reciter('ar.alafasy', 'مشاري راشد العفاسي', 'Mishary Rashid Alafasy'),
  Reciter('ar.husary', 'محمود خليل الحصري', 'Mahmoud Khalil Al-Husary'),
  Reciter('ar.minshawi', 'محمد صديق المنشاوي', 'Mohamed Siddiq Al-Minshawi'),
  Reciter(
    'ar.abdulbasitmurattal',
    'عبد الباسط عبد الصمد (مرتل)',
    'Abdul Basit Abdul Samad (Murattal)',
  ),
  Reciter(
    'ar.abdurrahmaansudais',
    'عبد الرحمن السديس',
    'Abdurrahman As-Sudais',
  ),
  Reciter('ar.mahermuaiqly', 'ماهر المعيقلي', 'Maher Al-Muaiqly'),
  Reciter('ar.saoodshuraym', 'سعود الشريم', 'Saud Ash-Shuraim'),
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
        Reciter(
          e['identifier'] as String,
          e['name'] as String,
          (e['englishName'] as String?) ?? e['name'] as String,
        ),
  ];
}

/// Which ayah plays next, repeating each one [repeat] times and the whole
/// list [loops] times.
class RecitationQueue {
  RecitationQueue(this.items, {this.repeat = 1, this.loops = 1});

  final List<AyahAudio> items;
  final int repeat;
  final int loops;
  int index = 0;
  int _played = 0;
  int _loop = 0;

  AyahAudio get current => items[index];

  /// Which pass over the list is playing, from 1.
  int get loop => _loop + 1;

  /// Moves on after the current ayah finished. Returns false at the end.
  bool advance() {
    _played++;
    if (_played < repeat) return true;
    _played = 0;
    index++;
    if (index < items.length) return true;
    _loop++;
    if (_loop >= loops) return false;
    index = 0;
    return true;
  }
}

enum RecitationStatus { idle, loading, playing, paused, error }

/// Plays the ayahs of a mushaf page one after another, optionally
/// continuing with the following pages.
class RecitationProvider extends ChangeNotifier {
  RecitationProvider(this.prefs, {this.downloads, http.Client? client})
    : _client = client ?? http.Client() {
    reciterId = prefs.getString('audio.reciter') ?? defaultReciters.first.id;
    repeat = prefs.getInt('audio.repeat') ?? 1;
    continuous = prefs.getBool('audio.continuous') ?? true;
  }

  final SharedPreferences prefs;
  final http.Client _client;

  /// Saved recitations, played instead of streaming when available.
  final AudioDownloads? downloads;
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _sub;
  RecitationQueue? _queue;
  List<Reciter> reciters = defaultReciters;

  late String reciterId;
  late int repeat;
  late bool continuous;

  RecitationStatus status = RecitationStatus.idle;
  int? page;

  /// A range being repeated for memorization: (surah, from, to), or null
  /// while reciting pages.
  (int, int, int)? range;

  /// Audio links per reciter and surah, fetched once.
  final _surahAudio = <(String, int), Map<int, String>>{};

  /// When the sleep timer stops the recitation, if set.
  DateTime? sleepAt;
  Timer? _sleepTimer;
  String? error;

  /// Called when playback moves on to [page], so the reader can follow.
  void Function(int page)? onPageChanged;

  AyahAudio? get current => _queue?.current;

  Reciter get reciter => reciters.firstWhere(
    (r) => r.id == reciterId,
    orElse: () => Reciter(reciterId, reciterId, reciterId),
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
      final res = await _client.get(
        Uri.parse('$recitationApi/edition?format=audio&type=versebyverse'),
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

  /// Plays [page], starting at the ayah [from] (surah, ayah) if given.
  Future<void> playPage(int page, {(int, int)? from}) async {
    this.page = page;
    range = null;
    status = RecitationStatus.loading;
    error = null;
    notifyListeners();
    try {
      final queue = RecitationQueue(await pageAudio(page), repeat: repeat);
      if (from != null) {
        final start = queue.items.indexWhere(
          (a) => a.surah == from.$1 && a.ayah == from.$2,
        );
        if (start > 0) queue.index = start;
      }
      _queue = queue;
      await _playCurrent();
    } catch (_) {
      status = RecitationStatus.error;
      error = tr(
        'تعذّر التشغيل، تحقق من الإنترنت',
        'Could not play. Check your internet connection.',
      );
      notifyListeners();
    }
  }

  /// The page's ayahs, as the page image shows them, each from its saved
  /// file when downloaded or else from the API.
  @visibleForTesting
  Future<List<AyahAudio>> pageAudio(int page) async {
    final regions = await AyahRegions.load();
    return _audioFor(regions.ayahsOn(page));
  }

  Future<List<AyahAudio>> _audioFor(List<(int, int)> ayahs) async {
    final saved = downloads;
    if (saved != null) await saved.ready;
    final result = <AyahAudio>[];
    for (final (surah, ayah) in ayahs) {
      var url = saved?.localUri(reciterId, surah, ayah);
      url ??= (await _surahUrls(surah))[ayah];
      if (url == null) throw StateError('no audio for $surah:$ayah');
      result.add(AyahAudio(surah, ayah, url));
    }
    return result;
  }

  Future<Map<int, String>> _surahUrls(int surah) async {
    final key = (reciterId, surah);
    final cached = _surahAudio[key];
    if (cached != null) return cached;
    final res = await _client
        .get(Uri.parse('$recitationApi/surah/$surah/$reciterId'))
        .timeout(const Duration(seconds: 20));
    return _surahAudio[key] = {
      for (final (ayah, url) in parseSurahAudio(res.body)) ayah: url,
    };
  }

  /// Repeats ayahs [from] to [to] of [surah] [times] times, for
  /// memorization; each ayah is still repeated [repeat] times.
  Future<void> playRange(int surah, int from, int to, {int times = 1}) async {
    range = (surah, from, to);
    status = RecitationStatus.loading;
    error = null;
    notifyListeners();
    try {
      final items = await _audioFor([
        for (var a = from; a <= to; a++) (surah, a),
      ]);
      _queue = RecitationQueue(items, repeat: repeat, loops: times);
      await _followPage();
      await _playCurrent();
    } catch (_) {
      status = RecitationStatus.error;
      error = tr(
        'تعذّر التشغيل، تحقق من الإنترنت',
        'Could not play. Check your internet connection.',
      );
      notifyListeners();
    }
  }

  /// Which pass of a repeated range is playing, and how many there are.
  (int, int)? get rangePass {
    final queue = _queue;
    if (range == null || queue == null) return null;
    return (queue.loop, queue.loops);
  }

  /// In a range, keeps [page] on the current ayah's page and turns the
  /// reader there.
  Future<void> _followPage() async {
    final current = _queue?.current;
    if (range == null || current == null) return;
    final p = (await AyahRegions.load()).pageOf(current.surah, current.ayah);
    if (p != null && p != page) {
      page = p;
      onPageChanged?.call(p);
    }
  }

  /// Stops the recitation after [duration], or cancels the timer (null).
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepAt = null;
    if (duration != null) {
      sleepAt = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        sleepAt = null;
        _sleepTimer = null;
        stop();
      });
    }
    notifyListeners();
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
      await _followPage();
      await _playCurrent();
      return;
    }
    final finished = page;
    if (range == null && continuous && finished != null && finished < 604) {
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
    range = null;
    notifyListeners();
    await _player?.stop();
  }

  void setReciter(String id) {
    reciterId = id;
    prefs.setString('audio.reciter', id);
    notifyListeners();
    final current = page;
    final repeating = range;
    if (status == RecitationStatus.idle || current == null) return;
    if (repeating != null) {
      final (surah, from, to) = repeating;
      playRange(surah, from, to, times: _queue?.loops ?? 1);
    } else {
      playPage(current);
    }
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
    _sleepTimer?.cancel();
    _sub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
