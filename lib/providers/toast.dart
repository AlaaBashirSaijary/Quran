import 'package:flutter/material.dart';

class ToastProvider extends ChangeNotifier {
  int hizbQuarter = 0;

  void update(int newHizbQuarter) {
    if (hizbQuarter != newHizbQuarter) {
      showToast();
    }
    hizbQuarter = newHizbQuarter;
  }

  bool isShowToast = false;
  bool _disposed = false;

  double get opacity => isShowToast ? 1 : 0;

  Future<void> showToast() async {
    isShowToast = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1500));
    // The reader may have closed (and the app been rebuilt) meanwhile.
    if (_disposed) return;

    isShowToast = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
