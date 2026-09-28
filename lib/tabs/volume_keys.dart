import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Counting tasbeeh with the phone's volume buttons (MainActivity.kt).
class VolumeKeys {
  VolumeKeys._();

  static const _channel = MethodChannel('tareeq/volume');
  static final _presses = StreamController<void>.broadcast();
  static bool _listening = false;
  static bool _capturing = false;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// A press of either volume button while captured.
  static Stream<void> get presses => _presses.stream;

  /// Whether the volume buttons count instead of changing the volume.
  static Future<void> capture(bool on) async {
    if (!supported || on == _capturing) return;
    _capturing = on;
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'press') _presses.add(null);
      });
    }
    try {
      await _channel.invokeMethod<void>('capture', on);
    } catch (_) {
      // No native side (tests, other platforms).
    }
  }
}
