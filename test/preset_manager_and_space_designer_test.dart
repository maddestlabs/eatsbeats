import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/script_preset_model.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/audio/convolver_engine.dart';
import 'package:eatsbeats/audio/procedural_ir_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Script vs Preset Separation Tests', () {
    test('LuaScriptLibrary contains valid DSP scripts and aliases', () {
      final scripts = LuaScriptLibrary.scripts;
      expect(scripts.isNotEmpty, isTrue);

      final eats303 = LuaScriptLibrary.getScriptById('eats_303');
      expect(eats303, isNotNull);
      expect(eats303!.name, contains('303'));
      expect(eats303.isInstrument, isTrue);

      // Backwards-compatibility alias check
      expect(LuaPresetLibrary.presets.length, equals(scripts.length));
      expect(LuaPresetLibrary.getPresetById('eats_303'), isNotNull);
    });

    test('ScriptPresetLibrary manages stock and user presets', () {
      final presets = ScriptPresetLibrary.instance.allPresets;
      expect(presets.isNotEmpty, isTrue);

      // Verify stock presets for eats_303
      final eats303Presets = ScriptPresetLibrary.instance.getPresetsForScript('eats_303');
      expect(eats303Presets.length, greaterThanOrEqualTo(3));
      expect(eats303Presets.any((p) => p.name == 'Classic Acid Squelch'), isTrue);

      // Test saving a custom user preset
      const customPreset = ScriptPreset(
        id: 'test_user_preset_123',
        scriptId: 'eats_303',
        name: 'My Ultra Squelch',
        category: 'Lead',
        author: 'Test Producer',
        isStock: false,
        params: {'Cutoff': 0.99, 'Resonance': 0.99},
      );

      ScriptPresetLibrary.instance.saveUserPreset(customPreset);
      final updatedEats303 = ScriptPresetLibrary.instance.getPresetsForScript('eats_303');
      expect(updatedEats303.any((p) => p.id == 'test_user_preset_123'), isTrue);

      // Delete user preset
      ScriptPresetLibrary.instance.deleteUserPreset('test_user_preset_123');
      final afterDelete = ScriptPresetLibrary.instance.getPresetsForScript('eats_303');
      expect(afterDelete.any((p) => p.id == 'test_user_preset_123'), isFalse);
    });

    test('DawState applies script presets and modifies track parameters', () {
      final dawState = DawState();
      final track = dawState.activeTrack;

      // Apply Eats-303 stock preset
      final classicAcid = ScriptPresetLibrary.instance.allPresets.firstWhere((p) => p.name == 'Classic Acid Squelch');
      dawState.applyScriptPreset(track, classicAcid);

      expect(track.luaParams['Cutoff'], equals(0.65));
      expect(track.luaParams['Resonance'], equals(0.85));
      expect(track.luaParams['Accent'], equals(0.70));

      // Test saving preset from track
      track.luaParams['Cutoff'] = 0.92;
      dawState.saveTrackScriptPreset(track, 'Acid Screamer 92', 'Lead');

      final savedList = ScriptPresetLibrary.instance.getPresetsForScript('eats_303');
      expect(savedList.any((p) => p.name == 'Acid Screamer 92'), isTrue);
    });
  });

  group('Unified Space / Cab Designer & Convolution Reverb Integration Tests', () {
    test('ConvolverEngine provides room and cab presets seamlessly', () {
      final roomPresets = ConvolverEngine.instance.getRoomPresets();
      final cabPresets = ConvolverEngine.instance.getCabPresets();

      expect(roomPresets.isNotEmpty, isTrue);
      expect(cabPresets.isNotEmpty, isTrue);
      expect(roomPresets.any((r) => r.name == 'Stone Cathedral'), isTrue);
      expect(cabPresets.any((c) => c.name.contains('4x12 Vintage Stack')), isTrue);
    });

    test('Saving custom space preset registers in ConvolverEngine and generates IR sample', () {
      final customRoom = const AcousticSpaceParams(
        name: 'Sci-Fi Mega Void',
        width: 50.0,
        length: 80.0,
        height: 30.0,
        material: AcousticMaterialType.sheetMetal,
        rt60: 5.5,
        damping: 0.1,
        isCabinetMode: false,
      );

      ConvolverEngine.instance.saveUserPreset(customRoom);

      // Verify preset is listed in available IR names for Convolution Reverb
      final availableIrs = ConvolverEngine.instance.getAvailableIrNames();
      expect(availableIrs.contains('Sci-Fi Mega Void'), isTrue);

      // Verify sample buffer can be retrieved / baked
      final irSample = ConvolverEngine.instance.getIrSample('Sci-Fi Mega Void');
      expect(irSample, isNotNull);
      expect(irSample!.isNotEmpty, isTrue);

      // Verify room preset querying
      final rooms = ConvolverEngine.instance.getRoomPresets();
      expect(rooms.any((r) => r.name == 'Sci-Fi Mega Void'), isTrue);
    });
  });
}
