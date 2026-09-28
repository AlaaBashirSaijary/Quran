import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../providers/sebha_provider.dart';
import 'volume_keys.dart';

class SebhaTab extends StatelessWidget {
  const SebhaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final sebha = Provider.of<SebhaProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('السبحة', 'Tasbeeh')),
        actions: [
          IconButton(
            tooltip: tr('بدء من جديد', 'Start over'),
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: sebha.resetRound,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'vibration') sebha.setVibration(!sebha.vibration);
              if (value == 'volume') sebha.setVolumeKeys(!sebha.volumeKeys);
              if (value == 'add') _showAddZikr(context);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'add',
                child: Text(tr('إضافة ذكر', 'Add a dhikr')),
              ),
              CheckedPopupMenuItem(
                value: 'vibration',
                checked: sebha.vibration,
                child: Text(tr('الاهتزاز', 'Vibration')),
              ),
              if (VolumeKeys.supported)
                CheckedPopupMenuItem(
                  value: 'volume',
                  checked: sebha.volumeKeys,
                  child: Text(
                    tr('العدّ بأزرار الصوت', 'Count with volume keys'),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<SebhaMode>(
              segments: [
                ButtonSegment(
                  value: SebhaMode.free,
                  icon: Icon(Icons.all_inclusive_rounded),
                  label: Text(tr('ذكر حر', 'Free')),
                ),
                ButtonSegment(
                  value: SebhaMode.afterPrayer,
                  icon: Icon(Icons.mosque_rounded),
                  label: Text(tr('بعد الصلاة', 'After prayer')),
                ),
              ],
              selected: {sebha.mode},
              onSelectionChanged: (value) => sebha.setMode(value.first),
            ),
          ),
          if (sebha.mode == SebhaMode.free)
            _ZikrChips(sebha: sebha)
          else
            _PrayerSteps(sebha: sebha),
          const SizedBox(height: 16),
          _Counter(sebha: sebha),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: sebha.currentCount == 0 ? null : sebha.undo,
                icon: const Icon(Icons.undo_rounded),
                label: Text(tr('تراجع', 'Undo')),
              ),
              if (sebha.mode == SebhaMode.free) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showTargetPicker(context, sebha.selected),
                  icon: const Icon(Icons.flag_rounded),
                  label: Text(
                    tr(
                      'الهدف ${sebha.selected.target}',
                      'Target ${sebha.selected.target}',
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _Stat(label: tr('اليوم', 'Today'), value: sebha.today),
                const SizedBox(width: 10),
                _Stat(label: tr('المجموع', 'Total'), value: sebha.total),
                const SizedBox(width: 10),
                _Stat(
                  label: tr('أيام متتالية', 'Day streak'),
                  value: sebha.streak,
                  icon: Icons.local_fire_department_rounded,
                  color: colorScheme.gold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZikrChips extends StatelessWidget {
  const _ZikrChips({required this.sebha});

  final SebhaProvider sebha;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final zikr in sebha.azkar)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onLongPress: zikr.isCustom
                    ? () => _confirmRemove(context, sebha, zikr)
                    : null,
                child: ChoiceChip(
                  label: Text(zikr.text),
                  selected: zikr.id == sebha.selected.id,
                  onSelected: (_) => sebha.select(zikr.id),
                  selectedColor: colorScheme.primary,
                  labelStyle: TextStyle(
                    color: zikr.id == sebha.selected.id
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                  showCheckmark: false,
                ),
              ),
            ),
          ActionChip(
            avatar: Icon(Icons.add_rounded, color: colorScheme.gold),
            label: Text(tr('ذكر جديد', 'New dhikr')),
            onPressed: () => _showAddZikr(context),
          ),
        ],
      ),
    );
  }
}

class _PrayerSteps extends StatelessWidget {
  const _PrayerSteps({required this.sebha});

