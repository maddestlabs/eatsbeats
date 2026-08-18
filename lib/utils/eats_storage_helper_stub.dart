import 'dart:async';
import 'dart:typed_data';

class EatsStorageHelperImpl {
  static final Map<String, String> _memorySettings = {};
  static final Map<String, Uint8List> _memorySoundFonts = {};
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

  static Future<void> saveSessionLua(String luaCode) async {
    _memorySessionLua = luaCode;
  }

  static Future<String?> loadSessionLua() async {
    return _memorySessionLua;
  }

  static Future<void> clearSessionLua() async {
    _memorySessionLua = null;
  }
}
