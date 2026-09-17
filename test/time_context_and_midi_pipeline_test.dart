import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/time_context.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/eatscript/eats_engine.dart';
import 'package:eatsbeats/eatscript/midi_pipeline_engine.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimeContext Unit Tests', () {
    test('Calculates beat, bar, seconds, and frameIndex accurately', () {
      final ctx = TimeContext.fromBeat(
        beat: 4.0, // Beat 4 = Bar 2, Beat 1 in 4/4
        bpm: 120.0,
      );

      expect(ctx.bpm, equals(120.0));
      expect(ctx.currentBar, equals(2.0));
      expect(ctx.audioTimeSeconds, equals(2.0)); // 4 beats * 0.5s = 2.0s
      expect(ctx.frameIndex, equals(120)); // 2.0s * 60fps = 120 frames
      expect(ctx.secondsPerBeat, equals(0.5));
      expect(ctx.secondsPerBar, equals(2.0));
    });

    test('Context map serialization converts time context correctly', () {
      final ctx = TimeContext.fromBeat(
        beat: 8.0,
        bpm: 120.0,
      );

      final table = ctx.toContextMap();
      expect(table['bpm'], equals(120.0));
      expect(table['bar'], equals(3.0));
      expect(table['seconds'], equals(4.0));
      expect(table['frameIndex'], equals(240));
    });
  });

  group('MidiPipelineEngine Unit Tests', () {
    late EatEngine eatEngine;
    late MidiPipelineEngine midiPipeline;

    setUp(() {
      eatEngine = EatEngine();
      midiPipeline = MidiPipelineEngine(eatEngine: eatEngine);
    });

    test('Evaluates clip notes through scale snap MIDI FX insert', () {
      final clip = TrackClip(
        id: 'clip_1',
        name: 'Test Clip',
        trackId: 'track_1',
        notes: [
          Note(id: 'n1', pitch: 61, startStep: 0.0), // C#4 -> should snap to C4 (60) in C Major
          Note(id: 'n2', pitch: 63, startStep: 1.0), // D#4 -> should snap to E4 (64) in C Major
        ],
      );

      final track = TrackChannel(
        id: 'track_1',
        name: 'Synth',
        color: Colors.blue,
        type: TrackType.synth,
        midiFXRack: [
          MidiFXInsert(
            id: 'fx_scale',
            name: 'Scale Snap',
            eatScriptCode: 'scale_snap',
            eatScriptParams: {'key': 0},
          ),
        ],
      );

      final ctx = TimeContext.fromBeat(beat: 0.0, bpm: 120.0);
      final processedNotes = midiPipeline.processClip(
        clip: clip,
        track: track,
        timeContext: ctx,
      );

      expect(processedNotes.length, equals(2));
      expect(processedNotes[0].pitch, equals(60)); // Snapped to C4
      expect(processedNotes[1].pitch, equals(62)); // Snapped to D4
      expect(processedNotes[0].id, equals('n1')); // Preserves voice ID
    });

    test('Evaluates Arpeggiator clip transform with multi-octave cycling and chord patterns', () {
      final clip = TrackClip(
        id: 'clip_arp',
        name: 'Arp Clip',
        trackId: 'track_1',
        notes: [
          Note(id: 'n_root', pitch: 60, startStep: 0.0, durationSteps: 1.0),
        ],
      );

      final track = TrackChannel(
        id: 'track_1',
        name: 'Arp Synth',
        color: Colors.purple,
        type: TrackType.synth,
        midiFXRack: [
          MidiFXInsert(
            id: 'arp_fx',
            name: 'Arp FX',
            eatScriptCode: 'arpeggiate',
            eatScriptParams: {'rate': 0.25, 'octaves': 2.0, 'pattern': 0.0},
          ),
        ],
      );

      final ctx = TimeContext.fromBeat(beat: 0.0, bpm: 120.0);
      final arpedNotes = midiPipeline.processClip(
        clip: clip,
        track: track,
        timeContext: ctx,
      );

      expect(arpedNotes.length, equals(4));
      expect(arpedNotes[0].pitch, equals(60));
      expect(arpedNotes[1].pitch, equals(72));
      expect(arpedNotes[2].pitch, equals(60));
      expect(arpedNotes[3].pitch, equals(72));
      expect(arpedNotes[0].id, contains('n_root_arp_0'));
    });

    test('Evaluates Chord Arpeggiator with UpDown pattern and Gate scaling', () {
      final chordClip = TrackClip(
        id: 'clip_chord_arp',
        name: 'Chord Arp Clip',
        trackId: 'track_1',
        notes: [
          Note(id: 'c1', pitch: 60, startStep: 0.0, durationSteps: 4.0), // C4
          Note(id: 'c2', pitch: 64, startStep: 0.0, durationSteps: 4.0), // E4
          Note(id: 'c3', pitch: 67, startStep: 0.0, durationSteps: 4.0), // G4
        ],
      );

      final track = TrackChannel(
        id: 'track_1',
        name: 'Arp Synth',
        color: Colors.purple,
        type: TrackType.synth,
        midiFXRack: [
          MidiFXInsert(
            id: 'arp_fx',
            name: 'Arpeggiator FX',
            eatScriptCode: 'arpeggiator',
            eatScriptParams: {'Rate': 1.0, 'Octaves': 1.0, 'Pattern': 2.0, 'Gate': 0.5}, // UpDown
          ),
        ],
      );

      final ctx = TimeContext.fromBeat(beat: 0.0, bpm: 120.0);
      final arpedNotes = midiPipeline.processClip(
        clip: chordClip,
        track: track,
        timeContext: ctx,
      );

      // C4 (60), E4 (64), G4 (67), E4 (64)
      expect(arpedNotes.length, equals(4));
      expect(arpedNotes[0].pitch, equals(60));
      expect(arpedNotes[1].pitch, equals(64));
      expect(arpedNotes[2].pitch, equals(67));
      expect(arpedNotes[3].pitch, equals(64));
      expect(arpedNotes[0].durationSteps, closeTo(0.5, 0.01)); // Gate = 0.5 * 1.0
    });

    test('Serializes Notes into Eatscript code and parses back', () {
      final baseNotes = [
        Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 1.0, velocity: 0.9),
        Note(id: 'n2', pitch: 64, startStep: 1.0, durationSteps: 2.0, velocity: 0.8),
      ];

      final eatScriptCode = MidiPipelineEngine.serializeNotesToScript(baseNotes);
      expect(eatScriptCode, contains('notes = {'));
      expect(eatScriptCode, contains('pitch = 60'));
      expect(eatScriptCode, contains('pitch = 64'));
      expect(eatScriptCode, contains('function process(notes, time_ctx)'));

      final parsed = MidiPipelineEngine.parseNotesFromScript(eatScriptCode);
      expect(parsed.length, equals(2));
      expect(parsed[0].pitch, equals(60));
      expect(parsed[1].pitch, equals(64));
      expect(parsed[1].durationSteps, equals(2.0));
    });

    test('Repeated note serialization does not duplicate notes block', () {
      final baseNotes = [
        Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 1.0),
      ];

      final pass1 = MidiPipelineEngine.serializeNotesToScript(baseNotes);
      final pass2 = MidiPipelineEngine.serializeNotesToScript(baseNotes, existingCode: pass1);
      final pass3 = MidiPipelineEngine.serializeNotesToScript(baseNotes, existingCode: pass2);

      // Verify "notes = {" appears exactly ONCE in the script string
      final occurrences = 'notes = {'.allMatches(pass3).length;
      expect(occurrences, equals(1));
    });
  });

  group('Tracker State & Editing Unit Tests', () {
    test('Tracker cell selection and note insertion with auto-advance', () {
      final dawState = DawState();
      dawState.selectTrackerCell(2, 0);

      expect(dawState.trackerSelectedStep, equals(2));
      expect(dawState.trackerSelectedColumn, equals(0));

      dawState.addOrUpdateTrackerNote(pitch: 60, velocity: 0.9, autoAdvance: true);

      final track = dawState.activeTrack;
      final addedNote = track.notes.firstWhere(
        (n) => n.startStep.toInt() == 2 && n.column == 0,
      );

      expect(addedNote.pitch, equals(60));
      expect(addedNote.velocity, equals(0.9));
      expect(dawState.trackerSelectedStep, equals(3)); // Auto-advanced to step 3

      // Delete note at cell
      dawState.selectTrackerCell(2, 0);
      dawState.deleteTrackerNoteAtSelectedCell();

      final remaining = track.notes.where(
        (n) => n.startStep.toInt() == 2 && n.column == 0,
      );
      expect(remaining.isEmpty, isTrue);
      dawState.dispose();
    });
  });
}
