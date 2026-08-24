import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/theme/eats_theme.dart';
import 'package:eatsbeats/utils/eats_storage_helper.dart';
import 'package:eatsbeats/utils/soundfont_pack_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EatsStorageHelper Key-Value & Binary Storage Tests', () {
    test('Settings key-value persistence for string, bool, and double', () async {
      await EatsStorageHelper.setString('test_theme', 'midnightBites');
      expect(await EatsStorageHelper.getString('test_theme'), equals('midnightBites'));

      await EatsStorageHelper.setBool('test_auto_restore', true);
      expect(await EatsStorageHelper.getBool('test_auto_restore'), isTrue);

      await EatsStorageHelper.setBool('test_auto_restore', false);
      expect(await EatsStorageHelper.getBool('test_auto_restore'), isFalse);

      await EatsStorageHelper.setDouble('test_ui_scale', 1.25);
      expect(await EatsStorageHelper.getDouble('test_ui_scale'), equals(1.25));
    });

    test('SoundFont binary caching and retrieval', () async {
      const fileName = 'TestSoundFont.sf2';
      final dummySfBytes = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0x01, 0x02, 0x03]);

      await EatsStorageHelper.saveSoundFont(fileName, dummySfBytes);
      expect(await EatsStorageHelper.hasSoundFont(fileName), isTrue);

      final loaded = await EatsStorageHelper.loadSoundFont(fileName);
      expect(loaded, isNotNull);
      expect(loaded!.length, equals(dummySfBytes.length));
      expect(loaded[0], equals(0x52));

      await EatsStorageHelper.deleteSoundFont(fileName);
      final afterDelete = await EatsStorageHelper.loadSoundFont(fileName);
      expect(afterDelete, isNull);
    });

    test('Session Lua save, load, and clear', () async {
      const sampleLua = '-- Eatsbeats Test Project\nreturn eatsbeats.song { bpm = 130 }';

      await EatsStorageHelper.saveSessionLua(sampleLua);
      final loaded = await EatsStorageHelper.loadSessionLua();
      expect(loaded, equals(sampleLua));

      await EatsStorageHelper.clearSessionLua();
      final cleared = await EatsStorageHelper.loadSessionLua();
      expect(cleared, isNull);
    });
  });

  group('DawState & Settings Persistence Integration Tests', () {
    test('DawState persists theme preset and ui scale', () async {
      final dawState = DawState(enableMeterTimer: false);

      dawState.setThemePreset(EatsThemePreset.midnightBites);
      expect(EatsTheme.currentPreset, equals(EatsThemePreset.midnightBites));
      expect(
        await EatsStorageHelper.getString(EatsStorageHelper.keyThemePreset),
        equals('midnightBites'),
      );

      dawState.commitUiScale(1.15);
      expect(dawState.uiScale, equals(1.15));
      expect(
        await EatsStorageHelper.getDouble(EatsStorageHelper.keyUiScale),
        equals(1.15),
      );

      dawState.autoRestoreSession = false;
      expect(dawState.autoRestoreSession, isFalse);
      expect(
        await EatsStorageHelper.getBool(EatsStorageHelper.keyAutoRestoreSession),
        isFalse,
      );

      // Verify fresh DawState loads persisted settings
      final freshState = DawState(enableMeterTimer: false);
      await freshState.loadPersistedSettings();
      expect(freshState.uiScale, equals(1.15));
      expect(freshState.autoRestoreSession, isFalse);
      expect(EatsTheme.currentPreset, equals(EatsThemePreset.midnightBites));

      freshState.dispose();
      dawState.dispose();
    });

    test('DawState autosaves and restores session roundtrip', () async {
      final stateA = DawState(enableMeterTimer: false);
      stateA.setProjectDetails('Persisted Acid Track', 'Maddest Producer');
      stateA.setBpm(138.0);

      final exportedLua = stateA.exportToEatsLua();
      await EatsStorageHelper.saveSessionLua(exportedLua);

      final stateB = DawState(enableMeterTimer: false);
      final restored = await stateB.restoreSavedSession();

      expect(restored, isTrue);
      expect(stateB.projectName, equals('Persisted Acid Track'));
      expect(stateB.authorName, equals('Maddest Producer'));
      expect(stateB.bpm, equals(138.0));

      await stateB.clearSavedSession();
      final loadedAfterClear = await EatsStorageHelper.loadSessionLua();
      expect(loadedAfterClear, isNull);

      stateA.dispose();
      stateB.dispose();
    });

    test('SoundFontPackManager restores cached pack on startup', () async {
      const fileName = 'GeneralUser_GS.sf2';
      final file = io.File('assets/soundfonts/super_small_font.sf2');
      final validSfBytes = file.existsSync() ? file.readAsBytesSync() : Uint8List(0);
      if (validSfBytes.isNotEmpty) {
        await EatsStorageHelper.saveSoundFont(fileName, validSfBytes);

        final manager = SoundFontPackManager.instance;
        await manager.restoreCachedPacks(force: true);

        final pack = manager.packs.firstWhere((p) => p.fileName == fileName);
        expect(pack.isDownloaded, isTrue);
        expect(pack.statusMessage, contains('Installed'));
      }
    });
  });
}
