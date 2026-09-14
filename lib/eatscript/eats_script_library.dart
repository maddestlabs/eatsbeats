import 'gm_standard_drum_kit_preset.dart';
import 'modular_drumpad_kit_preset.dart';
import 'pipe_family_presets.dart';
import 'brass_reed_family_presets.dart';
import 'eat_builtin_presets.g.dart';
import 'eat_script_engine.dart';
import 'eat_transpiler.dart';

// Backwards-compatibility aliases for LuaScript definitions & Eatscript branding
typedef LuaPreset = EatScriptDef;
typedef LuaPresetCategory = EatScriptCategory;
typedef LuaPresetLibrary = EatScriptLibrary;
typedef LuaScriptDef = EatScriptDef;
typedef LuaScriptCategory = EatScriptCategory;
typedef LuaScriptLibrary = EatScriptLibrary;
typedef EatPreset = EatScriptDef;

enum EatScriptCategory {
  instrument,
  audioFx,
  midiFx,
  midiSeq,
  noteSplitter,
  projectAction,
  utility,
  macro;

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
      case LuaScriptCategory.utility:
      case LuaScriptCategory.macro:
        return 'MACRO';
    }
  }

  static LuaScriptCategory parse(String categoryStr) {
    final clean = categoryStr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (clean.contains('macro') || clean.contains('project') || clean.contains('action') || clean.contains('songgen') || clean.contains('generator') || clean.contains('transpos')) {
      return LuaScriptCategory.macro;
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
    if (clean.contains('util')) return LuaScriptCategory.macro;
    return LuaScriptCategory.instrument;
  }
}

class EatScriptDef {
  final String id;
  final String name;
  final EatScriptCategory category;
  final String description;
  final String code;
  final List<String> tags;

  const EatScriptDef({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.code,
    this.tags = const [],
  });

  bool get isInstrument => category == LuaScriptCategory.instrument;
  bool get isAudioFx => category == LuaScriptCategory.audioFx;
  bool get isMidiFx => category == LuaScriptCategory.midiFx;
  bool get isMidiSeq => category == LuaScriptCategory.midiSeq;
  bool get isNoteSplitter => category == LuaScriptCategory.noteSplitter;
  bool get isProjectAction => category == LuaScriptCategory.projectAction || category == LuaScriptCategory.macro;
  bool get isUtility => category == LuaScriptCategory.utility || category == LuaScriptCategory.macro;
  bool get isMacro => category == LuaScriptCategory.macro || category == LuaScriptCategory.projectAction || category == LuaScriptCategory.utility;

  /// Returns the script formatted as Eatscript, transpiling legacy Lua on demand.
  String get eatCode {
    if (EatScriptEngine.isEatScript(code)) return code;
    return EatTranspiler.transpileLuaPreset(code);
  }

  List<String> get effectiveTags {
    if (tags.isNotEmpty) return tags;
    return inferredMixTags;
  }

  String get primaryTag {
    if (tags.isNotEmpty) return tags.first;
    final inferred = inferredMixTags;
    if (inferred.isNotEmpty) return inferred.first;
    return isInstrument ? 'synth' : category.name;
  }

