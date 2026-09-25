import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Zikr {
  const Zikr({
    required this.id,
    required this.text,
    required this.target,
    this.isCustom = false,
  });

  final String id;
  final String text;
  final int target;
  final bool isCustom;

  Zikr copyWith({int? target}) => Zikr(
        id: id,
        text: text,
        target: target ?? this.target,
        isCustom: isCustom,
      );

  Map<String, Object> toJson() =>
      {'id': id, 'text': text, 'target': target, 'custom': isCustom};

  static Zikr fromJson(Map<String, dynamic> json) => Zikr(
        id: json['id'] as String,
        text: json['text'] as String,
        target: json['target'] as int,
        isCustom: json['custom'] as bool? ?? false,
      );
}

enum SebhaMode { free, afterPrayer }

/// One step of the tasbeeh after prayer (Sahih Muslim 597): 33 of each, then
/// the tahleel once to complete a hundred.
class PrayerStep {
  const PrayerStep(this.text, this.target);

  final String text;
  final int target;
}

const afterPrayerSteps = [
  PrayerStep('سبحان الله', 33),
  PrayerStep('الحمد لله', 33),
  PrayerStep('الله أكبر', 33),
  PrayerStep(
    'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، وهو على كل شيء قدير',
    1,
  ),
];

const defaultAzkar = [
  Zikr(id: 'subhan', text: 'سبحان الله', target: 33),
  Zikr(id: 'hamd', text: 'الحمد لله', target: 33),
  Zikr(id: 'akbar', text: 'الله أكبر', target: 33),
  Zikr(id: 'tahleel', text: 'لا إله إلا الله', target: 100),
  Zikr(id: 'istighfar', text: 'أستغفر الله', target: 100),
  Zikr(id: 'bihamdih', text: 'سبحان الله وبحمده', target: 100),
  Zikr(id: 'hawqala', text: 'لا حول ولا قوة إلا بالله', target: 100),
  Zikr(id: 'salat', text: 'اللهم صلِّ وسلم على نبينا محمد', target: 100),
];

class SebhaProvider extends ChangeNotifier {
  SebhaProvider(this.prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _load();
  }

  final SharedPreferences prefs;
  final DateTime Function() _clock;

  late List<Zikr> _azkar;
  late String _selectedId;
  SebhaMode mode = SebhaMode.free;

  /// Taps in the current round of the free mode.
  int count = 0;

  /// Completed rounds of the selected zikr (free mode).
  int rounds = 0;

  int stepIndex = 0;
  int stepCount = 0;
  bool afterPrayerDone = false;

  int total = 0;
  int today = 0;
  int streak = 0;
  String? _lastDay;
  Map<String, int> _todayByZikr = {};

  bool vibration = true;

  List<Zikr> get azkar => List.unmodifiable(_azkar);

  Zikr get selected =>
      _azkar.firstWhere((z) => z.id == _selectedId, orElse: () => _azkar.first);

  int todayCountFor(String id) => _todayByZikr[id] ?? 0;

  PrayerStep get currentStep => afterPrayerSteps[stepIndex];

  /// Text and progress for whichever mode is active.
  String get currentText =>
      mode == SebhaMode.free ? selected.text : currentStep.text;
  int get currentCount => mode == SebhaMode.free ? count : stepCount;
  int get currentTarget =>
      mode == SebhaMode.free ? selected.target : currentStep.target;

  // ---------------------------------------------------------------- actions

  /// Counts one tap. Returns true when a target was just reached.
  bool tap() {
    _rollDay();
    total++;
    today++;
    var reached = false;

    if (mode == SebhaMode.free) {
      _todayByZikr[_selectedId] = todayCountFor(_selectedId) + 1;
      count++;
      if (count >= selected.target) {
        count = 0;
        rounds++;
        reached = true;
      }
    } else {
      if (afterPrayerDone) _restartAfterPrayer();
      stepCount++;
      if (stepCount >= currentStep.target) {
        reached = true;
        if (stepIndex == afterPrayerSteps.length - 1) {
          afterPrayerDone = true;
        } else {
          stepIndex++;
          stepCount = 0;
        }
      }
    }
    _save();
    notifyListeners();
    return reached;
  }

  /// Takes back the last tap of the current round.
  void undo() {
    if (mode == SebhaMode.free) {
      if (count == 0) return;
      count--;
      _todayByZikr[_selectedId] =
          (todayCountFor(_selectedId) - 1).clamp(0, 1 << 30);
    } else {
      if (afterPrayerDone || stepCount == 0) return;
      stepCount--;
    }
    total = (total - 1).clamp(0, 1 << 30);
    today = (today - 1).clamp(0, 1 << 30);
    _save();
    notifyListeners();
  }

  void resetRound() {
    count = 0;
    rounds = 0;
    _restartAfterPrayer();
    _save();
    notifyListeners();
  }

