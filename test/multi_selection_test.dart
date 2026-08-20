import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Piano Roll & Tracker Multi-Selection Tests', () {
    late DawState dawState;
    late TrackChannel track;

    setUp(() {
      dawState = DawState();
      track = dawState.activeTrack;
      dawState.removeNotes(track, track.notes.map((n) => n.id).toList());
      dawState.history.clear(dawState);
    });

    test('Batch removeNotes removes multiple notes and records undo history', () {
      final n1 = Note(id: 'note_1', pitch: 60, startStep: 0, durationSteps: 1, velocity: 0.8);
      final n2 = Note(id: 'note_2', pitch: 62, startStep: 1, durationSteps: 1, velocity: 0.8);
      final n3 = Note(id: 'note_3', pitch: 64, startStep: 2, durationSteps: 1, velocity: 0.8);

      dawState.addNote(track, n1);
      dawState.addNote(track, n2);
      dawState.addNote(track, n3);

      expect(track.notes.length, 3);

      dawState.removeNotes(track, ['note_1', 'note_3']);

      expect(track.notes.length, 1);
      expect(track.notes.first.id, 'note_2');

      // Undo
      expect(dawState.history.canUndo, isTrue);
      dawState.history.undo(dawState);
      expect(dawState.activeTrack.notes.length, 3);
    });

    test('Batch transposeNotes shifts pitches clamped between 0 and 127', () {
      final n1 = Note(id: 'note_1', pitch: 60, startStep: 0, durationSteps: 1, velocity: 0.8);
      final n2 = Note(id: 'note_2', pitch: 80, startStep: 1, durationSteps: 1, velocity: 0.8);

      dawState.addNote(track, n1);
      dawState.addNote(track, n2);

      dawState.transposeNotes(track, ['note_1', 'note_2'], 7);

      expect(track.notes.firstWhere((n) => n.id == 'note_1').pitch, 67);
      expect(track.notes.firstWhere((n) => n.id == 'note_2').pitch, 87);
    });

    test('Batch setNotesVelocity updates velocity across notes', () {
      final n1 = Note(id: 'note_1', pitch: 60, startStep: 0, durationSteps: 1, velocity: 0.5);
      final n2 = Note(id: 'note_2', pitch: 64, startStep: 1, durationSteps: 1, velocity: 0.7);

      dawState.addNote(track, n1);
      dawState.addNote(track, n2);

      dawState.setNotesVelocity(track, ['note_1', 'note_2'], 0.95);

      expect(track.notes.firstWhere((n) => n.id == 'note_1').velocity, 0.95);
      expect(track.notes.firstWhere((n) => n.id == 'note_2').velocity, 0.95);
    });

    test('Tracker block delete and transpose operations work correctly', () {
      // Add tracker notes on steps 0, 1, 2 in column 0 and column 1
      dawState.addOrUpdateTrackerNote(pitch: 60, velocity: 0.8, autoAdvance: false); // step 0, col 0

      dawState.selectTrackerCell(1, 0);
      dawState.addOrUpdateTrackerNote(pitch: 62, velocity: 0.8, autoAdvance: false); // step 1, col 0

      dawState.selectTrackerCell(0, 1);
      dawState.addOrUpdateTrackerNote(pitch: 64, velocity: 0.8, autoAdvance: false); // step 0, col 1

      dawState.selectTrackerCell(1, 1);
      dawState.addOrUpdateTrackerNote(pitch: 67, velocity: 0.8, autoAdvance: false); // step 1, col 1

      expect(track.notes.length, 4);

      // Transpose block (step 0..1, col 0..1) by +2 semitones
      dawState.transposeTrackerNotesInBlock(
        startStep: 0,
        endStep: 1,
        startCol: 0,
        endCol: 1,
        semitones: 2,
      );

      final n00 = track.notes.firstWhere((n) => n.startStep == 0.0 && n.column == 0);
      final n01 = track.notes.firstWhere((n) => n.startStep == 0.0 && n.column == 1);
      expect(n00.pitch, 62);
      expect(n01.pitch, 66);

      // Delete block (step 0..0, col 0..1)
      dawState.deleteTrackerNotesInBlock(
        startStep: 0,
        endStep: 0,
        startCol: 0,
        endCol: 1,
      );

      expect(track.notes.length, 2);
      expect(track.notes.every((n) => n.startStep == 1.0), isTrue);
    });
  });
}
