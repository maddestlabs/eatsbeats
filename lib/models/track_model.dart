import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'automation_model.dart';
import 'lyric_model.dart';
import '../eatscript/eats_synth_type.dart';

enum MusicViewType { pianoRoll, tracker, script, score }
enum TrackType {
  sampler,
  synth,
  eatScript,
  bass,
  tts,
  folder;

  // Backward compatibility getter
  bool get isScript => this == TrackType.eatScript;
  bool get isFolder => this == TrackType.folder;
}

enum ChordFollowMode {
  off,
  bass,
  chord,
  scale,
  colorLead;

  String get displayName {
    switch (this) {
      case ChordFollowMode.off:
        return 'Off';
      case ChordFollowMode.bass:
        return 'Bass';
      case ChordFollowMode.chord:
        return 'Chord';
      case ChordFollowMode.scale:
        return 'Scale';
      case ChordFollowMode.colorLead:
        return 'Lead';
    }
  }

  String get description {
    switch (this) {
      case ChordFollowMode.off:
        return 'Play original MIDI notes unadjusted';
      case ChordFollowMode.bass:
        return 'Snap to chord root or bass inversion note';
      case ChordFollowMode.chord:
        return 'Snap notes to nearest active chord tones (1, 3, 5, 7)';
      case ChordFollowMode.scale:
        return 'Snap notes to active chord diatonic scale';
      case ChordFollowMode.colorLead:
        return 'Preserve melodic shape while resolving harmonic clashes';
    }
  }
}

class Note {
  String id;
  int pitch; // MIDI Note Number (e.g., 60 = C4)
  double startStep; // Position in steps (0.0 to 32.0)
  double durationSteps; // Duration in steps (default 1.0)
  double velocity; // 0.0 to 1.0 (MPE Strike)
  int column; // Tracker sub-channel column index (0..N)
  String effectCommand; // Hex effect command (e.g., "00", "V90", "P12")
  bool isSlide;
  bool isAccent;
  String? lyric; // Syllable or word text attached to this note

  // Articulation & MPE Continuous Modulation
  String? articulation; // e.g. "muted", "harmonics", "pizzicato", "slap", "flam"
  double? releaseVelocity; // 0.0 to 1.0 (MPE Lift / Note-Off velocity)
  List<List<double>>? pitchBendPoints; // MPE Glide / Pitch Bend: [[normTime, semitones], ...]
  List<List<double>>? pressurePoints; // MPE Press / Poly Aftertouch: [[normTime, pressure (0..1)], ...]
  List<List<double>>? timbrePoints; // MPE Slide / Timbre / CC74: [[normTime, timbre (0..1)], ...]

  String? get art => articulation;
  set art(String? value) => articulation = value;

  double? get relVel => releaseVelocity;
  set relVel(double? value) => releaseVelocity = value;

  bool get isBend => isSlide || (pitchBendPoints != null && pitchBendPoints!.isNotEmpty);
  set isBend(bool value) => isSlide = value;

  /// True if accent is active via flag, high velocity, articulation tag, lyric tag, or tracker effect.
  bool get hasAccent {
    if (isAccent) return true;
    if (velocity > 0.75) return true;
    if (articulation != null && articulation!.toLowerCase().contains('accent')) return true;
    if (lyric != null && lyric!.toLowerCase().contains('accent')) return true;
    if (effectCommand.isNotEmpty && effectCommand.toLowerCase().contains('acc')) return true;
    return false;
  }

  Note({
    required this.id,
    required this.pitch,
    required this.startStep,
    this.durationSteps = 1.0,
    this.velocity = 0.9,
    this.column = 0,
    this.effectCommand = '00',
    this.isSlide = false,
    bool? isAccent,
    this.lyric,
    this.articulation,
    this.releaseVelocity,
    this.pitchBendPoints,
    this.pressurePoints,
    this.timbrePoints,
  }) : isAccent = isAccent ?? (velocity > 0.75 ||
            (articulation != null && articulation.toLowerCase().contains('accent')) ||
            (lyric != null && lyric.toLowerCase().contains('accent')) ||
            (effectCommand.toLowerCase().contains('acc')));

