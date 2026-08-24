import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/ui/widgets/project_browser_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Context-Based Presets Engine Tests', () {
    late DawState state;

    setUp(() {
      state = DawState();
    });

    test('addNewPresetTrack only creates a track for instrument presets', () {
      final initialTrackCount = state.activePattern.tracks.length;

      // 1. Attempt creating track with Audio FX -> should be rejected
      final audioFxPreset = LuaPresetLibrary.presets.firstWhere((p) => p.isAudioFx);
      state.addNewPresetTrack(audioFxPreset);
      expect(state.activePattern.tracks.length, equals(initialTrackCount));

      // 2. Attempt creating track with MIDI FX -> should be rejected
      final midiFxPreset = LuaPresetLibrary.presets.firstWhere((p) => p.isMidiFx);
      state.addNewPresetTrack(midiFxPreset);
      expect(state.activePattern.tracks.length, equals(initialTrackCount));

      // 3. Attempt creating track with MIDI SEQ -> should be rejected
      final midiSeqPreset = LuaPresetLibrary.presets.firstWhere((p) => p.isMidiSeq);
      state.addNewPresetTrack(midiSeqPreset);
      expect(state.activePattern.tracks.length, equals(initialTrackCount));

      // 4. Create track with Instrument preset -> should succeed
      final instrumentPreset = LuaPresetLibrary.presets.firstWhere((p) => p.isInstrument);
      state.addNewPresetTrack(instrumentPreset);
      expect(state.activePattern.tracks.length, equals(initialTrackCount + 1));
      expect(state.activeTrack.name, equals(instrumentPreset.name));
    });

    test('applyPreset with Audio FX appends to the end of track FX rack', () {
      final track = state.activeTrack;
      track.fxRack.clear();

      final bitcrusherPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'bitcrusher');
      final waveshaperPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'waveshaper');

      // Add first FX
      state.applyPreset(bitcrusherPreset, targetTrack: track);
      expect(track.fxRack.length, equals(1));
      expect(track.fxRack.first.name, equals(bitcrusherPreset.name));

      // Add second FX -> should append to the end
      state.applyPreset(waveshaperPreset, targetTrack: track);
      expect(track.fxRack.length, equals(2));
      expect(track.fxRack.first.name, equals(bitcrusherPreset.name));
      expect(track.fxRack.last.name, equals(waveshaperPreset.name));
    });

    test('applyPresetToClip with MIDI SEQ sets clip notes and tiles them across clip length', () {
      final track = state.activeTrack;
      expect(track.clips, isNotEmpty);
      final clip = track.clips.first;
      clip.barLength = 2;

      final seq4ToFloor = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'seq_4_to_floor');
      state.applyPresetToClip(track, clip, seq4ToFloor);

      expect(clip.name, equals(seq4ToFloor.name));
      // 4 hits per bar * 2 bars = 8 notes
      expect(clip.notes.length, equals(8));
      expect(clip.notes.first.pitch, equals(36));
      expect(clip.notes.last.startStep, equals(28.0)); // bar 2 hit 4 (12 + 16 = 28)
    });

    test('default project and newly created tracks start with no MIDI FX on clips', () {
      expect(state.activeTrack.midiFXRack, isEmpty);
      expect(state.activeTrack.clips, isNotEmpty);
      for (final track in state.activePattern.tracks) {
        expect(track.midiFXRack.any((f) => f.enabled), isFalse);
        for (final clip in track.clips) {
          expect(clip.hasMidiScript, isFalse);
        }
      }

      // Also create a new instrument track
      final synthPreset = LuaPresetLibrary.presets.firstWhere((p) => p.isInstrument);
      state.addNewPresetTrack(synthPreset);
      final newTrack = state.activeTrack;
      expect(newTrack.midiFXRack, isEmpty);
      expect(newTrack.clips.first.hasMidiScript, isFalse);
    });

    test('applyPresetToClip with MIDI FX routes to track midiFXRack and evaluates notes', () {
      final track = state.activeTrack;
      final clip = track.clips.first;
      clip.barLength = 1;
      // Add a base C4 note
      clip.notes = [
        Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 4, velocity: 0.8),
      ];

      final arpFx = LuaPresetLibrary.presets.firstWhere((p) => p.isMidiFx);
      state.applyPresetToClip(track, clip, arpFx);

      expect(track.midiFXRack, isNotEmpty);
      expect(track.midiFXRack.first.name, equals(arpFx.name));
      expect(clip.luaScriptCode, isEmpty);
      expect(clip.evaluatedNotesCache, isNotNull);
      expect(clip.evaluatedNotesCache!, isNotEmpty);
    });
  });

  group('Drag & Drop Context Validation Tests', () {
    late DawState state;

    setUp(() {
      state = DawState();
    });

    test('Arranger and Inspector preset acceptance rules', () {
      final instrumentPreset = LuaPresetLibrary.presets.firstWhere((p) => p.isInstrument);
      final audioFxPreset = LuaPresetLibrary.presets.firstWhere((p) => p.isAudioFx);
      final midiFxPreset = LuaPresetLibrary.presets.firstWhere((p) => p.isMidiFx);
      final midiSeqPreset = LuaPresetLibrary.presets.firstWhere((p) => p.isMidiSeq);
      final soundFontItem = SoundFontDragItem(fontId: 'sf2.sf2', displayName: 'SF2');

      // 1. Track list empty area / "+ Add track" target:
      // Accepts: instrument, SoundFont. Rejects: audioFx, midiFx, midiSeq
      bool trackListAccepts(Object data) {
        if (data is SoundFontDragItem) return true;
        if (data is LuaPreset) return data.isInstrument;
        return false;
      }
      expect(trackListAccepts(instrumentPreset), isTrue);
      expect(trackListAccepts(soundFontItem), isTrue);
      expect(trackListAccepts(audioFxPreset), isFalse);
      expect(trackListAccepts(midiFxPreset), isFalse);
      expect(trackListAccepts(midiSeqPreset), isFalse);

      // 2. Track Header row target:
      // Accepts: instrument, audioFx, midiFx, SoundFont. Rejects: midiSeq
      bool trackHeaderAccepts(Object data) {
        if (data is SoundFontDragItem) return true;
        if (data is LuaPreset) return data.isInstrument || data.isAudioFx || data.isMidiFx;
        return false;
      }
      expect(trackHeaderAccepts(instrumentPreset), isTrue);
      expect(trackHeaderAccepts(audioFxPreset), isTrue);
      expect(trackHeaderAccepts(midiFxPreset), isTrue);
      expect(trackHeaderAccepts(soundFontItem), isTrue);
      expect(trackHeaderAccepts(midiSeqPreset), isFalse);

      // 3. Clip target:
      // Accepts: midiSeq, midiFx. Rejects: instrument, audioFx, SoundFont
      bool clipAccepts(Object data) {
        if (data is LuaPreset) {
          return data.isMidiSeq || data.isMidiFx;
        }
        return false;
      }
      expect(clipAccepts(midiSeqPreset), isTrue);
      expect(clipAccepts(midiFxPreset), isTrue);
      expect(clipAccepts(instrumentPreset), isFalse);
      expect(clipAccepts(audioFxPreset), isFalse);
      expect(clipAccepts(soundFontItem), isFalse);

      // 4. Modular FX Rack target:
      // Accepts: audioFx only
      bool modularFxAccepts(LuaPreset data) {
        return data.isAudioFx;
      }
      expect(modularFxAccepts(audioFxPreset), isTrue);
      expect(modularFxAccepts(instrumentPreset), isFalse);
      expect(modularFxAccepts(midiFxPreset), isFalse);
      expect(modularFxAccepts(midiSeqPreset), isFalse);

      // 5. Track Header row target for TrackChannel reordering:
      // Accepts TrackChannel if ID is different
      final track1 = state.activePattern.tracks[0];
      final track2 = state.activePattern.tracks[1];
      bool trackHeaderAcceptsTrackReorder(Object data, TrackChannel targetTrack) {
        if (data is TrackChannel) return data.id != targetTrack.id;
        return false;
      }
      expect(trackHeaderAcceptsTrackReorder(track1, track2), isTrue);
      expect(trackHeaderAcceptsTrackReorder(track1, track1), isFalse);
    });

    test('DawState.reorderTracks reorders tracks correctly', () {
      final tracks = state.activePattern.tracks;
      expect(tracks.length, greaterThanOrEqualTo(3));
      final track0Name = tracks[0].name;
      final track1Name = tracks[1].name;
      final track2Name = tracks[2].name;

      // Reorder track 0 to position 2
      state.reorderTracks(0, 2);
      expect(state.activePattern.tracks[0].name, equals(track1Name));
      expect(state.activePattern.tracks[1].name, equals(track2Name));
      expect(state.activePattern.tracks[2].name, equals(track0Name));
      expect(state.activeTrackIndex, equals(2));
    });
  });
}
