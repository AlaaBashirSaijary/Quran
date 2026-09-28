import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/index.dart';
import '../hijri/hijri.dart';
import '../main.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../settings/backup.dart';
import 'error_log_screen.dart';
import '../quran/translations.dart';
import '../widgets/translation_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr('الإعدادات', 'Settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            // In both languages, so it can be found whichever is chosen.
            title: 'اللغة · Language',
            children: [
              RadioGroup<AppLanguage>(
                groupValue: settings.language,
                onChanged: (language) async {
                  if (language == null || language == settings.language) {
                    return;
                  }
                  await settings.setLanguage(language);
                  if (context.mounted) AppRoot.restart(context);
                },
                child: Column(
                  children: [
                    for (final language in AppLanguage.values)
                      RadioListTile(
                        value: language,
                        title: Text(language.label),
                      ),
                  ],
                ),
              ),
              SwitchListTile(
                title: Text(
                  tr('ترجمة معاني القرآن', 'Translation of the meanings'),
                ),
                subtitle: Text(
                  tr(
                    'في التفسير ونتائج البحث وعند الضغط على آية',
                    'In tafsir, search results and the ayah actions',
                  ),
                ),
                value: settings.showTranslation,
                onChanged: settings.setShowTranslation,
              ),
              ListTile(
                enabled: settings.showTranslation,
                leading: const Icon(Icons.translate_rounded),
                title: Text(tr('لغة الترجمة', 'Translation language')),
                subtitle: FutureBuilder<bool>(
                  future: Translations.instance.isDownloaded(
                    settings.translationLang,
                  ),
                  builder: (context, snapshot) => Text(
                    '${translationLanguage(settings.translationLang).name} · '
                    '${translationLanguage(settings.translationLang).translator}'
                    '${snapshot.data == false ? tr(' · غير محمّلة على هذا الهاتف، تُعرض الإنجليزية', ' · not on this phone, English is shown') : ''}',
                  ),
                ),
                onTap: () => chooseTranslation(context, settings),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  tr(
                    'القرآن والأحاديث والأذكار تبقى بالعربية.',
                    'The Quran, hadith and azkar stay in Arabic.',
                  ),
                  style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: tr('حجم الخط', 'Text size'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  tr(
                    'يُطبَّق على الأحاديث والأذكار والأدعية ونتائج البحث.',
                    'Applies to hadith, azkar, du‘as and search results.',
                  ),
                  style: TextStyle(color: colorScheme.pageNumber, fontSize: 13),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(tr('أ', 'A'), style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Slider(
                        value: SettingsProvider.scales
                            .indexOf(settings.textScale)
                            .clamp(0, SettingsProvider.scales.length - 1)
                            .toDouble(),
                        min: 0,
                        max: SettingsProvider.scales.length - 1.0,
                        divisions: SettingsProvider.scales.length - 1,
                        activeColor: colorScheme.gold,
                        onChanged: (i) => settings.setTextScale(
                          SettingsProvider.scales[i.round()],
                        ),
                      ),
                    ),
                    Text(tr('أ', 'A'), style: TextStyle(fontSize: 24)),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.div),
                ),
                child: Text(
                  'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: context.contentSize(19)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: tr('المظهر', 'Appearance'),
            children: [
              RadioGroup<ThemeMode>(
                groupValue: theme.themeMode,
                onChanged: (mode) {
                  if (mode != null) theme.setThemeMode(mode);
                },
                child: Column(
                  children: [
                    RadioListTile(
                      value: ThemeMode.system,
                      title: Text(tr('حسب إعداد الهاتف', 'Follow the phone')),
                    ),
                    RadioListTile(
                      value: ThemeMode.light,
                      title: Text(tr('فاتح', 'Light')),
                    ),
                    RadioListTile(
                      value: ThemeMode.dark,
                      title: Text(tr('داكن', 'Dark')),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: tr('التاريخ الهجري', 'Hijri date'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  tr(
                    'يُحسب بتقويم أم القرى. إن كان بدء الشهر في بلدك يختلف '
                        'بسبب رؤية الهلال فعدّله بيوم أو يومين.',
                    'Calculated with the Umm al-Qura calendar. If the month begins on a different day where you live because of moon sighting, adjust it by a day or two.',
                  ),
                  style: TextStyle(color: colorScheme.pageNumber, fontSize: 13),
                ),
              ),
              ListTile(
                title: Text(
                  hijriOf(
                    DateTime.now(),
                    offset: settings.hijriOffset,
                  ).toString(),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: tr('يوم قبل', 'A day earlier'),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      onPressed: settings.hijriOffset > -2
                          ? () => settings.setHijriOffset(
                              settings.hijriOffset - 1,
                            )
                          : null,
                    ),
                    Text(
                      settings.hijriOffset == 0
                          ? '0'
                          : settings.hijriOffset > 0
                          ? '+${settings.hijriOffset}'
                          : '${settings.hijriOffset}',
                    ),
                    IconButton(
                      tooltip: tr('يوم بعد', 'A day later'),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: settings.hijriOffset < 2
                          ? () => settings.setHijriOffset(
                              settings.hijriOffset + 1,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: tr('النسخ الاحتياطي', 'Backup'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  tr(
                    'يحفظ العلامات والختمة والسبحة وتقدّم الأذكار والإعدادات في '
                        'ملف، لنقلها إلى هاتف آخر أو استعادتها بعد إعادة التثبيت.',
                    'Saves your bookmarks, khatma, tasbeeh, azkar progress and settings to a file, to move them to another phone or restore them after reinstalling.',
                  ),
                  style: TextStyle(color: colorScheme.pageNumber, fontSize: 13),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: Text(tr('حفظ نسخة احتياطية', 'Save a backup')),
                onTap: () => _export(context),
              ),
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: Text(
                  tr('استعادة من نسخة احتياطية', 'Restore from a backup'),
                ),
                onTap: () => _import(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: tr('الخصوصية', 'Privacy'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  tr(
                    'لا يجمع التطبيق أي بيانات شخصية ولا يحتوي إعلانات أو تتبّعاً. '
                        'بياناتك تبقى على هاتفك، ويُستخدم موقعك على الهاتف فقط لحساب '
                        'المواقيت والقبلة. الإنترنت للتلاوة فقط (alquran.cloud).',
                    'The app collects no personal data and has no ads or tracking. '
                        'Your data stays on your phone, and your location is used on '
                        'the phone only, for prayer times and the qibla. The internet '
                        'is used only for recitations (alquran.cloud).',
                  ),
                  style: TextStyle(color: colorScheme.pageNumber, fontSize: 13),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(tr('سجل الأخطاء', 'Error log')),
                subtitle: Text(
                  tr(
                    'لمشاركته مع المطوّر عند حدوث مشكلة',
                    'To share with the developer if something goes wrong',
                  ),
                ),
                onTap: () => ErrorLogScreen.open(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final name =
        'manhaj-hayah-${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}.json';
    try {
      final bytes = utf8.encode(exportBackup(prefs, now: now));
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, name: name, mimeType: 'application/json'),
          ],
          fileNameOverrides: [name],
          subject: tr('نسخة احتياطية من منهج حياة', 'Manhaj Hayah backup'),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        _message(
          context,
          tr('تعذّر إنشاء النسخة الاحتياطية.', 'Could not create the backup.'),
        );
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('استعادة النسخة الاحتياطية؟', 'Restore the backup?')),
        content: Text(
          tr(
            'ستحلّ بيانات النسخة الاحتياطية محلّ البيانات الحالية في التطبيق.',
            'The backup will replace the app’s current data.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppConstant.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('استعادة', 'Restore')),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      final json = utf8.decode(await files.first.readAsBytes());
      final prefs = await SharedPreferences.getInstance();
      await importBackup(prefs, json);
      if (context.mounted) AppRoot.restart(context);
    } on BackupException catch (e) {
      if (context.mounted) _message(context, e.message);
    } catch (_) {
      if (context.mounted) {
        _message(context, tr('تعذّر قراءة الملف.', 'Could not read the file.'));
      }
    }
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppTheme.secondaryFontFamily,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
