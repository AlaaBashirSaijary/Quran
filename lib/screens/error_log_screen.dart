import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/error_log.dart';
import '../core/index.dart';

/// Errors recorded on this phone, to share with the developer.
class ErrorLogScreen extends StatefulWidget {
  const ErrorLogScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ErrorLogScreen()),
    );
  }

  @override
  State<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

class _ErrorLogScreenState extends State<ErrorLogScreen> {
  @override
  Widget build(BuildContext context) {
    final log = ErrorLog.instance;
    final entries = log?.entries.reversed.toList() ?? const <String>[];
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('سجل الأخطاء', 'Error Log')),
        actions: [
          if (entries.isNotEmpty) ...[
            IconButton(
              tooltip: tr('مشاركة', 'Share'),
              icon: const Icon(Icons.share_rounded),
              onPressed: () =>
                  SharePlus.instance.share(ShareParams(text: log!.report())),
            ),
            IconButton(
              tooltip: tr('مسح', 'Clear'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                log!.clear();
                setState(() {});
              },
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr(
              'يحفظ التطبيق هنا الأخطاء التي تحدث، على هاتفك فقط ولا يُرسل شيئاً. '
                  'إن واجهت مشكلة فشارك هذا السجل مع المطوّرة لتصلحها.',
              'The app keeps any errors here, on your phone only; nothing is '
                  'sent. If something goes wrong, share this log with the '
                  'developer so it can be fixed.',
            ),
            style: TextStyle(color: colorScheme.pageNumber, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: colorScheme.gold,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(tr('لا أخطاء مسجّلة', 'No errors recorded')),
                ],
              ),
            )
          else
            for (final entry in entries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    entry,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
