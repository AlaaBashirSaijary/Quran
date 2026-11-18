import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio/audio_store.dart';
import '../core/language.dart';

/// Where the catalog can be updated without a new release, so a pack can be
/// added, or withdrawn if its owner asks.
const azkarAudioCatalogUrl =
    'https://alaabashirsaijary.github.io/manhaj-hayah/azkar-audio.json';

const azkarAudioAsset = 'assets/azkar_audio/catalog.json';

/// A recording of the azkar of one category, with who made it, where it
/// comes from and on what terms it is shared.
class AzkarAudioPack {
  const AzkarAudioPack({
    required this.id,
    required this.category,
    required this.title,
    required this.reciter,
    required this.source,
    required this.sourceUrl,
    required this.license,
    required this.url,
    required this.size,
  });

  final String id;

  /// The azkar category it belongs to (see azkar.dart).
  final String category;
  final String title;
  final String reciter;
  final String source;
  final String sourceUrl;
  final String license;
  final String url;

  /// Size in bytes, as listed by the source.
  final int size;
}

/// A recording on another website that the app only links to: the user
/// opens its page in the browser, so the app copies nothing and needs no
/// permission.
class AzkarAudioLink {
  const AzkarAudioLink({
    required this.category,
    required this.title,
    required this.reciter,
    required this.source,
    required this.url,
    required this.hint,
  });

  final String category;
  final String title;
  final String reciter;
  final String source;
  final String url;
  final String hint;
}

/// The links of a catalog file (https only).
List<AzkarAudioLink> parseAzkarAudioLinks(String source) {
  final m = jsonDecode(source) as Map<String, dynamic>;
  return [
    for (final l in (m['links'] as List? ?? const []))
      if ((l as Map<String, dynamic>)['url'].toString().startsWith('https://'))
        AzkarAudioLink(
          category: l['category'] as String,
          title: l['title'] as String,
          reciter: l['reciter'] as String,
          source: l['source'] as String,
          url: l['url'] as String,
          hint: (l['hint'] as String?) ?? '',
        ),
  ];
}

/// The packs of a catalog file that may be shown: approved ones with an
/// https link. A pack whose owner has not given permission stays out.
List<AzkarAudioPack> parseAzkarAudio(String source) {
  final m = jsonDecode(source) as Map<String, dynamic>;
  return [
    for (final p in m['packs'] as List)
      if ((p as Map<String, dynamic>)['approved'] == true &&
          (p['url'] as String).startsWith('https://'))
        AzkarAudioPack(
          id: p['id'] as String,
          category: p['category'] as String,
          title: p['title'] as String,
          reciter: p['reciter'] as String,
          source: p['source'] as String,
          sourceUrl: p['sourceUrl'] as String,
          license: p['license'] as String,
          url: p['url'] as String,
          size: p['size'] as int,
        ),
  ];
}

/// Spoken azkar: lists the packs, saves them on the phone so they play
/// without internet, and plays them.
class AzkarAudio extends ChangeNotifier {
  AzkarAudio(
    this.prefs, {
    http.Client? client,
    Future<String?>? folder,
    Future<String> Function()? bundled,
    this.catalogUrl = azkarAudioCatalogUrl,
    Future<bool> Function(Uri url)? launcher,
  }) : _launcher =
           launcher ??
           ((url) => launchUrl(url, mode: LaunchMode.externalApplication)),
       _client = client ?? http.Client(),
       _folderFuture = folder ?? dataFolder('azkar_audio'),
       _bundled = bundled ?? (() => rootBundle.loadString(azkarAudioAsset));

  static const _catalogKey = 'azkar.audio.catalog';

  final SharedPreferences prefs;
  final http.Client _client;
  final Future<String?> _folderFuture;
  final Future<String> Function() _bundled;
  final String catalogUrl;
  final Future<bool> Function(Uri url) _launcher;

  String? _folder;
  var _packs = <AzkarAudioPack>[];
  var _links = <AzkarAudioLink>[];
  final _saved = <String>{};

  /// Share downloaded so far (0 to 1) of the packs being downloaded.
  final progress = <String, double>{};
  String? error;

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _sub;
  String? playingId;
  bool playing = false;
  bool loading = false;

  List<AzkarAudioPack> get packs => List.unmodifiable(_packs);

  /// The pack for [category], or null if there is none.
  AzkarAudioPack? packFor(String category) {
    for (final p in _packs) {
      if (p.category == category) return p;
    }
    return null;
  }

