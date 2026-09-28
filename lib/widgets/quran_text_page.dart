import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/recitation.dart';
import '../core/index.dart';
import '../providers/settings_provider.dart';
import '../quran/ayah_regions.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import 'ayah_actions.dart';

/// A mushaf page as text in the Uthmani font, for reading at any size.
/// It holds the same ayahs as the page image.
class QuranTextPage extends StatefulWidget {
  const QuranTextPage({super.key, required this.page});

  final int page;

  @override
  State<QuranTextPage> createState() => _QuranTextPageState();
}

class _QuranTextPageState extends State<QuranTextPage> {
  late final Future<List<Object>> _data = Future.wait([
    AyahRegions.load(),
    QuranSearch.load(),
  ]);

  final _recognizers = <GestureRecognizer>[];
  (int, int)? _selected;

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _actions(int surah, int ayah) async {
    setState(() => _selected = (surah, ayah));
    await showAyahActions(context, page: widget.page, surah: surah, ayah: ayah);
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final recited = context.select<RecitationProvider, (int, int)?>((r) {
      final current = r.current;
      if (r.page != widget.page ||
          current == null ||
          r.status == RecitationStatus.idle ||
          r.status == RecitationStatus.error) {
        return null;
      }
      return (current.surah, current.ayah);
    });
    final highlight = _selected ?? recited;

    final regions = AyahRegions.loaded;
    final quran = QuranSearch.loaded;
    return FutureBuilder<List<Object>>(
      future: _data,
      initialData: regions != null && quran != null ? [regions, quran] : null,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final regions = data[0] as AyahRegions;
        final quran = data[1] as QuranSearch;
        _disposeRecognizers();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _build(context, regions, quran, highlight),
          ),
        );
      },
    );
  }

  List<Widget> _build(
    BuildContext context,
    AyahRegions regions,
    QuranSearch quran,
    (int, int)? highlight,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = context.contentSize(24);
    final basmala = quran.ayahsOfSurah(1).first.text;
    final children = <Widget>[];

    // Consecutive ayahs of one surah are one paragraph.
    final runs = <List<(int, int)>>[];
    for (final ayah in regions.ayahsOn(widget.page)) {
      if (runs.isEmpty || runs.last.last.$1 != ayah.$1 || ayah.$2 == 1) {
        runs.add([ayah]);
      } else {
        runs.last.add(ayah);
      }
    }

    for (final run in runs) {
      final (surah, first) = run.first;
      if (first == 1) {
        children.add(_SurahHeader(surah: surah));
        if (surah != 1 && surah != 9) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                basmala,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppTheme.secondaryFontFamily,
                  fontSize: size,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          );
        }
      }
      final ayahs = quran.ayahsOfSurah(surah);
      children.add(
        Text.rich(
          TextSpan(
            children: [
              for (final (s, a) in run)
                TextSpan(
                  text: '${ayahs[a - 1].text} ﴿${_arabicDigits(a)}﴾ ',
                  recognizer:
                      (LongPressGestureRecognizer()
                            ..onLongPress = () => _actions(s, a))
                          .also(_recognizers.add),
                  style: highlight == (s, a)
                      ? TextStyle(
                          backgroundColor: colorScheme.gold.withValues(
                            alpha: 0.3,
                          ),
                        )
                      : null,
                ),
            ],
          ),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: AppTheme.secondaryFontFamily,
            fontSize: size,
            height: 2,
            color: colorScheme.onSurface,
          ),
        ),
      );
    }
    return children;
  }
}

extension _Also<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}

String _arabicDigits(int n) =>
    n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.surah});

  final int surah;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.gold.withValues(alpha: 0.12),
        border: Border.all(color: colorScheme.gold),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'سورة ${getSurahNameArabic(surah)}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.secondaryFontFamily,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
