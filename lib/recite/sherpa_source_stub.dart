import 'speech_model.dart';
import 'speech_source.dart';

/// Whether voice recognition can run on this platform.
bool get sherpaSupported => false;

SpeechSource? createSherpaSource(SpeechModel model) => null;
