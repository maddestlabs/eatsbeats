import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drum Presets & History Enhancements Tests', () {
    test('FM Acoustic Kick preset compiles and synthesizes sub-bass impact', () {
      final kickPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'fm_acoustic_kick');
      final compilation = LuaEngine.compile(kickPreset.code);
      expect(compilation.isSuccess, isTrue);

      final nearPitchParam = compilation.params.firstWhere((p) => p.name == 'NearPitchStart');
      expect(nearPitchParam.defaultValue, equals(180.0));

      // Synthesize punchy sub-bass buffer
      final buffer = LuaEngine.synthesizeBuffer(
        code: kickPreset.code,
        durationSec: 0.35,
        freq: 52.0,
        note: 36,
        params: {'NearPitchStart': 180.0, 'NearPitchEnd': 52.0, 'NearFmDepth': 600.0},
      );

      expect(buffer.length, equals((44100 * 0.35).toInt()));
      expect(buffer.any((s) => s.abs() > 0.1), isTrue);
    });

    test('FM Acoustic Snare preset compiles and synthesizes punchy snare with noise wires', () {
      final snarePreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'fm_acoustic_snare');
      final compilation = LuaEngine.compile(snarePreset.code);
      expect(compilation.isSuccess, isTrue);

      final snappyParam = compilation.params.firstWhere((p) => p.name == 'Snappy');
      expect(snappyParam.defaultValue, equals(0.65));

      final buffer = LuaEngine.synthesizeBuffer(
        code: snarePreset.code,
        durationSec: 0.25,
        freq: 185.0,
        note: 38,
        params: {'ToneFreq': 185.0, 'Snappy': 0.65, 'Decay': 0.22},
      );
      expect(buffer.length, equals((44100 * 0.25).toInt()));
      expect(buffer.any((s) => s.abs() > 0.1), isTrue);
    });

    test('FM Acoustic Hi-Hat preset compiles and synthesizes crisp hi-hat', () {
      final hatsPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'fm_acoustic_hihat');
      final compilation = LuaEngine.compile(hatsPreset.code);
      expect(compilation.isSuccess, isTrue);

      final cutoffParam = compilation.params.firstWhere((p) => p.name == 'Cutoff');
      expect(cutoffParam.defaultValue, equals(7000.0));

      final buffer = LuaEngine.synthesizeBuffer(
        code: hatsPreset.code,
        durationSec: 0.1,
        freq: 440.0,
        note: 42,
        params: {'Cutoff': 7000.0, 'Decay': 0.08},
      );
      expect(buffer.length, equals(4410));
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
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
