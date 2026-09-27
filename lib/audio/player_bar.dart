import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../providers/quran.dart';
import '../quran/quran.dart';
import 'downloads_screen.dart';
import 'recitation.dart';

/// Starts reciting the reader's current page, from the ayah [from]
/// (surah, ayah) if given.
void startRecitation(BuildContext context, {(int, int)? from}) {
  final quran = Provider.of<Quran>(context, listen: false);
  final recitation = Provider.of<RecitationProvider>(context, listen: false);
  recitation.onPageChanged = quran.goToPage;
  recitation.playPage(quran.currentPage, from: from);
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
      RecitationStatus.loading => tr('جارٍ التحميل…', 'Loading…'),
      RecitationStatus.error => recitation.error ?? '',
      _ when current != null =>
        '${surahTitle(current.surah)} · ${ayahLabel(current.ayah)}',
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
              tooltip: tr('إعادة المحاولة', 'Retry'),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => startRecitation(context),
            )
          else
            IconButton(
              tooltip: recitation.status == RecitationStatus.playing
                  ? tr('إيقاف مؤقت', 'Pause')
                  : tr('تشغيل', 'Play'),
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
            tooltip: tr('إعدادات التلاوة', 'Recitation settings'),
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () => showRecitationSettings(context),
          ),
          IconButton(
            tooltip: tr('إيقاف', 'Stop'),
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
              title: Text(tr('تكرار كل آية', 'Repeat each ayah')),
              subtitle: Text(tr('مفيد للحفظ', 'Helpful for memorizing')),
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
              title: Text(
                tr('المتابعة إلى الصفحة التالية', 'Continue to the next page'),
              ),
              value: recitation.continuous,
              onChanged: recitation.setContinuous,
            ),
            const Divider(),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                tr('القارئ', 'Reciter'),
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
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.download_for_offline_rounded,
                color: Theme.of(context).colorScheme.gold,
              ),
              title: Text(tr('التلاوات المحفوظة', 'Saved recitations')),
              subtitle: Text(
                tr(
                  'حمّل السور للاستماع دون إنترنت',
                  'Download surahs to listen without internet',
                ),
              ),
              onTap: () => DownloadsScreen.open(context),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tr(
                  'تُبثّ التلاوة من الإنترنت ما لم تكن السورة محفوظة. المصدر: alquran.cloud',
                  'Recitation streams from the internet unless the surah is saved. Source: alquran.cloud',
                ),
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
