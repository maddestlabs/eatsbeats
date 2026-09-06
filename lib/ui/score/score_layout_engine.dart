enum ScoreClef { treble, bass, grandStaff, auto }

enum ScoreAccidental { none, sharp, flat, natural }

enum ScoreNoteType { whole, half, quarter, eighth, sixteenth }

class ScorePitchLayout {
  final int midiPitch;
  final int diatonicStep;
  final ScoreAccidental accidental;
  final String noteName;
  final bool isTreble; // In Grand Staff, whether note belongs to Treble or Bass

  const ScorePitchLayout({
    required this.midiPitch,
    required this.diatonicStep,
    required this.accidental,
    required this.noteName,
    this.isTreble = true,
  });
}

class ScoreNoteVisual {
  final ScorePitchLayout pitchLayout;
  final ScoreNoteType noteType;
  final bool isDotted;
  final double yPos;
  final bool isStemUp;
  final List<double> ledgerLineYPositions;

  const ScoreNoteVisual({
    required this.pitchLayout,
    required this.noteType,
    required this.isDotted,
    required this.yPos,
    required this.isStemUp,
    required this.ledgerLineYPositions,
  });
}

/// Helper and layout math for mapping musical pitches and step durations to 2D score coordinates.
class ScoreLayoutEngine {
  // Diatonic steps from C0:
  // C=0, D=1, E=2, F=3, G=4, A=5, B=6
  // Treble Line 1 (E4) = (4 * 7) + 2 = 30
  // Treble Line 3 (B4) = (4 * 7) + 6 = 34
  // Treble Line 5 (F5) = (5 * 7) + 3 = 38
  // Bass Line 1 (G2) = (2 * 7) + 4 = 18
  // Bass Line 3 (D3) = (3 * 7) + 1 = 22
  // Bass Line 5 (A3) = (3 * 7) + 5 = 26
  // Middle C (C4, MIDI 60) = (4 * 7) + 0 = 28

  static const int trebleLine1Step = 30; // E4
  static const int trebleLine3Step = 34; // B4
  static const int trebleLine5Step = 38; // F5

  static const int bassLine1Step = 18; // G2
  static const int bassLine3Step = 22; // D3
  static const int bassLine5Step = 26; // A3

  static const int middleCStep = 28; // C4 (MIDI 60)

  // Chromatic pitch mapping within an octave (0 = C, 11 = B)
  // [diatonicIndex, ScoreAccidental]
  static const List<List<dynamic>> _chromaticMap = [
    [0, ScoreAccidental.none], // C
    [0, ScoreAccidental.sharp], // C#
    [1, ScoreAccidental.none], // D
    [1, ScoreAccidental.sharp], // D#
    [2, ScoreAccidental.none], // E
    [3, ScoreAccidental.none], // F
    [3, ScoreAccidental.sharp], // F#
    [4, ScoreAccidental.none], // G
    [4, ScoreAccidental.sharp], // G#
    [5, ScoreAccidental.none], // A
    [5, ScoreAccidental.sharp], // A#
    [6, ScoreAccidental.none], // B
  ];

  static const List<String> _diatonicNoteNames = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

  /// Resolves layout information for a given MIDI pitch (0 - 127).
  static ScorePitchLayout pitchToLayout(int midiPitch, {bool useFlats = false}) {
    final int clamped = midiPitch.clamp(0, 127);
    final int octave = (clamped ~/ 12) - 1;
    final int semitone = clamped % 12;

    int diatonic;
    ScoreAccidental accidental;

    if (useFlats && _chromaticMap[semitone][1] == ScoreAccidental.sharp) {
      // Map to next diatonic step with a flat
      diatonic = (_chromaticMap[semitone][0] as int) + 1;
      accidental = ScoreAccidental.flat;
    } else {
      diatonic = _chromaticMap[semitone][0] as int;
      accidental = _chromaticMap[semitone][1] as ScoreAccidental;
    }

    final int totalDiatonicStep = (octave * 7) + diatonic;
    final String accStr = accidental == ScoreAccidental.sharp ? '#' : (accidental == ScoreAccidental.flat ? 'b' : '');
    final String noteName = '${_diatonicNoteNames[diatonic]}$accStr$octave';

    return ScorePitchLayout(
      midiPitch: clamped,
      diatonicStep: totalDiatonicStep,
      accidental: accidental,
      noteName: noteName,
      isTreble: clamped >= 60, // C4 and above goes to Treble by default in Grand Staff
    );
  }

