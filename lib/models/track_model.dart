import 'package:flutter/material.dart';
import 'automation_model.dart';

enum MusicViewType { pianoRoll, tracker, script, score }
enum TrackType { sampler, synth, luaScript, bass;
  // Backward compatibility getter
  bool get isScript => this == TrackType.luaScript;
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
  double velocity; // 0.0 to 1.0
  int column; // Tracker sub-channel column index (0..N)
  String effectCommand; // Hex effect command (e.g., "00", "V90", "P12")
  bool isSlide;
  bool isAccent;

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
  }) : isAccent = isAccent ?? (velocity > 0.75);

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
  };

  factory Note.fromJson(Map<String, dynamic> json) {
    final vel = (json['velocity'] as num?)?.toDouble() ?? 0.9;
    final rawSlide = json['isSlide'];
    final rawAccent = json['isAccent'];
    final slideBool = rawSlide is bool ? rawSlide : (rawSlide.toString() == 'true');
    final accentBool = rawAccent is bool ? rawAccent : (rawAccent == null ? vel > 0.75 : rawAccent.toString() == 'true');
    return Note(
      id: json['id'] ?? '',
      pitch: json['pitch'] ?? 60,
      startStep: (json['startStep'] as num?)?.toDouble() ?? 0.0,
      durationSteps: (json['durationSteps'] as num?)?.toDouble() ?? 1.0,
      velocity: vel,
      column: json['column'] ?? 0,
      effectCommand: json['effectCommand'] ?? '00',
      isSlide: slideBool,
      isAccent: accentBool,
    );
  }
}

class StepEvent {
  bool active;
  double velocity;
  int pitch; // Default pitch for drum or note trigger
  bool isSlide;
  bool isAccent;

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
    return StepEvent(
      active: json['active'] ?? false,
      velocity: vel,
      pitch: json['pitch'] ?? 60,
      isSlide: json['isSlide'] ?? false,
      isAccent: json['isAccent'] ?? (vel > 0.75),
    );
  }
}

enum FXType { biquadFilter, delay, distortion, bitcrusher, convolutionReverb, compressor, limiter, luaFX }

class FXInsert {
  String id;
  String name;
  FXType type;
  bool enabled;
  double mix; // Dry/Wet 0.0 - 1.0
  Map<String, double> params; // e.g. 'cutoff': 2000, 'resonance': 3.0
  String? irSampleName; // Active Impulse Response name for convolutionReverb
  String? luaScriptCode; // Full Lua script code if Lua FX / visualizer
  String? presetId; // Preset identifier from LuaPresetLibrary
  Map<String, double> luaParams; // Custom Lua params

  FXInsert({
    required this.id,
    required this.name,
    required this.type,
    this.enabled = true,
    this.mix = 0.5,
    required this.params,
    this.irSampleName,
    this.luaScriptCode,
    this.presetId,
    Map<String, double>? luaParams,
  }) : luaParams = luaParams ?? {};

  bool get isLuaFX => type == FXType.luaFX || (luaScriptCode != null && luaScriptCode!.isNotEmpty);

  factory FXInsert.create(
    FXType type, {
    String? name,
    String? luaScriptCode,
    String? presetId,
    Map<String, double>? luaParams,
  }) {
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
          luaScriptCode: luaScriptCode,
          presetId: presetId,
          luaParams: luaParams,
        );

