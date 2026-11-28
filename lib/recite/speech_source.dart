import 'dart:async';

/// What a recogniser hears: the words so far in the current utterance, and
/// whether it is finished (the reciter paused).
class SpeechResult {
  const SpeechResult(this.text, {required this.isFinal});

  final String text;
  final bool isFinal;
}

/// Something that turns the reciter's voice into text.
abstract class SpeechSource {
  /// Whether it is the typed stand-in, which has no microphone: the screen
  /// then offers a box to type what is "recited".
  bool get typed;

  Stream<SpeechResult> get results;

  /// Short notes on how it is doing (for example how long the last
  /// recognition took), shown small on the screen.
  Stream<String> get notes;

  /// Starts listening.
  Future<void> start();

  /// Stops listening.
  Future<void> stop();

  void dispose();
}

/// A stand-in that takes the text from a box instead of the voice, for
/// trying the screen before a recogniser is added.
class TypedSpeechSource implements SpeechSource {
  final _controller = StreamController<SpeechResult>.broadcast();

  @override
  bool get typed => true;

  @override
  Stream<SpeechResult> get results => _controller.stream;

  /// Gives a typed text as if it was heard: a final result.
  void submit(String text) => _controller.add(SpeechResult(text, isFinal: true));

  @override
  Stream<String> get notes => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() => _controller.close();
}