  /// Interpolates a piecewise linear curve of [[timeNorm, value], ...] at [progress] (0.0 to 1.0).
  static double interpolateCurve(List<List<double>>? points, double progress, double fallback) {
    if (points == null || points.isEmpty) return fallback;
    if (points.length == 1) return points[0].length > 1 ? points[0][1] : fallback;

    final p = progress.clamp(0.0, 1.0);
    if (p <= points.first[0]) return points.first.length > 1 ? points.first[1] : fallback;
    if (p >= points.last[0]) return points.last.length > 1 ? points.last[1] : fallback;

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final t0 = p0[0];
      final t1 = p1[0];
      if (p >= t0 && p <= t1) {
        final span = t1 - t0;
        if (span <= 0.00001) return p1.length > 1 ? p1[1] : fallback;
        final norm = (p - t0) / span;
        final v0 = p0.length > 1 ? p0[1] : fallback;
        final v1 = p1.length > 1 ? p1[1] : fallback;
        return v0 + (v1 - v0) * norm;
      }
    }
    return points.last.length > 1 ? points.last[1] : fallback;
  }

  double getPitchBendAt(double progress) => interpolateCurve(pitchBendPoints, progress, 0.0);
  double getPressureAt(double progress) => interpolateCurve(pressurePoints, progress, velocity);
  double getTimbreAt(double progress) => interpolateCurve(timbrePoints, progress, 0.5);

  static const List<String> noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  String get pitchName => formatPitch(pitch);

  static String formatPitch(int p) {
    if (p < 0 || p > 127) return 'P$p';
    final octave = (p ~/ 12) - 1;
    return '${noteNames[p % 12]}$octave';
  }

  static int? parsePitch(String text) {
    final clean = text.trim().toUpperCase();
    if (clean.isEmpty) return null;
    final intVal = int.tryParse(clean);
    if (intVal != null && intVal >= 0 && intVal <= 127) return intVal;
    if (clean.startsWith('P')) {
      final pVal = int.tryParse(clean.substring(1));
      if (pVal != null && pVal >= 0 && pVal <= 127) return pVal;
    }

    final regex = RegExp(r'^([A-G][#B]?)(-?\d+)$');
    final match = regex.firstMatch(clean);
    if (match == null) return null;

    final notePart = match.group(1)!;
    final octPart = int.tryParse(match.group(2)!) ?? 4;

    int semitone = 0;
    switch (notePart) {
      case 'C': semitone = 0; break;
      case 'C#': case 'DB': semitone = 1; break;
      case 'D': semitone = 2; break;
      case 'D#': case 'EB': semitone = 3; break;
      case 'E': semitone = 4; break;
      case 'F': semitone = 5; break;
      case 'F#': case 'GB': semitone = 6; break;
      case 'G': semitone = 7; break;
      case 'G#': case 'AB': semitone = 8; break;
      case 'A': semitone = 9; break;
      case 'A#': case 'BB': semitone = 10; break;
      case 'B': semitone = 11; break;
      default: return null;
    }
    return ((octPart + 1) * 12 + semitone).clamp(0, 127);
  }

  Note copyWith({
    String? id,
    int? pitch,
    double? startStep,
    double? durationSteps,
    double? velocity,
    int? column,
    String? effectCommand,
    bool? isSlide,
    bool? isAccent,
    String? lyric,
    String? articulation,
    double? releaseVelocity,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
  }) {
    return Note(
      id: id ?? this.id,
      pitch: pitch ?? this.pitch,
      startStep: startStep ?? this.startStep,
      durationSteps: durationSteps ?? this.durationSteps,
      velocity: velocity ?? this.velocity,
      column: column ?? this.column,
      effectCommand: effectCommand ?? this.effectCommand,
      isSlide: isSlide ?? this.isSlide,
      isAccent: isAccent ?? this.isAccent,
      lyric: lyric ?? this.lyric,
      articulation: articulation ?? this.articulation,
      releaseVelocity: releaseVelocity ?? this.releaseVelocity,
      pitchBendPoints: pitchBendPoints ?? (this.pitchBendPoints != null ? List<List<double>>.from(this.pitchBendPoints!.map((e) => List<double>.from(e))) : null),
      pressurePoints: pressurePoints ?? (this.pressurePoints != null ? List<List<double>>.from(this.pressurePoints!.map((e) => List<double>.from(e))) : null),
      timbrePoints: timbrePoints ?? (this.timbrePoints != null ? List<List<double>>.from(this.timbrePoints!.map((e) => List<double>.from(e))) : null),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pitch': pitch,
    'startStep': startStep,
    'durationSteps': durationSteps,
    'velocity': velocity,
    'column': column,
    'effectCommand': effectCommand,
    'isSlide': isSlide,
    'isAccent': isAccent,
    if (lyric != null && lyric!.isNotEmpty) 'lyric': lyric,
    if (articulation != null && articulation!.isNotEmpty) 'articulation': articulation,
    if (releaseVelocity != null) 'releaseVelocity': releaseVelocity,
    if (pitchBendPoints != null && pitchBendPoints!.isNotEmpty) 'pitchBendPoints': pitchBendPoints,
    if (pressurePoints != null && pressurePoints!.isNotEmpty) 'pressurePoints': pressurePoints,
    if (timbrePoints != null && timbrePoints!.isNotEmpty) 'timbrePoints': timbrePoints,
  };

  factory Note.fromJson(Map<String, dynamic> json) {
    final vel = (json['velocity'] as num?)?.toDouble() ?? (json['vel'] as num?)?.toDouble() ?? 0.9;
    final start = (json['startStep'] as num?)?.toDouble() ?? (json['start'] as num?)?.toDouble() ?? 0.0;
    final dur = (json['durationSteps'] as num?)?.toDouble() ?? (json['duration'] as num?)?.toDouble() ?? (json['dur'] as num?)?.toDouble() ?? 1.0;
    final rawSlide = json['isSlide'];
    final rawAccent = json['isAccent'];
    final slideBool = rawSlide is bool ? rawSlide : (rawSlide.toString() == 'true');
    final accentBool = rawAccent is bool ? rawAccent : (rawAccent == null ? vel > 0.75 : rawAccent.toString() == 'true');

    List<List<double>>? parsePoints(dynamic raw) {
      if (raw is List) {
        final list = <List<double>>[];
        for (final item in raw) {
          if (item is List) {
            list.add(item.map((e) => (e as num).toDouble()).toList());
          }
        }
        if (list.isNotEmpty) return list;
      }
      return null;
    }

    return Note(
      id: json['id'] ?? '',
      pitch: json['pitch'] ?? 60,
      startStep: start,
      durationSteps: dur,
      velocity: vel,
      column: json['column'] ?? 0,
      effectCommand: json['effectCommand'] ?? '00',
      isSlide: slideBool,
      isAccent: accentBool,
      lyric: json['lyric'] as String?,
      articulation: json['articulation']?.toString() ?? json['art']?.toString(),
      releaseVelocity: (json['releaseVelocity'] as num?)?.toDouble() ?? (json['relVel'] as num?)?.toDouble() ?? (json['offVel'] as num?)?.toDouble(),
      pitchBendPoints: parsePoints(json['pitchBendPoints'] ?? json['bend']),
      pressurePoints: parsePoints(json['pressurePoints'] ?? json['pressure'] ?? json['press']),
      timbrePoints: parsePoints(json['timbrePoints'] ?? json['timbre'] ?? json['slide']),
    );
  }
}

class StepEvent {
  bool active;
  double velocity;
  int pitch; // Default pitch for drum or note trigger
  bool isSlide;
  bool isAccent;
  bool get hasAccent => isAccent || velocity > 0.75;

  StepEvent({
    this.active = false,
    this.velocity = 0.8,
    this.pitch = 60,
    this.isSlide = false,
    bool? isAccent,
  }) : isAccent = isAccent ?? (velocity > 0.75);

  StepEvent copyWith({bool? active, double? velocity, int? pitch, bool? isSlide, bool? isAccent}) {
    return StepEvent(
      active: active ?? this.active,
      velocity: velocity ?? this.velocity,
      pitch: pitch ?? this.pitch,
      isSlide: isSlide ?? this.isSlide,
      isAccent: isAccent ?? this.isAccent,
    );
  }

  Map<String, dynamic> toJson() => {
    'active': active,
    'velocity': velocity,
    'pitch': pitch,
    'isSlide': isSlide,
    'isAccent': isAccent,
  };

  factory StepEvent.fromJson(Map<String, dynamic> json) {
    final vel = (json['velocity'] as num?)?.toDouble() ?? 0.8;
    final rawAccent = json['isAccent'] ?? json['accent'];
    return StepEvent(
      active: json['active'] ?? false,
      velocity: vel,
      pitch: json['pitch'] ?? 60,
      isSlide: json['isSlide'] ?? json['slide'] ?? false,
      isAccent: rawAccent is bool ? rawAccent : (rawAccent == null ? vel > 0.75 : rawAccent.toString() == 'true'),
    );
  }
}

enum FXType {
  biquadFilter,
  delay,
  distortion,
  bitcrusher,
  convolutionReverb,
  compressor,
  limiter,
  vintageTape,
  eatScriptFX;

}

class FXInsert {
  String id;
  String name;
  FXType type;
  bool enabled;
  double mix; // Dry/Wet 0.0 - 1.0
  Map<String, double> params; // e.g. 'cutoff': 2000, 'resonance': 3.0
  String? irSampleName; // Active Impulse Response name for convolutionReverb
  String? eatScriptCode; // Full Eatscript code if Eatscript FX / visualizer
  String? presetId; // Preset identifier from EatScriptLibrary
  Map<String, double> eatScriptParams; // Custom Eatscript params

  FXInsert({
    required this.id,
    required this.name,
    required this.type,
    this.enabled = true,
    this.mix = 0.5,
    required this.params,
    this.irSampleName,
    this.eatScriptCode,
    this.presetId,
    Map<String, double>? eatScriptParams,
  }) : eatScriptParams = eatScriptParams ?? {};

  bool get isEatScriptFX => type == FXType.eatScriptFX || (eatScriptCode != null && eatScriptCode!.isNotEmpty);