  final SebhaProvider sebha;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < afterPrayerSteps.length; i++)
            Expanded(
              child: Container(
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color:
                      i < sebha.stepIndex ||
                          (i == sebha.stepIndex && sebha.afterPrayerDone)
                      ? colorScheme.gold
                      : i == sebha.stepIndex
                      ? colorScheme.primary
                      : colorScheme.div,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.sebha});

  final SebhaProvider sebha;

  void _tap() => countTasbeeh(sebha);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final done = sebha.mode == SebhaMode.afterPrayer && sebha.afterPrayerDone;
    final text = sebha.currentText;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: 96,
            child: Center(
              child: Text(
                done
                    ? tr('تقبّل الله منك', 'May Allah accept it from you')
                    : text,
                textAlign: TextAlign.center,
                style:
                    (text.length > 30
                            ? textTheme.titleLarge
                            : textTheme.displaySmall)
                        ?.copyWith(
                          fontFamily: AppTheme.secondaryFontFamily,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          height: 1.5,
                        ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: done ? 1 : sebha.currentCount / sebha.currentTarget,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                color: colorScheme.gold,
                backgroundColor: colorScheme.div,
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Material(
                  color: colorScheme.primary,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _tap,
                    child: Semantics(
                      button: true,
                      liveRegion: true,
                      label: tr('عدّاد التسبيح', 'Tasbeeh counter'),
                      onTapHint: done
                          ? tr('البدء من جديد', 'Start over')
                          : tr('تسبيحة', 'Count'),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (done)
                              Icon(
                                Icons.check_rounded,
                                size: 72,
                                color: colorScheme.onPrimary,
                              )
                            else
                              Text(
                                '${sebha.currentCount}',
                                style: TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            Text(
                              done
                                  ? tr(
                                      'اضغط للبدء من جديد',
                                      'Tap to start over',
                                    )
                                  : tr(
                                      'من ${sebha.currentTarget}',
                                      'of ${sebha.currentTarget}',
                                    ),
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onPrimary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            if (sebha.mode == SebhaMode.free &&
                                sebha.rounds > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  tr(
                                    'الجولة ${sebha.rounds + 1}',
                                    'Round ${sebha.rounds + 1}',
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  final String label;
  final int value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) Icon(icon, size: 20, color: color),
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color ?? colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: colorScheme.pageNumber),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showAddZikr(BuildContext context) async {
  final sebha = Provider.of<SebhaProvider>(context, listen: false);
  final textController = TextEditingController();
  final targetController = TextEditingController(text: '33');

  final added = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('إضافة ذكر', 'Add a dhikr')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: textController,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              labelText: tr('نص الذكر', 'Dhikr text'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: targetController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: tr('العدد المطلوب', 'Target count'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppConstant.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr('إضافة', 'Add')),
        ),
      ],
    ),
  );

  if (added == true) {
    sebha.addZikr(
      textController.text,
      int.tryParse(targetController.text) ?? 33,
    );
  }
  disposeAfterDialog([textController, targetController]);
}

Future<void> _showTargetPicker(BuildContext context, Zikr zikr) async {
  final sebha = Provider.of<SebhaProvider>(context, listen: false);
  final controller = TextEditingController(text: '${zikr.target}');

  final target = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('عدد «${zikr.text}»', 'Count for “${zikr.text}”')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final value in const [33, 100, 1000])
                ActionChip(
                  label: Text('$value'),
                  onPressed: () => Navigator.pop(context, value),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: tr('عدد آخر', 'Other number'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppConstant.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(controller.text)),
          child: Text(tr('حفظ', 'Save')),
        ),
      ],
    ),
  );

  if (target != null && target > 0) sebha.setTarget(zikr.id, target);
  disposeAfterDialog([controller]);
}

Future<void> _confirmRemove(
  BuildContext context,
  SebhaProvider sebha,
  Zikr zikr,
) async {
  final remove = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('حذف الذكر؟', 'Delete this dhikr?')),
      content: Text(zikr.text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppConstant.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr('حذف', 'Delete')),
        ),
      ],
    ),
  );
  if (remove == true) sebha.removeZikr(zikr.id);
}

/// One count, with a vibration if chosen (stronger on reaching the target).
void countTasbeeh(SebhaProvider sebha) {
  final reached = sebha.tap();
  if (!sebha.vibration) return;
  if (reached) {
    HapticFeedback.heavyImpact();
  } else {
    HapticFeedback.selectionClick();
  }
}