  List<String> get inferredMixTags {
    final lowerName = name.toLowerCase();
    final lowerId = id.toLowerCase();
    final List<String> list = [];

    if (lowerName.contains('kick') || lowerId.contains('kick')) {
      list.addAll(['kick', 'drums', 'sub_anchor', 'transient_punch', 'mono_center', 'sub_preserve_30hz']);
    } else if (lowerName.contains('snare') || lowerId.contains('snare')) {
      list.addAll(['snare', 'drums', 'mid_dominant', 'punchy_attack', 'hpf_safe_80hz', 'mud_cut_300hz']);
    } else if (lowerName.contains('clap') || lowerId.contains('clap')) {
      list.addAll(['clap', 'drums', 'high_presence', 'stereo_wide', 'hpf_safe_120hz']);
    } else if (lowerName.contains('hihat') || lowerName.contains('hi-hat') || lowerName.contains('hat') || lowerName.contains('cymbal') || lowerId.contains('hihat')) {
      list.addAll(['hihat', 'cymbals', 'drums', 'air_sparkle', 'hpf_safe_200hz']);
    } else if (lowerName.contains('tom') || lowerName.contains('cowbell') || lowerName.contains('rimshot') || lowerName.contains('perc') || lowerId.contains('tom') || lowerId.contains('cowbell') || lowerId.contains('rimshot')) {
      list.addAll(['percussion', 'drums', 'dynamic_expressive', 'hpf_safe_100hz']);
    } else if (lowerName.contains('303') || lowerName.contains('sub') || lowerName.contains('808') || lowerName.contains('moog') || lowerName.contains('synth bass') || lowerId.contains('moog_synth_bass')) {
      list.addAll(['synth_bass', 'bass', 'sub_anchor', 'mono_center', 'sub_preserve_30hz']);
    } else if (lowerName.contains('fretless') || lowerName.contains('upright') || lowerName.contains('double bass') || lowerName.contains('acoustic bass') || lowerId.contains('acoustic_bass') || lowerId.contains('fretless_bass') || lowerId.contains('upright_bass')) {
      list.addAll(['acoustic_bass', 'bass', 'low_warmth', 'dynamic_expressive', 'mono_center']);
    } else if (lowerName.contains('bass') || lowerId.contains('bass')) {
      list.addAll(['bass', 'sub_anchor', 'mono_center']);
    } else if (lowerName.contains('grand') || lowerName.contains('upright piano') || lowerName.contains('felt') || lowerName.contains('honky') || lowerId.contains('concert_grand') || lowerId.contains('felt_upright')) {
      list.addAll(['acoustic_piano', 'piano', 'keys', 'midrange', 'stereo_wide', 'dynamic_expressive', 'hpf_safe_80hz']);
    } else if (lowerName.contains('rhodes') || lowerName.contains('dx7') || lowerName.contains('wurlitzer') || lowerName.contains('epiano') || lowerName.contains('e-piano') || lowerId.contains('rhodes') || lowerId.contains('dx7')) {
      list.addAll(['electric_piano', 'keys', 'low_mid_warmth', 'stereo_wide', 'hpf_safe_100hz']);
    } else if (lowerName.contains('clavinet') || lowerName.contains('harpsichord') || lowerName.contains('cembalo') || lowerId.contains('clavinet') || lowerId.contains('harpsichord')) {
      list.addAll(['keys', 'percussive_keys', 'high_presence', 'hpf_safe_120hz']);
    } else if (lowerName.contains('glockenspiel') || lowerName.contains('music box') || lowerName.contains('xylophone') || lowerName.contains('vibraphone') || lowerName.contains('metallophone') || lowerName.contains('toy piano') || lowerName.contains('tinkle bell') || lowerName.contains('woodblock') || lowerName.contains('agogo') || lowerName.contains('cowbell') || lowerName.contains('steel drum') || lowerName.contains('steelpan') || lowerName.contains('taiko') || lowerName.contains('surdo') || lowerName.contains('melodic tom') || lowerName.contains('synth drum') || lowerName.contains('simmons') || lowerName.contains('reverse cymbal') || lowerId.contains('glockenspiel') || lowerId.contains('music_box') || lowerId.contains('xylophone') || lowerId.contains('vibraphone') || lowerId.contains('toy_piano') || lowerId.contains('tinkle_bell') || lowerId.contains('woodblock') || lowerId.contains('agogo') || lowerId.contains('steel_drums') || lowerId.contains('taiko') || lowerId.contains('melodic_tom') || lowerId.contains('synth_drum') || lowerId.contains('reverse_cymbal')) {
      list.addAll(['tuned_percussion', 'mallets', 'bells', 'percussive_keys', 'high_presence', 'air_sparkle', 'hpf_safe_120hz']);
    } else if (lowerName.contains('acoustic guitar') || lowerName.contains('spanish') || lowerName.contains('flamenco') || lowerName.contains('steel guitar') || lowerName.contains('12-string') || lowerName.contains('dobro') || lowerName.contains('harp guitar') || lowerName.contains('dub guitar') || lowerId.contains('guitar') || lowerId.contains('dobro')) {
      list.addAll(['acoustic_guitar', 'guitar', 'plucked_strings', 'mid_dominant', 'dynamic_expressive', 'hpf_safe_100hz']);
    } else if (lowerName.contains('ukulele') || lowerName.contains('lute') || lowerName.contains('banjo') || lowerName.contains('mandolin') || lowerId.contains('ukulele') || lowerId.contains('lute') || lowerId.contains('banjo') || lowerId.contains('mandolin')) {
      list.addAll(['folk_strings', 'plucked_strings', 'high_presence', 'hpf_safe_150hz']);
    } else if (lowerName.contains('guitar') || lowerName.contains('gtr') || lowerName.contains('strum')) {
      list.addAll(['guitar', 'mid_dominant', 'dynamic_expressive', 'hpf_safe_100hz']);
    } else if (lowerName.contains('violin') || lowerName.contains('viola') || lowerId.contains('solo_violin') || lowerId.contains('solo_viola')) {
      list.addAll(['solo_strings', 'violin', 'lead', 'high_presence', 'dynamic_expressive', 'hpf_safe_150hz']);
    } else if (lowerName.contains('cello') || lowerName.contains('string ensemble') || lowerName.contains('strings') || lowerName.contains('symphonic') || lowerId.contains('solo_cello') || lowerId.contains('string_ensemble')) {
      list.addAll(['orchestral_strings', 'strings', 'pad', 'low_mid_warmth', 'stereo_wide', 'hpf_safe_80hz']);
    } else if (lowerName.contains('vocal') || lowerName.contains('vox') || lowerName.contains('voice') || lowerName.contains('speech') || lowerName.contains('tts') || lowerId.contains('tts_voice_synth')) {
      list.addAll(['vocal_synth', 'vocal', 'speech', 'lead', 'mid_dominant', 'intimate_center', 'hpf_safe_120hz', 'mud_cut_300hz']);
    } else if (lowerName.contains('volts') || lowerName.contains('furnace') || lowerName.contains('lead') || lowerId.contains('eats_volts') || lowerId.contains('eats_furnace')) {
      list.addAll(['synth_lead', 'lead', 'presence_bite', 'hpf_safe_100hz']);
    } else if (lowerName.contains('rain') || lowerName.contains('wind') || lowerName.contains('water') || lowerName.contains('fire') || lowerName.contains('pad') || lowerName.contains('ambient') || lowerId.contains('eats_water') || lowerId.contains('eatsfx_rain') || lowerId.contains('eatsfx_wind') || lowerId.contains('eatsfx_fire') || lowerId.contains('eats_rain') || lowerId.contains('eats_wind') || lowerId.contains('eats_fire')) {
      list.addAll(['environmental', 'ambient', 'foley', 'sound_effects', 'stereo_wide', 'hpf_safe_80hz']);
    } else if (lowerId.contains('vintage_era_degrader') || lowerName.contains('vinyl')) {
      list.addAll(['audio_fx', 'vintage_character', 'tape_warmth']);
    } else {
      list.addAll([isInstrument ? 'synthesizer' : category.name]);
    }
    return list;
  }
}

