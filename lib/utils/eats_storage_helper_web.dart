import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:indexed_db' as idb;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/saved_project_model.dart';

class EatsStorageHelperImpl {
  static const String _dbName = 'eatsbeats_storage_db';
  static const int _dbVersion = 1;
  static const String _soundFontStore = 'soundfonts';
  static const String _projectsMetaKey = 'eatsbeats_saved_projects_meta';
  static const String _projectPrefix = 'eatsbeats_project_data_';

  static idb.Database? _db;

  static Future<idb.Database?> _getDb() async {
    if (_db != null) return _db;
    if (html.window.indexedDB == null) return null;

    try {
      _db = await html.window.indexedDB!.open(
        _dbName,
        version: _dbVersion,
        onUpgradeNeeded: (event) {
          final dynamic target = event.target;
          final idb.Database db = target.result as idb.Database;
          if (db.objectStoreNames == null || !db.objectStoreNames!.contains(_soundFontStore)) {
            db.createObjectStore(_soundFontStore);
          }
        },
      );
      return _db;
    } catch (e) {
      debugPrint('IndexedDB open exception: $e');
      return null;
    }
  }

  // --- Settings API (localStorage) ---

  static Future<String?> getString(String key) async {
    try {
      return html.window.localStorage[key];
    } catch (e) {
      debugPrint('localStorage error: $e');
      return null;
    }
  }

  static Future<void> setString(String key, String value) async {
    try {
      html.window.localStorage[key] = value;
    } catch (e) {
      debugPrint('localStorage set error: $e');
    }
  }

  static Future<bool?> getBool(String key) async {
    final val = await getString(key);
    if (val == null) return null;
    return val.toLowerCase() == 'true';
  }

  static Future<void> setBool(String key, bool value) async {
    await setString(key, value.toString());
  }

  static Future<double?> getDouble(String key) async {
    final val = await getString(key);
    if (val == null) return null;
    return double.tryParse(val);
  }

  static Future<void> setDouble(String key, double value) async {
    await setString(key, value.toString());
  }

  // --- SoundFont Storage API (IndexedDB) ---

  static Future<void> saveSoundFont(String fileName, Uint8List bytes) async {
    try {
      final db = await _getDb();
      if (db == null) {
        debugPrint('IndexedDB unavailable for saving $fileName');
        return;
      }

      final tx = db.transaction(_soundFontStore, 'readwrite');
      final store = tx.objectStore(_soundFontStore);
      final blob = html.Blob([bytes], 'application/octet-stream');
      await store.put(blob, fileName);
      await tx.completed;
      debugPrint('EatsStorageHelper (Web): Persisted $fileName (${bytes.length} bytes) to IndexedDB');
    } catch (e) {
      debugPrint('EatsStorageHelper (Web) error saving soundfont $fileName: $e');
    }
  }

  static Future<Uint8List?> loadSoundFont(String fileName) async {
    try {
      final db = await _getDb();
      if (db == null) return null;

      final tx = db.transaction(_soundFontStore, 'readonly');
      final store = tx.objectStore(_soundFontStore);
      final res = await store.getObject(fileName);

      if (res == null) return null;

      if (res is html.Blob) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(res);
        await reader.onLoadEnd.first;
        final result = reader.result;
        if (result is ByteBuffer) {
          return result.asUint8List();
        } else if (result is Uint8List) {
          return result;
        }
      } else if (res is ByteBuffer) {
        return res.asUint8List();
      } else if (res is Uint8List) {
        return res;
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (Web) exception reading soundfont $fileName: $e');
    }
    return null;
  }

  static Future<bool> hasSoundFont(String fileName) async {
    final bytes = await loadSoundFont(fileName);
    return bytes != null && bytes.isNotEmpty;
  }

  static Future<void> deleteSoundFont(String fileName) async {
    try {
      final db = await _getDb();
      if (db == null) return;
      final tx = db.transaction(_soundFontStore, 'readwrite');
      final store = tx.objectStore(_soundFontStore);
      await store.delete(fileName);
      await tx.completed;
    } catch (e) {
      debugPrint('EatsStorageHelper (Web) error deleting soundfont $fileName: $e');
    }
  }

  static Future<List<String>> listCachedSoundFonts() async {
    return [];
  }

  // --- Neural / AI Model Storage API (IndexedDB) ---

