import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../audio/soundfont_engine.dart';
import 'eats_file_helper.dart';

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
    ),
  ];

  List<SoundFontPackInfo> get packs => List.unmodifiable(_packs);

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
        SoundFontEngine.instance.registerSoundFont('GeneralUser GS', sfBytes);
        SoundFontEngine.instance.registerSoundFont('GeneralUser', sfBytes);

        pack.isDownloaded = true;
        pack.isDownloading = false;
        pack.downloadProgress = 1.0;
        pack.statusMessage = 'Installed';
        notifyListeners();
        debugPrint('SoundFontPackManager: Successfully installed SoundFont pack "${pack.title}"!');
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
