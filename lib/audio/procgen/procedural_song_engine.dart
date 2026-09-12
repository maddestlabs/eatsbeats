// Pure-Dart procedural multi-track song generator for Eatsbeats.
// Generates full arrangements (Drums, Bass, Chords, Lead/Hook) mapped to
// physical Eatscript instruments including the GM Standard Drum Kit.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../eatscript/eat_script_library.dart';
import '../../eatscript/project_script_engine.dart';
import '../../models/chord_model.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import 'procedural_drum_engine.dart';
import 'procedural_piano_engine.dart';

/// Configuration definition for a genre procedural archetype.
class SongGenreConfig {
  final String id;
  final String name;
  final double defaultBpm;
  final bool defaultMinor;
  final String drumStyle;
  final double defaultSwing;
  final double defaultGhostProb;
  final double defaultFillDensity;
  final String drumPresetId;
  final Map<String, double> drumParams;
  final String bassPresetId;
  final String bassName;
  final Color bassColor;
  final Map<String, double> bassParams;
  final String chordPresetId;
  final String chordName;
  final Color chordColor;
  final Map<String, double> chordParams;
  final String leadPresetId;
  final String leadName;
  final Color leadColor;
  final Map<String, double> leadParams;
  final List<List<(int offset, ChordQuality quality, double duration)>> chordProgressions;

  const SongGenreConfig({
    required this.id,
    required this.name,
    required this.defaultBpm,
    this.defaultMinor = true,
    required this.drumStyle,
    required this.defaultSwing,
    required this.defaultGhostProb,
    required this.defaultFillDensity,
    required this.drumPresetId,
    required this.drumParams,
    required this.bassPresetId,
    required this.bassName,
    required this.bassColor,
    required this.bassParams,
    required this.chordPresetId,
    required this.chordName,
    required this.chordColor,
    required this.chordParams,
    required this.leadPresetId,
    required this.leadName,
    required this.leadColor,
    required this.leadParams,
    required this.chordProgressions,
  });
}

class ProceduralSongEngine {
  static const List<String> availableStyles = [
    'Lo-Fi Hip Hop',
    'Synthwave / Retrowave',
    'Deep House',
    'Cyberpunk Acid',
    'Neo-Soul / R&B',
    'Pop / Funk Anthem',
    'SNES 16-Bit Adventure',
  ];

  static const List<String> availableStructures = [
    'Full Arrangement (Intro-Verse-Chorus-Outro)',
    'Groove Loop (Verse-Chorus)',
    'Seamless Loop',
  ];

