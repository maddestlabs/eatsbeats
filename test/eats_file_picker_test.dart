import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/utils/eats_file_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EatsFileHelper Cross-Platform Tests', () {
    test('EatsFileHelper exposes pickEatsFile, saveEatsZipFile, and saveEatsLuaFile', () {
      final state = DawState();
      state.projectName = 'Picker Test';
      
      final zipBytes = state.exportToEatsZip();
      expect(zipBytes, isNotEmpty);
      expect(zipBytes[0], 0x50); // 'P'
      expect(zipBytes[1], 0x4B); // 'K'

      // Roundtrip through loadFromEatsZipOrLua
      final newState = DawState();
      newState.loadFromEatsZipOrLua(zipBytes: zipBytes);
      expect(newState.projectName, 'Picker Test');

      // Test saving does not throw
      expect(() => EatsFileHelper.saveEatsZipFile(zipBytes, 'test.eats.zip'), returnsNormally);
      expect(() => EatsFileHelper.saveEatsLuaFile(state.exportToEatsLua(), 'test.eats.lua'), returnsNormally);
    });

    test('loadFromEatsZipOrLua correctly handles both lua and zip payloads', () {
      final state = DawState();
      state.projectName = 'Lua Payload Test';
      final lua = state.exportToEatsLua();

      final loadedState = DawState();
      loadedState.loadFromEatsZipOrLua(luaContent: lua);
      expect(loadedState.projectName, 'Lua Payload Test');
    });
  });
}