  /// The page to open for [category], when it has no pack of its own.
  AzkarAudioLink? linkFor(String category) {
    if (packFor(category) != null) return null;
    for (final l in _links) {
      if (l.category == category) return l;
    }
    return null;
  }

  /// Opens the link in the browser. Returns false if the phone could not.
  Future<bool> openLink(AzkarAudioLink link) async {
    try {
      return await _launcher(Uri.parse(link.url));
    } catch (_) {
      return false;
    }
  }

  /// Whether saving on the phone is possible here (not on the web).
  bool get supported => _folder != null;

  /// Reads the catalog: the one published online if it can be reached (and
  /// keeps it for next time), else the last one kept, else the bundled one.
  Future<void> load() async {
    _folder = await _folderFuture;
    var text = prefs.getString(_catalogKey);
    try {
      final res = await _client
          .get(Uri.parse(catalogUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = utf8.decode(res.bodyBytes);
        parseAzkarAudio(body);
        text = body;
        await prefs.setString(_catalogKey, body);
      }
    } catch (_) {
      // Offline or not published yet: what is kept is used.
    }
    final bundled = await _bundled();
    try {
      _packs = parseAzkarAudio(text ?? bundled);
      _links = parseAzkarAudioLinks(text ?? bundled);
    } catch (_) {
      _packs = parseAzkarAudio(bundled);
      _links = parseAzkarAudioLinks(bundled);
    }
    // A catalog without a links list keeps the bundled ones.
    if (_links.isEmpty) _links = parseAzkarAudioLinks(bundled);
    for (final p in _packs) {
      if (_folder != null && await fileExists(_path(p))) _saved.add(p.id);
    }
    notifyListeners();
  }

  String _path(AzkarAudioPack pack) => '$_folder/${pack.id}.mp3';

  bool isDownloaded(AzkarAudioPack pack) => _saved.contains(pack.id);

  Future<void> download(AzkarAudioPack pack) async {
    if (!supported || isDownloaded(pack) || progress.containsKey(pack.id)) {
      return;
    }
    progress[pack.id] = 0;
    error = null;
    notifyListeners();
    try {
      final request = http.Request('GET', Uri.parse(pack.url));
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError('HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? pack.size;
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        bytes.add(chunk);
        progress[pack.id] = total > 0
            ? (bytes.length / total).clamp(0.0, 1.0)
            : 0;
        notifyListeners();
      }
      // A page of text or an empty answer is not a recording.
      if (bytes.length < 10 * 1024) throw StateError('too small');
      await writeFile(_path(pack), bytes.toBytes());
      _saved.add(pack.id);
    } catch (_) {
      error = tr(
        'توقف التحميل. تحقق من الإنترنت وحاول مرة أخرى.',
        'The download stopped. Check your internet connection and try again.',
      );
    }
    progress.remove(pack.id);
    notifyListeners();
  }

  Future<void> delete(AzkarAudioPack pack) async {
    if (playingId == pack.id) await stop();
    if (_folder != null) await deleteFile(_path(pack));
    _saved.remove(pack.id);
    notifyListeners();
  }

  AudioPlayer get _audio {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _sub = player.playerStateStream.listen((state) {
      playing = state.playing && state.processingState != ProcessingState.completed;
      loading =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (state.processingState == ProcessingState.completed) {
        playingId = null;
        player.stop();
      }
      notifyListeners();
    });
    return _player = player;
  }

  /// Plays [pack] from the phone if it is saved, else from the internet.
  Future<void> play(AzkarAudioPack pack) async {
    error = null;
    playingId = pack.id;
    loading = true;
    notifyListeners();
    try {
      final player = _audio;
      if (isDownloaded(pack)) {
        await player.setFilePath(_path(pack));
      } else {
        await player.setUrl(pack.url);
      }
      unawaited(player.play());
    } catch (_) {
      playingId = null;
      loading = false;
      error = tr(
        'تعذّر تشغيل الصوت. تحقق من الإنترنت.',
        'The audio could not be played. Check your internet connection.',
      );
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _player?.pause();
    notifyListeners();
  }

  Future<void> toggle(AzkarAudioPack pack) async {
    if (playingId == pack.id) {
      playing ? await pause() : await _player?.play();
    } else {
      await play(pack);
    }
  }

  Future<void> stop() async {
    playingId = null;
    playing = false;
    await _player?.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
