import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../prayer/prayer.dart';
import '../providers/reading_provider.dart';
import '../providers/settings_provider.dart';
import '../widget/prayer_widget.dart';
import 'adhan_sound.dart';
import 'notification_service.dart';
import 'notification_settings.dart';
import 'planner.dart';
import '../quran/quran.dart';
import '../screens/index_screen.dart';

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
  void initState() {
    super.initState();
    if (!NotificationService.supported) return;
    final opened = NotificationService.instance.opened;
    opened.addListener(_onOpened);
    NotificationService.instance.start().then((_) => _onOpened());
  }

  @override
  void dispose() {
    NotificationService.instance.opened.removeListener(_onOpened);
    super.dispose();
  }

  /// Follows a tapped notification to what it points at.
  void _onOpened() {
    final opened = NotificationService.instance.opened;
    if (!mounted || opened.value == null) return;
    if (opened.value == openKahfPayload) {
      openQuranPage(context, getSurahFirstPage(18), isTab: true);
    }
    opened.value = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prayer = Provider.of<PrayerProvider>(context);
    final settings = Provider.of<NotificationSettings>(context);
    final reading = Provider.of<ReadingProvider>(context);
    final hijriOffset = Provider.of<SettingsProvider>(context).hijriOffset;
    final now = DateTime.now();
    final signature = [
      prayer.coordinates?.latitude,
      prayer.coordinates?.longitude,
      prayer.methodId,
      prayer.hanafiAsr,
      settings.signature,
      reading.goalMet,
      ReadingProvider.dayKey(now),
      hijriOffset,
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
        hijriOffset: hijriOffset,
      ),
      adhanUri: settings.adhanUri,
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
      appBar: AppBar(title: Text(tr('التنبيهات', 'Notifications'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!NotificationService.supported)
            _Note(
              icon: Icons.info_outline_rounded,
              text: tr(
                'التنبيهات تعمل على تطبيق الهاتف فقط.',
                'Notifications work in the phone app only.',
              ),
            ),
          if (!prayer.hasLocation)
            _Note(
              icon: Icons.location_off_rounded,
              text: tr(
                'اختر مدينتك في تبويب الصلاة لتفعيل تنبيهات الصلاة والأذكار.',
                'Choose your city in the Prayer tab to turn on prayer and azkar reminders.',
              ),
            ),
          if (!_exact)
            _Note(
              icon: Icons.alarm_off_rounded,
              text: tr(
                'قد تتأخر التنبيهات بضع دقائق. اسمح للتطبيق بضبط المنبّهات '
                    'بدقة ليصلك التنبيه في وقته تماماً.',
                'Reminders may arrive a few minutes late. Allow the app to set exact alarms so they arrive right on time.',
              ),
              action: TextButton(
                onPressed: () async {
                  await NotificationService.instance.requestExactTimes();
                  _checkExact();
                },
                child: Text(tr('السماح', 'Allow')),
              ),
            ),
          Card(
            child: Column(
              children: [
                _Header(
                  tr('تنبيه دخول وقت الصلاة', 'When the prayer time begins'),
                ),
                for (final p in NotificationSettings.prayers)
                  SwitchListTile(
                    title: Text(names[p] ?? _fallbackName(p.name)),
                    value: settings.prayerEnabled(p),
                    onChanged: (v) => settings.setPrayer(p, v),
                  ),
                if (PhoneSounds.supported)
                  ListTile(
                    leading: Icon(
                      Icons.volume_up_rounded,
                      color: colorScheme.gold,
                    ),
                    title: Text(tr('صوت الأذان', 'Adhan sound')),
                    subtitle: Text(
                      settings.adhanUri == null
                          ? tr(
                              'صوت التنبيه الافتراضي',
                              'Default notification sound',
                            )
                          : (settings.adhanTitle?.isNotEmpty ?? false)
                          ? settings.adhanTitle!
                          : tr('صوت مختار', 'Chosen sound'),
                    ),
                    trailing: Icon(
                      Icons.chevron_left_rounded,
                      color: colorScheme.gold,
                    ),
                    onTap: () => chooseAdhanSound(context, settings),
                  ),
                ListTile(
                  title: Text(
                    tr('تذكير قبل الصلاة', 'Reminder before the prayer'),
                  ),
                  trailing: DropdownButton<int>(
                    value: settings.minutesBefore,
                    underline: const SizedBox(),
                    items: [
                      for (final m in NotificationSettings.beforeOptions)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            m == 0 ? tr('بدون', 'None') : minutesLabel(m),
                          ),
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
                _Header(tr('الأذكار والورد', 'Azkar and daily reading')),
                SwitchListTile(
                  title: Text(tr('أذكار الصباح', 'Morning azkar')),
                  subtitle: Text(
                    tr('بعد الفجر بعشرين دقيقة', 'Twenty minutes after Fajr'),
                  ),
                  value: settings.morningAzkar,
                  onChanged: settings.setMorningAzkar,
                ),
                SwitchListTile(
                  title: Text(tr('أذكار المساء', 'Evening azkar')),
                  subtitle: Text(
                    tr('بعد العصر بعشرين دقيقة', 'Twenty minutes after Asr'),
                  ),
                  value: settings.eveningAzkar,
                  onChanged: settings.setEveningAzkar,
                ),
                SwitchListTile(
                  title: Text(tr('السحور في رمضان', 'Suhoor in Ramadan')),
                  subtitle: Text(
                    tr(
                      'قبل الفجر بخمس وأربعين دقيقة',
                      'Forty-five minutes before Fajr',
                    ),
                  ),
                  value: settings.suhoor,
                  onChanged: settings.setSuhoor,
                ),
                SwitchListTile(
                  title: Text(tr('يوم الجمعة', 'Friday')),
                  subtitle: Text(
                    tr(
                      'سورة الكهف صباحاً، والدعاء في آخر ساعة قبل المغرب',
                      'Al-Kahf in the morning, du‘a in the last hour before Maghrib',
                    ),
                  ),
                  value: settings.friday,
                  onChanged: settings.setFriday,
                ),
                SwitchListTile(
                  title: Text(tr('تذكير بالورد', 'Daily reading reminder')),
                  subtitle: Text(
                    tr(
                      'لا يظهر إذا أتممت وردك',
                      'Not shown once you finish your daily reading',
                    ),
                  ),
                  value: settings.wird,
                  onChanged: settings.setWird,
                ),
                ListTile(
                  enabled: settings.wird,
                  title: Text(tr('وقت تذكير الورد', 'Reading reminder time')),
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
            tr(
              'تُجدول التنبيهات لأسبوع قادم وتتجدد كلما فتحت التطبيق. بعض الهواتف '
                  '(مثل شاومي وهواوي) توقف تنبيهات التطبيقات في الخلفية لتوفير '
                  'البطارية؛ إن لم تصلك التنبيهات فاستثنِ التطبيق من توفير البطارية.',
              'Reminders are scheduled a week ahead and renewed whenever you open the app. Some phones (such as Xiaomi and Huawei) stop background notifications to save battery; if reminders do not arrive, exclude the app from battery saving.',
            ),
            style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
          ),
        ],
      ),
    );
  }

  static String _fallbackName(String name) => switch (name) {
    'fajr' => tr('الفجر', 'Fajr'),
    'dhuhr' => tr('الظهر', 'Dhuhr'),
    'asr' => tr('العصر', 'Asr'),
    'maghrib' => tr('المغرب', 'Maghrib'),
    _ => tr('العشاء', 'Isha'),
  };

  static String _clock(int minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).toString().padLeft(2, '0');
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m ${h < 12 ? tr('ص', 'AM') : tr('م', 'PM')}';
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
