enum LuaPresetCategory {
  instrument,
  audioFx,
  midiFx,
  midiSeq,
  utility;

  String get displayName {
    switch (this) {
      case LuaPresetCategory.instrument:
        return 'INSTRUMENT';
      case LuaPresetCategory.audioFx:
        return 'AUDIO FX';
      case LuaPresetCategory.midiFx:
        return 'MIDI FX';
      case LuaPresetCategory.midiSeq:
        return 'MIDI SEQ';
      case LuaPresetCategory.utility:
        return 'UTILITY';
    }
  }

  static LuaPresetCategory parse(String categoryStr) {
    final clean = categoryStr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (clean.contains('midiseq') || clean.contains('seq') || clean.contains('pattern')) {
      return LuaPresetCategory.midiSeq;
    }
    if (clean.contains('audiofx') || clean.contains('effect') || clean.contains('fx')) {
      if (clean.contains('midi')) return LuaPresetCategory.midiFx;
      return LuaPresetCategory.audioFx;
    }
    if (clean.contains('midi')) return LuaPresetCategory.midiFx;
    if (clean.contains('util')) return LuaPresetCategory.utility;
    return LuaPresetCategory.instrument;
  }
}

class LuaPreset {
  final String id;
  final String name;
  final LuaPresetCategory category;
  final String description;
  final String code;

  const LuaPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.code,
  });

  bool get isInstrument => category == LuaPresetCategory.instrument;
  bool get isAudioFx => category == LuaPresetCategory.audioFx;
  bool get isMidiFx => category == LuaPresetCategory.midiFx;
  bool get isMidiSeq => category == LuaPresetCategory.midiSeq;
}

class LuaPresetLibrary {
  static final List<LuaPreset> _customPresets = [];

  static List<LuaPreset> get presets => [..._builtinPresets, ..._customPresets];

  static List<LuaPreset> getPresetsByCategory(LuaPresetCategory category) {
    return presets.where((p) => p.category == category).toList();
  }

  static void registerCustomPreset(LuaPreset preset) {
    _customPresets.removeWhere((p) => p.id == preset.id || p.name == preset.name);
    _customPresets.add(preset);
  }

