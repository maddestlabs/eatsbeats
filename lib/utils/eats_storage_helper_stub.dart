import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../models/saved_project_model.dart';

class EatsStorageHelperImpl {
  static final Map<String, String> _memorySettings = {};
  static final Map<String, Uint8List> _memorySoundFonts = {};
  static final Map<String, String> _memoryProjects = {};
  static String? _memorySessionLua;

  static Future<String?> getString(String key) async {
    return _memorySettings[key];
  }

  static Future<void> setString(String key, String value) async {
    _memorySettings[key] = value;
  }

  static Future<bool?> getBool(String key) async {
    final val = _memorySettings[key];
    if (val == null) return null;
    return val == 'true';
  }

  static Future<void> setBool(String key, bool value) async {
    _memorySettings[key] = value.toString();
  }

  static Future<double?> getDouble(String key) async {
    final val = _memorySettings[key];
    if (val == null) return null;
    return double.tryParse(val);
  }

  static Future<void> setDouble(String key, double value) async {
    _memorySettings[key] = value.toString();
  }

  static Future<void> saveSoundFont(String fileName, Uint8List bytes) async {
    _memorySoundFonts[fileName] = bytes;
  }

  static Future<Uint8List?> loadSoundFont(String fileName) async {
    return _memorySoundFonts[fileName];
  }

  static Future<bool> hasSoundFont(String fileName) async {
    return _memorySoundFonts.containsKey(fileName);
  }

  static Future<void> deleteSoundFont(String fileName) async {
    _memorySoundFonts.remove(fileName);
  }

  static Future<List<String>> listCachedSoundFonts() async {
    return _memorySoundFonts.keys.toList();
  }

  static final Map<String, Uint8List> _memoryModels = {};

  static Future<void> saveModel(String fileName, Uint8List bytes) async {
    _memoryModels[fileName] = bytes;
  }

  static Future<Uint8List?> loadModel(String fileName) async {
    return _memoryModels[fileName];
  }

  static Future<bool> hasModel(String fileName) async {
    return _memoryModels.containsKey(fileName);
  }

  static Future<void> deleteModel(String fileName) async {
    _memoryModels.remove(fileName);
  }

  static Future<void> saveSessionLua(String luaCode) async {
    _memorySessionLua = luaCode;
  }

  static Future<String?> loadSessionLua() async {
    return _memorySessionLua;
  }

  static Future<void> clearSessionLua() async {
    _memorySessionLua = null;
  }

  // --- Saved Projects Storage API ---

  static String getProjectsFolderPath() => 'Projects';

  static Future<void> openProjectsFolder() async {}

  static Future<List<SavedProjectItem>> listSavedProjects() async {
    return _memoryProjects.entries.map((e) {
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

  static Future<SavedProjectItem?> saveProjectFile(String name, String luaCode) async {
    final sanitized = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = sanitized.toLowerCase().endsWith('.eats.lua') ? sanitized : '$sanitized.eats.lua';
    _memoryProjects[fileName] = luaCode;
    return SavedProjectItem(
      id: fileName,
      name: sanitized,
      fileName: fileName,
      filePath: 'Projects/$fileName',
      fileSizeBytes: utf8.encode(luaCode).length,
      lastModified: DateTime.now(),
      isWebStorage: false,
    );
  }

  static Future<String?> loadProjectFile(SavedProjectItem item) async {
    return _memoryProjects[item.fileName] ?? _memoryProjects[item.id];
  }

  static Future<bool> deleteProjectFile(SavedProjectItem item) async {
    _memoryProjects.remove(item.fileName);
    _memoryProjects.remove(item.id);
    return true;
  }

  static Future<bool> renameProjectFile(SavedProjectItem item, String newName) async {
    final sanitized = newName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final newFileName = sanitized.toLowerCase().endsWith('.eats.lua') ? sanitized : '$sanitized.eats.lua';
    final code = _memoryProjects.remove(item.fileName) ?? _memoryProjects.remove(item.id) ?? '';
    _memoryProjects[newFileName] = code;
    return true;
  }
}
