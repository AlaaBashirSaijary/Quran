import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../audio/audio_store.dart';
import '../content/library.dart';

/// One book in the library's catalog.
///
/// A book is only listed when its source, licence and reviewer are all
/// filled in, so nothing reaches the reader without them.
class BookInfo {
  const BookInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.edition,
    required this.license,
    required this.reviewer,
    required this.reviewedOn,
    this.asset,
    this.url,
    this.size = 0,
  });

  factory BookInfo.fromJson(Map<String, dynamic> json) {
    String text(String key) => '${json[key] ?? ''}'.trim();
    return BookInfo(
      id: text('id'),
      title: text('title'),
      author: text('author'),
      edition: text('edition'),
      license: text('license'),
      reviewer: text('reviewer'),
      reviewedOn: text('reviewedOn'),
      asset: text('asset').isEmpty ? null : text('asset'),
      url: text('url').isEmpty ? null : text('url'),
      size: json['size'] is int ? json['size'] as int : 0,
    );
  }

  final String id;
  final String title;
  final String author;

  /// Which edition the text was taken from.
  final String edition;

  /// The licence, or the permission, under which the text is included.
  final String license;

  /// Who checked the text, and when.
  final String reviewer;
  final String reviewedOn;

  /// A pack bundled in the app, or one downloaded from [url].
  final String? asset;
  final String? url;

  /// Download size in bytes, when known.
  final int size;

  bool get complete =>
      [id, title, author, edition, license, reviewer, reviewedOn].every(
        (s) => s.isNotEmpty,
      ) &&
      (asset != null || url != null);
}

/// Reads a book pack: `{"sections": [{"title": "...", "texts": ["..."]}]}`.
List<TextSection> parseBookPack(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final sections = [
    for (final s in (json['sections'] as List).cast<Map<String, dynamic>>())
      TextSection('${s['title']}', [
        for (final t in (s['texts'] as List)) '$t',
      ]),
  ];
  if (sections.isEmpty || sections.any((s) => s.texts.isEmpty)) {
    throw const FormatException('empty book');
  }
  return sections;
}

/// The books on offer, and which of them are on the phone. Packs are
/// downloaded when asked for and kept, like the extra tafsirs.
class BookLibrary extends ChangeNotifier {
  BookLibrary({
    http.Client? client,
    Future<String> Function()? catalog,
    Future<String?>? folder,
    Future<String> Function(String asset)? assets,
  }) : _client = client ?? http.Client(),
       _catalog =
           catalog ?? (() => rootBundle.loadString('assets/library/catalog.json')),
       _folder = folder ?? dataFolder('books'),
       _assets = assets ?? rootBundle.loadString;

  final http.Client _client;
  final Future<String> Function() _catalog;
  final Future<String?> _folder;
  final Future<String> Function(String asset) _assets;

  List<BookInfo> books = const [];
  final _installed = <String>{};
  final _busy = <String>{};
  bool loaded = false;
  String? error;

  bool isInstalled(String id) => _installed.contains(id);

  bool isBusy(String id) => _busy.contains(id);

  /// Reads the catalog and finds which packs are already on the phone.
  Future<void> load() async {
    try {
      final json = jsonDecode(await _catalog()) as Map<String, dynamic>;
      books = [
        for (final b in (json['books'] as List).cast<Map<String, dynamic>>())
          if (BookInfo.fromJson(b).complete) BookInfo.fromJson(b),
      ];
    } catch (_) {
      books = const [];
    }
    _installed.clear();
    final folder = await _folder;
    for (final b in books) {
      if (b.asset != null ||
          (folder != null && await fileExists('$folder/${b.id}/book.json'))) {
        _installed.add(b.id);
      }
    }
    loaded = true;
    notifyListeners();
  }

  BookInfo? byId(String id) {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Downloads a book. Returns whether it is now on the phone; a response
  /// that does not parse is not kept.
  Future<bool> install(String id) async {
    final book = byId(id);
    if (book == null || isInstalled(id) || isBusy(id)) return isInstalled(id);
    final url = book.url;
    final folder = await _folder;
    if (url == null || folder == null) return false;
    _busy.add(id);
    error = null;
    notifyListeners();
    try {
      final res = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) throw StateError('HTTP ${res.statusCode}');
      final body = utf8.decode(res.bodyBytes);
      parseBookPack(body);
      await writeFile(
        '$folder/$id/book.json',
        Uint8List.fromList(utf8.encode(body)),
      );
      _installed.add(id);
      return true;
    } catch (_) {
      error = 'download';
      return false;
    } finally {
      _busy.remove(id);
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    final folder = await _folder;
    final book = byId(id);
    if (folder == null || book == null || book.asset != null) return;
    await deleteFolder('$folder/$id');
    _installed.remove(id);
    notifyListeners();
  }

  /// The sections of an installed book.
  Future<List<TextSection>> sections(String id) async {
    final book = byId(id);
    if (book == null) throw StateError('unknown book');
    final asset = book.asset;
    if (asset != null) return parseBookPack(await _assets(asset));
    final folder = await _folder;
    final body = folder == null ? null : await readText('$folder/$id/book.json');
    if (body == null) throw StateError('book not installed');
    return parseBookPack(body);
  }
}