  void select(String id) {
    if (id == _selectedId && mode == SebhaMode.free) return;
    _selectedId = id;
    mode = SebhaMode.free;
    count = 0;
    rounds = 0;
    _save();
    notifyListeners();
  }

  void setMode(SebhaMode value) {
    if (mode == value) return;
    mode = value;
    _restartAfterPrayer();
    _save();
    notifyListeners();
  }

  void setTarget(String id, int target) {
    if (target < 1) return;
    _azkar = [
      for (final z in _azkar) z.id == id ? z.copyWith(target: target) : z,
    ];
    if (id == _selectedId && count >= target) count = 0;
    _save();
    notifyListeners();
  }

  void addZikr(String text, int target) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || target < 1) return;
    final id = 'custom_${_clock().microsecondsSinceEpoch}';
    _azkar = [
      ..._azkar,
      Zikr(id: id, text: trimmed, target: target, isCustom: true),
    ];
    select(id);
  }

  void removeZikr(String id) {
    final zikr = _azkar.where((z) => z.id == id).firstOrNull;
    if (zikr == null || !zikr.isCustom) return;
    _azkar = [
      for (final z in _azkar)
        if (z.id != id) z
    ];
    if (_selectedId == id) {
      _selectedId = _azkar.first.id;
      count = 0;
      rounds = 0;
    }
    _save();
    notifyListeners();
  }

  void setVibration(bool value) {
    vibration = value;
    prefs.setBool('sebha.vibration', value);
    notifyListeners();
  }

  // ------------------------------------------------------------ persistence

  static String _day(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Starts a new day's counts and keeps the streak of consecutive days.
  void _rollDay() {
    final now = _clock();
    final todayKey = _day(now);
    if (_lastDay == todayKey) return;
    final yesterday = _day(now.subtract(const Duration(days: 1)));
    streak = _lastDay == yesterday ? streak + 1 : 1;
    _lastDay = todayKey;
    today = 0;
    _todayByZikr = {};
  }

  void _restartAfterPrayer() {
    stepIndex = 0;
    stepCount = 0;
    afterPrayerDone = false;
  }

  void _load() {
    final saved = prefs.getString('sebha.azkar');
    _azkar = saved == null
        ? [...defaultAzkar]
        : [
            for (final item in jsonDecode(saved) as List)
              Zikr.fromJson(item as Map<String, dynamic>),
          ];
    if (_azkar.isEmpty) _azkar = [...defaultAzkar];
    _selectedId = prefs.getString('sebha.selected') ?? _azkar.first.id;
    mode = SebhaMode.values.firstWhere(
      (m) => m.name == prefs.getString('sebha.mode'),
      orElse: () => SebhaMode.free,
    );
    count = prefs.getInt('sebha.count') ?? 0;
    rounds = prefs.getInt('sebha.rounds') ?? 0;
    stepIndex =
        (prefs.getInt('sebha.step') ?? 0).clamp(0, afterPrayerSteps.length - 1);
    stepCount = prefs.getInt('sebha.stepCount') ?? 0;
    afterPrayerDone = stepIndex == afterPrayerSteps.length - 1 &&
        stepCount >= afterPrayerSteps.last.target;
    total = prefs.getInt('sebha.total') ?? prefs.getInt('sebhaTotal') ?? 0;
    today = prefs.getInt('sebha.today') ?? 0;
    streak = prefs.getInt('sebha.streak') ?? 0;
    _lastDay = prefs.getString('sebha.day');
    final byZikr = prefs.getString('sebha.todayByZikr');
    _todayByZikr = byZikr == null
        ? {}
        : (jsonDecode(byZikr) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int));
    vibration = prefs.getBool('sebha.vibration') ?? true;

    // A new day since the last visit: show zero for today, but keep the
    // streak until the next tap decides whether it continues.
    if (_lastDay != _day(_clock())) {
      today = 0;
      _todayByZikr = {};
      final yesterday = _day(_clock().subtract(const Duration(days: 1)));
      if (_lastDay != yesterday) streak = 0;
    }
  }

  void _save() {
    prefs
      ..setString(
        'sebha.azkar',
        jsonEncode([for (final z in _azkar) z.toJson()]),
      )
      ..setString('sebha.selected', _selectedId)
      ..setString('sebha.mode', mode.name)
      ..setInt('sebha.count', count)
      ..setInt('sebha.rounds', rounds)
      ..setInt('sebha.step', stepIndex)
      ..setInt('sebha.stepCount', stepCount)
      ..setInt('sebha.total', total)
      ..setInt('sebha.today', today)
      ..setInt('sebha.streak', streak)
      ..setString('sebha.todayByZikr', jsonEncode(_todayByZikr));
    if (_lastDay != null) prefs.setString('sebha.day', _lastDay!);
  }
}
