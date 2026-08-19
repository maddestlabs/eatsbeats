import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/lua/midi_pipeline_engine.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/audio/time_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LuaEngine luaEngine;
  late MidiPipelineEngine pipeline;

  setUp(() {
    luaEngine = LuaEngine();
    pipeline = MidiPipelineEngine(luaEngine: luaEngine);
  });

  group('MidiPipelineEngine Arpeggiator Patterns & Octaves', () {
    test('Generates Up and Down patterns accurately across 2 octaves', () {
      final chord = [
        Note(id: 'c', pitch: 60, startStep: 0.0, durationSteps: 4.0),
        Note(id: 'e', pitch: 64, startStep: 0.0, durationSteps: 4.0),
        Note(id: 'g', pitch: 67, startStep: 0.0, durationSteps: 4.0),
      ];

      // Up Pattern: C4(60), E4(64), G4(67), C5(72), E5(76), G5(79)
      final upArp = MidiPipelineEngine.applyArpeggiator(
        chord,
        stepRate: 1.0,
        octaves: 2,
        pattern: 'up',
      );
      expect(upArp.length, equals(4));
      expect(upArp[0].pitch, equals(60));
      expect(upArp[1].pitch, equals(64));
      expect(upArp[2].pitch, equals(67));
      expect(upArp[3].pitch, equals(72));

      // Down Pattern: G5(79), E5(76), C5(72), G4(67)...
      final downArp = MidiPipelineEngine.applyArpeggiator(
        chord,
        stepRate: 1.0,
        octaves: 2,
        pattern: 'down',
      );
      expect(downArp.length, equals(4));
      expect(downArp[0].pitch, equals(79));
      expect(downArp[1].pitch, equals(76));
      expect(downArp[2].pitch, equals(72));
      expect(downArp[3].pitch, equals(67));
    });

    test('Generates Converge (Outside-In) pattern', () {
      final chord = [
        Note(id: 'c', pitch: 60, startStep: 0.0, durationSteps: 4.0),
        Note(id: 'e', pitch: 64, startStep: 0.0, durationSteps: 4.0),
        Note(id: 'g', pitch: 67, startStep: 0.0, durationSteps: 4.0),
        Note(id: 'b', pitch: 71, startStep: 0.0, durationSteps: 4.0),
      ];

      final convergeArp = MidiPipelineEngine.applyArpeggiator(
        chord,
        stepRate: 1.0,
        octaves: 1,
        pattern: 'converge',
      );

      // Lowest (60), Highest (71), 2nd Lowest (64), 2nd Highest (67)
      expect(convergeArp[0].pitch, equals(60));
      expect(convergeArp[1].pitch, equals(71));
      expect(convergeArp[2].pitch, equals(64));
      expect(convergeArp[3].pitch, equals(67));
    });

    test('Generates Chord Strum mode (all notes triggered together per step)', () {
      final chord = [
        Note(id: 'c', pitch: 60, startStep: 0.0, durationSteps: 2.0),
        Note(id: 'g', pitch: 67, startStep: 0.0, durationSteps: 2.0),
      ];

      final strumArp = MidiPipelineEngine.applyArpeggiator(
        chord,
        stepRate: 1.0,
        octaves: 1,
        pattern: 'chord',
      );

      expect(strumArp.length, equals(4)); // 2 steps * 2 notes
      expect(strumArp[0].startStep, equals(0.0));
      expect(strumArp[1].startStep, equals(0.0));
      expect(strumArp[2].startStep, equals(1.0));
      expect(strumArp[3].startStep, equals(1.0));
    });

    test('Calculates Swing micro-offsets on odd sub-steps', () {
      final single = [
        Note(id: 'c', pitch: 60, startStep: 0.0, durationSteps: 2.0),
      ];

      final swingArp = MidiPipelineEngine.applyArpeggiator(
        single,
        stepRate: 0.5,
        octaves: 1,
        pattern: 'up',
        swing: 0.5,
      );

      expect(swingArp.length, equals(4));
      expect(swingArp[0].startStep, equals(0.0)); // even step -> 0 offset
      expect(swingArp[1].startStep, greaterThan(0.5)); // odd step -> delayed by swing
      expect(swingArp[2].startStep, equals(1.0)); // even step -> 0 offset
      expect(swingArp[3].startStep, greaterThan(1.5)); // odd step -> delayed by swing
    });
  });

  group('DawState MIDI FX Rack and Baking Integration', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    test('applyPresetToClip applies MIDI FX to clip without overwriting synth instrument', () {
      final track = dawState.activeTrack;
      track.type = TrackType.synth;
      track.name = 'Lead Synth';
      final clip = track.clips.first;

      final arpPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'arpeggiator_midi_fx');
      dawState.applyPresetToClip(track, clip, arpPreset);

      expect(track.type, equals(TrackType.synth)); // Preserves synth
      expect(clip.luaScriptCode, equals(arpPreset.code));
    });

    test('bakeMidiFXToClip permanently burns evaluated notes into clip and clears cache', () {
      final track = dawState.activeTrack;
      final clip = TrackClip(
        id: 'c_test',
        name: 'Test Clip',
        trackId: track.id,
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'root', pitch: 60, startStep: 0.0, durationSteps: 4.0),
        ],
      );
      track.clips.add(clip);
      dawState.selectClip(clip);

      dawState.addMidiFXInsert(
        track,
        name: 'Arp',
        luaScriptCode: 'arpeggiator',
        params: {'Rate': 1.0, 'Octaves': 2.0, 'Pattern': 0.0},
      );

      final ghostNotes = dawState.getEvaluatedClipNotes(clip, track);
      expect(ghostNotes.length, equals(4)); // 4 arpeggio steps

      // Bake to clip
      dawState.bakeMidiFXToClip(track, clip, disableTrackMidiFx: true);

      expect(clip.notes.length, equals(4));
      expect(clip.notes[0].pitch, equals(60));
      expect(clip.notes[1].pitch, equals(72));
      expect(clip.notes[2].pitch, equals(60));
      expect(clip.notes[3].pitch, equals(72));
      expect(track.midiFXRack.first.enabled, isFalse);
    });

    test('Clips are created clean without inheriting synth instrument code and notes remain untouched without MIDI FX', () {
      final track = dawState.activeTrack;
      track.type = TrackType.synth;
      track.luaScriptCode = '-- Acid Synth DSP code\nfunction Synth.render() end';
      track.notes.clear();
      track.notes.add(Note(id: 'lead_1', pitch: 60, startStep: 0.0, durationSteps: 2.0));

      final clip = dawState.activeTrackClip;
      expect(clip.luaScriptCode, isEmpty); // Does NOT inherit synth DSP

      final evaluated = dawState.getEvaluatedClipNotes(clip, track);
      expect(evaluated.length, equals(1));
      expect(evaluated.first.pitch, equals(60)); // Exact original pitch, no unexpected arp
    });

    test('deleteClip, duplicateClip, and renameClip work seamlessly with undo/redo', () {
      final track = dawState.activeTrack;
      track.clips.clear();

      dawState.addClipToTrack(track, 0);
      final clipA = track.clips.first;
      expect(track.clips.length, equals(1));
      expect(clipA.startBar, equals(0));

      // Rename
      dawState.renameClip(clipA, 'Verse Lead');
      expect(clipA.name, equals('Verse Lead'));

      // Duplicate
      dawState.duplicateClip(track, clipA);
      expect(track.clips.length, equals(2));
      final clipB = track.clips[1];
      expect(clipB.name, equals('Verse Lead (Copy)'));
      expect(clipB.startBar, equals(2)); // Placed right after bar 0 + length 2

      // Delete
      dawState.deleteClip(track, clipA);
      expect(track.clips.length, equals(1));
      expect(track.clips.first.id, equals(clipB.id));
    });

    test('toggleTrackMidiFXRack master enables and bypasses all inserts', () {
      final track = dawState.activeTrack;
      dawState.addMidiFXInsert(track, name: 'Arp', luaScriptCode: 'arpeggiator');
      dawState.addMidiFXInsert(track, name: 'Scale Snap', luaScriptCode: 'scale_snap');

      expect(track.midiFXRack.every((f) => f.enabled), isTrue);

      // Master Bypass
      dawState.toggleTrackMidiFXRack(track, false);
      expect(track.midiFXRack.every((f) => !f.enabled), isTrue);

      // Master Enable
      dawState.toggleTrackMidiFXRack(track, true);
      expect(track.midiFXRack.every((f) => f.enabled), isTrue);
    });
  });
}
