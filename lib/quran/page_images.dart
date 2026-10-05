import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../audio/audio_store.dart';
import '../core/language.dart';
import 'quran.dart';

/// True in the "light" build, which leaves the 604 mushaf page images out of
/// the APK (about 41 MB) and fetches each page the first time it is opened.
/// Built with `--dart-define=LITE=true`; the full build bundles every page.
const kLite = bool.fromEnvironment('LITE');

const pageImagesBase = 'https://alaabashirsaijary.github.io/manhaj-hayah/mushaf';
const mushafPageCount = 604;

/// Fetches mushaf pages for the light build, and keeps them on the phone so
/// each page is downloaded once.
class PageImages {
  PageImages._();

  static final _recent = <int, Uint8List>{};

  /// Progress (0 to 1) of "download the whole mushaf", or null when idle.
  static final progress = ValueNotifier<double?>(null);

  static String _name(int page) => 'page${formattedPageNumber(page)}.png';

  static void _remember(int page, Uint8List bytes) {
    _recent.remove(page);
    _recent[page] = bytes;
    while (_recent.length > 8) {
      _recent.remove(_recent.keys.first);
    }
  }

  static Future<Uint8List> load(int page) async {
    final cached = _recent[page];
    if (cached != null) return cached;
    final dir = await dataFolder('mushaf');
    final path = dir == null ? null : '$dir/${_name(page)}';
    if (path != null && await fileExists(path)) {
      final saved = await readBytes(path);
      if (saved != null && saved.isNotEmpty) {
        _remember(page, saved);
        return saved;
      }
    }
    final res = await http
        .get(Uri.parse('$pageImagesBase/${_name(page)}'))
        .timeout(const Duration(seconds: 40));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      throw Exception('HTTP ${res.statusCode}');
    }
    if (path != null) await writeFile(path, res.bodyBytes);
    _remember(page, res.bodyBytes);
    return res.bodyBytes;
  }

  /// Warms the pages next to the one being read. Failures are ignored.
  static void prefetch(int page) {
    for (final p in [page + 1, page - 1, page + 2]) {
      if (p >= 1 && p <= mushafPageCount) {
        unawaited(load(p).then((_) {}, onError: (_) {}));
      }
    }
  }

  static Future<int> savedCount() async {
    final dir = await dataFolder('mushaf');
    return dir == null ? 0 : fileCount(dir);
  }

  /// Downloads every page that is not saved yet. Returns how many pages
  /// failed (0 when the whole mushaf is now on the phone).
  static Future<int> downloadAll() async {
    if (progress.value != null) return 0;
    var failed = 0;
    progress.value = 0;
    try {
      for (var p = 1; p <= mushafPageCount; p++) {
        try {
          await load(p);
        } catch (_) {
          failed++;
        }
        progress.value = p / mushafPageCount;
      }
    } finally {
      progress.value = null;
    }
    return failed;
  }
}

/// One mushaf page: bundled in the full build, fetched in the light one.
class MushafPageImage extends StatefulWidget {
  const MushafPageImage({super.key, required this.page, this.semanticLabel});

  final int page;
  final String? semanticLabel;

  @override
  State<MushafPageImage> createState() => _MushafPageImageState();
}

class _MushafPageImageState extends State<MushafPageImage> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(MushafPageImage old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) _start();
  }

  void _start() {
    _bytes = PageImages.load(widget.page);
    _bytes.then((_) => PageImages.prefetch(widget.page), onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (!kLite) {
      return Image.asset(
        pageDir(widget.page),
        fit: BoxFit.fill,
        semanticLabel: widget.semanticLabel,
      );
    }
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(
            snap.data!,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            semanticLabel: widget.semanticLabel,
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      'تعذّر تنزيل الصفحة. تحتاج هذه النسخة الخفيفة إلى الإنترنت '
                          'لتنزيل كل صفحة مرة واحدة. يمكنك القراءة نصاً دون إنترنت '
                          'من زر «نص» في الأعلى.',
                      'Could not download this page. The light version needs the internet to fetch each page once. You can read as text without internet.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(_start),
                    child: Text(tr('إعادة المحاولة', 'Try again')),
                  ),
                ],
              ),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
