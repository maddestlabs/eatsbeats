// Pure-Dart procedural ensemble blueprint specification for Eatsbeats.
// Defines structured architectural blueprints for variable-N track ensembles
// and dynamic, evolving section arrangements.

import '../../models/chord_model.dart';

/// The 5 universal functional roles an instrument track performs in an ensemble.
enum FunctionalRole {
  /// Percussion / drums / rhythm machine / shaker / timpani.
  rhythm,

  /// Bassline / foundation / walking root / pedal drone.
  foundation,

  /// Harmonic accompaniment: sustained pads, strummed chords, arpeggios, stabs.
  harmonicTexture,

  /// Lyrical melody / hook / solo lead / primary vocal line.
  primaryMelody,

  /// Counter-melody / harmonic answering / 3rds/6ths doubling / fanfare stabs.
  counterpoint;

  static FunctionalRole fromString(String str) {
    final clean = str.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    for (final role in FunctionalRole.values) {
      if (role.name.toLowerCase() == clean) return role;
    }
    if (clean.contains('drum') || clean.contains('percuss') || clean.contains('beat')) return FunctionalRole.rhythm;
    if (clean.contains('bass') || clean.contains('root') || clean.contains('sub')) return FunctionalRole.foundation;
    if (clean.contains('chord') || clean.contains('pad') || clean.contains('strum') || clean.contains('arp')) {
      return FunctionalRole.harmonicTexture;
    }
    if (clean.contains('counter') || clean.contains('answer') || clean.contains('harmony')) return FunctionalRole.counterpoint;
    return FunctionalRole.primaryMelody;
  }
}

/// Rhythmic / voicing execution style for harmonic texture tracks.
enum TextureType {
  sustained,
  strummed,
  arpeggiated,
  stabs;

  static TextureType fromString(String str) {
    final clean = str.trim().toLowerCase();
    if (clean.contains('strum') || clean.contains('pluck') || clean.contains('lute') || clean.contains('acoustic')) {
      return TextureType.strummed;
    }
    if (clean.contains('arp') || clean.contains('cascade') || clean.contains('chip')) {
      return TextureType.arpeggiated;
    }
    if (clean.contains('stab') || clean.contains('punch') || clean.contains('skank')) {
      return TextureType.stabs;
    }
    return TextureType.sustained;
  }
}

/// Melodic motif behavior for a section.
enum MelodyBehavior {
  themeA,
  themeB,
  callResponse,
  variation,
  tacet; // Resting / silent

  static MelodyBehavior fromString(String str) {
    final clean = str.trim().toLowerCase();
    if (clean.contains('tacet') || clean.contains('rest') || clean.contains('silent')) return MelodyBehavior.tacet;
    if (clean.contains('b') || clean.contains('contrast')) return MelodyBehavior.themeB;
    if (clean.contains('call') || clean.contains('response') || clean.contains('echo')) return MelodyBehavior.callResponse;
    if (clean.contains('var') || clean.contains('prime') || clean.contains('evolv')) return MelodyBehavior.variation;
    return MelodyBehavior.themeA;
  }
}

/// Stylistic aesthetic and phrasing behavior for lead melody generation.
enum MelodyStyle {
  lyrical,        // Expressive, soulful, vocal-like phrasing with dynamic breath/rests
  heroicAnthem,   // Bold, triumphant leaps (4ths, 5ths, octaves), dotted figures, slides into climaxes
  syncopatedRiff, // Funky, driving, offbeat anticipations and punchy hooks
  cascadingRun,   // Flowing scalar runs, rapid undulating arpeggios (chiptune / synthwave)
  folkBallad,     // Pastoral, lilting pentatonic with graceful ornaments
  bluesy,         // Expressive blue notes (b3, b5, b7), bent slides, soul phrasing
  atmospheric,    // Spacious, floating, long breath/tails in high register
  auto;           // Intelligently chosen based on instrument, tempo, and seed

  static MelodyStyle fromString(String str) {
    final clean = str.trim().toLowerCase();
    if (clean.contains('hero') || clean.contains('anthem') || clean.contains('triumph') || clean.contains('epic')) {
      return MelodyStyle.heroicAnthem;
    }
    if (clean.contains('sync') || clean.contains('funk') || clean.contains('riff') || clean.contains('hook')) {
      return MelodyStyle.syncopatedRiff;
    }
    if (clean.contains('cascad') || clean.contains('run') || clean.contains('chip') || clean.contains('synthwave')) {
      return MelodyStyle.cascadingRun;
    }
    if (clean.contains('folk') || clean.contains('ballad') || clean.contains('waltz') || clean.contains('pastoral')) {
      return MelodyStyle.folkBallad;
    }
    if (clean.contains('blue') || clean.contains('soul') || clean.contains('jazz')) {
      return MelodyStyle.bluesy;
    }
    if (clean.contains('atmos') || clean.contains('ambient') || clean.contains('space') || clean.contains('ethereal')) {
      return MelodyStyle.atmospheric;
    }
    if (clean.contains('lyric') || clean.contains('vocal') || clean.contains('sing')) {
      return MelodyStyle.lyrical;
    }
    return MelodyStyle.auto;
  }
}

