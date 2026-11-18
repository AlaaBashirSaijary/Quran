import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import 'azkar_audio.dart';

String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

/// Listen to the azkar of a category, and save the recording on the phone.
/// Shows nothing when the category has no recording.
class AzkarAudioCard extends StatelessWidget {
  const AzkarAudioCard({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final audio = Provider.of<AzkarAudio>(context);
    final pack = audio.packFor(category);
    if (pack == null) {
      final link = audio.linkFor(category);
      return link == null ? const SizedBox.shrink() : _LinkCard(link: link);
    }
    final colorScheme = Theme.of(context).colorScheme;
    final downloaded = audio.isDownloaded(pack);
    final share = audio.progress[pack.id];
    final mine = audio.playingId == pack.id;
    final small = TextStyle(fontSize: 12.5, color: colorScheme.pageNumber, height: 1.6);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.filled(
                  tooltip: mine && audio.playing
                      ? tr('إيقاف مؤقت', 'Pause')
                      : tr('استماع', 'Listen'),
                  onPressed: () => audio.toggle(pack),
                  icon: mine && audio.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          mine && audio.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        tr('بصوت ${pack.reciter}', 'Read by ${pack.reciter}'),
                        style: small,
                      ),
                    ],
                  ),
                ),
                if (share != null)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(value: share == 0 ? null : share),
                  )
                else if (downloaded)
                  IconButton(
                    tooltip: tr('حذف من الهاتف', 'Remove from the phone'),
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => audio.delete(pack),
                  )
                else if (audio.supported)
                  IconButton(
                    tooltip: tr(
                      'تنزيل (${_mb(pack.size)} م.ب) للاستماع بلا إنترنت',
                      'Download (${_mb(pack.size)} MB) to listen offline',
                    ),
                    icon: const Icon(Icons.download_rounded),
                    onPressed: () => audio.download(pack),
                  ),
              ],
            ),
            if (downloaded)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr('محفوظ على الهاتف، يعمل بلا إنترنت', 'Saved on the phone, works offline'),
                  style: small,
                ),
              ),
            if (audio.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(audio.error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            const Divider(height: 20),
            SelectableText(
              '${tr('المصدر', 'Source')}: ${pack.source}\n${pack.sourceUrl}\n${tr('الترخيص', 'Licence')}: ${pack.license}',
              style: small,
            ),
          ],
        ),
      ),
    );
  }
}

/// A recording on another website: opens its page in the browser. If the
/// phone cannot open it, the link is copied instead.
class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.link});

  final AzkarAudioLink link;

  @override
  Widget build(BuildContext context) {
    final audio = Provider.of<AzkarAudio>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ListTile(
        leading: Icon(Icons.headphones_rounded, color: colorScheme.gold),
        title: Text(
          tr('استمع: ${link.title}', 'Listen: ${link.title}'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            tr('بصوت ${link.reciter}', 'Read by ${link.reciter}'),
            tr('على موقع IslamHouse', 'on IslamHouse'),
            if (link.hint.isNotEmpty) link.hint,
          ].join(' · '),
        ),
        trailing: const Icon(Icons.open_in_new_rounded),
        onTap: () async {
          final opened = await audio.openLink(link);
          if (opened || !context.mounted) return;
          await Clipboard.setData(ClipboardData(text: link.url));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  'تعذّر فتح المتصفح، نُسخ الرابط. الصقه في المتصفح.',
                  'The browser could not be opened. The link was copied; paste it in your browser.',
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
