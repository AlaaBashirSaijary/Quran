import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import '../widgets/surah_number.dart';
import 'matcher.dart';
import 'sherpa_source.dart';
import 'speech_model.dart';
import 'mistake_log.dart';
import 'speech_source.dart';

/// "Recitation": choose a surah to recite, and see the mistakes so far.
class ReciteSetupScreen extends StatelessWidget {
  const ReciteSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = Provider.of<MistakeLog>(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('التسميع', 'Recitation check'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              tr(
                'اختر سورة وتلُها من حفظك. يتتبع التطبيق كلماتك ويقف عند أول خطأ ويخبرك به، '
                    'وتُجمع أخطاؤك في سجل لتراجعها.\n\n'
                    'ميزة تجريبية: اختر سورة واضغط «ابدأ التسميع» ثم تلُها بصوتك؛ تعمل بلا إنترنت. '
                    'في النسخة الخفيفة يُنزَّل نموذج الصوت مرة واحدة (نحو 108 م.ب).',
                'Choose a surah and recite it from memory. The app follows your words, stops at the first mistake and tells you, and your mistakes are kept in a log to review.\n\nExperimental: pick a surah, press "Start reciting" and recite aloud; it works with no internet. The light build downloads the voice model once (about 108 MB).',
              ),
              style: const TextStyle(height: 1.7),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: Icon(Icons.fact_check_rounded, color: colorScheme.gold),
              title: Text(tr('سجل أخطائي', 'My mistakes')),
              subtitle: Text(
                log.isEmpty
                    ? tr('لا أخطاء مسجّلة بعد', 'No mistakes yet')
                    : tr('${log.total} خطأ في ${log.surahs.length} سور', '${log.total} mistakes in ${log.surahs.length} surahs'),
              ),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MistakesScreen()),
              ),
            ),
          ),
          if (sherpaSupported) const _ModelCard(),
          const SizedBox(height: 8),
          for (var surah = 1; surah <= 114; surah++)
            ListTile(
              leading: SurahNumber(number: surah),
              title: Text(surahTitle(surah)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReciteScreen(
                    surah: surah,
                    source: createSherpaSource(
                      Provider.of<SpeechModel>(context, listen: false),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Download, state and removal of the offline voice model.
class _ModelCard extends StatelessWidget {
  const _ModelCard();

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<SpeechModel>(context);
    final colorScheme = Theme.of(context).colorScheme;
    // A build that carries the model needs nothing from the user.
    if (model.bundledModel && model.ready) return const SizedBox.shrink();
    final Widget trailing;
    final String subtitle;
    switch (model.state) {
      case SpeechModelState.ready:
        subtitle = tr('جاهز، يعمل بلا إنترنت', 'Ready, works offline');
        trailing = IconButton(
          tooltip: tr('حذف النموذج', 'Delete the model'),
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: model.delete,
        );
      case SpeechModelState.downloading:
        subtitle = tr(
          'جارٍ التنزيل ${(model.progress * 100).round()}٪ — أبقِ الشاشة مفتوحة',
          'Downloading ${(model.progress * 100).round()}% — keep the screen open',
        );
        trailing = IconButton(
          tooltip: tr('إلغاء', 'Cancel'),
          icon: const Icon(Icons.close_rounded),
          onPressed: model.cancel,
        );
      case SpeechModelState.preparing:
        subtitle = tr('جارٍ تجهيز نموذج الصوت (مرة واحدة)…', 'Getting the voice model ready (once)…');
        trailing = const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
      case SpeechModelState.missing:
      case SpeechModelState.unsupported:
        subtitle = model.error == null
            ? tr('نموذج الصوت (نحو 108 م.ب) — يُنزَّل مرة واحدة', 'Voice model (about 108 MB), downloaded once')
            : tr('تعذّر ذلك: ${model.error}', 'It failed: ${model.error}');
        trailing = FilledButton(
          onPressed: model.state == SpeechModelState.unsupported ? null : model.download,
          child: Text(tr('نزّل', 'Download')),
        );
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.mic_rounded, color: colorScheme.gold),
            title: Text(tr('التعرف على الصوت', 'Voice recognition')),
            subtitle: Text(subtitle),
            trailing: trailing,
          ),
          if (model.state == SpeechModelState.downloading || model.state == SpeechModelState.preparing)
            LinearProgressIndicator(value: model.progress),
        ],
      ),
    );
  }
}

/// Reciting one surah: the words appear as they are recited, and it stops
/// at a mistake.
class ReciteScreen extends StatefulWidget {
  const ReciteScreen({super.key, required this.surah, this.fromAyah = 1, this.source});

  final int surah;
  final int fromAyah;

  /// What hears the voice. The typed stand-in when not given.
  final SpeechSource? source;

  @override
  State<ReciteScreen> createState() => _ReciteScreenState();
}

