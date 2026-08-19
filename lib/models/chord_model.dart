import 'dart:math' as math;

/// Chord qualities supported by the chord engine.
enum ChordQuality {
  major,
  minor,
  dominant7,
  major7,
  minor7,
  diminished,
  augmented,
  halfDiminished7,
  sus2,
  sus4,
  add9,
  min9,
  maj9,
  dom9;

  String get displayName {
    switch (this) {
      case ChordQuality.major:
        return 'Major';
      case ChordQuality.minor:
        return 'Minor';
      case ChordQuality.dominant7:
        return '7 (Dom)';
      case ChordQuality.major7:
        return 'Maj7';
      case ChordQuality.minor7:
        return 'Min7';
      case ChordQuality.diminished:
        return 'Dim';
      case ChordQuality.augmented:
        return 'Aug';
      case ChordQuality.halfDiminished7:
        return 'm7b5';
      case ChordQuality.sus2:
        return 'Sus2';
      case ChordQuality.sus4:
        return 'Sus4';
      case ChordQuality.add9:
        return 'Add9';
      case ChordQuality.min9:
        return 'Min9';
      case ChordQuality.maj9:
        return 'Maj9';
      case ChordQuality.dom9:
        return '9 (Dom)';
    }
  }

  String get symbol {
    switch (this) {
      case ChordQuality.major:
        return '';
      case ChordQuality.minor:
        return 'm';
      case ChordQuality.dominant7:
        return '7';
      case ChordQuality.major7:
        return 'maj7';
      case ChordQuality.minor7:
        return 'm7';
      case ChordQuality.diminished:
        return 'dim';
      case ChordQuality.augmented:
        return 'aug';
      case ChordQuality.halfDiminished7:
        return 'm7b5';
      case ChordQuality.sus2:
        return 'sus2';
      case ChordQuality.sus4:
        return 'sus4';
      case ChordQuality.add9:
        return 'add9';
      case ChordQuality.min9:
        return 'm9';
      case ChordQuality.maj9:
        return 'maj9';
      case ChordQuality.dom9:
        return '9';
    }
  }

  List<int> get intervals {
    switch (this) {
      case ChordQuality.major:
        return [0, 4, 7];
      case ChordQuality.minor:
        return [0, 3, 7];
      case ChordQuality.dominant7:
        return [0, 4, 7, 10];
      case ChordQuality.major7:
        return [0, 4, 7, 11];
      case ChordQuality.minor7:
        return [0, 3, 7, 10];
      case ChordQuality.diminished:
        return [0, 3, 6];
      case ChordQuality.augmented:
        return [0, 4, 8];
      case ChordQuality.halfDiminished7:
        return [0, 3, 6, 10];
      case ChordQuality.sus2:
        return [0, 2, 7];
      case ChordQuality.sus4:
        return [0, 5, 7];
      case ChordQuality.add9:
        return [0, 4, 7, 14];
      case ChordQuality.min9:
        return [0, 3, 7, 10, 14];
      case ChordQuality.maj9:
        return [0, 4, 7, 11, 14];
      case ChordQuality.dom9:
        return [0, 4, 7, 10, 14];
    }
  }
}

/// A chord event positioned on the Chord Track timeline.
class ChordEvent {
  String id;
  int startBar; // 0-indexed bar number
  double barLength; // Duration in bars (e.g. 1.0, 2.0, 0.5)
  int rootPitchClass; // 0 = C, 1 = C#, 2 = D, ..., 11 = B
  ChordQuality quality;
  int? bassPitchClass; // Optional bass note for slash chords (e.g. C/E -> bass = 4)

  ChordEvent({
    required this.id,
    required this.startBar,
    this.barLength = 1.0,
    required this.rootPitchClass,
    required this.quality,
    this.bassPitchClass,
  });

  /// Formatted name e.g. "Cmaj7", "Am", "G/B", "F#m7b5"
  String get displayName => ChordTheory.formatChordName(rootPitchClass, quality, bassPitchClass);

  /// Root note name e.g. "C", "F#", "Bb"
  String get rootName => ChordTheory.pitchClassNames[rootPitchClass % 12];

  /// Bass note name if slash chord, else empty
  String get bassName => bassPitchClass != null ? ChordTheory.pitchClassNames[bassPitchClass! % 12] : '';

  /// All pitch classes contained in this chord (0..11)
  List<int> get pitchClasses => ChordTheory.getPitchClasses(rootPitchClass, quality, bassPitchClass);

