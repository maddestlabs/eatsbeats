import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/saved_project_model.dart';

import 'eats_storage_helper_stub.dart'
    if (dart.library.html) 'eats_storage_helper_web.dart'
    if (dart.library.io) 'eats_storage_helper_io.dart';

/// Cross-platform storage helper for Eatsbeats.
/// - Web: Uses localStorage for settings/sessions and IndexedDB for large binary SoundFonts (.sf2).
/// - Windows/Desktop: Uses AppData directory for settings, sessions, and binary SoundFonts.
class EatsStorageHelper {
  /// Notifier triggered whenever a project file is saved, deleted, or renamed.
  static final ValueNotifier<int> onProjectsChanged = ValueNotifier<int>(0);

  /// Notifies all listening UI components (e.g. Project Browser > Projects) that project files changed.
  static void notifyProjectsChanged() {
    onProjectsChanged.value++;
  }

  // --- Settings Keys ---
  static const String keyThemePreset = 'theme_preset';
  static const String keyUiScale = 'ui_scale';
  static const String keyAutoRestoreSession = 'auto_restore_session';
  static const String keyAutoSaveEnabled = 'auto_save_enabled';
  static const String keyGuiAnimationsEnabled = 'gui_animations_enabled';

  // --- Settings Key-Value API ---

  static Future<String?> getString(String key) => EatsStorageHelperImpl.getString(key);
  static Future<void> setString(String key, String value) => EatsStorageHelperImpl.setString(key, value);

  static Future<bool?> getBool(String key) => EatsStorageHelperImpl.getBool(key);
  static Future<void> setBool(String key, bool value) => EatsStorageHelperImpl.setBool(key, value);

  static Future<double?> getDouble(String key) => EatsStorageHelperImpl.getDouble(key);
  static Future<void> setDouble(String key, double value) => EatsStorageHelperImpl.setDouble(key, value);

  static Future<void> remove(String key) => EatsStorageHelperImpl.remove(key);
  static void reloadSettings() => EatsStorageHelperImpl.reloadSettings();
  static String getSettingsFilePath() => EatsStorageHelperImpl.getSettingsFilePath();
  static Future<void> openSettingsFolder() => EatsStorageHelperImpl.openSettingsFolder();

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

  // --- Saved Projects API ---

  static String getProjectsFolderPath() => EatsStorageHelperImpl.getProjectsFolderPath();

  static Future<void> openProjectsFolder() => EatsStorageHelperImpl.openProjectsFolder();

  static Future<void> openFolderForFile(String filePath) => EatsStorageHelperImpl.openFolderForFile(filePath);

  static Future<List<SavedProjectItem>> listSavedProjects() =>
      EatsStorageHelperImpl.listSavedProjects();

  static Future<SavedProjectItem?> saveProjectFile(String name, String luaCode) async {
    final res = await EatsStorageHelperImpl.saveProjectFile(name, luaCode);
    if (res != null) {
      notifyProjectsChanged();
    }
    return res;
  }

  static Future<String?> loadProjectFile(SavedProjectItem item) =>
      EatsStorageHelperImpl.loadProjectFile(item);

  static Future<bool> deleteProjectFile(SavedProjectItem item) async {
    final res = await EatsStorageHelperImpl.deleteProjectFile(item);
    if (res) {
      notifyProjectsChanged();
    }
    return res;
  }

  static Future<bool> renameProjectFile(SavedProjectItem item, String newName) async {
    final res = await EatsStorageHelperImpl.renameProjectFile(item, newName);
    if (res) {
      notifyProjectsChanged();
    }
    return res;
  }

  static void setTestMode(bool value) => EatsStorageHelperImpl.setTestMode(value);
}
