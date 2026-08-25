import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void downloadWebZipImpl(Uint8List bytes, String fileName) {
  saveEatsZipFileImpl(bytes, fileName);
}

void downloadWebFileImpl(String content, String fileName) {
  saveEatsLuaFileImpl(content, fileName);
}

Future<void> saveEatsZipFileImpl(Uint8List zipBytes, String fileName) async {
  try {
    final defaultName = fileName.endsWith('.eats.zip')
        ? fileName
        : (fileName.endsWith('.zip') ? fileName : '$fileName.eats.zip');

    await FilePicker.saveFile(
      fileName: defaultName,
      bytes: zipBytes,
    );
  } catch (e) {
    debugPrint('Native saveEatsZipFile failed: $e');
  }
}

Future<void> saveEatsLuaFileImpl(String content, String fileName) async {
  try {
    final defaultName = fileName.endsWith('.eats.lua') ? fileName : '$fileName.eats.lua';
    final bytes = Uint8List.fromList(utf8.encode(content));

    await FilePicker.saveFile(
      fileName: defaultName,
      bytes: bytes,
    );
  } catch (e) {
    debugPrint('Native saveEatsLuaFile failed: $e');
    Clipboard.setData(ClipboardData(text: content));
  }
}

Future<void> pickEatsFileWebImpl(
    Function(Uint8List? bytes, String? textContent, String fileName) onFileLoaded) async {
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'lua', 'sf2', 'wav', 'mp3', 'mid', 'midi', 'txt', 'eats'],
    );

    if (files.isNotEmpty) {
      final pickedFile = files.first;
      Uint8List? bytes;

      if (pickedFile.path != null) {
        final file = io.File(pickedFile.path!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final name = pickedFile.name.toLowerCase();
        final isZip = name.endsWith('.zip') ||
            name.endsWith('.eats.zip') ||
            (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B);

        final isAudioOrSf2OrMidi =
            name.endsWith('.sf2') || name.endsWith('.wav') || name.endsWith('.mp3') || name.endsWith('.mid') || name.endsWith('.midi');

        if (isZip || isAudioOrSf2OrMidi) {
          onFileLoaded(bytes, null, pickedFile.name);
        } else {
          try {
            final text = utf8.decode(bytes);
            onFileLoaded(null, text, pickedFile.name);
          } catch (_) {
            onFileLoaded(bytes, null, pickedFile.name);
          }
        }
      }
    }
  } catch (e) {
    debugPrint('Native pickEatsFile failed: $e');
  }
}

void initGlobalAudioDropImpl(Function(String fileName, Uint8List bytes) onAudioDropped) {
  debugPrint('Global audio drop not supported on VM target');
}

Future<Uint8List?> fetchUrlBytesWebImpl(String url) async {
  io.HttpClient? client;
  try {
    client = io.HttpClient();
    final uri = Uri.parse(url);
    final request = await client.getUrl(uri);
    request.followRedirects = true;
    request.maxRedirects = 10;
    final response = await request.close();
    if (response.statusCode == 200) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } else {
      debugPrint('HTTP error ${response.statusCode} fetching $url');
    }
  } catch (e) {
    debugPrint('Error fetching URL $url on VM target: $e');
  } finally {
    client?.close();
  }
  return null;
}
