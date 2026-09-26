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
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'حجم الخط',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'يُطبَّق على الأحاديث والأذكار والأدعية ونتائج البحث.',
                  style: TextStyle(color: colorScheme.pageNumber, fontSize: 13),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Text('أ', style: TextStyle(fontSize: 14)),
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
                    const Text('أ', style: TextStyle(fontSize: 24)),
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
            title: 'المظهر',
            children: [
              RadioGroup<ThemeMode>(
                groupValue: theme.themeMode,
                onChanged: (mode) {
                  if (mode != null) theme.setThemeMode(mode);
                },
                child: const Column(
                  children: [
                    RadioListTile(
                      value: ThemeMode.system,
                      title: Text('حسب إعداد الهاتف'),
                    ),
                    RadioListTile(value: ThemeMode.light, title: Text('فاتح')),
                    RadioListTile(value: ThemeMode.dark, title: Text('داكن')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'التاريخ الهجري',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'يُحسب بتقويم أم القرى. إن كان بدء الشهر في بلدك يختلف '
                  'بسبب رؤية الهلال فعدّله بيوم أو يومين.',
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
                      tooltip: 'يوم قبل',
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
                      tooltip: 'يوم بعد',
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
            title: 'النسخ الاحتياطي',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'يحفظ العلامات والختمة والسبحة وتقدّم الأذكار والإعدادات في '
                  'ملف، لنقلها إلى هاتف آخر أو استعادتها بعد إعادة التثبيت.',
                  style: TextStyle(color: colorScheme.pageNumber, fontSize: 13),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text('حفظ نسخة احتياطية'),
                onTap: () => _export(context),
              ),
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: const Text('استعادة من نسخة احتياطية'),
                onTap: () => _import(context),
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
        'tareeq-aljannah-${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}.json';
    try {
      final bytes = utf8.encode(exportBackup(prefs, now: now));
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, name: name, mimeType: 'application/json'),
          ],
          fileNameOverrides: [name],
          subject: 'نسخة احتياطية من طريق الجنة',
        ),
      );
    } catch (_) {
      if (context.mounted) {
        _message(context, 'تعذّر إنشاء النسخة الاحتياطية.');
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
        title: const Text('استعادة النسخة الاحتياطية؟'),
        content: const Text(
          'ستحلّ بيانات النسخة الاحتياطية محلّ البيانات الحالية في التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppConstant.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('استعادة'),
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
      if (context.mounted) _message(context, 'تعذّر قراءة الملف.');
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
