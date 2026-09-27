import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../quran/translation.dart';

/// The English meaning of [ayahs] (surah, ayah) when the reader has turned
/// the translation on; nothing otherwise.
class TranslationText extends StatelessWidget {
  const TranslationText({super.key, required this.ayahs});

  final List<(int, int)> ayahs;

  @override
  Widget build(BuildContext context) {
    final bool show;
    try {
      show = Provider.of<SettingsProvider>(context).showTranslation;
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    if (!show || ayahs.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<Translation>(
      future: Translation.load(),
      initialData: Translation.loaded,
      builder: (context, snapshot) {
        final translation = snapshot.data;
        if (translation == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            [
              for (final (s, a) in ayahs)
                ayahs.length > 1
                    ? '($a) ${translation.of(s, a)}'
                    : translation.of(s, a),
            ].join(' '),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: context.contentSize(15),
              height: 1.6,
              color: colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        );
      },
    );
  }
}
