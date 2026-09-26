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
