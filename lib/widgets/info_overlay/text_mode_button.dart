import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/index.dart';
import '../../providers/settings_provider.dart';

/// Switches the reader between page images and text.
class TextModeButton extends StatelessWidget {
  const TextModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return IconButton(
      tooltip: settings.textMode
          ? tr('عرض صفحات المصحف', 'Show mushaf pages')
          : tr('القراءة نصاً', 'Read as text'),
      icon: Icon(
        settings.textMode ? Icons.image_rounded : Icons.text_fields_rounded,
        color: Colors.white,
      ),
      onPressed: () => settings.setTextMode(!settings.textMode),
    );
  }
}
