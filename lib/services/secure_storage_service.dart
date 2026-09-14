import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/platform_env_helper.dart';
import '../utils/eats_storage_helper.dart';

enum GeminiKeySource {
  none,
  environment,
  settingsFile,
  secureStorage,
  browserStorage,
  sessionOnly,
}

/// Centralized storage service for Eatsbeats settings and API keys.
/// - Desktop (Windows/macOS/Linux): Backed by editable binary folder or AppData `settings.json`,
///   and system environment variables (GEMINI_API_KEY).
/// - Web: Uses localStorage with opt-in user consent.
/// - Test environments: Isolated in-memory fallback.
class SecureStorageService {
  static const String _geminiApiKeyStorageKey = 'gemini_api_key';
  static const String keyWebRememberApiKey = 'remember_gemini_api_key';

  // In-memory test cache for test isolation
  static final Map<String, String> _testStorage = {};
  static bool? _testModeOverride;

  @visibleForTesting
  static void setTestMode(bool isTest) {
    _testModeOverride = isTest;
  }

  static bool get _isTest =>
      _testModeOverride ?? PlatformEnvHelper.isFlutterTest;

  /// Loads the Gemini API key from the most appropriate available source:
  /// 1. Environment variable (GEMINI_API_KEY / EATSBEATS_GEMINI_API_KEY on native desktop)
  /// 2. settings.json in binary folder or AppData (external manual config)
  /// 3. Web browser storage (if opted-in)
  static Future<({String? key, GeminiKeySource source})> loadGeminiApiKey() async {
    // 1. Check environment variable on desktop/native
    if (!kIsWeb) {
      try {
        final envKey = PlatformEnvHelper.getEnv('GEMINI_API_KEY') ??
            PlatformEnvHelper.getEnv('EATSBEATS_GEMINI_API_KEY');
        if (envKey != null && envKey.trim().isNotEmpty) {
          return (key: envKey.trim(), source: GeminiKeySource.environment);
        }
      } catch (e) {
        debugPrint('[SecureStorageService] Env read error: $e');
      }

      // 2. Check settings.json in binary directory or AppData
      try {
        if (_isTest) {
          final key = _testStorage[_geminiApiKeyStorageKey];
          if (key != null && key.isNotEmpty) {
            return (key: key, source: GeminiKeySource.settingsFile);
          }
        }
        final fileKey = await EatsStorageHelper.getString(_geminiApiKeyStorageKey) ??
            await EatsStorageHelper.getString('geminiApiKey');
        if (fileKey != null && fileKey.trim().isNotEmpty) {
          return (key: fileKey.trim(), source: GeminiKeySource.settingsFile);
        }
      } catch (e) {
        debugPrint('[SecureStorageService] settings.json key read error: $e');
      }
    }

    // 3. On Web, verify whether the user opted in to remembering the key
    if (kIsWeb) {
      final remember = await EatsStorageHelper.getBool(keyWebRememberApiKey) ?? false;
      if (!remember) {
        return (key: null, source: GeminiKeySource.none);
      }
      try {
        final webKey = await EatsStorageHelper.getString(_geminiApiKeyStorageKey);
        if (webKey != null && webKey.trim().isNotEmpty) {
          return (key: webKey.trim(), source: GeminiKeySource.browserStorage);
        }
      } catch (e) {
        debugPrint('[SecureStorageService] Web key read error: $e');
      }
    }

    if (_isTest) {
      final key = _testStorage[_geminiApiKeyStorageKey];
      if (key != null && key.isNotEmpty) {
        return (key: key, source: GeminiKeySource.settingsFile);
      }
    }

    return (key: null, source: GeminiKeySource.none);
  }

  /// Saves the Gemini API key to persistent storage (settings.json / localStorage).
  /// On Web, this also sets the opt-in remember preference.
  static Future<void> saveGeminiApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await deleteGeminiApiKey();
      return;
    }

    if (kIsWeb) {
      await EatsStorageHelper.setBool(keyWebRememberApiKey, true);
    }

    if (_isTest) {
      _testStorage[_geminiApiKeyStorageKey] = trimmed;
    }

    try {
      await EatsStorageHelper.setString(_geminiApiKeyStorageKey, trimmed);
    } catch (e) {
      debugPrint('[SecureStorageService] Storage write error: $e');
    }
  }

  /// Deletes the Gemini API key from persistent storage across all platforms.
  static Future<void> deleteGeminiApiKey() async {
    if (kIsWeb) {
      await EatsStorageHelper.setBool(keyWebRememberApiKey, false);
    }

    if (_isTest) {
      _testStorage.remove(_geminiApiKeyStorageKey);
    }

    try {
      await EatsStorageHelper.remove(_geminiApiKeyStorageKey);
      await EatsStorageHelper.remove('geminiApiKey');
    } catch (e) {
      debugPrint('[SecureStorageService] Storage delete error: $e');
    }
  }

  /// Checks whether a Gemini API key is currently saved in persistent storage or settings file.
  static Future<bool> isGeminiApiKeyStored() async {
    final fileKey = await EatsStorageHelper.getString(_geminiApiKeyStorageKey) ??
        await EatsStorageHelper.getString('geminiApiKey');
    if (fileKey != null && fileKey.trim().isNotEmpty) {
      if (kIsWeb) {
        final remember = await EatsStorageHelper.getBool(keyWebRememberApiKey) ?? false;
        if (!remember) return false;
      }
      return true;
    }

    if (_isTest) {
      return _testStorage.containsKey(_geminiApiKeyStorageKey) &&
          _testStorage[_geminiApiKeyStorageKey]!.isNotEmpty;
    }

    return false;
  }

  /// Checks if user has opted into remembering key on Web.
  static Future<bool> getWebRememberPreference() async {
    final pref = await EatsStorageHelper.getBool(keyWebRememberApiKey);
    if (kIsWeb) {
      return pref ?? false;
    }
    return pref ?? true;
  }

  /// Sets user preference for remembering key on Web.
  static Future<void> setWebRememberPreference(bool value) async {
    await EatsStorageHelper.setBool(keyWebRememberApiKey, value);
    if (!value) {
      if (_isTest) {
        _testStorage.remove(_geminiApiKeyStorageKey);
      }
      try {
        await EatsStorageHelper.remove(_geminiApiKeyStorageKey);
        await EatsStorageHelper.remove('geminiApiKey');
      } catch (_) {}
    }
  }
}
