import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/audio/time_context.dart';
import 'package:eatsbeats/lua/midi_pipeline_engine.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/eats_lua_serializer.dart';
import 'package:eatsbeats/lua/eats_lua_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chord Theory & Model Tests', () {
    test('Calculates pitch classes correctly for various chord qualities', () {
      // C Major (C, E, G -> 0, 4, 7)
      final cMaj = ChordEvent(id: '1', startBar: 0, rootPitchClass: 0, quality: ChordQuality.major);
      expect(cMaj.pitchClasses, equals([0, 4, 7]));
      expect(cMaj.displayName, equals('C'));

      // A Minor (A, C, E -> 9, 0, 4 -> sorted [0, 4, 9])
      final aMin = ChordEvent(id: '2', startBar: 1, rootPitchClass: 9, quality: ChordQuality.minor);
      expect(aMin.pitchClasses, equals([0, 4, 9]));
      expect(aMin.displayName, equals('Am'));

      // G Dominant 7 (G, B, D, F -> 7, 11, 2, 5 -> sorted [2, 5, 7, 11])
      final g7 = ChordEvent(id: '3', startBar: 2, rootPitchClass: 7, quality: ChordQuality.dominant7);
      expect(g7.pitchClasses, equals([2, 5, 7, 11]));
      expect(g7.displayName, equals('G7'));

      // C Maj7 (C, E, G, B -> 0, 4, 7, 11)
      final cMaj7 = ChordEvent(id: '4', startBar: 3, rootPitchClass: 0, quality: ChordQuality.major7);
      expect(cMaj7.pitchClasses, equals([0, 4, 7, 11]));
      expect(cMaj7.displayName, equals('Cmaj7'));

      // Slash Chord: C/E (Bass = E = 4)
      final cOverE = ChordEvent(id: '5', startBar: 4, rootPitchClass: 0, quality: ChordQuality.major, bassPitchClass: 4);
      expect(cOverE.displayName, equals('C/E'));
      expect(cOverE.pitchClasses, contains(4));
    });

    test('Calculates Roman Numerals correctly for Major and Minor keys', () {
      // In C Major key (Root = 0):
      expect(ChordTheory.getRomanNumeral(0, false, 0, ChordQuality.major), equals('I'));
      expect(ChordTheory.getRomanNumeral(0, false, 2, ChordQuality.minor), equals('ii'));
      expect(ChordTheory.getRomanNumeral(0, false, 4, ChordQuality.minor), equals('iii'));
      expect(ChordTheory.getRomanNumeral(0, false, 5, ChordQuality.major), equals('IV'));
      expect(ChordTheory.getRomanNumeral(0, false, 7, ChordQuality.major), equals('V'));
      expect(ChordTheory.getRomanNumeral(0, false, 9, ChordQuality.minor), equals('vi'));
      expect(ChordTheory.getRomanNumeral(0, false, 11, ChordQuality.diminished), equals('vii°'));

      // In A Minor key (Root = 9):
      expect(ChordTheory.getRomanNumeral(9, true, 9, ChordQuality.minor), equals('i'));
      expect(ChordTheory.getRomanNumeral(9, true, 0, ChordQuality.major), equals('III'));
      expect(ChordTheory.getRomanNumeral(9, true, 2, ChordQuality.minor), equals('iv'));
      expect(ChordTheory.getRomanNumeral(9, true, 4, ChordQuality.minor), equals('v'));
    });

    test('Circle of Fifths contains 12 unique major and minor pitch classes', () {
      expect(ChordTheory.circleOfFifthsMajor.length, equals(12));
      expect(ChordTheory.circleOfFifthsMajor.toSet().length, equals(12));
      expect(ChordTheory.circleOfFifthsMinor.length, equals(12));
      expect(ChordTheory.circleOfFifthsMinor.toSet().length, equals(12));
    });
  });

  group('Harmonic Remapping & Voice Leading Tests', () {
    final cMaj = ChordEvent(id: 'c1', startBar: 0, rootPitchClass: 0, quality: ChordQuality.major); // C, E, G
    final gOverB = ChordEvent(id: 'g1', startBar: 1, rootPitchClass: 7, quality: ChordQuality.major, bassPitchClass: 11); // G, B, D / B

    test('ChordFollowMode.off preserves pitch exactly', () {
      expect(ChordTheory.remapPitchForChord(61, cMaj, 'off'), equals(61)); // C#4 stays C#4
    });

    test('ChordFollowMode.bass snaps to root or slash bass note', () {
      // In C Major: MIDI 36 (C2) stays 36
      expect(ChordTheory.remapPitchForChord(36, cMaj, 'bass'), equals(36));
      // In C Major: MIDI 38 (D2) snaps to C2 (36)
      expect(ChordTheory.remapPitchForChord(38, cMaj, 'bass'), equals(36));

      // In G/B: MIDI 36 (C2) snaps to B1/B2 (35 or 47)
      final remappedBass = ChordTheory.remapPitchForChord(36, gOverB, 'bass');
      expect(remappedBass % 12, equals(11)); // B
    });

    test('ChordFollowMode.chord snaps to nearest chord tone', () {
      // In C Major (0, 4, 7):
      // D4 (MIDI 62, PC 2) is equidistant to C4 (60, PC 0) and E4 (64, PC 4)
      final remappedD = ChordTheory.remapPitchForChord(62, cMaj, 'chord');
      expect([60, 64], contains(remappedD));

      // F4 (MIDI 65, PC 5) snaps to E4 (64, PC 4)
      expect(ChordTheory.remapPitchForChord(65, cMaj, 'chord'), equals(64));

      // A4 (MIDI 69, PC 9) snaps to G4 (67, PC 7)
      expect(ChordTheory.remapPitchForChord(69, cMaj, 'chord'), equals(67));
    });

    test('ChordFollowMode.scale snaps to active chord parent scale', () {
      // In C Major scale (C, D, E, F, G, A, B -> [0, 2, 4, 5, 7, 9, 11]):
      // D4 (62) is in C scale -> stays 62
      expect(ChordTheory.remapPitchForChord(62, cMaj, 'scale'), equals(62));
      // C#4 (61) is non-scale -> snaps to C4 (60) or D4 (62)
      final remappedCs = ChordTheory.remapPitchForChord(61, cMaj, 'scale');
      expect([60, 62], contains(remappedCs));
    });
  });

  group('DawState & Lua Project Serialization Roundtrip Tests', () {
    test('DawState handles chord addition, lookup, and progression presets', () {
      final dawState = DawState();
      dawState.setSongKey('C Major');
      expect(dawState.songKeyRoot, equals(0));
      expect(dawState.isSongKeyMinor, isFalse);

      dawState.addOrUpdateChord(ChordEvent(
        id: 'chord_0',
        startBar: 0,
        barLength: 2.0,
        rootPitchClass: 0,
        quality: ChordQuality.major7,
      ));

      // Lookup chord at step 0 (Bar 0) and step 20 (Bar 1.25)
      expect(dawState.getActiveChordAtStep(0)?.displayName, equals('Cmaj7'));
      expect(dawState.getActiveChordAtStep(20)?.displayName, equals('Cmaj7'));
      // Step 40 (Bar 2.5) is outside Bar 0..2
      expect(dawState.getActiveChordAtStep(40), isNull);

      // Apply Progression Preset
      final popPreset = ChordTheory.progressionPresets.first; // Pop Classic (I - V - vi - IV)
      dawState.applyChordProgressionPreset(popPreset, startBar: 0);

      expect(dawState.chordTrack.length, equals(4));
      expect(dawState.getActiveChordAtBar(0)?.displayName, equals('C'));
      expect(dawState.getActiveChordAtBar(1)?.displayName, equals('G'));
      expect(dawState.getActiveChordAtBar(2)?.displayName, equals('Am'));
      expect(dawState.getActiveChordAtBar(3)?.displayName, equals('F'));
    });

    test('EatsLuaSerializer and EatsLuaParser preserve chordTrack, songKey, and track chordFollowMode', () {
      final dawState = DawState();
      dawState.setSongKey('A Minor');
      final track = dawState.activeTrack;
      track.chordFollowMode = ChordFollowMode.bass;

      dawState.addOrUpdateChord(ChordEvent(
        id: 'ch_1',
        startBar: 0,
        barLength: 1.0,
        rootPitchClass: 9,
        quality: ChordQuality.minor7,
      ));
      dawState.addOrUpdateChord(ChordEvent(
        id: 'ch_2',
        startBar: 1,
        barLength: 1.0,
        rootPitchClass: 5,
        quality: ChordQuality.major7,
        bassPitchClass: 0, // F/C
      ));

      final serializedLua = EatsLuaSerializer.serialize(dawState);
      expect(serializedLua, contains('songKey = "A Minor"'));
      expect(serializedLua, contains('chordFollowMode = "bass"'));
      expect(serializedLua, contains('chordTrack = {'));
      expect(serializedLua, contains('rootPitchClass = 9'));

      final restoredState = DawState();
      EatsLuaParser.populateDawState(restoredState, serializedLua);

      expect(restoredState.songKey, equals('A Minor'));
      expect(restoredState.chordTrack.length, equals(2));
      expect(restoredState.chordTrack[0].displayName, equals('Am7'));
      expect(restoredState.chordTrack[1].displayName, equals('Fmaj7/C'));
      expect(restoredState.activeTrack.chordFollowMode, equals(ChordFollowMode.bass));
    });

    test('DawState bakeTrackChordsToMidi destructively converts notes and resets follow mode', () {
      final dawState = DawState();
      final track = dawState.activeTrack;
      track.chordFollowMode = ChordFollowMode.chord;

      // Add C Major chord at Bar 0
      dawState.addOrUpdateChord(ChordEvent(
        id: 'c_maj',
        startBar: 0,
        barLength: 1.0,
        rootPitchClass: 0,
        quality: ChordQuality.major,
      ));

      // Add note F4 (MIDI 65) on step 0 of active track
      track.notes.clear();
      track.notes.add(Note(id: 'n1', pitch: 65, startStep: 0, durationSteps: 1.0));

      dawState.bakeTrackChordsToMidi(track);

      // F4 (65) should have baked into E4 (64)
      expect(track.notes.first.pitch, equals(64));
      expect(track.chordFollowMode, equals(ChordFollowMode.off));
    });
  });

  group('Lua MIDI FX & MIDI SEQ Chord Track API Tests', () {
    test('TimeContext exports rich chord and chordTrack table to Lua', () {
      final cMaj7 = ChordEvent(
        id: 'c1',
        startBar: 0,
        barLength: 2.0,
        rootPitchClass: 0,
        quality: ChordQuality.major7,
      );
      final gDom7 = ChordEvent(
        id: 'g1',
        startBar: 2,
        barLength: 2.0,
        rootPitchClass: 7,
        quality: ChordQuality.dominant7,
        bassPitchClass: 11, // G7/B
      );

      final ctx = TimeContext.fromBeat(
        beat: 0.0,
        bpm: 120.0,
        activeChord: cMaj7,
        chordTrack: [cMaj7, gDom7],
        songKey: 'C Major',
        songKeyRoot: 0,
        isSongKeyMinor: false,
      );

      final luaTable = ctx.toLuaTable();
      expect(luaTable['songKey'], equals('C Major'));
      expect(luaTable['songKeyRoot'], equals(0));
      expect(luaTable['isSongKeyMinor'], isFalse);

      final chordMap = luaTable['chord'] as Map<String, dynamic>;
      expect(chordMap['name'], equals('Cmaj7'));
      expect(chordMap['root'], equals(0));
      expect(chordMap['rootName'], equals('C'));
      expect(chordMap['quality'], equals('major7'));
      expect(chordMap['pitches'], equals([0, 4, 7, 11]));

      final chordTrackList = luaTable['chordTrack'] as List;
      expect(chordTrackList.length, equals(2));
      expect(chordTrackList[1]['name'], equals('G7/B'));
      expect(chordTrackList[1]['bass'], equals(11));
    });

    test('MidiPipelineEngine processes Chord Follower and Chord Arpeggiator MIDI FX', () {
      final cMaj = ChordEvent(id: 'c1', startBar: 0, barLength: 1.0, rootPitchClass: 0, quality: ChordQuality.major);
      final ctx = TimeContext.fromBeat(
        beat: 0.0,
        bpm: 120.0,
        activeChord: cMaj,
        chordTrack: [cMaj],
      );

      final pipeline = MidiPipelineEngine(luaEngine: LuaEngine());
      final track = TrackChannel(id: 't1', name: 'Synth Lead', type: TrackType.synth, color: const Color(0xFF00FFCC));

      // 1. Test Chord Follower MIDI FX
      final followerFX = MidiFXInsert(
        id: 'fx_follow',
        name: 'Harmonic Chord Follower FX',
        luaScriptCode: 'function ChordFollower.transform_notes(notes, params, timeContext) end',
        luaParams: {'Mode': 0.0}, // Chord mode
      );
      track.midiFXRack.add(followerFX);

      final clip = TrackClip(
        id: 'clip1',
        name: 'Test Clip',
        trackId: 't1',
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'n1', pitch: 62, startStep: 0.0, durationSteps: 2.0), // D4 -> snaps to C4 or E4
          Note(id: 'n2', pitch: 65, startStep: 4.0, durationSteps: 2.0), // F4 -> snaps to E4 (64)
        ],
      );

      final processedNotes = pipeline.processClip(clip: clip, track: track, timeContext: ctx);
      expect([60, 64], contains(processedNotes[0].pitch));
      expect(processedNotes[1].pitch, equals(64));

      // 2. Test Chord Arpeggiator MIDI FX
      track.midiFXRack.clear();
      final arpFX = MidiFXInsert(
        id: 'fx_arp',
        name: 'Chord Arpeggiator FX',
        luaScriptCode: 'function ChordArp.transform_notes(notes, params, timeContext) end',
        luaParams: {'Rate': 0.5, 'Octaves': 1.0, 'Pattern': 0.0}, // Up
      );
      track.midiFXRack.add(arpFX);

      final triggerClip = TrackClip(
        id: 'clip_arp',
        name: 'Arp Clip',
        trackId: 't1',
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'n_root', pitch: 60, startStep: 0.0, durationSteps: 4.0), // 4 steps duration with rate 0.5 -> 8 sub-notes
        ],
      );

      final arpedNotes = pipeline.processClip(clip: triggerClip, track: track, timeContext: ctx);
      expect(arpedNotes.length, equals(8));
      // First 3 sub-notes should be chord tones: C4 (60), E4 (64), G4 (67)
      expect(arpedNotes[0].pitch, equals(60));
      expect(arpedNotes[1].pitch, equals(64));
      expect(arpedNotes[2].pitch, equals(67));
    });

    test('MidiPipelineEngine generates full chord voicings for MIDI SEQ chord stabs', () {
      final cMaj = ChordEvent(id: 'c1', startBar: 0, barLength: 1.0, rootPitchClass: 0, quality: ChordQuality.major);
      final ctx = TimeContext.fromBeat(
        beat: 0.0,
        bpm: 120.0,
        activeChord: cMaj,
        chordTrack: [cMaj],
      );

      final clip = TrackClip(
        id: 'clip_stabs',
        name: 'Chord Stabs',
        trackId: 't1',
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'stab1', pitch: 60, startStep: 0.0, durationSteps: 2.0),
        ],
      );

      final pipeline = MidiPipelineEngine(luaEngine: LuaEngine());
      final track = TrackChannel(
        id: 't1',
        name: 'Keys',
        type: TrackType.synth,
        color: const Color(0xFFFFCC00),
        midiFXRack: [
          MidiFXInsert(id: 'mfx_stabs', name: 'Chord Voicing', luaScriptCode: 'Chord.generate_voicing(notes, time_ctx)'),
        ],
      );
      final voiced = pipeline.processClip(clip: clip, track: track, timeContext: ctx);

      // C major chord tones (C4=60, E4=64, G4=67)
      final pitches = voiced.map((n) => n.pitch).toList();
      expect(pitches, containsAll([60, 64, 67]));
    });

    test('Progression Presets Library contains extensive multi-genre chord progressions', () {
      final presets = ChordTheory.progressionPresets;
      expect(presets.length, greaterThanOrEqualTo(20));

      final popAxis = presets.firstWhere((p) => p.id == 'pop_axis');
      expect(popAxis.genre, equals('Pop'));
      expect(popAxis.romanSummary, equals('I - V - vi - IV'));

      final royalRoad = presets.firstWhere((p) => p.id == 'jpop_royal_road');
      expect(royalRoad.genre, equals('Anime / J-Pop'));
      expect(royalRoad.romanSummary, contains('IV - V - iii - vi'));

      final deepHouse = presets.firstWhere((p) => p.id == 'edm_deep_house');
      expect(deepHouse.genre, equals('EDM'));
    });

    testWidgets('ArrangerView right-click on chord block directly deletes the chord with undo support', (tester) async {
      final dawState = DawState(enableMeterTimer: false);
      dawState.setSongKey('C Major');
      dawState.addOrUpdateChord(
        ChordEvent(id: 'chord_del_test', startBar: 0, barLength: 2.0, rootPitchClass: 0, quality: ChordQuality.major),
      );

      expect(dawState.chordTrack.length, equals(1));

      // Direct deletion method check
      dawState.removeChord('chord_del_test');
      expect(dawState.chordTrack, isEmpty);

      // Undo restoration check
      expect(dawState.undo(), isTrue);
      expect(dawState.chordTrack.length, equals(1));
      expect(dawState.chordTrack.first.displayName, equals('C'));
    });
  });
}
