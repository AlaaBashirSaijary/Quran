import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../providers/settings_provider.dart';
import 'hijri.dart';

/// A Hijri month at a glance, with Gregorian dates and the days of note.
class HijriCalendarScreen extends StatefulWidget {
  const HijriCalendarScreen({super.key, this.today});

  /// For tests; defaults to now.
  final DateTime? today;

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HijriCalendarScreen()),
    );
  }

  @override
  State<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends State<HijriCalendarScreen> {
  late final DateTime _today;
  late DateTime _shown;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _shown = _today;
    _selected = _today;
  }

  void _move(List<DateTime> days, int direction) {
    setState(() {
      final edge = direction < 0 ? days.first : days.last;
      _shown = DateTime(edge.year, edge.month, edge.day + direction);
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final offset = Provider.of<SettingsProvider>(context).hijriOffset;
    final colorScheme = Theme.of(context).colorScheme;
    final days = hijriMonthDays(_shown, offset: offset);
    final first = hijriOf(days.first, offset: offset);
    final last = days.last;
    // Columns start on Saturday.
    final lead = (days.first.weekday - DateTime.saturday) % 7;
    final selected = _selected;
    final notes = selected == null
        ? const <String>[]
        : occasionsOn(selected, offset: offset);

    return Scaffold(
      appBar: AppBar(title: Text(tr('التقويم الهجري', 'Hijri Calendar'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: tr('الشهر السابق', 'Previous month'),
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _move(days, -1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${first.monthName} ${first.year}',
                      style: TextStyle(
                        fontFamily: AppTheme.secondaryFontFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${days.first.day}/${days.first.month} – '
                      '${last.day}/${last.month}/${last.year}',
                      style: TextStyle(color: colorScheme.pageNumber),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('الشهر التالي', 'Next month'),
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _move(days, 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.85,
            children: [
              for (var d = 0; d < 7; d++)
                Center(
                  child: FittedBox(
                    child: Text(
                      _shortDay(DateTime.saturday + d),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.gold,
                      ),
                    ),
                  ),
                ),
              for (var i = 0; i < lead; i++) const SizedBox(),
              for (final day in days)
                _DayCell(
                  day: day,
                  hijriDay: hijriOf(day, offset: offset).day,
                  isToday: day == _today,
                  isSelected: day == selected,
                  marked: occasionsOn(
                    day,
                    offset: offset,
                    weekly: false,
                  ).isNotEmpty,
                  onTap: () => setState(() => _selected = day),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (selected != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dayName(selected)} ${hijriOf(selected, offset: offset)}'
                      ' · ${selected.day}/${selected.month}/${selected.year}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (notes.isEmpty)
                      Text(
                        tr(
                          'لا مناسبة في هذا اليوم',
                          'Nothing of note on this day',
                        ),
                        style: TextStyle(color: colorScheme.pageNumber),
                      )
                    else
                      for (final note in notes)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: colorScheme.gold,
                              ),
                              const SizedBox(width: 6),
                              Expanded(child: Text(note)),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            tr(
              'تقويم أم القرى مع تعديلك في الإعدادات. قد يختلف بدء الشهر في بلدك برؤية الهلال.',
              'Umm al-Qura calendar with your adjustment in Settings. The month may begin differently where you live, by moon sighting.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
          ),
        ],
      ),
    );
  }

  static String _shortDay(int weekday) {
    final w = (weekday - 1) % 7 + 1;
    final name = dayName(DateTime(2026, 9, 21 + (w - 1)));
    return isEnglish ? name.substring(0, 3) : name;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hijriDay,
    required this.isToday,
    required this.isSelected,
    required this.marked,
    required this.onTap,
  });

  final DateTime day;
  final int hijriDay;
  final bool isToday;
  final bool isSelected;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fill = isToday ? colorScheme.primary : null;
    final ink = isToday ? colorScheme.onPrimary : colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isSelected
              ? BorderSide(color: colorScheme.gold, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$hijriDay',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              Text(
                '${day.day}/${day.month}',
                style: TextStyle(
                  fontSize: 9,
                  color: isToday
                      ? colorScheme.onPrimary.withValues(alpha: 0.8)
                      : colorScheme.pageNumber,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: marked ? colorScheme.gold : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
