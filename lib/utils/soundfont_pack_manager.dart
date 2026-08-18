import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../audio/soundfont_engine.dart';
import 'eats_file_helper.dart';
import 'eats_storage_helper.dart';

class SoundFontPackInfo {
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

  SoundFontPackInfo({
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

class SoundFontPackManager extends ChangeNotifier {
  static final SoundFontPackManager instance = SoundFontPackManager._internal();
  SoundFontPackManager._internal();

  final List<SoundFontPackInfo> _packs = [
    SoundFontPackInfo(
      id: 'generaluser_gs',
      title: 'GeneralUser GS SoundFont v1.471',
      description: 'High-quality Roland GS & General MIDI compatible SoundFont bank by S. Christian Collins (30+ MB, 250+ instruments).',
      url: 'https://raw.githubusercontent.com/JustEnoughLinuxOS/generaluser-gs/main/GeneralUser%20GS%20v1.471.sf2',
      fallbackUrl: 'https://raw.githubusercontent.com/ROCKNIX/generaluser-gs/main/GeneralUser%20GS%20v1.471.sf2',
      fileName: 'GeneralUser_GS.sf2',
      fileSizeMb: 30,
    ),
    SoundFontPackInfo(
      id: 'super_small_font',
      title: 'Super Small SoundFont',
      description: 'Ultra-lightweight 15 KB General MIDI fallback bank (175 presets).',
      url: '',
      fileName: 'super_small_font.sf2',
      fileSizeMb: 1,
      isDownloaded: true,
      statusMessage: 'Bundled',
    ),
  ];

  List<SoundFontPackInfo> get packs => List.unmodifiable(_packs);

  bool _isRestored = false;

  /// Checks persistent storage (IndexedDB on Web, AppData on Windows) for cached SoundFonts
  /// and registers them immediately.
  Future<void> restoreCachedPacks({bool force = false}) async {
    if (_isRestored && !force) return;
    _isRestored = true;

    for (final pack in _packs) {
      if (pack.url.isNotEmpty && !pack.isDownloaded) {
        try {
          final cachedBytes = await EatsStorageHelper.loadSoundFont(pack.fileName);
          if (cachedBytes != null && cachedBytes.isNotEmpty) {
            final loaded = SoundFontEngine.instance.registerSoundFont(pack.fileName, cachedBytes);
            if (loaded) {
              if (pack.id == 'generaluser_gs') {
                SoundFontEngine.instance.registerSoundFont('GeneralUser GS', cachedBytes);
                SoundFontEngine.instance.registerSoundFont('GeneralUser', cachedBytes);
              }
              pack.isDownloaded = true;
              pack.downloadProgress = 1.0;
              pack.statusMessage = 'Installed (Cached)';
              debugPrint('SoundFontPackManager: Restored "${pack.title}" from persistent storage cache.');
            }
          }
        } catch (e) {
          debugPrint('SoundFontPackManager: Error restoring cached pack ${pack.id}: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<bool> downloadAndInstallPack(SoundFontPackInfo pack) async {
    if (pack.isDownloading || pack.isDownloaded) return true;

    try {
      pack.isDownloading = true;
      pack.downloadProgress = 0.1;
      pack.statusMessage = 'Downloading ${pack.title}...';
      notifyListeners();

      debugPrint('SoundFontPackManager: Fetching SoundFont from ${pack.url}...');
      Uint8List? sfBytes = await EatsFileHelper.fetchUrlBytes(pack.url);

      if ((sfBytes == null || sfBytes.isEmpty) && pack.fallbackUrl.isNotEmpty) {
        debugPrint('SoundFontPackManager: Primary URL failed, fetching fallback ${pack.fallbackUrl}...');
        pack.downloadProgress = 0.3;
        pack.statusMessage = 'Retrying via mirror...';
        notifyListeners();
        sfBytes = await EatsFileHelper.fetchUrlBytes(pack.fallbackUrl);
      }

      if (sfBytes == null || sfBytes.isEmpty) {
        pack.isDownloading = false;
        pack.statusMessage = 'Download failed (Network error)';
        notifyListeners();
        return false;
      }

      pack.downloadProgress = 0.8;
      pack.statusMessage = 'Decoding & Registering SoundFont...';
      notifyListeners();

      final loaded = SoundFontEngine.instance.registerSoundFont(pack.fileName, sfBytes);
      if (loaded) {
        if (pack.id == 'generaluser_gs') {
          SoundFontEngine.instance.registerSoundFont('GeneralUser GS', sfBytes);
          SoundFontEngine.instance.registerSoundFont('GeneralUser', sfBytes);
        }

        // Persist to storage (IndexedDB on Web, AppData on Windows)
        await EatsStorageHelper.saveSoundFont(pack.fileName, sfBytes);

        pack.isDownloaded = true;
        pack.isDownloading = false;
        pack.downloadProgress = 1.0;
        pack.statusMessage = 'Installed';
        notifyListeners();
        debugPrint('SoundFontPackManager: Successfully installed and cached SoundFont pack "${pack.title}"!');
        return true;
      } else {
        pack.isDownloading = false;
        pack.statusMessage = 'Failed to decode SoundFont binary';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('SoundFontPackManager error: $e');
      pack.isDownloading = false;
      pack.statusMessage = 'Error: $e';
      notifyListeners();
      return false;
    }
  }
}
