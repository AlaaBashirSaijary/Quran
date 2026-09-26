import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../providers/reading_provider.dart';
import 'group_khatma_screen.dart';

/// Compact daily-goal and khatma progress, shown on the Quran tab.
class WirdCard extends StatelessWidget {
  const WirdCard({super.key});

  @override
  Widget build(BuildContext context) {
    final reading = Provider.of<ReadingProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WirdScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (reading.today / reading.goal).clamp(0, 1),
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      color: colorScheme.gold,
                      backgroundColor: colorScheme.div,
                    ),
                    Center(
                      child: reading.goalMet
                          ? Icon(Icons.check_rounded, color: colorScheme.gold)
                          : Text(
                              '${reading.today}/${reading.goal}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.juzCardText,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reading.goalMet
                          ? tr(
                              'أتممت وردك اليوم',
                              'You finished today’s reading',
                            )
                          : tr(
                              'وردك اليوم: ${_pages(reading.goal)}',
                              'Today’s reading: ${_pages(reading.goal)}',
                            ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.juzCardText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: reading.khatmaProgress,
                        minHeight: 6,
                        color: colorScheme.primary,
                        backgroundColor: colorScheme.div,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        'الختمة: ${reading.khatmaRead} من $totalPages صفحة',
                        'Khatma: ${reading.khatmaRead} of $totalPages pages',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.pageNumber,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: colorScheme.gold),
            ],
          ),
        ),
      ),
    );
  }
}

class WirdScreen extends StatelessWidget {
  const WirdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reading = Provider.of<ReadingProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final finished = reading.khatmaRead == totalPages;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('الورد والختمة', 'Daily Reading & Khatma')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: tr('الورد اليومي', 'Daily reading'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(
                    'قرأت اليوم ${_pages(reading.today)} من ${_pages(reading.goal)}',
                    'Read today: ${_pages(reading.today)} of ${_pages(reading.goal)}',
                  ),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final pages in ReadingProvider.goalOptions)
                      ChoiceChip(
                        label: Text(
                          pages == 20 ? tr('جزء', 'Juz') : _pages(pages),
                        ),
                        selected: reading.goal == pages,
                        onSelected: (_) => reading.setGoal(pages),
                        selectedColor: colorScheme.primary,
                        labelStyle: TextStyle(
                          color: reading.goal == pages
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                        showCheckmark: false,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _WeekChart(values: reading.lastDays(), goal: reading.goal),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: colorScheme.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr(
                        'أيام متتالية أتممت فيها وردك: ${reading.streak}',
                        'Days in a row you finished your reading: ${reading.streak}',
                      ),
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: tr('الختمة', 'Khatma'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(
                    'قرأت ${reading.khatmaRead} من $totalPages صفحة',
                    'Read ${reading.khatmaRead} of $totalPages pages',
                  ),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: reading.khatmaProgress,
                    minHeight: 12,
                    color: colorScheme.gold,
                    backgroundColor: colorScheme.div,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  finished
                      ? tr(
                          'أتممت الختمة، تقبّل الله منك',
                          'You completed the khatma. May Allah accept it from you.',
                        )
                      : tr(
                          'بمعدل ${_pages(reading.goal)} يومياً تختم خلال '
                              '${_days(reading.daysToFinish)} '
                              '(${_date(reading.estimatedFinish)})',
                          'At ${_pages(reading.goal)} a day you will finish in '
                              '${_days(reading.daysToFinish)} '
                              '(${_date(reading.estimatedFinish)})',
                        ),
                  style: TextStyle(color: colorScheme.pageNumber),
                ),
                if (reading.khatmas > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'عدد الختمات المكتملة: ${reading.khatmas}',
                      'Completed khatmas: ${reading.khatmas}',
                    ),
                    style: TextStyle(color: colorScheme.gold),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmNewKhatma(context, reading),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(tr('بدء ختمة جديدة', 'Start a new khatma')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                Icons.groups_rounded,
                color: colorScheme.gold,
                size: 36,
              ),
              title: Text(
                tr('الختمة الجماعية', 'Group Khatma'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                tr(
                  'وزّعوا الأجزاء بينكم وتابعوا الإنجاز عبر واتساب',
                  'Split the juz among you and follow progress over WhatsApp',
                ),
              ),
              trailing: Icon(
                Icons.chevron_left_rounded,
                color: colorScheme.gold,
              ),
              onTap: () => GroupKhatmaListScreen.open(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              'تُحسب الصفحة مقروءة عند الانتقال منها إلى الصفحة التالية أثناء القراءة.',
              'A page counts as read when you move on from it to the next page while reading.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmNewKhatma(
    BuildContext context,
    ReadingProvider reading,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('بدء ختمة جديدة؟', 'Start a new khatma?')),
        content: Text(
          tr(
            'سيُصفَّر تقدّم الختمة الحالية.',
            'Your current khatma progress will be reset.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppConstant.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('بدء', 'Start')),
          ),
        ],
      ),
    );
    if (confirm == true) reading.startNewKhatma();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: AppTheme.secondaryFontFamily,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Pages read on each of the last seven days, today last.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.values, required this.goal});

  final List<int> values;
  final int goal;

  static const _arabicDayNames = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  static const _englishDayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static List<String> get _dayNames =>
      isEnglish ? _englishDayNames : _arabicDayNames;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxValue = [goal, ...values].reduce((a, b) => a > b ? a : b);
    final today = DateTime.now();

    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      values[i] == 0 ? '' : '${values[i]}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.pageNumber,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: 80 * values[i] / maxValue + 2,
                      decoration: BoxDecoration(
                        color: values[i] >= goal
                            ? colorScheme.gold
                            : colorScheme.primary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        i == values.length - 1
                            ? tr('اليوم', 'Today')
                            : _dayNames[today
                                      .subtract(
                                        Duration(days: values.length - 1 - i),
                                      )
                                      .weekday -
                                  1],
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.pageNumber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "صفحة", "صفحتان", "3 صفحات", "11 صفحة".
String _pages(int n) {
  if (isEnglish) return n == 1 ? '1 page' : '$n pages';
  if (n == 1) return 'صفحة';
  if (n == 2) return 'صفحتان';
  if (n >= 3 && n <= 10) return '$n صفحات';
  return '$n صفحة';
}

/// After خلال: "يوم واحد", "يومين", "3 أيام", "11 يوماً".
String _days(int n) {
  if (isEnglish) return n <= 1 ? '1 day' : '$n days';
  if (n <= 1) return 'يوم واحد';
  if (n == 2) return 'يومين';
  if (n <= 10) return '$n أيام';
  return '$n يوماً';
}

String _date(DateTime date) => '${date.year}/${date.month}/${date.day}';
