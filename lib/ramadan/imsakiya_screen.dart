import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../hijri/hijri.dart';
import '../prayer/prayer.dart';
import '../providers/reading_provider.dart';
import '../providers/settings_provider.dart';
import 'ramadan.dart';

/// Fasting times for every day of this (or the next) Ramadan.
class ImsakiyaScreen extends StatelessWidget {
  const ImsakiyaScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ImsakiyaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prayer = Provider.of<PrayerProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final reading = Provider.of<ReadingProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = ramadanDays(now, offset: settings.hijriOffset);
    final year = hijriOf(days.first, offset: settings.hijriOffset).year;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('إمساكية رمضان $year', 'Ramadan $year Timetable')),
      ),
      body: !prayer.hasLocation
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    'اختر مدينتك في تبويب الصلاة أولاً.',
                    'Choose your city in the Prayer tab first.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.auto_stories_rounded,
                      color: colorScheme.gold,
                    ),
                    title: Text(tr('ختمة رمضان', 'Ramadan khatma')),
                    subtitle: Text(
                      tr(
                        'جزء كل يوم (20 صفحة) تختم به القرآن في الشهر',
                        'A juz a day (20 pages) finishes the Quran within the month',
                      ),
                    ),
                    trailing: reading.goal == 20
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.gold,
                          )
                        : FilledButton(
                            onPressed: () => reading.setGoal(20),
                            child: Text(tr('اعتماد', 'Set')),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'في ${prayer.placeName ?? ''} · ${prayer.method.name}. يبدأ الصيام عند الفجر، والإمساك قبله بعشر دقائق احتياطاً.',
                    'In ${prayer.placeName ?? ''} · ${prayer.method.name}. The fast begins at Fajr; imsak is ten minutes earlier as a precaution.',
                  ),
                  style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
                ),
                const SizedBox(height: 12),
                _Row(
                  cells: [
                    tr('اليوم', 'Day'),
                    tr('التاريخ', 'Date'),
                    tr('الإمساك', 'Imsak'),
                    tr('الفجر', 'Fajr'),
                    tr('المغرب', 'Maghrib'),
                  ],
                  header: true,
                ),
                for (final (i, day) in days.indexed)
                  _Row(
                    highlight: day == today,
                    cells: [
                      '${i + 1}',
                      '${dayName(day)} ${day.day}/${day.month}',
                      _time(fastingTimes(prayer, day).imsak),
                      _time(fastingTimes(prayer, day).fajr),
                      _time(fastingTimes(prayer, day).maghrib),
                    ],
                  ),
              ],
            ),
    );
  }
}

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _Row extends StatelessWidget {
  const _Row({
    required this.cells,
    this.header = false,
    this.highlight = false,
  });

  final List<String> cells;
  final bool header;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 13,
      fontWeight: header || highlight ? FontWeight.bold : FontWeight.normal,
      color: header ? colorScheme.onPrimary : colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: header
            ? colorScheme.primary
            : highlight
            ? colorScheme.gold.withValues(alpha: 0.25)
            : null,
        border: Border(bottom: BorderSide(color: colorScheme.div)),
        borderRadius: header
            ? const BorderRadius.vertical(top: Radius.circular(10))
            : null,
      ),
      child: Row(
        children: [
          for (final (i, cell) in cells.indexed)
            Expanded(
              flex: i == 1 ? 3 : 2,
              child: Text(cell, textAlign: TextAlign.center, style: style),
            ),
        ],
      ),
    );
  }
}

/// On the prayer tab: the countdown to iftar or the end of suhoor during
/// Ramadan, or the days left until it from mid-Sha'ban.
class RamadanCard extends StatelessWidget {
  const RamadanCard({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final prayer = Provider.of<PrayerProvider>(context);
    final offset = Provider.of<SettingsProvider>(context).hijriOffset;
    final colorScheme = Theme.of(context).colorScheme;
    final moment = nextFastingMoment(prayer, now, offset: offset);
    final until = daysUntilRamadan(now, offset: offset);
    if (moment == null && until == null) return const SizedBox.shrink();

    final String title;
    final String subtitle;
    if (moment case (final kind, final time)) {
      final left = time.difference(now);
      final clock =
          '${left.inHours}:${(left.inMinutes % 60).toString().padLeft(2, '0')}:'
          '${(left.inSeconds % 60).toString().padLeft(2, '0')}';
      title = kind == FastingMoment.iftar
          ? tr('باقٍ على الإفطار $clock', 'Iftar in $clock')
          : tr('باقٍ على انتهاء السحور $clock', 'Suhoor ends in $clock');
      subtitle = kind == FastingMoment.iftar
          ? tr(
              'الإفطار عند المغرب ${_time(time)}',
              'Iftar at Maghrib, ${_time(time)}',
            )
          : tr(
              'يبدأ الصيام عند الفجر ${_time(time)}',
              'The fast begins at Fajr, ${_time(time)}',
            );
    } else {
      title = until == 1
          ? tr(
              'رمضان يبدأ غداً إن شاء الله',
              'Ramadan begins tomorrow, in sha’ Allah',
            )
          : tr('باقٍ على رمضان $until يوماً', '$until days until Ramadan');
      subtitle = tr('إمساكية الشهر جاهزة', 'The month’s timetable is ready');
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.gold.withValues(alpha: 0.7)),
        ),
        child: ListTile(
          leading: Icon(
            Icons.nightlight_round,
            color: colorScheme.gold,
            size: 32,
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          subtitle: Text(subtitle),
          trailing: Icon(Icons.chevron_left_rounded, color: colorScheme.gold),
          onTap: () => ImsakiyaScreen.open(context),
        ),
      ),
    );
  }
}
