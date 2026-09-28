import 'dart:typed_data';

/// The folder recitations are saved in, or null when downloads are not
/// possible.
Future<String?> audioFolder() async => null;

Future<bool> fileExists(String path) async => false;

Future<void> writeFile(String path, Uint8List bytes) async {}

/// Total size in bytes of the files under [path].
Future<int> folderSize(String path) async => 0;

Future<void> deleteFolder(String path) async {}

/// A folder for the app's downloads named [name], or null on the web.
Future<String?> dataFolder(String name) async => null;

Future<String?> readText(String path) async => null;
