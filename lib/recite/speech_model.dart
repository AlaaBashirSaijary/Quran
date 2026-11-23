import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../audio/audio_store.dart';

/// Where the offline speech model is published.
const speechModelBase =
    'https://github.com/AlaaBashirSaijary/Quran/releases/download/speech-model-v1/';

/// The files the recogniser needs, by the names they have in the release.
const speechModelFiles = [
  'quran-base-encoder.int8.onnx',
  'quran-base-decoder.int8.onnx',
  'quran-base-tokens.txt',
  'silero_vad.onnx',
];

enum SpeechModelState { unsupported, missing, downloading, preparing, ready }

/// Where the full builds carry the model inside the app. The light builds
/// leave it out and download it instead.
const speechModelAssetDir = 'assets/speech_model/';

Future<Uint8List?> _bundledFile(String name) async {
  try {
    final data = await rootBundle.load('$speechModelAssetDir$name');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (_) {
    return null;
  }
}

/// The offline speech model on the phone: downloads it once (about 108 MB),
/// checks every file against the sizes and hashes in the release's
/// manifest, and tells whether it is ready.
class SpeechModel extends ChangeNotifier {
  SpeechModel({
    http.Client? client,
    Future<String?>? folder,
    this.baseUrl = speechModelBase,
    Future<Uint8List?> Function(String name)? bundled,
  }) : _bundled = bundled ?? _bundledFile,
       _client = client ?? http.Client(),
       _folderFuture = folder ?? dataFolder('speech_model');

  final http.Client _client;
  final Future<String?> _folderFuture;
  final String baseUrl;
  final Future<Uint8List?> Function(String name) _bundled;

  /// Whether the app carries the model inside it (no download needed).
  bool bundledModel = false;

  String? _folder;
  var state = SpeechModelState.missing;

  /// Share downloaded so far, 0 to 1.
  double progress = 0;
  String? error;
  var _cancel = false;

  /// Reads what is on the phone.
  Future<void> load() async {
    _folder = await _folderFuture;
    if (_folder == null) {
      state = SpeechModelState.unsupported;
    } else if (state != SpeechModelState.downloading && state != SpeechModelState.preparing) {
      bundledModel = await _bundled(speechModelFiles[2]) != null;
      if (await _complete()) {
        state = SpeechModelState.ready;
      } else if (bundledModel) {
        await _prepare();
        return;
      } else {
        state = SpeechModelState.missing;
      }
    }
    notifyListeners();
  }

  /// Copies the model that came with the app to the phone's storage, where
  /// the recogniser can open it as files. Done once.
  Future<void> _prepare() async {
    state = SpeechModelState.preparing;
    progress = 0;
    error = null;
    notifyListeners();
    try {
      await deleteFile('$_folder/ok');
      for (var i = 0; i < speechModelFiles.length; i++) {
        final name = speechModelFiles[i];
        final bytes = await _bundled(name);
        if (bytes == null) throw 'missing $name in the app';
        await writeFile('$_folder/$name', bytes);
        progress = (i + 1) / speechModelFiles.length;
        notifyListeners();
      }
      await writeFile('$_folder/ok', Uint8List.fromList(utf8.encode('ok')));
      state = SpeechModelState.ready;
    } catch (e) {
      error = '$e';
      state = SpeechModelState.missing;
    }
    notifyListeners();
  }

  Future<bool> _complete() async {
    for (final name in speechModelFiles) {
      if (!await fileExists('$_folder/$name')) return false;
    }
    return fileExists('$_folder/ok');
  }

  /// Path of a model file; only meaningful when [state] is ready.
  String pathOf(String name) => '$_folder/$name';

  bool get ready => state == SpeechModelState.ready;

  /// Downloads every file, resuming nothing: a file that fails its check is
  /// downloaded again on the next try.
  Future<void> download() async {
    if (state == SpeechModelState.downloading || _folder == null) return;
    state = SpeechModelState.downloading;
    progress = 0;
    error = null;
    _cancel = false;
    notifyListeners();
    try {
      final res = await _client.get(Uri.parse('${baseUrl}manifest.json'));
      if (res.statusCode != 200) throw 'manifest ${res.statusCode}';
      final manifest = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final files = (manifest['files'] ?? manifest) as Map<String, dynamic>;
      final plan = <String, ({int bytes, String sha256})>{};
      var total = 0;
      for (final name in speechModelFiles) {
        final info = files[name] as Map<String, dynamic>?;
        if (info == null) throw 'missing $name in the manifest';
        final entry = (bytes: info['bytes'] as int, sha256: info['sha256'] as String);
        plan[name] = entry;
        total += entry.bytes;
      }
      await deleteFile('$_folder/ok');
      var done = 0;
      for (final name in speechModelFiles) {
        final want = plan[name]!;
        final path = '$_folder/$name';
        if (await fileExists(path) &&
            await fileLength(path) == want.bytes &&
            await fileSha256(path) == want.sha256) {
          done += want.bytes;
          progress = done / total;
          notifyListeners();
          continue;
        }
        final temp = '$path.part';
        await deleteFile(temp);
        final request = http.Request('GET', Uri.parse('$baseUrl$name'));
        final response = await _client.send(request);
        if (response.statusCode != 200) throw '$name ${response.statusCode}';
        var got = 0;
        await for (final chunk in response.stream) {
          if (_cancel) throw 'cancelled';
          await appendFile(temp, chunk);
          got += chunk.length;
          progress = (done + got) / total;
          notifyListeners();
        }
        if (got != want.bytes || await fileSha256(temp) != want.sha256) {
          await deleteFile(temp);
          throw '$name failed its check';
        }
        await renameFile(temp, path);
        done += want.bytes;
      }
      await writeFile('$_folder/ok', Uint8List.fromList(utf8.encode('ok')));
      state = SpeechModelState.ready;
    } catch (e) {
      error = '$e';
      state = SpeechModelState.missing;
    }
    notifyListeners();
  }

  void cancel() => _cancel = true;

  Future<void> delete() async {
    if (_folder == null) return;
    await deleteFolder(_folder!);
    state = SpeechModelState.missing;
    progress = 0;
    notifyListeners();
  }
}
