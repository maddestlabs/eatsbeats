import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

void downloadWebZipImpl(Uint8List bytes, String fileName) {
  try {
    final blob = html.Blob([bytes], 'application/zip');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final name = fileName.endsWith('.eats.zip')
        ? fileName
        : (fileName.endsWith('.zip') ? fileName : '$fileName.eats.zip');
    final anchor = html.AnchorElement()
      ..href = url
      ..download = name
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    debugPrint('Web ZIP download failed: $e');
  }
}

void downloadWebFileImpl(String content, String fileName) {
  try {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'text/x-lua;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement()
      ..href = url
      ..download = fileName.endsWith('.eats.lua') ? fileName : '$fileName.eats.lua'
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    debugPrint('Web download failed: $e');
  }
}

void saveEatsZipFileImpl(Uint8List bytes, String fileName) {
  downloadWebZipImpl(bytes, fileName);
}

void saveEatsLuaFileImpl(String content, String fileName) {
  downloadWebFileImpl(content, fileName);
}

void pickEatsFileWebImpl(
    Function(Uint8List? bytes, String? textContent, String fileName) onFileLoaded) {
  try {
    final uploadInput = html.InputElement()
      ..type = 'file'
      ..accept = '.eats.zip,.zip,.sf2,.wav,.mp3,.mid,.midi,.lua,.eats,.txt,application/zip,application/x-zip-compressed,application/octet-stream,audio/midi,audio/x-midi,text/plain'
      ..style.display = 'none';

    // Must attach to body so iOS Safari / WebKit does not garbage-collect the node while file picker sheet is open
    html.document.body?.children.add(uploadInput);

    void cleanup() {
      try {
        uploadInput.remove();
      } catch (_) {}
    }

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        final name = file.name.toLowerCase();

        final isLikelyBinary = name.endsWith('.zip') ||
            name.endsWith('.eats.zip') ||
            name.endsWith('.sf2') ||
            name.endsWith('.wav') ||
            name.endsWith('.mp3') ||
            name.endsWith('.mid') ||
            name.endsWith('.midi');

        final reader = html.FileReader();

        if (isLikelyBinary) {
          reader.onLoad.listen((e) {
            final result = reader.result;
            Uint8List? bytes;
            if (result is Uint8List) {
              bytes = result;
            } else if (result is ByteBuffer) {
              bytes = result.asUint8List();
            } else if (result is List<int>) {
              bytes = Uint8List.fromList(result);
            } else if (result != null) {
              try {
                bytes = (result as dynamic).asUint8List();
              } catch (_) {
                try {
                  bytes = Uint8List.view(result as dynamic);
                } catch (_) {}
              }
            }

            if (bytes != null && bytes.isNotEmpty) {
              onFileLoaded(bytes, null, file.name);
            }
          });

          reader.onError.listen((err) {
            debugPrint('FileReader binary error: $err');
          });

          reader.readAsArrayBuffer(file);
        } else {
          // Read as ArrayBuffer first to inspect PK zip header or valid UTF-8 string
          reader.onLoad.listen((e) {
            final result = reader.result;
            Uint8List? bytes;
            if (result is Uint8List) {
              bytes = result;
            } else if (result is ByteBuffer) {
              bytes = result.asUint8List();
            } else if (result is List<int>) {
              bytes = Uint8List.fromList(result);
            }

            if (bytes != null && bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
              // PK header: ZIP archive
              onFileLoaded(bytes, null, file.name);
            } else if (bytes != null) {
              try {
                final text = utf8.decode(bytes);
                onFileLoaded(null, text, file.name);
              } catch (_) {
                onFileLoaded(bytes, null, file.name);
              }
            }
          });

          reader.onError.listen((err) {
            debugPrint('FileReader text/fallback error: $err');
          });

          reader.readAsArrayBuffer(file);
        }
      }
      cleanup();
    });

    uploadInput.click();
  } catch (e) {
    debugPrint('Web file picker failed: $e');
  }
}

void initGlobalAudioDropImpl(Function(String fileName, Uint8List bytes) onAudioDropped) {
  try {
    html.document.body?.onDragOver.listen((event) {
      event.preventDefault();
    });

    html.document.body?.onDrop.listen((event) {
      event.preventDefault();
      final files = event.dataTransfer.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        final name = file.name.toLowerCase();
        if (name.endsWith('.wav') ||
            name.endsWith('.mp3') ||
            name.endsWith('.sf2') ||
            name.endsWith('.mid') ||
            name.endsWith('.midi') ||
            name.endsWith('.ogg') ||
            name.endsWith('.flac')) {
          final reader = html.FileReader();
          reader.onLoad.listen((e) {
            final result = reader.result;
            if (result is Uint8List) {
              onAudioDropped(file.name, result);
            } else if (result is ByteBuffer) {
              onAudioDropped(file.name, result.asUint8List());
            } else if (result is List<int>) {
              onAudioDropped(file.name, Uint8List.fromList(result));
            }
          });
          reader.readAsArrayBuffer(file);
        }
      }
    });
  } catch (e) {
    debugPrint('Error setting up web file drop listener: $e');
  }
}

Future<Uint8List?> fetchUrlBytesWebImpl(String url) async {
  try {
    final req = await html.HttpRequest.request(
      url,
      responseType: 'arraybuffer',
    );
    if (req.status == 200 && req.response != null) {
      final ByteBuffer buf = req.response as ByteBuffer;
      return buf.asUint8List();
    }
  } catch (e) {
    debugPrint('Error fetching URL $url: $e');
  }
  return null;
}
