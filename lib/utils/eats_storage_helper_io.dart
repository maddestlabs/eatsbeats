import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/saved_project_model.dart';
import 'platform_env_helper.dart';

class EatsStorageHelperImpl {
  static io.Directory? _baseDir;
  static io.Directory? _projectsDir;
  static Map<String, dynamic>? _cachedSettings;

  // In-memory test isolation maps to prevent test runner disk race conditions
  static final Map<String, dynamic> _testSettings = {};
  static final Map<String, Uint8List> _testSoundFonts = {};
  static final Map<String, Uint8List> _testModels = {};
  static final Map<String, String> _testProjects = {};
  static String? _testSessionLua;

  static bool get _isTest => PlatformEnvHelper.isFlutterTest;

  static io.Directory _getBaseDirectory() {
    if (_baseDir != null) return _baseDir!;

    String path;
    if (io.Platform.isWindows) {
      final appData = io.Platform.environment['APPDATA'] ??
          io.Platform.environment['LOCALAPPDATA'] ??
          io.Directory.current.path;
      path = '$appData/Eatsbeats';
    } else if (io.Platform.isMacOS) {
      final home = io.Platform.environment['HOME'] ?? '.';
      path = '$home/Library/Application Support/Eatsbeats';
    } else if (io.Platform.isLinux) {
      final xdg = io.Platform.environment['XDG_DATA_HOME'];
      if (xdg != null && xdg.isNotEmpty) {
        path = '$xdg/eatsbeats';
      } else {
        final home = io.Platform.environment['HOME'] ?? '.';
        path = '$home/.local/share/eatsbeats';
      }
    } else {
      path = '${io.Directory.systemTemp.path}/eatsbeats';
    }

    _baseDir = io.Directory(path);
    if (!_baseDir!.existsSync()) {
      try {
        _baseDir!.createSync(recursive: true);
      } catch (e) {
        debugPrint('Error creating Eatsbeats storage directory: $e');
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

  static io.Directory _getModelsDir() {
    final base = _getBaseDirectory();
    final modelDir = io.Directory('${base.path}/models');
    if (!modelDir.existsSync()) {
      try {
        modelDir.createSync(recursive: true);
      } catch (e) {
        debugPrint('Error creating models directory: $e');
      }
    }
    return modelDir;
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

  // --- Neural / AI Model Storage API ---

  static Future<void> saveModel(String fileName, Uint8List bytes) async {
    if (_isTest) {
      _testModels[fileName] = bytes;
      return;
    }
    try {
      final dir = _getModelsDir();
      final file = io.File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('EatsStorageHelper (IO): Saved neural model $fileName (${bytes.length} bytes)');
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error saving neural model $fileName: $e');
    }
  }

  static Future<Uint8List?> loadModel(String fileName) async {
    if (_isTest) {
      return _testModels[fileName];
    }
    try {
      final dir = _getModelsDir();
      final file = io.File('${dir.path}/$fileName');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          debugPrint('EatsStorageHelper (IO): Loaded neural model $fileName (${bytes.length} bytes)');
          return bytes;
        }
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error loading neural model $fileName: $e');
    }
    return null;
  }

  static Future<bool> hasModel(String fileName) async {
    if (_isTest) {
      return _testModels.containsKey(fileName);
    }
    try {
      final dir = _getModelsDir();
      final file = io.File('${dir.path}/$fileName');
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteModel(String fileName) async {
    if (_isTest) {
      _testModels.remove(fileName);
      return;
    }
    try {
      final dir = _getModelsDir();
      final file = io.File('${dir.path}/$fileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error deleting neural model $fileName: $e');
    }
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

  // --- Saved Projects Storage API ---

  static io.Directory getProjectsDirectory() {
    if (_projectsDir != null) return _projectsDir!;

    // 1. Portable mode: ./Projects/ relative to executable/current directory
    final localDir = io.Directory('Projects');
    if (!localDir.existsSync()) {
      try {
        localDir.createSync(recursive: true);
      } catch (e) {
        debugPrint('Could not create portable Projects dir: $e');
      }
    }

    if (localDir.existsSync()) {
      _projectsDir = localDir;
      return _projectsDir!;
    }

    // 2. Fallback to AppData/Eatsbeats/Projects
    final base = _getBaseDirectory();
    final appDataProjects = io.Directory('${base.path}/Projects');
    if (!appDataProjects.existsSync()) {
      try {
        appDataProjects.createSync(recursive: true);
      } catch (e) {
        debugPrint('Could not create AppData Projects dir: $e');
      }
    }
    _projectsDir = appDataProjects;
    return _projectsDir!;
  }

  static String getProjectsFolderPath() {
    try {
      return getProjectsDirectory().absolute.path;
    } catch (_) {
      return 'Projects';
    }
  }

  static Future<void> openProjectsFolder() async {
    final path = getProjectsFolderPath();
    try {
      if (io.Platform.isWindows) {
        await io.Process.run('explorer.exe', [path]);
      } else if (io.Platform.isMacOS) {
        await io.Process.run('open', [path]);
      } else if (io.Platform.isLinux) {
        await io.Process.run('xdg-open', [path]);
      }
    } catch (e) {
      debugPrint('Error opening projects folder in file manager: $e');
    }
  }

  static Future<List<SavedProjectItem>> listSavedProjects() async {
    if (_isTest) {
      return _testProjects.entries.map((e) {
        return SavedProjectItem(
          id: e.key,
          name: e.key.replaceAll('.eats.lua', ''),
          fileName: e.key,
          filePath: 'Projects/${e.key}',
          fileSizeBytes: utf8.encode(e.value).length,
          lastModified: DateTime.now(),
          isWebStorage: false,
        );
      }).toList();
    }

    final results = <SavedProjectItem>[];
    try {
      final dir = getProjectsDirectory();
      if (await dir.exists()) {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is io.File) {
            final fileName = entity.uri.pathSegments.last;
            final lower = fileName.toLowerCase();
            if (lower.endsWith('.eats.lua') || lower.endsWith('.lua') || lower.endsWith('.json') || lower.endsWith('.mid')) {
              final stat = await entity.stat();
              String displayName = fileName;
              if (displayName.toLowerCase().endsWith('.eats.lua')) {
                displayName = displayName.substring(0, displayName.length - 9);
              } else if (displayName.contains('.')) {
                displayName = displayName.substring(0, displayName.lastIndexOf('.'));
              }

              results.add(SavedProjectItem(
                id: entity.path,
                name: displayName,
                fileName: fileName,
                filePath: entity.path,
                fileSizeBytes: stat.size,
                lastModified: stat.modified,
                isWebStorage: false,
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error listing saved projects: $e');
    }

    results.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return results;
  }

  static Future<SavedProjectItem?> saveProjectFile(String name, String luaCode) async {
    final sanitizedName = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = sanitizedName.toLowerCase().endsWith('.eats.lua')
        ? sanitizedName
        : '$sanitizedName.eats.lua';

    if (_isTest) {
      _testProjects[fileName] = luaCode;
      return SavedProjectItem(
        id: fileName,
        name: sanitizedName,
        fileName: fileName,
        filePath: 'Projects/$fileName',
        fileSizeBytes: utf8.encode(luaCode).length,
        lastModified: DateTime.now(),
        isWebStorage: false,
      );
    }

    try {
      final dir = getProjectsDirectory();
      final file = io.File('${dir.path}/$fileName');
      await file.writeAsString(luaCode, flush: true);
      final stat = await file.stat();

      return SavedProjectItem(
        id: file.path,
        name: sanitizedName,
        fileName: fileName,
        filePath: file.path,
        fileSizeBytes: stat.size,
        lastModified: stat.modified,
        isWebStorage: false,
      );
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error saving project $fileName: $e');
      return null;
    }
  }

  static Future<String?> loadProjectFile(SavedProjectItem item) async {
    if (_isTest) {
      return _testProjects[item.fileName] ?? _testProjects[item.id];
    }
    try {
      if (item.filePath != null) {
        final file = io.File(item.filePath!);
        if (await file.exists()) {
          return await file.readAsString();
        }
      }
      final dir = getProjectsDirectory();
      final file = io.File('${dir.path}/${item.fileName}');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error loading project ${item.fileName}: $e');
    }
    return null;
  }

  static Future<bool> deleteProjectFile(SavedProjectItem item) async {
    if (_isTest) {
      _testProjects.remove(item.fileName);
      _testProjects.remove(item.id);
      return true;
    }
    try {
      if (item.filePath != null) {
        final file = io.File(item.filePath!);
        if (await file.exists()) {
          await file.delete();
          return true;
        }
      }
      final dir = getProjectsDirectory();
      final file = io.File('${dir.path}/${item.fileName}');
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error deleting project ${item.fileName}: $e');
    }
    return false;
  }

  static Future<bool> renameProjectFile(SavedProjectItem item, String newName) async {
    final sanitized = newName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final newFileName = sanitized.toLowerCase().endsWith('.eats.lua') ? sanitized : '$sanitized.eats.lua';

    if (_isTest) {
      final code = _testProjects.remove(item.fileName) ?? _testProjects.remove(item.id) ?? '';
      _testProjects[newFileName] = code;
      return true;
    }

    try {
      final oldPath = item.filePath ?? '${getProjectsDirectory().path}/${item.fileName}';
      final oldFile = io.File(oldPath);
      if (await oldFile.exists()) {
        final newPath = '${oldFile.parent.path}/$newFileName';
        await oldFile.rename(newPath);
        return true;
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (IO) error renaming project: $e');
    }
    return false;
  }
}
