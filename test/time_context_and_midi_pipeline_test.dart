import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/audio/time_context.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/midi_pipeline_engine.dart';
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

    test('Lua table serialization converts time context correctly', () {
      final ctx = TimeContext.fromBeat(
        beat: 8.0,
        bpm: 120.0,
      );

      final table = ctx.toLuaTable();
      expect(table['bpm'], equals(120.0));
      expect(table['bar'], equals(3.0));
      expect(table['seconds'], equals(4.0));
      expect(table['frameIndex'], equals(240));
    });
  });

  group('MidiPipelineEngine Unit Tests', () {
    late LuaEngine luaEngine;
    late MidiPipelineEngine midiPipeline;

    setUp(() {
      luaEngine = LuaEngine();
      midiPipeline = MidiPipelineEngine(luaEngine: luaEngine);
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
            luaScriptCode: 'scale_snap',
            luaParams: {'key': 0},
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

    test('Evaluates Arpeggiator clip transform', () {
      final clip = TrackClip(
        id: 'clip_arp',
        name: 'Arp Clip',
        trackId: 'track_1',
        luaScriptCode: 'arpeggiate',
        luaParams: {'rate': 0.25},
        notes: [
          Note(id: 'n_root', pitch: 60, startStep: 0.0, durationSteps: 1.0),
        ],
      );

      final track = TrackChannel(
        id: 'track_1',
        name: 'Arp Synth',
        color: Colors.purple,
        type: TrackType.synth,
      );

      final ctx = TimeContext.fromBeat(beat: 0.0, bpm: 120.0);
      final arpedNotes = midiPipeline.processClip(
        clip: clip,
        track: track,
        timeContext: ctx,
      );

      expect(arpedNotes.length, equals(4));
      expect(arpedNotes[0].pitch, equals(60));
      expect(arpedNotes[1].pitch, equals(64));
      expect(arpedNotes[2].pitch, equals(68));
      expect(arpedNotes[3].pitch, equals(60));
      expect(arpedNotes[0].id, contains('n_root_arp_0'));
    });

    test('Serializes Notes into Lua table code and parses back', () {
      final baseNotes = [
        Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 1.0, velocity: 0.9),
        Note(id: 'n2', pitch: 64, startStep: 1.0, durationSteps: 2.0, velocity: 0.8),
      ];

      final luaCode = MidiPipelineEngine.serializeNotesToLua(baseNotes);
      expect(luaCode, contains('notes = {'));
      expect(luaCode, contains('pitch = 60'));
      expect(luaCode, contains('pitch = 64'));
      expect(luaCode, contains('function process(notes, time_ctx)'));

      final parsed = MidiPipelineEngine.parseNotesFromLuaTable(luaCode);
      expect(parsed.length, equals(2));
      expect(parsed[0].pitch, equals(60));
      expect(parsed[1].pitch, equals(64));
      expect(parsed[1].durationSteps, equals(2.0));
    });

    test('Repeated note serialization does not duplicate notes block', () {
      final baseNotes = [
        Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 1.0),
      ];

      final pass1 = MidiPipelineEngine.serializeNotesToLua(baseNotes);
      final pass2 = MidiPipelineEngine.serializeNotesToLua(baseNotes, existingCode: pass1);
      final pass3 = MidiPipelineEngine.serializeNotesToLua(baseNotes, existingCode: pass2);

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