class _ReciteScreenState extends State<ReciteScreen> {
  late final Future<QuranSearch> _quran = QuranSearch.load();
  late final SpeechSource _source = widget.source ?? TypedSpeechSource();
  final _box = TextEditingController();
  ReciteSession? _session;
  List<Ayah> _ayahs = const [];
  int _logged = 0;
  bool _reveal = false;
  bool _listening = false;
  String _heard = '';
  String? _problem;
  String _note = '';
  int _tentative = 0;
  StreamSubscription<SpeechResult>? _sub;
  StreamSubscription<String>? _notes;

  @override
  void initState() {
    super.initState();
    if (!_source.typed) {
      _sub = _source.results.listen(_onResult, onError: (Object e) {
        if (mounted) setState(() => _problem = '$e');
      });
      _notes = _source.notes.listen((n) {
        if (mounted && _listening) setState(() => _note = n);
      });
    }
  }

  void _onResult(SpeechResult r) {
    final session = _session;
    // Nothing is judged while it is stopped: a late result from before the
    // stop would be counted twice.
    if (session == null || !_listening || session.pending != null) return;
    _heard = r.text;
    final heard = heardWords(r.text);
    session.hear(heard, isFinal: r.isFinal);
    // Words heard but not yet settled show at once in a lighter colour.
    _tentative = r.isFinal ? session.position : session.preview(heard);
    _logMistakes();
    if (session.pending != null || session.finished) {
      _listening = false;
      unawaited(_source.stop());
    }
    if (mounted) setState(() {});
  }

