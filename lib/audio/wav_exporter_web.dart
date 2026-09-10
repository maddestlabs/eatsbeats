import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

Future<void> saveWavFileImpl(Uint8List wavBytes, String filename) async {
  try {
    final cleanName = filename.endsWith('.wav') ? filename : '$filename.wav';
    final blob = html.Blob([wavBytes], 'audio/wav');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement()
      ..href = url
      ..download = cleanName;
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    debugPrint('Web download error: $e');
  }
}
