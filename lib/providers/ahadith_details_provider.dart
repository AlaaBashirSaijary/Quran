import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../model/hadith_model.dart';

class AhadithDetailsProvider extends ChangeNotifier {
  List<HadithModel> ahadithData = [];

  Future<void> loadHadithFile() async {
    final hadithFile = await rootBundle.loadString('assets/ahadeth.txt');
    ahadithData = hadithFile
        .replaceAll('\uFEFF', '')
        // Tatweel was used to stretch words (أمـيـر), which reads as noise
        .replaceAll('\u0640', '')
        .split('#')
        .map((hadith) => hadith.trim())
        .where((hadith) => hadith.isNotEmpty)
        .map((hadith) {
          final lines = hadith.split('\n').map((line) => line.trim()).toList();
          return HadithModel(
            title: lines.first,
            content: lines.skip(1).where((line) => line.isNotEmpty).toList(),
          );
        })
        .toList();
    notifyListeners();
  }
}
