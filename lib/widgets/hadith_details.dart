import 'package:flutter/material.dart';

import '../core/index.dart';
import '../model/hadith_model.dart';
import '../providers/settings_provider.dart';
import '../share/share_card.dart';

class HadithDetails extends StatelessWidget {
  const HadithDetails({super.key, required this.hadith});

  final HadithModel hadith;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(hadith.title),
        actions: [
          IconButton(
            tooltip: tr('مشاركة كصورة', 'Share as image'),
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => shareAsImage(
              context,
              text: hadith.content.join('\n'),
              reference: 'الأربعون النووية · ${hadith.title}',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    color: colorScheme.gold,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  for (final line in hadith.content)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        line,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: context.contentSize(19),
                          height: 1.9,
                          fontWeight: FontWeight.w400,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