/// Dynamic transition fills connecting sections.
enum TransitionFill {
  none,
  snareBuild,
  crashDrop,
  tomsCrescendo,
  silenceStop;

  static TransitionFill fromString(String str) {
    final clean = str.trim().toLowerCase();
    if (clean.contains('snare') || clean.contains('build') || clean.contains('roll')) return TransitionFill.snareBuild;
    if (clean.contains('crash') || clean.contains('drop') || clean.contains('impact')) return TransitionFill.crashDrop;
    if (clean.contains('tom')) return TransitionFill.tomsCrescendo;
    if (clean.contains('silence') || clean.contains('stop') || clean.contains('cut')) return TransitionFill.silenceStop;
    return TransitionFill.none;
  }
}

/// Blueprint specification for a single instrument track in an ensemble.
class EnsembleTrackBlueprint {
  final String trackId;
  final String name;
  final String presetId;
  final FunctionalRole role;
  final TextureType textureType;
  final int colorHex;
  final Map<String, double> defaultParams;

  const EnsembleTrackBlueprint({
    required this.trackId,
    required this.name,
    required this.presetId,
    required this.role,
    this.textureType = TextureType.sustained,
    this.colorHex = 0xFF3E82F7,
    this.defaultParams = const {},
  });

  Map<String, dynamic> toJson() => {
    'trackId': trackId,
    'name': name,
    'presetId': presetId,
    'role': role.name,
    'textureType': textureType.name,
    'colorHex': colorHex,
    'defaultParams': defaultParams,
  };