  static Future<void> saveModel(String fileName, Uint8List bytes) async {
    await saveSoundFont(fileName, bytes);
  }

  static Future<Uint8List?> loadModel(String fileName) async {
    return await loadSoundFont(fileName);
  }

  static Future<bool> hasModel(String fileName) async {
    return await hasSoundFont(fileName);
  }

  static Future<void> deleteModel(String fileName) async {
    await deleteSoundFont(fileName);
  }

  // --- Session Storage API ---

  static const String _sessionKey = 'eatsbeats_session_lua';

  static Future<void> saveSessionLua(String luaCode) async {
    try {
      html.window.localStorage[_sessionKey] = luaCode;
    } catch (e) {
      debugPrint('EatsStorageHelper (Web) error saving session lua: $e');
    }
  }

  static Future<String?> loadSessionLua() async {
    try {
      final content = html.window.localStorage[_sessionKey];
      if (content != null && content.trim().isNotEmpty) {
        return content;
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (Web) error loading session lua: $e');
    }
    return null;
  }

  static Future<void> clearSessionLua() async {
    try {
      html.window.localStorage.remove(_sessionKey);
    } catch (e) {
      debugPrint('EatsStorageHelper (Web) error clearing session lua: $e');
    }
  }

  // --- Saved Projects Storage API ---

  static String getProjectsFolderPath() => 'Web Browser Storage (localStorage)';

  static Future<void> openProjectsFolder() async {}

  static Future<List<SavedProjectItem>> listSavedProjects() async {
    final results = <SavedProjectItem>[];
    try {
      final raw = html.window.localStorage[_projectsMetaKey];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              results.add(SavedProjectItem.fromJson(item));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (Web) error listing saved projects: $e');
    }
    results.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return results;
  }

  static Future<SavedProjectItem?> saveProjectFile(String name, String luaCode) async {
    final sanitized = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final id = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final fileName = sanitized.toLowerCase().endsWith('.eats.lua') ? sanitized : '$sanitized.eats.lua';

    try {
      final item = SavedProjectItem(
        id: id,
        name: sanitized,
        fileName: fileName,
        fileSizeBytes: utf8.encode(luaCode).length,
        lastModified: DateTime.now(),
        isWebStorage: true,
      );

      final list = await listSavedProjects();
      list.removeWhere((p) => p.name == sanitized || p.fileName == fileName);
      list.insert(0, item);

      html.window.localStorage[_projectsMetaKey] = jsonEncode(list.map((p) => p.toJson()).toList());
      html.window.localStorage['$_projectPrefix$id'] = luaCode;
      return item;
    } catch (e) {
      debugPrint('EatsStorageHelper (Web) error saving project: $e');
      return null;
    }
  }

  static Future<String?> loadProjectFile(SavedProjectItem item) async {
    try {
      return html.window.localStorage['$_projectPrefix${item.id}'];
    } catch (e) {
      debugPrint('EatsStorageHelper (Web) error loading project: $e');
      return null;
    }
  }

  static Future<bool> deleteProjectFile(SavedProjectItem item) async {
    try {
      final list = await listSavedProjects();
      list.removeWhere((p) => p.id == item.id);
      html.window.localStorage[_projectsMetaKey] = jsonEncode(list.map((p) => p.toJson()).toList());
      html.window.localStorage.remove('$_projectPrefix${item.id}');
      return true;
    } catch (e) {
      debugPrint('EatsStorageHelper (Web) error deleting project: $e');
      return false;
    }
  }

  static Future<bool> renameProjectFile(SavedProjectItem item, String newName) async {
    final sanitized = newName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = sanitized.toLowerCase().endsWith('.eats.lua') ? sanitized : '$sanitized.eats.lua';

    try {
      final list = await listSavedProjects();
      final idx = list.indexWhere((p) => p.id == item.id);
      if (idx != -1) {
        list[idx] = SavedProjectItem(
          id: item.id,
          name: sanitized,
          fileName: fileName,
          fileSizeBytes: item.fileSizeBytes,
          lastModified: DateTime.now(),
          isWebStorage: true,
        );
        html.window.localStorage[_projectsMetaKey] = jsonEncode(list.map((p) => p.toJson()).toList());
        return true;
      }
    } catch (e) {
      debugPrint('EatsStorageHelper (Web) error renaming project: $e');
    }
    return false;
  }
}