class EatScriptLibrary {
  static final List<LuaScriptDef> _customScripts = [];

  static List<LuaScriptDef> get scripts => [
        GmStandardDrumKitPreset.preset,
        ModularDrumpadKitPreset.preset,
        ...EatBuiltinPresets.presets,
        ...PipeFamilyPresets.all,
        ...BrassReedFamilyPresets.all,
        ..._customScripts,
      ];
  static List<LuaScriptDef> get presets => scripts; // Compatibility alias

  static List<LuaScriptDef> getScriptsByCategory(LuaScriptCategory category) {
    if (category == LuaScriptCategory.macro) {
      return scripts.where((p) => p.isMacro).toList();
    }
    return scripts.where((p) => p.category == category).toList();
  }

  static List<LuaScriptDef> getMacros() => scripts.where((p) => p.isMacro).toList();

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
    final List<String> tags = [];

    final lines = luaCode.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      final clean = trimmed.startsWith('--') ? trimmed.substring(2).trim() : (trimmed.startsWith('#') ? trimmed.substring(1).trim() : trimmed);
      if (clean.startsWith('@name:')) {
        name = clean.substring(6).trim();
      } else if (clean.startsWith('@category:')) {
        category = LuaScriptCategory.parse(clean.substring(10).trim());
      } else if (clean.startsWith('@description:')) {
        description = clean.substring(13).trim();
      } else if (clean.startsWith('@tags:') || clean.startsWith('@tag:')) {
        final prefixLen = clean.startsWith('@tags:') ? 6 : 5;
        final rawTags = clean.substring(prefixLen).split(',');
        for (final t in rawTags) {
          final ct = t.trim().toLowerCase();
          if (ct.isNotEmpty && !tags.contains(ct)) tags.add(ct);
        }
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
      tags: tags,
    );

