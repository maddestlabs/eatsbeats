import 'dart:async';
import 'dart:typed_data';
import '../models/saved_project_model.dart';

import 'eats_storage_helper_stub.dart'
    if (dart.library.html) 'eats_storage_helper_web.dart'
    if (dart.library.io) 'eats_storage_helper_io.dart';

/// Cross-platform storage helper for Eatsbeats.
/// - Web: Uses localStorage for settings/sessions and IndexedDB for large binary SoundFonts (.sf2).
/// - Windows/Desktop: Uses AppData directory for settings, sessions, and binary SoundFonts.
class EatsStorageHelper {
  // --- Settings Keys ---
  static const String keyThemePreset = 'theme_preset';
  static const String keyUiScale = 'ui_scale';
  static const String keyAutoRestoreSession = 'auto_restore_session';
  static const String keyAutoSaveEnabled = 'auto_save_enabled';

  // --- Settings Key-Value API ---

  static Future<String?> getString(String key) => EatsStorageHelperImpl.getString(key);
  static Future<void> setString(String key, String value) => EatsStorageHelperImpl.setString(key, value);

  static Future<bool?> getBool(String key) => EatsStorageHelperImpl.getBool(key);
  static Future<void> setBool(String key, bool value) => EatsStorageHelperImpl.setBool(key, value);

  static Future<double?> getDouble(String key) => EatsStorageHelperImpl.getDouble(key);
  static Future<void> setDouble(String key, double value) => EatsStorageHelperImpl.setDouble(key, value);

  // --- SoundFont Storage API ---

  static Future<void> saveSoundFont(String fileName, Uint8List bytes) =>
      EatsStorageHelperImpl.saveSoundFont(fileName, bytes);

  static Future<Uint8List?> loadSoundFont(String fileName) =>
      EatsStorageHelperImpl.loadSoundFont(fileName);

  static Future<bool> hasSoundFont(String fileName) =>
      EatsStorageHelperImpl.hasSoundFont(fileName);

  static Future<void> deleteSoundFont(String fileName) =>
      EatsStorageHelperImpl.deleteSoundFont(fileName);

  static Future<List<String>> listCachedSoundFonts() =>
      EatsStorageHelperImpl.listCachedSoundFonts();

  // --- Neural / AI Model Storage API ---

  static Future<void> saveModel(String fileName, Uint8List bytes) =>
      EatsStorageHelperImpl.saveModel(fileName, bytes);

  static Future<Uint8List?> loadModel(String fileName) =>
      EatsStorageHelperImpl.loadModel(fileName);

  static Future<bool> hasModel(String fileName) =>
      EatsStorageHelperImpl.hasModel(fileName);

  static Future<void> deleteModel(String fileName) =>
      EatsStorageHelperImpl.deleteModel(fileName);

  // --- Session Storage API ---

  static Future<void> saveSessionLua(String luaCode) =>
      EatsStorageHelperImpl.saveSessionLua(luaCode);

  static Future<String?> loadSessionLua() =>
      EatsStorageHelperImpl.loadSessionLua();

  static Future<void> clearSessionLua() =>
      EatsStorageHelperImpl.clearSessionLua();

  // --- Saved Projects Storage API ---

  static String getProjectsFolderPath() => EatsStorageHelperImpl.getProjectsFolderPath();

  static Future<void> openProjectsFolder() => EatsStorageHelperImpl.openProjectsFolder();

  static Future<List<SavedProjectItem>> listSavedProjects() =>
      EatsStorageHelperImpl.listSavedProjects();

  static Future<SavedProjectItem?> saveProjectFile(String name, String luaCode) =>
      EatsStorageHelperImpl.saveProjectFile(name, luaCode);

  static Future<String?> loadProjectFile(SavedProjectItem item) =>
      EatsStorageHelperImpl.loadProjectFile(item);

  static Future<bool> deleteProjectFile(SavedProjectItem item) =>
      EatsStorageHelperImpl.deleteProjectFile(item);

  static Future<bool> renameProjectFile(SavedProjectItem item, String newName) =>
      EatsStorageHelperImpl.renameProjectFile(item, newName);
}