  void _logMistakes() {
    final session = _session!;
    final log = Provider.of<MistakeLog>(context, listen: false);
    for (; _logged < session.mistakes.length; _logged++) {
      log.record(session.mistakes[_logged]);
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      _listening = false;
      setState(() {});
      await _source.stop();
    } else {
      _problem = null;
      _heard = '';
      _note = '';
      _tentative = 0;
      _listening = true;
      setState(() {});
      await _source.start();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _notes?.cancel();
    _source.dispose();
    _box.dispose();
    super.dispose();
  }

  void _begin(QuranSearch quran) {
    final all = quran.ayahsOfSurah(widget.surah);
    _ayahs = [for (final a in all) if (a.number >= widget.fromAyah) a];
    // The basmala may open a surah that is recited from its start.
    final basmala = widget.surah == 1 || widget.surah == 9 || widget.fromAyah != 1
        ? const <String>[]
        : heardWords(quran.ayahsOfSurah(1).first.text);
    _session = ReciteSession(reciteWords(_ayahs), basmala: basmala);
    _logged = 0;
  }

  void _send() {
    final session = _session;
    if (session == null || _box.text.trim().isEmpty) return;
    session.hear(heardWords(_box.text), isFinal: true);
    _box.clear();
    _logMistakes();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('تسميع سورة ${getSurahNameArabic(widget.surah)}', 'Recite ${surahNameOf(widget.surah)}')),
        actions: [
          IconButton(
            tooltip: _reveal ? tr('إخفاء النص', 'Hide the text') : tr('إظهار النص', 'Show the text'),
            icon: Icon(_reveal ? Icons.visibility_rounded : Icons.visibility_off_rounded),
            onPressed: () => setState(() => _reveal = !_reveal),
          ),
          IconButton(
            tooltip: tr('سجل الأخطاء', 'Mistakes'),
            icon: const Icon(Icons.fact_check_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MistakesScreen()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<QuranSearch>(
        future: _quran,
        initialData: QuranSearch.loaded,
        builder: (context, snap) {
          final quran = snap.data;
          if (quran == null) return const Center(child: CircularProgressIndicator());
          if (_session == null) _begin(quran);
          final session = _session!;
          return Column(
            children: [
              LinearProgressIndicator(value: session.words.isEmpty ? 0 : session.recited / session.words.length),
              if (_source.typed)
                Container(
                  width: double.infinity,
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    tr(
                      'وضع تجريبي: اكتب ما «تتلوه» كلمات ثم أرسل.',
                      'Test mode: type the words you "recite", then send.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final a in _ayahs) _ayah(a, session, colorScheme),
                    if (session.pending != null) _MistakeCard(session: session, onResume: () {
                      setState(session.resume);
                      if (!_source.typed) _toggleMic();
                    }),
                    if (session.finished) _Summary(session: session, onAgain: () => setState(() => _begin(quran))),
                  ],
                ),
              ),
              if (!_source.typed && !session.finished)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_problem != null)
                          Text(_problem!, style: const TextStyle(color: Colors.red)),
                        if (_listening && _heard.isNotEmpty)
                          Text(
                            _heard,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(color: colorScheme.pageNumber),
                          ),
                        if (_listening && _note.isNotEmpty)
                          Text(
                            _note,
                            style: TextStyle(fontSize: 11, color: colorScheme.pageNumber.withValues(alpha: 0.7)),
                          ),
                        const SizedBox(height: 6),
                        if (session.pending == null)
                          FilledButton.icon(
                            onPressed: _toggleMic,
                            icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
                            label: Text(
                              _listening
                                  ? tr('أوقف الاستماع', 'Stop listening')
                                  : tr('ابدأ التسميع', 'Start reciting'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_source.typed && !session.finished)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _box,
                            textDirection: TextDirection.rtl,
                            decoration: InputDecoration(
                              hintText: tr('اكتب ما تتلوه', 'Type what you recite'),
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: tr('أرسل', 'Send'),
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// An ayah with the words recited so far, and the stopping word in red.
  Widget _ayah(Ayah ayah, ReciteSession session, ColorScheme colorScheme) {
    final start = session.words.indexWhere((w) => w.ayah == ayah.number);
    final spans = <InlineSpan>[];
    for (var i = start; i < session.words.length && session.words[i].ayah == ayah.number; i++) {
      final word = session.words[i];
      final TextStyle? style;
      if (i < session.position) {
        style = TextStyle(color: colorScheme.primary);
      } else if (i == session.position && session.pending != null) {
        style = const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, decoration: TextDecoration.underline);
      } else if (i < _tentative && session.pending == null) {
        style = TextStyle(color: colorScheme.primary.withValues(alpha: 0.55));
      } else if (_reveal) {
        style = TextStyle(color: colorScheme.pageNumber);
      } else {
        continue;
      }
      spans.add(TextSpan(text: '${word.text} ', style: style));
    }
    if (spans.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.div.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontFamily: AppTheme.secondaryFontFamily, fontSize: 28, height: 2),
      ),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({required this.session, required this.onResume});

  final ReciteSession session;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final m = session.pending!;
    return Card(
      color: Colors.red.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('توقفتُ هنا', 'Stopped here'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.red),
            ),
            const SizedBox(height: 6),
            Text(
              m.kind == MistakeKind.wrong
                  ? tr(
                      'الكلمة المطلوبة: «${m.word.text}» (الآية ${m.word.ayah}). سمعتُ: «${m.heard}».',
                      'Expected: "${m.word.text}" (ayah ${m.word.ayah}). I heard: "${m.heard}".',
                    )
                  : tr(
                      'فاتتك كلمة «${m.word.text}» (الآية ${m.word.ayah}).',
                      'You left out "${m.word.text}" (ayah ${m.word.ayah}).',
                    ),
              style: const TextStyle(fontSize: 16, height: 1.7),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onResume,
              child: Text(tr('تابع من هذه الكلمة', 'Go on from this word')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.session, required this.onAgain});

  final ReciteSession session;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final n = session.mistakes.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              n == 0 ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.gold,
            ),
            const SizedBox(height: 8),
            Text(
              n == 0
                  ? tr('ما شاء الله! أتممتَها بلا خطأ', 'Mashallah! You finished it without a mistake')
                  : tr('أتممتَها بـ $n من الأخطاء', 'You finished it with $n mistakes'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onAgain,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(tr('أعد التسميع', 'Again')),
                ),
                if (n > 0)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MistakesScreen()),
                    ),
                    icon: const Icon(Icons.fact_check_rounded),
                    label: Text(tr('سجل الأخطاء', 'Mistakes')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The words that went wrong, by surah, with a way back to recite from
/// them.
class MistakesScreen extends StatelessWidget {
  const MistakesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = Provider.of<MistakeLog>(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('سجل أخطائي', 'My mistakes')),
        actions: [
          if (!log.isEmpty)
            IconButton(
              tooltip: tr('مسح السجل', 'Clear the log'),
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: Text(tr('مسح كل الأخطاء المسجّلة؟', 'Clear every recorded mistake?')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(tr('إلغاء', 'Cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(tr('مسح', 'Clear')),
                      ),
                    ],
                  ),
                );
                if (ok == true) log.clear();
              },
            ),
        ],
      ),
      body: log.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  tr(
                    'لا أخطاء مسجّلة. حين تخطئ في كلمة أثناء التسميع تُسجَّل هنا لتنتبه لها.',
                    'No mistakes recorded. A word you get wrong while reciting is kept here so you can watch for it.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.pageNumber),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final surah in log.surahs) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      surahTitle(surah),
                      style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.gold),
                    ),
                  ),
                  for (final m in log.ofSurah(surah))
                    ListTile(
                      title: Text(
                        m.text,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontFamily: AppTheme.secondaryFontFamily, fontSize: 26),
                      ),
                      subtitle: Text(
                        tr(
                          'الآية ${m.ayah}، الكلمة ${m.number} · ${m.skipped ? 'فاتتك' : 'سمعتُ: ${m.heard}'} · ${m.count} مرة',
                          'Ayah ${m.ayah}, word ${m.number} · ${m.skipped ? 'left out' : 'heard: ${m.heard}'} · ${m.count}×',
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: tr('راجع من هذه الآية', 'Recite from this ayah'),
                        icon: const Icon(Icons.mic_rounded),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReciteScreen(surah: m.surah, fromAyah: m.ayah),
                          ),
                        ),
                      ),
                      onLongPress: () => log.remove(m),
                    ),
                ],
              ],
            ),
    );
  }
}
