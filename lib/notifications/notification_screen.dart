import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../prayer/prayer.dart';
import '../providers/reading_provider.dart';
import '../widget/prayer_widget.dart';
import 'notification_service.dart';
import 'notification_settings.dart';
import 'planner.dart';

/// Keeps the scheduled reminders in step with the prayer times, the
/// reminder choices and today's wird, and the home-screen widget in step
/// with the prayer times. Place once near the app root.
class NotificationSync extends StatefulWidget {
  const NotificationSync({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends State<NotificationSync> {
  String? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prayer = Provider.of<PrayerProvider>(context);
    final settings = Provider.of<NotificationSettings>(context);
    final reading = Provider.of<ReadingProvider>(context);
    final now = DateTime.now();
    final signature = [
      prayer.coordinates?.latitude,
      prayer.coordinates?.longitude,
      prayer.methodId,
      prayer.hanafiAsr,
      settings.signature,
      reading.goalMet,
      ReadingProvider.dayKey(now),
    ].join('|');
    if (signature == _last) return;
    _last = signature;
    updatePrayerWidget(prayer, now);
    if (!NotificationService.supported) return;
    NotificationService.instance.schedule(
      planNotifications(
        prayer: prayer,
        settings: settings,
        now: now,
        wirdDoneToday: reading.goalMet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _exact = true;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.requestPermission();
    _checkExact();
  }

  Future<void> _checkExact() async {
    final exact = await NotificationService.instance.canUseExactTimes();
    if (mounted) setState(() => _exact = exact);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<NotificationSettings>(context);
    final prayer = Provider.of<PrayerProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final names = {
      for (final t
          in prayer.hasLocation
              ? prayer.timesOn(DateTime.now())
              : <PrayerTime>[])
        t.prayer: t.name,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('التنبيهات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!NotificationService.supported)
            _Note(
              icon: Icons.info_outline_rounded,
              text: 'التنبيهات تعمل على تطبيق الهاتف فقط.',
            ),
          if (!prayer.hasLocation)
            _Note(
              icon: Icons.location_off_rounded,
              text:
                  'اختر مدينتك في تبويب الصلاة لتفعيل تنبيهات الصلاة والأذكار.',
            ),
          if (!_exact)
            _Note(
              icon: Icons.alarm_off_rounded,
              text:
                  'قد تتأخر التنبيهات بضع دقائق. اسمح للتطبيق بضبط المنبّهات '
                  'بدقة ليصلك التنبيه في وقته تماماً.',
              action: TextButton(
                onPressed: () async {
                  await NotificationService.instance.requestExactTimes();
                  _checkExact();
                },
                child: const Text('السماح'),
              ),
            ),
          Card(
            child: Column(
              children: [
                const _Header('تنبيه دخول وقت الصلاة'),
                for (final p in NotificationSettings.prayers)
                  SwitchListTile(
                    title: Text(names[p] ?? _fallbackName(p.name)),
                    value: settings.prayerEnabled(p),
                    onChanged: (v) => settings.setPrayer(p, v),
                  ),
                ListTile(
                  title: const Text('تذكير قبل الصلاة'),
                  trailing: DropdownButton<int>(
                    value: settings.minutesBefore,
                    underline: const SizedBox(),
                    items: [
                      for (final m in NotificationSettings.beforeOptions)
                        DropdownMenuItem(
                          value: m,
                          child: Text(m == 0 ? 'بدون' : minutesLabel(m)),
                        ),
                    ],
                    onChanged: (m) {
                      if (m != null) settings.setMinutesBefore(m);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                const _Header('الأذكار والورد'),
                SwitchListTile(
                  title: const Text('أذكار الصباح'),
                  subtitle: const Text('بعد الفجر بعشرين دقيقة'),
                  value: settings.morningAzkar,
                  onChanged: settings.setMorningAzkar,
                ),
                SwitchListTile(
                  title: const Text('أذكار المساء'),
                  subtitle: const Text('بعد العصر بعشرين دقيقة'),
                  value: settings.eveningAzkar,
                  onChanged: settings.setEveningAzkar,
                ),
                SwitchListTile(
                  title: const Text('تذكير بالورد'),
                  subtitle: const Text('لا يظهر إذا أتممت وردك'),
                  value: settings.wird,
                  onChanged: settings.setWird,
                ),
                ListTile(
                  enabled: settings.wird,
                  title: const Text('وقت تذكير الورد'),
                  trailing: Text(
                    _clock(settings.wirdMinutes),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: settings.wirdMinutes ~/ 60,
                        minute: settings.wirdMinutes % 60,
                      ),
                    );
                    if (picked != null) {
                      settings.setWirdMinutes(picked.hour * 60 + picked.minute);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'تُجدول التنبيهات لأسبوع قادم وتتجدد كلما فتحت التطبيق. بعض الهواتف '
            '(مثل شاومي وهواوي) توقف تنبيهات التطبيقات في الخلفية لتوفير '
            'البطارية؛ إن لم تصلك التنبيهات فاستثنِ التطبيق من توفير البطارية.',
            style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
          ),
        ],
      ),
    );
  }

  static String _fallbackName(String name) => switch (name) {
    'fajr' => 'الفجر',
    'dhuhr' => 'الظهر',
    'asr' => 'العصر',
    'maghrib' => 'المغرب',
    _ => 'العشاء',
  };

  static String _clock(int minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).toString().padLeft(2, '0');
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m ${h < 12 ? 'ص' : 'م'}';
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.secondaryFontFamily,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.gold.withValues(alpha: 0.12),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.gold),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            ?action,
          ],
        ),
      ),
    );
  }
}
