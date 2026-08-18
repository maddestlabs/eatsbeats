import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void downloadWebZipImpl(Uint8List bytes, String fileName) {
  debugPrint('Zip download not supported on VM target');
}

void downloadWebFileImpl(String content, String fileName) {
  Clipboard.setData(ClipboardData(text: content));
}

void pickEatsFileWebImpl(
    Function(Uint8List? bytes, String? textContent, String fileName) onFileLoaded) {
  debugPrint('Web file picking not supported on VM target');
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

