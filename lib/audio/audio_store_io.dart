import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> audioFolder() async {
  try {
    final base = await getApplicationSupportDirectory();
    return '${base.path}/recitations';
  } catch (_) {
    return null;
  }
}

Future<bool> fileExists(String path) => File(path).exists();

/// Writes through a temporary file, so an interrupted download never
/// leaves a partial file that looks complete.
Future<void> writeFile(String path, Uint8List bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final temp = File('$path.part');
  await temp.writeAsBytes(bytes, flush: true);
  await temp.rename(path);
}

Future<int> folderSize(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) return 0;
  var total = 0;
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File) total += await entity.length();
  }
  return total;
}

Future<void> deleteFile(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}

Future<void> deleteFolder(String path) async {
  final dir = Directory(path);
  if (await dir.exists()) await dir.delete(recursive: true);
}

Future<String?> dataFolder(String name) async {
  try {
    final base = await getApplicationSupportDirectory();
    return '${base.path}/$name';
  } catch (_) {
    return null;
  }
}

Future<String?> readText(String path) async {
  final file = File(path);
  return await file.exists() ? file.readAsString() : null;
}

Future<Uint8List?> readBytes(String path) async {
  final file = File(path);
  return await file.exists() ? file.readAsBytes() : null;
}

/// How many files are saved directly under [path].
Future<int> fileCount(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) return 0;
  var n = 0;
  await for (final entity in dir.list()) {
    if (entity is File && !entity.path.endsWith('.part')) n++;
  }
  return n;
}

/// Adds [bytes] to the end of the file at [path], creating it when needed.
Future<void> appendFile(String path, List<int> bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, mode: FileMode.append, flush: true);
}

/// Renames [from] to [to], replacing a file that is already there.
Future<void> renameFile(String from, String to) async {
  final target = File(to);
  if (await target.exists()) await target.delete();
  await File(from).rename(to);
}

Future<int> fileLength(String path) async {
  final file = File(path);
  return await file.exists() ? file.length() : 0;
}

/// The SHA-256 of the file at [path] as hex, read in pieces.
Future<String?> fileSha256(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return (await sha256.bind(file.openRead()).first).toString();
}
