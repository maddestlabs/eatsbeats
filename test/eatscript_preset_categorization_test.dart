import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/eatscript/eats_preset_library.dart';
import 'package:eatsbeats/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EatScriptCategory & Header Meta-Tag Unit Tests', () {
    test('EatScriptLibrary filters presets by category', () {
      final instruments = EatScriptLibrary.getPresetsByCategory(EatScriptCategory.instrument);
      final audioFxs = EatScriptLibrary.getPresetsByCategory(EatScriptCategory.audioFx);
      final midiFxs = EatScriptLibrary.getPresetsByCategory(EatScriptCategory.midiFx);

      expect(instruments.any((p) => p.id == 'eats_303' || p.id == 'jc_303' || p.id == 'acid_303'), isTrue);
      expect(audioFxs.any((p) => p.id == 'stereo_delay' || p.id == 'bitcrusher_fx'), isTrue);
      expect(midiFxs.any((p) => p.id == 'arpeggiator_midi_fx'), isTrue);
    });

    test('parseFromScript extracts # @name: and # @category: header meta-tags', () {
      const code = '''
# @name: Stereo Phaser
# @category: audioFx
# @description: 4-stage stereo phaser plugin
local Phaser = {}
return Phaser
''';

      final preset = EatScriptLibrary.parseFromScript(code);
      expect(preset.name, equals('Stereo Phaser'));
      expect(preset.category, equals(EatScriptCategory.audioFx));
      expect(preset.description, equals('4-stage stereo phaser plugin'));
      expect(preset.isAudioFx, isTrue);
    });

    test('DawState addSampleTrackFromFile auto-registers dropped .eats Audio FX script', () {
      final dawState = DawState();
      final track = dawState.activeTrack;
      final initialFxCount = track.fxRack.length;

      const fxScript = '''
# @name: Tube Saturator
# @category: audioFx

def process(sample, t, params):
    return eat.tanh(sample * 2.0)
''';

      final bytes = Uint8List.fromList(utf8.encode(fxScript));
      dawState.addSampleTrackFromFile(fileName: 'tube_saturator.eats', fileBytes: bytes);

      expect(track.fxRack.length, equals(initialFxCount + 1));
      expect(track.fxRack.last.name, equals('Tube Saturator'));
      dawState.dispose();
    });
  });
}