  /// Library of genre configurations and harmonic vocabularies.
  static final Map<String, SongGenreConfig> genres = {
    // 1. Lo-Fi Hip Hop / Chillhop
    'Lo-Fi Hip Hop': SongGenreConfig(
      id: 'lofi',
      name: 'Lo-Fi Hip Hop',
      defaultBpm: 84.0,
      defaultMinor: true,
      drumStyle: 'Hip-Hop / Boom-Bap',
      defaultSwing: 0.40,
      defaultGhostProb: 0.35,
      defaultFillDensity: 0.30,
      drumPresetId: 'gm_standard_drum_kit',
      drumParams: {
        'MasterTune': -1.0,
        'RoomLevel': 0.38,
        'KitDrive': 0.18,
        'Humanize': 0.35,
        'StrikeDrift': 0.28,
      },
      bassPresetId: 'upright_bass',
      bassName: 'Acoustic Upright Bass',
      bassColor: const Color(0xFFC49A45),
      bassParams: {
        'FingerFlesh': 0.85,
        'FingerMass': 2.6,
        'SlapClick': 0.18,
        'ActionHeight': 4.0,
        'SubWarmth': 3.5,
        'BodyWarmth': 1.4,
        'WoodTone': -2.0,
      },
      chordPresetId: 'felt_upright_piano',
      chordName: 'Felt Upright Piano',
      chordColor: const Color(0xFF7FA99B),
      chordParams: {
        'FeltThickness': 0.75,
        'HammerSoftness': 0.82,
        'MechanicsLevel': 0.35,
        'RoomSize': 0.45,
      },
      leadPresetId: 'vibraphone',
      leadName: 'Lyrical Vibraphone',
      leadColor: const Color(0xFFFFB300),
      leadParams: {
        'TremoloSpeed': 4.2,
        'TremoloDepth': 0.55,
        'MalletHardness': 0.35,
      },
      chordProgressions: [
        // Progression 1: ii9 - V13 - Imaj7 - vi7 (Classic warm jazz turnaround)
        [
          (2, ChordQuality.min9, 2.0),
          (7, ChordQuality.dom9, 2.0),
          (0, ChordQuality.maj9, 2.0),
          (9, ChordQuality.minor7, 2.0),
        ],
        // Progression 2: i9 - iv9 - bVImaj7 - V7alt (Moody melancholy lo-fi)
        [
          (0, ChordQuality.min9, 2.0),
          (5, ChordQuality.min9, 2.0),
          (8, ChordQuality.major7, 2.0),
          (7, ChordQuality.dominant7, 2.0),
        ],
        // Progression 3: i7 - bVII7 - bVImaj7 - V7
        [
          (0, ChordQuality.minor7, 2.0),
          (10, ChordQuality.dominant7, 2.0),
          (8, ChordQuality.major7, 2.0),
          (7, ChordQuality.dominant7, 2.0),
        ],
      ],
    ),

    // 2. Synthwave / Retrowave
    'Synthwave / Retrowave': SongGenreConfig(
      id: 'synthwave',
      name: 'Synthwave / Retrowave',
      defaultBpm: 124.0,
      defaultMinor: true,
      drumStyle: 'House / Disco (4-on-Floor)',
      defaultSwing: 0.04,
      defaultGhostProb: 0.15,
      defaultFillDensity: 0.45,
      drumPresetId: 'gm_standard_drum_kit',
      drumParams: {
        'MasterTune': 0.0,
        'RoomLevel': 0.45,
        'KitDrive': 0.22,
        'Humanize': 0.12,
        'StrikeDrift': 0.10,
      },
      bassPresetId: 'moog_synth_bass',
      bassName: 'Model D Sub Bass',
      bassColor: const Color(0xFF00E5FF),
      bassParams: {
        'Cutoff': 480.0,
        'Resonance': 0.60,
        'FilterEnv': 0.70,
        'Decay': 0.35,
        'AmpDecay': 0.50,
        'Drive': 1.35,
      },
      chordPresetId: 'poly_lead',
      chordName: 'Neon Poly Synth',
      chordColor: const Color(0xFFFF007F),
      chordParams: {
        'Cutoff': 3200.0,
        'Resonance': 2.2,
        'Detune': 3.5,
        'Attack': 0.08,
        'Release': 0.65,
      },
      leadPresetId: 'poly_lead',
      leadName: 'Outrun Arp Lead',
      leadColor: const Color(0xFFFF9100),
      leadParams: {
        'Cutoff': 6500.0,
        'Resonance': 3.0,
        'Detune': 2.0,
        'Attack': 0.01,
        'Release': 0.22,
      },
      chordProgressions: [
        // Progression 1: i - bVI - bIII - bVII (Quintessential 80s anthem: Am - F - C - G)
        [
          (0, ChordQuality.minor, 2.0),
          (8, ChordQuality.major, 2.0),
          (3, ChordQuality.major, 2.0),
          (10, ChordQuality.major, 2.0),
        ],
        // Progression 2: i - bVI - iv - v
        [
          (0, ChordQuality.minor, 2.0),
          (8, ChordQuality.major, 2.0),
          (5, ChordQuality.minor, 2.0),
          (7, ChordQuality.minor, 2.0),
        ],
      ],
    ),

    // 3. Deep House / Club
    'Deep House': SongGenreConfig(
      id: 'deephouse',
      name: 'Deep House',
      defaultBpm: 124.0,
      defaultMinor: true,
      drumStyle: 'House / Disco (4-on-Floor)',
      defaultSwing: 0.16,
      defaultGhostProb: 0.20,
      defaultFillDensity: 0.35,
      drumPresetId: 'gm_standard_drum_kit',
      drumParams: {
        'MasterTune': 0.0,
        'RoomLevel': 0.30,
        'KitDrive': 0.15,
        'Humanize': 0.15,
        'StrikeDrift': 0.15,
      },
      bassPresetId: 'moog_synth_bass',
      bassName: 'Deep Sub Bass',
      bassColor: const Color(0xFF00FF66),
      bassParams: {
        'Cutoff': 320.0,
        'Resonance': 0.75,
        'FilterEnv': 0.55,
        'Decay': 0.28,
        'AmpDecay': 0.60,
        'Drive': 1.20,
      },
      chordPresetId: 'rhodes_epiano',
      chordName: 'Deep House Rhodes Stabs',
      chordColor: const Color(0xFF29B6F6),
      chordParams: {
        'Drive': 1.25,
        'TremoloDepth': 0.30,
        'BellGain': 1.2,
      },
      leadPresetId: 'poly_lead',
      leadName: 'Offbeat Pluck Hook',
      leadColor: const Color(0xFFE040FB),
      leadParams: {
        'Cutoff': 4000.0,
        'Resonance': 4.5,
        'Attack': 0.005,
        'Release': 0.18,
      },
      chordProgressions: [
        // Progression 1: i7 - v7 - iv7 - bVImaj7
        [
          (0, ChordQuality.minor7, 2.0),
          (7, ChordQuality.minor7, 2.0),
          (5, ChordQuality.minor7, 2.0),
          (8, ChordQuality.major7, 2.0),
        ],
        // Progression 2: i9 - bVII7 - bVImaj7 - bVII7
        [
          (0, ChordQuality.min9, 2.0),
          (10, ChordQuality.dominant7, 2.0),
          (8, ChordQuality.major7, 2.0),
          (10, ChordQuality.dominant7, 2.0),
        ],
      ],
    ),

    // 4. Cyberpunk Acid
    'Cyberpunk Acid': SongGenreConfig(
      id: 'acid',
      name: 'Cyberpunk Acid',
      defaultBpm: 135.0,
      defaultMinor: true,
      drumStyle: 'House / Disco (4-on-Floor)',
      defaultSwing: 0.0,
      defaultGhostProb: 0.20,
      defaultFillDensity: 0.40,
      drumPresetId: 'gm_standard_drum_kit',
      drumParams: {
        'MasterTune': 0.0,
        'RoomLevel': 0.25,
        'KitDrive': 0.35,
        'Humanize': 0.10,
        'StrikeDrift': 0.10,
      },
      bassPresetId: 'eats_303',
      bassName: 'Eats-303 Acid Bass',
      bassColor: const Color(0xFF00FFCC),
      bassParams: {
        'Waveform': 0.0, // Sawtooth
        'Cutoff': 1650.0,
        'Resonance': 9.8,
        'EnvMod': 0.85,
        'Decay': 0.32,
        'Accent': 0.85,
        'Drive': 0.55,
      },
      chordPresetId: 'poly_lead',
      chordName: 'Industrial Power Stabs',
      chordColor: const Color(0xFFFF2A6D),
      chordParams: {
        'Cutoff': 4500.0,
        'Resonance': 3.5,
        'Detune': 4.5,
        'Attack': 0.01,
        'Release': 0.40,
      },
      leadPresetId: 'poly_lead',
      leadName: 'Cyber Arp Hook',
      leadColor: const Color(0xFF05D9E8),
      leadParams: {
        'Cutoff': 7200.0,
        'Resonance': 2.8,
        'Detune': 1.8,
        'Attack': 0.005,
        'Release': 0.15,
      },
      chordProgressions: [
        // Progression 1: i - bII - i - bVII (Dark Phrygian industrial)
        [
          (0, ChordQuality.minor, 2.0),
          (1, ChordQuality.major, 2.0),
          (0, ChordQuality.minor, 2.0),
          (10, ChordQuality.major, 2.0),
        ],
        // Progression 2: i - iv - bVI - V
        [
          (0, ChordQuality.minor, 2.0),
          (5, ChordQuality.minor, 2.0),
          (8, ChordQuality.major, 2.0),
          (7, ChordQuality.dominant7, 2.0),
        ],
      ],
    ),

    // 5. Neo-Soul / R&B
    'Neo-Soul / R&B': SongGenreConfig(
      id: 'neosoul',
      name: 'Neo-Soul / R&B',
      defaultBpm: 90.0,
      defaultMinor: false,
      drumStyle: 'Funk / Breakbeat',
      defaultSwing: 0.38,
      defaultGhostProb: 0.40,
      defaultFillDensity: 0.35,
      drumPresetId: 'gm_standard_drum_kit',
      drumParams: {
        'MasterTune': 0.0,
        'RoomLevel': 0.35,
        'KitDrive': 0.12,
        'Humanize': 0.30,
        'StrikeDrift': 0.22,
      },
      bassPresetId: 'fretless_bass',
      bassName: 'Fretless J-Bass',
      bassColor: const Color(0xFFFF6D00),
      bassParams: {
        'MwahAmount': 0.78,
        'Growl': 0.65,
        'FingerDamping': 0.25,
        'BridgePickup': 0.88,
        'MidBark': 3.5,
        'Drive': 1.15,
      },
      chordPresetId: 'rhodes_epiano',
      chordName: 'Fender Rhodes Mark I',
      chordColor: const Color(0xFFD4AF37),
      chordParams: {
        'Drive': 1.10,
        'TremoloDepth': 0.40,
        'BellGain': 1.4,
      },
      leadPresetId: 'concert_flute',
      leadName: 'Lyrical Concert Flute',
      leadColor: const Color(0xFF81C784),
      leadParams: {
        'BreathPressure': 1.15,
        'ChiffAttack': 0.55,
        'VibratoDepth': 0.35,
        'VibratoRate': 6.5,
      },
      chordProgressions: [
        // Progression 1: ii9 - V13 - Imaj9 - VI7alt (Neo-soul 2-5-1-6)
        [
          (2, ChordQuality.min9, 2.0),
          (7, ChordQuality.dom9, 2.0),
          (0, ChordQuality.maj9, 2.0),
          (9, ChordQuality.dominant7, 2.0),
        ],
        // Progression 2: IVmaj9 - iii7 - vi9 - I7 (Silk soul groove)
        [
          (5, ChordQuality.maj9, 2.0),
          (4, ChordQuality.minor7, 2.0),
          (9, ChordQuality.min9, 2.0),
          (0, ChordQuality.dominant7, 2.0),
        ],
      ],
    ),

    // 6. Pop / Funk Anthem
    'Pop / Funk Anthem': const SongGenreConfig(
      id: 'popfunk',
      name: 'Pop / Funk Anthem',
      defaultBpm: 116.0,
      defaultMinor: false,
      drumStyle: 'Funk / Breakbeat',
      defaultSwing: 0.18,
      defaultGhostProb: 0.30,
      defaultFillDensity: 0.40,
      drumPresetId: 'gm_standard_drum_kit',
      drumParams: {
        'MasterTune': 0.0,
        'RoomLevel': 0.40,
        'KitDrive': 0.20,
        'Humanize': 0.20,
        'StrikeDrift': 0.15,
      },
      bassPresetId: 'fretless_bass',
      bassName: 'Funky Electric Bass',
      bassColor: const Color(0xFFFF5252),
      bassParams: {
        'MwahAmount': 0.50,
        'Growl': 0.80,
        'FingerDamping': 0.15,
        'BridgePickup': 0.95,
        'Drive': 1.30,
      },
      chordPresetId: 'concert_grand_piano',
      chordName: 'Concert Grand Piano',
      chordColor: const Color(0xFF64B5F6),
      chordParams: {
        'HammerHardness': 0.70,
        'LidOpen': 0.85,
        'DamperReso': 0.40,
      },
      leadPresetId: 'poly_lead',
      leadName: 'Anthem Brass Synth',
      leadColor: const Color(0xFFFFD600),
      leadParams: {
        'Cutoff': 5000.0,
        'Resonance': 2.2,
        'Detune': 3.0,
        'Attack': 0.02,
        'Release': 0.30,
      },
      chordProgressions: [
        // Progression 1: I - V - vi - IV (Universal Pop Anthem)
        [
          (0, ChordQuality.major, 2.0),
          (7, ChordQuality.major, 2.0),
          (9, ChordQuality.minor, 2.0),
          (5, ChordQuality.major, 2.0),
        ],
        // Progression 2: i - bVII - bVI - V7 (Funk minor walkdown)
        [
          (0, ChordQuality.minor, 2.0),
          (10, ChordQuality.major, 2.0),
          (8, ChordQuality.major, 2.0),
          (7, ChordQuality.dominant7, 2.0),
        ],
      ],
    ),

    // 7. SNES 16-Bit Adventure
    'SNES 16-Bit Adventure': const SongGenreConfig(
      id: 'snes_adventure',
      name: 'SNES 16-Bit Adventure',
      defaultBpm: 134.0,
      defaultMinor: false,
      drumStyle: '16-Bit Console Action',
      defaultSwing: 0.05,
      defaultGhostProb: 0.22,
      defaultFillDensity: 0.45,
      drumPresetId: 'snes_drum_kit',
      drumParams: {
        'MasterTune': 0.0,
        'KickPunch': 140.0,
        'SnareNoise': 0.65,
        'TomDecay': 0.35,
        'CymbalDecay': 0.80,
        'GaussianWarmth': 0.75,
        'EchoDelay': 128.0,
        'EchoFeedback': 0.35,
        'EchoVolume': 0.25,
      },
      bassPresetId: 'snes_console_synth',
      bassName: 'SNES Slap Bass',
      bassColor: const Color(0xFFE52521),
      bassParams: {
        'Waveform': 9.0, // Slap Bass
        'Attack': 0.002,
        'Decay': 0.28,
        'Sustain': 0.25,
        'Release': 0.15,
        'EchoVolume': 0.0,
      },
      chordPresetId: 'snes_console_synth',
      chordName: 'SNES Strings Pad',
      chordColor: const Color(0xFF6C5CE7),
      chordParams: {
        'Waveform': 7.0, // Strings
        'Attack': 0.04,
        'Decay': 0.45,
        'Sustain': 0.75,
        'Release': 0.35,
        'EchoDelay': 160.0,
        'EchoFeedback': 0.55,
        'EchoVolume': 0.45,
      },
      leadPresetId: 'snes_console_synth',
      leadName: 'SNES Hero Lead',
      leadColor: const Color(0xFF00CEC9),
      leadParams: {
        'Waveform': 8.0, // Flute
        'Attack': 0.005,
        'Decay': 0.35,
        'Sustain': 0.60,
        'Release': 0.20,
        'VibratoRate': 6.0,
        'VibratoDepth': 0.15,
        'EchoDelay': 128.0,
        'EchoFeedback': 0.40,
        'EchoVolume': 0.35,
      },
      chordProgressions: [
        // Progression 1: I - V - vi - IV (Chrono / Mana Overworld Hero Theme)
        [
          (0, ChordQuality.major, 2.0),
          (7, ChordQuality.major, 2.0),
          (9, ChordQuality.minor, 2.0),
          (5, ChordQuality.major, 2.0),
        ],
        // Progression 2: ii7 - V7 - Imaj7 - vi7 (JRPG Town / Peaceful Journey)
        [
          (2, ChordQuality.minor7, 2.0),
          (7, ChordQuality.dominant7, 2.0),
          (0, ChordQuality.major7, 2.0),
          (9, ChordQuality.minor7, 2.0),
        ],
        // Progression 3: i - bVII - bVI - bVII (Action Stage / Dungeon Tension)
        [
          (0, ChordQuality.minor, 2.0),
          (10, ChordQuality.major, 2.0),
          (8, ChordQuality.major, 2.0),
          (10, ChordQuality.major, 2.0),
        ],
        // Progression 4: i - IV - i - IV (Dorian Forest / Mystic Cavern)
        [
          (0, ChordQuality.minor, 2.0),
          (5, ChordQuality.major, 2.0),
          (0, ChordQuality.minor, 2.0),
          (5, ChordQuality.major, 2.0),
        ],
      ],
    ),
  };

