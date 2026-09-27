import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/index.dart';
import 'notification_settings.dart';

/// The phone's own sounds (MainActivity.kt): the system picker, and adding
/// an audio file to the notification sounds.
class PhoneSounds {
  static const _channel = MethodChannel('tareeq/sounds');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The chosen sound's URI, or null if cancelled.
  static Future<String?> pick({String? current}) =>
      _channel.invokeMethod<String>('pick', {'current': current});

  /// Adds the audio file at [path] to the notification sounds and returns
  /// its URI. Needs Android 10 or later.
  static Future<String?> import(String path, String name) =>
      _channel.invokeMethod<String>('import', {'path': path, 'name': name});

  static Future<String?> title(String uri) async {
    try {
      return await _channel.invokeMethod<String>('title', {'uri': uri});
    } catch (_) {
      return null;
    }
  }
}

/// A stable short hash, used to name the notification channel of a sound
/// (Android fixes a channel's sound when the channel is created).
String soundKey(String uri) {
  var hash = 0x811c9dc5;
  for (final unit in uri.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16);
}

/// Lets the user choose the sound of prayer-time notifications.
Future<void> chooseAdhanSound(
  BuildContext context,
  NotificationSettings settings,
) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.library_music_rounded),
            title: Text(
              tr('اختيار من أصوات الهاتف', 'Choose from phone sounds'),
            ),
            subtitle: Text(
              tr(
                'يظهر فيها أي أذان أضفته إلى أصوات الإشعارات',
                'Includes any adhan you added to the notification sounds',
              ),
            ),
            onTap: () => Navigator.pop(sheet, 'pick'),
          ),
          ListTile(
            leading: const Icon(Icons.audio_file_rounded),
            title: Text(tr('استيراد ملف صوتي', 'Import an audio file')),
            subtitle: Text(
              tr(
                'مثل ملف أذان حمّلته (أندرويد 10 فما فوق)',
                'Such as an adhan you downloaded (Android 10 or later)',
              ),
            ),
            onTap: () => Navigator.pop(sheet, 'import'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_rounded),
            title: Text(
              tr('صوت التنبيه الافتراضي', 'Default notification sound'),
            ),
            onTap: () => Navigator.pop(sheet, 'default'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  void fail(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  try {
    switch (choice) {
      case 'default':
        settings.setAdhanSound(null, null);
      case 'pick':
        final uri = await PhoneSounds.pick(current: settings.adhanUri);
        if (uri != null) {
          settings.setAdhanSound(uri, await PhoneSounds.title(uri));
        }
      case 'import':
        final files = await FilePicker.pickFiles(type: FileType.audio);
        final file = files.firstOrNull;
        final path = file?.path;
        if (file == null || path == null) return;
        final uri = await PhoneSounds.import(path, file.name);
        if (uri != null) {
          settings.setAdhanSound(
            uri,
            file.name.replaceAll(RegExp(r'\.\w+$'), ''),
          );
        }
    }
  } on PlatformException catch (e) {
    fail(
      e.code == 'unsupported'
          ? tr(
              'الاستيراد يحتاج أندرويد 10. أضف الملف إلى أصوات الإشعارات ثم اختره من أصوات الهاتف.',
              'Importing needs Android 10. Add the file to your notification sounds, then choose it from phone sounds.',
            )
          : tr('تعذّر اختيار الصوت.', 'Could not set the sound.'),
    );
  }
}
