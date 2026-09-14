import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/procgen/procedural_drum_engine.dart';
import 'package:eatsbeats/audio/procgen/procedural_song_engine.dart';
import 'package:eatsbeats/audio/sid_dsp_engine.dart';
import 'package:eatsbeats/eatscript/eats_dsp_synthesizer.dart';
import 'package:eatsbeats/eatscript/eats_script_library.dart';
import 'package:eatsbeats/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SIDDrumKitEngine Tests', () {
    test('Synthesizes valid non-empty audio buffers for GM drum notes', () {
      final drumNotes = [35, 36, 37, 38, 39, 40, 41, 42, 44, 46, 48, 49, 51];
      const params = <String, double>{
        'MasterTune': 0.0,
        'KickPunch': 0.75,
        'SnareSnap': 0.65,
        'NoiseMetal': 0.50,
        'ChipModel': 0.0,
        'Overdrive': 1.35,
      };

      for (final note in drumNotes) {
        final buffer = SIDDrumKitEngine.synthesizeBuffer(
          note: note,
          durationSec: 0.5,
          velocity: 0.9,
          params: params,
        );

        expect(buffer, isNotEmpty, reason: 'Drum note $note produced empty buffer');
        final maxAmp = buffer.map((s) => s.abs()).reduce(math.max);
        expect(maxAmp, greaterThan(0.01), reason: 'Drum note $note buffer has near-zero amplitude');
        expect(maxAmp, lessThanOrEqualTo(1.0), reason: 'Drum note $note clipped above 1.0');
      }
    });

    test('MasterTune shifts pitch of kick', () {
      final baseKick = SIDDrumKitEngine.synthesizeBuffer(
        note: 36,
        durationSec: 0.25,
        velocity: 0.9,
        params: {'MasterTune': 0.0},
      );
      final tunedKick = SIDDrumKitEngine.synthesizeBuffer(
        note: 36,
        durationSec: 0.25,
        velocity: 0.9,
        params: {'MasterTune': 12.0}, // +1 octave
      );

      expect(baseKick.length, equals(tunedKick.length));
      bool isDifferent = false;
      for (int i = 0; i < baseKick.length; i++) {
        if ((baseKick[i] - tunedKick[i]).abs() > 0.01) {
          isDifferent = true;
          break;
        }
      }
      expect(isDifferent, isTrue);
    });

    test('SnareSnap modulates noise ratio on snare notes', () {
      final tonalSnare = SIDDrumKitEngine.synthesizeBuffer(
        note: 38,
        durationSec: 0.25,
        velocity: 0.9,
        params: {'SnareSnap': 0.0},
      );
      final snappySnare = SIDDrumKitEngine.synthesizeBuffer(
        note: 38,
        durationSec: 0.25,
        velocity: 0.9,
        params: {'SnareSnap': 1.0},
      );

      bool differs = false;
      for (int i = 100; i < tonalSnare.length; i++) {
        if ((tonalSnare[i] - snappySnare[i]).abs() > 0.05) {
          differs = true;
          break;
        }
      }
      expect(differs, isTrue);
    });
  });

  group('Eatscript Library Preset & Synthesizer Integration', () {
    test('c64_sid_drum_kit preset exists in EatScriptLibrary', () {
      final preset = EatScriptLibrary.getPresetById('c64_sid_drum_kit');
      expect(preset, isNotNull);
      expect(preset!.name, equals('C64 SID Drum Kit'));
      expect(preset.code, contains('SIDDrumKit = True'));
    });

    test('EatDspSynthesizer routes c64_sid_drum_kit to SIDDrumKitEngine', () {
      final preset = EatScriptLibrary.getPresetById('c64_sid_drum_kit')!;
      final buffer = EatDspSynthesizer.synthesizeBuffer(
        code: preset.code,
        note: 36,
        freq: 440.0,
        durationSec: 0.3,
        velocity: 0.9,
        params: {'KickPunch': 0.8},
      );

      expect(buffer, isNotEmpty);
      final maxAmp = buffer.map((s) => s.abs()).reduce(math.max);
      expect(maxAmp, greaterThan(0.05));
    });
  });

  group('ProceduralDrumEngine 8-Bit Chiptune Style', () {
    test('Generates authentic C64 Chiptune drum pattern', () {
      final notes = ProceduralDrumEngine.generatePattern(
        style: '8-Bit Chiptune / C64 SID',
        bars: 4,
        density: 0.8,
        seed: 42,
      );

      expect(notes, isNotEmpty);
      // Contains kick (36), snare (38), and closed hat (42)
      expect(notes.any((n) => n.pitch == 36), isTrue);
      expect(notes.any((n) => n.pitch == 38), isTrue);
      expect(notes.any((n) => n.pitch == 42), isTrue);
    });
  });

  group('ProceduralSongEngine C64 SID 8-Bit Chiptune Genre', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    test('Generates 16-bar C64 SID Chiptune song across 4 tracks', () {
      final result = ProceduralSongEngine.generateToDawState(dawState, {
        'Style': 'C64 SID 8-Bit Chiptune',
        'Bars': 16,
        'Seed': 888,
        'Structure': 'Full Arrangement (Intro-Verse-Chorus-Outro)',
      });

      expect(result.isSuccess, isTrue);
      expect(dawState.bpm, equals(138.0));
      expect(dawState.loopStartBar, equals(0));
      expect(dawState.loopEndBar, equals(16));
      expect(dawState.isLooping, isTrue);
      expect(dawState.isSongMode, isTrue);

      final tracks = dawState.activePattern.tracks;
      expect(tracks.length, equals(4));

      // 1. Drum Track
      final drumTrack = tracks.firstWhere((t) => t.id == 'proc_track_drums');
      expect(drumTrack.name, equals('C64 SID Drum Kit'));
      expect(drumTrack.clips.length, greaterThanOrEqualTo(3));
      expect(drumTrack.clips.every((c) => c.notes.isNotEmpty), isTrue);

      // 2. Bass Track
      final bassTrack = tracks.firstWhere((t) => t.id == 'proc_track_bass');
      expect(bassTrack.name, equals('C64 SID PWM Bass'));
      expect(bassTrack.luaScriptCode, contains('Commodore 64'));

      // 3. Chord Track
      final chordTrack = tracks.firstWhere((t) => t.id == 'proc_track_chords');
      expect(chordTrack.name, equals('C64 SID 50Hz Arp'));
      expect(chordTrack.luaScriptCode, contains('Commodore 64'));

      // 4. Lead Track
      final leadTrack = tracks.firstWhere((t) => t.id == 'proc_track_lead');
      expect(leadTrack.name, equals('C64 SID Hero Lead'));
      expect(leadTrack.luaScriptCode, contains('Commodore 64'));

      // All tracks have notes
      for (final t in tracks) {
        final count = t.clips.fold<int>(0, (sum, c) => sum + c.notes.length);
        expect(count, greaterThan(15));
      }
    });

    test('32-bar C64 SID Chiptune song has non-empty clips and strictly bounded 0-based startSteps', () {
      final result = ProceduralSongEngine.generateToDawState(dawState, {
        'Style': 'C64 SID 8-Bit Chiptune',
        'Bars': 32,
        'Seed': 5555,
        'Structure': 'Full Arrangement (Intro-Verse-Chorus-Outro)',
      });

      expect(result.isSuccess, isTrue);
      final tracks = dawState.activePattern.tracks;
      expect(tracks.length, equals(4));

      for (final track in tracks) {
        expect(track.clips.length, equals(5));

        for (final clip in track.clips) {
          final maxAllowedStep = clip.barLength * 16.0;

          expect(
            clip.notes,
            isNotEmpty,
            reason: 'Clip "${clip.name}" in track "${track.name}" must not be empty',
          );

          for (final note in clip.notes) {
            expect(
              note.startStep,
              greaterThanOrEqualTo(0.0),
              reason: 'Track "${track.name}", clip "${clip.name}", note "${note.id}" startStep < 0',
            );
            expect(
              note.startStep,
              lessThan(maxAllowedStep),
              reason: 'Track "${track.name}", clip "${clip.name}", note "${note.id}" startStep (${note.startStep}) >= $maxAllowedStep',
            );
          }

          if (clip.barLength >= 8) {
            final firstFourBarsNotes = clip.notes.where((n) => n.startStep < 64.0).toList();
            expect(
              firstFourBarsNotes,
              isNotEmpty,
              reason: 'Clip "${clip.name}" in "${track.name}" must not have empty first 4 bars',
            );
          }
        }
      }
    });
    test('Resolves C64 SID style correctly when passed as dropdown index 7', () {
      final result = ProceduralSongEngine.generateToDawState(dawState, {
        'Style': 7, // Dropdown option index for C64 SID 8-Bit Chiptune
        'Bars': 16,
        'Seed': 12345,
      });

      expect(result.isSuccess, isTrue);
      final tracks = dawState.activePattern.tracks;
      expect(tracks.length, equals(4));
      expect(tracks[0].name, equals('C64 SID Drum Kit'));
      expect(tracks[1].name, equals('C64 SID PWM Bass'));
      expect(tracks[2].name, equals('C64 SID 50Hz Arp'));
      expect(tracks[3].name, equals('C64 SID Hero Lead'));
    });

    test('Resolves C64 SID style correctly when passed as all-caps string or ID', () {
      // 1. All-caps string
      ProceduralSongEngine.generateToDawState(dawState, {
        'Style': 'C64 SID 8-BIT CHIPTUNE',
        'Bars': 8,
        'Seed': 999,
      });
      var tracks = dawState.activePattern.tracks;
      expect(tracks[0].name, equals('C64 SID Drum Kit'));
      expect(tracks[1].name, equals('C64 SID PWM Bass'));

      // 2. ID string
      ProceduralSongEngine.generateToDawState(dawState, {
        'Style': 'c64_chiptune',
        'Bars': 8,
        'Seed': 999,
      });
      tracks = dawState.activePattern.tracks;
      expect(tracks[0].name, equals('C64 SID Drum Kit'));
      expect(tracks[1].name, equals('C64 SID PWM Bass'));
    });
  });
}
