import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'eats_file_helper.dart';
import 'eats_storage_helper.dart';

class AudioToMidiPackInfo {
  final String id;
  final String title;
  final String description;
  final String url;
  final String fallbackUrl;
  final String fileName;
  final int fileSizeMb;
  bool isDownloaded;
  bool isDownloading;
  double downloadProgress;
  String statusMessage;

  AudioToMidiPackInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    this.fallbackUrl = '',
    required this.fileName,
    required this.fileSizeMb,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.statusMessage = '',
  });
}

class AudioToMidiPackManager extends ChangeNotifier {
  static final AudioToMidiPackManager instance = AudioToMidiPackManager._internal();
  AudioToMidiPackManager._internal();

  final List<AudioToMidiPackInfo> _packs = [
    AudioToMidiPackInfo(
      id: 'basic_pitch_neural',
      title: 'Basic Pitch Polyphonic Neural Model',
      description: 'Deep-learning CNN polyphonic transcription model by Spotify Audio Intelligence Lab (~18 MB).',
      url: 'https://raw.githubusercontent.com/spotify/basic-pitch/main/basic_pitch/saved_models/icassp_2022/nmp.onnx',
      fallbackUrl: 'https://huggingface.co/spotify/basic-pitch/resolve/main/model.onnx',
      fileName: 'basic_pitch_model.onnx',
      fileSizeMb: 18,
    ),
  ];

  List<AudioToMidiPackInfo> get packs => List.unmodifiable(_packs);

  bool _isRestored = false;
  Uint8List? _cachedModelBytes;

  Uint8List? get cachedModelBytes => _cachedModelBytes;
  bool get hasNeuralModel => _cachedModelBytes != null && _cachedModelBytes!.isNotEmpty;

  /// Restores downloaded status from disk on startup
  Future<void> restoreDownloadedStatus() async {
    if (_isRestored) return;
    _isRestored = true;

    for (final pack in _packs) {
      final packFileName = pack.fileName;
      if (packFileName.isEmpty) continue;

      try {
        final exists = await EatsStorageHelper.hasModel(packFileName);
        if (exists) {
          pack.isDownloaded = true;
          pack.statusMessage = 'Installed';
          
          // Cache in memory for fast inference
          final bytes = await EatsStorageHelper.loadModel(packFileName);
          if (bytes != null && bytes.isNotEmpty) {
            _cachedModelBytes = bytes;
          }
        }
      } catch (e) {
        debugPrint('[AudioToMidiPackManager] Error restoring pack status: $e');
      }
    }
    notifyListeners();
  }

  /// Downloads the specified model pack with live progress updates
  Future<bool> downloadPack(String packId) async {
    final packIndex = _packs.indexWhere((p) => p.id == packId);
    if (packIndex == -1) return false;

    final pack = _packs[packIndex];
    if (pack.isDownloaded || pack.isDownloading) return true;

    pack.isDownloading = true;
    pack.downloadProgress = 0.1;
    pack.statusMessage = 'Connecting to neural model repository...';
    notifyListeners();

    try {
      debugPrint('[AudioToMidiPackManager] Fetching model from ${pack.url}...');
      pack.downloadProgress = 0.2;
      pack.statusMessage = 'Downloading neural model weights (${pack.fileSizeMb} MB)...';
      notifyListeners();

      Uint8List? bytes = await EatsFileHelper.fetchUrlBytes(pack.url);

      if ((bytes == null || bytes.isEmpty) && pack.fallbackUrl.isNotEmpty) {
        debugPrint('[AudioToMidiPackManager] Primary fetch failed, trying fallback: ${pack.fallbackUrl}');
        pack.downloadProgress = 0.4;
        pack.statusMessage = 'Retrying via mirror CDN...';
        notifyListeners();
        bytes = await EatsFileHelper.fetchUrlBytes(pack.fallbackUrl);
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Network download returned empty response');
      }

      pack.downloadProgress = 0.85;
      pack.statusMessage = 'Saving neural weights to local storage...';
      notifyListeners();

      // Persist model to storage
      await EatsStorageHelper.saveModel(pack.fileName, bytes);

      _cachedModelBytes = bytes;
      pack.isDownloaded = true;
      pack.isDownloading = false;
      pack.downloadProgress = 1.0;
      pack.statusMessage = 'Installed (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB)';
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('[AudioToMidiPackManager] Failed to download pack $packId: $e');
      pack.isDownloading = false;
      pack.downloadProgress = 0.0;
      pack.statusMessage = 'Download failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Removes the downloaded model pack from disk
  Future<void> removePack(String packId) async {
    final packIndex = _packs.indexWhere((p) => p.id == packId);
    if (packIndex == -1) return;

    final pack = _packs[packIndex];
    if (pack.fileName.isNotEmpty) {
      await EatsStorageHelper.deleteModel(pack.fileName);
    }
    _cachedModelBytes = null;
    pack.isDownloaded = false;
    pack.statusMessage = '';
    pack.downloadProgress = 0.0;
    notifyListeners();
  }
}
