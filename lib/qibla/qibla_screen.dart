import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/index.dart';
import '../prayer/prayer.dart';
import 'compass.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QiblaScreen()),
    );
  }

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _smoother = AngleSmoother();
  (double, double, double)? _gravity;
  (double, double, double)? _magnetic;
  double? _heading;
  bool _noSensor = false;
  bool _wasAligned = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    const period = Duration(milliseconds: 60);
    try {
      _subscriptions
        ..add(
          accelerometerEventStream(samplingPeriod: period).listen(
            (e) => _gravity = (e.x, e.y, e.z),
            onError: (_) => _missing(),
          ),
        )
        ..add(
          magnetometerEventStream(samplingPeriod: period).listen((e) {
            _magnetic = (e.x, e.y, e.z);
            _update();
          }, onError: (_) => _missing()),
        );
    } catch (_) {
      _noSensor = true;
    }
    _timeout = Timer(const Duration(seconds: 3), () {
      if (_heading == null) _missing();
    });
  }

  void _missing() {
    if (mounted) setState(() => _noSensor = true);
  }

  void _update() {
    final gravity = _gravity, magnetic = _magnetic;
    if (gravity == null || magnetic == null) return;
    final raw = headingFrom(gravity, magnetic);
    if (raw == null || !mounted) return;
    setState(() => _heading = _smoother.add(raw));
  }

  @override
  void dispose() {
    _timeout?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayer = Provider.of<PrayerProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final heading = _heading;
    final qibla = prayer.hasLocation ? prayer.qibla : null;

    Widget body;
    if (qibla == null) {
      body = const _Message(
        icon: Icons.location_off_rounded,
        text: 'اختر مدينتك في تبويب الصلاة أولاً لمعرفة اتجاه القبلة.',
      );
    } else if (_noSensor && heading == null) {
      body = _Message(
        icon: Icons.explore_off_rounded,
        text:
            'لا يمكن قراءة البوصلة على هذا الجهاز.\n'
            'القبلة على ${qibla.toStringAsFixed(0)}° من الشمال باتجاه عقارب الساعة.',
      );
    } else if (heading == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final turn = turnTowards(qibla, heading);
      final aligned = turn.abs() < 5;
      if (aligned && !_wasAligned) HapticFeedback.mediumImpact();
      _wasAligned = aligned;

      body = ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            aligned
                ? 'أنت متجه إلى القبلة'
                : turn > 0
                ? 'استدر ${turn.abs().round()}° إلى اليمين'
                : 'استدر ${turn.abs().round()}° إلى اليسار',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: AppTheme.secondaryFontFamily,
              color: aligned ? colorScheme.gold : colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1,
            child: _Dial(heading: heading, qibla: qibla, aligned: aligned),
          ),
          const SizedBox(height: 24),
          Text(
            'ضع الهاتف أفقياً بعيداً عن المعادن والمغناطيس. إن بدا الاتجاه '
            'غير مستقر فحرّك الهاتف في الهواء على شكل رقم 8 لمعايرة البوصلة. '
            'البوصلة تشير إلى الشمال المغناطيسي، وقد يختلف عن الحقيقي بضع درجات.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('اتجاه القبلة')),
      body: body,
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({
    required this.heading,
    required this.qibla,
    required this.aligned,
  });

  final double heading;
  final double qibla;
  final bool aligned;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return Stack(
          alignment: Alignment.center,
          children: [
            // The dial turns so that its N always points north.
            Transform.rotate(
              angle: -heading * pi / 180,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.brightness == Brightness.light
                      ? Colors.white
                      : AppColor.nightSurface,
                  border: Border.all(
                    color: aligned ? colorScheme.gold : colorScheme.div,
                    width: 6,
                  ),
                ),
                child: Stack(
                  children: [
                    for (final (angle, label) in const [
                      (0.0, 'شمال'),
                      (90.0, 'شرق'),
                      (180.0, 'جنوب'),
                      (270.0, 'غرب'),
                    ])
                      _AtAngle(
                        angle: angle,
                        radius: size / 2 - 28,
                        child: Transform.rotate(
                          angle: heading * pi / 180,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: angle == 0
                                  ? colorScheme.error
                                  : colorScheme.pageNumber,
                            ),
                          ),
                        ),
                      ),
                    _AtAngle(
                      angle: qibla,
                      radius: size / 2 - 64,
                      child: Transform.rotate(
                        angle: heading * pi / 180,
                        child: Icon(
                          Icons.mosque_rounded,
                          size: 40,
                          color: colorScheme.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The phone's own direction: always straight up.
            Icon(
              Icons.navigation_rounded,
              size: size * 0.3,
              color: aligned ? colorScheme.gold : colorScheme.primary,
            ),
          ],
        );
      },
    );
  }
}

/// Places [child] at [angle] degrees clockwise from the top, [radius] away
/// from the center of its parent.
class _AtAngle extends StatelessWidget {
  const _AtAngle({
    required this.angle,
    required this.radius,
    required this.child,
  });

  final double angle;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rad = angle * pi / 180;
    return Align(
      alignment: Alignment.center,
      child: Transform.translate(
        offset: Offset(radius * sin(rad), -radius * cos(rad)),
        child: child,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: colorScheme.gold),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