  factory FXInsert.create(
    FXType type, {
    String? name,
    String? eatScriptCode,
    String? presetId,
    Map<String, double>? eatScriptParams,
  }) {
    final code = eatScriptCode;
    final pMap = eatScriptParams;
    final id = 'fx_${DateTime.now().millisecondsSinceEpoch}_${type.name}';
    switch (type) {
      case FXType.convolutionReverb:
        return FXInsert(
          id: id,
          name: name ?? 'Convolution Reverb',
          type: FXType.convolutionReverb,
          mix: 0.5,
          params: {'DryLevel': 1.0, 'WetLevel': 0.5, 'PreDelayMs': 10.0, 'HighCut': 8000.0},
          irSampleName: 'Great Hall',
          eatScriptCode: code,
          presetId: presetId,
          eatScriptParams: pMap,
        );

      case FXType.distortion:
        return FXInsert(
          id: id,
          name: name ?? 'Tube Distortion',
          type: FXType.distortion,
          mix: 0.5,
          params: {'Drive': 0.5, 'Tone': 5000.0},
          eatScriptCode: code,
          presetId: presetId,
          eatScriptParams: pMap,
        );
      case FXType.bitcrusher:
        return FXInsert(
          id: id,
          name: name ?? 'Bitcrusher 8-Bit',
          type: FXType.bitcrusher,
          mix: 0.6,
          params: {'Bits': 8.0, 'Downsample': 4.0},
          eatScriptCode: code,
          presetId: presetId,
          eatScriptParams: pMap,
        );
      case FXType.delay:
        return FXInsert(
          id: id,
          name: name ?? 'Stereo Delay',
          type: FXType.delay,
          mix: 0.3,
          params: {'TimeMs': 250.0, 'Feedback': 0.4},
          eatScriptCode: code,
          presetId: presetId,
          eatScriptParams: pMap,
        );
      case FXType.compressor:
        return FXInsert(
          id: id,
          name: name ?? 'Dynamics Compressor',
          type: FXType.compressor,
          mix: 1.0,
          params: {
            'Threshold': -18.0,
            'Ratio': 4.0,
            'Attack': 0.02,
            'Release': 0.25,
            'Knee': 12.0,
          },
          eatScriptCode: code,
          presetId: presetId,
          eatScriptParams: pMap,
        );
      case FXType.limiter:
        return FXInsert(
          id: id,
          name: name ?? 'Master Limiter',
          type: FXType.limiter,
          mix: 1.0,
          params: {
            'Threshold': -1.0,
            'Release': 0.05,
            'Ceiling': -0.1,
          },
          eatScriptCode: code,
          presetId: presetId,
          eatScriptParams: pMap,
        );
      case FXType.vintageTape:
        return FXInsert(
          id: id,
          name: name ?? 'Eats Vinyl',
          type: FXType.vintageTape,
          mix: 1.0,
          params: {
            'Era': 1974.0,
            'Medium': 2.0,
            'WowDepth': 25.0,
            'FlutterDepth': 15.0,
            'MotorJitter': 10.0,
            'WarpSwell': 20.0,
            'TapeDropouts': 15.0,
            'LevelDrift': 10.0,
            'NeedleBumpFreq': 25.0,
            'StutterDepth': 35.0,
            'ThudLevel': 30.0,
            'TapeWarmth': 45.0,
            'HeadBump': 3.0,
            'HissLevel': 20.0,
            'VinylCrackle': 25.0,
            'GrooveRumble': 15.0,
            'StopTime': 0.8,
            'SpinUpTime': 0.4,
          },
          eatScriptCode: code,
          presetId: presetId ?? 'vintage_era_degrader',
          eatScriptParams: pMap,
        );
      case FXType.eatScriptFX:
        return FXInsert(
          id: id,
          name: name ?? 'EatScript FX',
          type: FXType.eatScriptFX,
          mix: 1.0,
          params: {},
          eatScriptCode: code,
          presetId: presetId,
          eatScriptParams: pMap,
        );
      case FXType.biquadFilter:
      default:
        return FXInsert(
          id: id,
          name: name ?? 'Lowpass Filter',
          type: FXType.biquadFilter,
          mix: 1.0,
          params: {'Cutoff': 3500.0, 'Resonance': 1.5},
          eatScriptCode: code,
          presetId: presetId,
          eatScriptParams: pMap,
        );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'enabled': enabled,
    'mix': mix,
    'params': params,
    'irSampleName': irSampleName,
    'eatScriptCode': eatScriptCode,
    'presetId': presetId,
    'eatScriptParams': eatScriptParams,
  };

  factory FXInsert.fromJson(Map<String, dynamic> json) => FXInsert(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    type: json['type'] == 'eatScriptFX'
        ? FXType.eatScriptFX
        : FXType.values.firstWhere((e) => e.name == json['type'], orElse: () => FXType.biquadFilter),
    enabled: json['enabled'] ?? true,
    mix: (json['mix'] as num?)?.toDouble() ?? 0.5,
    params: Map<String, double>.from(json['params'] ?? {}),
    irSampleName: json['irSampleName'] as String?,
    eatScriptCode: (json['eatScriptCode'] ?? json['eatScriptCode']) as String?,
    presetId: json['presetId'] as String?,
    eatScriptParams: Map<String, double>.from(json['eatScriptParams'] ?? json['eatScriptParams'] ?? {}),
  );
}

class MidiFXInsert {
  String id;
  String name;
  bool enabled;
  String eatScriptCode;
  Map<String, double> eatScriptParams;

  MidiFXInsert({
    required this.id,
    required this.name,
    this.enabled = true,
    this.eatScriptCode = '',
    Map<String, double>? eatScriptParams,
  }) : eatScriptParams = eatScriptParams ?? {};

  MidiFXInsert copyWith({
    String? id,
    String? name,
    bool? enabled,
    String? eatScriptCode,
    Map<String, double>? eatScriptParams,
  }) {
    return MidiFXInsert(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      eatScriptCode: eatScriptCode ?? this.eatScriptCode,
      eatScriptParams: eatScriptParams ?? Map.from(this.eatScriptParams),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'eatScriptCode': eatScriptCode,
    'eatScriptParams': eatScriptParams,
  };

  factory MidiFXInsert.fromJson(Map<String, dynamic> json) => MidiFXInsert(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    enabled: json['enabled'] ?? true,
    eatScriptCode: (json['eatScriptCode'] ?? json['eatScriptCode']) ?? '',
    eatScriptParams: Map<String, double>.from(json['eatScriptParams'] ?? json['eatScriptParams'] ?? {}),
  );
}

class TrackClip {
  String id;
  String name;
  String trackId;
  int startBar; // 0, 1, 2, 3...
  int barLength; // 1, 2, 4, 8...
  int patternIndex; // 0..255 (00..FF Hex Pattern Index)
  List<Note> notes;
  List<LyricCue> lyrics;
  String eatScriptCode;
  Map<String, double> eatScriptParams;

  List<Note>? evaluatedNotesCache;
  List<AutomationLane> automationLanes;

  int? loopLengthBars; // Length in bars of repeated pattern loop (null or equals barLength if unlooped)

  // Audio Clip & Linked MIDI Transcription
  bool isAudioClip;
  String? audioSampleName;
  double audioPitchOffset; // Semitones (-24.0 to +24.0)
  List<Note> embeddedTranscribedNotes;

  String get patternHex => patternIndex.toRadixString(16).padLeft(2, '0').toUpperCase();
  int get effectiveLoopLengthBars => (loopLengthBars != null && loopLengthBars! > 0) ? loopLengthBars! : barLength;
  bool get isLooped => loopLengthBars != null && loopLengthBars! > 0 && loopLengthBars! < barLength;

  bool get hasLyrics => lyrics.isNotEmpty || notes.any((n) => n.lyric != null && n.lyric!.isNotEmpty);
  bool get hasEmbeddedMidi => embeddedTranscribedNotes.isNotEmpty;

