import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'platform_env_helper.dart';

class EatsStorageHelperImpl {
  static io.Directory? _baseDir;
  static Map<String, dynamic>? _cachedSettings;

  // In-memory test isolation maps to prevent test runner disk race conditions
  static final Map<String, dynamic> _testSettings = {};
  static final Map<String, Uint8List> _testSoundFonts = {};
  static String? _testSessionLua;

  static bool get _isTest => PlatformEnvHelper.isFlutterTest;

  static io.Directory _getBaseDirectory() {
    if (_baseDir != null) return _baseDir!;

    String path;
    if (io.Platform.isWindows) {
      final appData = io.Platform.environment['APPDATA'] ??
          io.Platform.environment['LOCALAPPDATA'] ??
          io.Directory.current.path;
      path = '$appData/Eatsbits';
    } else if (io.Platform.isMacOS) {
      final home = io.Platform.environment['HOME'] ?? '.';
      path = '$home/Library/Application Support/Eatsbits';
    } else if (io.Platform.isLinux) {
      final xdg = io.Platform.environment['XDG_DATA_HOME'];
      if (xdg != null && xdg.isNotEmpty) {
        path = '$xdg/eatsbits';
      } else {
        final home = io.Platform.environment['HOME'] ?? '.';
        path = '$home/.local/share/eatsbits';
      }
    } else {
      path = '${io.Directory.systemTemp.path}/eatsbits';
    }

    _baseDir = io.Directory(path);
    if (!_baseDir!.existsSync()) {
      try {
        _baseDir!.createSync(recursive: true);
      } catch (e) {
        debugPrint('Error creating Eatsbits storage directory: $e');
      }
    }
    return _baseDir!;
  }

  static io.File _getSettingsFile() {
    final base = _getBaseDirectory();
    return io.File('${base.path}/settings.json');
  }

  static io.Directory _getSoundFontsDir() {
    final base = _getBaseDirectory();
    final sfDir = io.Directory('${base.path}/soundfonts');
    if (!sfDir.existsSync()) {
      try {
        sfDir.createSync(recursive: true);
      } catch (e) {
        debugPrint('Error creating soundfonts directory: $e');
      }
    }
    return sfDir;
  }

  static io.File _getSessionFile() {
    final base = _getBaseDirectory();
    final sessDir = io.Directory('${base.path}/sessions');
    if (!sessDir.existsSync()) {
      try {
        sessDir.createSync(recursive: true);
      } catch (e) {
        debugPrint('Error creating sessions directory: $e');
      }
    }
    return io.File('${sessDir.path}/autosave.eats.lua');
  }

  static Map<String, dynamic> _loadSettingsSync() {
    if (_isTest) {
      return _testSettings;
    }
    if (_cachedSettings != null) return _cachedSettings!;
    try {
      final file = _getSettingsFile();
      if (file.existsSync()) {
        final content = file.readAsStringSync().trim();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _cachedSettings = decoded;
            return _cachedSettings!;
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading settings.json: $e');
    }
    _cachedSettings = {};
    return _cachedSettings!;
  }

  static Future<void> _flushSettings() async {
    if (_isTest) return;
    try {
      final file = _getSettingsFile();
      await file.writeAsString(
        jsonEncode(_cachedSettings ?? {}),
        mode: io.FileMode.write,
        flush: true,
      );
    } catch (e) {
      debugPrint('Error saving settings.json: $e');
    }
  }

  // --- Settings API ---

  static Future<String?> getString(String key) async {
    final settings = _loadSettingsSync();
    return settings[key]?.toString();
  }

  static Future<void> setString(String key, String value) async {
    final settings = _loadSettingsSync();
    settings[key] = value;
    await _flushSettings();
  }

  static Future<bool?> getBool(String key) async {
    final settings = _loadSettingsSync();
    final val = settings[key];
    if (val == null) return null;
    if (val is bool) return val;
    return val.toString().toLowerCase() == 'true';
  }

  static Future<void> setBool(String key, bool value) async {
    final settings = _loadSettingsSync();
    settings[key] = value;
    await _flushSettings();
  }

  static Future<double?> getDouble(String key) async {
    final settings = _loadSettingsSync();
    final val = settings[key];
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  static Future<void> setDouble(String key, double value) async {
    final settings = _loadSettingsSync();
    settings[key] = value;
    await _flushSettings();
  }

  // --- SoundFont Storage API ---

  static Future<void> saveSoundFont(String fileName, Uint8List bytes) async {
    if (_isTest) {
      _testSoundFonts[fileName] = bytes;
      return;
    }
    try {
      final dir = _getSoundFontsDir();
      final file = io.File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('EatsStorageHelper (IO): Saved soundfont $fileName (${bytes.length} bytes)');
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error saving soundfont $fileName: $e');
    }
  }

  static Future<Uint8List?> loadSoundFont(String fileName) async {
    if (_isTest) {
      return _testSoundFonts[fileName];
    }
    try {
      // 1. Check AppData folder
      final dir = _getSoundFontsDir();
      final file = io.File('${dir.path}/$fileName');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          debugPrint('EatsStorageHelper (IO): Loaded soundfont $fileName from AppData (${bytes.length} bytes)');
          return bytes;
        }
      }

      // 2. Portable mode fallback (local ./soundfonts/)
      final localDir = io.Directory('soundfonts');
      if (await localDir.exists()) {
        final localFile = io.File('soundfonts/$fileName');
        if (await localFile.exists()) {
          final bytes = await localFile.readAsBytes();
          if (bytes.isNotEmpty) {
            debugPrint('EatsStorageHelper (IO): Loaded soundfont $fileName from local folder (${bytes.length} bytes)');
            return bytes;
          }
        }
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error loading soundfont $fileName: $e');
    }
    return null;
  }

  static Future<bool> hasSoundFont(String fileName) async {
    if (_isTest) {
      return _testSoundFonts.containsKey(fileName);
    }
    try {
      final dir = _getSoundFontsDir();
      final file = io.File('${dir.path}/$fileName');
      if (await file.exists()) return true;

      final localFile = io.File('soundfonts/$fileName');
      return await localFile.exists();
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteSoundFont(String fileName) async {
    if (_isTest) {
      _testSoundFonts.remove(fileName);
      return;
    }
    try {
      final dir = _getSoundFontsDir();
      final file = io.File('${dir.path}/$fileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error deleting soundfont $fileName: $e');
    }
  }

  static Future<List<String>> listCachedSoundFonts() async {
    if (_isTest) {
      return _testSoundFonts.keys.toList();
    }
    final list = <String>[];
    try {
      final dir = _getSoundFontsDir();
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is io.File && entity.path.toLowerCase().endsWith('.sf2')) {
            list.add(entity.uri.pathSegments.last);
          }
        }
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error listing soundfonts: $e');
    }
    return list;
  }

  // --- Session Storage API ---

  static Future<void> saveSessionLua(String luaCode) async {
    if (_isTest) {
      _testSessionLua = luaCode;
      return;
    }
    try {
      final file = _getSessionFile();
      await file.writeAsString(luaCode, flush: true);
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error saving session Lua: $e');
    }
  }

  static Future<String?> loadSessionLua() async {
    if (_isTest) {
      return _testSessionLua;
    }
    try {
      final file = _getSessionFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          return content;
        }
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error loading session Lua: $e');
    }
    return null;
  }

  static Future<void> clearSessionLua() async {
    if (_isTest) {
      _testSessionLua = null;
      return;
    }
    try {
      final file = _getSessionFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error clearing session Lua: $e');
    }
  }
}