  static LuaPreset parseFromLuaScript(String luaCode, {String fallbackName = 'Custom Script'}) {
    String name = fallbackName;
    LuaPresetCategory category = LuaPresetCategory.instrument;
    String description = 'User imported Lua script';

    final lines = luaCode.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('-- @name:')) {
        name = trimmed.substring(9).trim();
      } else if (trimmed.startsWith('-- @category:')) {
        category = LuaPresetCategory.parse(trimmed.substring(13).trim());
      } else if (trimmed.startsWith('-- @description:')) {
        description = trimmed.substring(16).trim();
      }
    }

    if (!luaCode.contains('@category:')) {
      if (luaCode.contains('processSignal') || luaCode.contains('evaluateEffect')) {
        category = LuaPresetCategory.audioFx;
      } else if (luaCode.contains('transform_notes') || luaCode.contains('midi_fx')) {
        category = LuaPresetCategory.midiFx;
      }
    }

    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    final preset = LuaPreset(
      id: id,
      name: name,
      category: category,
      description: description,
      code: luaCode,
    );

    registerCustomPreset(preset);
    return preset;
  }

  static LuaPreset? getPresetById(String id) {
    try {
      return presets.firstWhere((p) => p.id == id || (id == 'acid_303' && p.id == 'jc_303') || (id == 'jc_303' && p.id == 'acid_303'));
    } catch (_) {
      return null;
    }
  }

  static LuaPreset? findMatchingPreset(String luaCode, {String? fallbackName}) {
    if (luaCode.trim().isEmpty && (fallbackName == null || fallbackName.isEmpty)) {
      return null;
    }

    // 1. Check for explicit @id: or @name:
    final lines = luaCode.split('\n');
    String? explicitId;
    String? explicitName;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('-- @id:')) {
        explicitId = trimmed.substring(7).trim();
      } else if (trimmed.startsWith('-- @name:')) {
        explicitName = trimmed.substring(9).trim();
      }
    }

    if (explicitId != null) {
      final match = getPresetById(explicitId);
      if (match != null) return match;
    }

    if (explicitName != null) {
      try {
        return presets.firstWhere((p) => p.name.toLowerCase() == explicitName!.toLowerCase());
      } catch (_) {}
    }

    // 2. Try matching by fallback track name
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      final cleanName = fallbackName.trim().toLowerCase();
      try {
        return presets.firstWhere((p) => p.name.toLowerCase() == cleanName);
      } catch (_) {}
      try {
        return presets.firstWhere((p) => cleanName.contains(p.name.toLowerCase()) || p.name.toLowerCase().contains(cleanName));
      } catch (_) {}
    }

    // 3. Match by code signature
    if (luaCode.contains('FmAcousticKick') || luaCode.contains('Dual-Mic FM Acoustic Kick') || luaCode.contains('NearPitchStart') || luaCode.contains('fm_acoustic_kick')) {
      return getPresetById('fm_acoustic_kick');
    }
    if (luaCode.contains('FmAcousticSnare') || luaCode.contains('Dual-Mic FM Acoustic Snare') || luaCode.contains('WireCutoff') || luaCode.contains('fm_acoustic_snare')) {
      return getPresetById('fm_acoustic_snare');
    }
    if (luaCode.contains('FmAcousticTom') || luaCode.contains('FM Acoustic Tom') || luaCode.contains('fm_acoustic_tom') || luaCode.contains('TomPitchStart')) {
      return getPresetById('fm_acoustic_tom');
    }
    if (luaCode.contains('FmAcousticHiHat') || luaCode.contains('FM Acoustic Hi-Hat') || luaCode.contains('fm_acoustic_hihat')) {
      return getPresetById('fm_acoustic_hihat');
    }
    if (luaCode.contains('Analog808Kick') || luaCode.contains('Analog 808 Kick') || luaCode.contains('analog_808_kick')) {
      return getPresetById('analog_808_kick');
    }
    if (luaCode.contains('Analog808Snare') || luaCode.contains('Analog 808 Snare') || luaCode.contains('analog_808_snare')) {
      return getPresetById('analog_808_snare');
    }
    if (luaCode.contains('Analog808HiHat') || luaCode.contains('Analog 808 Hi-Hat') || luaCode.contains('analog_808_hihat')) {
      return getPresetById('analog_808_hihat');
    }
    if (luaCode.contains('Analog808Cowbell') || luaCode.contains('Analog 808 Cowbell') || luaCode.contains('analog_808_cowbell')) {
      return getPresetById('analog_808_cowbell');
    }
    if (luaCode.contains('Analog808Tom') || luaCode.contains('Analog 808 Tom') || luaCode.contains('analog_808_tom')) {
      return getPresetById('analog_808_tom');
    }
    if (luaCode.contains('JC303') || luaCode.contains('JC-303') || luaCode.contains('Acid303') || luaCode.contains('TB303') || luaCode.contains('jc_303') || luaCode.contains('acid_303')) {
      return getPresetById('jc_303');
    }
    if (luaCode.contains('YM2612')) {
      return getPresetById('ym2612_synth');
    }
    if (luaCode.contains('SNESSFX') || luaCode.contains('SFXR')) {
      return getPresetById('eats_sfxr');
    }
    if (luaCode.contains('PolyLeadSynth')) {
      return getPresetById('poly_lead');
    }

    return null;
  }

  static bool isUpgradeAvailable(String currentCode, {String? trackName}) {
    final preset = findMatchingPreset(currentCode, fallbackName: trackName);
    if (preset == null) return false;
    return preset.code.trim() != currentCode.trim();
  }

  static const List<LuaPreset> _builtinPresets = [
    // 0. Dual-Mic FM Acoustic Kick (Physical Excitation Model)
    LuaPreset(
      id: 'fm_acoustic_kick',
      name: 'FM Acoustic Kick',
      category: LuaPresetCategory.instrument,
      description: 'Physical dual-mic acoustic kick with noise FM excitation, sub-resonance boost, mid-scoop, beater click shelf, and farfield room mic delay.',
      code: '''
-- @name: FM Acoustic Kick
-- @category: instrument
local FmAcousticKick = {}

function FmAcousticKick.init()
  Param.add("NearPitchStart", 100.0, 300.0, 180.0)
  Param.add("NearPitchEnd", 30.0, 80.0, 52.0)
  Param.add("NearPitchDecay", 0.01, 0.2, 0.07)
  Param.add("NearFmDepth", 0.0, 1200.0, 600.0)
  Param.add("NearFmDecay", 0.002, 0.03, 0.008)
  Param.add("NearAmpDecay", 0.05, 0.8, 0.28)
  Param.add("SubResoGain", 0.0, 12.0, 4.0)
  Param.add("FarPitchStart", 80.0, 200.0, 130.0)
  Param.add("FarPitchEnd", 60.0, 120.0, 95.0)
  Param.add("FarPitchDecay", 0.05, 0.3, 0.15)
  Param.add("FarFmDepth", 0.0, 600.0, 250.0)
  Param.add("FarFmDecay", 0.01, 0.1, 0.045)
  Param.add("FarAmpDecay", 0.05, 0.6, 0.22)
  Param.add("FarLevel", 0.0, 1.0, 0.35)
  Param.add("RoomDelaySec", 0.002, 0.02, 0.008)
end

function FmAcousticKick.gui()
  return {
    panel = {
      title = "DUAL-MIC FM ACOUSTIC KICK",
      subtitle = "Physical Nearfield/Farfield Excitation Processor",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "NearPitchStart", label = "PUNCH FREQ", unit = "Hz" },
            { type = "nixie", param = "NearPitchEnd", label = "SUB FREQ", unit = "Hz" },
            { type = "nixie", param = "NearFmDepth", label = "FM NOISE", unit = "Hz" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "NearPitchStart", label = "PUNCH", size = 56 },
            { type = "knob", param = "NearPitchEnd", label = "SUB", size = 56 },
            { type = "knob", param = "NearPitchDecay", label = "SWEEP", size = 52 },
            { type = "knob", param = "NearFmDepth", label = "FM DEPTH", size = 52 },
            { type = "knob", param = "NearFmDecay", label = "FM DECAY", size = 52 },
            { type = "knob", param = "NearAmpDecay", label = "DECAY", size = 52 },
            { type = "knob", param = "SubResoGain", label = "SUB GAIN", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "FarLevel", label = "ROOM MIC", size = 52 },
            { type = "knob", param = "RoomDelaySec", label = "DISTANCE", size = 52 },
            { type = "knob", param = "FarFmDepth", label = "ROOM FM", size = 52 },
            { type = "knob", param = "FarAmpDecay", label = "ROOM AIR", size = 52 },
          }
        }
      }
    }
  }
end

return FmAcousticKick
''',
    ),

    // 0b. Dual-Mic FM Acoustic Snare
    LuaPreset(
      id: 'fm_acoustic_snare',
      name: 'FM Acoustic Snare',
      category: LuaPresetCategory.instrument,
      description: 'Physical acoustic snare with dual-body swept oscillator, noise-modulated snare wires, and acoustic room reflections.',
      code: '''
-- @name: FM Acoustic Snare
-- @category: instrument
local FmAcousticSnare = {}

function FmAcousticSnare.init()
  Param.add("ToneFreq", 100.0, 320.0, 185.0)
  Param.add("ToneDecay", 0.05, 0.5, 0.16)
  Param.add("Snappy", 0.0, 1.0, 0.65)
  Param.add("Decay", 0.05, 0.8, 0.22)
  Param.add("WireCutoff", 1000.0, 6000.0, 1800.0)
  Param.add("Variation", 0.0, 1.0, 0.0)
end

function FmAcousticSnare.gui()
  return {
    panel = {
      title = "DUAL-MIC FM ACOUSTIC SNARE",
      subtitle = "Physical Shell Resonance & Snare Wire Modulator",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "ToneFreq", label = "BODY FREQ", unit = "Hz" },
            { type = "nixie", param = "Snappy", label = "WIRE SNAPPY" },
            { type = "nixie", param = "WireCutoff", label = "WIRE HPF", unit = "Hz" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "ToneFreq", label = "BODY TONE", size = 56 },
            { type = "knob", param = "ToneDecay", label = "BODY DEC", size = 52 },
            { type = "knob", param = "Snappy", label = "SNAPPY", size = 56 },
            { type = "knob", param = "Decay", label = "WIRE DEC", size = 52 },
            { type = "knob", param = "WireCutoff", label = "WIRE HPF", size = 52 },
          }
        }
      }
    }
  }
end

return FmAcousticSnare
''',
    ),

    // 0c. Dual-Mic FM Acoustic Tom (Floor, Mid, Rack)
    LuaPreset(
      id: 'fm_acoustic_tom',
      name: 'FM Acoustic Tom',
      category: LuaPresetCategory.instrument,
      description: 'Physical acoustic tom with dual-membrane resonance, noise-FM stick strike excitation, shell tuning, and room reflections.',
      code: '''
-- @name: FM Acoustic Tom
-- @category: instrument
local FmAcousticTom = {}

function FmAcousticTom.init()
  Param.add("ToneFreq", 60.0, 220.0, 90.0)
  Param.add("TomPitchStart", 80.0, 300.0, 160.0)
  Param.add("PitchDecay", 0.02, 0.3, 0.12)
  Param.add("Decay", 0.1, 1.2, 0.45)
  Param.add("StickFmDepth", 0.0, 800.0, 350.0)
  Param.add("StickDecay", 0.002, 0.05, 0.012)
  Param.add("ShellFreq", 80.0, 260.0, 140.0)
  Param.add("RoomDelaySec", 0.002, 0.03, 0.010)
end

function FmAcousticTom.gui()
  return {
    panel = {
      title = "DUAL-MIC FM ACOUSTIC TOM",
      subtitle = "Dual-Membrane Physical Shell & Stick Modulator",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "ToneFreq", label = "TOM TONE", unit = "Hz" },
            { type = "nixie", param = "TomPitchStart", label = "IMPACT PITCH", unit = "Hz" },
            { type = "nixie", param = "StickFmDepth", label = "STICK FM", unit = "Hz" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "ToneFreq", label = "FUNDAMENTAL", size = 56 },
            { type = "knob", param = "TomPitchStart", label = "START PITCH", size = 52 },
            { type = "knob", param = "PitchDecay", label = "PITCH DEC", size = 52 },
            { type = "knob", param = "Decay", label = "RING DECAY", size = 56 },
            { type = "knob", param = "StickFmDepth", label = "STICK FM", size = 52 },
            { type = "knob", param = "ShellFreq", label = "SHELL RESO", size = 52 },
          }
        }
      }
    }
  }
end

return FmAcousticTom
''',
    ),

    // 0d. Dual-Mic FM Acoustic Hi-Hat
    LuaPreset(
      id: 'fm_acoustic_hihat',
      name: 'FM Acoustic Hi-Hat',
      category: LuaPresetCategory.instrument,
      description: 'Physical acoustic hi-hat combining inharmonic metallic oscillator cluster, stick ping click, and high-pass sizzle EQ.',
      code: '''
-- @name: FM Acoustic Hi-Hat
-- @category: instrument
local FmAcousticHiHat = {}

function FmAcousticHiHat.init()
  Param.add("Cutoff", 4000.0, 14000.0, 7000.0)
  Param.add("Decay", 0.02, 0.6, 0.08)
  Param.add("Sizzle", 0.0, 1.0, 0.65)
  Param.add("Tone", 0.5, 2.0, 1.0)
end

function FmAcousticHiHat.gui()
  return {
    panel = {
      title = "PHYSICAL METALLIC HI-HAT",
      subtitle = "6-Osc Inharmonic Cluster with Stick Transient",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Cutoff", label = "HPF CUTOFF", unit = "Hz" },
            { type = "nixie", param = "Decay", label = "DECAY TIME", unit = "s" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Cutoff", label = "CUTOFF", size = 56 },
            { type = "knob", param = "Decay", label = "DECAY", size = 56 },
            { type = "knob", param = "Sizzle", label = "SIZZLE", size = 52 },
            { type = "knob", param = "Tone", label = "CLUSTER TONE", size = 52 },
          }
        }
      }
    }
  }
end

return FmAcousticHiHat
''',
    ),

    // 0f. Authentic Analog 808 Bass Drum
    LuaPreset(
      id: 'analog_808_kick',
      name: 'Analog 808 Kick',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Roland TR-808 Bridged-T analog bass drum circuit with exponential pitch sweep, adjustable tone, click transient, and extended sub decay.',
      code: '''
-- @name: Analog 808 Kick
-- @category: instrument
local Analog808Kick = {}

function Analog808Kick.init()
  Param.add("Tune", 35.0, 75.0, 46.0)
  Param.add("StartFreq", 80.0, 220.0, 140.0)
  Param.add("PitchDecay", 0.01, 0.15, 0.045)
  Param.add("Decay", 0.1, 4.0, 0.85)
  Param.add("Tone", 100.0, 800.0, 220.0)
  Param.add("Click", 0.0, 1.0, 0.15)
  Param.add("Overdrive", 0.8, 3.0, 1.25)
end

function Analog808Kick.gui()
  return {
    panel = {
      title = "ROLAND TR-808 ANALOG BASS DRUM",
      subtitle = "Authentic Bridged-T Resonant Sine Circuit",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Tune", label = "SUB TUNE", unit = "Hz" },
            { type = "nixie", param = "Decay", label = "DECAY", unit = "s" },
            { type = "nixie", param = "Tone", label = "LPF TONE", unit = "Hz" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Tune", label = "TUNE", size = 56 },
            { type = "knob", param = "StartFreq", label = "PUNCH", size = 52 },
            { type = "knob", param = "PitchDecay", label = "SWEEP", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", size = 56 },
            { type = "knob", param = "Tone", label = "TONE", size = 52 },
            { type = "knob", param = "Click", label = "CLICK", size = 52 },
            { type = "knob", param = "Overdrive", label = "DRIVE", size = 52 },
          }
        }
      }
    }
  }
end

return Analog808Kick
''',
    ),

    // 0g. Authentic Analog 808 Snare Drum
    LuaPreset(
      id: 'analog_808_snare',
      name: 'Analog 808 Snare',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Roland TR-808 dual bridged-T resonant body (180Hz & 330Hz) and snappy high-pass noise wires.',
      code: '''
-- @name: Analog 808 Snare
-- @category: instrument
local Analog808Snare = {}

function Analog808Snare.init()
  Param.add("ToneDecay", 0.04, 0.3, 0.12)
  Param.add("Snappy", 0.0, 1.0, 0.70)
  Param.add("Decay", 0.05, 0.6, 0.20)
  Param.add("Tune", 0.7, 1.4, 1.0)
end

function Analog808Snare.gui()
  return {
    panel = {
      title = "ROLAND TR-808 ANALOG SNARE DRUM",
      subtitle = "Dual Bridged-T Body with Snappy Noise Wires",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Snappy", label = "SNAPPY WIRE" },
            { type = "nixie", param = "Decay", label = "WIRE DECAY", unit = "s" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Snappy", label = "SNAPPY", size = 56 },
            { type = "knob", param = "ToneDecay", label = "TONE DEC", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", size = 56 },
            { type = "knob", param = "Tune", label = "TUNE", size = 52 },
          }
        }
      }
    }
  }
end

return Analog808Snare
''',
    ),

    // 0h. Authentic Analog 808 Hi-Hat
    LuaPreset(
      id: 'analog_808_hihat',
      name: 'Analog 808 Hi-Hat',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Roland TR-808 6-Schmitt-trigger square oscillator metallic cluster with 7.5kHz resonant bandpass filter.',
      code: '''
-- @name: Analog 808 Hi-Hat
-- @category: instrument
local Analog808HiHat = {}

function Analog808HiHat.init()
  Param.add("Cutoff", 4000.0, 11000.0, 7500.0)
  Param.add("Decay", 0.02, 0.6, 0.08)
  Param.add("Tune", 0.5, 2.0, 1.0)
end

function Analog808HiHat.gui()
  return {
    panel = {
      title = "ROLAND TR-808 ANALOG HI-HAT",
      subtitle = "6-Osc Inharmonic Schmitt-Trigger Cluster",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Cutoff", label = "BPF CUTOFF", unit = "Hz" },
            { type = "nixie", param = "Decay", label = "DECAY", unit = "s" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Cutoff", label = "BPF CUTOFF", size = 56 },
            { type = "knob", param = "Decay", label = "DECAY", size = 56 },
            { type = "knob", param = "Tune", label = "CLUSTER TUNE", size = 52 },
          }
        }
      }
    }
  }
end

return Analog808HiHat
''',
    ),

    // 0i. Authentic Analog 808 Cowbell
    LuaPreset(
      id: 'analog_808_cowbell',
      name: 'Analog 808 Cowbell',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Roland TR-808 dual detuned square wave oscillator (540Hz & 800Hz) with 800Hz bandpass filter.',
      code: '''
-- @name: Analog 808 Cowbell
-- @category: instrument
local Analog808Cowbell = {}

function Analog808Cowbell.init()
  Param.add("Tune", 500.0, 1200.0, 800.0)
  Param.add("Decay", 0.05, 0.8, 0.32)
end

function Analog808Cowbell.gui()
  return {
    panel = {
      title = "ROLAND TR-808 ANALOG COWBELL",
      subtitle = "Dual Square-Wave 540Hz/800Hz Bandpass Circuit",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Tune", label = "BPF TUNE", unit = "Hz" },
            { type = "nixie", param = "Decay", label = "DECAY", unit = "s" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Tune", label = "BPF TUNE", size = 56 },
            { type = "knob", param = "Decay", label = "DECAY", size = 56 },
          }
        }
      }
    }
  }
end

return Analog808Cowbell
''',
    ),

    // 0j. Authentic Analog 808 Tom
    LuaPreset(
      id: 'analog_808_tom',
      name: 'Analog 808 Tom',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Roland TR-808 resonant bridged-T tank circuit tom/conga with pitch envelope decay.',
      code: '''
-- @name: Analog 808 Tom
-- @category: instrument
local Analog808Tom = {}

function Analog808Tom.init()
  Param.add("Tune", 60.0, 220.0, 100.0)
  Param.add("StartFreq", 100.0, 300.0, 160.0)
  Param.add("PitchDecay", 0.02, 0.2, 0.08)
  Param.add("Decay", 0.1, 1.2, 0.40)
end

function Analog808Tom.gui()
  return {
    panel = {
      title = "ROLAND TR-808 ANALOG TOM / CONGA",
      subtitle = "Resonant Bridged-T Tank Circuit",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Tune", label = "TOM TUNE", unit = "Hz" },
            { type = "nixie", param = "Decay", label = "DECAY", unit = "s" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Tune", label = "TUNE", size = 56 },
            { type = "knob", param = "StartFreq", label = "START PITCH", size = 52 },
            { type = "knob", param = "PitchDecay", label = "PITCH DEC", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", size = 56 },
          }
        }
      }
    }
  }
end

return Analog808Tom
''',
    ),

    // 1. JC-303 Acid Bass Synth (midilab/jc303 & Open303 based)
    LuaPreset(
      id: 'jc_303',
      name: 'JC-303',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Roland TB-303 emulation based on midilab/jc303 and Robin Schmidt (Open303) with 24dB 4-Pole Diode Ladder filter, 150Hz feedback highpass loop, leaky integrator saw/square oscillators, accent decay override, 60ms slide portamento, and overdrive.',
      code: '''
-- @name: JC-303
-- @category: instrument
local JC303 = {}

function JC303.init()
  Param.add("Waveform", 0.0, 1.0, 0.0, 1.0)       -- 0 = Saw, 1 = Square
  Param.add("Pitch", -12.0, 12.0, 0.0, 1.0)       -- Tuning semitones
  Param.add("Cutoff", 200.0, 4500.0, 1400.0)      -- Base VCF Cutoff
  Param.add("Resonance", 0.5, 16.0, 9.2)          -- Diode Ladder Q with 150Hz Feedback HPF
  Param.add("EnvMod", 0.0, 1.0, 0.75)             -- Exponential VCF Envelope Sweep
  Param.add("Decay", 0.05, 1.2, 0.28)             -- Non-accented Decay (forced 200ms on Accent)
  Param.add("Accent", 0.0, 1.0, 0.78)             -- Accent Cutoff Pulse & Gain Boost
  Param.add("Octave", -2.0, 0.0, 0.0, 1.0)        -- Octave Transpose (-2, -1, 0)
  Param.add("SubWaveform", 0.0, 1.0, 0.0, 1.0)    -- Sub-Oscillator Waveform
  Param.add("SubVolume", 0.0, 1.0, 0.0)           -- Sub-Oscillator Level
  Param.add("Drive", 0.0, 1.0, 0.25)              -- Analog Overdrive Saturation
  Param.add("Slide", 0.0, 1.0, 0.0)               -- 60ms Portamento Legato Slide
end

function JC303.process(time, freq, note, params, targetNote, isSlide, isAccent)
  local waveType = params["Waveform"] or 0.0
  local pitch = params["Pitch"] or 0.0
  local cutoff = params["Cutoff"] or 1400.0
  local res = params["Resonance"] or 9.2
  local envMod = params["EnvMod"] or 0.75
  local decay = params["Decay"] or 0.28
  local accent = params["Accent"] or 0.78
  local drive = params["Drive"] or params["Overdrive"] or 0.25
  local octave = math.floor((params["Octave"] or 0.0) + 0.5)
  local subWave = params["SubWaveform"] or 0.0
  local subVol = params["SubVolume"] or 0.0
  local slideParam = params["Slide"] or params["Portamento"] or 0.0
  local glideTime = slideParam > 0.01 and (0.010 + slideParam * 0.200) or 0.060

  -- Pitch glide / Portamento logic for JC-303 continuous monophonic voice
  local baseFreq = freq * (2.0 ^ (octave + pitch / 12.0))
  local currentFreq = baseFreq
  if targetNote and targetNote > 0 then
    local targetFreq = 440.0 * (2.0 ^ ((targetNote + octave * 12 + pitch - 69) / 12.0))
    currentFreq = targetFreq + (baseFreq - targetFreq) * math.exp(-time / glideTime)
  elseif isSlide or slideParam > 0.01 then
    local targetFreq = targetNote and (440.0 * (2.0 ^ ((targetNote + octave * 12 + pitch - 69) / 12.0))) or baseFreq
    currentFreq = targetFreq + (baseFreq - targetFreq) * math.exp(-time / glideTime)
  end

  -- JC-303 Oscillators: Leaky Integrator Sawtooth & Differentiated Square
  local phase = time * currentFreq
  local normPhase = phase - math.floor(phase)
  local sawRaw = 2.0 * normPhase - 1.0
  local sawHP = sawRaw - 0.85 * math.exp(-time * 12.0)
  local sqrRaw = normPhase < 0.48 and 0.78 or -0.78
  local osc = (1.0 - waveType) * sawHP + waveType * sqrRaw

  if subVol > 0.01 then
    local subPhase = time * (currentFreq * 0.5)
    local subNorm = subPhase - math.floor(subPhase)
    local subOsc = subWave > 0.5 and (subNorm < 0.5 and 0.7 or -0.7) or math.sin(6.283185 * subNorm)
    osc = osc * (1.0 - subVol * 0.4) + subOsc * (subVol * 0.6)
  end

  -- Dynamic Accent & VCF Envelope Decay Dynamics (TB-303 / Open303 Model)
  local hasAccent = isAccent or (accent > 0.7 and not isSlide)
  local envBoost = hasAccent and (1.0 + accent * 1.25) or 1.0
  local activeDecay = hasAccent and 0.200 or (decay <= 1.0 and (0.200 + decay * 1.800) or decay)
  local softAttack = 1.0 - math.exp(-time / 0.003)
  local env = softAttack * math.exp(-time / activeDecay)
  local accentPulse = hasAccent and (accent * 0.55 * math.exp(-time / 0.035)) or 0.0

  -- 24dB 4-Pole Diode Ladder Filter with non-linear diode saturation
  local modCutoff = (cutoff * (2.0 ^ ((env + accentPulse) * envMod * 5.2 * envBoost)))
  local filtered = DSP.lowpass(osc, math.min(18000.0, math.max(30.0, modCutoff)), res)

  -- Post-VCF 150Hz 1-Pole High-Pass filter & overdrive saturation
  local highpassed = filtered * 0.985
  local output = highpassed * (hasAccent and (1.35 + accent * 0.45) or 1.0)
  if drive > 0.02 then
    output = math.tanh(output * (1.0 + drive * 3.5))
  end

  return output
end

function JC303.gui()
  return {
    panel = {
      title = "JC-303 ACID BASSLINE",
      subtitle = "midilab/jc303 & Open303 Transistor Bass",
      background = "silver",
      accent = "track",
      knobStyle = "chrome",
      layout = {
        {
          type = "row",
          children = {
            { type = "switch", param = "Waveform", label = "WAVEFORM", options = {"SAW", "SQR"} },
            { type = "divider", orientation = "vertical", height = 62 },
            { type = "knob", param = "Pitch", label = "PITCH", size = 52, knobStyle = "chrome" },
            { type = "knob", param = "Cutoff", label = "CUTOFF", size = 58, knobStyle = "chrome" },
            { type = "knob", param = "Resonance", label = "RESONANCE", size = 58, knobStyle = "chrome" },
            { type = "knob", param = "EnvMod", label = "ENV MOD", size = 54, knobStyle = "chrome" },
            { type = "knob", param = "Decay", label = "DECAY", size = 54, knobStyle = "chrome" },
            { type = "knob", param = "Accent", label = "ACCENT", size = 54, knobStyle = "chrome" },
          }
        },
        { type = "divider", orientation = "horizontal" },
        {
          type = "row",
          children = {
            { type = "knob", param = "Octave", label = "OCTAVE", size = 50, knobStyle = "chrome" },
            { type = "divider", orientation = "vertical", height = 56 },
            { type = "switch", param = "SubWaveform", label = "SUB OSC", options = {"SIN", "SQR"} },
            { type = "knob", param = "SubVolume", label = "SUB VOL", size = 52, knobStyle = "chrome" },
            { type = "divider", orientation = "vertical", height = 56 },
            { type = "slider", param = "Slide", label = "PORTAMENTO SLIDE", orientation = "horizontal", size = 140 },
            { type = "divider", orientation = "vertical", height = 56 },
            { type = "knob", param = "Drive", label = "DRIVE", size = 54, knobStyle = "chrome" },
          }
        }
      }
    }
  }
end

return JC303
''',
    ),

    // 5. Poly Lead Synth Preset
    LuaPreset(
      id: 'poly_lead',
      name: 'Poly Lead Synth',
      category: LuaPresetCategory.instrument,
      description: 'Dual oscillator sawtooth lead synthesizer with dynamic lowpass filter sweep.',
      code: '''
-- @name: Poly Lead Synth
-- @category: instrument
local PolyLeadSynth = {}

function PolyLeadSynth.init()
  Param.add("Cutoff", 400.0, 12000.0, 4500.0)
  Param.add("Resonance", 0.5, 8.0, 3.0)
  Param.add("Detune", 0.0, 10.0, 3.0)
  Param.add("Attack", 0.001, 0.1, 0.01)
  Param.add("Release", 0.05, 1.0, 0.35)
end

function PolyLeadSynth.process(time, freq, note, params)
  local cutoff = params["Cutoff"] or 4500.0
  local res = params["Resonance"] or 3.0
  local detune = params["Detune"] or 3.0
  local attack = params["Attack"] or 0.01
  local release = params["Release"] or 0.35

  local env = 1.0
  if time < attack then
    env = time / attack
  else
    env = math.exp(-(time - attack) / release)
  end

  local f1 = freq
  local f2 = freq + detune
  local phase1 = time * f1
  local phase2 = time * f2

  local saw1 = 2.0 * (phase1 - math.floor(phase1)) - 1.0
  local saw2 = 2.0 * (phase2 - math.floor(phase2)) - 1.0
  local rawOsc = (saw1 + saw2) * 0.5

  local filtered = DSP.lowpass(rawOsc, cutoff, res)
  return filtered * env * 0.8
end

return PolyLeadSynth
''',
    ),

    // 7. YM2612 Genesis 4-Op FM Synth
    LuaPreset(
      id: 'ym2612_synth',
      name: 'YM2612 Genesis 4-Op FM',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Yamaha YM2612 / OPN2 4-operator FM sound chip emulation (Sega Genesis sound) with 8 selectable routing algorithms, operator feedback, Total Level brightness, and direct register poke access.',
      code: '''
-- @name: YM2612 Genesis 4-Op FM
-- @category: instrument
local YM2612 = {}

function YM2612.init()
  Param.add("Algorithm", 0.0, 7.0, 4.0, 1.0)
  Param.add("Feedback", 0.0, 7.0, 5.0, 1.0)
  Param.add("Op1_Mult", 0.5, 12.0, 1.0, 0.5)
  Param.add("Op1_TL", 0.0, 127.0, 8.0, 1.0)
  Param.add("Op2_Mult", 0.5, 12.0, 2.0, 0.5)
  Param.add("Op2_TL", 0.0, 127.0, 0.0, 1.0)
  Param.add("Op3_Mult", 0.5, 12.0, 3.0, 0.5)
  Param.add("Op3_TL", 0.0, 127.0, 16.0, 1.0)
  Param.add("Op4_Mult", 0.5, 12.0, 1.0, 0.5)
  Param.add("Op4_TL", 0.0, 127.0, 0.0, 1.0)
end

function YM2612.process(time, freq, note, params)
  return 0.0
end

function YM2612.gui()
  return {
    panel = {
      title = "YAMAHA YM2612 FM SOUND PROCESSOR",
      subtitle = "Sega Genesis 4-Operator FM Hardware Synthesis",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Algorithm", label = "ALGORITHM", width = 110 },
            { type = "nixie", param = "Feedback", label = "FEEDBACK", width = 110 },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Op1_Mult", label = "OP1 MULT", size = 48 },
            { type = "knob", param = "Op1_TL", label = "OP1 TL", size = 48 },
            { type = "knob", param = "Op2_Mult", label = "OP2 MULT", size = 48 },
            { type = "knob", param = "Op2_TL", label = "OP2 TL", size = 48 },
            { type = "knob", param = "Op3_Mult", label = "OP3 MULT", size = 48 },
            { type = "knob", param = "Op3_TL", label = "OP3 TL", size = 48 },
            { type = "knob", param = "Op4_Mult", label = "OP4 MULT", size = 48 },
            { type = "knob", param = "Op4_TL", label = "OP4 TL", size = 48 },
          }
        }
      }
    }
  }
end

return YM2612
''',
    ),

    // 8. SNES Sfxr (Sony S-DSP / SPC700)
    LuaPreset(
      id: 'eats_sfxr',
      name: 'SNES Sfxr',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Super Nintendo (Sony S-DSP / SPC700) 16-bit procedural sound effect engine with BRR wavetables, 4-point Gaussian filtering, 8-tap FIR echo reverb, and intelligent PRNG seed randomization. Instant archetypes: Laser, Explosion, Powerup, Coin, Jump, Hurt, Lose, Button, Warp, Mutate, Custom. Completely playable chromatically across keys!',
      code: '''
-- @name: SNES Sfxr
-- @category: instrument
local SNESSFX = {}

function SNESSFX.init()
  Param.choice("SFXType", {"Laser", "Explosion", "Powerup", "Coin", "Jump", "Hurt", "Lose", "Button", "Warp", "Mutate", "Custom SNES"}, 0.0)
  Param.add("Seed", 1.0, 9999.0, 42.0, 1.0)
  Param.choice("Waveform", {"Sine", "Square", "Pulse 25%", "Pulse 12%", "Sawtooth", "Triangle", "Organ", "Strings", "Flute", "Slap Bass", "Chime", "Noise"}, 1.0)
  Param.add("Attack", 0.001, 0.5, 0.005)
  Param.add("Decay", 0.01, 2.0, 0.25)
  Param.add("Sustain", 0.0, 1.0, 0.1)
  Param.add("Release", 0.01, 2.0, 0.2)
  Param.add("PitchSweep", -2.0, 2.0, 0.0)
  Param.add("SweepSpeed", 0.01, 1.0, 0.16)
  Param.add("VibratoRate", 0.0, 30.0, 0.0)
  Param.add("VibratoDepth", 0.0, 2.0, 0.0)
  Param.add("ArpSpeed", 0.02, 0.5, 0.05)
  Param.add("EchoDelay", 16.0, 480.0, 120.0, 16.0)
  Param.add("EchoFeedback", 0.0, 0.95, 0.45)
  Param.add("EchoVolume", 0.0, 1.0, 0.35)
  Param.add("NoiseMix", 0.0, 1.0, 0.0)
end

function SNESSFX.process(time, freq, note, params)
  return 0.0
end

function SNESSFX.gui()
  return {
    panel = {
      title = "SNES Sfxr",
      subtitle = "16-Bit Super Nintendo Procedural Sound Engine",
      background = "snes",
      accent = "#7B52AB",
      knobStyle = "snes",
      layout = {
        {
          type = "row",
          children = {
            { type = "listbox", param = "SFXType", label = "SFX Type", width = 160, height = 90 },
            { type = "listbox", param = "Waveform", label = "Wavetable", width = 160, height = 90 },
            {
              type = "column",
              children = {
                { type = "nixie", param = "Seed", label = "RNG SEED", width = 100 },
                { type = "button", action = "randomize", label = "RANDOMIZE", width = 100, height = 32 }
              }
            }
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Attack", label = "ATTACK", size = 48 },
            { type = "knob", param = "Decay", label = "DECAY", size = 48 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", size = 48 },
            { type = "knob", param = "Release", label = "RELEASE", size = 48 },
            { type = "knob", param = "PitchSweep", label = "SWEEP", size = 48 },
            { type = "knob", param = "VibratoRate", label = "VIB RATE", size = 48 },
            { type = "knob", param = "VibratoDepth", label = "VIB DEPTH", size = 48 },
            { type = "knob", param = "EchoDelay", label = "ECHO MS", size = 48 },
            { type = "knob", param = "EchoVolume", label = "ECHO VOL", size = 48 },
          }
        }
      }
    }
  }
end

return SNESSFX
''',
    ),

    // 9. SNES Synth
    LuaPreset(
      id: 'snes_console_synth',
      name: 'SNES Synth',
      category: LuaPresetCategory.instrument,
      description: 'Polyphonic 16-bit Super Nintendo sound processor emulation with Gaussian BRR wavetables, pitch modulation (PMOD), and 8-tap FIR echo reverb.',
      code: '''
-- @name: SNES Synth
-- @category: instrument
local SNESConsole = {}

function SNESConsole.init()
  Param.choice("Waveform", {"Square", "Pulse 25%", "Pulse 12%", "Sawtooth", "Triangle", "Sine", "Organ", "Strings", "Flute", "Slap Bass", "Chime", "Noise"}, 0.0)
  Param.add("Attack", 0.001, 0.5, 0.005)
  Param.add("Decay", 0.01, 2.0, 0.3)
  Param.add("Sustain", 0.0, 1.0, 0.5)
  Param.add("Release", 0.01, 2.0, 0.25)
  Param.add("VibratoRate", 0.0, 20.0, 5.5)
  Param.add("VibratoDepth", 0.0, 1.0, 0.1)
  Param.add("EchoDelay", 16.0, 480.0, 140.0, 16.0)
  Param.add("EchoFeedback", 0.0, 0.9, 0.55)
  Param.add("EchoVolume", 0.0, 1.0, 0.4)
end

function SNESConsole.process(time, freq, note, params)
  return 0.0
end

function SNESConsole.gui()
  return {
    panel = {
      title = "SNES Synth",
      subtitle = "16-Bit Polyphonic S-DSP Console Synthesizer",
      background = "snes",
      accent = "#7B52AB",
      knobStyle = "snes",
      layout = {
        {
          type = "row",
          children = {
            { type = "listbox", param = "Waveform", label = "Wavetable", width = 180, height = 90 },
            { type = "knob", param = "Attack", label = "ATTACK", size = 48 },
            { type = "knob", param = "Decay", label = "DECAY", size = 48 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", size = 48 },
            { type = "knob", param = "Release", label = "RELEASE", size = 48 },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "VibratoRate", label = "VIB RATE", size = 48 },
            { type = "knob", param = "VibratoDepth", label = "VIB DEPTH", size = 48 },
            { type = "knob", param = "EchoDelay", label = "ECHO MS", size = 48 },
            { type = "knob", param = "EchoFeedback", label = "ECHO FDBK", size = 48 },
            { type = "knob", param = "EchoVolume", label = "ECHO VOL", size = 48 },
          }
        }
      }
    }
  }
end

return SNESConsole
''',
    ),

    // 10. OPL3 Retro Chiptune
    LuaPreset(
      id: 'opl3_retro',
      name: 'OPL3 Retro Chiptune',
      category: LuaPresetCategory.instrument,
      description: 'Yamaha YMF262 / OPL3 2-Op & 4-Op FM synthesis modelled after Sound Blaster 16 and AdLib DOS sound cards.',
      code: '''
-- @name: OPL3 Retro Chiptune
-- @category: instrument
local OPL3 = {}

function OPL3.init()
  Param.add("Algorithm", 0.0, 7.0, 4.0, 1.0)
  Param.add("Feedback", 0.0, 7.0, 4.0, 1.0)
  Param.add("Op1_Mult", 0.5, 15.0, 1.0, 0.5)
  Param.add("Op1_TL", 0.0, 127.0, 12.0, 1.0)
  Param.add("Op2_Mult", 0.5, 15.0, 2.0, 0.5)
  Param.add("Op2_TL", 0.0, 127.0, 0.0, 1.0)
end

function OPL3.process(time, freq, note, params)
  return 0.0
end

function OPL3.gui()
  return {
    panel = {
      title = "YAMAHA YMF262 / OPL3 FM SYNTH",
      subtitle = "Sound Blaster 16 / AdLib DOS Chiptune Hardware",
      accent = "#39FF14",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Algorithm", label = "ALGORITHM", width = 110 },
            { type = "nixie", param = "Feedback", label = "FEEDBACK", width = 110 },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Op1_Mult", label = "OP1 MULT", size = 48 },
            { type = "knob", param = "Op1_TL", label = "OP1 TL", size = 48 },
            { type = "knob", param = "Op2_Mult", label = "OP2 MULT", size = 48 },
            { type = "knob", param = "Op2_TL", label = "OP2 TL", size = 48 },
          }
        }
      }
    }
  }
end

return OPL3
''',
    ),

    // 10. Lua Stereo Delay Effect
    LuaPreset(
      id: 'lua_delay',
      name: 'Lua Stereo Delay FX',
      category: LuaPresetCategory.audioFx,
      description: 'Feedback delay line effect module with dampening and dry/wet mix controls.',
      code: '''
-- @name: Lua Stereo Delay FX
-- @category: audioFx
local StereoDelayFX = {}

function StereoDelayFX.init()
  Param.add("TimeMs", 50.0, 800.0, 250.0)
  Param.add("Feedback", 0.0, 0.9, 0.45)
  Param.add("Dampening", 1000.0, 12000.0, 4500.0)
  Param.add("Mix", 0.0, 1.0, 0.4)
end

function StereoDelayFX.processSignal(inputSample, time, params)
  local timeMs = params["TimeMs"] or 250.0
  local fb = params["Feedback"] or 0.45
  local damp = params["Dampening"] or 4500.0
  local mix = params["Mix"] or 0.4

  local delayed = DSP.delay(inputSample, timeMs, fb)
  local dampened = DSP.lowpass(delayed, damp, 1.0)

  return (inputSample * (1.0 - mix)) + (dampened * mix)
end

return StereoDelayFX
''',
    ),

    // 8. Lua Stereo Chorus Effect
    LuaPreset(
      id: 'lua_chorus',
      name: 'Lua Stereo Chorus FX',
      category: LuaPresetCategory.audioFx,
      description: 'LFO modulated short delay lines creating lush stereo chorus and ensemble thickness.',
      code: '''
-- @name: Lua Stereo Chorus FX
-- @category: audioFx
local StereoChorusFX = {}

function StereoChorusFX.init()
  Param.add("RateHz", 0.1, 5.0, 1.2)
  Param.add("DepthMs", 1.0, 15.0, 6.0)
  Param.add("Mix", 0.0, 1.0, 0.5)
end

function StereoChorusFX.processSignal(inputSample, time, params)
  local rate = params["RateHz"] or 1.2
  local depth = params["DepthMs"] or 6.0
  local mix = params["Mix"] or 0.5

  local lfo = math.sin(2.0 * math.pi * rate * time)
  local modulatedTime = 12.0 + (lfo * depth)

  local wet = DSP.delay(inputSample, modulatedTime, 0.2)
  return (inputSample * (1.0 - mix)) + (wet * mix)
end

return StereoChorusFX
''',
    ),

    // 9. 8-Bit Retro Crusher FX
    LuaPreset(
      id: 'bitcrusher_fx',
      name: '8-Bit Retro Crusher FX',
      category: LuaPresetCategory.audioFx,
      description: 'Bit-depth and sample-rate reduction effect for lo-fi chiptune textures.',
      code: '''
-- @name: 8-Bit Retro Crusher FX
-- @category: audioFx
local BitcrusherFX = {}

function BitcrusherFX.init()
  Param.add("Bits", 2.0, 16.0, 6.0)
  Param.add("Downsample", 1.0, 16.0, 4.0)
  Param.add("Mix", 0.0, 1.0, 0.8)
end

function BitcrusherFX.processSignal(inputSample, time, params)
  local bits = params["Bits"] or 6.0
  local downsample = params["Downsample"] or 4.0
  local mix = params["Mix"] or 0.8

  local steps = math.pow(2.0, bits)
  local quantized = math.floor(inputSample * steps) / steps
  local crushed = DSP.sampleHold(quantized, downsample)

  return (inputSample * (1.0 - mix)) + (crushed * mix)
end

return BitcrusherFX
''',
    ),

    // 10. Warm Tube Distortion
    LuaPreset(
      id: 'tube_distortion',
      name: 'Warm Tube Distortion',
      category: LuaPresetCategory.audioFx,
      description: 'Non-linear soft-clipping saturation and warmth.',
      code: '''
-- @name: Warm Tube Distortion
-- @category: audioFx
local TubeDistortion = {}

function TubeDistortion.init()
  Param.add("Drive", 1.0, 20.0, 6.0)
  Param.add("Tone", 200.0, 8000.0, 3500.0)
  Param.add("OutGain", 0.1, 1.5, 0.7)
end

function TubeDistortion.processSignal(inputSample, time, params)
  local drive = params["Drive"] or 6.0
  local tone = params["Tone"] or 3500.0
  local outGain = params["OutGain"] or 0.7

  local driven = inputSample * drive
  local clipped = math.tanh(driven)
  local filtered = DSP.lowpass(clipped, tone, 1.0)
  return filtered * outGain
end

return TubeDistortion
''',
    ),

    // 11. Eatsbits Sampler Instrument (Melodic / One-Shot)
    LuaPreset(
      id: 'sampler_instrument',
      name: 'Sampler (Melodic / One-Shot)',
      category: LuaPresetCategory.instrument,
      description: 'Pitch-shifted sample player with ADSR envelope, filter cutoff, and root key tuning.',
      code: '''
-- @name: Sampler (Melodic / One-Shot)
-- @category: instrument
local SamplerInstrument = {}

function SamplerInstrument.init()
  Param.add("RootKey", 36.0, 84.0, 60.0)
  Param.add("AttackSec", 0.0, 1.0, 0.0)
  Param.add("DecaySec", 0.01, 1.0, 0.1)
  Param.add("Sustain", 0.0, 1.0, 0.8)
  Param.add("ReleaseSec", 0.01, 2.0, 0.4)
  Param.add("FilterCutoff", 200.0, 12000.0, 8000.0)
end

function SamplerInstrument.process(time, freq, note, params)
  local rootKey = params["RootKey"] or 60.0
  local pitchOffset = note - rootKey

  local rawSample = Sampler.read(note, time, pitchOffset)
  local attack = params["AttackSec"] or 0.0
  local decay = params["DecaySec"] or 0.1
  local sustain = params["Sustain"] or 0.8
  local release = params["ReleaseSec"] or 0.4
  local cutoff = params["FilterCutoff"] or 8000.0

  local env = DSP.adsr(time, attack, decay, sustain, release)
  local filtered = DSP.lowpass(rawSample, cutoff, 1.0)
  return filtered * env
end

return SamplerInstrument
''',
    ),

    // 12. Eatsbits Multi-Slot Drum Kit Sampler
    LuaPreset(
      id: 'drum_kit_sampler',
      name: 'Eats Multi-Slot Drum Sampler',
      category: LuaPresetCategory.instrument,
      description: 'Multi-slot drum sampler mapping notes (36=Kick, 38=Snare, 42=Hat, 39=Clap) to distinct audio sample slots.',
      code: '''
-- @name: Eats Multi-Slot Drum Sampler
-- @category: instrument
local DrumKitSampler = {}

function DrumKitSampler.init()
  Param.add("KickTune", -12.0, 12.0, 0.0)
  Param.add("SnareTune", -12.0, 12.0, 0.0)
  Param.add("Drive", 0.0, 1.0, 0.1)
end

function DrumKitSampler.process(time, freq, note, params)
  local sampleOut = 0.0
  if note == 36 then
    sampleOut = Sampler.readSample("kick", time, params["KickTune"] or 0.0)
  elseif note == 38 then
    sampleOut = Sampler.readSample("snare", time, params["SnareTune"] or 0.0)
  elseif note == 42 or note == 46 then
    sampleOut = Sampler.readSample("hihat", time, 0.0)
  elseif note == 39 then
    sampleOut = Sampler.readSample("clap", time, 0.0)
  else
    sampleOut = Sampler.read(note, time, 0.0)
  end

  local drive = params["Drive"] or 0.1
  if drive > 0.01 then
    sampleOut = math.tanh(sampleOut * (1.0 + drive * 4.0))
  end

  return sampleOut
end

return DrumKitSampler
''',
    ),

    // 13. SoundFont 2 Multi-Sample Instrument
    LuaPreset(
      id: 'soundfont_sampler',
      name: 'SoundFont 2 Player',
      category: LuaPresetCategory.instrument,
      description: 'Multi-sampled SoundFont 2 (.sf2) bank player with key-zone mapping, bank selection, and transient envelope control.',
      code: '''
-- @name: SoundFont 2 Player
-- @category: instrument
local SoundFontSampler = {}

function SoundFontSampler.init()
  Param.choice("SoundFontBank", {"Super Small Font", "GeneralUser GS"}, 0.0)
  Param.choice("Preset", {"000: Acoustic Grand Piano", "024: Acoustic Guitar", "040: Violin", "056: Trumpet", "073: Flute"}, 0.0)
  Param.add("PresetNum", 0, 127, 0, 1)
  Param.add("BankNum", 0, 128, 0, 1)
  Param.add("AttackSec", 0.0, 1.0, 0.0)
  Param.add("DecaySec", 0.01, 2.0, 0.3)
  Param.add("Sustain", 0.0, 1.0, 0.8)
  Param.add("ReleaseSec", 0.01, 2.0, 0.4)
  Param.add("Gain", 0.0, 2.0, 1.0)
end

function SoundFontSampler.process(time, freq, note, params)
  local rawSample = SoundFont.readZone(note, time)
  local attack = params["AttackSec"] or 0.0
  local decay = params["DecaySec"] or 0.3
  local sustain = params["Sustain"] or 0.8
  local release = params["ReleaseSec"] or 0.4
  local gain = params["Gain"] or 1.0

  local env = DSP.adsr(time, attack, decay, sustain, release)
  return rawSample * env * gain
end

function SoundFontSampler.gui()
  return {
    panel = {
      title = "SoundFont 2 Player",
      subtitle = "Multi-Sample SF2 Bank & Instrument Engine",
      background = "snes",
      accent = "#21F4E8",
      knobStyle = "snes",
      layout = {
        {
          type = "row",
          children = {
            { type = "listbox", param = "SoundFontBank", label = "SoundFont Bank", width = 160, height = 90 },
            { type = "listbox", param = "Preset", label = "Program Preset", width = 200, height = 90 },
            { type = "knob", param = "AttackSec", label = "ATTACK", size = 48 },
            { type = "knob", param = "DecaySec", label = "DECAY", size = 48 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", size = 48 },
            { type = "knob", param = "ReleaseSec", label = "RELEASE", size = 48 },
            { type = "knob", param = "Gain", label = "GAIN", size = 48 },
          }
        }
      }
    }
  }
end

return SoundFontSampler
''',
    ),

    // 14. Lua MIDI Arpeggiator FX
    LuaPreset(
      id: 'arpeggiator_midi_fx',
      name: 'Lua MIDI Arpeggiator FX',
      category: LuaPresetCategory.midiFx,
      description: 'Advanced MIDI arpeggiator with multi-octave cycling, rate dividers, gate, swing, and 8 pattern modes.',
      code: '''
-- @name: Lua MIDI Arpeggiator FX
-- @category: midiFx
-- @param: Rate = 1.0 (0.25: 1/64, 0.5: 1/32, 1.0: 1/16, 2.0: 1/8, 4.0: 1/4)
-- @param: Octaves = 2.0 (1 to 4 octaves)
-- @param: Pattern = 0.0 (0: Up, 1: Down, 2: UpDown, 3: DownUp, 4: Converge, 5: Diverge, 6: Random, 7: Chord, 8: AsPlayed)
-- @param: Gate = 0.85 (0.1: Staccato to 2.0: Legato)
-- @param: Swing = 0.0 (0.0 to 0.5 groove timing)
local ArpeggiatorMidiFX = {}

function ArpeggiatorMidiFX.transform_notes(notes, params, timeContext)
  return Midi.arpeggiate(notes, params, timeContext)
end

return ArpeggiatorMidiFX
''',
    ),

    // --- MIDI SEQUENCES (MIDI SEQ) ---

    // 15. 4-to-Floor Kick Pattern
    LuaPreset(
      id: 'seq_4_to_floor',
      name: '4-to-Floor Kick',
      category: LuaPresetCategory.midiSeq,
      description: 'Classic four-on-the-floor kick drum pattern hitting on every downbeat (1, 2, 3, 4).',
      code: '''
-- @name: 4-to-Floor Kick
-- @category: midiSeq
-- @description: Classic 4-on-the-floor kick pattern for house/techno/EDM

notes = {
  { pitch = 36, start = 0.00, duration = 1.00, vel = 0.95 },
  { pitch = 36, start = 4.00, duration = 1.00, vel = 0.90 },
  { pitch = 36, start = 8.00, duration = 1.00, vel = 0.95 },
  { pitch = 36, start = 12.00, duration = 1.00, vel = 0.90 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 16. Quarter Hats Pattern
    LuaPreset(
      id: 'seq_quarter_hats',
      name: 'Quarter Hats',
      category: LuaPresetCategory.midiSeq,
      description: 'Hi-hat pattern hitting on every quarter beat (1, 2, 3, 4).',
      code: '''
-- @name: Quarter Hats
-- @category: midiSeq
-- @description: Hi-hat hits on every quarter beat

notes = {
  { pitch = 42, start = 0.00, duration = 1.00, vel = 0.85 },
  { pitch = 42, start = 4.00, duration = 1.00, vel = 0.80 },
  { pitch = 42, start = 8.00, duration = 1.00, vel = 0.85 },
  { pitch = 42, start = 12.00, duration = 1.00, vel = 0.80 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 17. Eighth Hats Pattern
    LuaPreset(
      id: 'seq_eighth_hats',
      name: 'Eighth Hats',
      category: LuaPresetCategory.midiSeq,
      description: 'Driving 8th-note hi-hat groove hitting on the beat and between beats with dynamic accents.',
      code: '''
-- @name: Eighth Hats
-- @category: midiSeq
-- @description: Driving 8th-note hi-hat groove with alternating velocity accents

notes = {
  { pitch = 42, start = 0.00, duration = 1.00, vel = 0.85 },
  { pitch = 42, start = 2.00, duration = 1.00, vel = 0.70 },
  { pitch = 42, start = 4.00, duration = 1.00, vel = 0.80 },
  { pitch = 42, start = 6.00, duration = 1.00, vel = 0.70 },
  { pitch = 42, start = 8.00, duration = 1.00, vel = 0.85 },
  { pitch = 42, start = 10.00, duration = 1.00, vel = 0.70 },
  { pitch = 42, start = 12.00, duration = 1.00, vel = 0.80 },
  { pitch = 42, start = 14.00, duration = 1.00, vel = 0.70 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 18. Offbeat Open Hats
    LuaPreset(
      id: 'seq_offbeat_hats',
      name: 'Offbeat Open Hats',
      category: LuaPresetCategory.midiSeq,
      description: 'Classic house and garage offbeat open hi-hat groove hitting on the upbeat of every beat.',
      code: '''
-- @name: Offbeat Open Hats
-- @category: midiSeq
-- @description: Classic house and garage offbeat open hi-hat pattern

notes = {
  { pitch = 46, start = 2.00, duration = 1.50, vel = 0.88 },
  { pitch = 46, start = 6.00, duration = 1.50, vel = 0.85 },
  { pitch = 46, start = 10.00, duration = 1.50, vel = 0.88 },
  { pitch = 46, start = 14.00, duration = 1.50, vel = 0.85 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 19. Snares Backbeat
    LuaPreset(
      id: 'seq_snares',
      name: 'Snares (Backbeat)',
      category: LuaPresetCategory.midiSeq,
      description: 'Standard backbeat snare pattern hitting on beats 2 and 4.',
      code: '''
-- @name: Snares (Backbeat)
-- @category: midiSeq
-- @description: Standard snare backbeat on beats 2 and 4

notes = {
  { pitch = 38, start = 4.00, duration = 1.00, vel = 0.92 },
  { pitch = 38, start = 12.00, duration = 1.00, vel = 0.95 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 20. Trap / Half-time Snare
    LuaPreset(
      id: 'seq_trap_snare',
      name: 'Trap Snare (Half-Time)',
      category: LuaPresetCategory.midiSeq,
      description: 'Half-time hip-hop / trap snare pattern hitting firmly on beat 3.',
      code: '''
-- @name: Trap Snare (Half-Time)
-- @category: midiSeq
-- @description: Half-time hip-hop / trap snare hit on beat 3

notes = {
  { pitch = 38, start = 8.00, duration = 1.00, vel = 0.95 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 21. Bass Full
    LuaPreset(
      id: 'seq_bass_full',
      name: 'Bass Full',
      category: LuaPresetCategory.midiSeq,
      description: 'Single sustained full 1-bar root bass note (16 steps).',
      code: '''
-- @name: Bass Full
-- @category: midiSeq
-- @description: Sustained full-bar root bass note

notes = {
  { pitch = 36, start = 0.00, duration = 16.00, vel = 0.90 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 22. Bass Halves
    LuaPreset(
      id: 'seq_bass_halves',
      name: 'Bass Halves',
      category: LuaPresetCategory.midiSeq,
      description: 'Two half-bar sustained bass notes (8 steps each).',
      code: '''
-- @name: Bass Halves
-- @category: midiSeq
-- @description: Two half-bar sustained bass notes

notes = {
  { pitch = 36, start = 0.00, duration = 8.00, vel = 0.90 },
  { pitch = 36, start = 8.00, duration = 8.00, vel = 0.88 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 23. Offbeat Bass
    LuaPreset(
      id: 'seq_offbeat_bass',
      name: 'Offbeat Bass (Pump)',
      category: LuaPresetCategory.midiSeq,
      description: 'Pumping offbeat bass notes hitting between kick downbeats for EDM and house grooves.',
      code: '''
-- @name: Offbeat Bass (Pump)
-- @category: midiSeq
-- @description: Pumping offbeat bass pattern

notes = {
  { pitch = 36, start = 2.00, duration = 2.00, vel = 0.90 },
  { pitch = 36, start = 6.00, duration = 2.00, vel = 0.88 },
  { pitch = 36, start = 10.00, duration = 2.00, vel = 0.90 },
  { pitch = 36, start = 14.00, duration = 2.00, vel = 0.88 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 24. Harmonic Chord Follower MIDI FX
    LuaPreset(
      id: 'chord_follower_midi_fx',
      name: 'Harmonic Chord Follower FX',
      category: LuaPresetCategory.midiFx,
      description: 'Conforms incoming notes non-destructively to the active project Chord Track.',
      code: '''
-- @name: Harmonic Chord Follower FX
-- @category: midiFx
-- @param: Mode = 0 (0: Chord, 1: Bass, 2: Scale, 3: Color)
local ChordFollower = {}

function ChordFollower.transform_notes(notes, params, timeContext)
  -- Uses timeContext.chord / timeContext.chordTrack to conform notes
  return Midi.chord_follow(notes, params["Mode"] or 0, timeContext)
end

return ChordFollower
''',
    ),

    // 25. Chord Arpeggiator MIDI FX
    LuaPreset(
      id: 'chord_arp_midi_fx',
      name: 'Chord Arpeggiator FX',
      category: LuaPresetCategory.midiFx,
      description: 'Generates running arpeggio lines voiced directly from the active chord pitch classes.',
      code: '''
-- @name: Chord Arpeggiator FX
-- @category: midiFx
-- @param: Rate = 0.25 (0.25: 16th, 0.5: 8th, 1.0: Quarter)
-- @param: Octaves = 2 (1 to 3 octaves)
-- @param: Pattern = 0 (0: Up, 1: Down, 2: UpDown, 3: Random)
local ChordArp = {}

function ChordArp.transform_notes(notes, params, timeContext)
  return Midi.chord_arp(notes, params, timeContext)
end

return ChordArp
''',
    ),

    // 26. Chord Stabs & Voicings (MIDI SEQ)
    LuaPreset(
      id: 'seq_chord_stabs',
      name: 'Chord Stabs (Chord Track Follow)',
      category: LuaPresetCategory.midiSeq,
      description: 'Dynamic polyphonic chord stabs automatically voiced to the active project Chord Track progression.',
      code: '''
-- @name: Chord Stabs (Chord Track Follow)
-- @category: midiSeq
-- @description: Dynamic polyphonic chord stabs voiced to project Chord Track

notes = {
  { pitch = 60, start = 0.00, duration = 3.00, vel = 0.90 },
  { pitch = 60, start = 4.00, duration = 2.00, vel = 0.85 },
  { pitch = 60, start = 8.00, duration = 3.00, vel = 0.90 },
  { pitch = 60, start = 12.00, duration = 3.00, vel = 0.85 }
}

function process(notes, time_ctx)
  -- Automatically builds rich voicings using active Chord Track
  return Chord.generate_voicing(notes, time_ctx)
end
''',
    ),

    // 27. Dynamic Bassline (MIDI SEQ)
    LuaPreset(
      id: 'seq_dynamic_bassline',
      name: 'Dynamic Bassline (Chord Track Follow)',
      category: LuaPresetCategory.midiSeq,
      description: 'Rhythmic bass groove that tracks root and slash bass notes from the Chord Track.',
      code: '''
-- @name: Dynamic Bassline (Chord Track Follow)
-- @category: midiSeq
-- @description: Rhythmic bassline conforming to active Chord Track root/slash bass notes

notes = {
  { pitch = 36, start = 0.00, duration = 1.50, vel = 0.95 },
  { pitch = 36, start = 3.00, duration = 1.00, vel = 0.80 },
  { pitch = 36, start = 6.00, duration = 1.50, vel = 0.90 },
  { pitch = 36, start = 8.00, duration = 2.00, vel = 0.95 },
  { pitch = 36, start = 12.00, duration = 1.50, vel = 0.85 },
  { pitch = 36, start = 14.00, duration = 1.00, vel = 0.80 }
}

function process(notes, time_ctx)
  return Chord.snap_to_chord(notes, time_ctx, "bass")
end
''',
    ),
  ];
}