  ChordEvent copyWith({
    String? id,
    int? startBar,
    double? barLength,
    int? rootPitchClass,
    ChordQuality? quality,
    int? bassPitchClass,
    bool clearBass = false,
  }) {
    return ChordEvent(
      id: id ?? this.id,
      startBar: startBar ?? this.startBar,
      barLength: barLength ?? this.barLength,
      rootPitchClass: rootPitchClass ?? this.rootPitchClass,
      quality: quality ?? this.quality,
      bassPitchClass: clearBass ? null : (bassPitchClass ?? this.bassPitchClass),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startBar': startBar,
    'barLength': barLength,
    'rootPitchClass': rootPitchClass,
    'quality': quality.name,
    if (bassPitchClass != null) 'bassPitchClass': bassPitchClass,
  };

  factory ChordEvent.fromJson(Map<String, dynamic> json) {
    final qualityStr = json['quality'] as String? ?? 'major';
    final quality = ChordQuality.values.firstWhere(
      (q) => q.name == qualityStr,
      orElse: () => ChordQuality.major,
    );
    return ChordEvent(
      id: json['id'] as String? ?? 'chord_${DateTime.now().millisecondsSinceEpoch}',
      startBar: (json['startBar'] as num?)?.toInt() ?? 0,
      barLength: (json['barLength'] as num?)?.toDouble() ?? 1.0,
      rootPitchClass: (json['rootPitchClass'] as num?)?.toInt() ?? 0,
      quality: quality,
      bassPitchClass: (json['bassPitchClass'] as num?)?.toInt(),
    );
  }
}

/// Progression preset with pre-configured chord progressions.
class ChordProgressionPreset {
  final String id;
  final String name;
  final String genre;
  final List<(int rootOffset, ChordQuality quality, double barLen)> chords; // offsets from tonic

  const ChordProgressionPreset({
    required this.id,
    required this.name,
    required this.genre,
    required this.chords,
  });
}

/// Music Theory Utilities, Circle of Fifths Data & Harmonic Remapping.
class ChordTheory {
  static const List<String> pitchClassNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  static const List<String> pitchClassFlatNames = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
  ];

  /// Circle of Fifths order: 12 Major sectors starting at C (top, 12 o'clock) clockwise.
  /// C (0), G (7), D (2), A (9), E (4), B (11), F#/Gb (6), Db (1), Ab (8), Eb (3), Bb (10), F (5)
  static const List<int> circleOfFifthsMajor = [
    0,  // C (12 o'clock)
    7,  // G (1 o'clock)
    2,  // D (2 o'clock)
    9,  // A (3 o'clock)
    4,  // E (4 o'clock)
    11, // B (5 o'clock)
    6,  // F#/Gb (6 o'clock)
    1,  // Db/C# (7 o'clock)
    8,  // Ab/G# (8 o'clock)
    3,  // Eb/D# (9 o'clock)
    10, // Bb/A# (10 o'clock)
    5,  // F (11 o'clock)
  ];

  /// Circle of Fifths relative minor order:
  /// Am (9), Em (4), Bm (11), F#m (6), C#m (1), G#m (8), D#m/Ebm (3), Bbm (10), Fm (5), Cm (0), Gm (7), Dm (2)
  static const List<int> circleOfFifthsMinor = [
    9,  // Am
    4,  // Em
    11, // Bm
    6,  // F#m
    1,  // C#m
    8,  // G#m
    3,  // D#m / Ebm
    10, // Bbm
    5,  // Fm
    0,  // Cm
    7,  // Gm
    2,  // Dm
  ];

  static const List<String> circleMajorLabels = [
    'C', 'G', 'D', 'A', 'E', 'B', 'F#', 'Db', 'Ab', 'Eb', 'Bb', 'F'
  ];

  static const List<String> circleMinorLabels = [
    'Am', 'Em', 'Bm', 'F#m', 'C#m', 'G#m', 'D#m', 'Bbm', 'Fm', 'Cm', 'Gm', 'Dm'
  ];

