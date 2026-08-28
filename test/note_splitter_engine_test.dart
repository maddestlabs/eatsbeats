import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/lua/note_splitter_engine.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteSplitterEngine Tests', () {
    final testNotes = [
      // Low bass notes (MIDI 36 = C2, 40 = E2)
      Note(id: 'b1', pitch: 36, startStep: 0, durationSteps: 8, velocity: 0.9),
      Note(id: 'b2', pitch: 40, startStep: 8, durationSteps: 8, velocity: 0.9),

      // Mid chord notes (MIDI 52 = E3, 55 = G3, 60 = C4)
      Note(id: 'c1', pitch: 52, startStep: 0, durationSteps: 8, velocity: 0.7),
      Note(id: 'c2', pitch: 55, startStep: 0, durationSteps: 8, velocity: 0.7),

      // High lead notes (MIDI 72 = C5, 76 = E5)
      Note(id: 'l1', pitch: 72, startStep: 0, durationSteps: 4, velocity: 0.85),
      Note(id: 'l2', pitch: 76, startStep: 4, durationSteps: 4, velocity: 0.85),
    ];

    test('3-Way Voice Splitter separates Bass, Chords, and Skyline Lead', () {
      final results = NoteSplitterEngine.split3WayVoice(
        testNotes,
        bassSplitPitch: 48,
        leadThresholdPitch: 64,
      );

      expect(results.length, equals(3));
      final bassTrack = results.firstWhere((r) => r.name.contains('Bass'));
      final chordTrack = results.firstWhere((r) => r.name.contains('Harmony') || r.name.contains('Chord'));
      final leadTrack = results.firstWhere((r) => r.name.contains('Lead'));

      expect(bassTrack.notes.length, equals(2));
      expect(bassTrack.notes.map((n) => n.pitch), containsAll([36, 40]));

      expect(chordTrack.notes.length, equals(2));
      expect(chordTrack.notes.map((n) => n.pitch), containsAll([52, 55]));

      expect(leadTrack.notes.length, equals(2));
      expect(leadTrack.notes.map((n) => n.pitch), containsAll([72, 76]));
    });

    test('Bass & Treble Clef Splitter splits at pivot pitch C4 (60)', () {
      final results = NoteSplitterEngine.splitBassTreble(
        testNotes,
        splitPitch: 60,
      );

      expect(results.length, equals(2));
      final leftHand = results.firstWhere((r) => r.name.contains('Bass Clef'));
      final rightHand = results.firstWhere((r) => r.name.contains('Treble Clef'));

      // Left hand: pitches < 60 -> 36, 40, 52, 55
      expect(leftHand.notes.length, equals(4));
      // Right hand: pitches >= 60 -> 72, 76
      expect(rightHand.notes.length, equals(2));
    });

    test('4-Voice Polyphony Distribute separates chord cluster into 4 voices', () {
      final chordCluster = [
        Note(id: 'n1', pitch: 48, startStep: 0, durationSteps: 16, velocity: 0.8), // C3 (Bass)
        Note(id: 'n2', pitch: 55, startStep: 0, durationSteps: 16, velocity: 0.8), // G3 (Tenor)
        Note(id: 'n3', pitch: 60, startStep: 0, durationSteps: 16, velocity: 0.8), // C4 (Alto)
        Note(id: 'n4', pitch: 64, startStep: 0, durationSteps: 16, velocity: 0.8), // E4 (Soprano)
      ];

      final results = NoteSplitterEngine.split4VoicePolyphony(chordCluster);
      expect(results.length, equals(4));

      final soprano = results.firstWhere((r) => r.name.contains('Soprano'));
      final alto = results.firstWhere((r) => r.name.contains('Alto'));
      final tenor = results.firstWhere((r) => r.name.contains('Tenor'));
      final bass = results.firstWhere((r) => r.name.contains('Bass'));

      expect(soprano.notes.first.pitch, equals(64));
      expect(alto.notes.first.pitch, equals(60));
      expect(tenor.notes.first.pitch, equals(55));
      expect(bass.notes.first.pitch, equals(48));
    });

    test('Drum & Percussion Demuxer splits GM drum kit note numbers', () {
      final drumNotes = [
        Note(id: 'd1', pitch: 36, startStep: 0, durationSteps: 1, velocity: 0.9), // Kick
        Note(id: 'd2', pitch: 38, startStep: 4, durationSteps: 1, velocity: 0.9), // Snare
        Note(id: 'd3', pitch: 42, startStep: 0, durationSteps: 1, velocity: 0.7), // Closed Hat
        Note(id: 'd4', pitch: 46, startStep: 2, durationSteps: 1, velocity: 0.7), // Open Hat
        Note(id: 'd5', pitch: 45, startStep: 8, durationSteps: 1, velocity: 0.8), // Low Tom
      ];

      final results = NoteSplitterEngine.splitDrumPercussion(drumNotes);
      expect(results.length, equals(4));

      final kick = results.firstWhere((r) => r.name.contains('Kick'));
      final snare = results.firstWhere((r) => r.name.contains('Snare'));
      final hats = results.firstWhere((r) => r.name.contains('Hats'));
      final toms = results.firstWhere((r) => r.name.contains('Toms'));

      expect(kick.notes.first.pitch, equals(36));
      expect(snare.notes.first.pitch, equals(38));
      expect(hats.notes.length, equals(2));
      expect(toms.notes.first.pitch, equals(45));
    });

    test('LuaScriptLibrary contains noteSplitter category presets', () {
      final presets = LuaScriptLibrary.getPresetsByCategory(LuaScriptCategory.noteSplitter);
      expect(presets.isNotEmpty, isTrue);
      expect(presets.any((p) => p.name.contains('3-Way Voice')), isTrue);
      expect(presets.any((p) => p.name.contains('Bass & Treble Clef')), isTrue);
      expect(presets.any((p) => p.name.contains('4-Voice Polyphony')), isTrue);
      expect(presets.any((p) => p.name.contains('Drum & Percussion')), isTrue);
    });

    test('DawState.splitClipNotesWithPreset generates tracks with undo/redo support', () {
      final dawState = DawState();
      final clip = TrackClip(
        id: 'clip_source',
        name: 'Master Piano',
        trackId: dawState.activeTrack.id,
        startBar: 0,
        barLength: 4,
        notes: List.from(testNotes),
      );

      final initialTrackCount = dawState.activePattern.tracks.length;
      final preset = LuaScriptLibrary.getPresetsByCategory(LuaScriptCategory.noteSplitter).first;

      final created = dawState.splitClipNotesWithPreset(clip, preset);
      expect(created.isNotEmpty, isTrue);
      expect(dawState.activePattern.tracks.length, equals(initialTrackCount + created.length));

      // Test Undo
      expect(dawState.history.canUndo, isTrue);
      dawState.undo();
      expect(dawState.activePattern.tracks.length, equals(initialTrackCount));

      // Test Redo
      expect(dawState.history.canRedo, isTrue);
      dawState.redo();
      expect(dawState.activePattern.tracks.length, equals(initialTrackCount + created.length));
    });
  });
}
