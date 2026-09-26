import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../providers/quran.dart';
import '../quran/quran.dart';
import 'recitation.dart';

/// Starts reciting the reader's current page.
void startRecitation(BuildContext context) {
  final quran = Provider.of<Quran>(context, listen: false);
  final recitation = Provider.of<RecitationProvider>(context, listen: false);
  recitation.onPageChanged = quran.goToPage;
  recitation.playPage(quran.currentPage);
}

/// Floating controls shown in the reader while a recitation is active.
class RecitationBar extends StatelessWidget {
  const RecitationBar({super.key});

  @override
  Widget build(BuildContext context) {
    final recitation = Provider.of<RecitationProvider>(context);
    if (recitation.status == RecitationStatus.idle) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final current = recitation.current;
    final title = switch (recitation.status) {
      RecitationStatus.loading => 'جارٍ التحميل…',
      RecitationStatus.error => recitation.error ?? '',
      _ when current != null =>
        'سورة ${getSurahNameArabic(current.surah)} · الآية ${current.ayah}',
      _ => '',
    };

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.overlay,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.gold.withValues(alpha: 0.8)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Row(
        children: [
          if (recitation.status == RecitationStatus.loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else if (recitation.status == RecitationStatus.error)
            IconButton(
              tooltip: 'إعادة المحاولة',
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => startRecitation(context),
            )
          else
            IconButton(
              tooltip: recitation.status == RecitationStatus.playing
                  ? 'إيقاف مؤقت'
                  : 'تشغيل',
              icon: Icon(
                recitation.status == RecitationStatus.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
              onPressed: recitation.toggle,
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  recitation.reciter.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.gold, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إعدادات التلاوة',
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () => showRecitationSettings(context),
          ),
          IconButton(
            tooltip: 'إيقاف',
            icon: const Icon(Icons.stop_rounded, color: Colors.white),
            onPressed: recitation.stop,
          ),
        ],
      ),
    );
  }
}

Future<void> showRecitationSettings(BuildContext context) {
  Provider.of<RecitationProvider>(context, listen: false).loadReciters();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => Consumer<RecitationProvider>(
        builder: (context, recitation, _) => ListView(
          controller: controller,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              title: const Text('تكرار كل آية'),
              subtitle: const Text('مفيد للحفظ'),
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 5, label: Text('5')),
                ],
                selected: {recitation.repeat},
                onSelectionChanged: (v) => recitation.setRepeat(v.first),
                showSelectedIcon: false,
              ),
            ),
            SwitchListTile(
              title: const Text('المتابعة إلى الصفحة التالية'),
              value: recitation.continuous,
              onChanged: recitation.setContinuous,
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'القارئ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            RadioGroup<String>(
              groupValue: recitation.reciterId,
              onChanged: (id) {
                if (id != null) recitation.setReciter(id);
              },
              child: Column(
                children: [
                  for (final r in recitation.reciters)
                    RadioListTile<String>(value: r.id, title: Text(r.name)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'تحتاج التلاوة إلى اتصال بالإنترنت. المصدر: alquran.cloud',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.pageNumber,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