  /// Common chord progression presets
  static const List<ChordProgressionPreset> progressionPresets = [
    ChordProgressionPreset(
      id: 'pop_axis',
      name: 'Pop Classic (I - V - vi - IV)',
      genre: 'Pop / EDM',
      chords: [
        (0, ChordQuality.major, 1.0),  // I
        (7, ChordQuality.major, 1.0),  // V
        (9, ChordQuality.minor, 1.0),  // vi
        (5, ChordQuality.major, 1.0),  // IV
      ],
    ),
    ChordProgressionPreset(
      id: 'synthwave_dark',
      name: 'Cyberpunk Drive (vi - IV - I - V)',
      genre: 'Synthwave',
      chords: [
        (9, ChordQuality.minor, 1.0),  // vi
        (5, ChordQuality.major, 1.0),  // IV
        (0, ChordQuality.major, 1.0),  // I
        (7, ChordQuality.major, 1.0),  // V
      ],
    ),
    ChordProgressionPreset(
      id: 'jazz_two_five_one',
      name: 'Jazz Cadence (ii7 - V7 - Imaj7 - VI7)',
      genre: 'Jazz / Neo-Soul',
      chords: [
        (2, ChordQuality.minor7, 1.0),    // ii7
        (7, ChordQuality.dominant7, 1.0), // V7
        (0, ChordQuality.major7, 1.0),    // Imaj7
        (9, ChordQuality.dominant7, 1.0), // VI7
      ],
    ),
    ChordProgressionPreset(
      id: 'cinematic_epic',
      name: 'Epic Hero (i - VI - III - VII)',
      genre: 'Cinematic / Rock',
      chords: [
        (0, ChordQuality.minor, 1.0), // i
        (8, ChordQuality.major, 1.0), // VI
        (3, ChordQuality.major, 1.0), // III
        (10, ChordQuality.major, 1.0),// VII
      ],
    ),
    ChordProgressionPreset(
      id: 'lofi_chill',
      name: 'Lofi Nostalgia (Imaj9 - vi9 - ii9 - V7)',
      genre: 'Lofi / R&B',
      chords: [
        (0, ChordQuality.maj9, 1.0),      // Imaj9
        (9, ChordQuality.min9, 1.0),      // vi9
        (2, ChordQuality.min9, 1.0),      // ii9
        (7, ChordQuality.dominant7, 1.0), // V7
      ],
    ),
    ChordProgressionPreset(
      id: 'andalusian',
      name: 'Flamenco Descent (i - VII - VI - V)',
      genre: 'Latin / Flamenco',
      chords: [
        (0, ChordQuality.minor, 1.0),     // i
        (10, ChordQuality.major, 1.0),    // VII
        (8, ChordQuality.major, 1.0),     // VI
        (7, ChordQuality.dominant7, 1.0), // V
      ],
    ),
  ];

  /// Formats a chord name nicely (e.g. "Cmaj7", "G/B", "F#m7")
  static String formatChordName(int rootPitchClass, ChordQuality quality, [int? bassPitchClass]) {
    final rootName = pitchClassNames[rootPitchClass % 12];
    final sym = quality.symbol;
    if (bassPitchClass != null && (bassPitchClass % 12) != (rootPitchClass % 12)) {
      final bassName = pitchClassNames[bassPitchClass % 12];
      return '$rootName$sym/$bassName';
    }
    return '$rootName$sym';
  }

  /// Calculates all unique pitch classes (0..11) for a given chord.
  static List<int> getPitchClasses(int rootPitchClass, ChordQuality quality, [int? bassPitchClass]) {
    final set = <int>{};
    if (bassPitchClass != null) {
      set.add(bassPitchClass % 12);
    }
    for (final interval in quality.intervals) {
      set.add((rootPitchClass + interval) % 12);
    }
    return set.toList()..sort();
  }

  /// Returns MIDI notes for auditioning a chord around octave 4 (approx MIDI 60)
  static List<int> getAuditionMidiNotes(ChordEvent chord) {
    const baseMidi = 48; // C3
    final rootMidi = baseMidi + (chord.rootPitchClass % 12);
    final notes = <int>[];

    if (chord.bassPitchClass != null) {
      final bassMidi = 36 + (chord.bassPitchClass! % 12);
      notes.add(bassMidi);
    } else {
      notes.add(rootMidi - 12); // Add bass root octave below
    }

    for (final interval in chord.quality.intervals) {
      notes.add(rootMidi + interval);
    }
    return notes;
  }