      case FXType.distortion:
        return FXInsert(
          id: id,
          name: name ?? 'Tube Distortion',
          type: FXType.distortion,
          mix: 0.5,
          params: {'Drive': 0.5, 'Tone': 5000.0},
          luaScriptCode: luaScriptCode,
          presetId: presetId,
          luaParams: luaParams,
        );
      case FXType.bitcrusher:
        return FXInsert(
          id: id,
          name: name ?? 'Bitcrusher 8-Bit',
          type: FXType.bitcrusher,
          mix: 0.6,
          params: {'Bits': 8.0, 'Downsample': 4.0},
          luaScriptCode: luaScriptCode,
          presetId: presetId,
          luaParams: luaParams,
        );
      case FXType.delay:
        return FXInsert(
          id: id,
          name: name ?? 'Stereo Delay',
          type: FXType.delay,
          mix: 0.3,
          params: {'TimeMs': 250.0, 'Feedback': 0.4},
          luaScriptCode: luaScriptCode,
          presetId: presetId,
          luaParams: luaParams,
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
          luaScriptCode: luaScriptCode,
          presetId: presetId,
          luaParams: luaParams,
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
          luaScriptCode: luaScriptCode,
          presetId: presetId,
          luaParams: luaParams,
        );
      case FXType.luaFX:
        return FXInsert(
          id: id,
          name: name ?? 'Lua FX',
          type: FXType.luaFX,
          mix: 1.0,
          params: {},
          luaScriptCode: luaScriptCode,
          presetId: presetId,
          luaParams: luaParams,
        );
      case FXType.biquadFilter:
      default:
        return FXInsert(
          id: id,
          name: name ?? 'Lowpass Filter',
          type: FXType.biquadFilter,
          mix: 1.0,
          params: {'Cutoff': 3500.0, 'Resonance': 1.5},
          luaScriptCode: luaScriptCode,
          presetId: presetId,
          luaParams: luaParams,
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
    'luaScriptCode': luaScriptCode,
    'presetId': presetId,
    'luaParams': luaParams,
  };

  factory FXInsert.fromJson(Map<String, dynamic> json) => FXInsert(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    type: FXType.values.firstWhere((e) => e.name == json['type'], orElse: () => FXType.biquadFilter),
    enabled: json['enabled'] ?? true,
    mix: (json['mix'] as num?)?.toDouble() ?? 0.5,
    params: Map<String, double>.from(json['params'] ?? {}),
    irSampleName: json['irSampleName'] as String?,
    luaScriptCode: json['luaScriptCode'] as String?,
    presetId: json['presetId'] as String?,
    luaParams: Map<String, double>.from(json['luaParams'] ?? {}),
  );
}

class MidiFXInsert {
  String id;
  String name;
  bool enabled;
  String luaScriptCode;
  Map<String, double> luaParams;

  MidiFXInsert({
    required this.id,
    required this.name,
    this.enabled = true,
    this.luaScriptCode = '',
    Map<String, double>? luaParams,
  }) : luaParams = luaParams ?? {};

  MidiFXInsert copyWith({
    String? id,
    String? name,
    bool? enabled,
    String? luaScriptCode,
    Map<String, double>? luaParams,
  }) {
    return MidiFXInsert(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      luaScriptCode: luaScriptCode ?? this.luaScriptCode,
      luaParams: luaParams ?? Map.from(this.luaParams),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'luaScriptCode': luaScriptCode,
    'luaParams': luaParams,
  };

  factory MidiFXInsert.fromJson(Map<String, dynamic> json) => MidiFXInsert(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    enabled: json['enabled'] ?? true,
    luaScriptCode: json['luaScriptCode'] ?? '',
    luaParams: Map<String, double>.from(json['luaParams'] ?? {}),
  );
}

class TrackClip {
  String id;
  String name;
  String trackId;
  int startBar; // 0, 1, 2, 3...
  int barLength; // 1, 2, 4, 8...
  List<Note> notes;
  String luaScriptCode;
  Map<String, double> luaParams;
  List<Note>? evaluatedNotesCache;
  List<AutomationLane> automationLanes;

  bool get hasMidiScript {
    if (luaScriptCode.trim().isEmpty) return false;
    final lower = luaScriptCode.toLowerCase();
    return lower.contains('transform_notes') ||
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
    List<Note>? notes,
    this.luaScriptCode = '',
    Map<String, double>? luaParams,
    this.evaluatedNotesCache,
    List<AutomationLane>? automationLanes,
  })  : notes = notes ?? [],
        luaParams = luaParams ?? {},
        automationLanes = automationLanes ?? [];