  /// Main execution method for generating a song into [DawState].
  static ProjectScriptResult generateToDawState(
    DawState dawState,
    Map<String, dynamic> params,
  ) {
    // 1. Resolve Style
    final rawStyle = params['Style'] ?? params['style'];
    final String styleStr = rawStyle is num
        ? (rawStyle.toInt() >= 0 && rawStyle.toInt() < availableStyles.length
            ? availableStyles[rawStyle.toInt()]
            : 'Lo-Fi Hip Hop')
        : (rawStyle?.toString() ?? 'Lo-Fi Hip Hop');

    final config = genres[styleStr] ?? genres['Lo-Fi Hip Hop']!;

    // 2. Resolve Seed & PRNG
    final int seed = ((params['Seed'] ?? params['seed'] ?? 42) as num).toInt();
    final rng = Mulberry32Rng(seed);

    // 3. Resolve Length Bars & Structure
    final rawBars = ((params['Bars'] ?? params['bars'] ?? 16) as num).toInt();
    final int numBars = [4, 8, 16, 24, 32].contains(rawBars) ? rawBars : 16;

    final rawStructure = params['Structure'] ?? params['structure'];
    final String structureStr = rawStructure is num
        ? (rawStructure.toInt() >= 0 && rawStructure.toInt() < availableStructures.length
            ? availableStructures[rawStructure.toInt()]
            : availableStructures[0])
        : (rawStructure?.toString() ?? availableStructures[0]);

    // 4. Resolve Tempo
    final userBpm = params['Bpm'] ?? params['bpm'];
    final double bpm = userBpm != null ? (userBpm as num).toDouble() : config.defaultBpm;

    // 5. Resolve Root Key & Scale
    final rawRoot = params['Root'] ?? params['root'];
    int rootPitchClass;
    if (rawRoot == null || rawRoot == 0 || rawRoot == 'Auto / Key' || rawRoot == 'Auto') {
      // Pick a favorable root key deterministically from seed
      final candidateRoots = config.id == 'lofi'
          ? [0, 2, 5, 7, 9] // C, D, F, G, A
          : (config.id == 'synthwave'
              ? [9, 2, 0, 4]
              : (config.id == 'snes_adventure'
                  ? [0, 5, 7, 2, 9] // C, F, G, D, A
                  : [0, 2, 3, 5, 7, 9, 10]));
      rootPitchClass = candidateRoots[rng.pick([0, 1, 2, 3, 4].sublist(0, math.min(5, candidateRoots.length)))];
    } else if (rawRoot is num) {
      rootPitchClass = (rawRoot.toInt() - 1).clamp(0, 11);
    } else {
      const rootNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
      final idx = rootNames.indexOf(rawRoot.toString());
      rootPitchClass = idx >= 0 ? idx : 0;
    }

    final bool isMinor = config.defaultMinor;
    final rootName = ChordTheory.pitchClassNames[rootPitchClass];
    final modeName = isMinor ? 'Minor' : 'Major';

    // 6. Update DAW Global Transport & Key
    dawState.setBpm(bpm);
    dawState.projectName = '${config.name} (Seed #$seed)';
    dawState.setSongKey('$rootName $modeName');

    // 7. Generate Harmonic Chord Progression
    final progressionFormula = rng.pick(config.chordProgressions);
    final List<ChordEvent> chordEvents = [];
    int curBar = 0;
    int formIdx = 0;
    while (curBar < numBars) {
      final item = progressionFormula[formIdx % progressionFormula.length];
      final chRoot = (rootPitchClass + item.$1) % 12;
      final dur = math.min(item.$3, (numBars - curBar).toDouble());
      chordEvents.add(ChordEvent(
        id: 'chord_proc_${curBar}_$seed',
        startBar: curBar,
        barLength: dur,
        rootPitchClass: chRoot,
        quality: item.$2,
      ));
      curBar += dur.toInt();
      formIdx++;
    }
    dawState.chordTrack = chordEvents;

    // 8. Define Section Plan
    // (Intro, Verse, Chorus/Peak, Outro)
    final List<_Section> sections = _buildSectionPlan(numBars, structureStr);

    // 9. Clear and Prep Pattern
    final pattern = dawState.activePattern;
    pattern.tracks.clear();
    pattern.lengthSteps = numBars * 16;

    // 10. Generate Track 1: Drums (GM Standard Drum Kit)
    final drumTrack = _buildDrumTrack(
      config: config,
      bars: numBars,
      sections: sections,
      seed: seed,
      params: params,
    );
    pattern.tracks.add(drumTrack);

    // 11. Generate Track 2: Bassline
    final bassTrack = _buildBassTrack(
      config: config,
      bars: numBars,
      sections: sections,
      chords: chordEvents,
      rootPitchClass: rootPitchClass,
      seed: seed + 101,
      params: params,
    );
    pattern.tracks.add(bassTrack);

    // 12. Generate Track 3: Chords / Harmonic Accompaniment
    final chordTrack = _buildChordTrack(
      config: config,
      bars: numBars,
      sections: sections,
      chords: chordEvents,
      seed: seed + 202,
      params: params,
    );
    pattern.tracks.add(chordTrack);

    // 13. Generate Track 4: Lead / Hook Melody
    final leadTrack = _buildLeadTrack(
      config: config,
      bars: numBars,
      sections: sections,
      chords: chordEvents,
      rootPitchClass: rootPitchClass,
      isMinor: isMinor,
      seed: seed + 303,
      params: params,
    );
    pattern.tracks.add(leadTrack);

    // 14. Loop Points: Automatically loop from 0 to end of song!
    dawState.setLoopPoints(0, numBars);
    dawState.setLooping(true);
    dawState.isSongMode = true;

    // Count totals
    int totalNotes = 0;
    for (final t in pattern.tracks) {
      for (final c in t.clips) {
        totalNotes += c.notes.length;
      }
    }

    dawState.triggerAutoSave();
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    dawState.notifyListeners();

    return ProjectScriptResult(
      isSuccess: true,
      message: 'Generated $numBars-bar "${config.name}" (Seed: $seed, $bpm BPM, $rootName $modeName) across 4 tracks with $totalNotes notes!',
      affectedTracksCount: pattern.tracks.length,
      affectedNotesCount: totalNotes,
      affectedChordsCount: chordEvents.length,
    );
  }