  /// Returns diatonic Roman numeral relative to current Song Key root (e.g. C Major -> I, ii, iii, IV, V, vi, vii°)
  static String getRomanNumeral(int keyRootPitchClass, bool isKeyMinor, int chordRootPitchClass, ChordQuality quality) {
    final semitoneDiff = (chordRootPitchClass - keyRootPitchClass + 12) % 12;
    if (!isKeyMinor) {
      // Major Key
      switch (semitoneDiff) {
        case 0:
          return quality == ChordQuality.major || quality == ChordQuality.major7 || quality == ChordQuality.maj9 ? 'I' : 'i';
        case 2:
          return quality == ChordQuality.minor || quality == ChordQuality.minor7 || quality == ChordQuality.min9 ? 'ii' : 'II';
        case 4:
          return quality == ChordQuality.minor || quality == ChordQuality.minor7 || quality == ChordQuality.min9 ? 'iii' : 'III';
        case 5:
          return quality == ChordQuality.major || quality == ChordQuality.major7 || quality == ChordQuality.maj9 ? 'IV' : 'iv';
        case 7:
          return quality == ChordQuality.major || quality == ChordQuality.dominant7 || quality == ChordQuality.dom9 ? 'V' : 'v';
        case 9:
          return quality == ChordQuality.minor || quality == ChordQuality.minor7 || quality == ChordQuality.min9 ? 'vi' : 'VI';
        case 11:
          return quality == ChordQuality.diminished || quality == ChordQuality.halfDiminished7 ? 'vii°' : 'VII';
        default:
          return pitchClassNames[chordRootPitchClass % 12];
      }
    } else {
      // Minor Key
      switch (semitoneDiff) {
        case 0:
          return 'i';
        case 2:
          return 'ii°';
        case 3:
          return 'III';
        case 5:
          return 'iv';
        case 7:
          return quality == ChordQuality.dominant7 || quality == ChordQuality.major ? 'V' : 'v';
        case 8:
          return 'VI';
        case 10:
          return 'VII';
        default:
          return pitchClassNames[chordRootPitchClass % 12];
      }
    }
  }

  /// Scale degrees / Parent scale pitch classes for a chord
  static List<int> getScalePitchClassesForChord(ChordEvent chord) {
    final root = chord.rootPitchClass % 12;
    switch (chord.quality) {
      case ChordQuality.minor:
      case ChordQuality.minor7:
      case ChordQuality.min9:
        // Natural minor scale (Aeolian / Dorian)
        return [0, 2, 3, 5, 7, 8, 10].map((i) => (root + i) % 12).toList();
      case ChordQuality.dominant7:
      case ChordQuality.dom9:
        // Mixolydian scale
        return [0, 2, 4, 5, 7, 9, 10].map((i) => (root + i) % 12).toList();
      case ChordQuality.diminished:
      case ChordQuality.halfDiminished7:
        // Locrian scale
        return [0, 1, 3, 5, 6, 8, 10].map((i) => (root + i) % 12).toList();
      case ChordQuality.major:
      case ChordQuality.major7:
      case ChordQuality.maj9:
      case ChordQuality.add9:
      case ChordQuality.sus2:
      case ChordQuality.sus4:
      case ChordQuality.augmented:
      default:
        // Major scale (Ionian)
        return [0, 2, 4, 5, 7, 9, 11].map((i) => (root + i) % 12).toList();
    }
  }

  /// Non-destructive realtime pitch snapping / harmonic remapping algorithm
  static int remapPitchForChord(int originalPitch, ChordEvent chord, String followMode) {
    if (followMode == 'off') return originalPitch;

    final originalPc = originalPitch % 12;
    final octave = originalPitch ~/ 12;

    switch (followMode) {
      case 'bass':
        // Snap pitch class directly to bass/root note while preserving the register
        final targetPc = chord.bassPitchClass != null ? (chord.bassPitchClass! % 12) : (chord.rootPitchClass % 12);
        return (octave * 12) + targetPc;

      case 'chord':
        // Snap to closest tone in the active chord (Root, 3rd, 5th, 7th, 9th)
        final chordPcs = chord.pitchClasses;
        final bestPc = _findClosestPitchClass(originalPc, chordPcs);
        return (octave * 12) + bestPc;

      case 'scale':
        // Snap to closest tone in the chord's parent scale
        final scalePcs = getScalePitchClassesForChord(chord);
        final bestPc = _findClosestPitchClass(originalPc, scalePcs);
        return (octave * 12) + bestPc;

      case 'colorLead':
        // Keep note if it is a chord or scale tone; if it's dissonant, nudge to nearest chord tone
        final chordPcs = chord.pitchClasses;
        final scalePcs = getScalePitchClassesForChord(chord);
        if (chordPcs.contains(originalPc) || scalePcs.contains(originalPc)) {
          return originalPitch;
        }
        final bestPc = _findClosestPitchClass(originalPc, chordPcs);
        return (octave * 12) + bestPc;

      default:
        return originalPitch;
    }
  }

  static int _findClosestPitchClass(int pitchClass, List<int> targetPcs) {
    if (targetPcs.isEmpty) return pitchClass;
    int bestPc = targetPcs.first;
    int minDistance = 999;

    for (final target in targetPcs) {
      final diff = (pitchClass - target).abs();
      // Distance on circular clock (0..12)
      final distance = math.min(diff, 12 - diff);
      if (distance < minDistance) {
        minDistance = distance;
        bestPc = target;
      }
    }
    return bestPc;
  }
}
