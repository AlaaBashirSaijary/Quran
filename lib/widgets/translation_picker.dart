import 'package:flutter/material.dart';

import '../core/index.dart';
import '../providers/settings_provider.dart';
import '../quran/translations.dart';

/// Lists the translation languages; choosing one that is not on the phone
/// downloads it first.
Future<void> chooseTranslation(
  BuildContext context,
  SettingsProvider settings,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => _Picker(settings: settings),
);

class _Picker extends StatefulWidget {
  const _Picker({required this.settings});

  final SettingsProvider settings;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  final _downloaded = <String>{};
  String? _downloading;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final l in translationLanguages) {
      Translations.instance.isDownloaded(l.code).then((yes) {
        if (yes && mounted) setState(() => _downloaded.add(l.code));
      });
    }
  }

  Future<void> _choose(TranslationLanguage language) async {
    if (_downloading != null) return;
    if (!_downloaded.contains(language.code)) {
      setState(() {
        _downloading = language.code;
        _error = null;
      });
      try {
        await Translations.instance.download(language.code);
        _downloaded.add(language.code);
      } catch (_) {
        if (mounted) {
          setState(() {
            _downloading = null;
            _error = tr(
              'تعذّر تحميل الترجمة. تحقق من الإنترنت وحاول مرة أخرى.',
              'The translation could not be downloaded. Check your internet connection and try again.',
            );
          });
        }
        return;
      }
    }
    widget.settings.setTranslationLang(language.code);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final current = widget.settings.translationLang;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              tr(
                'الإنجليزية مضمّنة، وتُحمَّل اللغات الأخرى مرة واحدة (نحو 3 ميغابايت) ثم تعمل دون إنترنت.',
                'English is built in; other languages download once (about 3 MB) and then work offline.',
              ),
              style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: colorScheme.error)),
            ),
          for (final l in translationLanguages)
            ListTile(
              title: Text(l.name),
              subtitle: Text(l.translator),
              leading: Icon(
                l.code == current
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: colorScheme.gold,
              ),
              trailing: _downloading == l.code
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _downloaded.contains(l.code)
                  ? null
                  : const Icon(Icons.download_rounded),
              onTap: () => _choose(l),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              tr(
                'المصادر: tanzil.net والموسوعة القرآنية quranenc.com عبر حزمة quran-json.',
                'Sources: tanzil.net and quranenc.com, via the quran-json package.',
              ),
              style: TextStyle(fontSize: 11, color: colorScheme.pageNumber),
            ),
          ),
        ],
      ),
    );
  }
}