  /// Generates a default procedural demo song into [DawState], replacing static project files.
  static ProjectScriptResult generateDefaultDemo(
    DawState dawState, {
    String style = 'Lo-Fi Hip Hop',
    int seed = 42,
  }) {
    return generateToDawState(dawState, {
      'Style': style,
      'Bars': 16,
      'Seed': seed,
      'Structure': 'Full Arrangement (Intro-Verse-Chorus-Outro)',
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SECTION ARCHITECTURE
  // ─────────────────────────────────────────────────────────────────────────

  static List<_Section> _buildSectionPlan(int totalBars, String structure) {
    if (structure.contains('Seamless') || totalBars <= 4) {
      return [_Section(name: 'Main Groove', startBar: 0, lengthBars: totalBars, type: _SectionType.verse)];
    }

    if (structure.contains('Groove Loop') || totalBars <= 8) {
      final half = totalBars ~/ 2;
      return [
        _Section(name: 'Verse', startBar: 0, lengthBars: half, type: _SectionType.verse),
        _Section(name: 'Chorus', startBar: half, lengthBars: totalBars - half, type: _SectionType.chorus),
      ];
    }

    // Full Arrangement
    if (totalBars == 16) {
      return const [
        _Section(name: 'Intro', startBar: 0, lengthBars: 4, type: _SectionType.intro),
        _Section(name: 'Verse', startBar: 4, lengthBars: 6, type: _SectionType.verse),
        _Section(name: 'Chorus', startBar: 10, lengthBars: 4, type: _SectionType.chorus),
        _Section(name: 'Outro', startBar: 14, lengthBars: 2, type: _SectionType.outro),
      ];
    }

    if (totalBars == 24) {
      return const [
        _Section(name: 'Intro', startBar: 0, lengthBars: 4, type: _SectionType.intro),
        _Section(name: 'Verse 1', startBar: 4, lengthBars: 8, type: _SectionType.verse),
        _Section(name: 'Chorus', startBar: 12, lengthBars: 8, type: _SectionType.chorus),
        _Section(name: 'Outro', startBar: 20, lengthBars: 4, type: _SectionType.outro),
      ];
    }

    // 32 bars
    return const [
      _Section(name: 'Intro', startBar: 0, lengthBars: 4, type: _SectionType.intro),
      _Section(name: 'Verse 1', startBar: 4, lengthBars: 8, type: _SectionType.verse),
      _Section(name: 'Chorus 1', startBar: 12, lengthBars: 8, type: _SectionType.chorus),
      _Section(name: 'Breakdown / Verse 2', startBar: 20, lengthBars: 8, type: _SectionType.verse),
      _Section(name: 'Chorus 2 / Outro', startBar: 28, lengthBars: 4, type: _SectionType.outro),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TRACK BUILDERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Track 1: Drums mapped to GM Standard Drum Kit
  static TrackChannel _buildDrumTrack({
    required SongGenreConfig config,
    required int bars,
    required List<_Section> sections,
    required int seed,
    required Map<String, dynamic> params,
  }) {
    final drumPreset = EatScriptLibrary.getPresetById(config.drumPresetId);
    final String drumCode = drumPreset?.code ?? '';

    final swing = ((params['Swing'] as num?)?.toDouble() ?? config.defaultSwing).clamp(0.0, 1.0);
    final humanize = ((params['Humanize'] as num?)?.toDouble() ?? 0.25).clamp(0.0, 1.0);

    final track = TrackChannel(
      id: 'proc_track_drums',
      name: config.drumPresetId == 'snes_drum_kit' ? 'SNES Drum Kit' : 'Drums (GM Standard Kit)',
      color: config.drumPresetId == 'snes_drum_kit' ? const Color(0xFFE52521) : const Color(0xFFFF4081),
      type: TrackType.eatScript,
      volume: 0.90,
      pan: 0.0,
      luaScriptCode: drumCode,
      luaParams: {
        ...config.drumParams,
        'Swing': swing,
        'Humanize': humanize,
      },
    );

    // Generate drum notes section by section
    final List<Note> allNotes = [];

    for (final section in sections) {
      final sectionRng = Mulberry32Rng(seed + section.startBar * 13);
      final List<Note> sectionNotes = [];

      final bool isIntro = section.type == _SectionType.intro;
      final bool isOutro = section.type == _SectionType.outro;
      final bool isChorus = section.type == _SectionType.chorus;

      // Base pattern generation using ProceduralDrumEngine
      final rawNotes = ProceduralDrumEngine.generatePattern(
        style: config.drumStyle,
        bars: section.lengthBars,
        density: isIntro ? 0.35 : (isChorus ? 0.90 : 0.70),
        swing: swing,
        ghostProb: isIntro ? 0.10 : config.defaultGhostProb,
        fillDensity: isIntro ? 0.0 : (isChorus ? 0.50 : config.defaultFillDensity),
        humanize: humanize,
        seed: seed + section.startBar * 17,
      );

      // Filter notes according to section energy:
      // Intro: Soft hats/percussion, no heavy kick/snare to build tension
      // Outro: Diminishing energy, ride/crash decay
      for (final note in rawNotes) {
        if (isIntro) {
          // In intro, drop heavy kicks and loud snares
          if (note.pitch == 35 || note.pitch == 36 || note.pitch == 38) {
            // Replace snare with quiet side stick or shaker
            if (note.pitch == 38 && sectionRng.chance(0.6)) {
              sectionNotes.add(note.copyWith(
                pitch: 37, // Side Stick
                velocity: 0.45,
              ));
            }
            continue;
          }
        }

        if (isOutro && note.startStep > (section.lengthBars * 16 - 8)) {
          // Taper off at very end
          if (note.pitch == 35 || note.pitch == 36 || note.pitch == 38) continue;
        }

        // Chorus boost: Add ride cymbal (51) / open hat accents
        if (isChorus && note.pitch == 42 && sectionRng.chance(0.35)) {
          sectionNotes.add(note.copyWith(
            pitch: 51, // Ride Cymbal 1
            velocity: 0.75,
          ));
        }

        sectionNotes.add(note);
      }

      // Shift note start steps to section offset on the timeline
      final double startStepOffset = section.startBar * 16.0;
      final List<Note> timelineNotes = sectionNotes.map((n) {
        return n.copyWith(
          id: 'drum_${section.name}_${n.id}',
          startStep: n.startStep + startStepOffset,
        );
      }).toList();

      final clip = TrackClip(
        id: 'clip_drums_${section.name}_${section.startBar}',
        name: '${section.name} (Drums)',
        trackId: track.id,
        startBar: section.startBar,
        barLength: section.lengthBars,
        notes: sectionNotes.map((n) => n.copyWith(id: 'drum_${section.name}_${n.id}')).toList(),
      );
      track.clips.add(clip);
      allNotes.addAll(timelineNotes);
    }

    track.notes = allNotes.map((n) => n.copyWith()).toList();
    return track;
  }

  /// Track 2: Bassline
  static TrackChannel _buildBassTrack({
    required SongGenreConfig config,
    required int bars,
    required List<_Section> sections,
    required List<ChordEvent> chords,
    required int rootPitchClass,
    required int seed,
    required Map<String, dynamic> params,
  }) {
    final bassPreset = EatScriptLibrary.getPresetById(config.bassPresetId);
    final String bassCode = bassPreset?.code ?? '';

    final track = TrackChannel(
      id: 'proc_track_bass',
      name: config.bassName,
      color: config.bassColor,
      type: TrackType.eatScript,
      volume: 0.85,
      pan: 0.0,
      luaScriptCode: bassCode,
      luaParams: Map<String, double>.from(config.bassParams),
    );

    final rng = Mulberry32Rng(seed);
    final List<Note> allNotes = [];

    for (final section in sections) {
      final List<Note> sectionNotes = [];
      final int startBar = section.startBar;
      final int endBar = section.startBar + section.lengthBars;

      // Section behavior:
      // Intro: Bass is silent or soft pedal drone on root
      // Verse: Classic genre groove
      // Chorus: Driving high-energy variation
      // Outro: Sustained root resolution
      if (section.type == _SectionType.intro) {
        // Optional subtle root swell on bar 2..3
        if (section.lengthBars >= 4) {
          final ch = _getChordAtBar(chords, startBar + 2);
          final r = ch?.rootPitchClass ?? rootPitchClass;
          final bassPitch = 36 + r; // C2 (36)
          sectionNotes.add(Note(
            id: 'bass_intro_drone',
            pitch: bassPitch,
            startStep: 2 * 16.0,
            durationSteps: 30.0,
            velocity: 0.60,
          ));
        }
      } else {
        for (int bar = startBar; bar < endBar; bar++) {
          final chord = _getChordAtBar(chords, bar);
          final chRoot = chord?.bassPitchClass ?? chord?.rootPitchClass ?? rootPitchClass;
          final bassRoot = 36 + chRoot; // C2 (36) + root
          final int barInClip = bar - startBar;
          final double barStartStep = barInClip * 16.0;

          if (config.id == 'lofi') {
            // Lo-Fi Hip Hop: Laid-back swung walking bassline
            // Beat 1 (step 0): Deep root note
            sectionNotes.add(Note(
              id: 'bass_lofi_${bar}_0',
              pitch: bassRoot,
              startStep: barStartStep + 0.0,
              durationSteps: 3.5,
              velocity: 0.88,
            ));

            // Beat 2.5 (step 6): Soft ghost octave or 5th
            if (rng.chance(0.7)) {
              final fifth = bassRoot + 7;
              sectionNotes.add(Note(
                id: 'bass_lofi_${bar}_6',
                pitch: rng.chance(0.5) ? fifth : bassRoot + 12,
                startStep: barStartStep + 6.0,
                durationSteps: 1.8,
                velocity: 0.70,
              ));
            }

            // Beat 3.5 (step 10): Passing tone / root bounce
            sectionNotes.add(Note(
              id: 'bass_lofi_${bar}_10',
              pitch: bassRoot,
              startStep: barStartStep + 10.0,
              durationSteps: 2.5,
              velocity: 0.82,
            ));

            // Beat 4.5 (step 14): Walking approach tone to next bar
            if (rng.chance(0.65)) {
              final nextCh = _getChordAtBar(chords, bar + 1);
              final nextRoot = 36 + (nextCh?.rootPitchClass ?? rootPitchClass);
              final approach = nextRoot > bassRoot ? nextRoot - 1 : nextRoot + 1;
              sectionNotes.add(Note(
                id: 'bass_lofi_${bar}_14',
                pitch: approach.clamp(28, 55),
                startStep: barStartStep + 14.0,
                durationSteps: 1.8,
                velocity: 0.68,
              ));
            }
          } else if (config.id == 'synthwave') {
            // Synthwave: Driving rolling 16ths with octave bounce
            for (int s = 0; s < 16; s += 2) {
              final isOctave = (s % 4) == 2;
              final isAccent = (s % 8) == 0;
              sectionNotes.add(Note(
                id: 'bass_sw_${bar}_$s',
                pitch: isOctave ? bassRoot + 12 : bassRoot,
                startStep: barStartStep + s,
                durationSteps: 1.6,
                velocity: isAccent ? 0.95 : 0.75,
              ));
            }
          } else if (config.id == 'acid') {
            // Cyberpunk Acid: TB-303 running syncopated pattern with slides and accents
            final patternOffsets = [0, 0, 12, 0, 7, 0, 10, 12];
            for (int i = 0; i < 8; i++) {
              final step = i * 2;
              final offset = patternOffsets[i];
              final isSlide = (i == 3 || i == 7);
              final isAccent = (i == 0 || i == 6);
              sectionNotes.add(Note(
                id: 'bass_acid_${bar}_$step',
                pitch: bassRoot + offset,
                startStep: barStartStep + step,
                durationSteps: isSlide ? 2.2 : 1.4,
                velocity: isAccent ? 0.98 : 0.72,
                isSlide: isSlide,
                isAccent: isAccent,
              ));
            }
          } else if (config.id == 'deephouse') {
            // Deep House: Syncopated offbeat sub groove (steps 0, 3, 6, 10, 12)
            final houseSteps = [0, 3, 6, 10, 12];
            for (final s in houseSteps) {
              sectionNotes.add(Note(
                id: 'bass_house_${bar}_$s',
                pitch: bassRoot,
                startStep: barStartStep + s,
                durationSteps: 1.8,
                velocity: s == 0 ? 0.95 : 0.80,
              ));
            }
          } else if (config.id == 'snes_adventure') {
            // SNES 16-Bit Slap Bass: Driving syncopated root, 5th, and octave slap pops
            sectionNotes.add(Note(
              id: 'bass_snes_${bar}_0',
              pitch: bassRoot,
              startStep: barStartStep + 0.0,
              durationSteps: 2.5,
              velocity: 0.95,
            ));
            // Step 4: Staccato Octave Slap Pop
            sectionNotes.add(Note(
              id: 'bass_snes_${bar}_4',
              pitch: bassRoot + 12,
              startStep: barStartStep + 4.0,
              durationSteps: 1.5,
              velocity: 0.88,
            ));
            // Step 6: Fifth bounce
            sectionNotes.add(Note(
              id: 'bass_snes_${bar}_6',
              pitch: bassRoot + 7,
              startStep: barStartStep + 6.0,
              durationSteps: 1.5,
              velocity: 0.82,
            ));
            // Step 8: Mid-bar root
            sectionNotes.add(Note(
              id: 'bass_snes_${bar}_8',
              pitch: bassRoot,
              startStep: barStartStep + 8.0,
              durationSteps: 2.0,
              velocity: 0.90,
            ));
            // Step 12: High octave pop or 7th
            sectionNotes.add(Note(
              id: 'bass_snes_${bar}_12',
              pitch: rng.chance(0.6) ? bassRoot + 12 : bassRoot + 10,
              startStep: barStartStep + 12.0,
              durationSteps: 1.5,
              velocity: 0.85,
            ));
            // Step 14: Chromatic walking approach to next bar
            if (rng.chance(0.7)) {
              final nextCh = _getChordAtBar(chords, bar + 1);
              final nextRoot = 36 + (nextCh?.rootPitchClass ?? rootPitchClass);
              final approach = nextRoot > bassRoot ? nextRoot - 1 : nextRoot + 1;
              sectionNotes.add(Note(
                id: 'bass_snes_${bar}_14',
                pitch: approach.clamp(28, 55),
                startStep: barStartStep + 14.0,
                durationSteps: 1.8,
                velocity: 0.75,
              ));
            }
          } else {
            // Neo-Soul / Pop: Syncopated groove with 5th and octave
            final steps = [0, 4, 7, 10, 12];
            for (final s in steps) {
              final p = s == 7 ? bassRoot + 7 : (s == 12 ? bassRoot + 12 : bassRoot);
              sectionNotes.add(Note(
                id: 'bass_funk_${bar}_$s',
                pitch: p,
                startStep: barStartStep + s,
                durationSteps: 2.0,
                velocity: s == 0 ? 0.95 : 0.78,
              ));
            }
          }
        }
      }

      final double startStepOffset = section.startBar * 16.0;
      final List<Note> timelineNotes = sectionNotes.map((n) {
        return n.copyWith(
          startStep: n.startStep + startStepOffset,
        );
      }).toList();

      final clip = TrackClip(
        id: 'clip_bass_${section.name}_${section.startBar}',
        name: '${section.name} (Bass)',
        trackId: track.id,
        startBar: section.startBar,
        barLength: section.lengthBars,
        notes: sectionNotes.map((n) => n.copyWith()).toList(),
      );
      track.clips.add(clip);
      allNotes.addAll(timelineNotes);
    }

    track.notes = allNotes.map((n) => n.copyWith()).toList();
    return track;
  }

  /// Track 3: Chords / Harmonic Accompaniment (e.g. Felt Piano / Rhodes)
  static TrackChannel _buildChordTrack({
    required SongGenreConfig config,
    required int bars,
    required List<_Section> sections,
    required List<ChordEvent> chords,
    required int seed,
    required Map<String, dynamic> params,
  }) {
    final chordPreset = EatScriptLibrary.getPresetById(config.chordPresetId);
    final String chordCode = chordPreset?.code ?? '';

    final track = TrackChannel(
      id: 'proc_track_chords',
      name: config.chordName,
      color: config.chordColor,
      type: TrackType.eatScript,
      volume: 0.82,
      pan: -0.15,
      luaScriptCode: chordCode,
      luaParams: Map<String, double>.from(config.chordParams),
    );

    final rng = Mulberry32Rng(seed);
    final List<Note> allNotes = [];

    for (final section in sections) {
      final List<Note> sectionNotes = [];
      final int startBar = section.startBar;
      final int endBar = section.startBar + section.lengthBars;

      for (int bar = startBar; bar < endBar; bar += 2) {
        final chord = _getChordAtBar(chords, bar) ?? chords.first;
        final pitches = chord.pitchClasses;
        final int barInClip = bar - startBar;
        final double barStartStep = barInClip * 16.0;

        // Construct 4-note voicing in mid-register (C3..C5 / 48..72)
        final voicing = <int>[];
        for (int i = 0; i < pitches.length; i++) {
          final p = pitches[i];
          final octave = (i == 0) ? 48 : (i <= 2 ? 60 : 72);
          voicing.add(octave + p);
        }

        // Voice leading: Keep span compact
        voicing.sort();

        if (config.id == 'lofi') {
          // Lo-Fi Hip Hop: Gentle syncopated strums on Felt Piano / Rhodes
          // Hit 1: Beat 1 (or slight delayed rubato offset)
          final rubato = rng.rand(-0.04, 0.04);
          for (int vi = 0; vi < voicing.length; vi++) {
            // Humanize strum spread (10-20ms per note)
            final strumOffset = vi * 0.035;
            sectionNotes.add(Note(
              id: 'chord_lofi_${bar}_${vi}_1',
              pitch: voicing[vi],
              startStep: barStartStep + strumOffset + rubato,
              durationSteps: 14.5,
              velocity: 0.72 - (vi * 0.03) + rng.rand(-0.04, 0.04),
            ));
          }

          // Hit 2: Syncopated push on bar + 1 (step 10 or 12)
          if (section.type != _SectionType.intro && rng.chance(0.75)) {
            final pushStep = barStartStep + 16.0 + (rng.chance(0.5) ? 10.0 : 12.0);
            for (int vi = 0; vi < voicing.length; vi++) {
              sectionNotes.add(Note(
                id: 'chord_lofi_${bar}_${vi}_2',
                pitch: voicing[vi],
                startStep: pushStep + (vi * 0.025),
                durationSteps: 18.0,
                velocity: 0.68 + rng.rand(-0.03, 0.03),
              ));
            }
          }
        } else if (config.id == 'synthwave') {
          // Synthwave: Lush sustained pads spanning 2 bars
          for (int vi = 0; vi < voicing.length; vi++) {
            sectionNotes.add(Note(
              id: 'chord_sw_${bar}_$vi',
              pitch: voicing[vi],
              startStep: barStartStep,
              durationSteps: 31.0,
              velocity: 0.78,
            ));
          }
        } else if (config.id == 'deephouse') {
          // Deep House: Punchy syncopated stabs on offbeats (e.g. 2, 6, 11, 14)
          final stabSteps = [2.0, 6.0, 11.0, 14.0];
          for (final s in stabSteps) {
            for (int vi = 0; vi < voicing.length; vi++) {
              sectionNotes.add(Note(
                id: 'chord_dh_${bar}_${s.toInt()}_$vi',
                pitch: voicing[vi],
                startStep: barStartStep + s,
                durationSteps: 1.5,
                velocity: 0.82,
              ));
            }
          }
        } else if (config.id == 'snes_adventure') {
          // SNES 16-Bit Strings Pad: 2-3 voice smooth chord pads with FIR hall echo
          const double chordDur = 31.0;
          for (int vi = 0; vi < math.min(3, voicing.length); vi++) {
            sectionNotes.add(Note(
              id: 'chord_snes_${bar}_$vi',
              pitch: voicing[vi],
              startStep: barStartStep + (vi * 0.02),
              durationSteps: chordDur,
              velocity: 0.72,
            ));
          }
        } else {
          // Default sustained comping
          for (int vi = 0; vi < voicing.length; vi++) {
            sectionNotes.add(Note(
              id: 'chord_def_${bar}_$vi',
              pitch: voicing[vi],
              startStep: barStartStep,
              durationSteps: 28.0,
              velocity: 0.75,
            ));
          }
        }
      }

      final double startStepOffset = section.startBar * 16.0;
      final List<Note> timelineNotes = sectionNotes.map((n) {
        return n.copyWith(
          startStep: n.startStep + startStepOffset,
        );
      }).toList();

      final clip = TrackClip(
        id: 'clip_chords_${section.name}_${section.startBar}',
        name: '${section.name} (Chords)',
        trackId: track.id,
        startBar: section.startBar,
        barLength: section.lengthBars,
        notes: sectionNotes.map((n) => n.copyWith()).toList(),
      );
      track.clips.add(clip);
      allNotes.addAll(timelineNotes);
    }

    track.notes = allNotes.map((n) => n.copyWith()).toList();
    return track;
  }

  /// Track 4: Lead / Hook Melody (e.g. Vibraphone, Flute, or Poly Synth Arp)
  static TrackChannel _buildLeadTrack({
    required SongGenreConfig config,
    required int bars,
    required List<_Section> sections,
    required List<ChordEvent> chords,
    required int rootPitchClass,
    required bool isMinor,
    required int seed,
    required Map<String, dynamic> params,
  }) {
    final leadPreset = EatScriptLibrary.getPresetById(config.leadPresetId);
    final String leadCode = leadPreset?.code ?? '';

    final track = TrackChannel(
      id: 'proc_track_lead',
      name: config.leadName,
      color: config.leadColor,
      type: TrackType.eatScript,
      volume: 0.80,
      pan: 0.15,
      luaScriptCode: leadCode,
      luaParams: Map<String, double>.from(config.leadParams),
    );

    final rng = Mulberry32Rng(seed);
    final List<Note> allNotes = [];

    // Pentatonic subsets for expressive soulful melodies
    final pentatonicIntervals = isMinor
        ? [0, 3, 5, 7, 10] // Minor Pentatonic
        : [0, 2, 4, 7, 9]; // Major Pentatonic

    for (final section in sections) {
      final List<Note> sectionNotes = [];
      final int startBar = section.startBar;
      final int endBar = section.startBar + section.lengthBars;

      // In Intro, lead plays very sparse opening motif (or none)
      // In Verse, lead plays subtle call-and-response
      // In Chorus, lead plays full theme/hook
      if (section.type == _SectionType.intro) {
        // Sparse 2-note bell / vibraphone motif on bar 2
        final ch = _getChordAtBar(chords, startBar + 1);
        final pRoot = ch?.rootPitchClass ?? rootPitchClass;
        sectionNotes.add(Note(
          id: 'lead_intro_1',
          pitch: 72 + pRoot + 7, // High 5th
          startStep: 1 * 16.0 + 8.0,
          durationSteps: 6.0,
          velocity: 0.70,
        ));
        sectionNotes.add(Note(
          id: 'lead_intro_2',
          pitch: 72 + pRoot + (isMinor ? 3 : 4), // 3rd
          startStep: 2 * 16.0 + 0.0,
          durationSteps: 12.0,
          velocity: 0.65,
        ));
      } else if (config.id == 'synthwave' || config.id == 'acid') {
        // Fast neon 16th Arpeggiator across active chord tones
        for (int bar = startBar; bar < endBar; bar++) {
          final chord = _getChordAtBar(chords, bar) ?? chords.first;
          final pitches = chord.pitchClasses;
          final int barInClip = bar - startBar;
          final double barStartStep = barInClip * 16.0;

          for (int s = 0; s < 16; s++) {
            // 16th arp cycling up and down
            final pIdx = (s % (pitches.length * 2 - 2));
            final chordTone = pIdx < pitches.length ? pitches[pIdx] : pitches[(pitches.length * 2 - 2) - pIdx];
            final octave = ((s ~/ pitches.length) % 2) * 12;
            final pitch = 72 + chordTone + octave; // C5 (72)

            sectionNotes.add(Note(
              id: 'lead_arp_${bar}_$s',
              pitch: pitch.clamp(60, 96),
              startStep: barStartStep + s,
              durationSteps: 0.85,
              velocity: (s % 4 == 0) ? 0.85 : 0.70,
            ));
          }
        }
      } else if (config.id == 'snes_adventure') {
        // SNES 16-Bit Hero Lead: Lyrical melodic phrasing with arpeggiated motif and held climax
        for (int bar = startBar; bar < endBar; bar += 2) {
          final chord = _getChordAtBar(chords, bar) ?? chords.first;
          final pRoot = chord.rootPitchClass;
          final int barInClip = bar - startBar;
          final double barStartStep = barInClip * 16.0;

          // Heroic motif across bar 1
          final motifSteps = [0.0, 4.0, 7.0, 10.0];
          final intervals = [0, 4, 7, 12];
          for (int mi = 0; mi < motifSteps.length; mi++) {
            final interval = intervals[mi % intervals.length];
            final pitch = 72 + pRoot + interval;
            final dur = (mi == motifSteps.length - 1) ? 5.0 : 2.5;
            sectionNotes.add(Note(
              id: 'lead_snes_${bar}_$mi',
              pitch: pitch.clamp(60, 96),
              startStep: barStartStep + motifSteps[mi],
              durationSteps: dur,
              velocity: 0.88,
            ));
          }

          // Bar 2 answer / cadence note
          sectionNotes.add(Note(
            id: 'lead_snes_${bar}_ans',
            pitch: 72 + pRoot + 7, // Held 5th
            startStep: barStartStep + 16.0 + 2.0,
            durationSteps: 10.0,
            velocity: 0.85,
          ));
        }
      } else {
        // Lo-Fi Hip Hop / Neo-Soul: Lyrical phrased hook with space / breath!
        for (int bar = startBar; bar < endBar; bar += 2) {
          final chord = _getChordAtBar(chords, bar) ?? chords.first;
          final int barInClip = bar - startBar;
          final double barStartStep = barInClip * 16.0;

          // Phrase Motif: 3-5 notes spanning first bar, then resting on second bar
          final phraseSteps = [2.0, 5.0, 8.0, 11.0, 14.0];

          for (int ni = 0; ni < phraseSteps.length; ni++) {
            if (rng.chance(0.80)) {
              final interval = rng.pick(pentatonicIntervals);
              final pitch = 72 + rootPitchClass + interval;
              final dur = (ni == phraseSteps.length - 1) ? 6.0 : 2.5;

              sectionNotes.add(Note(
                id: 'lead_lofi_${bar}_$ni',
                pitch: pitch.clamp(60, 96),
                startStep: barStartStep + phraseSteps[ni] + rng.rand(-0.05, 0.05),
                durationSteps: dur,
                velocity: 0.78 + rng.rand(-0.06, 0.06),
              ));
            }
          }

          // In Chorus, add a resolving tail note on the second bar
          if (section.type == _SectionType.chorus && rng.chance(0.85)) {
            sectionNotes.add(Note(
              id: 'lead_lofi_tail_$bar',
              pitch: 72 + (chord.rootPitchClass) + (isMinor ? 3 : 4),
              startStep: barStartStep + 16.0 + 4.0,
              durationSteps: 8.0,
              velocity: 0.72,
            ));
          }
        }
      }

      final double startStepOffset = section.startBar * 16.0;
      final List<Note> timelineNotes = sectionNotes.map((n) {
        return n.copyWith(
          startStep: n.startStep + startStepOffset,
        );
      }).toList();

      final clip = TrackClip(
        id: 'clip_lead_${section.name}_${section.startBar}',
        name: '${section.name} (Lead)',
        trackId: track.id,
        startBar: section.startBar,
        barLength: section.lengthBars,
        notes: sectionNotes.map((n) => n.copyWith()).toList(),
      );
      track.clips.add(clip);
      allNotes.addAll(timelineNotes);
    }

    track.notes = allNotes.map((n) => n.copyWith()).toList();
    return track;
  }

  static ChordEvent? _getChordAtBar(List<ChordEvent> chords, int bar) {
    for (final c in chords) {
      if (bar >= c.startBar && bar < (c.startBar + c.barLength)) {
        return c;
      }
    }
    return chords.isNotEmpty ? chords.last : null;
  }
}

enum _SectionType { intro, verse, chorus, outro }

class _Section {
  final String name;
  final int startBar;
  final int lengthBars;
  final _SectionType type;

  const _Section({
    required this.name,
    required this.startBar,
    required this.lengthBars,
    required this.type,
  });
}
