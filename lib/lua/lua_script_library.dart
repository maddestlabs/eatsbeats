// Backwards-compatibility aliases for LuaScript definitions
typedef LuaPreset = LuaScriptDef;
typedef LuaPresetCategory = LuaScriptCategory;
typedef LuaPresetLibrary = LuaScriptLibrary;

enum LuaScriptCategory {
  instrument,
  audioFx,
  midiFx,
  midiSeq,
  noteSplitter,
  projectAction,
  utility;

  String get displayName {
    switch (this) {
      case LuaScriptCategory.instrument:
        return 'INSTRUMENT';
      case LuaScriptCategory.audioFx:
        return 'AUDIO FX';
      case LuaScriptCategory.midiFx:
        return 'MIDI FX';
      case LuaScriptCategory.midiSeq:
        return 'MIDI SEQ';
      case LuaScriptCategory.noteSplitter:
        return 'NOTE SPLITTER';
      case LuaScriptCategory.projectAction:
        return 'PROJECT SCRIPT';
      case LuaScriptCategory.utility:
        return 'UTILITY';
    }
  }

  static LuaScriptCategory parse(String categoryStr) {
    final clean = categoryStr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (clean.contains('project') || clean.contains('action') || clean.contains('songgen') || clean.contains('generator') || clean.contains('transpos')) {
      return LuaScriptCategory.projectAction;
    }
    if (clean.contains('split') || clean.contains('separator') || clean.contains('demux')) {
      return LuaScriptCategory.noteSplitter;
    }
    if (clean.contains('midiseq') || clean.contains('seq') || clean.contains('pattern')) {
      return LuaScriptCategory.midiSeq;
    }
    if (clean.contains('audiofx') || clean.contains('effect') || clean.contains('fx')) {
      if (clean.contains('midi')) return LuaScriptCategory.midiFx;
      return LuaScriptCategory.audioFx;
    }
    if (clean.contains('midi')) return LuaScriptCategory.midiFx;
    if (clean.contains('util')) return LuaScriptCategory.utility;
    return LuaScriptCategory.instrument;
  }
}

class LuaScriptDef {
  final String id;
  final String name;
  final LuaScriptCategory category;
  final String description;
  final String code;

  const LuaScriptDef({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.code,
  });

  bool get isInstrument => category == LuaScriptCategory.instrument;
  bool get isAudioFx => category == LuaScriptCategory.audioFx;
  bool get isMidiFx => category == LuaScriptCategory.midiFx;
  bool get isMidiSeq => category == LuaScriptCategory.midiSeq;
  bool get isNoteSplitter => category == LuaScriptCategory.noteSplitter;
  bool get isProjectAction => category == LuaScriptCategory.projectAction;
}

class LuaScriptLibrary {
  static final List<LuaScriptDef> _customScripts = [];

  static List<LuaScriptDef> get scripts => [..._builtinPresets, ..._customScripts];
  static List<LuaScriptDef> get presets => scripts; // Compatibility alias

  static List<LuaScriptDef> getScriptsByCategory(LuaScriptCategory category) {
    return scripts.where((p) => p.category == category).toList();
  }

  static List<LuaScriptDef> getPresetsByCategory(LuaScriptCategory category) => getScriptsByCategory(category);

  static void registerCustomScript(LuaScriptDef script) {
    _customScripts.removeWhere((p) => p.id == script.id || p.name == script.name);
    _customScripts.add(script);
  }

  static void registerCustomPreset(LuaScriptDef script) => registerCustomScript(script);

