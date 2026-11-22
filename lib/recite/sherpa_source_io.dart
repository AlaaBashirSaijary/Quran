import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'speech_model.dart';
import 'speech_source.dart';

/// Whether voice recognition can run here: on Android only for now.
bool get sherpaSupported => !kIsWeb && Platform.isAndroid;

SpeechSource? createSherpaSource(SpeechModel model) =>
    sherpaSupported && model.ready ? SherpaSpeechSource(model) : null;

const _rate = 16000;

/// Seconds of speech between the guesses shown while the reciter is still
/// speaking.
const _partialEvery = 1.5;

class _Paths {
  const _Paths(this.encoder, this.decoder, this.tokens, this.vad);
  final String encoder, decoder, tokens, vad;
}

/// Hears the microphone, cuts the speech into phrases at the pauses (Silero
/// VAD) and turns each into text with the Whisper model, all on the phone.
/// The work happens in its own isolate so the screen stays smooth.
class SherpaSpeechSource implements SpeechSource {
  SherpaSpeechSource(this._model);

  final SpeechModel _model;
  final _controller = StreamController<SpeechResult>.broadcast();
  final _recorder = AudioRecorder();

  Isolate? _isolate;
  SendPort? _worker;
  ReceivePort? _inbox;
  Completer<void>? _ready;
  StreamSubscription<Uint8List>? _mic;

  @override
  bool get typed => false;

  @override
  Stream<SpeechResult> get results => _controller.stream;

  Future<void> _spawn() async {
    if (_worker != null) return;
    if (_ready != null) return _ready!.future;
    final ready = _ready = Completer<void>();
    final inbox = _inbox = ReceivePort();
    inbox.listen((message) {
      if (message is SendPort) {
        _worker = message;
      } else if (message == 'ready') {
        if (!ready.isCompleted) ready.complete();
      } else if (message is List && message.first == 'text') {
        _controller.add(SpeechResult(message[1] as String, isFinal: message[2] as bool));
      } else if (message is List && message.first == 'error') {
        final error = message[1] as String;
        if (!ready.isCompleted) ready.completeError(error);
        _controller.addError(error);
      }
    });
    final paths = _Paths(
      _model.pathOf('quran-base-encoder.int8.onnx'),
      _model.pathOf('quran-base-decoder.int8.onnx'),
      _model.pathOf('quran-base-tokens.txt'),
      _model.pathOf('silero_vad.onnx'),
    );
    _isolate = await Isolate.spawn(_work, [inbox.sendPort, paths]);
    try {
      await ready.future;
    } catch (_) {
      _kill();
      rethrow;
    }
  }

  void _kill() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _worker = null;
    _inbox?.close();
    _inbox = null;
    _ready = null;
  }

  @override
  Future<void> start() async {
    if (_mic != null) return;
    try {
      if (!await _recorder.hasPermission()) {
        throw 'لم يُسمح باستخدام الميكروفون. فعّله من إعدادات التطبيق.';
      }
      await _spawn();
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _rate,
          numChannels: 1,
        ),
      );
      _mic = stream.listen((bytes) {
        _worker?.send(TransferableTypedData.fromList([bytes]));
      });
    } catch (e) {
      _controller.addError('$e');
    }
  }

  @override
  Future<void> stop() async {
    final mic = _mic;
    _mic = null;
    await mic?.cancel();
    if (await _recorder.isRecording()) await _recorder.stop();
    // Whatever was being said is finished off as a final result.
    _worker?.send('flush');
  }

  @override
  void dispose() {
    _mic?.cancel();
    _recorder.dispose();
    _worker?.send('exit');
    Future.delayed(const Duration(seconds: 2), _kill);
    _controller.close();
  }
}

/// The isolate: model in, text out.
void _work(List<Object> args) {
  final out = args[0] as SendPort;
  final paths = args[1] as _Paths;
  final inbox = ReceivePort();
  sherpa.OfflineRecognizer? recognizer;
  sherpa.VoiceActivityDetector? vad;
  try {
    sherpa.initBindings();
    recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: paths.encoder,
            decoder: paths.decoder,
            language: 'ar',
            task: 'transcribe',
          ),
          tokens: paths.tokens,
          numThreads: 2,
          debug: false,
        ),
      ),
    );
    vad = sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: paths.vad,
          minSilenceDuration: 0.6,
          minSpeechDuration: 0.2,
          maxSpeechDuration: 20,
        ),
        sampleRate: _rate,
        numThreads: 1,
        debug: false,
      ),
      bufferSizeInSeconds: 30,
    );
  } catch (e) {
    out.send(['error', 'تعذّر تشغيل نموذج الصوت: $e']);
    return;
  }

  String decode(Float32List samples) {
    final stream = recognizer!.createStream();
    try {
      // Whisper stops a phrase at a token budget per second; the default is
      // too small for fast recitation.
      stream.setOption(key: 'max_tokens_per_second', value: '30');
      stream.acceptWaveform(samples: samples, sampleRate: _rate);
      recognizer.decode(stream);
      return recognizer.getResult(stream).text.trim();
    } finally {
      stream.free();
    }
  }

  // The samples of the phrase being spoken, for the guesses shown before
  // the pause that ends it.
  var phrase = <double>[];
  var sinceGuess = 0;

  void sendFinals() {
    final v = vad!;
    while (!v.isEmpty()) {
      final text = decode(v.front().samples);
      v.pop();
      out.send(['text', text, true]);
      phrase = [];
      sinceGuess = 0;
    }
  }

  void hear(Float32List samples) {
    final v = vad!;
    v.acceptWaveform(samples);
    if (v.isDetected()) {
      phrase.addAll(samples);
      sinceGuess += samples.length;
      if (sinceGuess >= _partialEvery * _rate && phrase.length < 25 * _rate) {
        sinceGuess = 0;
        out.send(['text', decode(Float32List.fromList(phrase)), false]);
      }
    }
    sendFinals();
  }

  inbox.listen((message) {
    try {
      if (message is TransferableTypedData) {
        final bytes = message.materialize().asUint8List();
        final count = bytes.length ~/ 2;
        final view = ByteData.sublistView(bytes);
        final samples = Float32List(count);
        for (var i = 0; i < count; i++) {
          samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
        }
        hear(samples);
      } else if (message == 'flush') {
        vad!.flush();
        sendFinals();
        vad.reset();
        phrase = [];
        sinceGuess = 0;
      } else if (message == 'exit') {
        vad?.free();
        recognizer?.free();
        inbox.close();
      }
    } catch (e) {
      out.send(['error', '$e']);
    }
  });
  out.send(inbox.sendPort);
  out.send('ready');
}
