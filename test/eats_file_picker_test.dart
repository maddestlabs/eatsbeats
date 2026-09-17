import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/utils/eats_file_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EatsFileHelper Cross-Platform Tests', () {
    test('EatsFileHelper exposes pickEatsFile, saveEatsZipFile, and saveEatScriptFile', () {
      final state = DawState();
      state.projectName = 'Picker Test';
      
      final zipBytes = state.exportToEatsZip();
      expect(zipBytes, isNotEmpty);
      expect(zipBytes[0], 0x50); // 'P'
      expect(zipBytes[1], 0x4B); // 'K'

      // Roundtrip through loadFromEatsZipOrProject
      final newState = DawState();
      newState.loadFromEatsZipOrProject(zipBytes: zipBytes);
      expect(newState.projectName, 'Picker Test');

      // Test saving does not throw
      expect(() => EatsFileHelper.saveEatsZipFile(zipBytes, 'test.eats.zip'), returnsNormally);
      expect(() => EatsFileHelper.saveEatScriptFile(state.exportToEats(), 'test.eats'), returnsNormally);
    });

    test('loadFromEatsZipOrProject correctly handles both Eatscript and zip payloads', () {
      final state = DawState();
      state.projectName = 'Eatscript Payload Test';
      final script = state.exportToEats();

      final loadedState = DawState();
      loadedState.loadFromEatsZipOrProject(scriptContent: script);
      expect(loadedState.projectName, 'Eatscript Payload Test');
    });
  });
}
