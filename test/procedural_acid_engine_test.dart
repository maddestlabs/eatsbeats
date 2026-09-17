import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/procgen/procedural_acid_engine.dart';
import 'package:eatsbeats/eatscript/eats_script_library.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProceduralAcidEngine Unit & Pattern Generation Tests', () {
    test('generatePattern produces notes for all 6 acid styles', () {
      for (final style in ProceduralAcidEngine.styles) {
        final notes = ProceduralAcidEngine.generatePattern(
          style: style,
          scaleName: 'Minor Pentatonic',
          rootPitchClass: 0, // C
          bars: 2,
          density: 0.75,
          seed: 42,
        );

        expect(notes, isNotEmpty, reason: 'Failed to generate notes for style: $style');
        for (final note in notes) {
          expect(note.startStep, greaterThanOrEqualTo(0.0));
          expect(note.startStep, lessThan(32.0)); // 2 bars * 16 steps
          expect(note.durationSteps, greaterThan(0.0));
          expect(note.pitch, inInclusiveRange(24, 96));
        }
      }
    });

    test('generatePattern respects scale constraints (Minor Pentatonic on C)', () {
      // C Minor Pentatonic: C, Eb, F, G, Bb (pitch classes: 0, 3, 5, 7, 10)
      const allowedPitchClasses = {0, 3, 5, 7, 10};

      final notes = ProceduralAcidEngine.generatePattern(
        style: 'Classic Chicago Acid (1987)',
        scaleName: 'Minor Pentatonic',
        rootPitchClass: 0,
        bars: 4,
        density: 0.85,
        seed: 777,
      );

      expect(notes, isNotEmpty);
      for (final note in notes) {
        final pc = note.pitch % 12;
        expect(allowedPitchClasses.contains(pc), isTrue,
            reason: 'Pitch ${note.pitch} (pitch class $pc) is not in C Minor Pentatonic');
      }
    });

    test('generatePattern assigns authentic TB-303 slide and accent flags', () {
      final notes = ProceduralAcidEngine.generatePattern(
        style: '90s Acid Trance / Goa',
        scaleName: 'Phrygian (Dark)',
        bars: 2,
        density: 0.80,
        slideProb: 0.50,
        accentProb: 0.40,
        seed: 12345,
      );

      final slideNotes = notes.where((n) => n.isSlide).toList();
      final accentNotes = notes.where((n) => n.isAccent).toList();

      expect(slideNotes, isNotEmpty, reason: 'Expected slide notes in Goa Acid style');
      expect(accentNotes, isNotEmpty, reason: 'Expected accent notes in Goa Acid style');

      // Accented notes should have high velocity (>= 0.80)
      for (final accNote in accentNotes) {
        expect(accNote.velocity, greaterThanOrEqualTo(0.80));
      }
    });

    test('Deterministic output: same seed produces identical notes, different seeds vary', () {
      final run1 = ProceduralAcidEngine.generatePattern(
        style: 'Hard Acid Techno (Warehouse)',
        scaleName: 'Acid Blues (Flatted 5th)',
        bars: 2,
        seed: 999,
      );

      final run2 = ProceduralAcidEngine.generatePattern(
        style: 'Hard Acid Techno (Warehouse)',
        scaleName: 'Acid Blues (Flatted 5th)',
        bars: 2,
        seed: 999,
      );

      final runDifferent = ProceduralAcidEngine.generatePattern(
        style: 'Hard Acid Techno (Warehouse)',
        scaleName: 'Acid Blues (Flatted 5th)',
        bars: 2,
        seed: 1000,
      );

      expect(run1.length, equals(run2.length));
      for (int i = 0; i < run1.length; i++) {
        expect(run1[i].pitch, equals(run2[i].pitch));
        expect(run1[i].startStep, equals(run2[i].startStep));
        expect(run1[i].isSlide, equals(run2[i].isSlide));
        expect(run1[i].isAccent, equals(run2[i].isAccent));
      }

      // Check difference with different seed
      bool hasDifference = (run1.length != runDifferent.length);
      if (!hasDifference) {
        for (int i = 0; i < run1.length; i++) {
          if (run1[i].pitch != runDifferent[i].pitch ||
              run1[i].isSlide != runDifferent[i].isSlide ||
              run1[i].startStep != runDifferent[i].startStep) {
            hasDifference = true;
            break;
          }
        }
      }
      expect(hasDifference, isTrue);
    });

    test('generateCompanion909Notes creates authentic 4-on-the-floor beat', () {
      final drumNotes = ProceduralAcidEngine.generateCompanion909Notes(2);
      expect(drumNotes, isNotEmpty);

      // 2 bars = 8 quarter notes -> 8 kicks
      final kicks = drumNotes.where((n) => n.pitch == 36).toList();
      expect(kicks.length, equals(8));

      // 2 bars = 4 beats on 2 & 4 -> 4 claps
      final claps = drumNotes.where((n) => n.pitch == 39).toList();
      expect(claps.length, equals(4));

      // Offbeat open hats: 4 per bar * 2 = 8
      final openHats = drumNotes.where((n) => n.pitch == 46).toList();
      expect(openHats.length, equals(8));
    });

    test('generatePattern produces tied sustained notes when tieProb > 0', () {
      final tiedNotes = ProceduralAcidEngine.generatePattern(
        style: 'Minimalist Hypnotic Acid',
        scaleName: 'Minor Pentatonic',
        bars: 4,
        density: 0.85,
        tieProb: 0.50,
        seed: 30342,
      );

      final sustained = tiedNotes.where((n) => n.durationSteps >= 1.5).toList();
      expect(sustained, isNotEmpty, reason: 'Expected sustained/tied notes spanning >= 1.5 steps with high tieProb');
      for (final n in sustained) {
        expect(n.durationSteps, greaterThanOrEqualTo(1.5));
      }
    });

    test('generatePattern with tieProb = 0 produces single-step 16th notes', () {
      final staccatoNotes = ProceduralAcidEngine.generatePattern(
        style: 'Hard Acid Techno (Warehouse)',
        scaleName: 'Natural Minor',
        bars: 2,
        density: 0.80,
        tieProb: 0.0,
        seed: 1234,
      );

      for (final n in staccatoNotes) {
        expect(n.durationSteps, lessThanOrEqualTo(1.05),
            reason: 'Note at step ${n.startStep} should not exceed single-step length when tieProb = 0');
      }
    });

    test('slide notes bridge seamlessly into destination pitch', () {
      final notes = ProceduralAcidEngine.generatePattern(
        style: 'Classic Chicago Acid (1987)',
        scaleName: 'Minor Pentatonic',
        bars: 4,
        density: 0.85,
        slideProb: 0.60,
        tieProb: 0.30,
        seed: 7777,
      );

      final slideNotes = notes.where((n) => n.isSlide).toList();
      expect(slideNotes, isNotEmpty);

      // Verify that for slide notes with a predecessor, the predecessor bridges into the slide step
      for (final slideNote in slideNotes) {
        final predecessors = notes.where((n) => n.startStep < slideNote.startStep).toList();
        if (predecessors.isNotEmpty) {
          final prior = predecessors.last;
          if (slideNote.startStep - prior.startStep <= 2.0) {
            // Either prior note reaches the slide note or is adjacent
            expect(prior.startStep + prior.durationSteps, greaterThanOrEqualTo(slideNote.startStep - 0.5));
          }
        }
      }
    });
  });

  group('ProceduralAcidEngine DAW State & Macro Integration Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
      for (final p in dawState.patterns) {
        p.tracks.clear();
      }
    });

    test('Macro preset action_procedural_acid_303 is registered in EatScriptLibrary', () {
      final macro = EatScriptLibrary.getPresetById('action_procedural_acid_303');
      expect(macro, isNotNull);
      expect(macro!.isMacro, isTrue);
      expect(macro.name, contains('Procedural Acid 303'));
    });

    test('generateToDawState automatically creates Eats-303 track and stamps clip', () {
      final result = ProceduralAcidEngine.generateToDawState(dawState, {
        'Style': 0, // Classic Chicago Acid
        'Scale': 0, // Minor Pentatonic
        'Root': 0, // Auto
        'Bars': 2,
        'Density': 0.75,
        'SlideProbability': 0.40,
        'AccentProbability': 0.35,
        'Waveform': 0, // Saw
        'Companion909': 0, // No drums
        'Seed': 303,
      });

      expect(result.isSuccess, isTrue);
      expect(result.affectedTracksCount, equals(1));
      expect(result.affectedNotesCount, greaterThan(0));

      final tracks = dawState.activePattern.tracks;
      expect(tracks, isNotEmpty);
      final acidTrack = tracks.first;
      expect(acidTrack.name, contains('Acid 303'));
      expect(acidTrack.eatScriptCode, contains('eats_303'));
      expect(acidTrack.clips, isNotEmpty);

      final clip = acidTrack.clips.first;
      expect(clip.notes, isNotEmpty);
      expect(clip.barLength, equals(2));
    });

    test('generateToDawState with Companion909 adds both 303 and 909 tracks', () {
      final result = ProceduralAcidEngine.generateToDawState(dawState, {
        'Style': 1, // 90s Acid Trance / Goa
        'Scale': 1, // Phrygian
        'Root': 1, // C
        'Bars': 4,
        'Companion909': 1, // Enable 909 beat
        'Seed': 909303,
      });

      expect(result.isSuccess, isTrue);
      expect(result.affectedTracksCount, equals(2));

      final tracks = dawState.activePattern.tracks;
      expect(tracks.length, equals(2));
      expect(tracks.any((t) => t.name.contains('Acid 303')), isTrue);
      expect(tracks.any((t) => t.name.contains('909 Drums')), isTrue);
    });

    test('runProjectScript dispatches action_procedural_acid_303 cleanly', () {
      final macro = EatScriptLibrary.getPresetById('action_procedural_acid_303')!;

      final result = dawState.runProjectScript(macro, params: {
        'Style': 'Hard Acid Techno (Warehouse)',
        'Scale': 'Acid Blues (Flatted 5th)',
        'Bars': 2,
        'Companion909': 0,
        'Seed': 42,
      });

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('Hard Acid Techno (Warehouse)'));
      expect(dawState.activePattern.tracks, isNotEmpty);
    });
  });
}
