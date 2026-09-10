import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

Future<void> saveWavFileImpl(Uint8List wavBytes, String filename) async {
  try {
    final cleanName = filename.endsWith('.wav') ? filename : '$filename.wav';
    await FilePicker.saveFile(
      dialogTitle: 'Save Audio Export (.wav)',
      fileName: cleanName,
      bytes: wavBytes,
      type: FileType.custom,
      allowedExtensions: ['wav'],
    );
  } catch (e) {
    debugPrint('[WavExporter] Native saveWavFile failed: $e');
  }
}
