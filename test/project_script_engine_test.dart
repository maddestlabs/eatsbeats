import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/script_target_model.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/lua/project_script_engine.dart';
import 'package:eatsbeats/ui/widgets/project_script_runner_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProjectScriptEngine & Project-Wide Lua Action Scripts Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    test('getAllScriptTargets includes Project Action scripts', () {
      final targets = dawState.getAllScriptTargets();
      final projectTargets = targets.where((t) => t.type == ScriptTargetType.projectAction).toList();

      expect(projectTargets, isNotEmpty);
      expect(projectTargets.any((t) => t.title.contains('Global Chord-Aware Song Transpose')), isTrue);
      expect(projectTargets.any((t) => t.title.contains('Harmonic Progression Generator')), isTrue);
      expect(projectTargets.any((t) => t.title.contains('Procedural Multi-Track Song Generator')), isTrue);
      expect(projectTargets.any((t) => t.title.contains('Groove & Velocity Humanizer')), isTrue);
    });

    test('Global Chord-Aware Transposition shifts key, chords, and track notes', () {
      dawState.setSongKey('C Major');
      dawState.chordTrack = [
        ChordEvent(
          id: 'chord_c',
          startBar: 0,
          barLength: 2.0,
          rootPitchClass: 0, // C
          quality: ChordQuality.major,
        ),
      ];

      for (final p in dawState.patterns) {
        p.tracks.clear();
      }

      final testNotes = [
        Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 1.0), // C4 (60)
        Note(id: 'n2', pitch: 64, startStep: 1, durationSteps: 1.0), // E4 (64)
        Note(id: 'n3', pitch: 67, startStep: 2, durationSteps: 1.0), // G4 (67)
      ];

      final track = TrackChannel(
        id: 'track_lead_synth',
        name: 'Lead Synth',
        color: const Color(0xFF21F4E8),
        type: TrackType.synth,
        notes: testNotes,
      );
      final clip = TrackClip(
        id: 'clip_t',
        name: 'Lead Melody',
        trackId: track.id,
        notes: testNotes,
      );
      track.clips = [clip];
      dawState.activePattern.tracks.add(track);

      final script = LuaScriptLibrary.getScriptsByCategory(LuaScriptCategory.projectAction)
          .firstWhere((s) => s.id == 'action_global_transpose');

      // Transpose +2 semitones (C -> D)
      final result = dawState.runProjectScript(
        script,
        params: {'Semitones': 2, 'HarmonicMode': 0, 'UpdateKey': 1},
      );

      expect(result.isSuccess, isTrue);
      expect(dawState.songKey, equals('D Major'));
      expect(dawState.chordTrack.first.rootPitchClass, equals(2)); // D
      expect(clip.notes[0].pitch, equals(62)); // D4
      expect(clip.notes[1].pitch, equals(66)); // F#4
      expect(clip.notes[2].pitch, equals(69)); // A4

      // Test Undo restores everything back to C Major and pitches 60, 64, 67
      expect(dawState.undo(), isTrue);
      expect(dawState.songKey, equals('C Major'));
      expect(dawState.chordTrack.first.rootPitchClass, equals(0));
      final restoredClip = dawState.activePattern.tracks.first.clips.first;
      expect(restoredClip.notes[0].pitch, equals(60));
      expect(restoredClip.notes[1].pitch, equals(64));
      expect(restoredClip.notes[2].pitch, equals(67));
    });

    test('Harmonic Progression Generator populates ChordTrack and conforms notes', () {
      dawState.setSongKey('A Minor');
      final script = LuaScriptLibrary.getScriptsByCategory(LuaScriptCategory.projectAction)
          .firstWhere((s) => s.id == 'action_harmonic_progression');

      final result = dawState.runProjectScript(
        script,
        params: {'Genre': 0, 'LengthBars': 8, 'ConformTracks': 1}, // Synthwave
      );

      expect(result.isSuccess, isTrue);
      expect(dawState.chordTrack, isNotEmpty);
      expect(dawState.chordTrack.length, greaterThanOrEqualTo(4));
      expect(result.affectedChordsCount, equals(dawState.chordTrack.length));
    });

    test('Procedural Multi-Track Song Generator creates full 4-track arrangement', () {
      final script = LuaScriptLibrary.getScriptsByCategory(LuaScriptCategory.projectAction)
          .firstWhere((s) => s.id == 'action_procedural_song');

      final result = dawState.runProjectScript(
        script,
        params: {'Style': 0, 'Bpm': 128.0, 'Bars': 8},
      );

      expect(result.isSuccess, isTrue);
      expect(dawState.bpm, equals(128.0));
      expect(dawState.activePattern.tracks.length, equals(4));

      final drumTrack = dawState.activePattern.tracks.firstWhere((t) => t.id == 'proc_track_drums');
      final bassTrack = dawState.activePattern.tracks.firstWhere((t) => t.id == 'proc_track_bass');
      final chordTrack = dawState.activePattern.tracks.firstWhere((t) => t.id == 'proc_track_chords');
      final leadTrack = dawState.activePattern.tracks.firstWhere((t) => t.id == 'proc_track_lead');

      expect(drumTrack.clips.first.notes, isNotEmpty);
      expect(bassTrack.clips.first.notes, isNotEmpty);
      expect(chordTrack.clips.first.notes, isNotEmpty);
      expect(leadTrack.clips.first.notes, isNotEmpty);

      // Verify history snapshot undo works
      expect(dawState.undo(), isTrue);
    });

    test('Groove & Velocity Humanizer applies subtle variations', () {
      for (final p in dawState.patterns) {
        p.tracks.clear();
      }

      final track = TrackChannel(
        id: 'track_human',
        name: 'Humanize Channel',
        color: const Color(0xFF00FF66),
        type: TrackType.synth,
      );
      final clip = TrackClip(
        id: 'clip_human',
        name: 'Humanize Test',
        trackId: track.id,
        notes: [
          Note(id: 'hn1', pitch: 60, startStep: 4.0, velocity: 0.8),
          Note(id: 'hn2', pitch: 62, startStep: 8.0, velocity: 0.8),
        ],
      );
      track.clips = [clip];
      dawState.activePattern.tracks.add(track);

      final script = LuaScriptLibrary.getScriptsByCategory(LuaScriptCategory.projectAction)
          .firstWhere((s) => s.id == 'action_humanize_groove');

      final result = dawState.runProjectScript(
        script,
        params: {'TimingJitter': 0.05, 'VelocityJitter': 0.15},
      );

      expect(result.isSuccess, isTrue);
      expect(result.affectedNotesCount, equals(2));
    });

    testWidgets('ProjectScriptRunnerDialog renders parameters and executes script', (tester) async {
      final script = LuaScriptLibrary.getScriptsByCategory(LuaScriptCategory.projectAction)
          .firstWhere((s) => s.id == 'action_global_transpose');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ProjectScriptRunnerDialog.show(ctx, dawState: dawState, script: script),
                child: const Text('OPEN DIALOG'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pumpAndSettle();

      expect(find.text('Global Chord-Aware Song Transpose'), findsOneWidget);
      expect(find.text('EXECUTE ON PROJECT'), findsOneWidget);
      expect(find.text('SEMITONES'), findsOneWidget);

      await tester.tap(find.text('EXECUTE ON PROJECT'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectScriptRunnerDialog), findsNothing);
    });
  });
}
