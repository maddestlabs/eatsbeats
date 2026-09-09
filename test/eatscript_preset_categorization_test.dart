import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LuaPresetCategory & Header Meta-Tag Unit Tests', () {
    test('LuaPresetLibrary filters presets by category', () {
      final instruments = LuaPresetLibrary.getPresetsByCategory(LuaPresetCategory.instrument);
      final audioFxs = LuaPresetLibrary.getPresetsByCategory(LuaPresetCategory.audioFx);
      final midiFxs = LuaPresetLibrary.getPresetsByCategory(LuaPresetCategory.midiFx);

      expect(instruments.any((p) => p.id == 'eats_303' || p.id == 'jc_303' || p.id == 'acid_303'), isTrue);
      expect(audioFxs.any((p) => p.id == 'stereo_delay' || p.id == 'bitcrusher_fx'), isTrue);
      expect(midiFxs.any((p) => p.id == 'arpeggiator_midi_fx'), isTrue);
    });

    test('parseFromLuaScript extracts -- @name: and -- @category: header meta-tags', () {
      const code = '''
-- @name: Stereo Phaser
-- @category: audioFx
-- @description: 4-stage stereo phaser plugin
local Phaser = {}
return Phaser
''';

      final preset = LuaPresetLibrary.parseFromLuaScript(code);
      expect(preset.name, equals('Stereo Phaser'));
      expect(preset.category, equals(LuaPresetCategory.audioFx));
      expect(preset.description, equals('4-stage stereo phaser plugin'));
      expect(preset.isAudioFx, isTrue);
    });

    test('DawState addSampleTrackFromFile auto-registers dropped .lua Audio FX script', () {
      final dawState = DawState();
      final track = dawState.activeTrack;
      final initialFxCount = track.fxRack.length;

      const fxScript = '''
-- @name: Tube Saturator
-- @category: audioFx

function effect(sample, t, params)
  return math.tanh(sample * 2.0)
end
''';

      final bytes = Uint8List.fromList(utf8.encode(fxScript));
      dawState.addSampleTrackFromFile(fileName: 'tube_saturator.lua', fileBytes: bytes);

      expect(track.fxRack.length, equals(initialFxCount + 1));
      expect(track.fxRack.last.name, equals('Tube Saturator'));
      dawState.dispose();
    });
  });
}