  bool get hasMidiScript {
    if (eatScriptCode.trim().isEmpty) return false;
    final lower = eatScriptCode.toLowerCase();
    return lower.contains('transform_notes') ||
        lower.contains('def process') ||
        lower.contains('function process') ||
        lower.contains('midi.') ||
        lower.contains('chord.') ||
        lower.contains('@category: midifx') ||
        lower.contains('chord_follow') ||
        lower.contains('chord_arp') ||
        lower.contains('chord_stabs') ||
        lower.contains('arpeggiat') ||
        lower.contains('arp');
  }

  TrackClip({
    required this.id,
    required this.name,
    required this.trackId,
    this.startBar = 0,
    this.barLength = 2,
    this.patternIndex = 0,
    this.loopLengthBars,
    List<Note>? notes,
    List<LyricCue>? lyrics,
    String? eatScriptCode,
    Map<String, double>? eatScriptParams,
    this.evaluatedNotesCache,
    List<AutomationLane>? automationLanes,
    this.isAudioClip = false,
    this.audioSampleName,
    this.audioPitchOffset = 0.0,
    List<Note>? embeddedTranscribedNotes,
  })  : notes = notes ?? [],
        lyrics = lyrics ?? [],
        eatScriptCode = eatScriptCode ?? '',
        eatScriptParams = eatScriptParams ?? {},
        automationLanes = automationLanes ?? [],
        embeddedTranscribedNotes = embeddedTranscribedNotes ?? [];

