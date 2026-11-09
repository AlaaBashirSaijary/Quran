import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../notifications/notification_settings.dart';
import '../prayer/prayer.dart';
import 'prayer_lock.dart';

/// "Prayer lock": at the times of the prayers the user chooses, the social
/// apps they choose stay closed until they say they have prayed and read
/// the azkar. Off by default; the user turns it on and can turn it off.
class PrayerLockScreen extends StatefulWidget {
  const PrayerLockScreen({super.key});

  @override
  State<PrayerLockScreen> createState() => _PrayerLockScreenState();
}

class _PrayerLockScreenState extends State<PrayerLockScreen>
    with WidgetsBindingObserver {
  LockStatus _status = const LockStatus();
  List<String>? _installed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    PrayerLockBridge.installed([for (final a in socialApps) a.package]).then((
      list,
    ) {
      if (mounted) setState(() => _installed = list);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the phone's settings: see whether the service was turned on.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Back from the phone's settings: start watching if both are given.
      PrayerLockBridge.apply().then((_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    final status = await PrayerLockBridge.status();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _turnOn(PrayerLockSettings settings) async {
    settings.setEnabled(true);
    PrayerLockBridge.apply();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<PrayerLockSettings>(context);
    final prayer = Provider.of<PrayerProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final shown = [
      for (final a in socialApps)
        if (_installed == null || _installed!.contains(a.package)) a,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr('قفل وقت الصلاة', 'Prayer lock'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr(
              'عند دخول وقت الصلاة التي تختارها، تُغلَق تطبيقات التواصل التي تختارها '
                  'حتى تصلّي وتقرأ أذكار ما بعد الصلاة ثم تضغط «أتممتُ». '
                  'لا يمنع الاتصال ولا الرسائل النصية ولا أي تطبيق آخر.',
              'When a prayer you choose begins, the social apps you choose stay closed until you pray, read the azkar after the prayer and tap "I have finished". Calls, text messages and every other app keep working.',
            ),
            style: const TextStyle(fontSize: 16, height: 1.8),
          ),
          const SizedBox(height: 12),
          if (!PrayerLockBridge.supported)
            _Note(
              tr(
                'هذه الميزة تعمل على أندرويد فقط.',
                'This feature works on Android only.',
              ),
            ),
          if (!prayer.hasLocation)
            _Note(
              tr(
                'حدّد مدينتك أولاً من شاشة الصلاة ليعرف التطبيق مواقيت صلاتك.',
                'Choose your city on the prayer screen first, so the app knows your prayer times.',
              ),
            ),
          SwitchListTile(
            title: Text(
              tr('تفعيل القفل', 'Turn the lock on'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              settings.enabled && !_status.ready
                  ? tr(
                      'يلزم منح إذنين من إعدادات الهاتف (أدناه)',
                      'Two permissions are needed in the phone settings (below)',
                    )
                  : tr('يمكنك إيقافه في أي وقت', 'You can turn it off at any time'),
              style: TextStyle(
                color: settings.enabled && !_status.ready
                    ? Colors.orange
                    : colorScheme.pageNumber,
              ),
            ),
            value: settings.enabled,
            onChanged: (on) =>
                on ? _turnOn(settings) : settings.setEnabled(false),
          ),
          if (settings.enabled && !_status.ready)
            _Permissions(
              status: _status,
              onUsage: PrayerLockBridge.openUsageSettings,
              onOverlay: PrayerLockBridge.openOverlaySettings,
            ),
          if (_status.active)
            Card(
              color: colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.lock_clock_rounded),
                title: Text(
                  tr(
                    'القفل يعمل الآن لصلاة ${_status.prayer ?? ''}',
                    'The lock is on for ${_status.prayer ?? ''}',
                  ),
                ),
                trailing: FilledButton(
                  onPressed: () async {
                    await PrayerLockBridge.done();
                    _refresh();
                  },
                  child: Text(tr('أتممتُ', 'Finished')),
                ),
              ),
            ),
          const Divider(height: 32),
          _Heading(tr('الصلوات', 'Prayers')),
          for (final p in NotificationSettings.prayers)
            CheckboxListTile(
              title: Text(prayerName(p)),
              value: settings.prayerOn(p),
              onChanged: (v) => settings.setPrayer(p, v ?? true),
            ),
          const SizedBox(height: 8),
          _Heading(tr('يُفتح تلقائياً بعد', 'Opens by itself after')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final m in lockDurations)
                  ChoiceChip(
                    label: Text(tr('$m دقيقة', '$m min')),
                    selected: settings.minutes == m,
                    onSelected: (_) => settings.setMinutes(m),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              tr(
                'إن نسيتَ الضغط على «أتممتُ» ينتهي القفل وحده بعد هذه المدة، فلا يبقى مقفلاً.',
                'If you forget to tap "Finished" the lock ends by itself after this time, so it never stays on.',
              ),
              style: TextStyle(color: colorScheme.pageNumber, fontSize: 13),
            ),
          ),
          const Divider(height: 32),
          _Heading(tr('التطبيقات', 'Apps')),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tr(
                  'لم أجد على هاتفك تطبيقات تواصل أعرفها.',
                  'No social app I know of is installed on this phone.',
                ),
              ),
            ),
          for (final a in shown)
            CheckboxListTile(
              title: Text(a.name),
              value: settings.appOn(a.package),
              onChanged: (v) => settings.setApp(a.package, v ?? false),
            ),
          const Divider(height: 32),
          OutlinedButton.icon(
            onPressed: !settings.enabled || !_status.ready
                ? null
                : () async {
                    await PrayerLockBridge.test();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(
                            'القفل يعمل دقيقة. افتح أحد التطبيقات لتراه.',
                            'The lock is on for a minute. Open one of the apps to see it.',
                          ),
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.science_rounded),
            label: Text(tr('جرّب القفل لدقيقة', 'Try the lock for a minute')),
          ),
          const SizedBox(height: 16),
          _Note(
            tr(
              'تحتاج الميزة إلى مواقيت الصلاة التي يحسبها التطبيق، فإن لم تفتح '
                  'التطبيق لعشرة أيام يتوقف القفل حتى تفتحه.',
              'The lock uses the prayer times the app calculates, so if you do not open the app for ten days it stops until you do.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.gold,
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.pageNumber,
        fontSize: 13,
        height: 1.6,
      ),
    ),
  );
}

/// The two permissions the lock needs, each with a button to its page in
/// the phone's settings.
class _Permissions extends StatelessWidget {
  const _Permissions({
    required this.status,
    required this.onUsage,
    required this.onOverlay,
  });

  final LockStatus status;
  final VoidCallback onUsage;
  final VoidCallback onOverlay;

  @override
  Widget build(BuildContext context) {
    Widget row(bool on, String title, String why, VoidCallback open) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            on ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: on ? Colors.green : Colors.orange,
          ),
          title: Text(title),
          subtitle: Text(why),
          trailing: on
              ? null
              : FilledButton.tonal(
                  onPressed: open,
                  child: Text(tr('منح', 'Allow')),
                ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('الإذنان المطلوبان', 'The two permissions'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            row(
              status.usageOn,
              tr('الوصول إلى بيانات الاستخدام', 'Usage access'),
              tr(
                'ليعرف التطبيق أي تطبيق فُتح. اختر «منهج حياة» ثم فعّل المفتاح.',
                'So the app knows which app was opened. Choose the app, then turn it on.',
              ),
              onUsage,
            ),
            row(
              status.overlayOn,
              tr('العرض فوق التطبيقات الأخرى', 'Display over other apps'),
              tr(
                'ليظهر شاشة القفل فوق تطبيق التواصل.',
                'So the lock screen can come up over a social app.',
              ),
              onOverlay,
            ),
            Text(
              tr(
                'لا يقرأ التطبيق ما على الشاشة ولا يرسل شيئاً. يعمل بإشعار صغير دائم طالما القفل مفعّل.',
                'The app does not read the screen or send anything. It runs with a small ongoing notification while the lock is on.',
              ),
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.pageNumber,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
