import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/procgen/procedural_song_engine.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProceduralSongEngine & Authentic Genre Generator Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    test('Lo-Fi Hip Hop generates Felt Piano, Upright Bass, Swung GM Drums, and Vibraphone', () {
      final result = ProceduralSongEngine.generateToDawState(dawState, {
        'Style': 'Lo-Fi Hip Hop',
        'Bars': 16,
        'Seed': 42,
        'Structure': 'Full Arrangement (Intro-Verse-Chorus-Outro)',
      });

      expect(result.isSuccess, isTrue);
      expect(dawState.bpm, equals(84.0));
      expect(dawState.loopStartBar, equals(0));
      expect(dawState.loopEndBar, equals(16));
      expect(dawState.isLooping, isTrue);
      expect(dawState.isSongMode, isTrue);

      final tracks = dawState.activePattern.tracks;
      expect(tracks.length, equals(4));

      // 1. Drum Track (GM Standard Drum Kit)
      final drumTrack = tracks.firstWhere((t) => t.id == 'proc_track_drums');
      expect(drumTrack.type, equals(TrackType.eatScript));
      expect(drumTrack.luaScriptCode, contains('GM Standard Drum Kit'));
      expect(drumTrack.name, contains('GM Standard Kit'));
      expect(drumTrack.clips.length, greaterThanOrEqualTo(3)); // Intro, Verse, Chorus, Outro
      expect(drumTrack.clips.every((c) => c.notes.isNotEmpty), isTrue);

      // 2. Bass Track (Acoustic Upright Bass)
      final bassTrack = tracks.firstWhere((t) => t.id == 'proc_track_bass');
      expect(bassTrack.type, equals(TrackType.eatScript));
      expect(bassTrack.name, equals('Acoustic Upright Bass'));
      expect(bassTrack.luaScriptCode, contains('Upright Double Bass'));

      // 3. Chord Track (Felt Upright Piano with jazz extensions)
      final chordTrack = tracks.firstWhere((t) => t.id == 'proc_track_chords');
      expect(chordTrack.type, equals(TrackType.eatScript));
      expect(chordTrack.name, equals('Felt Upright Piano'));
      expect(chordTrack.luaScriptCode, contains('felt_upright_piano'));

      // Verify extended chords exist in chord track
      expect(dawState.chordTrack, isNotEmpty);
      expect(
        dawState.chordTrack.any((c) =>
            c.quality == ChordQuality.min9 ||
            c.quality == ChordQuality.maj9 ||
            c.quality == ChordQuality.major7 ||
            c.quality == ChordQuality.dominant7),
        isTrue,
      );

      // 4. Lead Track (Lyrical Vibraphone)
      final leadTrack = tracks.firstWhere((t) => t.id == 'proc_track_lead');
      expect(leadTrack.type, equals(TrackType.eatScript));
      expect(leadTrack.name, equals('Lyrical Vibraphone'));
      expect(leadTrack.luaScriptCode, contains('Vibraphone'));
    });

    test('Synthwave / Retrowave generates Model D Sub Bass, Poly Lead, and Neon Arps', () {
      final result = ProceduralSongEngine.generateToDawState(dawState, {
        'Style': 'Synthwave / Retrowave',
        'Bars': 16,
        'Seed': 100,
        'Structure': 'Full Arrangement (Intro-Verse-Chorus-Outro)',
      });

      expect(result.isSuccess, isTrue);
      expect(dawState.bpm, equals(124.0));
      expect(dawState.loopStartBar, equals(0));
      expect(dawState.loopEndBar, equals(16));

      final tracks = dawState.activePattern.tracks;
      final bassTrack = tracks.firstWhere((t) => t.id == 'proc_track_bass');
      expect(bassTrack.name, equals('Model D Sub Bass'));
      expect(bassTrack.luaScriptCode, contains('Model D'));

      final leadTrack = tracks.firstWhere((t) => t.id == 'proc_track_lead');
      expect(leadTrack.name, equals('Outrun Arp Lead'));
      expect(leadTrack.luaScriptCode, contains('Poly Lead'));
      // Verify fast 16th arp notes were generated
      final leadNotes = leadTrack.clips.expand((c) => c.notes).toList();
      expect(leadNotes.length, greaterThan(100));
    });

    test('Cyberpunk Acid generates TB-303 with slides and accents', () {
      final result = ProceduralSongEngine.generateToDawState(dawState, {
        'Style': 'Cyberpunk Acid',
        'Bars': 8,
        'Seed': 77,
      });

      expect(result.isSuccess, isTrue);
      expect(dawState.bpm, equals(135.0));

      final bassTrack = dawState.activePattern.tracks.firstWhere((t) => t.id == 'proc_track_bass');
      expect(bassTrack.name, equals('Eats-303 Acid Bass'));
      expect(bassTrack.luaScriptCode.contains('Eats303') || bassTrack.luaScriptCode.contains('TB-303'), isTrue);

      // Check that 303 pattern contains slides and accents
      final bassNotes = bassTrack.clips.expand((c) => c.notes).toList();
      expect(bassNotes.any((n) => n.isSlide), isTrue);
      expect(bassNotes.any((n) => n.isAccent), isTrue);
    });

    test('Neo-Soul / R&B generates Fender Rhodes and Fretless J-Bass', () {
      final result = ProceduralSongEngine.generateToDawState(dawState, {
        'Style': 'Neo-Soul / R&B',
        'Bars': 8,
        'Seed': 55,
      });

      expect(result.isSuccess, isTrue);
      expect(dawState.bpm, equals(90.0));

      final bassTrack = dawState.activePattern.tracks.firstWhere((t) => t.id == 'proc_track_bass');
      expect(bassTrack.name, equals('Fretless J-Bass'));

      final chordTrack = dawState.activePattern.tracks.firstWhere((t) => t.id == 'proc_track_chords');
      expect(chordTrack.name, equals('Fender Rhodes Mark I'));

      final leadTrack = dawState.activePattern.tracks.firstWhere((t) => t.id == 'proc_track_lead');
      expect(leadTrack.name, equals('Lyrical Concert Flute'));
    });

    test('Deterministic Seed produces identical notes, chords, and tracks', () {
      // Run 1 with Seed 4242
      final daw1 = DawState(enableMeterTimer: false);
      ProceduralSongEngine.generateToDawState(daw1, {
        'Style': 'Lo-Fi Hip Hop',
        'Bars': 16,
        'Seed': 4242,
      });

      // Run 2 with same Seed 4242
      final daw2 = DawState(enableMeterTimer: false);
      ProceduralSongEngine.generateToDawState(daw2, {
        'Style': 'Lo-Fi Hip Hop',
        'Bars': 16,
        'Seed': 4242,
      });

      // Compare chord track
      expect(daw1.chordTrack.length, equals(daw2.chordTrack.length));
      for (int i = 0; i < daw1.chordTrack.length; i++) {
        expect(daw1.chordTrack[i].rootPitchClass, equals(daw2.chordTrack[i].rootPitchClass));
        expect(daw1.chordTrack[i].quality, equals(daw2.chordTrack[i].quality));
      }

      // Compare notes across all tracks
      for (int t = 0; t < daw1.activePattern.tracks.length; t++) {
        final t1 = daw1.activePattern.tracks[t];
        final t2 = daw2.activePattern.tracks[t];
        expect(t1.name, equals(t2.name));

        final notes1 = t1.clips.expand((c) => c.notes).toList();
        final notes2 = t2.clips.expand((c) => c.notes).toList();
        expect(notes1.length, equals(notes2.length));
        for (int ni = 0; ni < notes1.length; ni++) {
          expect(notes1[ni].pitch, equals(notes2[ni].pitch));
          expect(notes1[ni].startStep, closeTo(notes2[ni].startStep, 0.001));
          expect(notes1[ni].velocity, closeTo(notes2[ni].velocity, 0.001));
        }
      }

      // Different seed produces different notes
      final daw3 = DawState(enableMeterTimer: false);
      ProceduralSongEngine.generateToDawState(daw3, {
        'Style': 'Lo-Fi Hip Hop',
        'Bars': 16,
        'Seed': 9999,
      });
      final notesLead1 = daw1.activePattern.tracks[3].clips.expand((c) => c.notes).toList();
      final notesLead3 = daw3.activePattern.tracks[3].clips.expand((c) => c.notes).toList();
      expect(notesLead1.map((n) => n.pitch).toList(), isNot(equals(notesLead3.map((n) => n.pitch).toList())));
    });

    test('generateProceduralDemo on DawState creates song with history tracking', () {
      expect(dawState.activePattern.tracks.length, greaterThanOrEqualTo(1));

      final result = dawState.generateProceduralDemo(
        style: 'Lo-Fi Hip Hop',
        seed: 88,
        bars: 16,
      );

      expect(result.isSuccess, isTrue);
      expect(dawState.activePattern.tracks.length, equals(4));
      expect(dawState.loopStartBar, equals(0));
      expect(dawState.loopEndBar, equals(16));
      expect(dawState.isLooping, isTrue);

      // Verify undo works
      expect(dawState.undo(), isTrue);
    });
  });
}
