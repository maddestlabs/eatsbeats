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

  /// Save/Download legacy `.eats.lua` file.
  /// Returns the saved absolute file path (or file name on Web), or null if cancelled.
  static Future<String?> saveEatsLuaFile(String content, String fileName) async {
    if (kIsWeb) {
      return downloadWebFileImpl(content, fileName);
    } else {
      return saveEatsLuaFileImpl(content, fileName);
    }
  }

  /// Save/Download Eatscript `.eat` / `.eats` script file.
  /// Returns the saved absolute file path (or file name on Web), or null if cancelled.
  static Future<String?> saveEatScriptFile(String content, String fileName) async {
    final cleanName = fileName.endsWith('.eat') || fileName.endsWith('.eats')
        ? fileName
        : '$fileName.eat';
    return saveEatsLuaFile(content, cleanName);
  }

  /// Triggers file open dialog for `.eats.zip`, `.zip`, `.eats.lua`, `.sf2`, `.wav`, `.mid`, `.midi`, or `.txt` files.
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

  /// Backward compatibility for text-only picking.
  static void pickEatsLuaFileWeb(Function(String content, String fileName) onFileLoaded) {
    pickEatsFile((zipBytes, textContent, fileName) {
      if (textContent != null) {
        onFileLoaded(textContent, fileName);
      }
    });
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
