import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'eats_file_helper_stub.dart'
    if (dart.library.html) 'eats_file_helper_web.dart';

class EatsFileHelper {
  /// Save/Download `.eats.zip` binary archive.
  static void saveEatsZipFile(Uint8List zipBytes, String fileName) {
    if (kIsWeb) {
      downloadWebZipImpl(zipBytes, fileName);
    } else {
      debugPrint('Desktop/Mobile zip file saving fallback');
    }
  }

  /// Save/Download legacy `.eats.lua` file.
  static void saveEatsLuaFile(String content, String fileName) {
    if (kIsWeb) {
      downloadWebFileImpl(content, fileName);
    } else {
      Clipboard.setData(ClipboardData(text: content));
    }
  }

  /// Triggers a web file input dialog for picking `.eats.zip`, `.zip`, `.eats.lua`, or `.txt` files.
  static void pickEatsFileWeb(
      Function(Uint8List? zipBytes, String? textContent, String fileName) onFileLoaded) {
    if (kIsWeb) {
      pickEatsFileWebImpl(onFileLoaded);
    }
  }

  /// Backward compatibility for text-only picking.
  static void pickEatsLuaFileWeb(Function(String content, String fileName) onFileLoaded) {
    pickEatsFileWeb((zipBytes, textContent, fileName) {
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