  TrackClip copyWith({
    String? id,
    String? name,
    String? trackId,
    int? startBar,
    int? barLength,
    int? patternIndex,
    int? loopLengthBars,
    List<Note>? notes,
    List<LyricCue>? lyrics,
    String? eatScriptCode,
    Map<String, double>? eatScriptParams,
    List<Note>? evaluatedNotesCache,
    List<AutomationLane>? automationLanes,
    bool? isAudioClip,
    String? audioSampleName,
    double? audioPitchOffset,
    List<Note>? embeddedTranscribedNotes,
  }) {
    return TrackClip(
      id: id ?? this.id,
      name: name ?? this.name,
      trackId: trackId ?? this.trackId,
      startBar: startBar ?? this.startBar,
      barLength: barLength ?? this.barLength,
      patternIndex: patternIndex ?? this.patternIndex,
      loopLengthBars: loopLengthBars ?? this.loopLengthBars,
      notes: notes ?? this.notes.map((n) => n.copyWith()).toList(),
      lyrics: lyrics ?? this.lyrics.map((l) => l.copyWith()).toList(),
      eatScriptCode: eatScriptCode ?? this.eatScriptCode,
      eatScriptParams: eatScriptParams ?? Map.from(this.eatScriptParams),
      evaluatedNotesCache: evaluatedNotesCache ?? (this.evaluatedNotesCache != null ? this.evaluatedNotesCache!.map((n) => n.copyWith()).toList() : null),
      automationLanes: automationLanes ?? this.automationLanes.map((a) => a.copyWith()).toList(),
      isAudioClip: isAudioClip ?? this.isAudioClip,
      audioSampleName: audioSampleName ?? this.audioSampleName,
      audioPitchOffset: audioPitchOffset ?? this.audioPitchOffset,
      embeddedTranscribedNotes: embeddedTranscribedNotes ?? this.embeddedTranscribedNotes.map((n) => n.copyWith()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trackId': trackId,
    'startBar': startBar,
    'barLength': barLength,
    'patternIndex': patternIndex,
    if (loopLengthBars != null) 'loopLengthBars': loopLengthBars,
    'notes': notes.map((n) => n.toJson()).toList(),
    'lyrics': lyrics.map((l) => l.toJson()).toList(),
    'eatScriptCode': eatScriptCode,
    'eatScriptParams': eatScriptParams,
    'automationLanes': automationLanes.map((a) => a.toJson()).toList(),
    'isAudioClip': isAudioClip,
    if (audioSampleName != null) 'audioSampleName': audioSampleName,
    'audioPitchOffset': audioPitchOffset,
    'embeddedTranscribedNotes': embeddedTranscribedNotes.map((n) => n.toJson()).toList(),
  };

  factory TrackClip.fromJson(Map<String, dynamic> json) => TrackClip(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    trackId: json['trackId'] ?? '',
    startBar: json['startBar'] ?? 0,
    barLength: json['barLength'] ?? 2,
    patternIndex: (json['patternIndex'] as num?)?.toInt() ?? 0,
    loopLengthBars: (json['loopLengthBars'] as num?)?.toInt(),
    notes: (json['notes'] as List?)?.map((n) => Note.fromJson(n)).toList() ?? [],
    lyrics: (json['lyrics'] as List?)?.map((l) => LyricCue.fromJson(l)).toList() ?? [],
    eatScriptCode: (json['eatScriptCode'] ?? json['eatScriptCode']) ?? '',
    eatScriptParams: Map<String, double>.from(json['eatScriptParams'] ?? json['eatScriptParams'] ?? {}),
    automationLanes: (json['automationLanes'] as List?)
            ?.map((a) => AutomationLane.fromJson(a))
            .toList() ??
        [],
    isAudioClip: json['isAudioClip'] ?? false,
    audioSampleName: json['audioSampleName'] as String?,
    audioPitchOffset: (json['audioPitchOffset'] as num?)?.toDouble() ?? 0.0,
    embeddedTranscribedNotes: (json['embeddedTranscribedNotes'] as List?)?.map((n) => Note.fromJson(n)).toList() ?? [],
  );
}

/// A zero-allocation mutating map wrapper for track parameters that notifies
/// the track to invalidate its cached synthesis parameter hash when any value changes.
class _TrackParamMap with MapMixin<String, double> {
  final Map<String, double> _inner;
  final VoidCallback _onMutated;

  _TrackParamMap(this._inner, this._onMutated);

  @override
  double? operator [](Object? key) => _inner[key];

  @override
  void operator []=(String key, double value) {
    if (_inner[key] != value) {
      _inner[key] = value;
      _onMutated();
    }
  }

  @override
  void clear() {
    if (_inner.isNotEmpty) {
      _inner.clear();
      _onMutated();
    }
  }

  @override
  Iterable<String> get keys => _inner.keys;

  @override
  double? remove(Object? key) {
    final removed = _inner.remove(key);
    if (removed != null) {
      _onMutated();
    }
    return removed;
  }

  @override
  void addAll(Map<String, double> other) {
    bool changed = false;
    for (final entry in other.entries) {
      if (_inner[entry.key] != entry.value) {
        _inner[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) {
      _onMutated();
    }
  }
}

class TrackChannel {
  String id;
  String name;
  Color color;
  TrackType _type;
  TrackType get type => _type;
  set type(TrackType val) {
    if (_type != val) {
      _type = val;
      invalidateParamsHash();
    }
  }

  double volume; // 0.0 to 1.5
  double pan; // -1.0 to 1.0
  bool isMuted;
  bool isSoloed;
  
  // Instrument config
  String _sampleName;
  String get sampleName => _sampleName;
  set sampleName(String val) {
    if (_sampleName != val) {
      _sampleName = val;
      invalidateParamsHash();
    }
  }

  String _synthWaveform;
  String get synthWaveform => _synthWaveform;
  set synthWaveform(String val) {
    if (_synthWaveform != val) {
      _synthWaveform = val;
      invalidateParamsHash();
    }
  }

  double _cutoff;
  double get cutoff => _cutoff;
  set cutoff(double val) {
    if (_cutoff != val) {
      _cutoff = val;
      invalidateParamsHash();
    }
  }

  double resonance;

  double _attack;
  double get attack => _attack;
  set attack(double val) {
    if (_attack != val) {
      _attack = val;
      invalidateParamsHash();
    }
  }

  double _release;
  double get release => _release;
  set release(double val) {
    if (_release != val) {
      _release = val;
      invalidateParamsHash();
    }
  }

  // TTS & Lyrics Config
  bool enableTts;
  String? ttsVoice;
  double ttsPitch;
  double ttsRate;
  double ttsVolume;
  List<LyricCue> lyrics;

  // EatScript engine plugin integration
  String _eatScriptCode;
  late Map<String, double> _eatScriptParams;

  int? _cachedParamsHash;
  EatSynthType? _resolvedSynthType;

  /// Invalidates the pre-calculated parameter hash when values or code mutate.
  void invalidateParamsHash() {
    _cachedParamsHash = null;
    _resolvedSynthType = null;
  }

  /// Cached resolved synth engine type to bypass script inspection on synthesis.
  EatSynthType? get resolvedSynthType => _resolvedSynthType;
  set resolvedSynthType(EatSynthType? type) => _resolvedSynthType = type;

  /// Cached deterministic hash of track synthesis parameters and script source.
  int get paramsHash {
    if (_cachedParamsHash != null) return _cachedParamsHash!;
    int h = _type.hashCode ^
        _sampleName.hashCode ^
        _synthWaveform.hashCode ^
        _eatScriptCode.hashCode ^
        (_cutoff * 100).round() ^
        (_attack * 10000).round() ^
        (_release * 10000).round();
    final sortedKeys = _eatScriptParams.keys.toList()..sort();
    for (final k in sortedKeys) {
      final v = _eatScriptParams[k] ?? 0.0;
      h = (h * 31) ^ (k.hashCode ^ (v * 10000).round());
    }
    _cachedParamsHash = h;
    return h;
  }

  String get eatScriptCode => _eatScriptCode;
  set eatScriptCode(String val) {
    if (_eatScriptCode != val) {
      _eatScriptCode = val;
      invalidateParamsHash();
    }
  }

  Map<String, double> get eatScriptParams => _eatScriptParams;
  set eatScriptParams(Map<String, double> val) {
    _eatScriptParams = _TrackParamMap(Map.from(val), invalidateParamsHash);
    invalidateParamsHash();
  }

  /// Sets or updates a single synthesis parameter and invalidates the cached parameter hash.
  void setParam(String key, double value) {
    _eatScriptParams[key] = value;
  }

  // Pattern steps & Piano Roll notes & Per-track clips
  List<StepEvent> steps; // 16 or 32 step grid
  List<Note> notes; // Active clip notes
  List<TrackClip> clips; // Per-track arrangement clips

  // Unified Note Selection State across all views (Piano Roll, Tracker, Score, Script)
  Set<String> selectedNoteIds;

  List<Note> get selectedNotes => notes.where((n) => selectedNoteIds.contains(n.id)).toList();
  bool isNoteSelected(String id) => selectedNoteIds.contains(id);
  bool get hasSelectedNotes => selectedNoteIds.isNotEmpty;

  // Automation Lanes for continuous & discrete parameters
  List<AutomationLane> automationLanes;

  // FX Racks
  List<FXInsert> fxRack; // Audio FX Rack
  List<MidiFXInsert> midiFXRack; // MIDI FX Rack

  // Multi-View Config
  int trackerColumns; // Number of tracker sub-channel columns for polyphony (default 4)
  MusicViewType activeView; // Active view for this track (pianoRoll, tracker, score)
  bool isMonophonic;
  ChordFollowMode chordFollowMode;

  // Track Freeze / Bake State (Pre-rendered offline PCM stream)
  bool isFrozen;
  bool isBaking;
  Float32List? frozenAudioBuffer; // Contiguous rendered stereo/mono PCM Float32 stream
  int frozenSampleRate;
  double frozenDurationSec;
  String? frozenContentHash; // Deterministic hash of Eatscript code, parameters, notes & FX

  bool get hasValidBake => isFrozen && frozenAudioBuffer != null && frozenAudioBuffer!.isNotEmpty;

  // Folder & Grouping Configuration
  String? parentFolderId; // ID of parent folder track (null if top-level)
  bool isCollapsed; // When true, child tracks are collapsed/hidden in Arranger/Mixer
  bool isFolderBus; // If true, route child audio through folder's FX rack
  bool syncColorWithChildren; // When true, changing folder color propagates to children

  bool get isFolder => type == TrackType.folder;
  bool get isChildTrack => parentFolderId != null && parentFolderId!.isNotEmpty;

  bool get hasLyrics =>
      lyrics.isNotEmpty ||
      clips.any((c) => c.hasLyrics) ||
      notes.any((n) => n.lyric != null && n.lyric!.isNotEmpty);

  bool get isMonophonicTrack =>
      isMonophonic ||
      type == TrackType.bass ||
      type == TrackType.tts ||
      name.toLowerCase().contains('303') ||
      name.toLowerCase().contains('bass') ||
      eatScriptCode.contains('Eats303') ||
      eatScriptCode.contains('Eats-303') ||
      eatScriptCode.contains('eats_303') ||
      eatScriptCode.contains('JC303') ||
      eatScriptCode.contains('JC-303') ||
      eatScriptCode.contains('Acid303') ||
      eatScriptCode.contains('TB303') ||
      eatScriptCode.contains('polyphony = 1') ||
      eatScriptCode.contains('setPolyphony(1)');

  /// Determines whether this track represents a drum, percussion, or kit instrument.
  bool get isDrumTrack =>
      type == TrackType.sampler ||
      name.toLowerCase().contains('drum') ||
      name.toLowerCase().contains('beat') ||
      name.toLowerCase().contains('kit') ||
      name.toLowerCase().contains('percussion') ||
      name.toLowerCase().contains('kick') ||
      name.toLowerCase().contains('snare') ||
      name.toLowerCase().contains('hihat') ||
      name.toLowerCase().contains('hat') ||
      name.toLowerCase().contains('tom') ||
      name.toLowerCase().contains('cymbal') ||
      name.toLowerCase().contains('clap') ||
      name.toLowerCase().contains('rim') ||
      name.toLowerCase().contains('cowbell') ||
      name.toLowerCase().contains('shaker') ||
      name.toLowerCase().contains('conga') ||
      name.toLowerCase().contains('bongo') ||
      name.toLowerCase().contains('808') ||
      name.toLowerCase().contains('909') ||
      name.toLowerCase().contains('707') ||
      name.toLowerCase().contains('linn') ||
      name.toLowerCase().contains('dMX') ||
      name.toLowerCase().contains('cr-78') ||
      eatScriptCode.contains('drum_machine') ||
      eatScriptCode.contains('snes_drum') ||
      eatScriptCode.contains('analog_drum') ||
      eatScriptCode.contains('c64_drum') ||
      eatScriptCode.contains('synth_drum') ||
      eatScriptCode.contains('tr909') ||
      eatScriptCode.contains('tr808') ||
      eatScriptCode.contains('cr78');

  String iconName; // e.g. 'synth', 'drums', 'bass', 'vocal', 'lead', 'fx', 'sampler', 'piano', 'guitar', 'waveform', 'code', 'music', 'tts', 'folder'

  IconData get iconData {
    switch (iconName.toLowerCase()) {
      case 'folder':
      case 'folder_open':
      case 'group':
        return isCollapsed ? Icons.folder : Icons.folder_open;
      case 'synth':
      case 'piano':
        return Icons.piano;
      case 'drums':
        return Icons.album;
      case 'bass':
        return Icons.waves;
      case 'tts':
      case 'speech':
        return Icons.record_voice_over;
      case 'vocal':
      case 'mic':
        return Icons.mic;
      case 'lead':
        return Icons.bolt;
      case 'fx':
        return Icons.tune;
      case 'sampler':
      case 'wav':
        return Icons.graphic_eq;
      case 'guitar':
        return Icons.queue_music;
      case 'headset':
        return Icons.headset;
      case 'speaker':
        return Icons.speaker;
      case 'code':
      case 'eatscript':
        return Icons.code;
      case 'memory':
      case 'bits':
        return Icons.memory;
      case 'music':
      default:
        return isFolder ? (isCollapsed ? Icons.folder : Icons.folder_open) : Icons.music_note;
    }
  }

  // Built-in Channel Strip 4-Band Parametric EQ (HPF, Low Shelf, Mid Peak, High Shelf)
  bool eqEnabled;
  double eqHpf; // 20.0 to 500.0 Hz (default 20.0)
  double eqLowGain; // -18.0 to +18.0 dB at ~100Hz (default 0.0)
  double eqMidFreq; // 200.0 to 8000.0 Hz (default 1000.0)
  double eqMidGain; // -18.0 to +18.0 dB (default 0.0)
  double eqMidQ; // 0.3 to 10.0 (default 1.0)
  double eqHighGain; // -18.0 to +18.0 dB at ~8000Hz (default 0.0)

  // Semantic Instrument Tags for AI Mixing & Categorization
  List<String> tags; // e.g. ["kick", "acoustic"], ["synth_bass"], ["piano"]

  List<String> get effectiveTags {
    if (tags.isNotEmpty) return tags;
    return inferredMixTags;
  }

  String get primaryTag {
    if (tags.isNotEmpty) return tags.first;
    final lowerName = name.toLowerCase();
    if (lowerName.contains('kick')) return 'kick';
    if (lowerName.contains('snare')) return 'snare';
    if (lowerName.contains('clap')) return 'clap';
    if (lowerName.contains('hihat') || lowerName.contains('hat')) return 'hihat';
    if (lowerName.contains('bass') || lowerName.contains('303') || lowerName.contains('808') || lowerName.contains('sub')) return 'bass';
    if (lowerName.contains('piano') || lowerName.contains('keys') || lowerName.contains('rhodes')) return 'piano';
    if (lowerName.contains('guitar') || lowerName.contains('gtr') || lowerName.contains('strum')) return 'guitar';
    if (lowerName.contains('vocal') || lowerName.contains('vox') || lowerName.contains('speech')) return 'vocal';
    if (lowerName.contains('lead')) return 'lead';
    if (lowerName.contains('pad') || lowerName.contains('string') || lowerName.contains('choir')) return 'pad';
    if (type == TrackType.sampler) return sampleName;
    return type.name;
  }

  List<String> get inferredMixTags {
    final lowerName = name.toLowerCase();
    final List<String> list = [];

    if (lowerName.contains('kick')) {
      list.addAll(['kick', 'drums', 'sub_anchor', 'transient_punch', 'mono_center', 'sub_preserve_30hz']);
    } else if (lowerName.contains('snare')) {
      list.addAll(['snare', 'drums', 'mid_dominant', 'punchy_attack', 'hpf_safe_80hz', 'mud_cut_300hz']);
    } else if (lowerName.contains('clap')) {
      list.addAll(['clap', 'drums', 'high_presence', 'stereo_wide', 'hpf_safe_120hz']);
    } else if (lowerName.contains('hihat') || lowerName.contains('hi-hat') || lowerName.contains('hat') || lowerName.contains('cymbal') || lowerName.contains('ride') || lowerName.contains('crash')) {
      list.addAll(['hihat', 'cymbals', 'drums', 'air_sparkle', 'hpf_safe_200hz']);
    } else if (lowerName.contains('tom') || lowerName.contains('cowbell') || lowerName.contains('rim') || lowerName.contains('perc')) {
      list.addAll(['percussion', 'drums', 'dynamic_expressive', 'hpf_safe_100hz']);
    } else if (lowerName.contains('303') || lowerName.contains('sub') || lowerName.contains('808') || lowerName.contains('moog') || lowerName.contains('synth bass')) {
      list.addAll(['synth_bass', 'bass', 'sub_anchor', 'mono_center', 'sub_preserve_30hz']);
    } else if (lowerName.contains('fretless') || lowerName.contains('upright') || lowerName.contains('double bass') || lowerName.contains('acoustic bass')) {
      list.addAll(['acoustic_bass', 'bass', 'low_warmth', 'dynamic_expressive', 'mono_center']);
    } else if (lowerName.contains('bass')) {
      list.addAll(['bass', 'sub_anchor', 'mono_center']);
    } else if (lowerName.contains('grand') || lowerName.contains('upright piano') || lowerName.contains('felt') || lowerName.contains('piano')) {
      list.addAll(['acoustic_piano', 'piano', 'keys', 'midrange', 'stereo_wide', 'dynamic_expressive', 'hpf_safe_80hz']);
    } else if (lowerName.contains('rhodes') || lowerName.contains('dx7') || lowerName.contains('wurlitzer') || lowerName.contains('epiano') || lowerName.contains('e-piano')) {
      list.addAll(['electric_piano', 'keys', 'low_mid_warmth', 'stereo_wide', 'hpf_safe_100hz']);
    } else if (lowerName.contains('clavinet') || lowerName.contains('harpsichord') || lowerName.contains('cembalo') || lowerName.contains('organ')) {
      list.addAll(['keys', 'percussive_keys', 'high_presence', 'hpf_safe_120hz']);
    } else if (lowerName.contains('acoustic guitar') || lowerName.contains('spanish') || lowerName.contains('flamenco') || lowerName.contains('steel guitar') || lowerName.contains('12-string') || lowerName.contains('dobro') || lowerName.contains('harp guitar')) {
      list.addAll(['acoustic_guitar', 'guitar', 'plucked_strings', 'mid_dominant', 'dynamic_expressive', 'hpf_safe_100hz']);
    } else if (lowerName.contains('ukulele') || lowerName.contains('lute') || lowerName.contains('banjo') || lowerName.contains('mandolin')) {
      list.addAll(['folk_strings', 'plucked_strings', 'high_presence', 'hpf_safe_150hz']);
    } else if (lowerName.contains('guitar') || lowerName.contains('gtr') || lowerName.contains('strum')) {
      list.addAll(['guitar', 'mid_dominant', 'dynamic_expressive', 'hpf_safe_100hz']);
    } else if (lowerName.contains('violin') || lowerName.contains('viola') || lowerName.contains('solo string')) {
      list.addAll(['solo_strings', 'lead', 'high_presence', 'dynamic_expressive', 'hpf_safe_150hz']);
    } else if (lowerName.contains('cello') || lowerName.contains('string ensemble') || lowerName.contains('strings') || lowerName.contains('symphonic')) {
      list.addAll(['orchestral_strings', 'strings', 'pad', 'low_mid_warmth', 'stereo_wide', 'hpf_safe_80hz']);
    } else if (lowerName.contains('vocal') || lowerName.contains('vox') || lowerName.contains('voice') || lowerName.contains('speech') || lowerName.contains('tts')) {
      list.addAll(['vocal', 'lead', 'mid_dominant', 'intimate_center', 'hpf_safe_120hz', 'mud_cut_300hz']);
    } else if (lowerName.contains('lead') || lowerName.contains('volts') || lowerName.contains('fire')) {
      list.addAll(['synth_lead', 'lead', 'presence_bite', 'hpf_safe_100hz']);
    } else if (lowerName.contains('pad') || lowerName.contains('water') || lowerName.contains('ambient') || lowerName.contains('choir')) {
      list.addAll(['synth_pad', 'pad', 'ambient_wash', 'stereo_wide', 'hpf_safe_120hz']);
    } else {
      if (type == TrackType.sampler) {
        list.addAll(['sample', sampleName, 'dynamic_expressive']);
      } else {
        list.addAll([type.name, 'synthesizer']);
      }
    }
    return list;
  }

  TrackChannel({
    required this.id,
    required this.name,
    required this.color,
    TrackType type = TrackType.synth,
    this.volume = 0.8,
    this.pan = 0.0,
    this.isMuted = false,
    this.isSoloed = false,
    String sampleName = 'kick',
    String synthWaveform = 'sawtooth',
    double cutoff = 3000.0,
    this.resonance = 1.0,
    double attack = 0.01,
    double release = 0.3,
    this.eqEnabled = false,
    this.eqHpf = 20.0,
    this.eqLowGain = 0.0,
    this.eqMidFreq = 1000.0,
    this.eqMidGain = 0.0,
    this.eqMidQ = 1.0,
    this.eqHighGain = 0.0,
    List<String>? tags,
    bool? enableTts,
    this.ttsVoice,
    this.ttsPitch = 1.0,
    this.ttsRate = 1.0,
    this.ttsVolume = 1.0,
    List<LyricCue>? lyrics,
    String? iconName,
    String? eatScriptCode,
    Map<String, double>? eatScriptParams,
    this.trackerColumns = 4,
    this.activeView = MusicViewType.pianoRoll,
    this.isMonophonic = false,
    this.chordFollowMode = ChordFollowMode.off,
    this.parentFolderId,
    this.isCollapsed = false,
    this.isFolderBus = true,
    this.syncColorWithChildren = true,
    this.isFrozen = false,
    this.isBaking = false,
    this.frozenAudioBuffer,
    this.frozenSampleRate = 44100,
    this.frozenDurationSec = 0.0,
    this.frozenContentHash,
    List<StepEvent>? steps,
    List<Note>? notes,
    List<TrackClip>? clips,
    List<AutomationLane>? automationLanes,
    List<FXInsert>? fxRack,
    List<MidiFXInsert>? midiFXRack,
    Set<String>? selectedNoteIds,
  })  : _type = type,
        _sampleName = sampleName,
        _synthWaveform = synthWaveform,
        _cutoff = cutoff,
        _attack = attack,
        _release = release,
        tags = tags ?? [],
        enableTts = enableTts ?? (type == TrackType.tts),
        lyrics = lyrics ?? [],
        iconName = iconName ?? _defaultIconForType(type),
        _eatScriptCode = eatScriptCode ?? '',
        steps = steps ?? List.generate(32, (_) => StepEvent()),
        notes = notes ?? [],
        clips = clips ?? [],
        selectedNoteIds = selectedNoteIds ?? {},
        automationLanes = automationLanes ?? [],
        fxRack = fxRack ?? [],
        midiFXRack = midiFXRack ?? [] {
    final initialMap = Map<String, double>.from(eatScriptParams ?? {});
    _eatScriptParams = _TrackParamMap(initialMap, invalidateParamsHash);
  }

  static String _defaultIconForType(TrackType type) {
    switch (type) {
      case TrackType.synth:
        return 'synth';
      case TrackType.sampler:
        return 'sampler';
      case TrackType.bass:
        return 'bass';
      case TrackType.eatScript:
        return 'code';
      case TrackType.tts:
        return 'tts';
      case TrackType.folder:
        return 'folder';
    }
  }

  TrackChannel copyWith({
    String? id,
    String? name,
    Color? color,
    TrackType? type,
    double? volume,
    double? pan,
    bool? isMuted,
    bool? isSoloed,
    String? sampleName,
    String? synthWaveform,
    double? cutoff,
    double? resonance,
    double? attack,
    double? release,
    bool? eqEnabled,
    double? eqHpf,
    double? eqLowGain,
    double? eqMidFreq,
    double? eqMidGain,
    double? eqMidQ,
    double? eqHighGain,
    List<String>? tags,
    bool? enableTts,
    String? ttsVoice,
    double? ttsPitch,
    double? ttsRate,
    double? ttsVolume,
    List<LyricCue>? lyrics,
    String? iconName,
    String? eatScriptCode,
    int? trackerColumns,
    MusicViewType? activeView,
    bool? isMonophonic,
    ChordFollowMode? chordFollowMode,
    bool? isFrozen,
    bool? isBaking,
    Float32List? frozenAudioBuffer,
    int? frozenSampleRate,
    double? frozenDurationSec,
    String? frozenContentHash,
    String? parentFolderId,
    bool? isCollapsed,
    bool? isFolderBus,
    bool? syncColorWithChildren,
    Map<String, double>? eatScriptParams,
    List<StepEvent>? steps,
    List<Note>? notes,
    List<TrackClip>? clips,
    List<AutomationLane>? automationLanes,
    List<FXInsert>? fxRack,
    List<MidiFXInsert>? midiFXRack,
    Set<String>? selectedNoteIds,
  }) {
    return TrackChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      type: type ?? this.type,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      isMuted: isMuted ?? this.isMuted,
      isSoloed: isSoloed ?? this.isSoloed,
      sampleName: sampleName ?? this.sampleName,
      synthWaveform: synthWaveform ?? this.synthWaveform,
      cutoff: cutoff ?? this.cutoff,
      resonance: resonance ?? this.resonance,
      attack: attack ?? this.attack,
      release: release ?? this.release,
      eqEnabled: eqEnabled ?? this.eqEnabled,
      eqHpf: eqHpf ?? this.eqHpf,
      eqLowGain: eqLowGain ?? this.eqLowGain,
      eqMidFreq: eqMidFreq ?? this.eqMidFreq,
      eqMidGain: eqMidGain ?? this.eqMidGain,
      eqMidQ: eqMidQ ?? this.eqMidQ,
      eqHighGain: eqHighGain ?? this.eqHighGain,
      tags: tags ?? List.from(this.tags),
      enableTts: enableTts ?? this.enableTts,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      lyrics: lyrics ?? this.lyrics.map((l) => l.copyWith()).toList(),
      iconName: iconName ?? this.iconName,
      eatScriptCode: eatScriptCode ?? this.eatScriptCode,
      trackerColumns: trackerColumns ?? this.trackerColumns,
      activeView: activeView ?? this.activeView,
      isMonophonic: isMonophonic ?? this.isMonophonic,
      chordFollowMode: chordFollowMode ?? this.chordFollowMode,
      isFrozen: isFrozen ?? this.isFrozen,
      isBaking: isBaking ?? this.isBaking,
      frozenAudioBuffer: frozenAudioBuffer ?? this.frozenAudioBuffer,
      frozenSampleRate: frozenSampleRate ?? this.frozenSampleRate,
      frozenDurationSec: frozenDurationSec ?? this.frozenDurationSec,
      frozenContentHash: frozenContentHash ?? this.frozenContentHash,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      isFolderBus: isFolderBus ?? this.isFolderBus,
      syncColorWithChildren: syncColorWithChildren ?? this.syncColorWithChildren,
      eatScriptParams: eatScriptParams ?? Map.from(this.eatScriptParams),
      steps: steps ?? this.steps.map((s) => s.copyWith()).toList(),
      notes: notes ?? this.notes.map((n) => n.copyWith()).toList(),
      clips: clips ?? this.clips.map((c) => c.copyWith()).toList(),
      selectedNoteIds: selectedNoteIds ?? Set.from(this.selectedNoteIds),
      automationLanes: automationLanes ?? this.automationLanes.map((a) => a.copyWith()).toList(),
      fxRack: fxRack ?? List.from(this.fxRack),
      midiFXRack: midiFXRack ?? List.from(this.midiFXRack),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.value,
    'type': type.name,
    'iconName': iconName,
    'volume': volume,
    'pan': pan,
    'isMuted': isMuted,
    'isSoloed': isSoloed,
    'sampleName': sampleName,
    'synthWaveform': synthWaveform,
    'cutoff': cutoff,
    'resonance': resonance,
    'attack': attack,
    'release': release,
    'eqEnabled': eqEnabled,
    'eqHpf': eqHpf,
    'eqLowGain': eqLowGain,
    'eqMidFreq': eqMidFreq,
    'eqMidGain': eqMidGain,
    'eqMidQ': eqMidQ,
    'eqHighGain': eqHighGain,
    if (tags.isNotEmpty) 'tags': tags,
    'enableTts': enableTts,
    if (ttsVoice != null) 'ttsVoice': ttsVoice,
    'ttsPitch': ttsPitch,
    'ttsRate': ttsRate,
    'ttsVolume': ttsVolume,
    'lyrics': lyrics.map((l) => l.toJson()).toList(),
    'eatScriptCode': eatScriptCode,
    'trackerColumns': trackerColumns,
    'activeView': activeView.name,
    'isMonophonic': isMonophonic,
    'chordFollowMode': chordFollowMode.name,
    'isFrozen': isFrozen,
    if (frozenContentHash != null) 'frozenContentHash': frozenContentHash,
    if (parentFolderId != null) 'parentFolderId': parentFolderId,
    'isCollapsed': isCollapsed,
    'isFolderBus': isFolderBus,
    'syncColorWithChildren': syncColorWithChildren,
    'eatScriptParams': eatScriptParams,
    'steps': steps.map((s) => s.toJson()).toList(),
    'notes': notes.map((n) => n.toJson()).toList(),
    'automationLanes': automationLanes.map((a) => a.toJson()).toList(),
    'fxRack': fxRack.map((f) => f.toJson()).toList(),
    'midiFXRack': midiFXRack.map((f) => f.toJson()).toList(),
  };

  factory TrackChannel.fromJson(Map<String, dynamic> json) => TrackChannel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    color: Color(json['color'] ?? 0xFF4A90E2),
    type: json['type'] == 'eatScript'
        ? TrackType.eatScript
        : TrackType.values.firstWhere((e) => e.name == json['type'], orElse: () => TrackType.synth),
    iconName: json['iconName'],
    volume: (json['volume'] as num?)?.toDouble() ?? 0.8,
    pan: (json['pan'] as num?)?.toDouble() ?? 0.0,
    isMuted: json['isMuted'] ?? false,
    isSoloed: json['isSoloed'] ?? false,
    sampleName: json['sampleName'] ?? 'kick',
    synthWaveform: json['synthWaveform'] ?? 'sawtooth',
    cutoff: (json['cutoff'] as num?)?.toDouble() ?? 3000.0,
    resonance: (json['resonance'] as num?)?.toDouble() ?? 1.0,
    attack: (json['attack'] as num?)?.toDouble() ?? 0.01,
    release: (json['release'] as num?)?.toDouble() ?? 0.3,
    eqEnabled: json['eqEnabled'] ?? false,
    eqHpf: (json['eqHpf'] as num?)?.toDouble() ?? 20.0,
    eqLowGain: (json['eqLowGain'] as num?)?.toDouble() ?? 0.0,
    eqMidFreq: (json['eqMidFreq'] as num?)?.toDouble() ?? 1000.0,
    eqMidGain: (json['eqMidGain'] as num?)?.toDouble() ?? 0.0,
    eqMidQ: (json['eqMidQ'] as num?)?.toDouble() ?? 1.0,
    eqHighGain: (json['eqHighGain'] as num?)?.toDouble() ?? 0.0,
    tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    enableTts: json['enableTts'] ?? (json['type'] == 'tts'),
    ttsVoice: json['ttsVoice'] as String?,
    ttsPitch: (json['ttsPitch'] as num?)?.toDouble() ?? 1.0,
    ttsRate: (json['ttsRate'] as num?)?.toDouble() ?? 1.0,
    ttsVolume: (json['ttsVolume'] as num?)?.toDouble() ?? 1.0,
    lyrics: (json['lyrics'] as List?)?.map((l) => LyricCue.fromJson(l)).toList() ?? [],
    eatScriptCode: (json['eatScriptCode'] ?? json['eatScriptCode']) ?? '',
    eatScriptParams: Map<String, double>.from(json['eatScriptParams'] ?? json['eatScriptParams'] ?? {}),
    trackerColumns: json['trackerColumns'] ?? 4,
    activeView: MusicViewType.values.firstWhere((e) => e.name == json['activeView'], orElse: () => MusicViewType.pianoRoll),
    isMonophonic: json['isMonophonic'] ?? false,
    chordFollowMode: ChordFollowMode.values.firstWhere((e) => e.name == json['chordFollowMode'], orElse: () => ChordFollowMode.off),
    isFrozen: json['isFrozen'] ?? false,
    frozenContentHash: json['frozenContentHash'] as String?,
    parentFolderId: json['parentFolderId'] as String?,
    isCollapsed: json['isCollapsed'] ?? false,
    isFolderBus: json['isFolderBus'] ?? true,
    syncColorWithChildren: json['syncColorWithChildren'] ?? true,
    steps: (json['steps'] as List?)?.map((s) => StepEvent.fromJson(s)).toList() ?? List.generate(32, (_) => StepEvent()),
    notes: (json['notes'] as List?)?.map((n) => Note.fromJson(n)).toList() ?? [],
    clips: (json['clips'] as List?)?.map((c) => TrackClip.fromJson(c)).toList() ?? [],
    automationLanes: (json['automationLanes'] as List?)?.map((a) => AutomationLane.fromJson(a)).toList() ?? [],
    fxRack: (json['fxRack'] as List?)?.map((f) => FXInsert.fromJson(f)).toList() ?? [],
    midiFXRack: (json['midiFXRack'] as List?)?.map((f) => MidiFXInsert.fromJson(f)).toList() ?? [],
  );
}

class Pattern {
  String id;
  String name;
  int lengthSteps; // 16 or 32
  List<TrackChannel> tracks;

  int get barLength => (lengthSteps / 16).ceil().clamp(1, 64);

  Pattern({
    required this.id,
    required this.name,
    this.lengthSteps = 16,
    required this.tracks,
  });
}

class ArrangementItem {
  String patternId;
  int startBar;
  int barLength;

  ArrangementItem({
    required this.patternId,
    required this.startBar,
    this.barLength = 1,
  });
}
