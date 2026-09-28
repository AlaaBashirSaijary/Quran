import 'package:flutter/foundation.dart';

extension Round on double {
  int get fixedRound {
    if (this == roundToDouble()) return toInt();
    return toInt() + 1;
  }
}

/// Neither bundled font has the ﷺ ligature (U+FDFA), so it is shown as the
/// words it stands for (its Unicode compatibility decomposition).
String expandLigatures(String text) =>
    text.replaceAll('ﷺ', 'صلى الله عليه وسلم');

/// Disposes [controllers] of a dialog once it has finished closing: its
/// closing animation (and the keyboard going away) still rebuilds the
/// fields that use them.
void disposeAfterDialog(List<ChangeNotifier> controllers) {
  Future<void>.delayed(const Duration(seconds: 1), () {
    for (final c in controllers) {
      c.dispose();
    }
  });
}
