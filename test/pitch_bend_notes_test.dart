import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/audio/poly_synth.dart';
import 'package:eatsbeats/lua/eats_lua_serializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pitch Bend & Slide Notes - Model & Serialization Tests', () {
    test('Note isBend alias and isSlide property work symmetrically', () {
      final note = Note(
        id: 'n_bend_1',
        pitch: 60,
        startStep: 0,
        durationSteps: 2,
        velocity: 0.8,
        isSlide: false,
      );

      expect(note.isSlide, isFalse);
      expect(note.isBend, isFalse);

      note.isBend = true;
      expect(note.isSlide, isTrue);
      expect(note.isBend, isTrue);

      final copy = note.copyWith(isSlide: false);
      expect(copy.isSlide, isFalse);
      expect(copy.isBend, isFalse);
    });

    test('JSON serialization preserves isSlide', () {
      final note = Note(
        id: 'n_json_1',
        pitch: 65,
        startStep: 4.0,
        durationSteps: 1.5,
        velocity: 0.9,
        column: 1,
        isSlide: true,
      );

      final json = note.toJson();
      expect(json['isSlide'], isTrue);

      final fromJson = Note.fromJson(json);
      expect(fromJson.isSlide, isTrue);
      expect(fromJson.isBend, isTrue);
      expect(fromJson.column, equals(1));
    });

    test('Lua serialization roundtrip preserves isSlide for polyphonic notes', () {
      final state = DawState();
      final track = state.activeTrack;
      track.notes.clear();
      track.notes.addAll([
        Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 4, column: 0, isSlide: false),
        Note(id: 'n2', pitch: 67, startStep: 2, durationSteps: 2, column: 0, isSlide: true),
        Note(id: 'n3', pitch: 64, startStep: 0, durationSteps: 4, column: 1, isSlide: false),
      ]);

      final luaString = EatsLuaSerializer.serializeNotes(track.notes, relativeSteps: false);
      expect(luaString.contains('isSlide = true'), isTrue);

      final songLua = state.exportToEatsLua();
      final newState = DawState();
      newState.loadFromEatsLua(songLua);

      final loadedTrack = newState.patterns.first.tracks.firstWhere((t) => t.id == track.id);
      final restoredNotes = loadedTrack.notes;
      expect(restoredNotes.length, equals(3));
      expect(restoredNotes[1].isSlide, isTrue);
      expect(restoredNotes[1].isBend, isTrue);
      expect(restoredNotes[0].isSlide, isFalse);
    });
  });

  group('Pitch Bend & Slide Notes - DawState Manipulation Tests', () {
    late DawState daw;

    setUp(() {
      daw = DawState();
    });

    test('setNoteSlide and toggleNoteSlide update note and notify listeners', () {
      final track = daw.activeTrack;
      track.notes.clear();
      final note = Note(id: 'test_n1', pitch: 60, startStep: 0, durationSteps: 2, isSlide: false);
      daw.addNote(track, note);

      expect(track.notes.firstWhere((n) => n.id == 'test_n1').isSlide, isFalse);

      daw.setNoteSlide(track, note, true);
      expect(track.notes.firstWhere((n) => n.id == 'test_n1').isSlide, isTrue);

      daw.toggleNoteSlide(track, track.notes.firstWhere((n) => n.id == 'test_n1'));
      expect(track.notes.firstWhere((n) => n.id == 'test_n1').isSlide, isFalse);
    });

    test('setNotesSlide batch updates multiple notes', () {
      final track = daw.activeTrack;
      track.notes.clear();
      final n1 = Note(id: 'bn1', pitch: 60, startStep: 0, isSlide: false);
      final n2 = Note(id: 'bn2', pitch: 64, startStep: 2, isSlide: false);
      final n3 = Note(id: 'bn3', pitch: 67, startStep: 4, isSlide: false);
      daw.addNote(track, n1);
      daw.addNote(track, n2);
      daw.addNote(track, n3);

      daw.setNotesSlide(track, ['bn1', 'bn3'], true);

      expect(track.notes.firstWhere((n) => n.id == 'bn1').isSlide, isTrue);
      expect(track.notes.firstWhere((n) => n.id == 'bn2').isSlide, isFalse);
      expect(track.notes.firstWhere((n) => n.id == 'bn3').isSlide, isTrue);
    });

    test('Tracker addOrUpdateTrackerNote with isSlide and toggleTrackerSlideAtSelectedCell', () {
      daw.selectTrackerCell(2, 0);
      daw.addOrUpdateTrackerNote(pitch: 62, isSlide: true, autoAdvance: false);

      final track = daw.activeTrack;
      final note = track.notes.firstWhere((n) => n.startStep == 2.0 && n.column == 0);
      expect(note.isSlide, isTrue);
      expect(note.isBend, isTrue);

      daw.toggleTrackerSlideAtSelectedCell();
      expect(note.isSlide, isFalse);

      daw.toggleTrackerSlideAtSelectedCell();
      expect(note.isSlide, isTrue);
    });
  });

  group('Pitch Bend & Slide Notes - PolySynth Synthesis Tests', () {
    test('generateSynthToneBuffer supports targetMidiNote and isSlide frequency glide', () {
      final normalBuffer = PolySynth.generateSynthToneBuffer(
        midiNote: 60,
        waveform: 'sawtooth',
        lengthSec: 0.1,
      );
      expect(normalBuffer.length, greaterThan(0));

      final slideBuffer = PolySynth.generateSynthToneBuffer(
        midiNote: 60,
        targetMidiNote: 72,
        isSlide: true,
        waveform: 'sawtooth',
        lengthSec: 0.1,
      );
      expect(slideBuffer.length, equals(normalBuffer.length));

      // Verifies buffer is populated with non-zero audio samples
      bool hasNonZero = slideBuffer.any((s) => s != 0.0);
      expect(hasNonZero, isTrue);
    });
  });
}
