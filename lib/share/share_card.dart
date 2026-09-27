import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/index.dart';

/// Opens a preview of [text] as a card image, ready to share.
///
/// [reference] names the source, e.g. «سورة البقرة ﴿255﴾» or a book.
/// Quranic text is set in the Uthmani font.
void shareAsImage(
  BuildContext context, {
  required String text,
  required String reference,
  bool quran = false,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>
          ShareCardScreen(text: text, reference: reference, quran: quran),
    ),
  );
}

class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({
    super.key,
    required this.text,
    required this.reference,
    this.quran = false,
  });

  final String text;
  final String reference;
  final bool quran;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _card = GlobalKey();
  bool _light = false;
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              png!.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'tareeq-aljannah.png',
            ),
          ],
          fileNameOverrides: ['tareeq-aljannah.png'],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('تعذّر إنشاء الصورة.', 'Could not create the image.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('مشاركة كصورة', 'Share as Image')),
        actions: [
          IconButton(
            tooltip: _light
                ? tr('خلفية خضراء', 'Green background')
                : tr('خلفية فاتحة', 'Light background'),
            icon: Icon(
              _light ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            ),
            onPressed: () => setState(() => _light = !_light),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: RepaintBoundary(
              key: _card,
              child: ShareCard(
                text: widget.text,
                reference: widget.reference,
                quran: widget.quran,
                light: _light,
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _share,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_rounded),
            label: Text(tr('مشاركة الصورة', 'Share image')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: '${widget.text}\n${widget.reference}'),
              );
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(tr('نُسخ النص', 'Text copied'))),
                );
            },
            icon: Icon(Icons.copy_rounded, color: colorScheme.gold),
            label: Text(tr('نسخ النص', 'Copy text')),
          ),
        ],
      ),
    );
  }
}

/// The image itself: the text on green (or cream) inside a gold frame,
/// with its source and the app's name.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.text,
    required this.reference,
    this.quran = false,
    this.light = false,
  });

  final String text;
  final String reference;
  final bool quran;
  final bool light;

  /// Smaller type for longer texts, so the card stays a sensible shape.
  double get _fontSize {
    final base = quran ? 26.0 : 20.0;
    if (text.length > 900) return base * 0.62;
    if (text.length > 500) return base * 0.72;
    if (text.length > 250) return base * 0.85;
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final background = light ? AppColor.cream : AppColor.greenDark;
    final ink = light ? AppColor.greenDark : Colors.white;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: light
                ? [AppColor.paper, AppColor.cream]
                : [AppColor.green, AppColor.greenDark],
          ),
          color: background,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.gold, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: AppColor.gold, size: 18),
              const SizedBox(height: 14),
              Text(
                text,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: quran ? AppTheme.secondaryFontFamily : null,
                  fontSize: _fontSize,
                  height: quran ? 1.9 : 1.8,
                  color: ink,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Divider(color: AppColor.gold.withValues(alpha: 0.6)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      reference,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColor.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: AppColor.gold.withValues(alpha: 0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'طريق الجنة',
                style: TextStyle(
                  fontSize: 11,
                  color: ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «سورة البقرة ﴿255﴾» or «سورة البقرة ﴿1–5﴾», always in Arabic because
/// it travels with the Arabic text.
String quranReference(String surahName, int from, [int? to]) =>
    'سورة $surahName ﴿${to == null || to == from ? '$from' : '$from–$to'}﴾';