  factory EnsembleTrackBlueprint.fromJson(Map<String, dynamic> json) {
    return EnsembleTrackBlueprint(
      trackId: json['trackId']?.toString() ?? 'track_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? 'Instrument',
      presetId: json['presetId']?.toString() ?? 'felt_piano',
      role: FunctionalRole.fromString(json['role']?.toString() ?? 'harmonicTexture'),
      textureType: TextureType.fromString(json['textureType']?.toString() ?? 'sustained'),
      colorHex: (json['colorHex'] as num?)?.toInt() ?? 0xFF3E82F7,
      defaultParams: (json['defaultParams'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? const {},
    );
  }
}

/// Chord definition within an ensemble section.
class EnsembleChordEvent {
  final int rootPitchClass; // 0..11
  final ChordQuality quality;
  final double barLength; // In bars (e.g. 1.0, 2.0, 4.0)

  const EnsembleChordEvent({
    required this.rootPitchClass,
    required this.quality,
    this.barLength = 2.0,
  });

  Map<String, dynamic> toJson() => {
    'rootPitchClass': rootPitchClass,
    'quality': quality.name,
    'barLength': barLength,
  };

  factory EnsembleChordEvent.fromJson(Map<String, dynamic> json) {
    final rawRoot = json['rootPitchClass'] ?? json['root'] ?? 0;
    final int root = rawRoot is num ? rawRoot.toInt() % 12 : 0;

    final qStr = (json['quality'] ?? 'major').toString().toLowerCase();
    ChordQuality q = ChordQuality.major;
    for (final val in ChordQuality.values) {
      if (val.name.toLowerCase() == qStr || val.displayName.toLowerCase() == qStr) {
        q = val;
        break;
      }
    }

    return EnsembleChordEvent(
      rootPitchClass: root,
      quality: q,
      barLength: ((json['barLength'] ?? json['duration'] ?? 2.0) as num).toDouble(),
    );
  }
}

/// Section blueprint defining timeline, chords, and per-track energy allocation.
class EnsembleSectionBlueprint {
  final String name;
  final int lengthBars;
  final List<EnsembleChordEvent> chords;
  final Map<String, double> trackEnergy; // trackId -> energy (0.0 to 1.0)
  final MelodyBehavior melodyBehavior;
  final MelodyStyle melodyStyle;
  final List<int>? melodyMotif; // Optional scale degree offsets (e.g. [0, 2, 4, 7])
  final double melodyDensity; // 0.1 to 1.0
  final TransitionFill transitionFill;

  const EnsembleSectionBlueprint({
    required this.name,
    required this.lengthBars,
    required this.chords,
    this.trackEnergy = const {},
    this.melodyBehavior = MelodyBehavior.themeA,
    this.melodyStyle = MelodyStyle.auto,
    this.melodyMotif,
    this.melodyDensity = 0.65,
    this.transitionFill = TransitionFill.none,
  });

  double getTrackEnergy(String trackId) => trackEnergy[trackId] ?? 0.8;

  Map<String, dynamic> toJson() => {
    'name': name,
    'lengthBars': lengthBars,
    'chords': chords.map((c) => c.toJson()).toList(),
    'trackEnergy': trackEnergy,
    'melodyBehavior': melodyBehavior.name,
    'melodyStyle': melodyStyle.name,
    if (melodyMotif != null) 'melodyMotif': melodyMotif,
    'melodyDensity': melodyDensity,
    'transitionFill': transitionFill.name,
  };

  factory EnsembleSectionBlueprint.fromJson(Map<String, dynamic> json) {
    final rawChords = json['chords'] as List? ?? [];
    final List<EnsembleChordEvent> parsedChords = [];
    for (final c in rawChords) {
      if (c is Map) parsedChords.add(EnsembleChordEvent.fromJson(Map<String, dynamic>.from(c)));
    }

    final rawEnergy = json['trackEnergy'] as Map? ?? {};
    final Map<String, double> parsedEnergy = {};
    for (final entry in rawEnergy.entries) {
      parsedEnergy[entry.key.toString()] = ((entry.value as num?)?.toDouble() ?? 0.8).clamp(0.0, 1.0);
    }

    final rawMotif = json['melodyMotif'];
    List<int>? parsedMotif;
    if (rawMotif is List) {
      parsedMotif = rawMotif.map((n) {
        if (n is num) return n.toInt();
        if (n is String) {
          final p = int.tryParse(n);
          if (p != null) return p;
        }
        return 0;
      }).toList();
    }

    return EnsembleSectionBlueprint(
      name: json['name']?.toString() ?? 'Section',
      lengthBars: (json['lengthBars'] as num?)?.toInt() ?? 8,
      chords: parsedChords,
      trackEnergy: parsedEnergy,
      melodyBehavior: MelodyBehavior.fromString(json['melodyBehavior']?.toString() ?? 'themeA'),
      melodyStyle: MelodyStyle.fromString(json['melodyStyle']?.toString() ?? 'auto'),
      melodyMotif: parsedMotif,
      melodyDensity: ((json['melodyDensity'] as num?)?.toDouble() ?? 0.65).clamp(0.1, 1.0),
      transitionFill: TransitionFill.fromString(json['transitionFill']?.toString() ?? 'none'),
    );
  }
}

/// Complete architectural blueprint for an ensemble composition.
class SongStructureBlueprint {
  final String? archetypeId;
  final String title;
  final double bpm;
  final String meter; // "4/4", "3/4", "6/8"
  final int rootPitchClass; // 0..11
  final String mode; // "major", "minor", "dorian", etc.
  final List<EnsembleTrackBlueprint> ensemble;
  final List<EnsembleSectionBlueprint> sections;

  const SongStructureBlueprint({
    this.archetypeId,
    required this.title,
    required this.bpm,
    this.meter = '4/4',
    required this.rootPitchClass,
    this.mode = 'minor',
    required this.ensemble,
    required this.sections,
  });

  int get totalBars => sections.fold(0, (sum, s) => sum + s.lengthBars);

  int get stepsPerBar => meter == '3/4' ? 12 : (meter == '6/8' ? 12 : 16);

  Map<String, dynamic> toJson() => {
    if (archetypeId != null) 'archetypeId': archetypeId,
    'title': title,
    'bpm': bpm,
    'meter': meter,
    'rootPitchClass': rootPitchClass,
    'mode': mode,
    'ensemble': ensemble.map((t) => t.toJson()).toList(),
    'sections': sections.map((s) => s.toJson()).toList(),
  };

  factory SongStructureBlueprint.fromJson(Map<String, dynamic> json) {
    final rawEnsemble = json['ensemble'] as List? ?? [];
    final List<EnsembleTrackBlueprint> parsedEnsemble = [];
    for (final t in rawEnsemble) {
      if (t is Map) parsedEnsemble.add(EnsembleTrackBlueprint.fromJson(Map<String, dynamic>.from(t)));
    }

    final rawSections = json['sections'] as List? ?? [];
    final List<EnsembleSectionBlueprint> parsedSections = [];
    for (final s in rawSections) {
      if (s is Map) parsedSections.add(EnsembleSectionBlueprint.fromJson(Map<String, dynamic>.from(s)));
    }

    return SongStructureBlueprint(
      archetypeId: json['archetypeId']?.toString(),
      title: json['title']?.toString() ?? 'Ensemble Piece',
      bpm: ((json['bpm'] as num?)?.toDouble() ?? 120.0).clamp(40.0, 240.0),
      meter: json['meter']?.toString() ?? '4/4',
      rootPitchClass: ((json['rootPitchClass'] as num?)?.toInt() ?? 0) % 12,
      mode: json['mode']?.toString() ?? 'minor',
      ensemble: parsedEnsemble,
      sections: parsedSections,
    );
  }
}