  /// Converts step duration (e.g. 4.0 = quarter note in standard 16-step bar) to note symbol type.
  static (ScoreNoteType, bool) durationToNoteType(double durationSteps, {double stepsPerBeat = 4.0}) {
    final double beats = durationSteps / stepsPerBeat;

    if (beats >= 3.5) {
      return (ScoreNoteType.whole, false);
    } else if (beats >= 2.5) {
      return (ScoreNoteType.half, true); // Dotted half
    } else if (beats >= 1.75) {
      return (ScoreNoteType.half, false);
    } else if (beats >= 1.25) {
      return (ScoreNoteType.quarter, true); // Dotted quarter
    } else if (beats >= 0.75) {
      return (ScoreNoteType.quarter, false);
    } else if (beats >= 0.35) {
      return (ScoreNoteType.eighth, false);
    } else {
      return (ScoreNoteType.sixteenth, false);
    }
  }

  /// Computes the visual Y coordinate and ledger lines for a notehead on a staff.
  /// [staffLine1Y] is the screen Y coordinate of Line 1 (the bottom line).
  /// [sp] is the staff space (distance between lines).
  static ScoreNoteVisual computeVisual({
    required ScorePitchLayout pitchLayout,
    required double durationSteps,
    required double staffLine1Y,
    required double sp,
    required bool isTrebleStaff,
    double stepsPerBeat = 4.0,
  }) {
    final int line1Step = isTrebleStaff ? trebleLine1Step : bassLine1Step;
    final int line5Step = isTrebleStaff ? trebleLine5Step : bassLine5Step;
    final int line3Step = isTrebleStaff ? trebleLine3Step : bassLine3Step;

    final double halfSp = sp / 2.0;
    // Step delta relative to Line 1
    final int stepDelta = pitchLayout.diatonicStep - line1Step;
    // Screen Y decreases as step goes higher
    final double noteY = staffLine1Y - (stepDelta * halfSp);

    // Stem direction rule: at or above line 3 stems point down; below line 3 stems point up
    final bool isStemUp = pitchLayout.diatonicStep < line3Step;

    // Determine ledger lines if outside the 5 staff lines
    final List<double> ledgers = [];
    if (pitchLayout.diatonicStep < line1Step) {
      // Below staff
      // Line 1 is at staffLine1Y. Ledger line 1 below is at staffLine1Y + sp
      for (int s = line1Step - 2; s >= pitchLayout.diatonicStep; s -= 2) {
        ledgers.add(staffLine1Y - (s - line1Step) * halfSp);
      }
    } else if (pitchLayout.diatonicStep > line5Step) {
      // Above staff
      // Line 5 is at staffLine1Y - 4 * sp. Ledger line 1 above is at staffLine1Y - 5 * sp
      for (int s = line5Step + 2; s <= pitchLayout.diatonicStep; s += 2) {
        ledgers.add(staffLine1Y - (s - line1Step) * halfSp);
      }
    }

    final (noteType, isDotted) = durationToNoteType(durationSteps, stepsPerBeat: stepsPerBeat);

    return ScoreNoteVisual(
      pitchLayout: pitchLayout,
      noteType: noteType,
      isDotted: isDotted,
      yPos: noteY,
      isStemUp: isStemUp,
      ledgerLineYPositions: ledgers,
    );
  }

  /// Inverts screen Y coordinate back to the closest MIDI pitch.
  static int yToMidiPitch({
    required double y,
    required double staffLine1Y,
    required double sp,
    required bool isTrebleStaff,
    ScoreAccidental forcedAccidental = ScoreAccidental.none,
  }) {
    final int line1Step = isTrebleStaff ? trebleLine1Step : bassLine1Step;
    final double halfSp = sp / 2.0;

    // Calculate closest diatonic step
    final double stepDeltaExact = (staffLine1Y - y) / halfSp;
    final int diatonicStep = (line1Step + stepDeltaExact.round()).clamp(0, 70);

    // Diatonic step -> octave and diatonic index
    final int octave = diatonicStep ~/ 7;
    final int diatonicIndex = diatonicStep % 7;

    // Convert diatonic index to standard natural semitone
    const naturalSemitones = [0, 2, 4, 5, 7, 9, 11];
    int semitone = naturalSemitones[diatonicIndex];

    if (forcedAccidental == ScoreAccidental.sharp) {
      semitone += 1;
    } else if (forcedAccidental == ScoreAccidental.flat) {
      semitone -= 1;
    }

    final int midiPitch = ((octave + 1) * 12 + semitone).clamp(0, 127);
    return midiPitch;
  }
}
