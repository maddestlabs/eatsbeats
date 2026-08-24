import 'dart:async';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import '../audio/convolver_engine.dart';
import '../audio/sampler_engine.dart';
import 'eats_file_helper.dart';

class IrPackInfo {
  final String id;
  final String title;
  final String description;
  final String zipUrl;
  final int fileSizeMb;
  bool isDownloaded;

  IrPackInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.zipUrl,
    required this.fileSizeMb,
    this.isDownloaded = false,
  });
}

class IrPackManager {
  static final IrPackManager instance = IrPackManager._internal();
  IrPackManager._internal();

  final List<IrPackInfo> _catalog = [
    IrPackInfo(
      id: 'sadiquecat_ir_collection',
      title: 'Sadiquecat Impulse Response Collection',
      description: '100+ Professional acoustic impulse response samples (Cathedrals, Plates, Springs, Chambers & Rooms).',
      zipUrl: 'audio/ir/43771__sadiquecat__impulse-response.zip',
      fileSizeMb: 115,
    ),
  ];

  List<IrPackInfo> get catalog => List.unmodifiable(_catalog);

  /// Downloads, unzips, and registers impulse response WAV samples from a designated zip pack.
  Future<bool> downloadAndInstallPack(
    IrPackInfo pack, {
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1, 'Downloading IR Pack ZIP...');
      debugPrint('IrPackManager: Downloading ${pack.zipUrl}...');

      Uint8List? zipBytes = await EatsFileHelper.fetchUrlBytes(pack.zipUrl);
      if (zipBytes == null || zipBytes.isEmpty) {
        final fallbackUrl = 'https://raw.githubusercontent.com/maddestlabs/eatsbeats/main/web/${pack.zipUrl}';
        debugPrint('IrPackManager: Primary fetch failed, trying fallback: $fallbackUrl');
        zipBytes = await EatsFileHelper.fetchUrlBytes(fallbackUrl);
      }

      if (zipBytes == null || zipBytes.isEmpty) {
        onProgress?.call(0.0, 'Download failed (Network error)');
        return false;
      }


      onProgress?.call(0.5, 'Unzipping Impulse Responses...');
      debugPrint('IrPackManager: Unzipping archive (${zipBytes.length} bytes)...');

      final archive = ZipDecoder().decodeBytes(zipBytes);
      int extractedCount = 0;

      for (int i = 0; i < archive.files.length; i++) {
        final file = archive.files[i];
        if (!file.isFile) continue;

        final fileName = file.name.replaceAll('\\', '/').split('/').last;
        if (fileName.toLowerCase().endsWith('.wav')) {
          final content = file.content as List<int>;
          final wavBytes = Uint8List.fromList(content);

          final decoded = SamplerEngine.decodeWav(wavBytes);
          if (decoded != null && decoded.samples.isNotEmpty) {
            ConvolverEngine.instance.registerIrSample(fileName, decoded.samples);
            extractedCount++;
          }
        }

        if (i % 5 == 0) {
          final progress = 0.5 + (0.5 * (i / archive.files.length));
          onProgress?.call(progress, 'Extracting IR: $fileName');
        }
      }

      pack.isDownloaded = true;
      onProgress?.call(1.0, 'Installed $extractedCount Impulse Responses!');
      debugPrint('IrPackManager: Successfully installed $extractedCount IRs from ${pack.title}');
      return true;
    } catch (e) {
      debugPrint('IrPackManager error installing ${pack.id}: $e');
      onProgress?.call(0.0, 'Error: $e');
      return false;
    }
  }
}
