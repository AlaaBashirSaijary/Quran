/// The offline recogniser. It needs the phone's native libraries, so on the
/// web there is none.
library;

export 'sherpa_source_stub.dart' if (dart.library.io) 'sherpa_source_io.dart';