  TrackClip copyWith({
    String? id,
    String? name,
    String? trackId,
    int? startBar,
    int? barLength,
    List<Note>? notes,
    String? luaScriptCode,
    Map<String, double>? luaParams,
    List<Note>? evaluatedNotesCache,
    List<AutomationLane>? automationLanes,
  }) {
    return TrackClip(
      id: id ?? this.id,
      name: name ?? this.name,
      trackId: trackId ?? this.trackId,
      startBar: startBar ?? this.startBar,
      barLength: barLength ?? this.barLength,
      notes: notes ?? this.notes.map((n) => n.copyWith()).toList(),
      luaScriptCode: luaScriptCode ?? this.luaScriptCode,
      luaParams: luaParams ?? Map.from(this.luaParams),
      evaluatedNotesCache: evaluatedNotesCache ?? (this.evaluatedNotesCache != null ? this.evaluatedNotesCache!.map((n) => n.copyWith()).toList() : null),
      automationLanes: automationLanes ?? this.automationLanes.map((a) => a.copyWith()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trackId': trackId,
    'startBar': startBar,
    'barLength': barLength,
    'notes': notes.map((n) => n.toJson()).toList(),
    'luaScriptCode': luaScriptCode,
    'luaParams': luaParams,
    'automationLanes': automationLanes.map((a) => a.toJson()).toList(),
  };

  factory TrackClip.fromJson(Map<String, dynamic> json) => TrackClip(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    trackId: json['trackId'] ?? '',
    startBar: json['startBar'] ?? 0,
    barLength: json['barLength'] ?? 2,
    notes: (json['notes'] as List?)?.map((n) => Note.fromJson(n)).toList() ?? [],
    luaScriptCode: json['luaScriptCode'] ?? '',
    luaParams: Map<String, double>.from(json['luaParams'] ?? {}),
    automationLanes: (json['automationLanes'] as List?)
            ?.map((a) => AutomationLane.fromJson(a))
            .toList() ??
        [],
  );
}

class TrackChannel {
  String id;
  String name;
  Color color;
  TrackType type;
  double volume; // 0.0 to 1.5
  double pan; // -1.0 to 1.0
  bool isMuted;
  bool isSoloed;
  
  // Instrument config
  String sampleName; // For sampler (kick, snare, hihat, clap, bass, synth)
  String synthWaveform; // sine, square, sawtooth, triangle
  double cutoff;
  double resonance;
  double attack;
  double release;

  // Lua engine plugin integration
  String luaScriptCode;
  Map<String, double> luaParams;

  // Backwards compatibility getters
  String get wrenScriptCode => luaScriptCode;
  set wrenScriptCode(String val) => luaScriptCode = val;
  Map<String, double> get wrenParams => luaParams;
  set wrenParams(Map<String, double> val) => luaParams = val;

  // Pattern steps & Piano Roll notes & Per-track clips
  List<StepEvent> steps; // 16 or 32 step grid
  List<Note> notes; // Active clip notes
  List<TrackClip> clips; // Per-track arrangement clips

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

  bool get isMonophonicTrack =>
      isMonophonic ||
      type == TrackType.bass ||
      name.toLowerCase().contains('303') ||
      name.toLowerCase().contains('bass') ||
      luaScriptCode.contains('Eats303') ||
      luaScriptCode.contains('Eats-303') ||
      luaScriptCode.contains('eats_303') ||
      luaScriptCode.contains('JC303') ||
      luaScriptCode.contains('JC-303') ||
      luaScriptCode.contains('Acid303') ||
      luaScriptCode.contains('TB303') ||
      luaScriptCode.contains('polyphony = 1') ||
      luaScriptCode.contains('setPolyphony(1)');

  String iconName; // e.g. 'synth', 'drums', 'bass', 'vocal', 'lead', 'fx', 'sampler', 'piano', 'guitar', 'waveform', 'code', 'music'

  IconData get iconData {
    switch (iconName.toLowerCase()) {
      case 'synth':
      case 'piano':
        return Icons.piano;
      case 'drums':
        return Icons.album;
      case 'bass':
        return Icons.waves;
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
      case 'lua':
        return Icons.code;
      case 'memory':
      case 'bits':
        return Icons.memory;
      case 'music':
      default:
        return Icons.music_note;
    }
  }

  TrackChannel({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    this.volume = 0.8,
    this.pan = 0.0,
    this.isMuted = false,
    this.isSoloed = false,
    this.sampleName = 'kick',
    this.synthWaveform = 'sawtooth',
    this.cutoff = 3000.0,
    this.resonance = 1.0,
    this.attack = 0.01,
    this.release = 0.3,
    String? iconName,
    String luaScriptCode = '',
    String wrenScriptCode = '',
    this.trackerColumns = 4,
    this.activeView = MusicViewType.pianoRoll,
    this.isMonophonic = false,
    this.chordFollowMode = ChordFollowMode.off,
    Map<String, double>? luaParams,
    Map<String, double>? wrenParams,
    List<StepEvent>? steps,
    List<Note>? notes,
    List<TrackClip>? clips,
    List<AutomationLane>? automationLanes,
    List<FXInsert>? fxRack,
    List<MidiFXInsert>? midiFXRack,
  })  : iconName = iconName ?? _defaultIconForType(type),
        luaScriptCode = luaScriptCode.isNotEmpty ? luaScriptCode : wrenScriptCode,
        luaParams = luaParams ?? wrenParams ?? {},
        steps = steps ?? List.generate(32, (_) => StepEvent()),
        notes = notes ?? [],
        clips = clips ?? [],
        automationLanes = automationLanes ?? [],
        fxRack = fxRack ?? [],
        midiFXRack = midiFXRack ?? [];

  static String _defaultIconForType(TrackType type) {
    switch (type) {
      case TrackType.synth:
        return 'synth';
      case TrackType.sampler:
        return 'sampler';
      case TrackType.bass:
        return 'bass';
      case TrackType.luaScript:
        return 'code';
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
    String? iconName,
    String? luaScriptCode,
    String? wrenScriptCode,
    int? trackerColumns,
    MusicViewType? activeView,
    bool? isMonophonic,
    ChordFollowMode? chordFollowMode,
    Map<String, double>? luaParams,
    Map<String, double>? wrenParams,
    List<StepEvent>? steps,
    List<Note>? notes,
    List<TrackClip>? clips,
    List<AutomationLane>? automationLanes,
    List<FXInsert>? fxRack,
    List<MidiFXInsert>? midiFXRack,
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
      iconName: iconName ?? this.iconName,
      luaScriptCode: luaScriptCode ?? wrenScriptCode ?? this.luaScriptCode,
      trackerColumns: trackerColumns ?? this.trackerColumns,
      activeView: activeView ?? this.activeView,
      isMonophonic: isMonophonic ?? this.isMonophonic,
      chordFollowMode: chordFollowMode ?? this.chordFollowMode,
      luaParams: luaParams ?? wrenParams ?? Map.from(this.luaParams),
      steps: steps ?? this.steps.map((s) => s.copyWith()).toList(),
      notes: notes ?? this.notes.map((n) => n.copyWith()).toList(),
      clips: clips ?? this.clips.map((c) => c.copyWith()).toList(),
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
    'luaScriptCode': luaScriptCode,
    'wrenScriptCode': luaScriptCode,
    'trackerColumns': trackerColumns,
    'activeView': activeView.name,
    'isMonophonic': isMonophonic,
    'chordFollowMode': chordFollowMode.name,
    'luaParams': luaParams,
    'wrenParams': luaParams,
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
    type: TrackType.values.firstWhere((e) => e.name == json['type'], orElse: () => TrackType.synth),
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
    luaScriptCode: json['luaScriptCode'] ?? json['wrenScriptCode'] ?? '',
    trackerColumns: json['trackerColumns'] ?? 4,
    activeView: MusicViewType.values.firstWhere((e) => e.name == json['activeView'], orElse: () => MusicViewType.pianoRoll),
    isMonophonic: json['isMonophonic'] ?? false,
    chordFollowMode: ChordFollowMode.values.firstWhere((e) => e.name == json['chordFollowMode'], orElse: () => ChordFollowMode.off),
    luaParams: Map<String, double>.from(json['luaParams'] ?? json['wrenParams'] ?? {}),
    steps: (json['steps'] as List?)?.map((s) => StepEvent.fromJson(s)).toList() ?? List.generate(32, (_) => StepEvent()),
    notes: (json['notes'] as List?)?.map((n) => Note.fromJson(n)).toList() ?? [],
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
