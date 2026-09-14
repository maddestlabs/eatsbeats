import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/services/gemini_service.dart';
import 'package:eatsbeats/services/secure_storage_service.dart';
import 'package:eatsbeats/utils/eats_storage_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SecureStorageService.setTestMode(true);
    await SecureStorageService.deleteGeminiApiKey();
    await GeminiService.deleteApiKey();
  });

  tearDown(() async {
    await SecureStorageService.deleteGeminiApiKey();
    await GeminiService.deleteApiKey();
    SecureStorageService.setTestMode(false);
  });

  group('SecureStorageService Direct CRUD & Lifecycle Tests', () {
    test('Stores, checks existence, loads, and deletes Gemini API key', () async {
      expect(await SecureStorageService.isGeminiApiKeyStored(), isFalse);
      expect((await SecureStorageService.loadGeminiApiKey()).key, isNull);

      // Save key
      const testKey = 'AIzaSyFakeTestKey1234567890';
      await SecureStorageService.saveGeminiApiKey(testKey);

      expect(await SecureStorageService.isGeminiApiKeyStored(), isTrue);
      final loaded = await SecureStorageService.loadGeminiApiKey();
      expect(loaded.key, equals(testKey));
      expect(loaded.source, equals(GeminiKeySource.settingsFile));

      // Delete key
      await SecureStorageService.deleteGeminiApiKey();
      expect(await SecureStorageService.isGeminiApiKeyStored(), isFalse);
      expect((await SecureStorageService.loadGeminiApiKey()).key, isNull);
    });

    test('Trims whitespace when saving and treats empty string as deletion', () async {
      await SecureStorageService.saveGeminiApiKey('   AIzaSyPaddedKey   ');
      final loaded = await SecureStorageService.loadGeminiApiKey();
      expect(loaded.key, equals('AIzaSyPaddedKey'));

      await SecureStorageService.saveGeminiApiKey('    ');
      expect(await SecureStorageService.isGeminiApiKeyStored(), isFalse);
      expect((await SecureStorageService.loadGeminiApiKey()).key, isNull);
    });

    test('Web remember preference toggles persistence state', () async {
      await SecureStorageService.setWebRememberPreference(true);
      expect(await SecureStorageService.getWebRememberPreference(), isTrue);

      await SecureStorageService.saveGeminiApiKey('AIzaSyWebKey');
      expect(await SecureStorageService.isGeminiApiKeyStored(), isTrue);

      // Disabling preference should delete stored key
      await SecureStorageService.setWebRememberPreference(false);
      expect(await SecureStorageService.getWebRememberPreference(), isFalse);
      expect(await SecureStorageService.isGeminiApiKeyStored(), isFalse);
    });

    test('settings.json external configuration loading and deletion', () async {
      // 1. Set key in settings.json
      await EatsStorageHelper.setString('gemini_api_key', 'AIzaSyExternalSettingsFileKey');
      expect(await SecureStorageService.isGeminiApiKeyStored(), isTrue);

      final loaded = await SecureStorageService.loadGeminiApiKey();
      expect(loaded.key, equals('AIzaSyExternalSettingsFileKey'));
      expect(loaded.source, equals(GeminiKeySource.settingsFile));

      // 2. Saving a new key updates the settings
      await SecureStorageService.saveGeminiApiKey('AIzaSyUpdatedKey');
      final updatedLoaded = await SecureStorageService.loadGeminiApiKey();
      expect(updatedLoaded.key, equals('AIzaSyUpdatedKey'));
      expect(updatedLoaded.source, equals(GeminiKeySource.settingsFile));

      // 3. Deletion clears settings.json as well
      await SecureStorageService.deleteGeminiApiKey();
      expect(await EatsStorageHelper.getString('gemini_api_key'), isNull);
    });

    test('EatsStorageHelper exposed settings file path and reload', () async {
      final path = EatsStorageHelper.getSettingsFilePath();
      expect(path, isNotEmpty);
      expect(path.endsWith('settings.json'), isTrue);

      // Verify reloadSettings executes cleanly
      EatsStorageHelper.reloadSettings();
    });
  });

  group('GeminiService Persistence Integration Tests', () {
    test('GeminiService persistApiKey, loadPersistedApiKey, and deleteApiKey', () async {
      expect(GeminiService.hasApiKey, isFalse);
      expect(GeminiService.apiKey, isEmpty);
      expect(GeminiService.keySource, equals(GeminiKeySource.none));

      // Persist key
      const keyToPersist = 'AIzaSyServicePersistedKey';
      await GeminiService.persistApiKey(keyToPersist);

      expect(GeminiService.hasApiKey, isTrue);
      expect(GeminiService.apiKey, equals(keyToPersist));
      expect(GeminiService.keySource, equals(GeminiKeySource.settingsFile));

      // Clear in-memory only to simulate new app launch
      GeminiService.apiKey = '';
      GeminiService.keySource = GeminiKeySource.none;
      expect(GeminiService.hasApiKey, isFalse);

      // Load persisted key across session
      await GeminiService.loadPersistedApiKey();
      expect(GeminiService.hasApiKey, isTrue);
      expect(GeminiService.apiKey, equals(keyToPersist));

      // Explicit delete
      await GeminiService.deleteApiKey();
      expect(GeminiService.hasApiKey, isFalse);
      expect(GeminiService.apiKey, isEmpty);
      expect(GeminiService.keySource, equals(GeminiKeySource.none));

      // Re-load should find nothing
      await GeminiService.loadPersistedApiKey();
      expect(GeminiService.hasApiKey, isFalse);
    });

    test('DawState loadPersistedSettings automatically restores Gemini API key', () async {
      const persistedKey = 'AIzaSyDawStateRestoredKey';
      await SecureStorageService.saveGeminiApiKey(persistedKey);

      // Clean in-memory state
      GeminiService.apiKey = '';
      GeminiService.keySource = GeminiKeySource.none;
      expect(GeminiService.hasApiKey, isFalse);

      final dawState = DawState(enableMeterTimer: false);
      await dawState.loadPersistedSettings();

      expect(GeminiService.hasApiKey, isTrue);
      expect(GeminiService.apiKey, equals(persistedKey));
      dawState.dispose();
    });
  });
}
