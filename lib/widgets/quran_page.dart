import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/recitation.dart';
import '../core/index.dart';
import '../quran/ayah_regions.dart';
import '../quran/page_images.dart';
import '../quran/quran.dart';
import 'ayah_actions.dart';
import 'invert_color.dart';

/// Aspect ratio of the page images (width / height).
const _pageRatio = 512 / 828;

/// Whether the page being read is zoomed in; page swiping pauses meanwhile
/// so a drag pans the page instead.
final readerZoomed = ValueNotifier<bool>(false);

/// A mushaf page. Long-pressing an ayah highlights it and offers tafsir,
/// recitation and sharing; the ayah being recited is highlighted too.
class QuranPage extends StatefulWidget {
  const QuranPage({super.key, required this.pageIndex});

  final int pageIndex;

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  (int, int)? _selected;
  final _zoom = TransformationController();
  bool _zoomed = false;
  Offset _doubleTapAt = Offset.zero;

  void _setZoomed(bool value) {
    if (_zoomed == value) return;
    setState(() => _zoomed = value);
    readerZoomed.value = value;
  }

  void _onInteractionEnd(ScaleEndDetails _) =>
      _setZoomed(_zoom.value.getMaxScaleOnAxis() > 1.01);

  /// Double tap zooms in to twice the size around the tap, or back out.
  void _onDoubleTap() {
    if (_zoomed) {
      _zoom.value = Matrix4.identity();
      _setZoomed(false);
    } else {
      const scale = 2.0;
      final p = _doubleTapAt;
      _zoom.value = Matrix4.identity()
        ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
      _setZoomed(true);
    }
  }

  @override
  void dispose() {
    if (_zoomed) readerZoomed.value = false;
    _zoom.dispose();
    super.dispose();
  }

  int get _page => widget.pageIndex + 1;

  @override
  void initState() {
    super.initState();
    if (AyahRegions.loaded == null) {
      AyahRegions.load().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _onLongPress(Offset local, Size size) async {
    final regions = AyahRegions.loaded;
    if (regions == null) return;
    final hit = regions.ayahAt(
      _page,
      Offset(local.dx / size.width, local.dy / size.height),
    );
    if (hit == null) return;
    setState(() => _selected = hit);
    await showAyahActions(context, page: _page, surah: hit.$1, ayah: hit.$2);
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // The ayah being recited, when it is on this page.
    final recited = context.select<RecitationProvider, (int, int)?>((r) {
      final current = r.current;
      if (r.page != _page ||
          current == null ||
          r.status == RecitationStatus.idle ||
          r.status == RecitationStatus.error) {
        return null;
      }
      return (current.surah, current.ayah);
    });
    final highlight = _selected ?? recited;
    final rects = highlight == null
        ? const <Rect>[]
        : AyahRegions.loaded?.rectsOf(_page, highlight.$1, highlight.$2) ??
              const <Rect>[];

    return AspectRatio(
      aspectRatio: _pageRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return InteractiveViewer(
            transformationController: _zoom,
            minScale: 1,
            maxScale: 4,
            // Unzoomed, a horizontal drag must reach the page swiper.
            panEnabled: _zoomed,
            onInteractionEnd: _onInteractionEnd,
            child: GestureDetector(
              onLongPressStart: (d) => _onLongPress(d.localPosition, size),
              onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
              onDoubleTap: _onDoubleTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (rects.isNotEmpty)
                    CustomPaint(
                      painter: _HighlightPainter(
                        rects,
                        colorScheme.gold.withValues(alpha: 0.28),
                      ),
                    ),
                  InvertColor(
                    isInvert: Theme.of(context).brightness == Brightness.dark,
                    child: MushafPageImage(
                      page: _page,
                      semanticLabel: tr(
                        'صفحة $_page من المصحف',
                        'Mushaf page $_page',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter(this.rects, this.color);

  final List<Rect> rects;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final r in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            r.left * size.width,
            r.top * size.height,
            r.right * size.width,
            r.bottom * size.height,
          ),
          const Radius.circular(6),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.rects != rects || old.color != color;
}