    registerCustomScript(script);
    return script;
  }

  static LuaScriptDef? getScriptById(String id) {
    try {
      final builtin = EatBuiltinPresets.getById(id);
      if (builtin != null) return builtin;
      for (final s in scripts) {
        if (s.id == id) return s;
      }
      return scripts.firstWhere((p) =>
          (id == 'voltaic_plasma_synth' && p.id == 'eats_volts') ||
          (id == 'eats_volts' && p.id == 'voltaic_plasma_synth') ||
          (id == 'pyrophone_synth' && p.id == 'eats_furnace') ||
          (id == 'eats_rain' && p.id == 'eatsfx_rain') ||
          (id == 'eatsfx_rain' && p.id == 'eats_rain') ||
          (id == 'eats_wind' && p.id == 'eatsfx_wind') ||
          (id == 'eatsfx_wind' && p.id == 'eats_wind') ||
          (id == 'eats_fire' && p.id == 'eatsfx_fire') ||
          (id == 'eatsfx_fire' && p.id == 'eats_fire') ||
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
      final clean = trimmed.startsWith('--') ? trimmed.substring(2).trim() : (trimmed.startsWith('#') ? trimmed.substring(1).trim() : trimmed);
      if (clean.startsWith('@id:')) {
        explicitId = clean.substring(4).trim();
      } else if (clean.startsWith('@name:')) {
        explicitName = clean.substring(6).trim();
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
    if (luaCode.contains('modular_drumpad_kit') ||
        luaCode.contains('ModularDrumpadKit') ||
        luaCode.contains('Modular Drum Machine')) {
      return getPresetById('modular_drumpad_kit');
    }
    if (luaCode.contains('gm_standard_drum_kit') ||
        luaCode.contains('GmStandardDrumKit') ||
        luaCode.contains('GM Standard Drum Kit')) {
      return getPresetById('gm_standard_drum_kit');
    }
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
    if (luaCode.contains('StereoDelay') || luaCode.contains('stereo_delay') || luaCode.contains('Stereo Delay')) {
      return getPresetById('stereo_delay');
    }
    if (luaCode.contains('FilterFX') || luaCode.contains('lowpass_filter') || luaCode.contains('Lowpass Filter')) {
      return getPresetById('lowpass_filter');
    }
    if (luaCode.contains('VintageDegrader') || luaCode.contains('vintage_era_degrader') || luaCode.contains('Vintage Era Degrader') || luaCode.contains('Eats Vinyl') || luaCode.contains('eats_vinyl') || luaCode.contains('Era Bandwidth Morph')) {
      return getPresetById('vintage_era_degrader');
    }
    if (luaCode.contains('PolyLeadSynth')) {
      return getPresetById('poly_lead');
    }
    if (luaCode.contains('RhodesEPiano') || luaCode.contains('rhodes_epiano') || luaCode.contains('Rhodes Mark I') || luaCode.contains('Stage 73')) {
      return getPresetById('rhodes_epiano');
    }
    if (luaCode.contains('ReggaeGuitar') || luaCode.contains('reggae_guitar') || luaCode.contains('Reggae Skank') || luaCode.contains('Dub Guitar') || luaCode.contains('Dub Chop') || luaCode.contains('SkankGuitar') || luaCode.contains('DubGuitar')) {
      return getPresetById('reggae_guitar');
    }
    if (luaCode.contains('HawaiianUkulele') || luaCode.contains('hawaiian_ukulele') || luaCode.contains('Ukulele') || (luaCode.contains('PluckSnap') && luaCode.contains('StrumSpread'))) {
      return getPresetById('hawaiian_ukulele');
    }
    if (luaCode.contains('SpanishGuitar') || luaCode.contains('spanish_guitar') || luaCode.contains('ClassicalGuitar') || luaCode.contains('classical_guitar') || luaCode.contains('Spanish Guitar') || luaCode.contains('Classical Guitar') || (luaCode.contains('FleshNail') && luaCode.contains('AirResonance'))) {
      return getPresetById('spanish_guitar');
    }
    if (luaCode.contains('RenaissanceLute') || luaCode.contains('renaissance_lute') || luaCode.contains('BaroqueLute') || luaCode.contains('baroque_lute') || luaCode.contains('Lute') || luaCode.contains('Vihuela') || (luaCode.contains('CourseDetune') && luaCode.contains('BowlWarmth'))) {
      return getPresetById('renaissance_lute');
    }
    if (luaCode.contains('BaroqueGuitar') || luaCode.contains('baroque_guitar') || luaCode.contains('5-Course Guitar') || luaCode.contains('Chitarra Spagnola') || (luaCode.contains('RoseBite') && luaCode.contains('RasgueadoSpeed'))) {
      return getPresetById('baroque_guitar');
    }
    if (luaCode.contains('FlamencoGuitar') || luaCode.contains('flamenco_guitar') || luaCode.contains('Guitarra Flamenca') || luaCode.contains('Flamenco') || (luaCode.contains('GolpeTap') && luaCode.contains('SnapDamp'))) {
      return getPresetById('flamenco_guitar');
    }
    if (luaCode.contains('SteelAcousticGuitar') || luaCode.contains('acoustic_steel_guitar') || luaCode.contains('Steel Acoustic') || (luaCode.contains('BodyProfile') && luaCode.contains('BronzeSparkle'))) {
      return getPresetById('acoustic_steel_guitar');
    }
    if (luaCode.contains('TwelveStringGuitar') || luaCode.contains('twelve_string_guitar') || luaCode.contains('12-String') || (luaCode.contains('ChorusDetune') && luaCode.contains('OctavePairing'))) {
      return getPresetById('twelve_string_guitar');
    }
    if (luaCode.contains('DobroResonator') || luaCode.contains('dobro_resonator') || luaCode.contains('Dobro') || luaCode.contains('Resonator') || (luaCode.contains('ConeType') && luaCode.contains('MetalBark'))) {
      return getPresetById('dobro_resonator');
    }
    if (luaCode.contains('PedalSteelGuitar') || luaCode.contains('pedal_steel_guitar') || luaCode.contains('Pedal Steel') || (luaCode.contains('VolumeSwell') && luaCode.contains('BarVibrato'))) {
      return getPresetById('pedal_steel_guitar');
    }
    if (luaCode.contains('HarpGuitar') || luaCode.contains('harp_guitar') || luaCode.contains('Harp Guitar') || (luaCode.contains('SubDroneGain') && luaCode.contains('PickStyle'))) {
      return getPresetById('harp_guitar');
    }
    if (luaCode.contains('BluegrassBanjo') || luaCode.contains('bluegrass_banjo') || luaCode.contains('Banjo') || (luaCode.contains('HeadTension') && luaCode.contains('TwangSnap'))) {
      return getPresetById('bluegrass_banjo');
    }
    if (luaCode.contains('FolkMandolin') || luaCode.contains('folk_mandolin') || luaCode.contains('Mandolin') || (luaCode.contains('TremoloSpeed') && luaCode.contains('MandolinBite'))) {
      return getPresetById('folk_mandolin');
    }
    if (luaCode.contains('SoloViolin') || luaCode.contains('solo_violin') || luaCode.contains('Virtuoso Solo Violin') || (luaCode.contains('BowPressure') && luaCode.contains('BridgeBite'))) {
      return getPresetById('solo_violin');
    }
    if (luaCode.contains('SoloViola') || luaCode.contains('solo_viola') || luaCode.contains('Warm Solo Viola') || (luaCode.contains('BowPressure') && luaCode.contains('ViolaWarmth'))) {
      return getPresetById('solo_viola');
    }
    if (luaCode.contains('SoloCello') || luaCode.contains('solo_cello') || luaCode.contains('Deep Solo Cello') || (luaCode.contains('BowPressure') && luaCode.contains('ChestResonance'))) {
      return getPresetById('solo_cello');
    }
    if (luaCode.contains('DoubleBass') || luaCode.contains('double_bass') || luaCode.contains('Orchestral Double Bass') || luaCode.contains('Contrabass') || (luaCode.contains('BowPressure') && luaCode.contains('SubPunch'))) {
      return getPresetById('double_bass');
    }
    if (luaCode.contains('StringEnsemble') || luaCode.contains('string_ensemble') || luaCode.contains('Symphonic String Ensemble') || luaCode.contains('Orchestral Strings') || (luaCode.contains('EnsembleChorus') && luaCode.contains('AirSheen'))) {
      return getPresetById('string_ensemble');
    }

    if (luaCode.contains('EatsVolts') || luaCode.contains('eats_volts') || luaCode.contains('Eats Volts') || luaCode.contains('VoltaicPlasmaSynth') || luaCode.contains('voltaic_plasma_synth') || luaCode.contains('VOLTAIC') || luaCode.contains('Plasma Arc') || luaCode.contains('Singing Arc') || (luaCode.contains('SparkGap') && luaCode.contains('CrackleRate'))) {
      return getPresetById('eats_volts');
    }
    if (luaCode.contains('EatsFurnace') || luaCode.contains('eats_furnace') || luaCode.contains('Eats Furnace') || luaCode.contains('PyrophoneSynth') || luaCode.contains('pyrophone_synth') || luaCode.contains('PYROPHONE') || luaCode.contains('Thermoacoustic') || luaCode.contains('Singing Flame') || luaCode.contains('Rijke Tube') || (luaCode.contains('FuelPressure') && luaCode.contains('FlameCusp'))) {
      return getPresetById('eats_furnace');
    }
    if (luaCode.contains('EatsFXRain') || luaCode.contains('eatsfx_rain') || luaCode.contains('EatsFX Rain') || luaCode.contains('EatsRain') || luaCode.contains('eats_rain') || luaCode.contains('Eats Rain') || luaCode.contains('RainIntensity') || (luaCode.contains('RainHiss') && luaCode.contains('DropletForce'))) {
      return getPresetById('eatsfx_rain');
    }
    if (luaCode.contains('EatsFXWind') || luaCode.contains('eatsfx_wind') || luaCode.contains('EatsFX Wind') || luaCode.contains('EatsWind') || luaCode.contains('eats_wind') || luaCode.contains('Eats Wind') || luaCode.contains('AeolianPitch') || (luaCode.contains('GustSpeed') && luaCode.contains('HowlDepth'))) {
      return getPresetById('eatsfx_wind');
    }
    if (luaCode.contains('EatsFXFire') || luaCode.contains('eatsfx_fire') || luaCode.contains('EatsFX Fire') || luaCode.contains('EatsFire') || luaCode.contains('eats_fire') || luaCode.contains('Eats Fire') || luaCode.contains('SapCrackle') || (luaCode.contains('FlameRoar') && luaCode.contains('EmberSizzle'))) {
      return getPresetById('eatsfx_fire');
    }
    if (luaCode.contains('EatsWater') || luaCode.contains('eats_water') || luaCode.contains('Eats Water') || luaCode.contains('Hydraulophone') || (luaCode.contains('WaterFlow') && luaCode.contains('BubblePinch'))) {
      return getPresetById('eats_water');
    }
    if (luaCode.contains('DX7EPiano') || luaCode.contains('dx7_epiano') || luaCode.contains('DX7') || luaCode.contains('FullTines')) {
      return getPresetById('dx7_epiano');
    }
    if (luaCode.contains('ClavinetD6') || luaCode.contains('clavinet_d6') || luaCode.contains('Clavinet') || luaCode.contains('Hohner Clav')) {
      return getPresetById('clavinet_d6');
    }
    if (luaCode.contains('TTSVoiceSynth') || luaCode.contains('tts_voice_synth') || luaCode.contains('TTS Voice Synth') || luaCode.contains('Vocal Formant') || luaCode.contains('Formant Synth')) {
      return getPresetById('tts_voice_synth');
    }
    if (luaCode.contains('Harpsichord') || luaCode.contains('harpsichord_cembalo') || luaCode.contains('Cembalo') || luaCode.contains('Virginal')) {
      return getPresetById('harpsichord_cembalo');
    }
    if (luaCode.contains('ConcertGrandPiano') || luaCode.contains('concert_grand_piano') || luaCode.contains('Concert Grand') || luaCode.contains('Grand Piano') || (luaCode.contains('HammerHardness') && luaCode.contains('Stiffness')) || (luaCode.contains('HammerHardness') && luaCode.contains('Brightness')) || (luaCode.contains('HammerHardness') && luaCode.contains('Soundboard') && luaCode.contains('PedalReso'))) {
      return getPresetById('concert_grand_piano');
    }
    if (luaCode.contains('FeltUprightPiano') || luaCode.contains('felt_upright_piano') || luaCode.contains('Felt Piano') || luaCode.contains('Studio Upright') || (luaCode.contains('FeltThickness') && luaCode.contains('MechanicalThud'))) {
      return getPresetById('felt_upright_piano');
    }
    if (luaCode.contains('HonkyTonkPiano') || luaCode.contains('honky_tonk_piano') || luaCode.contains('Honky Tonk') || luaCode.contains('Tack Piano') || (luaCode.contains('TackBite') && luaCode.contains('ActionClack'))) {
      return getPresetById('honky_tonk_piano');
    }
    if (luaCode.contains('ToyPiano') || luaCode.contains('toy_piano') || luaCode.contains('Toy Piano') || (luaCode.contains('ClangRatio') && luaCode.contains('TineDecay'))) {
      return getPresetById('toy_piano');
    }
    if (luaCode.contains('Glockenspiel') || luaCode.contains('glockenspiel') || (luaCode.contains('BarDecay') && luaCode.contains('BellShimmer')) || (luaCode.contains('BellShimmer') && luaCode.contains('MalletHardness'))) {
      return getPresetById('glockenspiel');
    }
    if (luaCode.contains('MusicBox') || luaCode.contains('music_box') || luaCode.contains('Music Box') || (luaCode.contains('PinScrape') && luaCode.contains('BoxWarmth')) || (luaCode.contains('PinScrape') && luaCode.contains('HighTineRing'))) {
      return getPresetById('music_box');
    }
    if (luaCode.contains('Xylophone') || luaCode.contains('xylophone') || (luaCode.contains('WoodDecay') && luaCode.contains('TripleOctave')) || (luaCode.contains('WoodDecay') && luaCode.contains('ResonatorPop'))) {
      return getPresetById('xylophone');
    }
    if (luaCode.contains('Vibraphone') || luaCode.contains('vibraphone') || (luaCode.contains('MotorSpeed') && luaCode.contains('TremoloDepth')) || (luaCode.contains('DoubleOctave') && luaCode.contains('TremoloDepth'))) {
      return getPresetById('vibraphone');
    }
    if (luaCode.contains('TinkleBell') || luaCode.contains('tinkle_bell') || luaCode.contains('Tinkle Bell') || luaCode.contains('WindChime') || (luaCode.contains('ChimeDecay') && luaCode.contains('BreezeFlutter'))) {
      return getPresetById('tinkle_bell');
    }
    if (luaCode.contains('Woodblock') || luaCode.contains('woodblock') || luaCode.contains('Wood Block') || luaCode.contains('TempleBlock') || (luaCode.contains('WoodDecay') && luaCode.contains('CavityPop'))) {
      return getPresetById('woodblock');
    }
    if (luaCode.contains('AgogoBell') || luaCode.contains('agogo_bell') || luaCode.contains('Agogo Bell') || luaCode.contains('Agogo') || (luaCode.contains('BellDecay') && luaCode.contains('ClangRatio'))) {
      return getPresetById('agogo_bell');
    }
    if (luaCode.contains('SteelDrums') || luaCode.contains('steel_drums') || luaCode.contains('Steel Drums') || luaCode.contains('SteelPan') || luaCode.contains('steelpan') || (luaCode.contains('PanDecay') && luaCode.contains('OctaveHarmonic'))) {
      return getPresetById('steel_drums');
    }
    if (luaCode.contains('TaikoDrum') || luaCode.contains('taiko_drum') || luaCode.contains('Taiko Drum') || luaCode.contains('Taiko') || luaCode.contains('Surdo') || (luaCode.contains('DrumDecay') && luaCode.contains('PitchSag'))) {
      return getPresetById('taiko_drum');
    }
    if (luaCode.contains('MelodicTom') || luaCode.contains('melodic_tom') || luaCode.contains('Melodic Tom') || (luaCode.contains('TomDecay') && luaCode.contains('HeadCoupling'))) {
      return getPresetById('melodic_tom');
    }
    if (luaCode.contains('SimmonsSynthDrum') || luaCode.contains('simmons_synth_drum') || luaCode.contains('Simmons SDS') || luaCode.contains('SynthDrum') || luaCode.contains('synth_drum') || (luaCode.contains('PitchDrop') && luaCode.contains('SweepTime'))) {
      return getPresetById('synth_drum');
    }
    if (luaCode.contains('ReverseCymbal') || luaCode.contains('reverse_cymbal') || luaCode.contains('Reverse Cymbal') || (luaCode.contains('SwellDuration') && luaCode.contains('CrescendoCurve'))) {
      return getPresetById('reverse_cymbal');
    }
    if (luaCode.contains('ConcertPiccolo') || luaCode.contains('concert_piccolo') || luaCode.contains('Piccolo')) {
      return getPresetById('concert_piccolo');
    }
    if (luaCode.contains('ConcertFlute') || luaCode.contains('concert_flute') || luaCode.contains('Flute')) {
      return getPresetById('concert_flute');
    }
    if (luaCode.contains('WoodenRecorder') || luaCode.contains('wooden_recorder') || luaCode.contains('Recorder') || luaCode.contains('Blockflöte')) {
      return getPresetById('wooden_recorder');
    }
    if (luaCode.contains('PanFlute') || luaCode.contains('pan_flute') || luaCode.contains('Pan Flute') || luaCode.contains('Zampoña') || luaCode.contains('Siku')) {
      return getPresetById('pan_flute');
    }
    if (luaCode.contains('BlownBottle') || luaCode.contains('blown_bottle') || luaCode.contains('Blown Bottle')) {
      return getPresetById('blown_bottle');
    }
    if (luaCode.contains('Shakuhachi') || luaCode.contains('shakuhachi_bamboo') || luaCode.contains('Muraiki')) {
      return getPresetById('shakuhachi_bamboo');
    }
    if (luaCode.contains('TinWhistle') || luaCode.contains('tin_whistle') || luaCode.contains('Pennywhistle') || luaCode.contains('Tin Whistle')) {
      return getPresetById('tin_whistle');
    }
    if (luaCode.contains('SweetOcarina') || luaCode.contains('sweet_ocarina') || luaCode.contains('Ocarina')) {
      return getPresetById('sweet_ocarina');
    }
    if (luaCode.contains('OrchestralTrumpet') || luaCode.contains('orchestral_trumpet') || luaCode.contains('Trumpet')) {
      return getPresetById('orchestral_trumpet');
    }
    if (luaCode.contains('TenorTrombone') || luaCode.contains('tenor_trombone') || luaCode.contains('Trombone')) {
      return getPresetById('tenor_trombone');
    }
    if (luaCode.contains('Tuba') || luaCode.contains('tuba_brass')) {
      return getPresetById('tuba_brass');
    }
    if (luaCode.contains('MutedTrumpet') || luaCode.contains('muted_trumpet')) {
      return getPresetById('muted_trumpet');
    }
    if (luaCode.contains('FrenchHorn') || luaCode.contains('french_horn') || luaCode.contains('French Horn')) {
      return getPresetById('french_horn');
    }
    if (luaCode.contains('BrassSection') || luaCode.contains('brass_section') || luaCode.contains('Brass Section')) {
      return getPresetById('brass_section');
    }
    if (luaCode.contains('SopranoSax') || luaCode.contains('soprano_sax') || luaCode.contains('Soprano Sax')) {
      return getPresetById('soprano_sax');
    }
    if (luaCode.contains('AltoSax') || luaCode.contains('alto_sax') || luaCode.contains('Alto Sax')) {
      return getPresetById('alto_sax');
    }
    if (luaCode.contains('TenorSax') || luaCode.contains('tenor_sax') || luaCode.contains('Tenor Sax')) {
      return getPresetById('tenor_sax');
    }
    if (luaCode.contains('BaritoneSax') || luaCode.contains('baritone_sax') || luaCode.contains('Baritone Sax')) {
      return getPresetById('baritone_sax');
    }
    if (luaCode.contains('Oboe') || luaCode.contains('oboe_woodwind')) {
      return getPresetById('oboe_woodwind');
    }
    if (luaCode.contains('EnglishHorn') || luaCode.contains('english_horn') || luaCode.contains('English Horn')) {
      return getPresetById('english_horn');
    }
    if (luaCode.contains('Bassoon') || luaCode.contains('bassoon_woodwind')) {
      return getPresetById('bassoon_woodwind');
    }
    if (luaCode.contains('Clarinet') || luaCode.contains('clarinet_woodwind')) {
      return getPresetById('clarinet_woodwind');
    }
    if (luaCode.contains('Sitar') || luaCode.contains('sitar_jawari') || luaCode.contains('Jawari')) {
      return getPresetById('sitar_jawari');
    }

    return null;
  }

  static bool isUpgradeAvailable(String currentCode, {String? trackName}) {
    final preset = findMatchingPreset(currentCode, fallbackName: trackName);
    if (preset == null) return false;
    final cur = currentCode.trim();
    // If the track is already running the latest Eatscript factory code, no upgrade is needed
    if (cur == preset.eatCode.trim()) return false;
    return true;
  }
}
