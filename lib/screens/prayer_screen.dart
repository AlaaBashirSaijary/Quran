import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../prayer/prayer.dart';

class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prayer = Provider.of<PrayerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: [
          if (prayer.hasLocation)
            IconButton(
              tooltip: 'الإعدادات',
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
            const Text(
              'لحساب مواقيت الصلاة نحتاج إلى معرفة مدينتك',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'تُحسب المواقيت على هاتفك دون إنترنت، ولا يُرسل موقعك إلى أي جهة.',
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
                label: const Text('استخدام موقعي'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickCity(context),
                icon: const Icon(Icons.location_city_rounded),
                label: const Text('اختيار مدينة'),
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
              const SizedBox(height: 12),
              Text(
                'الصلاة القادمة: ${next.name}',
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
                'عند ${_time(next.time)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
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
        Card(
          child: prayer.nearKaaba
              ? ListTile(
                  leading: Icon(Icons.mosque_rounded, color: colorScheme.gold),
                  title: const Text('اتجاه القبلة'),
                  subtitle: const Text('أنت قريب من المسجد الحرام'),
                )
              : ListTile(
                  leading: Transform.rotate(
                    angle: prayer.qibla * pi / 180,
                    child: Icon(
                      Icons.navigation_rounded,
                      color: colorScheme.gold,
                    ),
                  ),
                  title: const Text('اتجاه القبلة'),
                  subtitle: Text(
                    '${prayer.qibla.toStringAsFixed(0)}° من الشمال باتجاه عقارب الساعة',
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          'طريقة الحساب: ${prayer.method.name}'
          '${prayer.hanafiAsr ? ' · العصر على المذهب الحنفي' : ''}',
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
              'الآن',
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

/// 12-hour clock with ص/م.
String _time(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$hour:${_two(t.minute)} ${t.hour < 12 ? 'ص' : 'م'}';
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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'اختر مدينتك',
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
              title: const Text('تحديث موقعي'),
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
              title: const Text('اختيار مدينة'),
              subtitle: Text(prayer.placeName ?? ''),
              onTap: () => _pickCity(context),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.wb_twilight_rounded),
              title: const Text('العصر على المذهب الحنفي'),
              subtitle: const Text('يتأخر وقت العصر (ظل المثلين)'),
              value: prayer.hanafiAsr,
              onChanged: prayer.setHanafiAsr,
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'طريقة الحساب',
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
