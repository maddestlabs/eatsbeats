import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/lua/eats_lua_serializer.dart';
import 'package:eatsbeats/lua/eats_lua_parser.dart';

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

    test('EatsLuaSerializer and EatsLuaParser handle note clipboard Lua format', () {
      final notes = [
        Note(id: 'n1', pitch: 60, startStep: 4.0, durationSteps: 1.0, velocity: 0.8, column: 0),
        Note(id: 'n2', pitch: 64, startStep: 5.0, durationSteps: 2.0, velocity: 0.9, column: 1, isAccent: true),
      ];

      final luaStr = EatsLuaSerializer.serializeNotes(notes, relativeSteps: true);
      expect(luaStr, contains('pitch = 60'));
      expect(luaStr, contains('pitch = 64'));
      expect(luaStr, contains('startStep = 0.00')); // Relative step normalized
      expect(luaStr, contains('startStep = 1.00'));

      final parsed = EatsLuaParser.parseNotes(luaStr);
      expect(parsed.length, 2);
      expect(parsed[0].pitch, 60);
      expect(parsed[0].startStep, 0.0);
      expect(parsed[0].durationSteps, 1.0);
      expect(parsed[1].pitch, 64);
      expect(parsed[1].startStep, 1.0);
      expect(parsed[1].durationSteps, 2.0);
      expect(parsed[1].isAccent, isTrue);
    });

    test('copyNotesToClipboard and pasteNotesFromClipboard paste notes with correct step offset', () async {
      final n1 = Note(id: 'note_1', pitch: 60, startStep: 0, durationSteps: 1, velocity: 0.8);
      final n2 = Note(id: 'note_2', pitch: 67, startStep: 2, durationSteps: 1, velocity: 0.85);
      dawState.addNote(track, n1);
      dawState.addNote(track, n2);

      // Copy selected note_1 & note_2
      final lua = await dawState.copyNotesToClipboard(track, ['note_1', 'note_2']);
      expect(lua, isNotEmpty);
      expect(dawState.noteClipboard.length, 2);

      // Paste at targetStep = 8.0
      final pasted = await dawState.pasteNotesFromClipboard(track, targetStep: 8.0);
      expect(pasted.length, 2);
      expect(pasted[0].startStep, 8.0);
      expect(pasted[0].pitch, 60);
      expect(pasted[1].startStep, 10.0); // 8.0 + (2.0 - 0.0)
      expect(pasted[1].pitch, 67);

      expect(track.notes.length, 4);

      // Undo paste
      expect(dawState.history.canUndo, isTrue);
      dawState.history.undo(dawState);
      expect(dawState.activeTrack.notes.length, 2);
    });

    test('cutNotesToClipboard copies and removes notes in single transaction', () async {
      final n1 = Note(id: 'note_1', pitch: 60, startStep: 0, durationSteps: 1, velocity: 0.8);
      final n2 = Note(id: 'note_2', pitch: 62, startStep: 1, durationSteps: 1, velocity: 0.8);
      dawState.addNote(track, n1);
      dawState.addNote(track, n2);

      await dawState.cutNotesToClipboard(track, ['note_1']);
      expect(track.notes.length, 1);
      expect(track.notes.first.id, 'note_2');
      expect(dawState.noteClipboard.length, 1);
      expect(dawState.noteClipboard.first.pitch, 60);

      // Paste cut note at step 4.0
      final pasted = await dawState.pasteNotesFromClipboard(track, targetStep: 4.0);
      expect(pasted.length, 1);
      expect(pasted.first.startStep, 4.0);
      expect(pasted.first.pitch, 60);
      expect(track.notes.length, 2);
    });

    test('copyTrackerBlockToClipboard and paste to tracker column', () async {
      dawState.selectTrackerCell(0, 0);
      dawState.addOrUpdateTrackerNote(pitch: 60, velocity: 0.8, autoAdvance: false);
      dawState.selectTrackerCell(1, 0);
      dawState.addOrUpdateTrackerNote(pitch: 64, velocity: 0.8, autoAdvance: false);

      final lua = await dawState.copyTrackerBlockToClipboard(startStep: 0, endStep: 1, startCol: 0, endCol: 0);
      expect(lua, contains('pitch = 60'));
      expect(lua, contains('pitch = 64'));

      // Paste at Step 4, Column 1
      final pasted = await dawState.pasteNotesFromClipboard(track, targetStep: 4.0, targetCol: 1);
      expect(pasted.length, 2);
      expect(pasted[0].startStep, 4.0);
      expect(pasted[0].column, 1);
      expect(pasted[1].startStep, 5.0);
      expect(pasted[1].column, 1);
    });
  });
}
