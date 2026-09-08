import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/procgen/procedural_piano_engine.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProceduralPianoEngine Core Tests', () {
    test('Mulberry32Rng is deterministic with identical seed', () {
      final rng1 = Mulberry32Rng(42);
      final rng2 = Mulberry32Rng(42);

      for (int i = 0; i < 20; i++) {
        expect(rng1.nextDouble(), equals(rng2.nextDouble()));
      }
    });

    test('Generates deterministic piece for given seed and style', () {
      final pieceA = ProceduralPianoEngine.generatePiece(
        seed: 12345,
        style: 'nocturne',
        root: 'D',
        mode: 'minor',
      );

      final pieceB = ProceduralPianoEngine.generatePiece(
        seed: 12345,
        style: 'nocturne',
        root: 'D',
        mode: 'minor',
      );

      expect(pieceA.totalBars, equals(pieceB.totalBars));
      expect(pieceA.notes.length, equals(pieceB.notes.length));
      expect(pieceA.chords.length, equals(pieceB.chords.length));

      for (int i = 0; i < pieceA.notes.length; i++) {
        expect(pieceA.notes[i].pitch, equals(pieceB.notes[i].pitch));
        expect(pieceA.notes[i].time, equals(pieceB.notes[i].time));
        expect(pieceA.notes[i].hand, equals(pieceB.notes[i].hand));
      }
    });

    test('Different styles generate appropriate meter and tempos', () {
      final nocturne = ProceduralPianoEngine.generatePiece(seed: 1, style: 'nocturne');
      expect(nocturne.beats, equals(4));
      expect(nocturne.meter, equals('4/4'));

      final waltz = ProceduralPianoEngine.generatePiece(seed: 1, style: 'waltz');
      expect(waltz.beats, equals(3));
      expect(waltz.meter, equals('3/4'));

      final barcarolle = ProceduralPianoEngine.generatePiece(seed: 1, style: 'barcarolle');
      expect(barcarolle.beats, equals(2));
      expect(barcarolle.meter, equals('6/8'));

      final blues = ProceduralPianoEngine.generatePiece(seed: 1, style: 'blues');
      expect(blues.beats, equals(4));
      expect(blues.swing, isTrue);
    });

    test('Performance offsets provide right hand melody lead and rubato scaling', () {
      final piece = ProceduralPianoEngine.generatePiece(seed: 99, style: 'nocturne');
      final offsets = ProceduralPianoEngine.performTimingOffsets(piece);

      expect(offsets.length, equals(piece.notes.length));

      // Check right hand melody notes lead the beat (negative offset)
      int melodyLeadCount = 0;
      for (int i = 0; i < piece.notes.length; i++) {
        final n = piece.notes[i];
        if (n.hand == 'right' && offsets[i] < 0) {
          melodyLeadCount++;
        }
      }
      expect(melodyLeadCount, greaterThan(0));
    });
  });

  group('ProceduralPianoEngine DawState Integration Tests', () {
    late DawState state;

    setUp(() {
      state = DawState();
    });

    test('Generates two tracks layout with Concert Grand Piano', () {
      final result = ProceduralPianoEngine.generateToDawState(state, {
        'Style': 'Nocturne',
        'Root': 'D',
        'Mode': 'Minor',
        'Seed': 42,
        'TrackLayout': 'Two Tracks (Right/Left Hand)',
      });

      expect(result.isSuccess, isTrue);
      expect(state.activePattern.tracks.length, equals(2));

      final rightTrack = state.activePattern.tracks[0];
      final leftTrack = state.activePattern.tracks[1];

      expect(rightTrack.name, contains('Right Hand'));
      expect(leftTrack.name, contains('Left Hand'));
      expect(rightTrack.clips.first.notes, isNotEmpty);
      expect(leftTrack.clips.first.notes, isNotEmpty);

      // Verify song key & chords updated
      expect(state.songKeyRoot, equals(2)); // D
      expect(state.isSongKeyMinor, isTrue);
      expect(state.chordTrack, isNotEmpty);
    });

    test('Generates single unified track layout', () {
      final result = ProceduralPianoEngine.generateToDawState(state, {
        'Style': 'Prelude',
        'Root': 'G',
        'Mode': 'Major',
        'Seed': 100,
        'TrackLayout': 'Single Unified Track',
      });

      expect(result.isSuccess, isTrue);
      expect(state.activePattern.tracks.length, equals(1));

      final track = state.activePattern.tracks.first;
      expect(track.name, equals('Concert Grand Piano'));
      expect(track.clips.first.notes.length, greaterThan(20));
      expect(state.songKeyRoot, equals(7)); // G
    });

    test('STMN Procedural Piano script is registered and executable via DawState', () {
      final preset = LuaPresetLibrary.getPresetById('action_stmn_procedural_piano');
      expect(preset, isNotNull);
      expect(preset!.name, equals('STMN Procedural Piano'));
      expect(preset.category, equals(LuaScriptCategory.projectAction));

      final result = state.runProjectScript(preset, params: {
        'Style': 0, // Nocturne
        'Root': 0, // C
        'Mode': 0, // Major
        'Seed': 777,
        'TrackLayout': 0, // Two Tracks
      });

      expect(result.isSuccess, isTrue);
      expect(state.activePattern.tracks.length, equals(2));
      expect(state.chordTrack, isNotEmpty);
    });
  });
}
