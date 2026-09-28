import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../audio/audio_store.dart';
import 'translation.dart';

/// A translation of the meanings the reader can choose. English is bundled;
/// the others are downloaded once from the quran-json package (tanzil.net
/// and quranenc.com texts) and kept on the phone.
class TranslationLanguage {
  const TranslationLanguage(
    this.code,
    this.name,
    this.translator, {
    this.direction = TextDirection.ltr,
  });

  final String code;

  /// In its own language.
  final String name;
  final String translator;
  final TextDirection direction;

  bool get bundled => code == 'en';
}

const translationLanguages = [
  TranslationLanguage('en', 'English', 'Saheeh International'),
  TranslationLanguage(
    'ur',
    'اردو',
    'ابو الاعلیٰ مودودی',
    direction: TextDirection.rtl,
  ),
  TranslationLanguage('id', 'Bahasa Indonesia', 'Kementerian Agama RI'),
  TranslationLanguage('tr', 'Türkçe', 'Diyanet İşleri'),
  TranslationLanguage('fr', 'Français', 'Muhammad Hamidullah'),
  TranslationLanguage('bn', 'বাংলা', 'Muhiuddin Khan'),
  TranslationLanguage('ru', 'Русский', 'Эльмир Кулиев'),
  TranslationLanguage('es', 'Español', 'Muhammad Isa García'),
  TranslationLanguage('zh', '中文', '马坚 (Muhammad Makin)'),
  TranslationLanguage('sv', 'Svenska', 'Knut Bernström'),
];

TranslationLanguage translationLanguage(String? code) =>
    translationLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => translationLanguages.first,
    );

/// Parses a quran-json `quran_xx.json` file into each surah's translations.
List<List<String>> parseQuranJson(String body) => [
  for (final surah in (jsonDecode(body) as List).cast<Map<String, dynamic>>())
    [
      for (final verse
          in (surah['verses'] as List).cast<Map<String, dynamic>>())
        (verse['translation'] as String).trim(),
    ],
];

class Translations {
  Translations({http.Client? client, Future<String?>? folder})
    : _client = client ?? http.Client(),
      _folder = folder ?? dataFolder('translations');

  static final instance = Translations();

  static const _url = 'https://cdn.jsdelivr.net/npm/quran-json@3.1.2/dist';

  final http.Client _client;
  final Future<String?> _folder;
  final _loaded = <String, Translation>{};

  Translation? loaded(String code) =>
      code == 'en' ? Translation.loaded : _loaded[code];

  Future<String?> _path(String code) async {
    final folder = await _folder;
    return folder == null ? null : '$folder/$code.json';
  }

  /// Whether [code] is on the phone (English always is).
  Future<bool> isDownloaded(String code) async {
    if (code == 'en' || _loaded.containsKey(code)) return true;
    final path = await _path(code);
    return path != null && await fileExists(path);
  }

  /// The translation in [code], or null if it has not been downloaded.
  Future<Translation?> load(String code) async {
    if (code == 'en') return Translation.load();
    final cached = _loaded[code];
    if (cached != null) return cached;
    final path = await _path(code);
    final body = path == null ? null : await readText(path);
    if (body == null) return null;
    final surahs = [
      for (final s in jsonDecode(body) as List) (s as List).cast<String>(),
    ];
    return _loaded[code] = Translation.fromSurahs(surahs);
  }

  /// Downloads the translation in [code] and keeps only its text.
  Future<Translation> download(String code) async {
    final res = await _client
        .get(Uri.parse('$_url/quran_$code.json'))
        .timeout(const Duration(minutes: 2));
    if (res.statusCode != 200) throw StateError('HTTP ${res.statusCode}');
    final surahs = parseQuranJson(utf8.decode(res.bodyBytes));
    if (surahs.length != 114) throw const FormatException('not 114 surahs');
    final path = await _path(code);
    if (path != null) {
      await writeFile(
        path,
        Uint8List.fromList(utf8.encode(jsonEncode(surahs))),
      );
    }
    return _loaded[code] = Translation.fromSurahs(surahs);
  }
}
