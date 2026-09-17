import 'package:flutter/foundation.dart';

import 'eats_file_helper_stub.dart'
    if (dart.library.html) 'eats_file_helper_web.dart';

class EatsFileHelper {
  /// Save/Download `.eats.zip` binary archive across Web, Desktop (Windows/macOS/Linux), and Mobile.
  /// Returns the saved absolute file path (or file name on Web), or null if cancelled.
  static Future<String?> saveEatsZipFile(Uint8List zipBytes, String fileName) async {
    if (kIsWeb) {
      return downloadWebZipImpl(zipBytes, fileName);
    } else {
      return saveEatsZipFileImpl(zipBytes, fileName);
    }
  }

  /// Save/Download Eatscript `.eats` script file.
  /// Returns the saved absolute file path (or file name on Web), or null if cancelled.
  static Future<String?> saveEatScriptFile(String content, String fileName) async {
    final cleanName = fileName.endsWith('.eats')
        ? fileName
        : '$fileName.eats';
    if (kIsWeb) {
      return downloadWebFileImpl(content, cleanName);
    } else {
      return saveEatsFileImpl(content, cleanName);
    }
  }

  /// Alias for saving an Eatsbeats script or project file.
  static Future<String?> saveEatsFile(String content, String fileName) =>
      saveEatScriptFile(content, fileName);

  /// Triggers file open dialog for `.eats.zip`, `.zip`, `.eats`, `.sf2`, `.wav`, `.mid`, `.midi`, or `.txt` files.
  /// Works across Web, iOS, Android, and Desktop (Windows, macOS, Linux).
  static void pickEatsFile(
      Function(Uint8List? zipBytes, String? textContent, String fileName) onFileLoaded) {
    pickEatsFileWebImpl(onFileLoaded);
  }

  /// Backward compatibility alias.
  static void pickEatsFileWeb(
      Function(Uint8List? zipBytes, String? textContent, String fileName) onFileLoaded) {
    pickEatsFile(onFileLoaded);
  }


  /// Initializes global drag & drop listener for audio files (.wav, .mp3).
  static void initGlobalAudioDrop(Function(String fileName, Uint8List fileBytes) onAudioDropped) {
    if (kIsWeb) {
      initGlobalAudioDropImpl(onAudioDropped);
    }
  }

  /// Downloads binary bytes from an HTTP URL.
  static Future<Uint8List?> fetchUrlBytes(String url) async {
    return fetchUrlBytesWebImpl(url);
  }
}
