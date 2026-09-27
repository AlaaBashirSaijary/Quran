/// Where downloaded recitations are kept. Downloads need a file system, so
/// on the web every call reports that nothing is stored.
library;

export 'audio_store_stub.dart' if (dart.library.io) 'audio_store_io.dart';
