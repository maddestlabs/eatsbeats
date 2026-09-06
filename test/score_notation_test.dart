import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/ui/score/score_layout_engine.dart';
import 'package:eatsbeats/ui/score/score_vector_glyphs.dart';

void main() {
  group('ScoreLayoutEngine Tests', () {
    test('Pitch to layout correctly maps Middle C (C4, MIDI 60)', () {
      final layout = ScoreLayoutEngine.pitchToLayout(60);
      expect(layout.midiPitch, 60);
      expect(layout.noteName, 'C4');
      expect(layout.accidental, ScoreAccidental.none);
      // C4 is diatonic step (4 * 7) + 0 = 28
      expect(layout.diatonicStep, 28);
    });

    test('Pitch to layout correctly maps sharps and accidentals', () {
      final fSharp4 = ScoreLayoutEngine.pitchToLayout(66); // F#4
      expect(fSharp4.noteName, 'F#4');
      expect(fSharp4.accidental, ScoreAccidental.sharp);

      final bFlat4 = ScoreLayoutEngine.pitchToLayout(70, useFlats: true); // Bb4
      expect(bFlat4.noteName, 'Bb4');
      expect(bFlat4.accidental, ScoreAccidental.flat);
    });

    test('Computes correct ledger lines for Middle C on Treble Staff', () {
      final layout = ScoreLayoutEngine.pitchToLayout(60); // C4
      const double staffLine1Y = 160.0;
      const double sp = 12.0;

      final visual = ScoreLayoutEngine.computeVisual(
        pitchLayout: layout,
        durationSteps: 4.0,
        staffLine1Y: staffLine1Y,
        sp: sp,
        isTrebleStaff: true,
      );

      // Treble Line 1 is E4 (diatonic step 30).
      // C4 is step 28, which is 2 half-spaces (1 full staff space) below Line 1.
      expect(visual.yPos, staffLine1Y + sp);
      // Middle C on Treble has 1 ledger line below (at staffLine1Y + sp)
      expect(visual.ledgerLineYPositions.length, 1);
      expect(visual.ledgerLineYPositions.first, staffLine1Y + sp);
      // Stems below middle line (B4) point up
      expect(visual.isStemUp, true);
      // 4.0 steps is a quarter note
      expect(visual.noteType, ScoreNoteType.quarter);
    });

    test('Computes stem direction rule correctly', () {
      const double staffLine1Y = 160.0;
      const double sp = 12.0;

      // B4 (MIDI 71) is Treble Line 3 -> stems point down
      final b4 = ScoreLayoutEngine.pitchToLayout(71);
      final visualB4 = ScoreLayoutEngine.computeVisual(
        pitchLayout: b4,
        durationSteps: 4.0,
        staffLine1Y: staffLine1Y,
        sp: sp,
        isTrebleStaff: true,
      );
      expect(visualB4.isStemUp, false);

      // A4 (MIDI 69) is Treble Space 2 (below line 3) -> stems point up
      final a4 = ScoreLayoutEngine.pitchToLayout(69);
      final visualA4 = ScoreLayoutEngine.computeVisual(
        pitchLayout: a4,
        durationSteps: 4.0,
        staffLine1Y: staffLine1Y,
        sp: sp,
        isTrebleStaff: true,
      );
      expect(visualA4.isStemUp, true);
    });

    test('Duration mapping matches standard note subdivisions', () {
      expect(ScoreLayoutEngine.durationToNoteType(16.0).$1, ScoreNoteType.whole);
      expect(ScoreLayoutEngine.durationToNoteType(8.0).$1, ScoreNoteType.half);
      expect(ScoreLayoutEngine.durationToNoteType(4.0).$1, ScoreNoteType.quarter);
      expect(ScoreLayoutEngine.durationToNoteType(2.0).$1, ScoreNoteType.eighth);
      expect(ScoreLayoutEngine.durationToNoteType(1.0).$1, ScoreNoteType.sixteenth);
    });

    test('Inverts Y screen coordinate back to exact MIDI pitch', () {
      const double staffLine1Y = 160.0;
      const double sp = 12.0;

      // E4 is on Line 1 (Y = 160.0)
      final pitchE4 = ScoreLayoutEngine.yToMidiPitch(
        y: staffLine1Y,
        staffLine1Y: staffLine1Y,
        sp: sp,
        isTrebleStaff: true,
      );
      expect(pitchE4, 64); // E4 is MIDI 64

      // G4 is on Line 2 (Y = 160.0 - 12.0 = 148.0)
      final pitchG4 = ScoreLayoutEngine.yToMidiPitch(
        y: staffLine1Y - sp,
        staffLine1Y: staffLine1Y,
        sp: sp,
        isTrebleStaff: true,
      );
      expect(pitchG4, 67); // G4 is MIDI 67
    });

    test('Bravura SMuFL glyph vector paths generate valid non-empty bounds', () {
      const double sp = 13.0;

      final treblePath = ScoreVectorGlyphs.createTrebleClefPath(0, 0, sp);
      final trebleBounds = treblePath.getBounds();
      expect(trebleBounds.isEmpty, false);
      expect(trebleBounds.width, greaterThan(20.0));
      expect(trebleBounds.height, greaterThan(50.0));

      final bassPath = ScoreVectorGlyphs.createBassClefPath(0, 0, sp);
      final bassBounds = bassPath.getBounds();
      expect(bassBounds.isEmpty, false);
      expect(bassBounds.width, greaterThan(20.0));
      expect(bassBounds.height, greaterThan(30.0));

      final bracePath = ScoreVectorGlyphs.createGrandStaffBracePath(0, 50.0, 200.0, sp);
      final braceBounds = bracePath.getBounds();
      expect(braceBounds.isEmpty, false);
      expect(braceBounds.height, closeTo(150.0, 1.0));

      final sharpPath = ScoreVectorGlyphs.createSharpPath(0, 0, sp);
      expect(sharpPath.getBounds().isEmpty, false);

      final flatPath = ScoreVectorGlyphs.createFlatPath(0, 0, sp);
      expect(flatPath.getBounds().isEmpty, false);

      final naturalPath = ScoreVectorGlyphs.createNaturalPath(0, 0, sp);
      expect(naturalPath.getBounds().isEmpty, false);

      final qRestPath = ScoreVectorGlyphs.createQuarterRestPath(0, 0, sp);
      expect(qRestPath.getBounds().isEmpty, false);
    });
  });
}
