// Pure-Dart procedural piano composition engine.
// Ported from STMN Piano Music Generator (MIT License, Copyright (c) 2024 stmn).
// Generates complete classical and blues piano compositions from seeded pseudo-random streams.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/chord_model.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../lua/lua_script_library.dart';
import '../../lua/project_script_engine.dart';

/// Mulberry32 32-bit deterministic pseudo-random number generator.
class Mulberry32Rng {
  int _state;

  Mulberry32Rng(int seed) : _state = seed & 0xFFFFFFFF;

  /// Returns a double in range [0.0, 1.0).
  double nextDouble() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= t + _imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296.0;
  }

  static int _imul(int a, int b) {
    final ah = (a >>> 16) & 0xFFFF;
    final al = a & 0xFFFF;
    final bh = (b >>> 16) & 0xFFFF;
    final bl = b & 0xFFFF;
    return ((al * bl) + (((ah * bl + al * bh) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }

  T pick<T>(List<T> list) => list[(nextDouble() * list.length).floor() % list.length];

  double rand(double a, double b) => a + nextDouble() * (b - a);

  bool chance(double p) => nextDouble() < p;

  K weighted<K>(List<(K key, double weight)> entries) {
    double total = entries.fold(0.0, (sum, e) => sum + e.$2);
    double r = nextDouble() * total;
    for (final e in entries) {
      r -= e.$2;
      if (r <= 0) return e.$1;
    }
    return entries.last.$1;
  }
}

class ProceduralStyle {
  final String key;
  final String label;
  final int beats;
  final double beatUnit;
  final double tempo;
  final double rubato;
  final double pickup;
  final (double, double) dynamicRange;
  final bool blues;
  final bool swing;
  final bool backbeat;
  final int? accentBeat;
  final Map<String, double> kinds;
  final Map<String, double> shapes;
  final Map<String, dynamic> character;

  const ProceduralStyle({
    required this.key,
    required this.label,
    required this.beats,
    this.beatUnit = 1.0,
    required this.tempo,
    required this.rubato,
    required this.pickup,
    required this.dynamicRange,
    this.blues = false,
    this.swing = false,
    this.backbeat = false,
    this.accentBeat,
    required this.kinds,
    required this.shapes,
    this.character = const {},
  });
}

class ProceduralChord {
  final String name;
  final int rootPc;
  final String quality;
  final List<int> pcs;
  final int bassPc;
  final double start;
  final double len;

  const ProceduralChord({
    required this.name,
    required this.rootPc,
    required this.quality,
    required this.pcs,
    required this.bassPc,
    required this.start,
    required this.len,
  });
}

class ProceduralNote {
  final double time; // in pulses (quarter notes or dotted quarters)
  final double duration; // in pulses
  final int pitch; // MIDI note number
  final double velocity; // 0.0 .. 1.0
  final String hand; // 'right' or 'left'
  final bool strong;
  final int bar;
  final bool ornament;
  final double ornFactor;
  final bool spread;
  final bool roll;
  final bool pedal;
  final bool pickup;

  ProceduralNote({
    required this.time,
    required this.duration,
    required this.pitch,
    this.velocity = 0.8,
    required this.hand,
    this.strong = false,
    this.bar = 0,
    this.ornament = false,
    this.ornFactor = 1.0,
    this.spread = false,
    this.roll = false,
    this.pedal = true,
    this.pickup = false,
  });

  ProceduralNote copyWith({
    double? time,
    double? duration,
    int? pitch,
    double? velocity,
    String? hand,
    bool? strong,
    int? bar,
    bool? ornament,
    double? ornFactor,
    bool? spread,
    bool? roll,
    bool? pedal,
    bool? pickup,
  }) {
    return ProceduralNote(
      time: time ?? this.time,
      duration: duration ?? this.duration,
      pitch: pitch ?? this.pitch,
      velocity: velocity ?? this.velocity,
      hand: hand ?? this.hand,
      strong: strong ?? this.strong,
      bar: bar ?? this.bar,
      ornament: ornament ?? this.ornament,
      ornFactor: ornFactor ?? this.ornFactor,
      spread: spread ?? this.spread,
      roll: roll ?? this.roll,
      pedal: pedal ?? this.pedal,
      pickup: pickup ?? this.pickup,
    );
  }
}

class ProceduralSection {
  final String name;
  final int bar;

  const ProceduralSection({required this.name, required this.bar});
}

class ProceduralPiece {
  final int seed;
  final int melodySeed;
  final int leftSeed;
  final String styleKey;
  final String root;
  final String mode;
  final int tempo;
  final int beats;
  final double beatUnit;
  final String meter;
  final double rubato;
  final bool swing;
  final int totalBars;
  final double totalBeats;
  final List<ProceduralNote> notes;
  final List<ProceduralChord> chords;
  final List<ProceduralSection> sections;
  final String description;

  const ProceduralPiece({
    required this.seed,
    required this.melodySeed,
    required this.leftSeed,
    required this.styleKey,
    required this.root,
    required this.mode,
    required this.tempo,
    required this.beats,
    required this.beatUnit,
    required this.meter,
    required this.rubato,
    required this.swing,
    required this.totalBars,
    required this.totalBeats,
    required this.notes,
    required this.chords,
    required this.sections,
    required this.description,
  });
}

/// The core procedural composition engine.
class ProceduralPianoEngine {
  static const List<String> roots = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  static const Map<String, List<int>> scales = {
    'major': [0, 2, 4, 5, 7, 9, 11],
    'minor': [0, 2, 3, 5, 7, 8, 10],
  };

  static const Map<String, List<int>> qualityPcs = {
    'maj': [0, 4, 7],
    'min': [0, 3, 7],
    'dim': [0, 3, 6],
    'dom7': [0, 4, 7, 10],
    'min7': [0, 3, 7, 10],
  };

  static const Map<String, Map<String, (int, String)>> chordsDict = {
    'major': {
      'I': (0, 'maj'), 'ii': (2, 'min'), 'iii': (4, 'min'), 'IV': (5, 'maj'), 'V': (7, 'maj'), 'V7': (7, 'dom7'), 'vi': (9, 'min'),
      'V/V': (2, 'dom7'), 'V/vi': (4, 'dom7'), 'V/IV': (0, 'dom7'), 'V/ii': (9, 'dom7'),
    },
    'minor': {
      'i': (0, 'min'), 'iio': (2, 'dim'), 'III': (3, 'maj'), 'iv': (5, 'min'), 'V': (7, 'maj'), 'V7': (7, 'dom7'), 'VI': (8, 'maj'), 'VII': (10, 'maj'),
      'V/iv': (0, 'dom7'), 'V/VI': (3, 'dom7'), 'V/III': (10, 'dom7'),
    },
  };

  static const Map<String, Map<String, (int, String)>> bluesChords = {
    'major': {'I7': (0, 'dom7'), 'IV7': (5, 'dom7'), 'V7': (7, 'dom7')},
    'minor': {'i7': (0, 'min7'), 'iv7': (5, 'min7'), 'V7': (7, 'dom7')},
  };

  static const Map<String, List<int>> bluesScale = {
    'major': [0, 2, 3, 4, 7, 9, 10],
    'minor': [0, 3, 5, 6, 7, 10],
  };

  static const Map<String, List<List<String>>> bluesForms = {
    'major': [
      ['I7', 'I7', 'I7', 'I7', 'IV7', 'IV7', 'I7', 'I7', 'V7', 'IV7', 'I7', 'V7'],
      ['I7', 'IV7', 'I7', 'I7', 'IV7', 'IV7', 'I7', 'I7', 'V7', 'IV7', 'I7', 'V7'],
      ['I7', 'I7', 'I7', 'I7', 'IV7', 'IV7', 'I7', 'I7', 'V7', 'V7', 'I7', 'V7'],
    ],
    'minor': [
      ['i7', 'i7', 'i7', 'i7', 'iv7', 'iv7', 'i7', 'i7', 'V7', 'iv7', 'i7', 'V7'],
      ['i7', 'iv7', 'i7', 'i7', 'iv7', 'iv7', 'i7', 'i7', 'V7', 'iv7', 'i7', 'V7'],
    ],
  };

  static const Map<String, Map<String, List<List<String>>>> progressions = {
    'major': {
      'antecedent': [
        ['I', 'vi', 'IV', 'V'], ['I', 'IV', 'I6', 'V'], ['I', 'V', 'vi', 'V'], ['I', 'iii', 'IV', 'V'], ['I', 'V/V', 'V', 'V'],
        ['I', 'V/vi', 'vi', 'V'], ['I', 'V/IV', 'IV', 'V'], ['I', 'vi', 'ii6', 'V'], ['I', 'IV', 'ii6 V', 'V'], ['I V', 'I', 'IV', 'V'], ['I', 'I', 'IV', 'V'],
        ['I', 'V43 I6', 'IV', 'V'], ['I I6', 'IV', 'ii6', 'V'], ['I', 'vi', 'IV', 'I64 V'], ['I', 'IV', 'V65 I', 'V'],
      ],
      'consequent': [
        ['I', 'IV', 'V7', 'I'], ['vi', 'IV', 'V7', 'I'], ['I', 'ii6', 'V7', 'I'], ['IV', 'I6', 'V7', 'I'], ['I', 'V/ii', 'ii V7', 'I'],
        ['I', 'V/IV', 'IV V7', 'I'], ['vi', 'ii6', 'V7', 'I'], ['I', 'IV', 'ii6 V7', 'I'], ['I vi', 'IV', 'V7', 'I'],
        ['I', 'IV', 'I64 V7', 'I'], ['vi', 'ii6', 'I64 V7', 'I'], ['I6', 'IV', 'I64 V7', 'I'], ['I', 'V43 I6', 'ii6 V7', 'I'],
      ],
      'bAntecedent': [
        ['vi', 'IV', 'I6', 'V'], ['IV', 'V', 'vi', 'iii'], ['ii6', 'V', 'I', 'vi'], ['IV', 'V/V', 'V', 'V'], ['vi', 'V/vi', 'vi', 'V'], ['IV', 'I6', 'ii6', 'V'],
      ],
      'bConsequent': [
        ['IV', 'ii6', 'V', 'V7'], ['IV', 'I6', 'V', 'V7'], ['vi', 'ii6', 'V', 'V7'], ['ii', 'V/V', 'V', 'V7'], ['vi', 'IV', 'ii6', 'V7'],
      ],
      'bConsequentPivot': [
        ['vi', 'ii6', 'V', 'V7'], ['vi', 'IV', 'ii6', 'V7'], ['IV', 'ii6', 'I64', 'V7'], ['vi', 'V/V', 'V', 'V7'],
      ],
      'bClosing': [
        ['IV', 'ii6', 'I64 V7', 'I'], ['vi', 'IV', 'V7', 'I'], ['IV', 'I6', 'ii6 V7', 'I'],
      ],
      'intro': [['I'], ['I'], ['I', 'V7'], ['I', 'I']],
      'coda2': [['I', 'I']],
      'coda4': [['IV', 'I V7', 'I', 'I'], ['IV', 'V7', 'I', 'I']],
    },
    'minor': {
      'antecedent': [
        ['i', 'VI', 'iv', 'V'], ['i', 'iv', 'i6', 'V'], ['i', 'VII', 'VI', 'V'], ['i', 'III', 'iv', 'V'], ['i', 'V/iv', 'iv', 'V'],
        ['i', 'V/VI', 'VI', 'V'], ['i', 'iv', 'iio6', 'V'], ['i V', 'i', 'iv', 'V'], ['i', 'VI', 'iio6 V', 'V'],
        ['i', 'V43 i6', 'iv', 'V'], ['i i6', 'iv', 'iio6', 'V'], ['i', 'VI', 'iv', 'i64 V'],
      ],
      'consequent': [
        ['i', 'iv', 'V7', 'i'], ['VI', 'iv', 'V7', 'i'], ['i', 'iio6', 'V7', 'i'], ['iv', 'i6', 'V7', 'i'], ['i', 'V/iv', 'iv V7', 'i'],
        ['VI', 'iio6', 'V7', 'i'], ['i', 'VII', 'VI V7', 'i'], ['i VI', 'iv', 'V7', 'i'],
        ['i', 'iv', 'i64 V7', 'i'], ['VI', 'iio6', 'i64 V7', 'i'], ['i6', 'iv', 'i64 V7', 'i'],
      ],
      'bAntecedent': [
        ['III', 'VII', 'VI', 'V'], ['iv', 'i6', 'iio6', 'V'], ['VI', 'III', 'iv', 'V'], ['III', 'V/III', 'III', 'V'], ['VI', 'V/VI', 'VI', 'V'],
      ],
      'bConsequent': [
        ['iv', 'iio6', 'V', 'V7'], ['VI', 'iv', 'V', 'V7'], ['iv', 'i6', 'V', 'V7'], ['VI', 'iio6', 'V', 'V7'],
      ],
      'bConsequentPivot': [
        ['VI', 'iio6', 'V', 'V7'], ['VI', 'iv', 'i64', 'V7'], ['iv', 'iio6', 'V', 'V7'],
      ],
      'bClosing': [
        ['iv', 'iio6', 'i64 V7', 'i'], ['VI', 'iv', 'V7', 'i'], ['iv', 'i6', 'iio6 V7', 'i'],
      ],
      'intro': [['i'], ['i'], ['i', 'V7'], ['i', 'i']],
      'coda2': [['i', 'i']],
      'coda4': [['iv', 'i V7', 'i', 'i'], ['iv', 'V7', 'i', 'i']],
    },
  };

  static const List<({String name, List<String> parts})> forms = [
    (name: 'AABA', parts: ['A', "A'", 'B', 'A']),
    (name: 'ABAB', parts: ['A', 'B', "A'", "B'"]),
    (name: 'ABA', parts: ['A', 'B', 'A']),
    (name: 'AABA', parts: ['A', "A'", 'B', "A'"]),
    (name: 'ABACA', parts: ['A', 'B', 'A', 'C', 'A']),
  ];

  static const Map<String, ProceduralStyle> styles = {
    'nocturne': ProceduralStyle(
      key: 'nocturne', label: 'Nocturne', beats: 4, tempo: 72, rubato: 1.0, pickup: 0.3, dynamicRange: (0.55, 0.22),
      kinds: {'broken': 4, 'block': 0.8, 'bassChord': 1, 'octaves': 0.2, 'rhythmic': 0.2, 'pedalPoint': 1},
      shapes: {'alberti': 0.4, 'updown': 2, 'rising': 1.5, 'walk': 1, 'pedal': 1, 'sweep': 2},
      character: {'density': [0.3, 0.8]},
    ),
    'prelude': ProceduralStyle(
      key: 'prelude', label: 'Prelude', beats: 4, tempo: 96, rubato: 0.8, pickup: 0.3, dynamicRange: (0.62, 0.25),
      kinds: {'broken': 6, 'block': 0.4, 'bassChord': 0.4, 'octaves': 0.3, 'rhythmic': 0.2, 'pedalPoint': 0.8},
      shapes: {'alberti': 1, 'updown': 2, 'rising': 2, 'walk': 1.5, 'pedal': 1, 'sweep': 2},
      character: {'density': [0.2, 0.6], 'grace': 0.2},
    ),
    'ballade': ProceduralStyle(
      key: 'ballade', label: 'Ballade', beats: 4, tempo: 84, rubato: 1.0, pickup: 0.3, dynamicRange: (0.66, 0.30),
      kinds: {'broken': 4.5, 'block': 0.8, 'bassChord': 0.5, 'octaves': 0.8, 'rhythmic': 0.3, 'pedalPoint': 0.8},
      shapes: {'alberti': 0.3, 'updown': 1, 'rising': 1, 'walk': 1, 'pedal': 1, 'sweep': 3},
      character: {'range': [8, 12], 'leapiness': [0.9, 1.6], 'octaves': 0.6},
    ),
    'sonatina': ProceduralStyle(
      key: 'sonatina', label: 'Sonatina', beats: 4, tempo: 112, rubato: 0.25, pickup: 0.5, dynamicRange: (0.62, 0.25),
      kinds: {'broken': 4, 'block': 1, 'bassChord': 1.2, 'octaves': 0.8, 'rhythmic': 0.4, 'pedalPoint': 0.3},
      shapes: {'alberti': 4, 'updown': 1, 'rising': 0.5, 'walk': 0.5, 'pedal': 0.5, 'sweep': 0.2},
      character: {'grace': 0.2, 'trill': 0.5},
    ),
    'march': ProceduralStyle(
      key: 'march', label: 'March', beats: 4, tempo: 108, rubato: 0.2, pickup: 0.5, dynamicRange: (0.72, 0.28),
      kinds: {'broken': 0.6, 'block': 2, 'bassChord': 2.5, 'octaves': 2, 'rhythmic': 3, 'pedalPoint': 0.2},
      shapes: {'alberti': 1, 'updown': 1, 'rising': 0.5, 'walk': 0.5, 'pedal': 0.5, 'sweep': 0.1},
      character: {'dotted': [0.4, 0.9], 'syncopation': 0.1, 'triplets': 0.1, 'density': [0.3, 0.7]},
    ),
    'chorale': ProceduralStyle(
      key: 'chorale', label: 'Chorale', beats: 4, tempo: 64, rubato: 0.8, pickup: 0.15, dynamicRange: (0.48, 0.18),
      kinds: {'broken': 0.8, 'block': 5, 'bassChord': 0.5, 'octaves': 0.1, 'rhythmic': 0.1, 'pedalPoint': 0.8},
      shapes: {'alberti': 1, 'updown': 1, 'rising': 1, 'walk': 1, 'pedal': 1, 'sweep': 0.5},
      character: {'density': [0.1, 0.4], 'syncopation': 0, 'triplets': 0.05, 'grace': 0.05, 'leapiness': [0.4, 0.9]},
    ),
    'elegy': ProceduralStyle(
      key: 'elegy', label: 'Elegy', beats: 4, tempo: 58, rubato: 1.0, pickup: 0.15, dynamicRange: (0.48, 0.18),
      kinds: {'broken': 3, 'block': 1.2, 'bassChord': 0.3, 'octaves': 0.1, 'rhythmic': 0.1, 'pedalPoint': 2},
      shapes: {'alberti': 0.3, 'updown': 2, 'rising': 1, 'walk': 1, 'pedal': 1.5, 'sweep': 1.5},
      character: {'density': [0.15, 0.5], 'syncopation': 0.1, 'grace': 0.5, 'leapiness': [0.4, 1.0]},
    ),
    'etude': ProceduralStyle(
      key: 'etude', label: 'Etude', beats: 4, tempo: 126, rubato: 0.25, pickup: 0.35, dynamicRange: (0.72, 0.28),
      kinds: {'broken': 6, 'block': 0.3, 'bassChord': 0.5, 'octaves': 0.8, 'rhythmic': 0.3, 'pedalPoint': 0.3},
      shapes: {'alberti': 3, 'updown': 2, 'rising': 1.5, 'walk': 1.5, 'pedal': 1, 'sweep': 1},
      character: {'density': [0.4, 0.9], 'grace': 0.1},
    ),
    'waltz': ProceduralStyle(
      key: 'waltz', label: 'Waltz', beats: 3, tempo: 150, rubato: 0.5, pickup: 0.5, dynamicRange: (0.62, 0.25),
      kinds: {'broken': 1.2, 'block': 0.5, 'bassChord': 5, 'octaves': 0.3, 'rhythmic': 0.6, 'pedalPoint': 0.3},
      shapes: {'alberti': 0.5, 'updown': 1.5, 'rising': 1.5, 'walk': 0.5, 'pedal': 1, 'sweep': 0.5},
      character: {'syncopation': 0.15},
    ),
    'minuet': ProceduralStyle(
      key: 'minuet', label: 'Minuet', beats: 3, tempo: 118, rubato: 0.5, pickup: 0.5, dynamicRange: (0.62, 0.25),
      kinds: {'broken': 2, 'block': 1.5, 'bassChord': 3, 'octaves': 0.4, 'rhythmic': 0.8, 'pedalPoint': 0.3},
      shapes: {'alberti': 2.5, 'updown': 1, 'rising': 1, 'walk': 0.5, 'pedal': 0.5, 'sweep': 0.2},
      character: {'density': [0.25, 0.65], 'syncopation': 0.1, 'triplets': 0.1, 'trill': 0.5, 'grace': 0.5},
    ),
    'mazurka': ProceduralStyle(
      key: 'mazurka', label: 'Mazurka', beats: 3, tempo: 132, accentBeat: 1, rubato: 0.5, pickup: 0.5, dynamicRange: (0.68, 0.26),
      kinds: {'broken': 0.6, 'block': 1, 'bassChord': 3, 'octaves': 0.3, 'rhythmic': 3, 'pedalPoint': 0.3},
      shapes: {'alberti': 0.5, 'updown': 1, 'rising': 1, 'walk': 0.5, 'pedal': 1, 'sweep': 0.2},
      character: {'dotted': [0.4, 0.9], 'triplets': 0.3, 'grace': 0.5},
    ),
    'polonaise': ProceduralStyle(
      key: 'polonaise', label: 'Polonaise', beats: 3, tempo: 100, rubato: 0.3, pickup: 0.45, dynamicRange: (0.72, 0.28),
      kinds: {'broken': 0.6, 'block': 1, 'bassChord': 1.5, 'octaves': 1, 'rhythmic': 4, 'pedalPoint': 0.3},
      shapes: {'alberti': 0.5, 'updown': 1, 'rising': 1, 'walk': 0.5, 'pedal': 1, 'sweep': 0.5},
      character: {'dotted': [0.4, 0.9], 'density': [0.4, 0.85], 'octaves': 0.5},
    ),
    'barcarolle': ProceduralStyle(
      key: 'barcarolle', label: 'Barcarolle', beats: 2, beatUnit: 1.5, tempo: 60, rubato: 1.0, pickup: 0.3, dynamicRange: (0.55, 0.22),
      kinds: {'broken': 4, 'block': 0.5, 'bassChord': 2.5, 'octaves': 0.2, 'rhythmic': 0.6, 'pedalPoint': 1},
      shapes: {'alberti': 1, 'updown': 3, 'rising': 1.5, 'walk': 1, 'pedal': 1.5, 'sweep': 1.5},
      character: {'density': [0.3, 0.75]},
    ),
    'lullaby': ProceduralStyle(
      key: 'lullaby', label: 'Lullaby', beats: 2, beatUnit: 1.5, tempo: 52, rubato: 1.0, pickup: 0.15, dynamicRange: (0.48, 0.18),
      kinds: {'broken': 4, 'block': 0.6, 'bassChord': 1.5, 'octaves': 0.1, 'rhythmic': 0.3, 'pedalPoint': 2},
      shapes: {'alberti': 1, 'updown': 3, 'rising': 1.5, 'walk': 1, 'pedal': 2, 'sweep': 1},
      character: {'density': [0.15, 0.55], 'leapiness': [0.4, 0.9], 'syncopation': 0.05, 'grace': 0.3, 'octaves': 0.05},
    ),
    'blues': ProceduralStyle(
      key: 'blues', label: 'Blues', beats: 4, tempo: 96, blues: true, rubato: 0.15, pickup: 0.4, dynamicRange: (0.66, 0.26),
      swing: true, backbeat: true,
      kinds: {'boogie': 4, 'walking': 2, 'block': 1.5, 'bassChord': 0.6},
      shapes: {'alberti': 1, 'updown': 1, 'rising': 1, 'walk': 1, 'pedal': 1, 'sweep': 0.5},
      character: {'density': [0.3, 0.7], 'syncopation': 0.8, 'triplets': 1.0, 'dotted': [0, 0.1], 'grace': 0.75, 'register': [65, 76], 'trill': 0.05, 'octaves': 0.2},
    ),
    'tarantella': ProceduralStyle(
      key: 'tarantella', label: 'Tarantella', beats: 2, beatUnit: 1.5, tempo: 112, rubato: 0.25, pickup: 0.3, dynamicRange: (0.72, 0.28),
      kinds: {'broken': 1.5, 'block': 1, 'bassChord': 4, 'octaves': 1, 'rhythmic': 2.5, 'pedalPoint': 0.2},
      shapes: {'alberti': 1, 'updown': 1.5, 'rising': 1, 'walk': 0.5, 'pedal': 1, 'sweep': 0.3},
      character: {'density': [0.5, 0.95], 'leapiness': [0.8, 1.6], 'grace': 0.15, 'octaves': 0.5},
    ),
  };

  static const int melodyLow = 60; // C4
  static const int melodyHigh = 88; // E6
  static const int chordFloor = 48; // C3
  static const int hammerMax = 4;

  static double near(double t) => (t * 24.0).round() / 24.0;

  static ProceduralChord chordInfo(String mode, int rootPc, String name) {
    String base = name;
    int? bassRole;
    bool seventhFromFig = false;

    for (final fig in ['64', '65', '43', '42', '6']) {
      if (name.length > fig.length && name.endsWith(fig)) {
        base = name.substring(0, name.length - fig.length);
        if (fig == '64') { bassRole = 2; seventhFromFig = false; }
        else if (fig == '65') { bassRole = 1; seventhFromFig = true; }
        else if (fig == '43') { bassRole = 2; seventhFromFig = true; }
        else if (fig == '42') { bassRole = 3; seventhFromFig = true; }
        else if (fig == '6') { bassRole = 1; seventhFromFig = false; }
        break;
      }
    }

    int offset;
    String qual;
    if (mode == 'blues') {
      final b = bluesChords['major']?[base] ?? bluesChords['minor']?[base] ?? (0, 'dom7');
      offset = b.$1;
      qual = b.$2;
    } else {
      final c = chordsDict[mode]?[base] ?? chordsDict['major']?[base] ?? (0, 'maj');
      offset = c.$1;
      qual = c.$2;
    }

    if (seventhFromFig) {
      if (qual == 'maj') qual = 'dom7';
      if (qual == 'min') qual = 'min7';
      if (qual == 'dim') qual = 'dim';
    }

    final root = (rootPc + offset) % 12;
    final intervals = qualityPcs[qual] ?? [0, 4, 7];
    final pcs = intervals.map((i) => (root + i) % 12).toList();
    final bassPc = (bassRole != null && bassRole < pcs.length) ? pcs[bassRole] : pcs[0];

    return ProceduralChord(
      name: name,
      rootPc: root,
      quality: qual,
      pcs: pcs,
      bassPc: bassPc,
      start: 0,
      len: 1,
    );
  }

  static List<ProceduralChord> parseBar(String str, String mode, int rootPc, int beats) {
    final tokens = str.trim().split(RegExp(r'\s+'));
    final step = beats / tokens.length.toDouble();
    return tokens.asMap().entries.map((e) {
      final c = chordInfo(mode, rootPc, e.value);
      return ProceduralChord(
        name: c.name,
        rootPc: c.rootPc,
        quality: c.quality,
        pcs: c.pcs,
        bassPc: c.bassPc,
        start: near(e.key * step),
        len: near(step),
      );
    }).toList();
  }

  static List<List<ProceduralChord>> parsePhrase(List<String> bars, String mode, int rootPc, int beats) {
    return bars.map((b) => parseBar(b, mode, rootPc, beats)).toList();
  }

  static ProceduralChord chordAt(List<ProceduralChord> segments, double t) {
    for (final s in segments) {
      if (t >= s.start - 1e-6 && t < s.start + s.len - 1e-6) return s;
    }
    return segments.last;
  }

  static int nearestPc(int pitch, int pc, [int low = melodyLow, int high = melodyHigh]) {
    final cand1 = pitch - ((pitch - pc) % 12 + 12) % 12;
    final cand2 = cand1 + 12;
    final best = (pitch - cand1).abs() <= (cand2 - pitch).abs() ? cand1 : cand2;
    if (best < low) return best + 12;
    if (best > high) return best - 12;
    return best;
  }

  static List<int> localScale(ProceduralChord chord, List<int> scale) {
    final out = List<int>.from(scale);
    for (final p in chord.pcs) {
      if (!out.contains(p)) {
        int bestIdx = 0, bestDist = 999;
        for (int i = 0; i < out.length; i++) {
          final d = (out[i] - p).abs();
          final cd = d > 6 ? 12 - d : d;
          if (cd < bestDist) { bestDist = cd; bestIdx = i; }
        }
        out[bestIdx] = p;
      }
    }
    out.sort();
    return out;
  }

  /// Generates the complete procedural piano piece.
  static ProceduralPiece generatePiece({
    int seed = 1,
    String style = 'nocturne',
    String root = 'C',
    String mode = 'major',
    int? tempo,
    int? melodySeed,
    int? leftSeed,
  }) {
    final styleObj = styles[style] ?? styles['nocturne']!;
    final rootPc = roots.indexOf(root) >= 0 ? roots.indexOf(root) : 0;
    final beats = styleObj.beats;
    final beatUnit = styleObj.beatUnit;
    final compound = beats == 2;
    final meter = compound ? '6/8' : '$beats/4';
    final actualTempo = tempo ?? styleObj.tempo.toInt();

    final styleOffset = 7919 * styles.keys.toList().indexOf(styleObj.key);
    final actualMelodySeed = melodySeed ?? seed;
    final actualLeftSeed = leftSeed ?? seed;

    final rng = Mulberry32Rng(seed + styleOffset);
    final rngMelody = Mulberry32Rng(actualMelodySeed * 3 + 104729 + styleOffset);
    final rngLeft = Mulberry32Rng(actualLeftSeed * 5 + 1299709 + styleOffset);

    final scale = (styleObj.blues ? bluesScale[mode]! : scales[mode]!).map((i) => (rootPc + i) % 12).toList();
    final minDur = actualTempo / (60.0 * 6.0); // note budget

    final prog = progressions[mode]!;
    final relMode = mode == 'major' ? 'minor' : 'major';
    final relRoot = (rootPc + (mode == 'major' ? 9 : 3)) % 12;
    final bInRelative = rng.chance(0.5);

    final form = rng.pick(forms);
    final introBars = rng.pick(prog['intro']!);
    final codaBars = rng.chance(0.5) ? rng.pick(prog['coda4']!) : rng.pick(prog['coda2']!);

    final notes = <ProceduralNote>[];
    final chordsTimeline = <ProceduralChord>[];
    final sections = <ProceduralSection>[];
    int currentBar = 0;

    // Build intro
    sections.add(ProceduralSection(name: 'Intro', bar: currentBar));
    final introChords = parsePhrase(introBars, mode, rootPc, beats);
    for (int b = 0; b < introChords.length; b++) {
      final barSegs = introChords[b];
      for (final seg in barSegs) {
        chordsTimeline.add(ProceduralChord(
          name: seg.name, rootPc: seg.rootPc, quality: seg.quality, pcs: seg.pcs, bassPc: seg.bassPc,
          start: currentBar * beats.toDouble() + seg.start, len: seg.len,
        ));
      }
      _generateAccompBar(rngLeft, styleObj, barSegs, currentBar, beats, notes);
      currentBar++;
    }

    // A material
    final antChords = parsePhrase(rng.pick(prog['antecedent']!), mode, rootPc, beats);
    final consChords = parsePhrase(rng.pick(prog['consequent']!), mode, rootPc, beats);
    final consChords2 = parsePhrase(rng.pick(prog['consequent']!), mode, rootPc, beats);

    int startPitch = nearestPc(72, antChords[0][0].pcs[rngMelody.chance(0.5) ? 1 : 2]);
    int peak = math.min(melodyHigh - 1, startPitch + 10);

    final antNotes = _generatePhraseNotes(rngMelody, antChords, beats, scale, startPitch, peak, 0, minDur, rootPc);
    final consNotes = _generatePhraseNotes(rngMelody, consChords, beats, scale, antNotes.last.pitch, peak, 1, minDur, rootPc, endOnTonic: true);
    final consNotes2 = _generatePhraseNotes(rngMelody, consChords2, beats, scale, antNotes.last.pitch, peak, 1, minDur, rootPc, endOnTonic: true);

    // Assembly through form parts
    for (int pIdx = 0; pIdx < form.parts.length; pIdx++) {
      final part = form.parts[pIdx];
      final isLast = pIdx == form.parts.length - 1;
      sections.add(ProceduralSection(name: part, bar: currentBar));

      if (part == 'A' || part == "A'") {
        final phraseCons = (isLast && part == 'A') ? consNotes2 : (part == 'A' ? consNotes : consNotes2);
        final phraseConsChords = (isLast && part == 'A') ? consChords2 : (part == 'A' ? consChords : consChords2);

        // Add Antecedent (4 bars)
        _placePhrase(antNotes, currentBar, beats, notes);
        for (int b = 0; b < 4; b++) {
          final barSegs = antChords[b];
          for (final seg in barSegs) {
            chordsTimeline.add(ProceduralChord(
              name: seg.name, rootPc: seg.rootPc, quality: seg.quality, pcs: seg.pcs, bassPc: seg.bassPc,
              start: currentBar * beats.toDouble() + seg.start, len: seg.len,
            ));
          }
          _generateAccompBar(rngLeft, styleObj, barSegs, currentBar, beats, notes);
          currentBar++;
        }

        // Add Consequent (4 bars)
        _placePhrase(phraseCons, currentBar, beats, notes);
        for (int b = 0; b < 4; b++) {
          final barSegs = phraseConsChords[b];
          for (final seg in barSegs) {
            chordsTimeline.add(ProceduralChord(
              name: seg.name, rootPc: seg.rootPc, quality: seg.quality, pcs: seg.pcs, bassPc: seg.bassPc,
              start: currentBar * beats.toDouble() + seg.start, len: seg.len,
            ));
          }
          _generateAccompBar(rngLeft, styleObj, barSegs, currentBar, beats, notes);
          currentBar++;
        }
      } else {
        // B or C contrast section
        final inRel = bInRelative && part == 'B';
        final bAntBars = inRel
            ? parsePhrase(rng.pick(progressions[relMode]!['antecedent']!), relMode, relRoot, beats)
            : parsePhrase(rng.pick(prog['bAntecedent']!), mode, rootPc, beats);
        final bConsBars = isLast
            ? parsePhrase(rng.pick(prog['bClosing']!), mode, rootPc, beats)
            : parsePhrase(rng.pick(inRel ? prog['bConsequentPivot']! : prog['bConsequent']!), mode, rootPc, beats);

        final bStartPitch = nearestPc(startPitch + 2, bAntBars[0][0].pcs[1]);
        final bNotes1 = _generatePhraseNotes(rngMelody, bAntBars, beats, scale, bStartPitch, peak, 0, minDur, rootPc);
        final bNotes2 = _generatePhraseNotes(rngMelody, bConsBars, beats, scale, bNotes1.last.pitch, peak, 1, minDur, rootPc, endOnTonic: isLast);

        // Add B Antecedent (4 bars)
        _placePhrase(bNotes1, currentBar, beats, notes);
        for (int b = 0; b < 4; b++) {
          final barSegs = bAntBars[b];
          for (final seg in barSegs) {
            chordsTimeline.add(ProceduralChord(
              name: seg.name, rootPc: seg.rootPc, quality: seg.quality, pcs: seg.pcs, bassPc: seg.bassPc,
              start: currentBar * beats.toDouble() + seg.start, len: seg.len,
            ));
          }
          _generateAccompBar(rngLeft, styleObj, barSegs, currentBar, beats, notes);
          currentBar++;
        }

        // Add B Consequent (4 bars)
        _placePhrase(bNotes2, currentBar, beats, notes);
        for (int b = 0; b < 4; b++) {
          final barSegs = bConsBars[b];
          for (final seg in barSegs) {
            chordsTimeline.add(ProceduralChord(
              name: seg.name, rootPc: seg.rootPc, quality: seg.quality, pcs: seg.pcs, bassPc: seg.bassPc,
              start: currentBar * beats.toDouble() + seg.start, len: seg.len,
            ));
          }
          _generateAccompBar(rngLeft, styleObj, barSegs, currentBar, beats, notes);
          currentBar++;
        }
      }
    }

    // Coda: echo of cadence & final chord
    sections.add(ProceduralSection(name: 'Coda', bar: currentBar));
    final tonicChords = parsePhrase(mode == 'major' ? ['I', 'I'] : ['i', 'i'], mode, rootPc, beats);
    final codaChords = codaBars.length == 4 ? [...consChords.sublist(2, 4), ...tonicChords] : tonicChords;

    for (int b = 0; b < codaChords.length; b++) {
      final barSegs = codaChords[b];
      for (final seg in barSegs) {
        chordsTimeline.add(ProceduralChord(
          name: seg.name, rootPc: seg.rootPc, quality: seg.quality, pcs: seg.pcs, bassPc: seg.bassPc,
          start: currentBar * beats.toDouble() + seg.start, len: seg.len,
        ));
      }
      if (b == codaChords.length - 1) {
        // Final sustained rolled chord
        _addFinalChord(notes, currentBar * beats.toDouble(), beats.toDouble() * 2, segs: barSegs, rootPc: rootPc);
      } else {
        _generateAccompBar(rngLeft, styleObj, barSegs, currentBar, beats, notes);
      }
      currentBar++;
    }

    notes.sort((a, b) => a.time.compareTo(b.time));

    final description = '${styleObj.label} in $root $mode, form ${form.name} (${form.parts.join(" ")}), $currentBar bars, seed $seed.';

    return ProceduralPiece(
      seed: seed,
      melodySeed: actualMelodySeed,
      leftSeed: actualLeftSeed,
      styleKey: styleObj.key,
      root: root,
      mode: mode,
      tempo: actualTempo,
      beats: beats,
      beatUnit: beatUnit,
      meter: meter,
      rubato: styleObj.rubato,
      swing: styleObj.swing,
      totalBars: currentBar,
      totalBeats: currentBar * beats.toDouble(),
      notes: notes,
      chords: chordsTimeline,
      sections: sections,
      description: description,
    );
  }

  static List<ProceduralNote> _generatePhraseNotes(
    Mulberry32Rng rng,
    List<List<ProceduralChord>> bars,
    int beats,
    List<int> scale,
    int startPitch,
    int peak,
    int phraseIndex,
    double minDur,
    int tonicPc, {
    bool endOnTonic = false,
  }) {
    final phrase = <ProceduralNote>[];
    int prevPitch = startPitch;
    bool prevNct = false;

    for (int bar = 0; bar < 4; bar++) {
      final segments = bars[bar];
      final isCadence = bar == 3;

      // Draw 1-bar rhythmic cells (quarters, eighths, triplets)
      List<double> rhythm;
      if (beats == 4) {
        rhythm = rng.chance(0.6) ? [1.0, 1.0, 1.0, 1.0] : [1.0, 0.5, 0.5, 1.0, 1.0];
      } else if (beats == 3) {
        rhythm = rng.chance(0.5) ? [1.0, 1.0, 1.0] : [1.0, 0.5, 0.5, 1.0];
      } else {
        rhythm = [1.0, 1.0]; // compound
      }

      double t = 0;
      for (int i = 0; i < rhythm.length; i++) {
        final dur = rhythm[i];
        final chord = chordAt(segments, t);
        final isStrong = (t == 0 || (beats == 4 && t == 2.0));
        final isFinalNote = (isCadence && i == rhythm.length - 1);

        int pitch;
        if (isFinalNote && endOnTonic) {
          pitch = nearestPc(prevPitch, tonicPc);
        } else {
          final wantChordTone = isStrong || prevNct || rng.chance(0.65);
          final allowedPcs = wantChordTone ? chord.pcs : localScale(chord, scale);

          // Step-wise preference
          final candidates = <int>[];
          for (int p = math.max(melodyLow, prevPitch - 7); p <= math.min(melodyHigh, prevPitch + 7); p++) {
            if (allowedPcs.contains(p % 12)) candidates.add(p);
          }

          if (candidates.isNotEmpty) {
            candidates.sort((a, b) => (a - prevPitch).abs().compareTo((b - prevPitch).abs()));
            pitch = rng.chance(0.6) ? candidates.first : candidates[rng.pick([0, math.min(1, candidates.length - 1)])];
          } else {
            pitch = nearestPc(prevPitch, chord.pcs.first);
          }
        }

        prevNct = !chord.pcs.contains(pitch % 12);
        prevPitch = pitch;

        phrase.add(ProceduralNote(
          time: near(bar * beats.toDouble() + t),
          duration: dur,
          pitch: pitch,
          velocity: isStrong ? 0.88 : 0.74,
          hand: 'right',
          strong: isStrong,
          bar: bar,
        ));

        t = near(t + dur);
      }
    }

    return phrase;
  }

  static void _placePhrase(List<ProceduralNote> phrase, int currentBar, int beats, List<ProceduralNote> target) {
    for (final n in phrase) {
      target.add(n.copyWith(
        time: near(currentBar * beats.toDouble() + n.time),
        bar: currentBar + n.bar,
      ));
    }
  }

  static void _generateAccompBar(
    Mulberry32Rng rng,
    ProceduralStyle style,
    List<ProceduralChord> barSegs,
    int bar,
    int beats,
    List<ProceduralNote> notes,
  ) {
    for (final seg in barSegs) {
      final bass = nearestPc(36, seg.bassPc, 31, 47);
      final midPcs = seg.pcs;
      final chordLow = nearestPc(chordFloor, midPcs[1 % midPcs.length], chordFloor, 59);
      final chordHigh = nearestPc(chordFloor + 7, midPcs[2 % midPcs.length], chordFloor + 4, 64);

      if (style.beats == 3) {
        // Waltz / Minuet: Bass on beat 1, chords on beats 2 & 3
        notes.add(ProceduralNote(
          time: near(bar * beats.toDouble() + seg.start),
          duration: 0.9, pitch: bass, velocity: 0.82, hand: 'left', strong: true, bar: bar,
        ));
        for (double b = 1.0; b < seg.len; b += 1.0) {
          notes.add(ProceduralNote(
            time: near(bar * beats.toDouble() + seg.start + b),
            duration: 0.8, pitch: chordLow, velocity: 0.65, hand: 'left', bar: bar,
          ));
          notes.add(ProceduralNote(
            time: near(bar * beats.toDouble() + seg.start + b),
            duration: 0.8, pitch: chordHigh, velocity: 0.62, hand: 'left', bar: bar,
          ));
        }
      } else if (style.beats == 2) {
        // Barcarolle / 6/8: Arpeggiated wave
        for (int step = 0; step < 6; step++) {
          final t = near(seg.start + (step * (seg.len / 6.0)));
          final p = step == 0 ? bass : (step % 2 == 1 ? chordLow : chordHigh);
          notes.add(ProceduralNote(
            time: near(bar * beats.toDouble() + t),
            duration: 0.45, pitch: p, velocity: step == 0 ? 0.80 : 0.62, hand: 'left', strong: step == 0, bar: bar,
          ));
        }
      } else {
        // 4/4 styles: Alberti / broken chord
        // Bass on downbeat
        notes.add(ProceduralNote(
          time: near(bar * beats.toDouble() + seg.start),
          duration: 0.9, pitch: bass, velocity: 0.82, hand: 'left', strong: true, bar: bar,
        ));
        // Eighth note figuration: root - 5th - 3rd - 5th
        final pitches = [bass, chordHigh, chordLow, chordHigh];
        for (int i = 1; i < 4; i++) {
          notes.add(ProceduralNote(
            time: near(bar * beats.toDouble() + seg.start + i * 1.0),
            duration: 0.85, pitch: pitches[i % pitches.length], velocity: 0.68, hand: 'left', bar: bar,
          ));
        }
      }
    }
  }

  static void _addFinalChord(
    List<ProceduralNote> notes,
    double time,
    double duration, {
    required List<ProceduralChord> segs,
    required int rootPc,
  }) {
    final chord = segs.first;
    final bassLow = nearestPc(36, rootPc, 24, 40);
    final bassFifth = nearestPc(bassLow + 7, chord.pcs[2 % chord.pcs.length], 36, 48);
    final midRoot = nearestPc(48, rootPc, 48, 59);
    final midThird = nearestPc(52, chord.pcs[1 % chord.pcs.length], 48, 64);
    final topTonic = nearestPc(60, rootPc, 60, 72);

    final chordPitches = [bassLow, bassFifth, midRoot, midThird, topTonic];
    for (int i = 0; i < chordPitches.length; i++) {
      notes.add(ProceduralNote(
        time: near(time + i * 0.04), // spread rolled chord from bass
        duration: duration,
        pitch: chordPitches[i],
        velocity: 0.78 - (i * 0.02),
        hand: 'left',
        spread: true,
      ));
    }
  }

  /// Evaluates micro-timing and human performance adjustments.
  static List<double> performTimingOffsets(ProceduralPiece piece) {
    final rng = Mulberry32Rng((piece.seed * 11 + 7) & 0xFFFFFFFF);
    final scale = piece.rubato >= 0.8 ? 1.0 : (piece.rubato >= 0.45 ? 0.8 : 0.6);

    return piece.notes.map((n) {
      double off = (rng.nextDouble() - 0.5) * (n.hand == 'right' ? 0.014 : 0.018) * scale;
      if (n.hand == 'right' && !n.ornament) {
        off -= 0.021 * scale; // Melody leads the bass by ~21ms
      }
      if (n.pickup) {
        off -= 0.012 * scale;
      }
      final frac = n.time - n.time.floor();
      if (frac < 1e-6 && n.hand == 'left' && off < 0) {
        off = 0; // Downbeat bass is never early
      }
      return off.clamp(-0.06, 0.06);
    }).toList();
  }

  /// Populates the generated composition into DawState.
  static ProjectScriptResult generateToDawState(DawState dawState, Map<String, dynamic> params) {
    final styleRaw = (params['Style'] ?? params['style'] ?? 'Nocturne').toString();
    final styleKey = styleRaw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final root = (params['Root'] ?? params['root'] ?? 'C').toString();
    final mode = (params['Mode'] ?? params['mode'] ?? 'major').toString().toLowerCase();
    final num rawSeed = (params['Seed'] ?? params['seed'] ?? 42) as num;
    final int seed = rawSeed.toInt();

    final layoutRaw = (params['TrackLayout'] ?? params['track_layout'] ?? 'Two Tracks (Right/Left Hand)').toString();
    final bool splitHands = layoutRaw.toLowerCase().contains('two') || layoutRaw.toLowerCase().contains('split');

    final num rawRubato = (params['Rubato'] ?? params['rubato'] ?? 0.7) as num;
    final double rubato = rawRubato.toDouble();

    final num rawArt = (params['LeftArticulation'] ?? params['left_articulation'] ?? 1.0) as num;
    final double articulation = rawArt.toDouble();

    final num rawTempo = (params['TempoBpm'] ?? params['tempo_bpm'] ?? 0) as num;
    final int? userTempo = rawTempo.toInt() > 40 ? rawTempo.toInt() : null;

    // Generate piece
    final piece = generatePiece(
      seed: seed,
      style: styleKey,
      root: root,
      mode: mode,
      tempo: userTempo,
    );

    // 1. Update Project BPM & Song Key
    dawState.setBpm(piece.tempo.toDouble());
    final modeLabel = piece.mode == 'minor' ? 'Minor' : 'Major';
    dawState.setSongKey('${piece.root} $modeLabel');
    dawState.projectName = '${styles[piece.styleKey]?.label ?? "Piano"} in ${piece.root} ${piece.mode}';

    // 2. Populate Chord Track with Figured Bass Progressions
    final newChords = <ChordEvent>[];
    for (int i = 0; i < piece.chords.length; i++) {
      final c = piece.chords[i];
      final startBar = (c.start / piece.beats).floor();
      final barLen = (c.len / piece.beats);

      ChordQuality q = ChordQuality.major;
      if (c.quality == 'min') q = ChordQuality.minor;
      else if (c.quality == 'dom7') q = ChordQuality.dominant7;
      else if (c.quality == 'min7') q = ChordQuality.minor7;
      else if (c.quality == 'dim') q = ChordQuality.diminished;

      newChords.add(ChordEvent(
        id: 'stmn_chord_${startBar}_$i',
        startBar: startBar,
        barLength: barLen,
        rootPitchClass: c.rootPc,
        quality: q,
        bassPitchClass: c.bassPc != c.rootPc ? c.bassPc : null,
      ));
    }
    dawState.chordTrack = newChords;

    // 3. Clear existing tracks in pattern & configure steps
    final pattern = dawState.activePattern;
    pattern.tracks.clear();

    // 1 bar = 16 steps (for 4/4 and 3/4) or scaled by beats
    final stepsPerBeat = 4.0;
    final totalSteps = (piece.totalBars * piece.beats * stepsPerBeat).round();
    pattern.lengthSteps = totalSteps.clamp(16, 512);

    // Look up Concert Grand Piano physical model preset
    final pianoPreset = LuaPresetLibrary.getPresetById('concert_grand_piano') ??
        LuaPresetLibrary.presets.firstWhere(
          (p) => p.isInstrument && (p.name.contains('Grand Piano') || p.name.contains('Concert Grand')),
          orElse: () => LuaPresetLibrary.presets.first,
        );

    final timingOffsets = performTimingOffsets(piece);

    if (splitHands) {
      // Track 1: Right Hand (Melody & Lead)
      final rightTrack = TrackChannel(
        id: 'track_piano_rh_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Concert Grand (Right Hand)',
        type: TrackType.luaScript,
        color: const Color(0xFF21F4E8),
        luaScriptCode: pianoPreset.code,
        volume: 0.88,
      );
      final rightClip = TrackClip(
        id: 'clip_piano_rh_0',
        name: 'Melody & Phrasing',
        trackId: rightTrack.id,
        startBar: 0,
        barLength: piece.totalBars,
      );

      // Track 2: Left Hand (Accompaniment & Bass)
      final leftTrack = TrackChannel(
        id: 'track_piano_lh_${DateTime.now().millisecondsSinceEpoch + 1}',
        name: 'Concert Grand (Left Hand)',
        type: TrackType.luaScript,
        color: const Color(0xFF00FF66),
        luaScriptCode: pianoPreset.code,
        volume: 0.78,
      );
      final leftClip = TrackClip(
        id: 'clip_piano_lh_0',
        name: 'Harmonic Accompaniment',
        trackId: leftTrack.id,
        startBar: 0,
        barLength: piece.totalBars,
      );

      for (int i = 0; i < piece.notes.length; i++) {
        final n = piece.notes[i];
        final offset = timingOffsets[i];
        final startStep = math.max(0.0, (n.time * stepsPerBeat) + (offset * (piece.tempo / 60.0) * stepsPerBeat));
        final durSteps = n.hand == 'left' ? math.max(0.4, n.duration * stepsPerBeat * articulation) : math.max(0.4, n.duration * stepsPerBeat);

        final noteObj = Note(
          id: 'n_${n.hand}_$i',
          pitch: n.pitch,
          startStep: startStep,
          durationSteps: durSteps,
          velocity: n.velocity,
        );

        if (n.hand == 'right') {
          rightClip.notes.add(noteObj);
        } else {
          leftClip.notes.add(noteObj);
        }
      }

      rightTrack.clips.add(rightClip);
      leftTrack.clips.add(leftClip);
      pattern.tracks.add(rightTrack);
      pattern.tracks.add(leftTrack);
    } else {
      // Unified Track
      final unifiedTrack = TrackChannel(
        id: 'track_piano_unified_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Concert Grand Piano',
        type: TrackType.luaScript,
        color: const Color(0xFF21F4E8),
        luaScriptCode: pianoPreset.code,
        volume: 0.85,
      );
      final clip = TrackClip(
        id: 'clip_piano_unified_0',
        name: 'Complete Piano Performance',
        trackId: unifiedTrack.id,
        startBar: 0,
        barLength: piece.totalBars,
      );

      for (int i = 0; i < piece.notes.length; i++) {
        final n = piece.notes[i];
        final offset = timingOffsets[i];
        final startStep = math.max(0.0, (n.time * stepsPerBeat) + (offset * (piece.tempo / 60.0) * stepsPerBeat));
        final durSteps = n.hand == 'left' ? math.max(0.4, n.duration * stepsPerBeat * articulation) : math.max(0.4, n.duration * stepsPerBeat);

        clip.notes.add(Note(
          id: 'n_$i',
          pitch: n.pitch,
          startStep: startStep,
          durationSteps: durSteps,
          velocity: n.velocity,
        ));
      }

      unifiedTrack.clips.add(clip);
      pattern.tracks.add(unifiedTrack);
    }

    dawState.triggerAutoSave();
    dawState.notifyListeners();

    return ProjectScriptResult(
      isSuccess: true,
      message: 'Generated ${piece.description} (${piece.notes.length} notes, ${piece.totalBars} bars).',
      affectedTracksCount: pattern.tracks.length,
      affectedNotesCount: piece.notes.length,
      affectedChordsCount: newChords.length,
    );
  }
}
