import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/script_view.dart';
import 'package:eatsbeats/ui/edit_view.dart';
import 'package:eatsbeats/ui/widgets/note_inspector_sidebar.dart';
import 'package:eatsbeats/theme/eats_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unified Note Selection & Persistent State Tests', () {
    late DawState dawState;
    late TrackChannel track;

    setUp(() {
      dawState = DawState();
      track = TrackChannel(
        id: 'track_test_1',
        name: 'Lead Synth',
        color: Colors.cyan,
        type: TrackType.synth,
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 1.0, velocity: 0.9), // C4
          Note(id: 'n2', pitch: 64, startStep: 1.0, durationSteps: 1.0, velocity: 0.8), // E4
          Note(id: 'n3', pitch: 67, startStep: 2.0, durationSteps: 2.0, velocity: 0.85), // G4
        ],
      );
      dawState.tracks.clear();
      dawState.tracks.add(track);
      dawState.activeTrackIndex = 0;
    });

    test('TrackChannel selectedNoteIds state and helper getters', () {
      expect(track.selectedNoteIds, isEmpty);
      expect(track.hasSelectedNotes, isFalse);
      expect(track.selectedNotes, isEmpty);

      dawState.selectNotes(track, ['n1', 'n3']);

      expect(track.selectedNoteIds.length, equals(2));
      expect(track.hasSelectedNotes, isTrue);
      expect(track.isNoteSelected('n1'), isTrue);
      expect(track.isNoteSelected('n2'), isFalse);
      expect(track.isNoteSelected('n3'), isTrue);
      expect(track.selectedNotes.map((n) => n.id).toList(), equals(['n1', 'n3']));
    });

    test('toggleNoteSelection, selectAllNotes, invertNoteSelection, clearNoteSelection', () {
      dawState.selectNotes(track, ['n1']);
      expect(track.selectedNoteIds, equals({'n1'}));

      // Toggle n2 (adds it)
      dawState.toggleNoteSelection(track, 'n2');
      expect(track.selectedNoteIds, equals({'n1', 'n2'}));

      // Toggle n1 (removes it)
      dawState.toggleNoteSelection(track, 'n1');
      expect(track.selectedNoteIds, equals({'n2'}));

      // Invert selection (should select n1 and n3)
      dawState.invertNoteSelection(track);
      expect(track.selectedNoteIds, equals({'n1', 'n3'}));

      // Select All
      dawState.selectAllNotes(track);
      expect(track.selectedNoteIds, equals({'n1', 'n2', 'n3'}));

      // Clear
      dawState.clearNoteSelection(track);
      expect(track.selectedNoteIds, isEmpty);
      expect(track.hasSelectedNotes, isFalse);
    });

    test('removeNote and removeNotes automatically cleans up selectedNoteIds', () {
      dawState.selectNotes(track, ['n1', 'n2']);
      expect(track.selectedNoteIds.length, equals(2));

      // Remove n1
      dawState.removeNote(track, 'n1');
      expect(track.notes.length, equals(2));
      expect(track.selectedNoteIds, equals({'n2'}));

      // Remove n2
      dawState.removeNotes(track, ['n2']);
      expect(track.notes.length, equals(1));
      expect(track.selectedNoteIds, isEmpty);
    });

    test('Batch transpose, quantize, and humanize on selected notes', () {
      dawState.selectNotes(track, ['n1', 'n2']);

      // Transpose selected notes by 2 semitones
      dawState.transposeNotes(track, track.selectedNoteIds, 2);
      expect(track.notes.firstWhere((n) => n.id == 'n1').pitch, equals(62)); // D4
      expect(track.notes.firstWhere((n) => n.id == 'n2').pitch, equals(66)); // F#4
      expect(track.notes.firstWhere((n) => n.id == 'n3').pitch, equals(67)); // Untouched G4

      // Quantize to snap 2.0
      dawState.batchQuantizeNotes(track, track.selectedNoteIds, 2.0);
      expect(track.notes.firstWhere((n) => n.id == 'n1').startStep, equals(0.0));
      expect(track.notes.firstWhere((n) => n.id == 'n2').startStep, equals(2.0));

      // Batch set articulation
      dawState.setNotesArticulation(track, track.selectedNoteIds, 'pizzicato');
      expect(track.notes.firstWhere((n) => n.id == 'n1').articulation, equals('pizzicato'));
      expect(track.notes.firstWhere((n) => n.id == 'n2').articulation, equals('pizzicato'));
      expect(track.notes.firstWhere((n) => n.id == 'n3').articulation, isNull);
    });
  });

  group('Note Pitch Parsing & Declarative Formatting Tests', () {
    test('Note.formatPitch correctly converts MIDI numbers to pitch names', () {
      expect(Note.formatPitch(60), equals('C4'));
      expect(Note.formatPitch(61), equals('C#4'));
      expect(Note.formatPitch(69), equals('A4'));
      expect(Note.formatPitch(72), equals('C5'));
      expect(Note.formatPitch(24), equals('C1'));
    });

    test('Note.parsePitch correctly parses standard scientific pitch notation', () {
      expect(Note.parsePitch('C4'), equals(60));
      expect(Note.parsePitch('c4'), equals(60));
      expect(Note.parsePitch('C#4'), equals(61));
      expect(Note.parsePitch('Db4'), equals(61));
      expect(Note.parsePitch('A4'), equals(69));
      expect(Note.parsePitch('C5'), equals(72));
      expect(Note.parsePitch('60'), equals(60));
      expect(Note.parsePitch('P60'), equals(60));
      expect(Note.parsePitch('invalid'), isNull);
    });
  });

  group('ScriptView Widget Mounting Tests', () {
    testWidgets('ScriptView mounts without assertion error or crashing', (WidgetTester tester) async {
      final dawState = DawState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScriptView(dawState: dawState),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ScriptView), findsOneWidget);
    });
  });

  group('Tracker Multi-Selection & Deselection Persistence Tests', () {
    test('Tracker block selection and accumulator toggles sync with track.selectedNoteIds', () {
      final dawState = DawState();
      final track = TrackChannel(
        id: 't_tracker',
        name: 'Chiptune Bass',
        color: Colors.purple,
        type: TrackType.synth,
        trackerColumns: 2,
        notes: [
          Note(id: 'note_0_0', pitch: 36, startStep: 0.0, column: 0),
          Note(id: 'note_2_0', pitch: 38, startStep: 2.0, column: 0),
          Note(id: 'note_2_1', pitch: 48, startStep: 2.0, column: 1),
          Note(id: 'note_4_0', pitch: 40, startStep: 4.0, column: 0),
        ],
      );
      dawState.tracks.clear();
      dawState.tracks.add(track);
      dawState.activeTrackIndex = 0;

      // 1. Initial state: nothing selected
      expect(track.selectedNoteIds, isEmpty);

      // 2. Accumulator (Ctrl-click / Ctrl-Space): Select non-adjacent notes
      dawState.toggleNoteSelection(track, 'note_0_0');
      dawState.toggleNoteSelection(track, 'note_4_0');
      expect(track.selectedNoteIds, equals({'note_0_0', 'note_4_0'}));

      // 3. Persistent Deselection: clearing selection clears across all views
      dawState.clearNoteSelection(track);
      expect(track.selectedNoteIds, isEmpty);
      expect(track.hasSelectedNotes, isFalse);

      // 4. Block Selection (e.g. step 0 to step 2, columns 0 to 1)
      final blockNotes = track.notes.where((n) {
        final s = n.startStep.toInt();
        return s >= 0 && s <= 2 && n.column >= 0 && n.column <= 1;
      }).map((n) => n.id).toList();

      dawState.selectNotes(track, blockNotes);
      expect(track.selectedNoteIds, equals({'note_0_0', 'note_2_0', 'note_2_1'}));
      expect(track.isNoteSelected('note_4_0'), isFalse);
    });
  });

  group('EditView Sidebar Reactivity Widget Tests', () {
    testWidgets('EditView reactively renders NoteInspectorSidebar when notes are selected and hides on deselection', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      dawState.clearNoteSelection(track);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: EditView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no notes selected -> NoteInspectorSidebar should not be in tree
      expect(find.byType(NoteInspectorSidebar), findsNothing);

      // Select notes -> EditView should immediately rebuild and render NoteInspectorSidebar
      dawState.selectNotes(track, [track.notes.first.id]);
      await tester.pumpAndSettle();
      expect(find.byType(NoteInspectorSidebar), findsOneWidget);

      // Deselect notes -> NoteInspectorSidebar should disappear
      dawState.clearNoteSelection(track);
      await tester.pumpAndSettle();
      expect(find.byType(NoteInspectorSidebar), findsNothing);
    });

    testWidgets('PianoRollView tap on blank space deselects notes immediately with no delay', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      dawState.setTrackActiveView(track, MusicViewType.pianoRoll);
      dawState.selectNotes(track, [track.notes.first.id]);
      expect(track.hasSelectedNotes, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: EditView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NoteInspectorSidebar), findsOneWidget);

      // Tap on empty space on the grid canvas
      final gridFinder = find.byType(CustomPaint).first;
      await tester.tap(gridFinder);
      await tester.pump();

      // Selection must be cleared immediately without waiting for timeouts
      expect(track.hasSelectedNotes, isFalse);
      expect(track.selectedNoteIds, isEmpty);
    });
  });
}

