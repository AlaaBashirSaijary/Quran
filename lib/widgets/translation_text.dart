import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../quran/translation.dart';
import '../quran/translations.dart';

/// The English meaning of [ayahs] (surah, ayah) when the reader has turned
/// the translation on; nothing otherwise.
class TranslationText extends StatelessWidget {
  const TranslationText({super.key, required this.ayahs});

  final List<(int, int)> ayahs;

  @override
  Widget build(BuildContext context) {
    final bool show;
    final String code;
    try {
      final settings = Provider.of<SettingsProvider>(context);
      show = settings.showTranslation;
      code = settings.translationLang;
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final language = translationLanguage(code);
    if (!show || ayahs.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<Translation?>(
      future: Translations.instance.load(language.code),
      initialData: Translations.instance.loaded(language.code),
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
            textDirection: language.direction,
            textAlign: TextAlign.start,
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
