import 'dart:async';
import 'dart:html' as html;
import 'dart:indexed_db' as idb;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class EatsStorageHelperImpl {
  static const String _dbName = 'eatsbits_storage_db';
  static const int _dbVersion = 1;
  static const String _soundFontStore = 'soundfonts';

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

  // --- Session Storage API ---

  static const String _sessionKey = 'eatsbits_session_lua';

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
}
