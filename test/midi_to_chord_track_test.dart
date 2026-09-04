import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/utils/midi_file_parser.dart';
import 'package:eatsbeats/ui/arranger_view.dart';
import 'package:eatsbeats/ui/widgets/arranger_context_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MIDI to Chord Track Analysis & State Tests', () {
    test('extractAndApplyChordsFromClip analyzes standard MIDI clip notes and creates chord events', () {
      final dawState = DawState(enableMeterTimer: false);
      expect(dawState.chordTrack, isEmpty);

      // Create a MIDI clip with C Major chord (C4=60, E4=64, G4=67) at bar 0, duration 1 bar (16 steps)
      // and G Major chord (G4=67, B4=71, D5=74) at bar 1, duration 1 bar (16 steps)
      final clip = TrackClip(
        id: 'clip_c_g',
        name: 'Chords Clip',
        trackId: dawState.activeTrack.id,
        startBar: 0,
        barLength: 2,
        notes: [
          // Bar 0: C Major
          Note(id: 'c1', pitch: 60, startStep: 0, durationSteps: 16),
          Note(id: 'e1', pitch: 64, startStep: 0, durationSteps: 16),
          Note(id: 'g1', pitch: 67, startStep: 0, durationSteps: 16),
          // Bar 1: G Major
          Note(id: 'g2', pitch: 67, startStep: 16, durationSteps: 16),
          Note(id: 'b2', pitch: 71, startStep: 16, durationSteps: 16),
          Note(id: 'd3', pitch: 74, startStep: 16, durationSteps: 16),
        ],
      );

      final count = dawState.extractAndApplyChordsFromClip(clip);
      expect(count, equals(2));
      expect(dawState.chordTrack.length, equals(2));

      expect(dawState.chordTrack[0].startBar, equals(0));
      expect(dawState.chordTrack[0].rootPitchClass, equals(0)); // C
      expect(dawState.chordTrack[0].quality, equals(ChordQuality.major));
      expect(dawState.chordTrack[0].displayName, equals('C'));

      expect(dawState.chordTrack[1].startBar, equals(1));
      expect(dawState.chordTrack[1].rootPitchClass, equals(7)); // G
      expect(dawState.chordTrack[1].quality, equals(ChordQuality.major));
      expect(dawState.chordTrack[1].displayName, equals('G'));
    });

    test('extractAndApplyChordsFromTrack analyzes multi-clip track across timeline', () {
      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      track.clips.clear();

      // Clip 1 at Bar 0: A Minor (A3=57, C4=60, E4=64)
      final clip1 = TrackClip(
        id: 'c1',
        name: 'Am Clip',
        trackId: track.id,
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'a1', pitch: 57, startStep: 0, durationSteps: 16),
          Note(id: 'c1', pitch: 60, startStep: 0, durationSteps: 16),
          Note(id: 'e1', pitch: 64, startStep: 0, durationSteps: 16),
        ],
      );

      // Clip 2 at Bar 1: F Major (F3=53, A3=57, C4=60)
      final clip2 = TrackClip(
        id: 'c2',
        name: 'F Clip',
        trackId: track.id,
        startBar: 1,
        barLength: 1,
        notes: [
          Note(id: 'f1', pitch: 53, startStep: 0, durationSteps: 16),
          Note(id: 'a2', pitch: 57, startStep: 0, durationSteps: 16),
          Note(id: 'c2', pitch: 60, startStep: 0, durationSteps: 16),
        ],
      );

      track.clips.addAll([clip1, clip2]);

      final count = dawState.extractAndApplyChordsFromTrack(track);
      expect(count, equals(2));
      expect(dawState.chordTrack.length, equals(2));
      expect(dawState.chordTrack[0].displayName, equals('Am'));
      expect(dawState.chordTrack[1].displayName, equals('F'));
    });

    test('extractAndApplyChordsFromMidiTrack analyzes transcribed audio MIDI notes', () {
      final dawState = DawState(enableMeterTimer: false);

      // Simulated ParsedMidiTrack from audio transcription
      final parsed = ParsedMidiTrack(
        trackIndex: 0,
        name: 'Guitar Transcribed',
        notes: [
          // D Minor (D4=62, F4=65, A4=69)
          Note(id: 'd', pitch: 62, startStep: 0, durationSteps: 16),
          Note(id: 'f', pitch: 65, startStep: 0, durationSteps: 16),
          Note(id: 'a', pitch: 69, startStep: 0, durationSteps: 16),
        ],
      );

      final count = dawState.extractAndApplyChordsFromMidiTrack(parsed);
      expect(count, equals(1));
      expect(dawState.chordTrack.first.displayName, equals('Dm'));
      expect(dawState.chordTrack.first.startBar, equals(0));
    });

    test('Merging identical consecutive chords across multiple bars works as expected', () {
      final dawState = DawState(enableMeterTimer: false);

      // C Major spanning across bar 0 and bar 1
      final clip = TrackClip(
        id: 'c_long',
        name: 'Long C',
        trackId: dawState.activeTrack.id,
        startBar: 0,
        barLength: 2,
        notes: [
          Note(id: 'c', pitch: 60, startStep: 0, durationSteps: 32),
          Note(id: 'e', pitch: 64, startStep: 0, durationSteps: 32),
          Note(id: 'g', pitch: 67, startStep: 0, durationSteps: 32),
        ],
      );

      final count = dawState.extractAndApplyChordsFromClip(clip);
      expect(count, equals(1));
      expect(dawState.chordTrack.length, equals(1));
      expect(dawState.chordTrack.first.displayName, equals('C'));
      expect(dawState.chordTrack.first.startBar, equals(0));
      expect(dawState.chordTrack.first.barLength, equals(2.0));
    });
  });

  group('MIDI to Chord Track Undo & Redo Lifecycle Tests', () {
    test('Extract chords from clip is completely undo-able and redo-able', () {
      final dawState = DawState(enableMeterTimer: false);

      // Add pre-existing chord at Bar 4
      dawState.addOrUpdateChord(ChordEvent(
        id: 'existing_d',
        startBar: 4,
        barLength: 1.0,
        rootPitchClass: 2,
        quality: ChordQuality.minor,
      ));
      expect(dawState.chordTrack.length, equals(1));
      expect(dawState.chordTrack.first.displayName, equals('Dm'));

      // Create new clip at Bar 0 with C Major
      final clip = TrackClip(
        id: 'c_clip',
        name: 'New C Clip',
        trackId: dawState.activeTrack.id,
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'c', pitch: 60, startStep: 0, durationSteps: 16),
          Note(id: 'e', pitch: 64, startStep: 0, durationSteps: 16),
          Note(id: 'g', pitch: 67, startStep: 0, durationSteps: 16),
        ],
      );

      // Extract chords
      final count = dawState.extractAndApplyChordsFromClip(clip);
      expect(count, equals(1));
      expect(dawState.chordTrack.length, equals(2));
      expect(dawState.chordTrack[0].displayName, equals('C'));
      expect(dawState.chordTrack[1].displayName, equals('Dm'));

      // Perform Undo
      expect(dawState.history.canUndo, isTrue);
      expect(dawState.undo(), isTrue);

      // Chord track should be exactly restored to initial state
      expect(dawState.chordTrack.length, equals(1));
      expect(dawState.chordTrack.first.displayName, equals('Dm'));
      expect(dawState.chordTrack.first.startBar, equals(4));

      // Perform Redo
      expect(dawState.history.canRedo, isTrue);
      expect(dawState.redo(), isTrue);

      // Chord track should re-apply the extracted chord
      expect(dawState.chordTrack.length, equals(2));
      expect(dawState.chordTrack[0].displayName, equals('C'));
      expect(dawState.chordTrack[1].displayName, equals('Dm'));
    });

    test('Extract chords from track is completely undo-able and redo-able', () {
      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      track.clips.clear();

      final clip = TrackClip(
        id: 'g_clip',
        name: 'G Track Clip',
        trackId: track.id,
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'g', pitch: 67, startStep: 0, durationSteps: 16),
          Note(id: 'b', pitch: 71, startStep: 0, durationSteps: 16),
          Note(id: 'd', pitch: 74, startStep: 0, durationSteps: 16),
        ],
      );
      track.clips.add(clip);

      final count = dawState.extractAndApplyChordsFromTrack(track);
      expect(count, equals(1));
      expect(dawState.chordTrack.length, equals(1));
      expect(dawState.chordTrack.first.displayName, equals('G'));

      // Undo
      expect(dawState.undo(), isTrue);
      expect(dawState.chordTrack, isEmpty);

      // Redo
      expect(dawState.redo(), isTrue);
      expect(dawState.chordTrack.length, equals(1));
      expect(dawState.chordTrack.first.displayName, equals('G'));
    });

    test('Extract chords from ParsedMidiTrack is completely undo-able and redo-able', () {
      final dawState = DawState(enableMeterTimer: false);

      final parsed = ParsedMidiTrack(
        trackIndex: 0,
        name: 'Vocal Chords',
        notes: [
          Note(id: 'f', pitch: 65, startStep: 0, durationSteps: 16),
          Note(id: 'a', pitch: 69, startStep: 0, durationSteps: 16),
          Note(id: 'c', pitch: 72, startStep: 0, durationSteps: 16),
        ],
      );

      final count = dawState.extractAndApplyChordsFromMidiTrack(parsed);
      expect(count, equals(1));
      expect(dawState.chordTrack.first.displayName, equals('F'));

      // Undo
      expect(dawState.undo(), isTrue);
      expect(dawState.chordTrack, isEmpty);

      // Redo
      expect(dawState.redo(), isTrue);
      expect(dawState.chordTrack.first.displayName, equals('F'));
    });
  });

  group('UI Integration Widget Tests', () {
    testWidgets('ArrangerView displays Chords button in chord header and opens Chords dialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find tooltip or icon for Chords button
      final chordsBtn = find.byTooltip('Chords');
      expect(chordsBtn, findsOneWidget);

      // Tap to open Chords dialog
      await tester.tap(chordsBtn);
      await tester.pumpAndSettle();

      // Should show 'CHORDS' label in lane and dialog header
      expect(find.text('CHORDS'), findsNWidgets(2));
      // Should show 'Browse' button
      expect(find.text('Browse'), findsOneWidget);
      // Should show 'Extract from Active Track'
      expect(find.textContaining('Extract from Active Track'), findsOneWidget);
    });

    testWidgets('ArrangerContextInspector shows Extract Chords to Chord Track button for MIDI clips and tracks', (tester) async {
      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      final clip = TrackClip(
        id: 'test_clip',
        name: 'Piano Clip',
        trackId: track.id,
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 16),
          Note(id: 'n2', pitch: 64, startStep: 0, durationSteps: 16),
          Note(id: 'n3', pitch: 67, startStep: 0, durationSteps: 16),
        ],
      );
      track.clips.add(clip);
      dawState.selectClip(clip);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerContextInspector(
              dawState: dawState,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show Extract Chords to Chord Track button in clip section
      final extractBtn = find.text('EXTRACT CHORDS TO CHORD TRACK');
      expect(extractBtn, findsOneWidget);

      // Tap button
      await tester.tap(extractBtn);
      await tester.pumpAndSettle();

      // Verify chord track now has C major chord
      expect(dawState.chordTrack.length, equals(1));
      expect(dawState.chordTrack.first.displayName, equals('C'));

      // Verify Undo works
      expect(dawState.undo(), isTrue);
      expect(dawState.chordTrack, isEmpty);
    });
  });
}