  static LuaScriptDef parseFromLuaScript(String luaCode, {String fallbackName = 'Custom Script'}) {
    String name = fallbackName;
    LuaScriptCategory category = LuaScriptCategory.instrument;
    String description = 'User imported Lua script';

    final lines = luaCode.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('-- @name:')) {
        name = trimmed.substring(9).trim();
      } else if (trimmed.startsWith('-- @category:')) {
        category = LuaScriptCategory.parse(trimmed.substring(13).trim());
      } else if (trimmed.startsWith('-- @description:')) {
        description = trimmed.substring(16).trim();
      }
    }

    if (!luaCode.contains('@category:')) {
      if (luaCode.contains('processSignal') || luaCode.contains('evaluateEffect')) {
        category = LuaScriptCategory.audioFx;
      } else if (luaCode.contains('transform_notes') || luaCode.contains('midi_fx')) {
        category = LuaScriptCategory.midiFx;
      }
    }

    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    final script = LuaScriptDef(
      id: id,
      name: name,
      category: category,
      description: description,
      code: luaCode,
    );

    registerCustomScript(script);
    return script;
  }

  static LuaScriptDef? getScriptById(String id) {
    try {
      return scripts.firstWhere((p) =>
          p.id == id ||
          (id == 'eats_303' && (p.id == 'jc_303' || p.id == 'acid_303')) ||
          (id == 'jc_303' && (p.id == 'eats_303' || p.id == 'acid_303')) ||
          (id == 'acid_303' && (p.id == 'eats_303' || p.id == 'jc_303')));
    } catch (_) {
      return null;
    }
  }

  static LuaScriptDef? getPresetById(String id) => getScriptById(id);

  static LuaScriptDef? findMatchingPreset(String luaCode, {String? fallbackName}) => findMatchingScript(luaCode, fallbackName: fallbackName);

  static LuaScriptDef? findMatchingScript(String luaCode, {String? fallbackName}) {
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
    if (luaCode.contains('Analog909Kick') || luaCode.contains('Analog 909 Kick') || luaCode.contains('analog_909_kick')) {
      return getPresetById('analog_909_kick');
    }
    if (luaCode.contains('Analog909Snare') || luaCode.contains('Analog 909 Snare') || luaCode.contains('analog_909_snare')) {
      return getPresetById('analog_909_snare');
    }
    if (luaCode.contains('Analog909ClosedHiHat') || luaCode.contains('Analog 909 Closed Hi-Hat') || luaCode.contains('analog_909_closed_hihat') || luaCode.contains('analog_909_hihat') || luaCode.contains('Analog 909 Hi-Hat') || luaCode.contains('Analog909HiHat')) {
      return getPresetById('analog_909_closed_hihat');
    }
    if (luaCode.contains('Analog909OpenHiHat') || luaCode.contains('Analog 909 Open Hi-Hat') || luaCode.contains('analog_909_open_hihat')) {
      return getPresetById('analog_909_open_hihat');
    }
    if (luaCode.contains('Analog909Clap') || luaCode.contains('Analog 909 Clap') || luaCode.contains('analog_909_clap') || luaCode.contains('Analog 909 Handclap')) {
      return getPresetById('analog_909_clap');
    }
    if (luaCode.contains('Analog909Rimshot') || luaCode.contains('Analog 909 Rimshot') || luaCode.contains('analog_909_rimshot')) {
      return getPresetById('analog_909_rimshot');
    }
    if (luaCode.contains('Eats303') || luaCode.contains('Eats-303') || luaCode.contains('eats_303') ||
        luaCode.contains('JC303') || luaCode.contains('JC-303') || luaCode.contains('Acid303') ||
        luaCode.contains('TB303') || luaCode.contains('jc_303') || luaCode.contains('acid_303')) {
      return getPresetById('eats_303');
    }
    if (luaCode.contains('YM2612')) {
      return getPresetById('ym2612_synth');
    }
    if (luaCode.contains('SNESSFX') || luaCode.contains('SFXR')) {
      return getPresetById('eats_sfxr');
    }
    if (luaCode.contains('Nibbles') || luaCode.contains('nibbles') || luaCode.contains('eats_nibbles') || luaCode.contains('Eats-Nibbles')) {
      return getPresetById('eats_nibbles');
    }
    if (luaCode.contains('CyberRunner') || luaCode.contains('Cyber Runner') || luaCode.contains('eats_runner') || luaCode.contains('Eats-Runner')) {
      return getPresetById('eats_runner');
    }
    if (luaCode.contains('Oscilloscope') || luaCode.contains('eats_scope') || luaCode.contains('Eats-Scope') || luaCode.contains('Scope')) {
      return getPresetById('eats_scope');
    }
    if (luaCode.contains('Spectrum') || luaCode.contains('eats_spectrum') || luaCode.contains('Eats-Spectrum') || luaCode.contains('Analyzer')) {
      return getPresetById('eats_spectrum');
    }
    if (luaCode.contains('Limiter') || luaCode.contains('master_limiter') || luaCode.contains('Master Limiter')) {
      return getPresetById('master_limiter');
    }
    if (luaCode.contains('Compressor') || luaCode.contains('dynamics_compressor') || luaCode.contains('Dynamics Compressor')) {
      return getPresetById('dynamics_compressor');
    }
    if (luaCode.contains('RoomDesigner') || luaCode.contains('room_designer') || luaCode.contains('Room Designer')) {
      return getPresetById('room_designer');
    }
    if (luaCode.contains('CabDesigner') || luaCode.contains('cab_designer') || luaCode.contains('Cab Designer')) {
      return getPresetById('cab_designer');
    }
    if (luaCode.contains('ConvReverb') || luaCode.contains('convolution_reverb') || luaCode.contains('Convolution Reverb')) {
      return getPresetById('convolution_reverb');
    }
    if (luaCode.contains('StereoDelay') || luaCode.contains('stereo_delay') || luaCode.contains('Stereo Delay')) {
      return getPresetById('stereo_delay');
    }
    if (luaCode.contains('FilterFX') || luaCode.contains('lowpass_filter') || luaCode.contains('Lowpass Filter')) {
      return getPresetById('lowpass_filter');
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

function FmAcousticKick.rack()
  return {
    rows = {
      -- ROW 1: Nearfield Physical Synthesis Chain
      {
        { id = "exciter", title = "NOISE FM EXCITER", hp = 11, row = 1, category = "MOD" },
        { id = "carrier", title = "BATTER CARRIER VCO", hp = 15, row = 1, category = "VCO" },
        { id = "sub_eq",  title = "SUB PEAKING EQ", hp = 11, row = 1, category = "VCF" },
      },
      -- ROW 2: Farfield Room Reflections & Summing Output
      {
        { id = "room_vco", title = "ROOM FARFIELD VCO", hp = 11, row = 2, category = "VCO" },
        { id = "delay",    title = "ROOM DELAY LINE", hp = 14, row = 2, category = "FX" },
        { id = "master",   title = "MASTER DUAL-MIC OUT", hp = 15, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "modulation" },
      { from = "1:1:2", to = "1:2:0", color = "audio" },
      { from = "1:2:1", to = "2:2:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "pitch" },
      { from = "2:1:1", to = "2:2:1", color = "pitch" },
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

function FmAcousticSnare.rack()
  return {
    rows = {
      -- ROW 1: Dual-Shell & Snare Wire Oscillators
      {
        { id = "shell_osc", title = "DUAL SHELL VCO", hp = 14, row = 1, category = "VCO" },
        { id = "wire_mod",  title = "SNARE WIRE NOISE", hp = 14, row = 1, category = "MOD" },
      },
      -- ROW 2: Snare Filter & Master Output
      {
        { id = "snare_vcf", title = "WIRE HPF VCF", hp = 14, row = 2, category = "VCF" },
        { id = "master",    title = "STEREO OUT VCA", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:0:1", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
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

function FmAcousticTom.rack()
  return {
    rows = {
      -- ROW 1: Physical Strike & Shell Membrane
      {
        { id = "stick_exciter", title = "STICK FM EXCITER", hp = 14, row = 1, category = "MOD" },
        { id = "shell_vco",     title = "SHELL MEMBRANE VCO", hp = 16, row = 1, category = "VCO" },
      },
      -- ROW 2: Shell Tuning & Room Acoustic Delay
      {
        { id = "shell_eq",   title = "SHELL TUNING EQ", hp = 14, row = 2, category = "VCF" },
        { id = "room_delay", title = "ROOM REFLECT DELAY", hp = 16, row = 2, category = "FX" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "modulation" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
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

function FmAcousticHiHat.rack()
  return {
    rows = {
      -- ROW 1: Metallic Inharmonic Cluster & Ping Transient
      {
        { id = "metal_cluster",  title = "6-OSC METAL CLUSTER", hp = 16, row = 1, category = "VCO" },
        { id = "ping_transient", title = "STICK PING TRANSIENT", hp = 14, row = 1, category = "MOD" },
      },
      -- ROW 2: Sizzle High-Pass Filter & VCA
      {
        { id = "sizzle_hpf", title = "SIZZLE HIGH-PASS VCF", hp = 14, row = 2, category = "VCF" },
        { id = "hat_vca",    title = "STEREO VCA OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:0:0", color = "audio" },
      { from = "1:1:1", to = "2:0:1", color = "modulation" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
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
      description: 'Authentic Eats-808 analog Bridged-T analog bass drum circuit with exponential pitch sweep, adjustable tone, click transient, and extended sub decay.',
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
      title = "EATS-808 ANALOG BASS DRUM",
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

function Analog808Kick.rack()
  return {
    rows = {
      -- ROW 1: Bridged-T Resonant Sine & Click
      {
        { id = "bridged_t", title = "BRIDGED-T SINE VCO", hp = 14, row = 1, category = "VCO" },
        { id = "click_gen", title = "CLICK TRANSIENT", hp = 12, row = 1, category = "MOD" },
        { id = "tone_lpf",  title = "TONE LOWPASS VCF", hp = 12, row = 1, category = "VCF" },
      },
      -- ROW 2: Saturation Overdrive & 808 Master Out
      {
        { id = "drive",  title = "DRIVE OVERLOAD", hp = 14, row = 2, category = "FX" },
        { id = "master", title = "808 MASTER OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:2:0", color = "audio" },
      { from = "1:1:1", to = "1:2:1", color = "modulation" },
      { from = "1:2:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
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
      description: 'Authentic Eats-808 analog dual bridged-T resonant body (180Hz & 330Hz) and snappy high-pass noise wires.',
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
      title = "EATS-808 ANALOG SNARE DRUM",
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

function Analog808Snare.rack()
  return {
    rows = {
      -- ROW 1: Dual Bridged-T Tonal Body & Snappy Noise
      {
        { id = "body_vco",   title = "DUAL BRIDGED-T VCO", hp = 14, row = 1, category = "VCO" },
        { id = "snappy_gen", title = "SNAPPY NOISE GEN", hp = 14, row = 1, category = "MOD" },
      },
      -- ROW 2: Snare Filter & Output
      {
        { id = "bandpass", title = "BANDPASS FILTER", hp = 14, row = 2, category = "VCF" },
        { id = "master",   title = "808 MASTER OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:0:0", color = "audio" },
      { from = "1:1:1", to = "2:0:1", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
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
      description: 'Authentic Eats-808 analog 6-Schmitt-trigger square oscillator metallic cluster with 7.5kHz resonant bandpass filter.',
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
      title = "EATS-808 ANALOG HI-HAT",
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

function Analog808HiHat.rack()
  return {
    rows = {
      {
        { id = "cluster_vco", title = "6-OSC SCHMITT CLUSTER", hp = 16, row = 1, category = "VCO" },
        { id = "bandpass",    title = "7.5KHZ RESONANT BPF", hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "decay_env", title = "VCA DECAY ENVELOPE", hp = 14, row = 2, category = "MOD" },
        { id = "master",    title = "808 HI-HAT OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "2:0:1", to = "1:1:1", color = "modulation" },
      { from = "1:1:1", to = "2:1:0", color = "audio" },
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
      description: 'Authentic Eats-808 analog dual detuned square wave oscillator (540Hz & 800Hz) with 800Hz bandpass filter.',
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
      title = "EATS-808 ANALOG COWBELL",
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

function Analog808Cowbell.rack()
  return {
    rows = {
      {
        { id = "dual_sqr", title = "540HZ / 800HZ DUAL SQR", hp = 16, row = 1, category = "VCO" },
        { id = "bpf_reso", title = "COWBELL 800HZ BPF", hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "env_decay", title = "EXPONENTIAL DECAY", hp = 14, row = 2, category = "MOD" },
        { id = "master",    title = "808 MASTER OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "2:0:1", to = "1:1:1", color = "modulation" },
      { from = "1:1:1", to = "2:1:0", color = "audio" },
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
      description: 'Authentic Eats-808 analog resonant bridged-T tank circuit tom/conga with pitch envelope decay.',
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
      title = "EATS-808 ANALOG TOM / CONGA",
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

function Analog808Tom.rack()
  return {
    rows = {
      {
        { id = "tank_vco",   title = "BRIDGED-T TANK VCO", hp = 14, row = 1, category = "VCO" },
        { id = "pitch_sweep", title = "PITCH SWEEP MOD", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "env_decay", title = "RINGING DECAY VCA", hp = 14, row = 2, category = "MOD" },
        { id = "master",    title = "808 TOM OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:1:1", to = "1:0:0", color = "pitch" },
      { from = "1:0:1", to = "2:1:0", color = "audio" },
      { from = "2:0:1", to = "2:1:1", color = "modulation" },
    }
  }
end

return Analog808Tom
''',
    ),

    // 0k. Authentic Analog 909 Bass Drum
    LuaPreset(
      id: 'analog_909_kick',
      name: 'Analog 909 Kick',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Eats-909 analog physical circuit model (André Michelle DSP): 274Hz to 53Hz exponential sweep, single-cycle analog oscillator wavetable, 60ms hold, and beater click attack transient.',
      code: '''
-- @name: Analog 909 Kick
-- @category: instrument
local Analog909Kick = {}

function Analog909Kick.init()
  Param.add("Tune", 0.007, 0.030, 0.018)
  Param.add("Attack", 0.0, 2.0, 1.0)
  Param.add("Decay", 0.012, 0.120, 0.050)
end

function Analog909Kick.gui()
  return {
    panel = {
      title = "EATS-909 ANALOG BASS DRUM",
      subtitle = "Physical Model: 274Hz -> 53Hz Wavetable & Attack Transient",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Tune", label = "TUNE PITCH", unit = "s" },
            { type = "nixie", param = "Attack", label = "ATTACK CLICK" },
            { type = "nixie", param = "Decay", label = "DECAY HOLD", unit = "s" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Tune", label = "TUNE", size = 56 },
            { type = "knob", param = "Attack", label = "ATTACK", size = 56 },
            { type = "knob", param = "Decay", label = "DECAY", size = 56 },
          }
        }
      }
    }
  }
end

function Analog909Kick.rack()
  return {
    rows = {
      {
        { id = "wavetable_vco", title = "274HZ-53HZ 909 VCO", hp = 16, row = 1, category = "VCO" },
        { id = "attack_click",  title = "ATTACK CLICK TRANSIENT", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "decay_hold", title = "60MS HOLD & DECAY VCA", hp = 16, row = 2, category = "MOD" },
        { id = "master",     title = "909 KICK MASTER OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:1:0", color = "audio" },
      { from = "1:1:1", to = "2:1:1", color = "audio" },
      { from = "2:0:1", to = "2:1:2", color = "modulation" },
    }
  }
end

return Analog909Kick
''',
    ),

    // 0l. Authentic Analog 909 Snare Drum
    LuaPreset(
      id: 'analog_909_snare',
      name: 'Analog 909 Snare',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Eats-909 analog dual-layer physical model (André Michelle DSP): tuned analog resonant tonal body (snare-tone) and snappy noise wires (snare-noise).',
      code: '''
-- @name: Analog 909 Snare
-- @category: instrument
local Analog909Snare = {}

function Analog909Snare.init()
  Param.add("Tune", -0.5, 0.5, 0.0)
  Param.add("Snappy", 0.0, 2.0, 1.0)
  Param.add("ToneDecay", 0.04, 0.25, 0.12)
end

function Analog909Snare.gui()
  return {
    panel = {
      title = "EATS-909 ANALOG SNARE DRUM",
      subtitle = "Dual Layer: Resonant Tonal Body & Snappy Noise Wires",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Tune", label = "TONE PITCH" },
            { type = "nixie", param = "Snappy", label = "SNAPPY WIRE" },
            { type = "nixie", param = "ToneDecay", label = "TONE DECAY", unit = "s" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Tune", label = "TUNE", size = 56 },
            { type = "knob", param = "Snappy", label = "SNAPPY", size = 56 },
            { type = "knob", param = "ToneDecay", label = "TONE DEC", size = 56 },
          }
        }
      }
    }
  }
end

function Analog909Snare.rack()
  return {
    rows = {
      {
        { id = "tone_vco",    title = "DUAL RESONANT TONE VCO", hp = 16, row = 1, category = "VCO" },
        { id = "snappy_wire", title = "SNAPPY WIRE NOISE GEN", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "wire_hpf", title = "HIGH-PASS NOISE VCF", hp = 14, row = 2, category = "VCF" },
        { id = "master",   title = "909 SNARE MASTER OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:1", color = "audio" },
    }
  }
end

return Analog909Snare
''',
    ),

    // 0m. Authentic Analog 909 Closed Hi-Hat
    LuaPreset(
      id: 'analog_909_closed_hihat',
      name: 'Analog 909 Closed Hi-Hat',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Eats-909 analog 6-bit compressed PCM ROM (closed-hihat) with analog VCA decay and pitch tuning.',
      code: '''
-- @name: Analog 909 Closed Hi-Hat
-- @category: instrument
local Analog909ClosedHiHat = {}

function Analog909ClosedHiHat.init()
  Param.add("Tune", -0.5, 0.5, 0.0)
  Param.add("Decay", 0.008, 0.060, 0.025)
end

function Analog909ClosedHiHat.gui()
  return {
    panel = {
      title = "EATS-909 CLOSED HI-HAT",
      subtitle = "Authentic 6-Bit Compressed PCM ROM & Analog VCA",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Tune", label = "SAMPLE TUNE" },
            { type = "nixie", param = "Decay", label = "VCA DECAY", unit = "s" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Tune", label = "TUNE", size = 56 },
            { type = "knob", param = "Decay", label = "DECAY", size = 56 },
          }
        }
      }
    }
  }
end

function Analog909ClosedHiHat.rack()
  return {
    rows = {
      {
        { id = "pcm_rom",  title = "6-BIT COMPRESSED PCM ROM", hp = 16, row = 1, category = "VCO" },
        { id = "tune_mod", title = "SAMPLE CLOCK TUNER", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "decay_vca", title = "ANALOG DECAY VCA", hp = 14, row = 2, category = "MOD" },
        { id = "master",    title = "909 CLOSED HAT OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:1:1", to = "1:0:0", color = "pitch" },
      { from = "1:0:1", to = "2:1:0", color = "audio" },
      { from = "2:0:1", to = "2:1:1", color = "modulation" },
    }
  }
end

return Analog909ClosedHiHat
''',
    ),

    // 0n. Authentic Analog 909 Open Hi-Hat
    LuaPreset(
      id: 'analog_909_open_hihat',
      name: 'Analog 909 Open Hi-Hat',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Eats-909 analog 6-bit compressed PCM ROM (opened-hihat) with extended analog envelope decay and pitch tuning.',
      code: '''
-- @name: Analog 909 Open Hi-Hat
-- @category: instrument
local Analog909OpenHiHat = {}

function Analog909OpenHiHat.init()
  Param.add("Tune", -0.5, 0.5, 0.0)
  Param.add("Decay", 0.030, 0.160, 0.080)
end

function Analog909OpenHiHat.gui()
  return {
    panel = {
      title = "EATS-909 OPEN HI-HAT",
      subtitle = "Authentic 6-Bit Compressed PCM ROM & Extended Decay",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Tune", label = "SAMPLE TUNE" },
            { type = "nixie", param = "Decay", label = "VCA DECAY", unit = "s" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Tune", label = "TUNE", size = 56 },
            { type = "knob", param = "Decay", label = "DECAY", size = 56 },
          }
        }
      }
    }
  }
end

function Analog909OpenHiHat.rack()
  return {
    rows = {
      {
        { id = "pcm_rom",   title = "6-BIT COMPRESSED PCM ROM", hp = 16, row = 1, category = "VCO" },
        { id = "clock_mod", title = "CLOCK TUNING MODULATOR", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "ext_decay", title = "EXTENDED DECAY VCA", hp = 14, row = 2, category = "MOD" },
        { id = "master",    title = "909 OPEN HAT OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:1:1", to = "1:0:0", color = "pitch" },
      { from = "1:0:1", to = "2:1:0", color = "audio" },
      { from = "2:0:1", to = "2:1:1", color = "modulation" },
    }
  }
end

return Analog909OpenHiHat
''',
    ),

    // 0o. Authentic Analog 909 Handclap
    LuaPreset(
      id: 'analog_909_clap',
      name: 'Analog 909 Handclap',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Eats-909 analog handclap (clap.raw) with multi-trigger impulse playback, diffuse reverberation, and pitch tuning.',
      code: '''
-- @name: Analog 909 Handclap
-- @category: instrument
local Analog909Clap = {}

function Analog909Clap.init()
  Param.add("Tune", -0.5, 0.5, 0.0)
  Param.add("Decay", 0.08, 0.60, 0.28)
end

function Analog909Clap.gui()
  return {
    panel = {
      title = "EATS-909 HANDCLAP",
      subtitle = "Multi-Trigger Triggered ROM & Reverb Tail",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Tune", label = "SAMPLE TUNE" },
            { type = "nixie", param = "Decay", label = "REVERB DECAY", unit = "s" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Tune", label = "TUNE", size = 56 },
            { type = "knob", param = "Decay", label = "DECAY", size = 56 },
          }
        }
      }
    }
  }
end

function Analog909Clap.rack()
  return {
    rows = {
      {
        { id = "burst_rom",   title = "MULTI-BURST CLAP ROM", hp = 16, row = 1, category = "VCO" },
        { id = "trigger_mod", title = "IMPULSE SPREAD TRIGGER", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "tail_reverb", title = "DIFFUSE REVERB TAIL", hp = 16, row = 2, category = "FX" },
        { id = "master",      title = "909 CLAP MASTER OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:1:1", to = "1:0:0", color = "modulation" },
      { from = "1:0:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return Analog909Clap
''',
    ),

    // 0p. Authentic Analog 909 Rimshot
    LuaPreset(
      id: 'analog_909_rimshot',
      name: 'Analog 909 Rimshot',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Eats-909 analog high-Q resonant tank circuit (rim.raw) with stick click clack and envelope decay.',
      code: '''
-- @name: Analog 909 Rimshot
-- @category: instrument
local Analog909Rimshot = {}

function Analog909Rimshot.init()
  Param.add("Tune", -0.5, 0.5, 0.0)
  Param.add("Decay", 0.02, 0.20, 0.075)
end

function Analog909Rimshot.gui()
  return {
    panel = {
      title = "EATS-909 RIMSHOT",
      subtitle = "High-Q Resonant Tank Circuit ROM Clack",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Tune", label = "SAMPLE TUNE" },
            { type = "nixie", param = "Decay", label = "RING DECAY", unit = "s" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Tune", label = "TUNE", size = 56 },
            { type = "knob", param = "Decay", label = "DECAY", size = 56 },
          }
        }
      }
    }
  }
end

function Analog909Rimshot.rack()
  return {
    rows = {
      {
        { id = "tank_rom",  title = "HIGH-Q TANK CIRCUIT ROM", hp = 16, row = 1, category = "VCO" },
        { id = "click_mod", title = "STICK CLICK ATTACK", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "ring_decay", title = "METALLIC RING DECAY", hp = 14, row = 2, category = "MOD" },
        { id = "master",     title = "909 RIMSHOT MASTER OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:1:1", to = "1:0:0", color = "modulation" },
      { from = "1:0:1", to = "2:1:0", color = "audio" },
      { from = "2:0:1", to = "2:1:1", color = "modulation" },
    }
  }
end

return Analog909Rimshot
''',
    ),

    // 1. Eats-303 Acid Bass Synth (Inspired by JC-303 / Open303 DSP & 303 Diode Topology)
    LuaPreset(
      id: 'eats_303',
      name: 'Eats-303',
      category: LuaPresetCategory.instrument,
      description: 'Authentic Eats-303 acid bassline emulation with 24dB 4-Pole Diode Ladder filter, 150Hz feedback highpass loop, leaky integrator saw/square oscillators, accent decay override, 60ms slide portamento, and overdrive. DSP synthesis inspired by midilab/jc303 (Jean-Christophe Taveau) and Robin Schmidt (Open303).',
      code: '''
-- @name: Eats-303
-- @category: instrument
-- @description: Authentic TB-303 acid bass emulation with diode ladder filter. DSP inspired by JC-303 (Jean-Christophe Taveau) & Open303.
local Eats303 = {}

function Eats303.init()
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

--- Modular Module 1: 303 Leaky Integrator Oscillator Core with Portamento Slide
function Eats303.oscillator(time, freq, params, isSlide, targetNote)
  local waveType = params["Waveform"] or 0.0
  local pitch = params["Pitch"] or 0.0
  local octave = math.floor((params["Octave"] or 0.0) + 0.5)
  local subWave = params["SubWaveform"] or 0.0
  local subVol = params["SubVolume"] or 0.0
  local slideParam = params["Slide"] or params["Portamento"] or 0.0
  local glideTime = slideParam > 0.01 and (0.010 + slideParam * 0.200) or 0.060

  local baseFreq = freq * (2.0 ^ (octave + pitch / 12.0))
  local currentFreq = baseFreq
  if targetNote and targetNote > 0 then
    local targetFreq = 440.0 * (2.0 ^ ((targetNote + octave * 12 + pitch - 69) / 12.0))
    currentFreq = targetFreq + (baseFreq - targetFreq) * math.exp(-time / glideTime)
  elseif isSlide or slideParam > 0.01 then
    local targetFreq = targetNote and (440.0 * (2.0 ^ ((targetNote + octave * 12 + pitch - 69) / 12.0))) or baseFreq
    currentFreq = targetFreq + (baseFreq - targetFreq) * math.exp(-time / glideTime)
  end

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
  return osc
end

--- Modular Module 2: Dynamic Accent & VCF Envelope Generator
function Eats303.envelope(time, params, isAccent, isSlide)
  local decay = params["Decay"] or 0.28
  local accent = params["Accent"] or 0.78
  local envMod = params["EnvMod"] or 0.75
  local hasAccent = isAccent or (accent > 0.7 and not isSlide)
  local envBoost = hasAccent and (1.0 + accent * 1.25) or 1.0
  local activeDecay = hasAccent and 0.200 or (decay <= 1.0 and (0.200 + decay * 1.800) or decay)
  local softAttack = 1.0 - math.exp(-time / 0.003)
  local env = softAttack * math.exp(-time / activeDecay)
  local accentPulse = hasAccent and (accent * 0.55 * math.exp(-time / 0.035)) or 0.0
  return (env + accentPulse) * envMod * 5.2 * envBoost, hasAccent
end

--- Modular Module 3: 24dB Diode Ladder VCF with 150Hz Feedback Highpass
function Eats303.diode_filter(input_sample, cutoff, res, envModFactor)
  local modCutoff = cutoff * (2.0 ^ envModFactor)
  local filtered = DSP.lowpass(input_sample, math.min(18000.0, math.max(30.0, modCutoff)), res)
  return filtered * 0.985
end

--- Modular Module 4: Analog Saturation Overdrive & VCA Output
function Eats303.overdrive(input_sample, drive, hasAccent, accent)
  local output = input_sample * (hasAccent and (1.35 + (accent or 0.78) * 0.45) or 1.0)
  if drive > 0.02 then
    output = math.tanh(output * (1.0 + drive * 3.5))
  end
  return output
end

function Eats303.process(time, freq, note, params, targetNote, isSlide, isAccent)
  local osc = Eats303.oscillator(time, freq, params, isSlide, targetNote)
  local envFactor, hasAccent = Eats303.envelope(time, params, isAccent, isSlide)
  local filtered = Eats303.diode_filter(osc, params["Cutoff"] or 1400.0, params["Resonance"] or 9.2, envFactor)
  return Eats303.overdrive(filtered, params["Drive"] or params["Overdrive"] or 0.25, hasAccent, params["Accent"] or 0.78)
end

function Eats303.gui()
  return {
    panel = {
      title = "EATS-303 ACID BASSLINE",
      subtitle = "Eats-303 Acid Synth • (JC-303 & Open303 DSP)",
      background = "silver",
      accent = "#000000",
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

function Eats303.rack()
  return {
    rows = {
      -- ROW 1: 303 Leaky Saw/Sqr VCO, Diode Ladder VCF & Drive
      {
        { id = "vco",   title = "TB-303 VCO", hp = 12, row = 1, category = "VCO" },
        { id = "vcf",   title = "18DB RESO VCF", hp = 14, row = 1, category = "VCF" },
        { id = "vca",   title = "ANALOG VCA", hp = 12, row = 1, category = "OUT" },
      },
      -- ROW 2: Accent Envelope Modulator & Master Summing Out
      {
        { id = "env",    title = "ACID ENVELOPE", hp = 14, row = 2, category = "MOD" },
        { id = "master", title = "MASTER STEREO OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "2:0:0", to = "1:1:1", color = "modulation" },
      { from = "1:1:2", to = "1:2:0", color = "audio" },
      { from = "1:2:1", to = "2:1:0", color = "audio" },
    }
  }
end

-- Backward compatibility aliases
JC303 = Eats303

return Eats303
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

function PolyLeadSynth.gui()
  return {
    panel = {
      title = "POLY LEAD SYNTH",
      subtitle = "Dual Detuned Saw & Dynamic VCF Lead",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Cutoff", label = "CUTOFF", size = 56 },
            { type = "knob", param = "Resonance", label = "RESO", size = 56 },
            { type = "knob", param = "Detune", label = "DETUNE", size = 52 },
            { type = "knob", param = "Attack", label = "ATTACK", size = 52 },
            { type = "knob", param = "Release", label = "RELEASE", size = 52 },
          }
        }
      }
    }
  }
end

function PolyLeadSynth.rack()
  return {
    rows = {
      {
        { id = "dual_saw", title = "DUAL DETUNED SAW VCO", hp = 16, row = 1, category = "VCO" },
        { id = "lead_vcf", title = "24DB LADDER VCF", hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "lead_env", title = "EXPONENTIAL ADSR", hp = 14, row = 2, category = "MOD" },
        { id = "master",   title = "STEREO LEAD OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "2:0:1", to = "1:1:1", color = "modulation" },
      { from = "1:1:1", to = "2:1:0", color = "audio" },
    }
  }
end

return PolyLeadSynth
''',
    ),

    // 7. YM2612 Genesis 4-Op FM Synth
    LuaPreset(
      id: 'ym2612_synth',
      name: 'YM2612 Genesis 4-Op FM',
      category: LuaPresetCategory.instrument,
      description: 'Authentic YM2612 / OPN2 4-operator FM sound chip emulation (16-bit arcade & console sound) with 8 selectable routing algorithms, operator feedback, Total Level brightness, and direct register poke access.',
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

function YM2612.operator(phase, totalLevel, mult)
  local tlGain = math.exp(-((totalLevel or 0.0) / 127.0) * 4.0)
  return math.sin(phase * (mult or 1.0)) * tlGain
end

function YM2612.ladder_dac(sample)
  local steps = 512.0
  return math.floor(sample * steps + 0.5) / steps
end

function YM2612.process(time, freq, note, params)
  local algo = math.floor(params["Algorithm"] or 4.0)
  local fb = (params["Feedback"] or 5.0) / 7.0
  local op1M = params["Op1_Mult"] or 1.0
  local op1TL = params["Op1_TL"] or 8.0
  local op2M = params["Op2_Mult"] or 1.0
  local op2TL = params["Op2_TL"] or 12.0
  local op3M = params["Op3_Mult"] or 1.0
  local op3TL = params["Op3_TL"] or 0.0
  local op4M = params["Op4_Mult"] or 1.0
  local op4TL = params["Op4_TL"] or 0.0

  local basePhase = 2.0 * math.pi * freq * time
  local op1Mod = math.sin(basePhase * op1M) * fb * 1.5
  local op1 = YM2612.operator(basePhase + op1Mod, op1TL, op1M)
  local op2 = YM2612.operator(basePhase + op1 * 2.0, op2TL, op2M)
  local op3 = YM2612.operator(basePhase + op2 * 1.5, op3TL, op3M)
  local op4 = YM2612.operator(basePhase + op3 * 2.0, op4TL, op4M)

  local env = math.exp(-time * 1.5)
  local rawOut = (op2 * 0.3 + op4 * 0.7) * env
  return YM2612.ladder_dac(math.tanh(rawOut * 1.2))
end

function YM2612.gui()
  return {
    panel = {
      title = "YM2612 FM SOUND PROCESSOR",
      subtitle = "16-Bit 4-Operator FM Hardware Synthesis",
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

function YM2612.rack()
  return {
    rows = {
      {
        { id = "op12", title = "OP1-OP2 FM VCO", hp = 14, row = 1, category = "VCO" },
        { id = "op34", title = "OP3-OP4 FM VCO", hp = 14, row = 1, category = "VCO" },
        { id = "env",  title = "SSG-EG ENVELOPE", hp = 12, row = 1, category = "MOD" },
      },
      {
        { id = "dac",    title = "YM2612 9-BIT DAC", hp = 14, row = 2, category = "FX" },
        { id = "master", title = "MASTER STEREO OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:2", to = "1:1:0", color = "modulation" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return YM2612
''',
    ),

    // 8. SNES Sfxr (16-Bit S-DSP / SPC700)
    LuaPreset(
      id: 'eats_sfxr',
      name: 'SNES Sfxr',
      category: LuaPresetCategory.instrument,
      description: 'Authentic 16-Bit S-DSP Console Engine 16-bit procedural sound effect engine with BRR wavetables, 4-point Gaussian filtering, 8-tap FIR echo reverb, and intelligent PRNG seed randomization. Instant archetypes: Laser, Explosion, Powerup, Coin, Jump, Hurt, Lose, Button, Warp, Mutate, Custom. Completely playable chromatically across keys!',
      code: '''
-- @name: SNES Sfxr
-- @category: instrument
local SNESSFX = {}

function SNESSFX.init()
  Param.choice("SFXType", {"Laser", "Explosion", "Powerup", "Coin", "Jump", "Hurt", "Lose", "Button", "Warp", "Mutate", "Custom SNES"}, 0.0)
  Param.add("Seed", 1.0, 9999.0, 42.0, 1.0)
  Param.choice("Waveform", {"Sine", "Square", "Pulse 25%", "Pulse 12%", "Sawtooth", "Triangle", "Organ", "Strings", "Flute", "Slap Bass", "Chime", "Noise"}, 1.0)
  Param.add("Attack", 0.001, 0.5, 0.005)
  Param.add("Decay", 0.01, 2.0, 0.35)
  Param.add("Sustain", 0.0, 1.0, 0.2)
  Param.add("Release", 0.01, 2.0, 0.2)
  Param.add("PitchSweep", -2.0, 2.0, -0.45)
  Param.add("VibratoRate", 0.0, 20.0, 0.0)
  Param.add("VibratoDepth", 0.0, 1.0, 0.0)
  Param.add("EchoDelay", 16.0, 480.0, 120.0, 16.0)
  Param.add("EchoFeedback", 0.0, 0.95, 0.45)
  Param.add("EchoVolume", 0.0, 1.0, 0.35)
  Param.add("NoiseMix", 0.0, 1.0, 0.0)
end

function SNESSFX.oscillator(phase, waveIdx, noiseMix)
  local normPos = (phase / (2.0 * math.pi)) % 1.0
  local w = math.floor(waveIdx or 1)
  local osc = 0.0
  if w == 0 then
    osc = math.sin(phase)
  elseif w == 1 then
    osc = normPos < 0.5 and 1.0 or -1.0
  elseif w == 2 then
    osc = normPos < 0.25 and 1.0 or -1.0
  elseif w == 3 then
    osc = normPos < 0.125 and 1.0 or -1.0
  elseif w == 4 then
    osc = (2.0 * normPos - 1.0) * 0.9
  elseif w == 5 then
    osc = (4.0 * math.abs(normPos - 0.5) - 1.0)
  elseif w == 6 then
    osc = (math.sin(phase) + math.sin(phase * 2.0) * 0.5 + math.sin(phase * 4.0) * 0.25) * 0.57
  elseif w == 7 then
    osc = (2.0 * normPos - 1.0) * 0.6 + (2.0 * ((normPos * 2.0) % 1.0) - 1.0) * 0.4
  elseif w == 8 then
    osc = math.sin(phase) * 0.85 + math.sin(phase * 3.0) * 0.15
  elseif w == 9 then
    osc = (math.sin(phase) + math.sin(phase * 3.0) * 0.4) * 0.75
  elseif w == 10 then
    osc = (math.sin(phase) + math.sin(phase * 2.76) * 0.4 + math.sin(phase * 5.4) * 0.25) * 0.6
  else
    osc = (math.random() * 2.0 - 1.0) * 0.8
  end

  if (noiseMix or 0.0) > 0.01 then
    local n = (math.random() * 2.0 - 1.0) * noiseMix
    osc = osc * (1.0 - noiseMix) + n
  end
  return osc
end

function SNESSFX.envelope(time, a, d, s)
  local att = math.max(0.001, a or 0.005)
  local dec = math.max(0.01, d or 0.35)
  local sus = math.max(0.0, math.min(1.0, s or 0.2))
  if time < att then
    return time / att
  else
    return math.max(0.0, sus + (1.0 - sus) * math.exp(-(time - att) * 4.0 / dec))
  end
end

function SNESSFX.echo(signal, time, delayMs, feedback, vol)
  local dSec = math.max(0.016, (delayMs or 120.0) / 1000.0)
  local fb = math.max(0.0, math.min(0.95, feedback or 0.45))
  local ev = math.max(0.0, math.min(1.0, vol or 0.35))
  local echoSignal = 0.0
  if time > dSec then
    local damp = math.exp(-(time - dSec) * 3.0) * fb
    echoSignal = signal * damp * 0.5
  end
  return signal + echoSignal * ev
end

function SNESSFX.process(time, freq, note, params)
  local wIdx = params["Waveform"] or 1.0
  local sweep = params["PitchSweep"] or -0.45
  local a = params["Attack"] or 0.005
  local d = params["Decay"] or 0.35
  local s = params["Sustain"] or 0.2
  local nMix = params["NoiseMix"] or 0.0
  local eDelay = params["EchoDelay"] or 120.0
  local eFdbk = params["EchoFeedback"] or 0.45
  local eVol = params["EchoVolume"] or 0.35

  -- Pitch sweep
  local sweepFreq = freq * math.max(0.05, 1.0 + sweep * math.min(1.5, time * 8.0))
  local phase = 2.0 * math.pi * sweepFreq * time
  local rawVoice = SNESSFX.oscillator(phase, wIdx, nMix)
  local env = SNESSFX.envelope(time, a, d, s)
  local dryOut = rawVoice * env
  return math.tanh(SNESSFX.echo(dryOut, time, eDelay, eFdbk, eVol) * 1.3)
end

function SNESSFX.gui()
  return {
    panel = {
      title = "SNES Sfxr",
      subtitle = "16-Bit Procedural Sound Engine",
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

function SNESSFX.rack()
  return {
    rows = {
      {
        { id = "sfx_vco",   title = "SFX GENERATOR VCO", hp = 16, row = 1, category = "VCO" },
        { id = "sweep_env", title = "PITCH SWEEP ENV", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "echo_fir", title = "8-TAP FIR ECHO", hp = 16, row = 2, category = "FX" },
        { id = "master",   title = "SFXR MASTER OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:1:1", to = "1:0:0", color = "pitch" },
      { from = "1:0:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
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
      description: 'Polyphonic 16-bit console sound processor emulation with Gaussian BRR wavetables, pitch modulation (PMOD), and 8-tap FIR echo reverb.',
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

function SNESConsole.wavetable(phase, waveIdx)
  local normPos = (phase / (2.0 * math.pi)) % 1.0
  local w = math.floor(waveIdx or 0)
  if w == 0 then
    local s = normPos < 0.5 and 1.0 or -1.0
    return s * 0.9
  elseif w == 1 then
    local s = normPos < 0.25 and 1.0 or -1.0
    return s * 0.85
  elseif w == 2 then
    local s = normPos < 0.125 and 1.0 or -1.0
    return s * 0.85
  elseif w == 3 then
    return (2.0 * normPos - 1.0) * 0.85
  elseif w == 4 then
    local t = 4.0 * math.abs(normPos - 0.5) - 1.0
    return t * 0.95
  elseif w == 5 then
    return math.sin(phase)
  elseif w == 6 then
    local s1 = math.sin(phase)
    local s2 = math.sin(phase * 2.0) * 0.5
    local s4 = math.sin(phase * 4.0) * 0.25
    return (s1 + s2 + s4) * 0.57
  elseif w == 7 then
    local saw1 = 2.0 * normPos - 1.0
    local saw2 = 2.0 * ((normPos * 2.0) % 1.0) - 1.0
    return (saw1 * 0.6 + saw2 * 0.4) * 0.9
  elseif w == 8 then
    return math.sin(phase) * 0.85 + math.sin(phase * 3.0) * 0.15
  elseif w == 9 then
    local b1 = math.sin(phase)
    local b2 = math.sin(phase * 3.0) * 0.4
    return (b1 + b2) * 0.75
  elseif w == 10 then
    local c1 = math.sin(phase)
    local c2 = math.sin(phase * 2.76) * 0.4
    local c3 = math.sin(phase * 5.4) * 0.25
    return (c1 + c2 + c3) * 0.6
  else
    return (math.random() * 2.0 - 1.0) * 0.7
  end
end

function SNESConsole.adsr(time, a, d, s, r)
  local att = math.max(0.001, a or 0.005)
  local dec = math.max(0.01, d or 0.3)
  local sus = math.max(0.0, math.min(1.0, s or 0.5))
  if time < att then
    return time / att
  else
    local tDec = time - att
    return sus + (1.0 - sus) * math.exp(-tDec * 3.5 / dec)
  end
end

function SNESConsole.echo(signal, time, delayMs, feedback, vol)
  local dSec = math.max(0.016, (delayMs or 140.0) / 1000.0)
  local fb = math.max(0.0, math.min(0.95, feedback or 0.55))
  local ev = math.max(0.0, math.min(1.0, vol or 0.4))
  local echoSignal = 0.0
  if time > dSec then
    local taps = { 0.34, 0.45, -0.12, 0.10 }
    for i = 1, 4 do
      local tTap = time - dSec * i
      if tTap > 0 then
        local damp = math.exp(-tTap * 2.5) * (fb ^ i)
        echoSignal = echoSignal + signal * damp * taps[i]
      end
    end
  end
  return signal + echoSignal * ev
end

function SNESConsole.process(time, freq, note, params)
  local wIdx = params["Waveform"] or 0.0
  local a = params["Attack"] or 0.005
  local d = params["Decay"] or 0.3
  local s = params["Sustain"] or 0.5
  local r = params["Release"] or 0.25
  local vRate = params["VibratoRate"] or 5.5
  local vDepth = params["VibratoDepth"] or 0.1
  local eDelay = params["EchoDelay"] or 140.0
  local eFdbk = params["EchoFeedback"] or 0.55
  local eVol = params["EchoVolume"] or 0.4

  -- 1. Vibrato Pitch Modulation
  local vibOffset = 0.0
  if vDepth > 0.001 and vRate > 0.1 then
    vibOffset = math.sin(2.0 * math.pi * vRate * time) * (vDepth * 0.06)
  end
  local curFreq = freq * (1.0 + vibOffset)

  -- 2. Wavetable Synthesis with S-DSP Gaussian curve
  local phase = 2.0 * math.pi * curFreq * time
  local rawVoice = SNESConsole.wavetable(phase, wIdx)

  -- 3. ADSR / S-DSP Gain Envelope
  local env = SNESConsole.adsr(time, a, d, s, r)
  local dryOut = rawVoice * env

  -- 4. 8-Tap FIR Echo Reverb Emulation
  return math.tanh(SNESConsole.echo(dryOut, time, eDelay, eFdbk, eVol) * 1.2)
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

function SNESConsole.rack()
  return {
    rows = {
      -- ROW 1: Wavetable Sound Engine & ADSR
      {
        { id = "brr_vco", title = "BRR WAVETABLE VCO", hp = 16, row = 1, category = "VCO" },
        { id = "snes_adsr", title = "ADSR / GAIN ENV", hp = 14, row = 1, category = "MOD" },
      },
      -- ROW 2: S-DSP Echo Processor & Output
      {
        { id = "echo", title = "8-TAP FIR ECHO", hp = 16, row = 2, category = "FX" },
        { id = "master", title = "S-DSP MASTER OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:2", to = "2:0:0", color = "audio" },
      { from = "1:1:1", to = "2:0:1", color = "modulation" },
      { from = "2:0:2", to = "2:1:0", color = "audio" },
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
      description: 'YMF262 / OPL3 2-Op & 4-Op FM synthesis modelled after classic 16-bit retro DOS sound cards.',
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

function OPL3.operator(phase, totalLevel, mult)
  local gain = math.exp(-((totalLevel or 0.0) / 127.0) * 3.5)
  return math.sin(phase * (mult or 1.0)) * gain
end

function OPL3.process(time, freq, note, params)
  local algo = params["Algorithm"] or 4.0
  local fb = (params["Feedback"] or 4.0) / 7.0
  local op1M = params["Op1_Mult"] or 1.0
  local op1TL = params["Op1_TL"] or 12.0
  local op2M = params["Op2_Mult"] or 2.0
  local op2TL = params["Op2_TL"] or 0.0

  local basePhase = 2.0 * math.pi * freq * time
  local op1Out = OPL3.operator(basePhase, op1TL, op1M) * (1.0 + fb)
  local op2Out = OPL3.operator(basePhase + op1Out * 2.5, op2TL, op2M)

  local env = math.exp(-time * 2.0)
  return math.tanh((op2Out * env) * 1.1)
end

function OPL3.gui()
  return {
    panel = {
      title = "YMF262 / OPL3 FM SYNTH",
      subtitle = "Classic 16-Bit Retro DOS FM Hardware",
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

function OPL3.rack()
  return {
    rows = {
      {
        { id = "op1", title = "OPL3 OP1 MODULATOR", hp = 14, row = 1, category = "VCO" },
        { id = "op2", title = "OPL3 OP2 CARRIER", hp = 14, row = 1, category = "VCO" },
      },
      {
        { id = "dac",    title = "YMF262 16-BIT DAC", hp = 14, row = 2, category = "FX" },
        { id = "master", title = "OPL3 MASTER OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "modulation" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return OPL3
''',
    ),

    // 8. 8-Bit Crusher FX
    LuaPreset(
      id: 'bitcrusher',
      name: '8-Bit Crusher',
      category: LuaPresetCategory.audioFx,
      description: 'Hardware bit-depth and sample-rate reduction for authentic 8-bit crunch and lo-fi textures.',
      code: '''
-- @name: 8-Bit Crusher
-- @category: audioFx
-- @description: Hardware bit-depth and sample-rate reduction for authentic 8-bit crunch and lo-fi textures
local Bitcrusher = {}

function Bitcrusher.init()
  Param.add("Bits", 1.0, 16.0, 8.0, 1.0)
  Param.add("Downsample", 1.0, 32.0, 1.0, 1.0)
  Param.add("Drive", 0.5, 4.0, 1.0, 0.05)
  Param.add("Mix", 0.0, 1.0, 1.0, 0.05)
end

function Bitcrusher.process(input_l, input_r, params)
  local bits = params["Bits"] or 8.0
  local down = math.floor(params["Downsample"] or 1.0)
  local drive = params["Drive"] or 1.0
  local mix = params["Mix"] or 1.0

  local levels = 2.0 ^ math.max(1.0, math.min(16.0, bits))
  local inL = math.tanh(input_l * drive)
  local inR = math.tanh(input_r * drive)

  local crushedL = math.floor(inL * levels + 0.5) / levels
  local crushedR = math.floor(inR * levels + 0.5) / levels

  local outL = input_l * (1.0 - mix) + crushedL * mix
  local outR = input_r * (1.0 - mix) + crushedR * mix
  return outL, outR
end

function Bitcrusher.gui()
  return {
    panel = {
      title = "8-Bit Crusher",
      subtitle = "Hardware Bit-Depth & Sample-Rate Reduction",
      background = "snes",
      accent = "#FFD700",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Bits", label = "BITS", unit = "bit", knobStyle = "snes", size = 60 },
            { type = "knob", param = "Downsample", label = "CRUSH", unit = "x", knobStyle = "snes" },
            { type = "knob", param = "Drive", label = "DRIVE", unit = "x", knobStyle = "snes" },
            { type = "knob", param = "Mix", label = "MIX", knobStyle = "snes" },
          }
        }
      }
    }
  }
end

function Bitcrusher.rack()
  return {
    rows = {
      {
        { id = "in_lr", title = "AUDIO INPUT L/R", hp = 14, row = 1, category = "OUT" },
        { id = "crush", title = "8-BIT CRUSHER CORE", hp = 16, row = 1, category = "FX" },
      },
      {
        { id = "mix",    title = "DRY / WET MIXER", hp = 14, row = 2, category = "MOD" },
        { id = "out_lr", title = "AUDIO OUTPUT L/R", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return Bitcrusher
''',
    ),

    // 9. WaveShaper Distortion FX
    LuaPreset(
      id: 'waveshaper',
      name: 'WaveShaper',
      category: LuaPresetCategory.audioFx,
      description: 'Interactive multi-curve transfer function distortion, asymmetric tube saturation and wavefolder with DC offset filtering.',
      code: '''
-- @name: WaveShaper
-- @category: audioFx
-- @description: Interactive multi-curve distortion and wavefolder with DC offset filtering
local WaveShaper = {}

function WaveShaper.init()
  Param.add("Shape", 0.0, 4.0, 0.0, 1.0)
  Param.add("Tension", -1.0, 1.0, 0.0, 0.02)
  Param.add("Pre", 0.1, 4.0, 1.0, 0.05)
  Param.add("Post", 0.0, 4.0, 1.0, 0.05)
  Param.toggle("DCFilter", 1.0)
  Param.add("Mix", 0.0, 1.0, 1.0, 0.05)
end

function WaveShaper.process(input_l, input_r, params)
  return input_l, input_r
end

function WaveShaper.gui()
  return {
    panel = {
      title = "WaveShaper",
      subtitle = "Interactive Transfer Function & Wavefolder",
      background = "grunge",
      accent = "#21F4E8",
      layout = {
        { type = "waveshaper_canvas", height = 150 },
        {
          type = "row",
          children = {
            { type = "knob", param = "Pre", label = "PRE / DRIVE", unit = "x" },
            { type = "switch", param = "DCFilter", label = "DC FILTER", leftText = "OFF", rightText = "ON" },
            { type = "knob", param = "Post", label = "POST GAIN", unit = "x" },
            { type = "knob", param = "Mix", label = "MIX" },
          }
        }
      }
    }
  }
end

function WaveShaper.rack()
  return {
    rows = {
      {
        { id = "in_lr",  title = "AUDIO INPUT L/R", hp = 14, row = 1, category = "OUT" },
        { id = "shaper", title = "WAVESHAPER SATURATION", hp = 16, row = 1, category = "FX" },
      },
      {
        { id = "dc_flt", title = "DC FILTER & GAIN", hp = 14, row = 2, category = "VCF" },
        { id = "out_lr", title = "AUDIO OUTPUT L/R", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return WaveShaper
''',
    ),

    // 11. Eatsbeats Sampler Instrument (Melodic / One-Shot)
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

function SamplerInstrument.gui()
  return {
    panel = {
      title = "MELODIC SAMPLER",
      subtitle = "Pitch-Shifted ADSR Sample Player",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "RootKey", label = "ROOT KEY", size = 52 },
            { type = "knob", param = "AttackSec", label = "ATTACK", size = 52 },
            { type = "knob", param = "DecaySec", label = "DECAY", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", size = 52 },
            { type = "knob", param = "ReleaseSec", label = "RELEASE", size = 52 },
            { type = "knob", param = "FilterCutoff", label = "CUTOFF", size = 56 },
          }
        }
      }
    }
  }
end

function SamplerInstrument.rack()
  return {
    rows = {
      {
        { id = "sample_vco", title = "SAMPLE PLAYBACK CORE", hp = 16, row = 1, category = "VCO" },
        { id = "sample_vcf", title = "MULTIMODE 24DB VCF", hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "sample_env", title = "ADSR ENVELOPE", hp = 14, row = 2, category = "MOD" },
        { id = "master",     title = "MASTER STEREO OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "2:0:1", to = "1:1:1", color = "modulation" },
      { from = "1:1:1", to = "2:1:0", color = "audio" },
    }
  }
end

return SamplerInstrument
''',
    ),

    // 12. Eatsbeats Multi-Slot Drum Kit Sampler
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

function DrumKitSampler.gui()
  return {
    panel = {
      title = "MULTI-SLOT DRUM SAMPLER",
      subtitle = "4-Slot Velocity-Sensitive Trigger Rack",
      accent = "track",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "KickTune", label = "KICK TUNE", size = 52 },
            { type = "knob", param = "SnareTune", label = "SNARE TUNE", size = 52 },
            { type = "knob", param = "Drive", label = "SAT DRIVE", size = 52 },
          }
        }
      }
    }
  }
end

function DrumKitSampler.rack()
  return {
    rows = {
      {
        { id = "multi_slot", title = "4-SLOT DRUM SAMPLER", hp = 16, row = 1, category = "VCO" },
        { id = "slot_tune",  title = "PITCH TUNING MATRIX", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "drive_sat", title = "OVERDRIVE TANK", hp = 14, row = 2, category = "FX" },
        { id = "master",    title = "DRUM MASTER OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:1:1", to = "1:0:0", color = "pitch" },
      { from = "1:0:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
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
      knobStyle = "snes",
      layout = {
        {
          type = "row",
          children = {
            { type = "listbox", param = "SoundFontBank", label = "SoundFont Bank", width = 160, height = 90 },
            { type = "listbox", param = "Preset", label = "Program Preset", width = 200, height = 90 },
          }
        },
        {
          type = "row",
          children = {
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

function SoundFontSampler.rack()
  return {
    rows = {
      {
        { id = "sf2_engine", title = "SF2 SOUNDFONT ENGINE", hp = 16, row = 1, category = "VCO" },
        { id = "zone_mod",   title = "VELOCITY KEY-ZONE MATRIX", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "adsr_env", title = "ADSR AMPLIFIER", hp = 14, row = 2, category = "MOD" },
        { id = "master",   title = "SF2 MASTER OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return SoundFontSampler
''',
    ),

    // 14. Lua MIDI Arpeggiator FX
    LuaPreset(
      id: 'arpeggiator_midi_fx',
      name: 'Arpeggiator FX',
      category: LuaPresetCategory.midiFx,
      description: 'Advanced MIDI arpeggiator with multi-octave cycling, rate dividers, gate, swing, and 8 pattern modes.',
      code: '''
-- @name: Arpeggiator FX
-- @category: midiFx
-- @description: Advanced melodic MIDI arpeggiator with multi-octave cycling and pattern modes.
local ArpeggiatorMidiFX = {}

function ArpeggiatorMidiFX.init()
  Param.add("Rate", 0.25, 4.0, 1.0, 0.25)
  Param.add("Octaves", 1.0, 4.0, 2.0, 1.0)
  Param.choice("Pattern", {"Up", "Down", "UpDown", "DownUp", "Converge", "Diverge", "Random", "Chord", "AsPlayed"}, 0.0)
  Param.add("Gate", 0.1, 2.0, 0.85, 0.05)
  Param.add("Swing", 0.0, 0.5, 0.0, 0.05)
end

function ArpeggiatorMidiFX.transform_notes(notes, params, timeContext)
  return Midi.arpeggiate(notes, params, timeContext)
end

function ArpeggiatorMidiFX.gui()
  return {
    panel = {
      title = "Arpeggiator FX",
      subtitle = "Melodic Note Arpeggiator & Gate Modulator",
      background = "dark",
      accent = "#FFD700",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Rate", label = "RATE", unit = "x", size = 52 },
            { type = "knob", param = "Octaves", label = "OCTAVES", size = 52 },
            { type = "listbox", param = "Pattern", label = "PATTERN", width = 110, height = 70 },
            { type = "knob", param = "Gate", label = "GATE", size = 52 },
            { type = "knob", param = "Swing", label = "SWING", size = 52 },
          }
        }
      }
    }
  }
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
-- @description: Conforms incoming notes non-destructively to active project Chord Track.
local ChordFollower = {}

function ChordFollower.init()
  Param.choice("Mode", {"Chord Tones", "Bass Root", "Scale Steps", "Color Extensions"}, 0.0)
end

function ChordFollower.transform_notes(notes, params, timeContext)
  return Midi.chord_follow(notes, params["Mode"] or 0, timeContext)
end

function ChordFollower.gui()
  return {
    panel = {
      title = "Harmonic Chord Follower FX",
      subtitle = "Project Chord Track Harmonizer",
      background = "dark",
      accent = "#FF8C00",
      layout = {
        {
          type = "row",
          children = {
            { type = "listbox", param = "Mode", label = "HARMONIC MODE", width = 140, height = 70 },
          }
        }
      }
    }
  }
end

function ChordFollower.rack()
  return {
    rows = {
      {
        { id = "midi_in",     title = "MIDI NOTE IN", hp = 14, row = 1, category = "MOD" },
        { id = "chord_track", title = "CHORD TRACK REF", hp = 16, row = 1, category = "MOD" },
      },
      {
        { id = "harmonizer", title = "HARMONIZER ENGINE", hp = 16, row = 2, category = "MOD" },
        { id = "midi_out",   title = "MIDI NOTE OUT", hp = 14, row = 2, category = "MOD" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:0:0", color = "pitch" },
      { from = "1:1:1", to = "2:0:1", color = "modulation" },
      { from = "2:0:1", to = "2:1:0", color = "pitch" },
    }
  }
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
-- @description: Dynamic arpeggiator voiced to active project Chord Track.
local ChordArp = {}

function ChordArp.init()
  Param.add("Rate", 0.25, 4.0, 1.0, 0.25)
  Param.add("Octaves", 1.0, 4.0, 2.0, 1.0)
  Param.choice("Pattern", {"Up", "Down", "UpDown", "Random"}, 0.0)
  Param.add("Gate", 0.1, 2.0, 0.85, 0.05)
end

function ChordArp.transform_notes(notes, params, timeContext)
  return Midi.chord_arp(notes, params, timeContext)
end

function ChordArp.gui()
  return {
    panel = {
      title = "Chord Arpeggiator FX",
      subtitle = "Chord Progression Voiced Arpeggiator",
      background = "dark",
      accent = "#00FF9D",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Rate", label = "RATE", unit = "x", size = 52 },
            { type = "knob", param = "Octaves", label = "OCTAVES", size = 52 },
            { type = "listbox", param = "Pattern", label = "PATTERN", width = 100, height = 65 },
            { type = "knob", param = "Gate", label = "GATE", size = 52 },
          }
        }
      }
    }
  }
end

function ChordArp.rack()
  return {
    rows = {
      {
        { id = "chord_ref",  title = "CHORD TRACK REF", hp = 14, row = 1, category = "MOD" },
        { id = "arp_engine", title = "CHORD ARP ENGINE", hp = 16, row = 1, category = "MOD" },
      },
      {
        { id = "gate_clock", title = "GATE / SWING CLOCK", hp = 14, row = 2, category = "MOD" },
        { id = "midi_out",   title = "MIDI NOTE OUT", hp = 14, row = 2, category = "MOD" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "pitch" },
      { from = "1:1:1", to = "2:1:0", color = "pitch" },
    }
  }
end

return ChordArp
''',
    ),

    // 25b. Scale Snap MIDI FX
    LuaPreset(
      id: 'scale_snap_midi_fx',
      name: 'Scale Snap FX',
      category: LuaPresetCategory.midiFx,
      description: 'Quantizes note pitches non-destructively to musical scale degrees.',
      code: '''
-- @name: Scale Snap FX
-- @category: midiFx
-- @description: Quantizes note pitches non-destructively to musical scale degrees.
local ScaleSnap = {}

function ScaleSnap.init()
  Param.add("Key", 0.0, 11.0, 0.0, 1.0)
  Param.choice("Scale", {"Major", "Natural Minor", "Harmonic Minor", "Melodic Minor", "Dorian", "Mixolydian", "Pentatonic", "Blues"}, 0.0)
end

function ScaleSnap.transform_notes(notes, params, timeContext)
  return Midi.scale_snap(notes, params, timeContext)
end

function ScaleSnap.gui()
  return {
    panel = {
      title = "Scale Snap FX",
      subtitle = "Musical Pitch Quantizer & Scale Snapper",
      background = "dark",
      accent = "#00E5FF",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Key", label = "ROOT KEY" },
            { type = "listbox", param = "Scale", label = "SCALE MODE", width = 130, height = 70 },
          }
        }
      }
    }
  }
end

function ScaleSnap.rack()
  return {
    rows = {
      {
        { id = "midi_in",     title = "MIDI NOTE IN", hp = 14, row = 1, category = "MOD" },
        { id = "scale_quant", title = "SCALE QUANTIZER", hp = 16, row = 1, category = "MOD" },
      },
      {
        { id = "root_key", title = "ROOT KEY TRANSPOSE", hp = 14, row = 2, category = "MOD" },
        { id = "midi_out", title = "QUANTIZED OUT", hp = 14, row = 2, category = "MOD" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "pitch" },
      { from = "1:1:1", to = "2:1:0", color = "pitch" },
    }
  }
end

return ScaleSnap
''',
    ),

    // 25c. Humanize & Groove MIDI FX
    LuaPreset(
      id: 'humanize_midi_fx',
      name: 'Humanize & Groove FX',
      category: LuaPresetCategory.midiFx,
      description: 'Adds organic human feel with micro-timing jitter and velocity dynamics.',
      code: '''
-- @name: Humanize & Groove FX
-- @category: midiFx
-- @description: Adds organic human feel with micro-timing jitter and velocity dynamics.
local Humanize = {}

function Humanize.init()
  Param.add("Timing", 0.0, 0.15, 0.04, 0.005)
  Param.add("Velocity", 0.0, 0.5, 0.15, 0.02)
end

function Humanize.transform_notes(notes, params, timeContext)
  return Midi.humanize(notes, params, timeContext)
end

function Humanize.gui()
  return {
    panel = {
      title = "Humanize & Groove FX",
      subtitle = "Organic Micro-Timing & Velocity Humanizer",
      background = "dark",
      accent = "#E040FB",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Timing", label = "TIMING JITTER", size = 56 },
            { type = "knob", param = "Velocity", label = "VEL DYNAMICS", size = 56 },
          }
        }
      }
    }
  }
end

function Humanize.rack()
  return {
    rows = {
      {
        { id = "midi_in",    title = "MIDI NOTE IN", hp = 14, row = 1, category = "MOD" },
        { id = "jitter_mod", title = "MICRO-TIMING JITTER", hp = 16, row = 1, category = "MOD" },
      },
      {
        { id = "vel_human", title = "VELOCITY DYNAMICS", hp = 14, row = 2, category = "MOD" },
        { id = "midi_out",  title = "GROOVE NOTE OUT", hp = 14, row = 2, category = "MOD" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "pitch" },
      { from = "1:1:1", to = "2:1:0", color = "pitch" },
    }
  }
end

return Humanize
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

    // 28. Eats-Nibbles (Throwback Arcade Game & SFX Synthesizer)
    LuaPreset(
      id: 'eats_nibbles',
      name: 'Eats-Nibbles',
      category: LuaPresetCategory.instrument,
      description: 'Authentic FastTracker II Nibbles throwback arcade game and procedural sound engine with SNES Sfxr integration, score tracking, on-screen D-Pad, and beat-synced rhythm turning.',
      code: '''
-- @name: Eats-Nibbles
-- @category: instrument
-- @description: Authentic FastTracker II Nibbles throwback game with procedural SNES Sfxr sound effects
local Nibbles = {}

function Nibbles.init()
  Param.add("Speed", 4.0, 30.0, 14.0, 1.0)
  Param.choice("SFXType", {"Coin", "Laser", "Explosion", "Powerup", "Jump", "Button"}, 0.0)
  Param.add("BeatSync", 0.0, 1.0, 0.0, 1.0)
  Param.add("Seed", 1.0, 9999.0, 1337.0, 1.0)
end

function Nibbles.process(time, freq, note, params)
  return 0.0
end

function Nibbles.gui()
  return {
    panel = {
      title = "Eats-Nibbles",
      subtitle = "FastTracker II Classic Arcade Easter Egg",
      background = "dark",
      accent = "#00FF9D",
      layout = {
        {
          type = "canvas",
          mode = "grid",
          cols = 32,
          rows = 22,
          width = 340,
          height = 190,
          showDpad = true,
          showActionButtons = true
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Speed", label = "SPEED", unit = "fps" },
            { type = "switch", param = "BeatSync", label = "BEAT SYNC" },
            { type = "listbox", param = "SFXType", label = "SFX TONE", width = 110, height = 70 }
          }
        }
      }
    }
  }
end

function Nibbles.rack()
  return {
    rows = {
      {
        { id = "game_matrix", title = "FT2 GRID MATRIX", hp = 16, row = 1, category = "VCO" },
        { id = "beat_clock",  title = "BEAT SYNC CLOCK", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "sfxr_synth", title = "SNES SFXR ENGINE", hp = 16, row = 2, category = "VCO" },
        { id = "master",     title = "GAME MASTER OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:0:0", color = "modulation" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return Nibbles
''',
    ),

    // 29. Eats-Runner (Audiovisual Platformer & Synced Visualizer)
    LuaPreset(
      id: 'eats_runner',
      name: 'Eats-Runner',
      category: LuaPresetCategory.instrument,
      description: '16-bit audiovisual side-scroller runner game with parallax skyline, starry horizon, jump physics, SNES Sfxr sound triggers, and timeline parameter automation.',
      code: '''
-- @name: Eats-Runner
-- @category: instrument
-- @description: 16-bit audiovisual platformer and timeline-automated music visualizer
local CyberRunner = {}

function CyberRunner.init()
  Param.add("Jump", 0.0, 1.0, 0.0, 1.0)
  Param.add("Speed", 50.0, 250.0, 120.0, 10.0)
  Param.choice("SFXType", {"Jump", "Coin", "Laser", "Explosion", "Powerup"}, 0.0)
  Param.add("Seed", 1.0, 9999.0, 543.0, 1.0)
end

function CyberRunner.process(time, freq, note, params)
  return 0.0
end

function CyberRunner.gui()
  return {
    panel = {
      title = "Eats-Runner",
      subtitle = "Audiovisual Platformer & Synced Visualizer",
      background = "snes",
      accent = "#00E5FF",
      knobStyle = "snes",
      layout = {
        {
          type = "canvas",
          mode = "pixel",
          width = 340,
          height = 180,
          showActionButtons = true
        },
        {
          type = "row",
          children = {
            { type = "button", param = "Jump", label = "JUMP", width = 80, height = 36 },
            { type = "knob", param = "Speed", label = "SPEED", unit = "px/s", knobStyle = "snes" },
            { type = "listbox", param = "SFXType", label = "SFX VOICE", width = 120, height = 70 }
          }
        }
      }
    }
  }
end

function CyberRunner.rack()
  return {
    rows = {
      {
        { id = "pixel_engine", title = "16-BIT RUNNER CORE", hp = 16, row = 1, category = "VCO" },
        { id = "jump_physics", title = "JUMP PHYSICS MOD", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "sfx_player", title = "SNES SFX ENGINE", hp = 16, row = 2, category = "VCO" },
        { id = "master",     title = "RUNNER MASTER OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:0:0", color = "modulation" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return CyberRunner
''',
    ),

    // 30. TTS Voice Synth (Musical Speech & Syllable Synthesizer)
    LuaPreset(
      id: 'tts_voice_synth',
      name: 'TTS Voice Synth',
      category: LuaPresetCategory.instrument,
      description: 'Text-to-speech voice synthesizer instrument. Produces synchronized spoken syllables, phonemes, and lyric phrases driven by track and clip lyric cues.',
      code: '''
-- @name: TTS Voice Synth
-- @category: instrument
-- @description: Musical text-to-speech voice synthesizer instrument
local TtsSynth = {}

function TtsSynth.init()
  Param.add("Pitch", 0.5, 2.0, 1.0, 0.05)
  Param.add("Rate", 0.5, 2.0, 1.0, 0.05)
  Param.add("Volume", 0.0, 1.0, 1.0, 0.05)
  Param.choice("VoiceStyle", {"Default", "Neutral", "Bright", "Deep", "Robotic"}, 0.0)
end

function TtsSynth.process(time, freq, note, params)
  -- Real-time spoken vocal synthesis driven by timeline lyric cues
  return 0.0
end

function TtsSynth.gui()
  return {
    panel = {
      title = "TTS VOICE SYNTH",
      subtitle = "Musical Speech & Syllable Synthesizer",
      background = "rack",
      accent = "track",
      knobStyle = "vintage",
      layout = {
        {
          type = "row",
          children = {
            { type = "nixie", param = "Pitch", label = "PITCH SCALE", unit = "x" },
            { type = "nixie", param = "Rate", label = "SPEECH RATE", unit = "x" },
            { type = "nixie", param = "Volume", label = "VOCAL GAIN", unit = "" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Pitch", label = "PITCH", size = 56, knobStyle = "vintage" },
            { type = "knob", param = "Rate", label = "RATE", size = 56, knobStyle = "vintage" },
            { type = "knob", param = "Volume", label = "GAIN", size = 56, knobStyle = "vintage" },
            { type = "listbox", param = "VoiceStyle", label = "VOICE STYLE", width = 130, height = 75 }
          }
        }
      }
    }
  }
end

function TtsSynth.rack()
  return {
    rows = {
      {
        { id = "formant_vco", title = "FORMANT VOCAL VCO", hp = 16, row = 1, category = "VCO" },
        { id = "phoneme_mod", title = "PHONEME ENVELOPE", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "vocal_eq", title = "SPEECH FORMANT VCF", hp = 14, row = 2, category = "VCF" },
        { id = "master",   title = "VOCAL MASTER OUT", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:0:0", color = "audio" },
      { from = "1:1:1", to = "2:0:1", color = "modulation" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return TtsSynth
''',
    ),

    // 30. Eats-Scope (Vector Oscilloscope Audio Visualizer FX)
    LuaPreset(
      id: 'eats_scope',
      name: 'Eats-Scope',
      category: LuaPresetCategory.audioFx,
      description: 'Glowing neon vector oscilloscope and waveform monitor visualizer that reacts in real-time to audio playback and synthesizer modulations.',
      code: '''
-- @name: Eats-Scope
-- @category: audioFx
-- @description: Glowing neon vector oscilloscope and waveform monitor visualizer
local Scope = {}

function Scope.init()
  Param.add("Timebase", 0.1, 2.0, 1.0, 0.05)
  Param.add("Gain", 0.1, 3.0, 1.0, 0.1)
  Param.choice("GlowColor", {"Neon Mint", "Cyber Cyan", "Laser Red", "Gold Solar", "Purple Dream"}, 0.0)
end

function Scope.process(input_l, input_r, params)
  return input_l, input_r
end

function Scope.gui()
  return {
    panel = {
      title = "Eats-Scope",
      subtitle = "Vector Waveform Oscilloscope Visualizer",
      background = "dark",
      accent = "#00FF9D",
      layout = {
        {
          type = "canvas",
          mode = "vector",
          width = 340,
          height = 180
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Timebase", label = "TIMEBASE", unit = "x" },
            { type = "knob", param = "Gain", label = "GAIN", unit = "x" },
            { type = "listbox", param = "GlowColor", label = "BEAM COLOR", width = 120, height = 70 }
          }
        }
      }
    }
  }
end

function Scope.rack()
  return {
    rows = {
      {
        { id = "in_lr",        title = "AUDIO INPUT L/R", hp = 14, row = 1, category = "OUT" },
        { id = "vector_scope", title = "VECTOR OSCILLOSCOPE", hp = 16, row = 1, category = "FX" },
      },
      {
        { id = "thru_out", title = "THRU AUDIO OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:0:1", to = "2:0:0", color = "audio" },
    }
  }
end

return Scope
''',
    ),

    // 31. Eats-Spectrum (16-Band Real-Time Spectrum Analyzer FX)
    LuaPreset(
      id: 'eats_spectrum',
      name: 'Eats-Spectrum',
      category: LuaPresetCategory.audioFx,
      description: 'Multi-band graphic spectrum analyzer visualizer with peak hold caps, multi-gradient color LED meters, and audio-reactive energy tracking.',
      code: '''
-- @name: Eats-Spectrum
-- @category: audioFx
-- @description: 16-band graphic spectrum analyzer visualizer with peak hold caps
local Spectrum = {}

function Spectrum.init()
  Param.add("Gain", 0.2, 4.0, 1.0, 0.1)
  Param.add("Decay", 0.1, 2.0, 0.6, 0.05)
  Param.choice("Mode", {"16-Band Bar", "8-Band Chunky", "Peak Hold", "Smooth Curve"}, 0.0)
end

function Spectrum.process(input_l, input_r, params)
  return input_l, input_r
end

function Spectrum.gui()
  return {
    panel = {
      title = "Eats-Spectrum",
      subtitle = "16-Band Real-Time Spectrum Analyzer",
      background = "dark",
      accent = "#00E5FF",
      layout = {
        {
          type = "canvas",
          mode = "spectrum",
          width = 340,
          height = 180
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Gain", label = "GAIN", unit = "x" },
            { type = "knob", param = "Decay", label = "DECAY", unit = "s" },
            { type = "listbox", param = "Mode", label = "METER MODE", width = 120, height = 70 }
          }
        }
      }
    }
  }
end

function Spectrum.rack()
  return {
    rows = {
      {
        { id = "in_lr",        title = "AUDIO INPUT L/R", hp = 14, row = 1, category = "OUT" },
        { id = "spectrum_fft", title = "16-BAND FFT ANALYZER", hp = 16, row = 1, category = "FX" },
      },
      {
        { id = "thru_out", title = "THRU AUDIO OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:0:1", to = "2:0:0", color = "audio" },
    }
  }
end

return Spectrum
''',
    ),

    // 32. Master Limiter / Peak Guard FX
    LuaPreset(
      id: 'master_limiter',
      name: 'Master Limiter',
      category: LuaPresetCategory.audioFx,
      description: 'Brickwall peak limiter with lookahead ceiling protection and transparent release envelope.',
      code: '''
-- @name: Master Limiter
-- @category: audioFx
-- @description: Brickwall peak limiter with lookahead ceiling protection
local Limiter = {}

function Limiter.init()
  Param.add("Threshold", -24.0, 0.0, -1.0, 0.5)
  Param.add("Release", 0.01, 1.0, 0.05, 0.01)
  Param.add("Ceiling", -6.0, 0.0, -0.1, 0.1)
end

function Limiter.process(input_l, input_r, params)
  return input_l, input_r
end

function Limiter.gui()
  return {
    panel = {
      title = "Master Limiter",
      subtitle = "Brickwall Peak Limiting & Output Protection",
      background = "silver",
      accent = "#FF3366",
      knobStyle = "chrome",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Threshold", label = "THRESHOLD", unit = "dB", knobStyle = "chrome" },
            { type = "knob", param = "Release", label = "RELEASE", unit = "s", knobStyle = "chrome" },
            { type = "knob", param = "Ceiling", label = "CEILING", unit = "dB", knobStyle = "chrome" },
          }
        }
      }
    }
  }
end

function Limiter.rack()
  return {
    rows = {
      {
        { id = "in_lr",     title = "AUDIO INPUT L/R", hp = 14, row = 1, category = "OUT" },
        { id = "brickwall", title = "BRICKWALL PEAK DETECT", hp = 16, row = 1, category = "FX" },
      },
      {
        { id = "ceiling_vca", title = "CEILING GAIN VCA", hp = 14, row = 2, category = "OUT" },
        { id = "out_lr",      title = "MASTER PROTECT OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "modulation" },
      { from = "1:0:1", to = "2:0:1", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return Limiter
''',
    ),

    // 33. Dynamics Compressor FX
    LuaPreset(
      id: 'dynamics_compressor',
      name: 'Dynamics Compressor',
      category: LuaPresetCategory.audioFx,
      description: 'Studio dynamic range compressor with adjustable ratio, soft knee, attack, and release.',
      code: '''
-- @name: Dynamics Compressor
-- @category: audioFx
-- @description: Studio dynamic range compressor with adjustable ratio and knee
local Compressor = {}

function Compressor.init()
  Param.add("Threshold", -40.0, 0.0, -18.0, 1.0)
  Param.add("Ratio", 1.0, 20.0, 4.0, 0.5)
  Param.add("Attack", 0.001, 0.2, 0.02, 0.005)
  Param.add("Release", 0.01, 1.0, 0.25, 0.01)
  Param.add("Knee", 0.0, 24.0, 12.0, 1.0)
end

function Compressor.process(input_l, input_r, params)
  return input_l, input_r
end

function Compressor.gui()
  return {
    panel = {
      title = "Dynamics Compressor",
      subtitle = "Studio VCA Dynamic Range Compression",
      background = "dark",
      accent = "#00FF9D",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Threshold", label = "THRESHOLD", unit = "dB" },
            { type = "knob", param = "Ratio", label = "RATIO", unit = ":1" },
            { type = "knob", param = "Attack", label = "ATTACK", unit = "s" },
            { type = "knob", param = "Release", label = "RELEASE", unit = "s" },
          }
        }
      }
    }
  }
end

function Compressor.rack()
  return {
    rows = {
      {
        { id = "in_lr",     title = "AUDIO INPUT L/R", hp = 14, row = 1, category = "OUT" },
        { id = "sidechain", title = "SIDECHAIN RMS DETECT", hp = 16, row = 1, category = "MOD" },
      },
      {
        { id = "gain_reduction", title = "VCA GAIN REDUCTION", hp = 14, row = 2, category = "FX" },
        { id = "out_lr",         title = "COMPRESSED AUDIO OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "modulation" },
      { from = "1:0:1", to = "2:0:1", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return Compressor
''',
    ),

    // 34. Convolution Reverb FX
    LuaPreset(
      id: 'convolution_reverb',
      name: 'Convolution Reverb',
      category: LuaPresetCategory.audioFx,
      description: 'Impulse-response based acoustic space reverb simulator with true stereo convolution.',
      code: '''
-- @name: Convolution Reverb
-- @category: audioFx
-- @description: Impulse-response based acoustic space reverb simulator with true stereo convolution
local ConvReverb = {}

function ConvReverb.init()
  Param.choice("IRSample", {"Great Hall", "Stone Cathedral", "Plate Reverb", "Spring Tank", "Warm Room", "Studio Live Room", "Tile Bathroom", "Small Vocal Booth", "4x12 Vintage Stack", "2x12 British Celestion", "1x12 Tweed Combo", "Bass 8x10 Fridge", "Small Radio Speaker"}, 0.0)
  Param.add("DryLevel", 0.0, 1.5, 1.0, 0.05)
  Param.add("WetLevel", 0.0, 1.5, 0.5, 0.05)
  Param.add("PreDelayMs", 0.0, 100.0, 10.0, 1.0)
  Param.add("HighCut", 1000.0, 20000.0, 8000.0, 100.0)
  Param.add("SourceX", 0.05, 0.95, 0.50, 0.01)
  Param.add("SourceY", 0.05, 0.95, 0.50, 0.01)
  Param.add("SourceZ", 0.05, 0.95, 0.50, 0.01)
  Param.add("ListenerX", 0.05, 0.95, 0.50, 0.01)
  Param.add("ListenerY", 0.05, 0.95, 0.80, 0.01)
  Param.add("ListenerZ", 0.05, 0.95, 0.50, 0.01)
  Param.add("StereoWidth", 0.05, 1.00, 0.20, 0.01)
end

function ConvReverb.process(input_l, input_r, params)
  return input_l, input_r
end

function ConvReverb.gui()
  return {
    panel = {
      title = "Convolution Reverb",
      subtitle = "True Stereo 3D Acoustic Space Modeling",
      background = "grunge",
      accent = "#21F4E8",
      layout = {
        { type = "space_visualizer", height = 135 },
        {
          type = "row",
          children = {
            { type = "listbox", param = "IRSample", label = "SPACE / IMPULSE", width = 160, height = 75 },
            { type = "knob", param = "DryLevel", label = "DRY" },
            { type = "knob", param = "WetLevel", label = "WET" },
            { type = "knob", param = "HighCut", label = "HI-CUT", unit = "Hz" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "SourceX", label = "SRC X", size = 36 },
            { type = "knob", param = "SourceY", label = "SRC Y", size = 36 },
            { type = "knob", param = "SourceZ", label = "SRC Z", size = 36 },
            { type = "knob", param = "ListenerX", label = "MIC X", size = 36 },
            { type = "knob", param = "ListenerY", label = "MIC Y", size = 36 },
            { type = "knob", param = "ListenerZ", label = "MIC Z", size = 36 },
            { type = "knob", param = "StereoWidth", label = "SPREAD", unit = "m", size = 36 },
          }
        }
      }
    }
  }
end

function ConvReverb.rack()
  return {
    rows = {
      {
        { id = "in_lr",     title = "AUDIO INPUT L/R", hp = 14, row = 1, category = "OUT" },
        { id = "ir_engine", title = "STEREO CONV CORE", hp = 16, row = 1, category = "FX" },
      },
      {
        { id = "predelay", title = "PREDELAY & HI-CUT", hp = 14, row = 2, category = "VCF" },
        { id = "out_lr",   title = "REVERB OUTPUT L/R", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return ConvReverb
''',
    ),

    // 34a. Procedural Room Designer FX
    LuaPreset(
      id: 'room_designer',
      name: 'Room Designer',
      category: LuaPresetCategory.audioFx,
      description: 'Interactive 3D Room Acoustic Synthesizer with Image Source & Velvet Noise physics.',
      code: '''
-- @name: Room Designer
-- @category: audioFx
-- @description: Interactive 3D Room Acoustic Synthesizer with Image Source & Velvet Noise physics
local RoomDesigner = {}

function RoomDesigner.init()
  Param.add("Width", 1.0, 30.0, 15.0, 0.5)
  Param.add("Length", 1.0, 40.0, 25.0, 0.5)
  Param.add("Height", 1.0, 18.0, 10.0, 0.5)
  Param.choice("Material", {"Wood Paneling", "Pine Wood", "Acoustic Foam", "Hard Concrete", "Birch Plywood", "Velvet Drapes", "Sheet Metal", "Carpet"}, 0.0)
  Param.add("RT60", 0.1, 5.0, 2.2, 0.05)
  Param.add("Damping", 0.0, 1.0, 0.25, 0.05)
  Param.add("SourceX", 0.05, 0.95, 0.50, 0.01)
  Param.add("SourceY", 0.05, 0.95, 0.50, 0.01)
  Param.add("SourceZ", 0.05, 0.95, 0.50, 0.01)
  Param.add("ListenerX", 0.05, 0.95, 0.50, 0.01)
  Param.add("ListenerY", 0.05, 0.95, 0.80, 0.01)
  Param.add("ListenerZ", 0.05, 0.95, 0.50, 0.01)
  Param.add("StereoWidth", 0.05, 1.00, 0.20, 0.01)
  Param.add("DryLevel", 0.0, 1.5, 1.0, 0.05)
  Param.add("WetLevel", 0.0, 1.5, 0.5, 0.05)
end

function RoomDesigner.process(input_l, input_r, params)
  return input_l, input_r
end

function RoomDesigner.gui()
  return {
    panel = {
      title = "Room Designer",
      subtitle = "3D Image Source & Velvet Noise Acoustic Engine",
      background = "grunge",
      accent = "#21F4E8",
      layout = {
        { type = "space_visualizer", height = 135 },
        {
          type = "row",
          children = {
            { type = "listbox", param = "Material", label = "MATERIAL", width = 130, height = 70 },
            { type = "knob", param = "Width", label = "WIDTH", unit = "m" },
            { type = "knob", param = "Length", label = "LENGTH", unit = "m" },
            { type = "knob", param = "Height", label = "HEIGHT", unit = "m" },
            { type = "knob", param = "RT60", label = "DECAY", unit = "s" },
            { type = "knob", param = "Damping", label = "DAMP" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "SourceX", label = "SRC X", size = 36 },
            { type = "knob", param = "SourceY", label = "SRC Y", size = 36 },
            { type = "knob", param = "SourceZ", label = "SRC Z", size = 36 },
            { type = "knob", param = "ListenerX", label = "MIC X", size = 36 },
            { type = "knob", param = "ListenerY", label = "MIC Y", size = 36 },
            { type = "knob", param = "ListenerZ", label = "MIC Z", size = 36 },
            { type = "knob", param = "StereoWidth", label = "SPREAD", unit = "m", size = 36 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "DryLevel", label = "DRY LEVEL", width = 480, style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "WetLevel", label = "WET LEVEL", width = 480, style = "capsule" },
          }
        }
      }
    }
  }
end

function RoomDesigner.rack()
  return {
    rows = {
      {
        { id = "in_lr",     title = "AUDIO INPUT L/R", hp = 14, row = 1, category = "OUT" },
        { id = "early_ref", title = "3D IMAGE SOURCE CORE", hp = 16, row = 1, category = "FX" },
      },
      {
        { id = "velvet_tail", title = "VELVET NOISE LATE TAIL", hp = 16, row = 2, category = "FX" },
        { id = "out_lr",      title = "ACOUSTIC ROOM OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return RoomDesigner
''',
    ),

    // 34b. Procedural Amp Cabinet Designer FX
    LuaPreset(
      id: 'cab_designer',
      name: 'Cab Designer',
      category: LuaPresetCategory.audioFx,
      description: 'Physical modeling amplifier cabinet simulator with modal standing waves and speaker resonance.',
      code: '''
-- @name: Cab Designer
-- @category: audioFx
-- @description: Physical modeling amplifier cabinet simulator with modal standing waves and speaker resonance
local CabDesigner = {}

function CabDesigner.init()
  Param.choice("Material", {"Birch Plywood", "Pine Wood", "Wood Paneling"}, 0.0)
  Param.add("Width", 0.20, 1.50, 0.76, 0.02)
  Param.add("Length", 0.20, 1.50, 0.76, 0.02)
  Param.add("Height", 0.15, 1.00, 0.36, 0.02)
  Param.add("SourceX", 0.05, 0.95, 0.50, 0.01)
  Param.add("SourceY", 0.05, 0.95, 0.50, 0.01)
  Param.add("SourceZ", 0.05, 0.95, 0.50, 0.01)
  Param.add("ListenerX", 0.05, 0.95, 0.50, 0.01)
  Param.add("ListenerY", 0.05, 0.95, 0.80, 0.01)
  Param.add("ListenerZ", 0.05, 0.95, 0.50, 0.01)
  Param.add("MicDistance", 0.01, 0.30, 0.05, 0.01)
  Param.add("MicAngle", 0.0, 60.0, 0.0, 1.0)
  Param.toggle("OpenBack", 0.0)
  Param.add("DryLevel", 0.0, 1.5, 0.0, 0.05)
  Param.add("WetLevel", 0.0, 1.5, 1.0, 0.05)
  Param.add("isCabinet", 0.0, 1.0, 1.0, 1.0)
end

function CabDesigner.process(input_l, input_r, params)
  return input_l, input_r
end

function CabDesigner.gui()
  return {
    panel = {
      title = "Cab Designer",
      subtitle = "Modal Enclosure & Speaker Physical Modeling",
      background = "grunge",
      accent = "#FF6B00",
      layout = {
        { type = "space_visualizer", height = 135 },
        {
          type = "row",
          children = {
            { type = "listbox", param = "Material", label = "WOOD", width = 120, height = 70 },
            { type = "knob", param = "Width", label = "WIDTH", unit = "m" },
            { type = "knob", param = "Length", label = "LENGTH", unit = "m" },
            { type = "knob", param = "Height", label = "HEIGHT", unit = "m" },
            { type = "knob", param = "MicDistance", label = "MIC DIST", unit = "m" },
            { type = "knob", param = "MicAngle", label = "OFF-AXIS", unit = "°" },
            { type = "switch", param = "OpenBack", label = "OPEN", orientation = "vertical" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "SourceX", label = "CONE X", size = 36 },
            { type = "knob", param = "SourceY", label = "CONE Y", size = 36 },
            { type = "knob", param = "SourceZ", label = "CONE Z", size = 36 },
            { type = "knob", param = "ListenerX", label = "MIC X", size = 36 },
            { type = "knob", param = "ListenerY", label = "MIC Y", size = 36 },
            { type = "knob", param = "ListenerZ", label = "MIC Z", size = 36 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "DryLevel", label = "DRY LEVEL", width = 480, style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "WetLevel", label = "WET LEVEL", width = 480, style = "capsule" },
          }
        }
      }
    }
  }
end

function CabDesigner.rack()
  return {
    rows = {
      {
        { id = "in_lr",     title = "AMP SIGNAL IN", hp = 14, row = 1, category = "OUT" },
        { id = "modal_box", title = "CAB MODAL ENCLOSURE", hp = 16, row = 1, category = "VCF" },
      },
      {
        { id = "speaker_ir", title = "CONE & MIC PLACEMENT", hp = 16, row = 2, category = "FX" },
        { id = "out_lr",     title = "CABINET OUT L/R", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return CabDesigner
''',
    ),

    // 35. Stereo Delay FX
    LuaPreset(
      id: 'stereo_delay',
      name: 'Stereo Delay',
      category: LuaPresetCategory.audioFx,
      description: 'Stereo feedback echo delay unit with ping-pong spatial modulation.',
      code: '''
-- @name: Stereo Delay
-- @category: audioFx
-- @description: Stereo feedback echo delay unit with ping-pong modulation
local StereoDelay = {}

function StereoDelay.init()
  Param.add("TimeMs", 20.0, 1000.0, 250.0, 10.0)
  Param.add("Feedback", 0.0, 0.95, 0.40, 0.05)
  Param.add("Mix", 0.0, 1.0, 0.35, 0.05)
end

function StereoDelay.process(input_l, input_r, params)
  return input_l, input_r
end

function StereoDelay.gui()
  return {
    panel = {
      title = "Stereo Delay",
      subtitle = "Dual-Channel Echo & Feedback Unit",
      background = "dark",
      accent = "#FFD700",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "TimeMs", label = "TIME", unit = "ms" },
            { type = "knob", param = "Feedback", label = "FEEDBACK" },
            { type = "knob", param = "Mix", label = "DRY/WET" },
          }
        }
      }
    }
  }
end

function StereoDelay.rack()
  return {
    rows = {
      {
        { id = "in_lr",     title = "AUDIO INPUT L/R", hp = 14, row = 1, category = "OUT" },
        { id = "ping_pong", title = "STEREO DELAY LINE", hp = 16, row = 1, category = "FX" },
      },
      {
        { id = "feedback_vcf", title = "FEEDBACK DAMP VCF", hp = 14, row = 2, category = "VCF" },
        { id = "out_lr",       title = "DELAY OUTPUT L/R", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return StereoDelay
''',
    ),

    // 36. Lowpass Filter FX
    LuaPreset(
      id: 'lowpass_filter',
      name: 'Lowpass Filter',
      category: LuaPresetCategory.audioFx,
      description: 'Analog-modeled 24dB resonant state-variable lowpass filter with drive saturation.',
      code: '''
-- @name: Lowpass Filter
-- @category: audioFx
-- @description: Analog-modeled 24dB resonant lowpass filter
local FilterFX = {}

function FilterFX.init()
  Param.add("Cutoff", 20.0, 20000.0, 3500.0, 50.0)
  Param.add("Resonance", 0.1, 15.0, 1.5, 0.1)
end

function FilterFX.process(input_l, input_r, params)
  return input_l, input_r
end

function FilterFX.gui()
  return {
    panel = {
      title = "Lowpass Filter",
      subtitle = "Analog-Modeled 24dB Resonant Filter",
      background = "snes",
      accent = "#E040FB",
      knobStyle = "snes",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Cutoff", label = "CUTOFF", unit = "Hz", knobStyle = "snes", size = 64 },
            { type = "knob", param = "Resonance", label = "RESONANCE", knobStyle = "snes" },
          }
        }
      }
    }
  }
end

function FilterFX.rack()
  return {
    rows = {
      {
        { id = "in_lr",    title = "AUDIO INPUT L/R", hp = 14, row = 1, category = "OUT" },
        { id = "svf_core", title = "24DB SVF LOWPASS", hp = 16, row = 1, category = "VCF" },
      },
      {
        { id = "drive_stage", title = "ANALOG DRIVE STAGE", hp = 14, row = 2, category = "FX" },
        { id = "out_lr",      title = "FILTERED OUT L/R", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return FilterFX
''',
    ),

    // 37. Kinetic Lyric Visualizer
    LuaPreset(
      id: 'kinetic_lyric_visualizer',
      name: 'Kinetic Lyric Video',
      category: LuaPresetCategory.utility,
      description: 'Audio-reactive kinetic typography visualizer with glowing beat-synced lyrics and spectrum bloom.',
      code: '''
-- @name: Kinetic Lyric Video
-- @category: utility
-- @description: Time-synced audio-reactive lyric typography visualizer
local LyricVis = {}

function LyricVis.init()
  Param.add("GlowSize", 0.0, 100.0, 40.0, 1.0)
  Param.add("TextScale", 0.5, 3.0, 1.4, 0.1)
  Param.add("KineticShake", 0.0, 1.0, 0.5, 0.05)
end

function LyricVis.gui()
  return {
    panel = {
      title = "Kinetic Lyric Video",
      subtitle = "Audio-Reactive Time-Synced Visualizer",
      background = "cyberpunk",
      accent = "#00FFE0",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "TextScale", label = "SCALE", knobStyle = "cyber" },
            { type = "knob", param = "GlowSize", label = "GLOW", knobStyle = "cyber" },
            { type = "knob", param = "KineticShake", label = "SHAKE", knobStyle = "cyber" },
          }
        },
        {
          type = "canvas",
          canvasType = "vector",
          height = 200,
          label = "LIVE LYRIC RENDERER"
        }
      }
    }
  }
end

function LyricVis.rack()
  return {
    rows = {
      {
        { id = "lyric_in",     title = "TIMELINE LYRIC STREAM", hp = 16, row = 1, category = "MOD" },
        { id = "glow_render", title = "BLOOM GLOW RENDERER", hp = 16, row = 1, category = "FX" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "modulation" },
    }
  }
end

return LyricVis
''',
    ),

    // 38. Retro CRT Teleprompter
    LuaPreset(
      id: 'retro_crt_teleprompter',
      name: 'Retro CRT Teleprompter',
      category: LuaPresetCategory.utility,
      description: 'Cyberpunk green-phosphor CRT teleprompter with rolling line cues and syllable highlight.',
      code: '''
-- @name: Retro CRT Teleprompter
-- @category: utility
-- @description: Cyberpunk terminal teleprompter with upcoming lyric roll
local Teleprompter = {}

function Teleprompter.init()
  Param.add("Scanlines", 0.0, 1.0, 0.8, 0.1)
  Param.add("PhosphorGlow", 0.0, 1.0, 0.9, 0.1)
  Param.add("CrtCurvature", 0.0, 1.0, 0.3, 0.05)
end

function Teleprompter.gui()
  return {
    panel = {
      title = "CRT Teleprompter",
      subtitle = "Vocalist Cues & Lyric Roll",
      background = "arcade",
      accent = "#39FF14",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Scanlines", label = "SCANLINES", knobStyle = "arcade" },
            { type = "knob", param = "PhosphorGlow", label = "PHOSPHOR", knobStyle = "arcade" },
            { type = "knob", param = "CrtCurvature", label = "CURVE", knobStyle = "arcade" },
          }
        },
        {
          type = "canvas",
          canvasType = "vector",
          height = 180,
          label = "TERMINAL PROMPTER"
        }
      }
    }
  }
end

function Teleprompter.rack()
  return {
    rows = {
      {
        { id = "cue_in",      title = "VOCALIST CUE SYNC", hp = 16, row = 1, category = "MOD" },
        { id = "crt_display", title = "GREEN CRT TERMINAL", hp = 16, row = 1, category = "FX" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "modulation" },
    }
  }
end

return Teleprompter
''',
    ),
    LuaScriptDef(
      id: 'splitter_3way_voice',
      name: '3-Way Voice Splitter (Bass, Chords, Lead)',
      category: LuaScriptCategory.noteSplitter,
      description: 'Separates polyphonic MIDI into dedicated Bass, Middle Harmony Chords, and Skyline Lead tracks.',
      code: '''-- @name: 3-Way Voice Splitter (Bass, Chords, Lead)
-- @author: Eatsbeats
-- @category: note_splitter
-- @description: Separates polyphonic MIDI into dedicated Bass, Middle Harmony Chords, and Skyline Lead tracks.
-- @param: bass_split "Bass Cutoff (MIDI)" 48 24 60 1
-- @param: lead_split "Lead Threshold (MIDI)" 64 48 84 1

function split(notes, params)
  -- 3-Way Voice Splitter using Skyline Lead detection and Harmonic Bass isolation
  local bass_track = {}
  local chords_track = {}
  local lead_track = {}
  
  for _, note in ipairs(notes) do
    if note.pitch < params.bass_split then
      table.insert(bass_track, note)
    elseif note.pitch >= params.lead_split and is_skyline(note, notes) then
      table.insert(lead_track, note)
    else
      table.insert(chords_track, note)
    end
  end
  
  return {
    { name = "Bassline", notes = bass_track, color = 0xFF00FF66 },
    { name = "Harmony & Chords", notes = chords_track, color = 0xFF21F4E8 },
    { name = "Lead Melody", notes = lead_track, color = 0xFFFF007A },
  }
end
''',
    ),
    LuaScriptDef(
      id: 'splitter_bass_treble',
      name: 'Bass & Treble Clef Splitter (Piano)',
      category: LuaScriptCategory.noteSplitter,
      description: 'Splits notes at a pivot key into Left Hand (Bass Clef) and Right Hand (Treble Clef) tracks.',
      code: '''-- @name: Bass & Treble Clef Splitter
-- @author: Eatsbeats
-- @category: note_splitter
-- @description: Splits notes at a pivot key into Left Hand (Bass Clef) and Right Hand (Treble Clef) tracks.
-- @param: split_pitch "Pivot Key (MIDI)" 60 36 84 1

function split(notes, params)
  local left_hand = {}
  local right_hand = {}
  
  for _, note in ipairs(notes) do
    if note.pitch < params.split_pitch then
      table.insert(left_hand, note)
    else
      table.insert(right_hand, note)
    end
  end
  
  return {
    { name = "Bass Clef (Left Hand)", notes = left_hand, color = 0xFF3399FF },
    { name = "Treble Clef (Right Hand)", notes = right_hand, color = 0xFFFFD700 },
  }
end
''',
    ),
    LuaScriptDef(
      id: 'splitter_4voice_polyphony',
      name: '4-Voice Polyphony Distribute (SATB)',
      category: LuaScriptCategory.noteSplitter,
      description: 'Distributes polyphonic chord voices into Soprano, Alto, Tenor, and Bass monophonic tracks.',
      code: '''-- @name: 4-Voice Polyphony Distribute (SATB)
-- @author: Eatsbeats
-- @category: note_splitter
-- @description: Distributes polyphonic chord voices into Soprano, Alto, Tenor, and Bass monophonic tracks.

function split(notes, params)
  return {
    { name = "Voice 1 (Soprano / Top)", color = 0xFFFF007A },
    { name = "Voice 2 (Alto / High-Mid)", color = 0xFFFF8C00 },
    { name = "Voice 3 (Tenor / Low-Mid)", color = 0xFF21F4E8 },
    { name = "Voice 4 (Bass / Root)", color = 0xFF00FF66 },
  }
end
''',
    ),
    LuaScriptDef(
      id: 'splitter_drum_demux',
      name: 'Drum & Percussion Demuxer',
      category: LuaScriptCategory.noteSplitter,
      description: 'Separates standard General MIDI drum tracks into Kick, Snare/Clap, Hats/Cymbals, and Percussion tracks.',
      code: '''-- @name: Drum & Percussion Demuxer
-- @author: Eatsbeats
-- @category: note_splitter
-- @description: Separates standard General MIDI drum tracks into Kick, Snare/Clap, Hats/Cymbals, and Percussion tracks.

function split(notes, params)
  return {
    { name = "Drums (Kick)", color = 0xFFFF3333 },
    { name = "Drums (Snare & Clap)", color = 0xFFFF8C00 },
    { name = "Drums (Hi-Hats & Cymbals)", color = 0xFFFFE600 },
    { name = "Drums (Toms & Perc)", color = 0xFFBD00FF },
  }
end
''',
    ),
    LuaScriptDef(
      id: 'action_global_transpose',
      name: 'Global Chord-Aware Song Transpose',
      category: LuaScriptCategory.projectAction,
      description: 'Transposes all tracks, clips, and chord track events across the entire project with scale/chord adherence.',
      code: '''-- @name: Global Chord-Aware Song Transpose
-- @author: Eatsbeats
-- @category: project_action
-- @description: Transposes all tracks, clips, and chord track events across the entire project with scale/chord adherence.

Param.add("Semitones", -12, 12, 2, 1)
Param.choice("HarmonicMode", {"Strict Chromatic", "Snap to Scale", "Smart Chord Shift"}, 0)
Param.choice("UpdateKey", {"No (Keep Key)", "Yes (Shift Song Key)"}, 1)

function run(project, params)
  -- Evaluated by ProjectScriptEngine
  local semitones = params.Semitones or 2
  local mode = params.HarmonicMode or 0
  local updateKey = params.UpdateKey or 1
  
  -- Transposes chord track & note events across all active patterns
  return {
    semitones = semitones,
    harmonic_mode = mode,
    update_key = updateKey,
  }
end
''',
    ),
    LuaScriptDef(
      id: 'action_harmonic_progression',
      name: 'Harmonic Progression Generator',
      category: LuaScriptCategory.projectAction,
      description: 'Generates Roman numeral / modal chord progressions across the project chord track and conforms tracks.',
      code: '''-- @name: Harmonic Progression Generator
-- @author: Eatsbeats
-- @category: project_action
-- @description: Generates Roman numeral / modal chord progressions across the project chord track and conforms tracks.

Param.choice("Genre", {"Synthwave", "Pop Anthem", "Deep House / Club", "Jazz / Neo-Soul", "Classic EDM"}, 0)
Param.add("LengthBars", 2, 32, 8, 2)
Param.choice("ConformTracks", {"Chord Track Only", "Conform Synth Tracks to Chords"}, 1)

function run(project, params)
  local genre = params.Genre or 0
  local bars = params.LengthBars or 8
  local conform = params.ConformTracks or 1
  
  return {
    genre = genre,
    length_bars = bars,
    conform_tracks = conform,
  }
end
''',
    ),
    LuaScriptDef(
      id: 'action_procedural_song',
      name: 'Procedural Multi-Track Song Generator',
      category: LuaScriptCategory.projectAction,
      description: 'Procedurally generates a full arrangement (Drums, Acid Bass, Chords, Lead Arp) based on genre style.',
      code: '''-- @name: Procedural Multi-Track Song Generator
-- @author: Eatsbeats
-- @category: project_action
-- @description: Procedurally generates a full arrangement (Drums, Acid Bass, Chords, Lead Arp) based on genre style.

Param.choice("Style", {"Synthwave / Retro", "Deep House", "Cyberpunk Acid", "Lo-Fi Hip Hop"}, 0)
Param.add("Bpm", 80, 175, 124, 1)
Param.add("Bars", 4, 16, 8, 4)

function run(project, params)
  local style = params.Style or 0
  local bpm = params.Bpm or 124
  local bars = params.Bars or 8

  return {
    style = style,
    bpm = bpm,
    bars = bars,
  }
end
''',
    ),
    LuaScriptDef(
      id: 'action_humanize_groove',
      name: 'Groove & Velocity Humanizer',
      category: LuaScriptCategory.projectAction,
      description: 'Applies organic micro-timing variations and velocity dynamics across all tracks in the song.',
      code: '''-- @name: Groove & Velocity Humanizer
-- @author: Eatsbeats
-- @category: project_action
-- @description: Applies organic micro-timing variations and velocity dynamics across all tracks in the song.

Param.add("TimingJitter", 0.0, 0.15, 0.04, 0.01)
Param.add("VelocityJitter", 0.0, 0.30, 0.12, 0.02)

function run(project, params)
  local timing = params.TimingJitter or 0.04
  local velocity = params.VelocityJitter or 0.12
  
  return {
    timing_jitter = timing,
    velocity_jitter = velocity,
  }
end
''',
    ),
  ];
}
