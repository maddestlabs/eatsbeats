import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drum Presets & History Enhancements Tests', () {
    test('Eats Kick preset compiles with extended AmpDecay range and synthesizes sub-bass', () {
      final kickPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'procedural_kick');
      final compilation = LuaEngine.compile(kickPreset.code);
      expect(compilation.isSuccess, isTrue);

      final ampDecayParam = compilation.params.firstWhere((p) => p.name == 'AmpDecay');
      expect(ampDecayParam.max, greaterThanOrEqualTo(4.0));

      // Synthesize 2-second sub-bass buffer
      final buffer = LuaEngine.synthesizeBuffer(
        code: kickPreset.code,
        durationSec: 2.0,
        freq: 42.0,
        note: 36,
        params: {'AmpDecay': 3.5, 'StartFreq': 150.0, 'EndFreq': 38.0},
      );

      expect(buffer.length, equals(88200));
      // Mid-buffer around 1.0 second should still contain active sub-bass sine wave
      double peakAt1Sec = 0.0;
      for (int i = 44100; i < 44100 + 1000; i++) {
        final absVal = buffer[i].abs();
        if (absVal > peakAt1Sec) peakAt1Sec = absVal;
      }
      expect(peakAt1Sec, greaterThan(0.1));
    });

    test('Eats Snare preset compiles with Variation parameter and synthesizes punchy snare', () {
      final snarePreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'procedural_snare');
      final compilation = LuaEngine.compile(snarePreset.code);
      expect(compilation.isSuccess, isTrue);

      final variationParam = compilation.params.firstWhere((p) => p.name == 'Variation');
      expect(variationParam.min, equals(0.0));
      expect(variationParam.max, equals(1.0));
      expect(variationParam.defaultValue, equals(0.0));

      // Synthesize with variation = 0
      final buffer0 = LuaEngine.synthesizeBuffer(
        code: snarePreset.code,
        durationSec: 0.25,
        freq: 185.0,
        note: 38,
        params: {'ToneFreq': 185.0, 'Snappy': 0.65, 'Decay': 0.18, 'Variation': 0.0},
      );
      expect(buffer0.length, equals(11025));

      // Synthesize with variation = 0.5 on another note
      final bufferVar = LuaEngine.synthesizeBuffer(
        code: snarePreset.code,
        durationSec: 0.25,
        freq: 185.0,
        note: 40,
        params: {'ToneFreq': 185.0, 'Snappy': 0.65, 'Decay': 0.18, 'Variation': 0.5},
      );
      expect(bufferVar.length, equals(11025));
    });

    test('Eats Hats preset compiles with Variation parameter and synthesizes crisp hi-hat', () {
      final hatsPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'procedural_hihat');
      final compilation = LuaEngine.compile(hatsPreset.code);
      expect(compilation.isSuccess, isTrue);

      final variationParam = compilation.params.firstWhere((p) => p.name == 'Variation');
      expect(variationParam.min, equals(0.0));
      expect(variationParam.max, equals(1.0));
      expect(variationParam.defaultValue, equals(0.0));

      final buffer = LuaEngine.synthesizeBuffer(
        code: hatsPreset.code,
        durationSec: 0.1,
        freq: 8000.0,
        note: 42,
        params: {'Cutoff': 7500.0, 'Decay': 0.06, 'Metallic': 0.15, 'Variation': 0.3},
      );
      expect(buffer.length, equals(4410));
      expect(buffer.first, isNot(equals(0.0)));
    });

    test('Track deletion removes track and allows full history undo', () {
      final dawState = DawState();
      final initialTrackCount = dawState.activePattern.tracks.length;

      // Duplicate to ensure at least 2 tracks
      final trackToDuplicate = dawState.activePattern.tracks.first;
      dawState.duplicateTrack(trackToDuplicate);
      expect(dawState.activePattern.tracks.length, equals(initialTrackCount + 1));

      final trackToDelete = dawState.activePattern.tracks.last;
      dawState.deleteTrack(trackToDelete);
      expect(dawState.activePattern.tracks.length, equals(initialTrackCount));

      // Undo deletion restores track
      expect(dawState.history.canUndo, isTrue);
      dawState.undo();
      expect(dawState.activePattern.tracks.length, equals(initialTrackCount + 1));

      dawState.dispose();
    });
  });
}
