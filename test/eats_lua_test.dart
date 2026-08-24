import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/lua/eats_lua_serializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Eats.lua Save & Load Serialization Tests', () {
    test('Serializes DawState to .eats.lua valid string', () {
      final state = DawState();
      state.projectName = 'Acid Sunset';
      state.setBpm(128.0);
      state.setMasterVolume(0.90);

      final luaString = EatsLuaSerializer.serialize(state, projectName: state.projectName);

      expect(luaString, contains('return eatsbeats.song {'));
      expect(luaString, contains('title = "Acid Sunset"'));
      expect(luaString, contains('bpm = 128.00'));
      expect(luaString, contains('masterVolume = 0.90'));
      expect(luaString, contains('tracks = {'));
      state.dispose();
    });

    test('Round-trip serialization and deserialization preserves song state', () {
      final state = DawState();
      state.projectName = 'Test Techno Track';
      state.setBpm(132.5);
      state.setMasterVolume(0.88);
      state.setLoopPoints(2, 6);

      // Modify active track notes and parameters
      final track = state.activeTrack;
      track.name = 'Acid 303 Lead';
      track.cutoff = 4500.0;
      track.resonance = 2.5;
      track.volume = 0.95;
      track.pan = -0.2;
      track.notes.add(Note(
        id: 'n_test_1',
        pitch: 36,
        startStep: 0.0,
        durationSteps: 0.5,
        velocity: 0.95,
        isAccent: true,
      ));
      track.notes.add(Note(
        id: 'n_test_2',
        pitch: 48,
        startStep: 1.0,
        durationSteps: 0.5,
        velocity: 0.70,
        isSlide: true,
      ));

      // Serialize
      final luaCode = state.exportToEatsLua();

      // Create new DAW state and load
      final newState = DawState();
      newState.loadFromEatsLua(luaCode);

      expect(newState.projectName, equals('Test Techno Track'));
      expect(newState.bpm, equals(132.5));
      expect(newState.masterVolume, equals(0.88));
      expect(newState.isLooping, isTrue);
      expect(newState.loopStartBar, equals(2));
      expect(newState.loopEndBar, equals(6));

      final loadedTrack = newState.patterns.first.tracks.firstWhere((t) => t.name == 'Acid 303 Lead');
      expect(loadedTrack.cutoff, equals(4500.0));
      expect(loadedTrack.resonance, equals(2.5));
      expect(loadedTrack.volume, equals(0.95));
      expect(loadedTrack.pan, equals(-0.2));

      expect(loadedTrack.notes.length, greaterThanOrEqualTo(2));
      final n1 = loadedTrack.notes.firstWhere((n) => n.id == 'n_test_1');
      expect(n1.pitch, equals(36));
      expect(n1.isAccent, isTrue);

      final n2 = loadedTrack.notes.firstWhere((n) => n.id == 'n_test_2');
      expect(n2.pitch, equals(48));
      expect(n2.isSlide, isTrue);

      state.dispose();
      newState.dispose();
    });

    test('Parses multiline embedded Lua clip code blocks', () {
      const sampleLuaFile = '''
return eatsbeats.song {
  meta = {
    title = "Generative Acid",
    bpm = 140.0,
  },
  tracks = {
    {
      id = "tr_gen",
      name = "Procedural Hats",
      type = "synth",
      clips = {
        {
          id = "c_1",
          name = "Gen Clip",
          luaScriptCode = [[
function process(notes, context)
  return notes
end
          ]],
        }
      }
    }
  }
}
''';

      final newState = DawState();
      newState.loadFromEatsLua(sampleLuaFile);

      expect(newState.projectName, equals('Generative Acid'));
      expect(newState.bpm, equals(140.0));

      final genTrack = newState.patterns.first.tracks.firstWhere((t) => t.name == 'Procedural Hats');
      expect(genTrack.clips.length, equals(1));
      expect(genTrack.clips.first.luaScriptCode, contains('function process(notes, context)'));
      newState.dispose();
    });

    test('Full default DawState export and re-import works cleanly with Lua comments', () {
      final state = DawState();
      final exported = state.exportToEatsLua();

      expect(exported, contains('return eatsbeats.song {'));

      final newState = DawState();
      expect(() => newState.loadFromEatsLua(exported), returnsNormally);
      expect(newState.patterns.first.tracks.length, equals(state.patterns.first.tracks.length));
      state.dispose();
      newState.dispose();
    });
  });

  group('Monophonic Track & Slide Detection Tests', () {
    test('TrackChannel detects monophonic tracks correctly', () {
      final track303 = TrackChannel(
        id: 't_303',
        name: 'TB-303',
        color: const Color(0xFF000000),
        type: TrackType.luaScript,
        luaScriptCode: 'local Acid303 = {}',
      );
      expect(track303.isMonophonicTrack, isTrue);

      final trackBass = TrackChannel(
        id: 't_bass',
        name: 'Bass Line',
        color: const Color(0xFF000000),
        type: TrackType.bass,
      );
      expect(trackBass.isMonophonicTrack, isTrue);

      final trackPoly = TrackChannel(
        id: 't_poly',
        name: 'Poly Synth',
        color: const Color(0xFF000000),
        type: TrackType.synth,
        isMonophonic: false,
      );
      expect(trackPoly.isMonophonicTrack, isFalse);
    });
  });
}
