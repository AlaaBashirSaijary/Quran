import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/index.dart';
import '../providers/reading_provider.dart';
import '../providers/sebha_provider.dart';
import 'harvest.dart';

/// "My month": a card summarising the last 30 days, ready to share.
class HarvestScreen extends StatefulWidget {
  const HarvestScreen({super.key});

  @override
  State<HarvestScreen> createState() => _HarvestScreenState();
}

class _HarvestScreenState extends State<HarvestScreen> {
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
              name: 'manhaj-hayah-month.png',
            ),
          ],
          fileNameOverrides: ['manhaj-hayah-month.png'],
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
    final reading = Provider.of<ReadingProvider>(context);
    final sebha = Provider.of<SebhaProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final harvest = Harvest.compute(reading, sebha);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('حصادي الشهري', 'My month')),
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
          if (harvest.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                tr(
                  'ابدأ وردك أو أذكارك اليوم، وسيظهر حصادك هنا.',
                  'Start your daily reading or azkar today and your month will show here.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.pageNumber),
              ),
            ),
          Center(
            child: RepaintBoundary(
              key: _card,
              child: HarvestCard(harvest: harvest, light: _light),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              'يُحسب من بيانات هاتفك فقط، ولا يُرسل إلى أي مكان. '
                  'عدّاد التسبيح يبدأ من لحظة تحديث التطبيق.',
              'Calculated from data on your phone only and never sent anywhere. '
                  'The tasbeeh count starts from when you updated the app.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.pageNumber, fontSize: 12),
          ),
          const SizedBox(height: 16),
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
        ],
      ),
    );
  }
}

/// The card itself: four numbers, the khatma bar and the app's name.
class HarvestCard extends StatelessWidget {
  const HarvestCard({super.key, required this.harvest, this.light = false});

  final Harvest harvest;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final background = light ? AppColor.cream : AppColor.greenDark;
    final ink = light ? AppColor.greenDark : Colors.white;
    final h = harvest;
    return Directionality(
      textDirection: Directionality.of(context),
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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.gold, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: AppColor.gold, size: 18),
              const SizedBox(height: 10),
              Text(
                tr('حصادي في آخر ${h.days} يوماً', 'My last ${h.days} days'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Stat(
                    '${h.pages}',
                    tr('صفحة قرأتها', 'pages read'),
                    ink,
                  ),
                  _Stat(
                    '${h.activeDays}',
                    tr('يوماً قرأت فيه', 'days of reading'),
                    ink,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Stat(
                    '${h.azkarDays}',
                    tr('يوماً أكملت فيه أذكاراً', 'days of azkar'),
                    ink,
                  ),
                  _Stat('${h.tasbeeh}', tr('تسبيحة', 'tasbeeh'), ink),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  tr(
                    'ختمتي الحالية: ${h.khatmaPercent}٪',
                    'Current khatma: ${h.khatmaPercent}%',
                  ),
                  style: TextStyle(color: ink, fontSize: 14),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: h.khatmaPercent / 100,
                  minHeight: 10,
                  color: AppColor.gold,
                  backgroundColor: ink.withValues(alpha: 0.18),
                ),
              ),
              if (h.bestStreak > 1) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tr(
                      'أطول سلسلة أيام متتالية: ${h.bestStreak}',
                      'Longest streak: ${h.bestStreak} days',
                    ),
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              if (h.khatmas > 0) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tr(
                      'ختمات مكتملة: ${h.khatmas}',
                      'Completed khatmas: ${h.khatmas}',
                    ),
                    style: const TextStyle(
                      color: AppColor.gold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Divider(color: AppColor.gold.withValues(alpha: 0.6)),
              const SizedBox(height: 4),
              Text(
                'منهج حياة',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ink.withValues(alpha: 0.8),
                ),
              ),
              Text(
                'alaabashirsaijary.github.io/manhaj-hayah',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 10,
                  color: ink.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.ink);

  final String value;
  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: AppColor.gold,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: ink, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
