import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import 'recordings.dart';

String _clock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
}

/// "My recordings": record your voice, listen back, rename, delete, and
/// send a recording to other apps.
class RecordingsScreen extends StatelessWidget {
  const RecordingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recordings = Provider.of<Recordings>(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('تسجيلاتي', 'My recordings'))),
      body: Column(
        children: [
          _RecordPanel(recordings: recordings),
          const Divider(height: 1),
          Expanded(
            child: recordings.items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        tr(
                          'لا تسجيلات بعد. اضغط الزر وسجّل تلاوتك أو ما تريد، ثم استمع إليه أو شاركه.',
                          'No recordings yet. Press the button and record your recitation or anything else, then listen or share it.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.pageNumber, height: 1.7),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [for (final r in recordings.items) _RecordingTile(recording: r)],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.recordings});

  final Recordings recordings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final on = recordings.recording;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            _clock(recordings.elapsed),
            style: const TextStyle(fontSize: 40, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: !recordings.supported
                ? null
                : () async {
                    if (on) {
                      final r = await recordings.stop();
                      if (r == null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr('التسجيل قصير جداً فلم يُحفظ', 'Too short, not saved'))),
                        );
                      }
                    } else {
                      await recordings.start();
                    }
                  },
            child: Semantics(
              button: true,
              label: on ? tr('أوقف التسجيل', 'Stop recording') : tr('ابدأ التسجيل', 'Start recording'),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? Colors.red : colorScheme.gold,
                ),
                child: Icon(on ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            on ? tr('جارٍ التسجيل… اضغط للإيقاف', 'Recording… press to stop') : tr('اضغط للتسجيل', 'Press to record'),
            style: TextStyle(color: colorScheme.pageNumber),
          ),
          if (recordings.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(recordings.error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.recording});

  final Recording recording;

  Future<void> _rename(BuildContext context, Recordings recordings) async {
    final box = TextEditingController(text: recording.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('اسم التسجيل', 'Recording name')),
        content: TextField(controller: box, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('إلغاء', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, box.text), child: Text(tr('حفظ', 'Save'))),
        ],
      ),
    );
    if (title != null) await recordings.rename(recording, title);
  }

  Future<void> _delete(BuildContext context, Recordings recordings) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(tr('حذف هذا التسجيل؟', 'Delete this recording?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('حذف', 'Delete'))),
        ],
      ),
    );
    if (ok == true) await recordings.delete(recording);
  }

  @override
  Widget build(BuildContext context) {
    final recordings = Provider.of<Recordings>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final here = recordings.playingFile == recording.file;
    final playing = here && recordings.playing;
    return ListTile(
      leading: IconButton.filledTonal(
        tooltip: playing ? tr('إيقاف مؤقت', 'Pause') : tr('تشغيل', 'Play'),
        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
        onPressed: () => recordings.toggle(recording),
      ),
      title: Text(recording.title),
      subtitle: Text(_clock(recording.length), style: TextStyle(color: colorScheme.pageNumber)),
      onTap: () => _rename(context, recordings),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: tr('مشاركة', 'Share'),
            icon: const Icon(Icons.share_rounded),
            onPressed: () async {
              final ok = await recordings.share(recording);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('تعذّرت المشاركة', 'Could not share'))),
                );
              }
            },
          ),
          IconButton(
            tooltip: tr('حذف', 'Delete'),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(context, recordings),
          ),
        ],
      ),
    );
  }
}
