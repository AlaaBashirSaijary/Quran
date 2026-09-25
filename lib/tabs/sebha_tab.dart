import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/index.dart';

class SebhaTab extends StatefulWidget {
  const SebhaTab({super.key});

  @override
  State<SebhaTab> createState() => _SebhaTabState();
}

class _SebhaTabState extends State<SebhaTab> {
  static const perZikr = 33;
  static const azkar = [
    'سبحان الله',
    'الحمد لله',
    'لا إله إلا الله',
    'الله أكبر',
    'أستغفر الله',
  ];

  SharedPreferences? prefs;
  int counter = 0;
  int index = 0;
  int total = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((value) {
      if (!mounted) return;
      setState(() {
        prefs = value;
        counter = value.getInt('sebhaCounter') ?? 0;
        index = (value.getInt('sebhaIndex') ?? 0) % azkar.length;
        total = value.getInt('sebhaTotal') ?? 0;
      });
    });
  }

  void _save() {
    prefs?.setInt('sebhaCounter', counter);
    prefs?.setInt('sebhaIndex', index);
    prefs?.setInt('sebhaTotal', total);
  }

  void _tap() {
    setState(() {
      counter++;
      total++;
      if (counter == perZikr) {
        counter = 0;
        index = (index + 1) % azkar.length;
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    });
    _save();
  }

  void _reset() {
    setState(() {
      counter = 0;
      index = 0;
      total = 0;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('السبحة'),
        actions: [
          IconButton(
            tooltip: 'تصفير',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _reset,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                azkar[index],
                style: textTheme.displaySmall?.copyWith(
                  fontFamily: AppTheme.secondaryFontFamily,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: counter / perZikr,
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
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _tap,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$counter',
                                  style: TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                                Text(
                                  'من $perZikr',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onPrimary
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اضغط على الدائرة للتسبيح',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: colorScheme.gold),
                      const SizedBox(width: 10),
                      Text('مجموع التسبيحات: $total',
                          style: textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
