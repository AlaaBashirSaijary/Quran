import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../audio/audio_store.dart';
import '../core/language.dart';
import 'search.dart';
import 'tafsir.dart';

/// A tafsir the reader can choose. The Muyassar is bundled; the others are
/// fetched a surah at a time from the tafsir_api collection (quran.com and
/// Tarteel's QUL data) the first time they are opened, then kept.
class TafsirSource {
  const TafsirSource(this.id, this.arabicName, this.englishName, this.slug);

  final String id;
  final String arabicName;
  final String englishName;

  /// The folder name in tafsir_api, or null for the bundled Muyassar.
  final String? slug;

  String get name => tr(arabicName, englishName);
  bool get bundled => slug == null;
}

const tafsirSources = [
  TafsirSource('muyassar', 'التفسير الميسر', 'Al-Muyassar', null),
  TafsirSource('saadi', 'تفسير السعدي', 'Al-Sa‘di', 'ar-tafseer-al-saddi'),
  TafsirSource(
    'mukhtasar',
    'المختصر في التفسير',
    'Al-Mukhtasar',
    'ar-tafsir-al-mukhtasar',
  ),
  TafsirSource(
    'ibnKathir',
    'تفسير ابن كثير',
    'Ibn Kathir',
    'ar-tafsir-ibn-kathir',
  ),
  TafsirSource(
    'qurtubi',
    'تفسير القرطبي',
    'Al-Qurtubi',
    'ar-tafseer-al-qurtubi',
  ),
];

TafsirSource tafsirSource(String? id) => tafsirSources.firstWhere(
  (s) => s.id == id,
  orElse: () => tafsirSources.first,
);

const _mirrors = [
  'https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir',
  'https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir',
];

/// Parses a tafsir_api surah file: a list of {surah, ayah, text}. An entry
/// explains its ayah and any following ayahs without an entry of their own.
List<TafsirEntry> parseSurahTafsir(String body, int surah, int ayahCount) {
  final items = [
    for (final e in (jsonDecode(body) as List).cast<Map<String, dynamic>>())
      if ((e['text'] as String? ?? '').trim().isNotEmpty)
        (int.parse('${e['ayah']}'), (e['text'] as String).trim()),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [
    for (var i = 0; i < items.length; i++)
      TafsirEntry(
        surah,
        items[i].$1,
        i + 1 < items.length ? items[i + 1].$1 - 1 : ayahCount,
        items[i].$2,
      ),
  ];
}

class TafsirLibrary {
  TafsirLibrary({http.Client? client, Future<String?>? folder})
    : _client = client ?? http.Client(),
      _folder = folder ?? dataFolder('tafsir');

  static final instance = TafsirLibrary();

  final http.Client _client;
  final Future<String?> _folder;
  final _memory = <(String, int), List<TafsirEntry>>{};

  /// The entries of [surah] in [source], downloading them if needed.
  Future<List<TafsirEntry>> surah(TafsirSource source, int surah) async {
    final slug = source.slug;
    if (slug == null) return (await Tafsir.load()).ofSurah(surah);
    final key = (source.id, surah);
    final cached = _memory[key];
    if (cached != null) return cached;

    final count = (await QuranSearch.load()).ayahsOfSurah(surah).length;
    final folder = await _folder;
    final path = folder == null ? null : '$folder/$slug/$surah.json';
    final saved = path == null ? null : await readText(path);
    if (saved != null) {
      return _memory[key] = parseSurahTafsir(saved, surah, count);
    }
    final body = await _download(slug, surah);
    // Only a file that parses is kept, so a bad response can be retried.
    final entries = parseSurahTafsir(body, surah, count);
    if (entries.isEmpty) throw const FormatException('no tafsir entries');
    if (path != null) {
      await writeFile(path, Uint8List.fromList(utf8.encode(body)));
    }
    return _memory[key] = entries;
  }

  Future<String> _download(String slug, int surah) async {
    Object? failure;
    for (final mirror in _mirrors) {
      try {
        final res = await _client
            .get(Uri.parse('$mirror/$slug/$surah.json'))
            .timeout(const Duration(seconds: 60));
        if (res.statusCode == 200) return utf8.decode(res.bodyBytes);
        failure = 'HTTP ${res.statusCode}';
      } catch (e) {
        failure = e;
      }
    }
    throw StateError('tafsir download failed: $failure');
  }

  /// The entries explaining [ayahs], each once, with the ayahs it covers.
  Future<List<(TafsirEntry, List<Ayah>)>> forAyahs(
    TafsirSource source,
    List<Ayah> ayahs,
  ) async {
    final result = <(TafsirEntry, List<Ayah>)>[];
    for (final ayah in ayahs) {
      final entries = await surah(source, ayah.surah);
      final entry = entries.where((e) => e.covers(ayah.surah, ayah.number));
      if (entry.isEmpty) continue;
      if (result.isNotEmpty && identical(result.last.$1, entry.first)) {
        result.last.$2.add(ayah);
      } else {
        result.add((entry.first, [ayah]));
      }
    }
    return result;
  }
}
