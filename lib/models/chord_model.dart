import 'dart:math' as math;
import 'track_model.dart';

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
  final String description;
  final List<String> tags;
  final List<(int rootOffset, ChordQuality quality, double barLen)> chords; // offsets from tonic

  const ChordProgressionPreset({
    required this.id,
    required this.name,
    required this.genre,
    this.description = '',
    this.tags = const [],
    required this.chords,
  });

  /// Formatted Roman numeral summary string
  String get romanSummary {
    return chords.map((c) {
      final name = ChordTheory.getRomanNumeral(0, false, c.$1, c.$2);
      return name;
    }).join(' - ');
  }
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

  /// Common & Curated chord progression presets
  static const List<ChordProgressionPreset> progressionPresets = [
    // --- POP & MAINSTREAM ---
    ChordProgressionPreset(
      id: 'pop_axis',
      name: 'Pop Classic (I - V - vi - IV)',
      genre: 'Pop',
      description: 'The iconic Axis of Awesome progression behind hundreds of massive global hit songs.',
      tags: ['pop', 'hits', 'anthem', 'radio'],
      chords: [
        (0, ChordQuality.major, 1.0),  // I
        (7, ChordQuality.major, 1.0),  // V
        (9, ChordQuality.minor, 1.0),  // vi
        (5, ChordQuality.major, 1.0),  // IV
      ],
    ),
    ChordProgressionPreset(
      id: 'pop_doo_wop',
      name: '50s Doo-Wop (I - vi - IV - V)',
      genre: 'Pop',
      description: 'Nostalgic golden-era ballad progression made legendary by "Stand By Me" and classic rock & roll.',
      tags: ['50s', 'ballad', 'retro', 'motown'],
      chords: [
        (0, ChordQuality.major, 1.0),  // I
        (9, ChordQuality.minor, 1.0),  // vi
        (5, ChordQuality.major, 1.0),  // IV
        (7, ChordQuality.major, 1.0),  // V
      ],
    ),
    ChordProgressionPreset(
      id: 'pop_emotional',
      name: 'Emotional Anthem (I - iii - IV - V)',
      genre: 'Pop',
      description: 'Uplifting ascending progression featuring a bittersweet mediant chord.',
      tags: ['pop', 'uplifting', 'climax'],
      chords: [
        (0, ChordQuality.major, 1.0),  // I
        (4, ChordQuality.minor, 1.0),  // iii
        (5, ChordQuality.major, 1.0),  // IV
        (7, ChordQuality.major, 1.0),  // V
      ],
    ),
    ChordProgressionPreset(
      id: 'pop_melancholy',
      name: 'Sensitive Minor (vi - IV - I - V)',
      genre: 'Pop',
      description: 'Moody, emotive minor pop progression used in countless heartfelt modern tracks.',
      tags: ['pop', 'minor', 'emotional'],
      chords: [
        (9, ChordQuality.minor, 1.0),  // vi
        (5, ChordQuality.major, 1.0),  // IV
        (0, ChordQuality.major, 1.0),  // I
        (7, ChordQuality.major, 1.0),  // V
      ],
    ),

    // --- SYNTHWAVE & CYBERPUNK ---
    ChordProgressionPreset(
      id: 'synthwave_dark',
      name: 'Cyberpunk Drive (vi - IV - I - V)',
      genre: 'Synthwave',
      description: 'Relentless driving progression with high-energy minor synth energy.',
      tags: ['synthwave', 'cyberpunk', 'retrowave', 'drive'],
      chords: [
        (9, ChordQuality.minor, 1.0),  // vi
        (5, ChordQuality.major, 1.0),  // IV
        (0, ChordQuality.major, 1.0),  // I
        (7, ChordQuality.major, 1.0),  // V
      ],
    ),
    ChordProgressionPreset(
      id: 'synthwave_outrun',
      name: 'Outrun Sunset (i - VII - v - VI)',
      genre: 'Synthwave',
      description: 'Nostalgic 80s arcade sunset cruising vibe with natural minor cadences.',
      tags: ['synthwave', 'outrun', '80s', 'neon'],
      chords: [
        (0, ChordQuality.minor, 1.0),   // i
        (10, ChordQuality.major, 1.0),  // VII
        (7, ChordQuality.minor, 1.0),   // v
        (8, ChordQuality.major, 1.0),   // VI
      ],
    ),
    ChordProgressionPreset(
      id: 'synthwave_darkwave',
      name: 'Darkwave Pulse (i - VI - iv - V)',
      genre: 'Synthwave',
      description: 'Ominous industrial darkwave loop with a harmonic minor dominant turnaround.',
      tags: ['synthwave', 'darkwave', 'goth', 'minor'],
      chords: [
        (0, ChordQuality.minor, 1.0),     // i
        (8, ChordQuality.major, 1.0),     // VI
        (5, ChordQuality.minor, 1.0),     // iv
        (7, ChordQuality.dominant7, 1.0), // V7
      ],
    ),

    // --- EDM, HOUSE & TRANCE ---
    ChordProgressionPreset(
      id: 'edm_progressive_house',
      name: 'Progressive House (IV - I - vi - V)',
      genre: 'EDM',
      description: 'Festival mainstage euphoric buildup and melodic drop progression.',
      tags: ['edm', 'house', 'festival', 'euphoria'],
      chords: [
        (5, ChordQuality.major, 1.0), // IV
        (0, ChordQuality.major, 1.0), // I
        (9, ChordQuality.minor, 1.0), // vi
        (7, ChordQuality.major, 1.0), // V
      ],
    ),
    ChordProgressionPreset(
      id: 'edm_deep_house',
      name: 'Deep House Nocturne (i7 - v7 - iv7 - VImaj7)',
      genre: 'EDM',
      description: 'Late-night club groove with lush minor 7th chords and deep sub warmth.',
      tags: ['edm', 'deephouse', 'club', 'groove'],
      chords: [
        (0, ChordQuality.minor7, 1.0), // i7
        (7, ChordQuality.minor7, 1.0), // v7
        (5, ChordQuality.minor7, 1.0), // iv7
        (8, ChordQuality.major7, 1.0), // VImaj7
      ],
    ),
    ChordProgressionPreset(
      id: 'edm_trance_uplift',
      name: 'Trance Uplift (i - VI - VII - i)',
      genre: 'EDM',
      description: 'Driving 138 BPM uplifting trance arpeggio progression with high emotional energy.',
      tags: ['edm', 'trance', 'uplift', 'energy'],
      chords: [
        (0, ChordQuality.minor, 1.0),  // i
        (8, ChordQuality.major, 1.0),  // VI
        (10, ChordQuality.major, 1.0), // VII
        (0, ChordQuality.minor, 1.0),  // i
      ],
    ),
    ChordProgressionPreset(
      id: 'edm_future_bass',
      name: 'Future Bass Lush (IVmaj9 - V - iii7 - vi7)',
      genre: 'EDM',
      description: 'Glitchy vocal-chopped future bass progression with extended lush 9th chords.',
      tags: ['edm', 'futurebass', 'chill', 'lush'],
      chords: [
        (5, ChordQuality.maj9, 1.0),   // IVmaj9
        (7, ChordQuality.major, 1.0),  // V
        (4, ChordQuality.minor7, 1.0), // iii7
        (9, ChordQuality.minor7, 1.0), // vi7
      ],
    ),

    // --- JAZZ, NEO-SOUL & R&B ---
    ChordProgressionPreset(
      id: 'jazz_two_five_one',
      name: 'Jazz Cadence (ii7 - V7 - Imaj7 - VI7)',
      genre: 'Jazz / Neo-Soul',
      description: 'The foundational standard of jazz harmony with secondary dominant turnaround.',
      tags: ['jazz', 'ii-v-i', 'standard', 'harmony'],
      chords: [
        (2, ChordQuality.minor7, 1.0),    // ii7
        (7, ChordQuality.dominant7, 1.0), // V7
        (0, ChordQuality.major7, 1.0),    // Imaj7
        (9, ChordQuality.dominant7, 1.0), // VI7
      ],
    ),
    ChordProgressionPreset(
      id: 'neo_soul_smooth',
      name: 'Neo-Soul Silk (ii9 - V9 - Imaj9 - VI7alt)',
      genre: 'Jazz / Neo-Soul',
      description: 'Silky, warm Neo-Soul progression with rich color tones and voice leading.',
      tags: ['neosoul', 'soul', 'rnb', 'warm'],
      chords: [
        (2, ChordQuality.min9, 1.0),      // ii9
        (7, ChordQuality.dom9, 1.0),      // V9
        (0, ChordQuality.maj9, 1.0),      // Imaj9
        (9, ChordQuality.dominant7, 1.0), // VI7
      ],
    ),
    ChordProgressionPreset(
      id: 'rnb_bedroom_jam',
      name: 'R&B Slow Jam (IVmaj7 - iii7 - ii7 - Imaj7)',
      genre: 'Jazz / Neo-Soul',
      description: 'Velveteen step-wise descending bass line progression for smooth R&B ballads.',
      tags: ['rnb', 'slowjam', 'ballad', 'descent'],
      chords: [
        (5, ChordQuality.major7, 1.0), // IVmaj7
        (4, ChordQuality.minor7, 1.0), // iii7
        (2, ChordQuality.minor7, 1.0), // ii7
        (0, ChordQuality.major7, 1.0), // Imaj7
      ],
    ),
    ChordProgressionPreset(
      id: 'jazz_modal_so_what',
      name: 'Modal Jazz Vamp (i7 - i7 - bII7 - i7)',
      genre: 'Jazz / Neo-Soul',
      description: 'Miles Davis "So What" style Dorian modal shift with half-step chromatic tension.',
      tags: ['jazz', 'modal', 'dorian', 'vamp'],
      chords: [
        (0, ChordQuality.minor7, 2.0), // i7
        (1, ChordQuality.minor7, 1.0), // bII7
        (0, ChordQuality.minor7, 1.0), // i7
      ],
    ),

    // --- LO-FI & CHILLHOP ---
    ChordProgressionPreset(
      id: 'lofi_chill',
      name: 'Lofi Nostalgia (Imaj9 - vi9 - ii9 - V7)',
      genre: 'Lo-Fi',
      description: 'Wobbly tape saturation and rainy day study beats progression.',
      tags: ['lofi', 'chill', 'study', 'relax'],
      chords: [
        (0, ChordQuality.maj9, 1.0),      // Imaj9
        (9, ChordQuality.min9, 1.0),      // vi9
        (2, ChordQuality.min9, 1.0),      // ii9
        (7, ChordQuality.dominant7, 1.0), // V7
      ],
    ),
    ChordProgressionPreset(
      id: 'lofi_sunset',
      name: 'Lofi Sunset Breeze (IVmaj9 - iii7 - vi9 - Imaj7)',
      genre: 'Lo-Fi',
      description: 'Dreamy chillhop loop with lush upper extensions and laid-back swing.',
      tags: ['lofi', 'chillhop', 'sunset', 'warm'],
      chords: [
        (5, ChordQuality.maj9, 1.0),   // IVmaj9
        (4, ChordQuality.minor7, 1.0), // iii7
        (9, ChordQuality.min9, 1.0),   // vi9
        (0, ChordQuality.major7, 1.0), // Imaj7
      ],
    ),

    // --- CINEMATIC & AMBIENT ---
    ChordProgressionPreset(
      id: 'cinematic_epic',
      name: 'Epic Hero (i - VI - III - VII)',
      genre: 'Cinematic',
      description: 'Blockbuster trailer and movie soundtrack theme with sweeping orchestral power.',
      tags: ['cinematic', 'epic', 'soundtrack', 'heroic'],
      chords: [
        (0, ChordQuality.minor, 1.0), // i
        (8, ChordQuality.major, 1.0), // VI
        (3, ChordQuality.major, 1.0), // III
        (10, ChordQuality.major, 1.0),// VII
      ],
    ),
    ChordProgressionPreset(
      id: 'cinematic_hans_ostinato',
      name: 'Hans Zimmer Ostinato (i - VI - iv - VII)',
      genre: 'Cinematic',
      description: 'Relentless cello string ostinato with massive harmonic tension and resolution.',
      tags: ['cinematic', 'zimmer', 'strings', 'tension'],
      chords: [
        (0, ChordQuality.minor, 1.0),  // i
        (8, ChordQuality.major, 1.0),  // VI
        (5, ChordQuality.minor, 1.0),  // iv
        (10, ChordQuality.major, 1.0), // VII
      ],
    ),
    ChordProgressionPreset(
      id: 'cinematic_ethereal',
      name: 'Ethereal Dreamscape (Imaj7 - IVmaj7 - vi7 - V)',
      genre: 'Cinematic',
      description: 'Spacious, ambient soundscape progression with floating reverbs and pads.',
      tags: ['ambient', 'ethereal', 'pads', 'space'],
      chords: [
        (0, ChordQuality.major7, 1.0), // Imaj7
        (5, ChordQuality.major7, 1.0), // IVmaj7
        (9, ChordQuality.minor7, 1.0), // vi7
        (7, ChordQuality.major, 1.0),  // V
      ],
    ),

    // --- ROCK & METAL ---
    ChordProgressionPreset(
      id: 'rock_power_anthem',
      name: 'Classic Rock Anthem (I - IV - V - IV)',
      genre: 'Rock / Metal',
      description: 'Timeless arena rock progression with roaring overdriven rhythm guitars.',
      tags: ['rock', 'arena', 'power', 'guitars'],
      chords: [
        (0, ChordQuality.major, 1.0), // I
        (5, ChordQuality.major, 1.0), // IV
        (7, ChordQuality.major, 1.0), // V
        (5, ChordQuality.major, 1.0), // IV
      ],
    ),
    ChordProgressionPreset(
      id: 'metal_phrygian_menace',
      name: 'Phrygian Metal Riff (i - bII - i - bVII)',
      genre: 'Rock / Metal',
      description: 'Heavy downtuned metal riff with the sinister half-step Phrygian flat-2nd.',
      tags: ['metal', 'phrygian', 'heavy', 'riff'],
      chords: [
        (0, ChordQuality.minor, 1.0),  // i
        (1, ChordQuality.major, 1.0),  // bII
        (0, ChordQuality.minor, 1.0),  // i
        (10, ChordQuality.major, 1.0), // bVII
      ],
    ),
    ChordProgressionPreset(
      id: 'grunge_minor_drop',
      name: '90s Grunge Drop (i - VI - III - VII)',
      genre: 'Rock / Metal',
      description: 'Raw, gritty grunge and alternative rock power chord progression.',
      tags: ['grunge', 'alternative', '90s', 'distortion'],
      chords: [
        (0, ChordQuality.minor, 1.0),  // i
        (8, ChordQuality.major, 1.0),  // VI
        (3, ChordQuality.major, 1.0),  // III
        (10, ChordQuality.major, 1.0), // VII
      ],
    ),

    // --- LATIN & FLAMENCO ---
    ChordProgressionPreset(
      id: 'andalusian',
      name: 'Flamenco Descent (i - VII - VI - V)',
      genre: 'Latin / Flamenco',
      description: 'The ancient Andalusian cadence featuring dramatic step-wise downward resolution.',
      tags: ['latin', 'flamenco', 'spanish', 'classical'],
      chords: [
        (0, ChordQuality.minor, 1.0),     // i
        (10, ChordQuality.major, 1.0),    // VII
        (8, ChordQuality.major, 1.0),     // VI
        (7, ChordQuality.dominant7, 1.0), // V7
      ],
    ),
    ChordProgressionPreset(
      id: 'bossa_ipanema',
      name: 'Bossa Nova Ipanema (Imaj7 - II7 - ii7 - V7)',
      genre: 'Latin / Flamenco',
      description: 'Classic Brazilian bossa nova with secondary dominant 9th chords and gentle nylon swing.',
      tags: ['bossa', 'latin', 'brazil', 'jazz'],
      chords: [
        (0, ChordQuality.major7, 1.0),    // Imaj7
        (2, ChordQuality.dominant7, 1.0), // II7
        (2, ChordQuality.minor7, 1.0),    // ii7
        (7, ChordQuality.dominant7, 1.0), // V7
      ],
    ),
    ChordProgressionPreset(
      id: 'latin_reggaeton_bounce',
      name: 'Reggaeton / Latin Trap (i - VI - III - VII)',
      genre: 'Latin / Flamenco',
      description: 'Bouncing Latin urban dembow groove progression with infectious minor warmth.',
      tags: ['reggaeton', 'dembow', 'latin', 'trap'],
      chords: [
        (0, ChordQuality.minor, 1.0),  // i
        (8, ChordQuality.major, 1.0),  // VI
        (3, ChordQuality.major, 1.0),  // III
        (10, ChordQuality.major, 1.0), // VII
      ],
    ),

    // --- ANIME & J-POP ---
    ChordProgressionPreset(
      id: 'jpop_royal_road',
      name: 'Royal Road / Oudo 王道 (IVmaj7 - V7 - iii7 - vi)',
      genre: 'Anime / J-Pop',
      description: 'The signature "Royal Road" progression used in anime openings and J-Pop masterpieces.',
      tags: ['anime', 'jpop', 'oudo', 'royalroad'],
      chords: [
        (5, ChordQuality.major7, 1.0),    // IVmaj7
        (7, ChordQuality.dominant7, 1.0), // V7
        (4, ChordQuality.minor7, 1.0),    // iii7
        (9, ChordQuality.minor, 1.0),     // vi
      ],
    ),
    ChordProgressionPreset(
      id: 'jpop_just_the_two_of_us',
      name: 'Shibutani Groover (IVmaj7 - III7 - vi7 - I7)',
      genre: 'Anime / J-Pop',
      description: 'Funky J-Rock & City Pop progression with chromatic secondary dominant push.',
      tags: ['citypop', 'anime', 'funk', 'groove'],
      chords: [
        (5, ChordQuality.major7, 1.0),    // IVmaj7
        (4, ChordQuality.dominant7, 1.0), // III7
        (9, ChordQuality.minor7, 1.0),    // vi7
        (0, ChordQuality.dominant7, 1.0), // I7
      ],
    ),
    ChordProgressionPreset(
      id: 'jpop_emotional_climax',
      name: 'Anime Emotional Climax (IV - V - vi - I)',
      genre: 'Anime / J-Pop',
      description: 'Driving cinematic chorus explosion from high-octane anime openings.',
      tags: ['anime', 'opening', 'chorus', 'climax'],
      chords: [
        (5, ChordQuality.major, 1.0), // IV
        (7, ChordQuality.major, 1.0), // V
        (9, ChordQuality.minor, 1.0), // vi
        (0, ChordQuality.major, 1.0), // I
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

  /// Given a list of active MIDI pitches (e.g. [60, 64, 67] for C4, E4, G4),
  /// detects the best matching root pitch class (0..11) and ChordQuality.
  static (int rootPc, ChordQuality quality, int? bassPc)? detectChordFromPitches(List<int> midiPitches) {
    if (midiPitches.isEmpty) return null;

    // Find lowest bass note
    final lowestPitch = midiPitches.reduce((a, b) => a < b ? a : b);
    final bassPc = lowestPitch % 12;

    // Count active pitch classes
    final activePcs = midiPitches.map((p) => p % 12).toSet();
    if (activePcs.isEmpty) return null;

    int bestRoot = bassPc;
    ChordQuality bestQuality = ChordQuality.major;
    double bestScore = -1.0;

    // Candidate roots to test (prioritize bass note and active pitch classes)
    final candidateRoots = activePcs.toList();

    for (final root in candidateRoots) {
      for (final quality in ChordQuality.values) {
        final chordPcs = quality.intervals.map((i) => (root + i) % 12).toSet();

        // Intersection (matching tones)
        final matches = activePcs.intersection(chordPcs).length;
        final thirdPc = (root + quality.intervals[1]) % 12;
        final hasThird = activePcs.contains(thirdPc);
        final hasRoot = activePcs.contains(root);

        // Score formula
        double score = (matches.toDouble() / chordPcs.length);
        if (hasRoot) score += 0.5;
        if (hasThird) score += 0.4;
        if (root == bassPc) score += 0.3; // Prefer root in bass

        // Penalize extra tones outside the chord
        final outsideTones = activePcs.difference(chordPcs).length;
        score -= outsideTones * 0.25;

        if (score > bestScore) {
          bestScore = score;
          bestRoot = root;
          bestQuality = quality;
        }
      }
    }

    return (bestRoot, bestQuality, bassPc != bestRoot ? bassPc : null);
  }

  /// Analyzes note events across bars and creates a sequence of ChordEvents
  static List<ChordEvent> extractChordsFromNotes(
    List<Note> notes, {
    int startBar = 0,
    int totalBars = 0,
    int stepsPerBar = 16,
  }) {
    if (notes.isEmpty) return [];

    final List<ChordEvent> extracted = [];

    // Determine max bar from notes if totalBars <= 0
    int effectiveTotalBars = totalBars;
    if (effectiveTotalBars <= 0) {
      double maxStep = 0.0;
      for (final n in notes) {
        final end = n.startStep + n.durationSteps;
        if (end > maxStep) maxStep = end;
      }
      effectiveTotalBars = (maxStep / stepsPerBar).ceil();
      if (effectiveTotalBars < 1) effectiveTotalBars = 1;
    }

    for (int bar = 0; bar < effectiveTotalBars; bar++) {
      final barStartStep = bar * stepsPerBar;
      final barEndStep = (bar + 1) * stepsPerBar;

      // Notes active during this bar
      final barNotes = notes.where((n) {
        final noteEnd = n.startStep + n.durationSteps;
        return n.startStep < barEndStep && noteEnd > barStartStep;
      }).toList();

      if (barNotes.isNotEmpty) {
        final pitches = barNotes.map((n) => n.pitch).toList();
        final detected = detectChordFromPitches(pitches);
        if (detected != null) {
          final chord = ChordEvent(
            id: 'chord_extracted_${startBar + bar}_${DateTime.now().microsecondsSinceEpoch}',
            startBar: startBar + bar,
            barLength: 1.0,
            rootPitchClass: detected.$1,
            quality: detected.$2,
            bassPitchClass: detected.$3,
          );

          // Merge with previous chord if identical
          if (extracted.isNotEmpty &&
              extracted.last.rootPitchClass == chord.rootPitchClass &&
              extracted.last.quality == chord.quality &&
              extracted.last.bassPitchClass == chord.bassPitchClass &&
              (extracted.last.startBar + extracted.last.barLength) == chord.startBar) {
            extracted.last.barLength += 1.0;
          } else {
            extracted.add(chord);
          }
        }
      }
    }

    return extracted;
  }
}
