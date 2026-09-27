import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../quran/quran.dart';
import 'downloads.dart';
import 'recitation.dart';

/// Download surahs for the chosen reciter to listen without internet.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DownloadsScreen()),
    );
  }

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late Future<int> _size;
  bool _wasBusy = false;

  @override
  void initState() {
    super.initState();
    _size = context.read<AudioDownloads>().size();
  }

  void _refreshSize() =>
      setState(() => _size = context.read<AudioDownloads>().size());

  @override
  Widget build(BuildContext context) {
    final downloads = Provider.of<AudioDownloads>(context);
    final recitation = Provider.of<RecitationProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final reciter = recitation.reciterId;
    final saved = downloads.downloadedSurahs(reciter);

    // Update the used space once a batch finishes.
    final busy = downloads.progress.isNotEmpty;
    if (_wasBusy && !busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSize());
    }
    _wasBusy = busy;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('التلاوات المحفوظة', 'Saved Recitations')),
        actions: [
          if (downloads.supported)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'juzAmma') {
                  downloads.download(reciter, [
                    for (var s = 78; s <= 114; s++) s,
                  ]);
                } else if (v == 'all') {
                  downloads.download(reciter, [
                    for (var s = 1; s <= 114; s++) s,
                  ]);
                } else if (v == 'delete' && await _confirmDeleteAll(context)) {
                  await downloads.deleteAll();
                  _refreshSize();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'juzAmma',
                  child: Text(tr('تحميل جزء عمّ', 'Download Juz ‘Amma')),
                ),
                PopupMenuItem(
                  value: 'all',
                  child: Text(
                    tr('تحميل القرآن كاملاً', 'Download the whole Quran'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(tr('حذف كل التلاوات', 'Delete all recitations')),
                ),
              ],
            ),
        ],
      ),
      body: !downloads.supported
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    'التحميل متاح في تطبيق الهاتف فقط.',
                    'Downloads are available in the phone app only.',
                  ),
                ),
              ),
            )
          : ListView.builder(
              itemCount: 115,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _Header(
                    reciter: recitation.reciter.name,
                    saved: saved.length,
                    size: _size,
                    error: downloads.error,
                  );
                }
                final surah = i;
                final progress = downloads.progress[(reciter, surah)];
                final done = saved.contains(surah);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: done
                        ? colorScheme.gold
                        : colorScheme.primary.withValues(alpha: 0.12),
                    foregroundColor: done
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
                    child: Text('$surah', style: const TextStyle(fontSize: 13)),
                  ),
                  title: Text(surahTitle(surah)),
                  subtitle: Text(
                    tr(
                      '${getNumberOfAyahs(surah)} آية',
                      '${getNumberOfAyahs(surah)} ayahs',
                    ),
                  ),
                  trailing: progress != null
                      ? IconButton(
                          tooltip: tr('إلغاء', 'Cancel'),
                          onPressed: () => downloads.cancel(reciter, surah),
                          icon: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress == 0 ? null : progress,
                                strokeWidth: 3,
                                color: colorScheme.gold,
                              ),
                              const Icon(Icons.close_rounded, size: 16),
                            ],
                          ),
                        )
                      : done
                      ? IconButton(
                          tooltip: tr('حذف', 'Delete'),
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            await downloads.delete(reciter, surah);
                            _refreshSize();
                          },
                        )
                      : IconButton(
                          tooltip: tr('تحميل', 'Download'),
                          icon: Icon(
                            Icons.download_rounded,
                            color: colorScheme.primary,
                          ),
                          onPressed: () => downloads.download(reciter, [surah]),
                        ),
                );
              },
            ),
    );
  }

  Future<bool> _confirmDeleteAll(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('حذف كل التلاوات؟', 'Delete all recitations?')),
          content: Text(
            tr(
              'تُحذف التلاوات المحفوظة لكل القرّاء.',
              'Saved recitations of every reciter will be deleted.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppConstant.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('حذف', 'Delete')),
            ),
          ],
        ),
      ) ??
      false;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.reciter,
    required this.saved,
    required this.size,
    required this.error,
  });

  final String reciter;
  final int saved;
  final Future<int> size;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.headphones_rounded, color: colorScheme.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reciter,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: size,
              builder: (context, snapshot) => Text(
                tr(
                  'المحفوظ: $saved من 114 سورة · ${formatSize(snapshot.data ?? 0)}',
                  'Saved: $saved of 114 surahs · ${formatSize(snapshot.data ?? 0)}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'تُحفظ السور للقارئ المختار في إعدادات التلاوة وتُشغَّل دون إنترنت. القرآن كاملاً يأخذ مئات الميغابايتات، فابدأ بالسور التي تحتاجها.',
                'Surahs are saved for the reciter chosen in the recitation settings and play without internet. The whole Quran takes hundreds of megabytes, so start with the surahs you need.',
              ),
              style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: TextStyle(color: colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

/// "12.3 MB".
String formatSize(int bytes) {
  const mb = 1024 * 1024;
  if (bytes < mb) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * mb)).toStringAsFixed(2)} GB';
}
