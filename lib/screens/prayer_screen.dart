import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../notifications/notification_screen.dart';
import '../hijri/hijri.dart' as hijri;
import '../hijri/hijri.dart' show hijriOf, occasionsOn;
import '../prayer/prayer.dart';
import '../providers/settings_provider.dart';
import '../qibla/qibla_screen.dart';
import '../ramadan/imsakiya_screen.dart';
import '../hijri/calendar_screen.dart';

class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prayer = Provider.of<PrayerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('مواقيت الصلاة', 'Prayer Times')),
        actions: [
          IconButton(
            tooltip: tr('التقويم الهجري', 'Hijri calendar'),
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => HijriCalendarScreen.open(context),
          ),
          IconButton(
            tooltip: tr('التنبيهات', 'Notifications'),
            icon: const Icon(Icons.notifications_active_rounded),
            onPressed: () => NotificationSettingsScreen.open(context),
          ),
          if (prayer.hasLocation)
            IconButton(
              tooltip: tr('الإعدادات', 'Settings'),
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => _showSettings(context),
            ),
        ],
      ),
      body: prayer.hasLocation ? const _Times() : const _ChooseLocation(),
    );
  }
}

class _ChooseLocation extends StatelessWidget {
  const _ChooseLocation();

  @override
  Widget build(BuildContext context) {
    final prayer = Provider.of<PrayerProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mosque_rounded, size: 80, color: colorScheme.gold),
            const SizedBox(height: 16),
            Text(
              tr(
                'لحساب مواقيت الصلاة نحتاج إلى معرفة مدينتك',
                'To calculate prayer times we need to know your city',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'تُحسب المواقيت على هاتفك دون إنترنت، ولا يُرسل موقعك إلى أي جهة.',
                'Times are calculated on your phone without internet, and your location is never sent anywhere.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.pageNumber),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: prayer.locating
                    ? null
                    : () => prayer.useDeviceLocation(),
                icon: prayer.locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: Text(tr('استخدام موقعي', 'Use my location')),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickCity(context),
                icon: const Icon(Icons.location_city_rounded),
                label: Text(tr('اختيار مدينة', 'Choose a city')),
              ),
            ),
            if (prayer.error != null) ...[
              const SizedBox(height: 16),
              Text(
                prayer.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Times extends StatefulWidget {
  const _Times();

  @override
  State<_Times> createState() => _TimesState();
}

class _TimesState extends State<_Times> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayer = Provider.of<PrayerProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final times = prayer.timesOn(_now);
    final next = prayer.nextPrayer(_now);
    final current = prayer.currentPrayer(_now);
    final left = next.time.difference(_now);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.brightness == Brightness.light
                ? AppColor.green
                : AppColor.nightSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.gold.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.place_rounded, color: colorScheme.gold, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    prayer.placeName ?? '',
                    style: TextStyle(color: colorScheme.gold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${hijri.dayName(_now)} ${hijriOf(_now, offset: settings.hijriOffset)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                tr('الصلاة القادمة: ${next.name}', 'Next prayer: ${next.name}'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontFamily: AppTheme.secondaryFontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  _countdown(left),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                tr('عند ${_time(next.time)}', 'At ${_time(next.time)}'),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        RamadanCard(now: _now),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              for (final t in times)
                _TimeRow(
                  time: t,
                  isCurrent: t.prayer == current,
                  isNext:
                      t.prayer == next.prayer && t.time.day == next.time.day,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Occasions(now: _now, offset: settings.hijriOffset),
        Card(
          child: prayer.nearKaaba
              ? ListTile(
                  leading: Icon(Icons.mosque_rounded, color: colorScheme.gold),
                  title: Text(tr('اتجاه القبلة', 'Qibla Direction')),
                  subtitle: Text(
                    tr(
                      'أنت قريب من المسجد الحرام',
                      'You are close to the Sacred Mosque',
                    ),
                  ),
                )
              : ListTile(
                  leading: Transform.rotate(
                    angle: prayer.qibla * pi / 180,
                    child: Icon(
                      Icons.navigation_rounded,
                      color: colorScheme.gold,
                    ),
                  ),
                  title: Text(tr('اتجاه القبلة', 'Qibla Direction')),
                  subtitle: Text(
                    tr(
                      '${prayer.qibla.toStringAsFixed(0)}° من الشمال باتجاه عقارب الساعة',
                      '${prayer.qibla.toStringAsFixed(0)}° clockwise from north',
                    ),
                  ),
                  trailing: Icon(
                    Icons.explore_rounded,
                    color: colorScheme.primary,
                  ),
                  onTap: () => QiblaScreen.open(context),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          '${tr('طريقة الحساب', 'Calculation method')}: ${prayer.method.name}'
          '${prayer.hanafiAsr ? tr(' · العصر على المذهب الحنفي', ' · Hanafi Asr') : ''}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.time,
    required this.isCurrent,
    required this.isNext,
  });

  final PrayerTime time;
  final bool isCurrent;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlight = isCurrent || isNext;
    return Container(
      decoration: BoxDecoration(
        color: isCurrent ? colorScheme.gold.withValues(alpha: 0.15) : null,
        border: Border(bottom: BorderSide(color: colorScheme.div)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text(
            time.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            Text(
              tr('الآن', 'Now'),
              style: TextStyle(fontSize: 12, color: colorScheme.gold),
            ),
          ],
          const Spacer(),
          Text(
            _time(time.time),
            style: TextStyle(
              fontSize: 18,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 12-hour clock with ص/م (AM/PM).
String _time(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$hour:${_two(t.minute)} ${t.hour < 12 ? tr('ص', 'AM') : tr('م', 'PM')}';
}

String _countdown(Duration d) =>
    '${_two(d.inHours)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';

Future<void> _pickCity(BuildContext context) async {
  final prayer = Provider.of<PrayerProvider>(context, listen: false);
  final city = await showModalBottomSheet<City>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => ListView(
        controller: controller,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              tr('اختر مدينتك', 'Choose your city'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          for (final city in cities)
            ListTile(
              title: Text(city.name),
              onTap: () => Navigator.pop(context, city),
            ),
        ],
      ),
    ),
  );
  if (city != null) prayer.setCity(city);
}

Future<void> _showSettings(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, controller) => Consumer<PrayerProvider>(
        builder: (context, prayer, _) => ListView(
          controller: controller,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: const Icon(Icons.my_location_rounded),
              title: Text(tr('تحديث موقعي', 'Update my location')),
              subtitle: prayer.error == null ? null : Text(prayer.error!),
              trailing: prayer.locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: prayer.locating ? null : prayer.useDeviceLocation,
            ),
            ListTile(
              leading: const Icon(Icons.location_city_rounded),
              title: Text(tr('اختيار مدينة', 'Choose a city')),
              subtitle: Text(prayer.placeName ?? ''),
              onTap: () => _pickCity(context),
            ),
            ListTile(
              leading: Icon(
                Icons.nightlight_round,
                color: Theme.of(context).colorScheme.gold,
              ),
              title: Text(tr('إمساكية رمضان', 'Ramadan timetable')),
              onTap: () {
                Navigator.pop(context);
                ImsakiyaScreen.open(context);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.wb_twilight_rounded),
              title: Text(tr('العصر على المذهب الحنفي', 'Hanafi Asr')),
              subtitle: Text(
                tr(
                  'يتأخر وقت العصر (ظل المثلين)',
                  'Later Asr (shadow twice the length)',
                ),
              ),
              value: prayer.hanafiAsr,
              onChanged: prayer.setHanafiAsr,
            ),
            const Divider(),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                tr('طريقة الحساب', 'Calculation method'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            RadioGroup<String>(
              groupValue: prayer.methodId,
              onChanged: (id) {
                if (id != null) prayer.setMethod(id);
              },
              child: Column(
                children: [
                  for (final method in prayerMethods)
                    RadioListTile<String>(
                      value: method.id,
                      title: Text(method.name),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Today's and tomorrow's days of note, if any.
class _Occasions extends StatelessWidget {
  const _Occasions({required this.now, required this.offset});

  final DateTime now;
  final int offset;

  @override
  Widget build(BuildContext context) {
    final today = occasionsOn(now, offset: offset);
    final tomorrow = occasionsOn(
      now.add(const Duration(days: 1)),
      offset: offset,
    );
    if (today.isEmpty && tomorrow.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, notes) in [
                (tr('اليوم', 'Today'), today),
                (tr('غداً', 'Tomorrow'), tomorrow),
              ])
                if (notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 20,
                          color: colorScheme.gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$label: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                TextSpan(text: notes.join(tr('، ', ', '))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
