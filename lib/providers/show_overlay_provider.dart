import 'package:flutter/material.dart';

class ShowOverlayProvider extends ChangeNotifier {
  bool isShowOverlay = false;

  void toggleisShowOverlay() {
    isShowOverlay = !isShowOverlay;
    notifyListeners();
  }

  void hideOverlay() {
    if (!isShowOverlay) return;
    isShowOverlay = false;
    notifyListeners();
  }
}
