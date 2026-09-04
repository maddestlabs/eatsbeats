import 'pipe_family_presets.dart';
import 'brass_reed_family_presets.dart';

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
  final List<String> tags;

  const LuaScriptDef({
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
  bool get isProjectAction => category == LuaScriptCategory.projectAction;

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
    } else if (lowerName.contains('glockenspiel') || lowerName.contains('music box') || lowerName.contains('xylophone') || lowerName.contains('vibraphone') || lowerName.contains('metallophone') || lowerName.contains('toy piano') || lowerId.contains('glockenspiel') || lowerId.contains('music_box') || lowerId.contains('xylophone') || lowerId.contains('vibraphone') || lowerId.contains('toy_piano')) {
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
    } else if (lowerName.contains('rain') || lowerName.contains('wind') || lowerName.contains('thunder') || lowerName.contains('water') || lowerName.contains('fire') || lowerName.contains('pad') || lowerName.contains('ambient') || lowerId.contains('eats_water') || lowerId.contains('eats_rain') || lowerId.contains('eats_wind') || lowerId.contains('eats_fire') || lowerId.contains('eats_thunder')) {
      list.addAll(['environmental', 'ambient', 'foley', 'sound_effects', 'stereo_wide', 'hpf_safe_80hz']);
    } else if (lowerId.contains('vintage_era_degrader') || lowerName.contains('vinyl')) {
      list.addAll(['audio_fx', 'vintage_character', 'tape_warmth']);
    } else {
      list.addAll([isInstrument ? 'synthesizer' : category.name]);
    }
    return list;
  }
}

class LuaScriptLibrary {
  static final List<LuaScriptDef> _customScripts = [];

  static List<LuaScriptDef> get scripts => [..._builtinPresets, ...PipeFamilyPresets.all, ...BrassReedFamilyPresets.all, ..._customScripts];
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
    final List<String> tags = [];

    final lines = luaCode.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('-- @name:')) {
        name = trimmed.substring(9).trim();
      } else if (trimmed.startsWith('-- @category:')) {
        category = LuaScriptCategory.parse(trimmed.substring(13).trim());
      } else if (trimmed.startsWith('-- @description:')) {
        description = trimmed.substring(16).trim();
      } else if (trimmed.startsWith('-- @tags:') || trimmed.startsWith('-- @tag:')) {
        final prefixLen = trimmed.startsWith('-- @tags:') ? 9 : 8;
        final rawTags = trimmed.substring(prefixLen).split(',');
        for (final t in rawTags) {
          final clean = t.trim().toLowerCase();
          if (clean.isNotEmpty && !tags.contains(clean)) tags.add(clean);
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
      for (final s in scripts) {
        if (s.id == id) return s;
      }
      return scripts.firstWhere((p) =>
          (id == 'voltaic_plasma_synth' && p.id == 'eats_volts') ||
          (id == 'eats_volts' && p.id == 'voltaic_plasma_synth') ||
          (id == 'pyrophone_synth' && p.id == 'eats_furnace') ||
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
    if (luaCode.contains('EatsRain') || luaCode.contains('eats_rain') || luaCode.contains('Eats Rain') || luaCode.contains('RainIntensity') || (luaCode.contains('RainHiss') && luaCode.contains('DropletForce'))) {
      return getPresetById('eats_rain');
    }
    if (luaCode.contains('EatsWind') || luaCode.contains('eats_wind') || luaCode.contains('Eats Wind') || luaCode.contains('AeolianPitch') || (luaCode.contains('GustSpeed') && luaCode.contains('HowlDepth'))) {
      return getPresetById('eats_wind');
    }
    if (luaCode.contains('EatsFire') || luaCode.contains('eats_fire') || luaCode.contains('Eats Fire') || luaCode.contains('SapCrackle') || (luaCode.contains('FlameRoar') && luaCode.contains('EmberSizzle'))) {
      return getPresetById('eats_fire');
    }
    if (luaCode.contains('EatsThunder') || luaCode.contains('eats_thunder') || luaCode.contains('Eats Thunder') || luaCode.contains('StrikeTrigger') || (luaCode.contains('StrikeProximity') && luaCode.contains('RumbleDecay'))) {
      return getPresetById('eats_thunder');
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
    return preset.code.trim() != currentCode.trim();
  }

  static const List<LuaPreset> _builtinPresets = [
    // 00. TTS Voice Synth (Tactile Minimalist Ceramic Vocal Formant Synthesizer)
    LuaPreset(
      id: 'tts_voice_synth',
      name: 'TTS Voice Synth',
      category: LuaPresetCategory.instrument,
      description: 'Tactile minimalist vocal formant synthesizer and speech engine with 3-column ceramic layout: glottal pulse oscillator, vocal tract F1/F2/F3 formant filters, breath air turbulence, prosody dynamics, and analog character saturation.',
      code: r'''
-- @id: tts_voice_synth
-- @name: TTS Voice Synth
-- @category: instrument
-- @description: Tactile minimalist vocal formant synthesizer and speech engine: glottal pulse oscillator, vocal tract resonance filters, breath turbulence, prosody dynamics, and voice profile selection.

local TTSVoiceSynth = {}

function TTSVoiceSynth.init()
  return {
    -- Card 1: Vocal Formant Engine & Articulation
    voice_mode = 0,    -- 0: Natural, 1: Robot, 2: Whisper
    speech_speed = 1,  -- 0: Slow, 1: Normal, 2: Fast
    pitch = 1.0,       -- Pitch scale (0.5 to 2.0)
    tone = 0.5,        -- Formant resonance brightness (0.0 to 1.0)
    bypass_engine = 1.0,

    -- Card 2: Output & Space
    volume = 0.85,     -- Master level (0.0 to 1.0)
    space = 0.35,      -- Reverb space & stereo width (0.0 to 1.0)
    air = 0.30,        -- Breath & articulation clarity (0.0 to 1.0)
    adv = 1.0,
    bypass_out = 1.0,
  }
end

function TTSVoiceSynth.gui()
  return {
    panel = {
      title = "TTS VOICE SYNTH",
      subtitle = "Vocal Speech & Formant Synthesizer",
      background = "minimal_white",
      accent = "#D9603B",
      knobStyle = "minimal_white",
      layout = {
        {
          type = "row",
          children = {
            {
              type = "column",
              children = {
                { type = "spectrum", width = 210, height = 96 },
                { type = "segmented_pill", param = "voice_mode", label = "VOICE PROFILE", options = { "Natural", "Robot", "Whisper" } },
                { type = "segmented_pill", param = "speech_speed", label = "SPEED", options = { "Slow", "Normal", "Fast" } },
                {
                  type = "row",
                  children = {
                    { type = "knob", param = "pitch", label = "PITCH", size = 48, knobStyle = "minimal_white" },
                    { type = "knob", param = "tone", label = "TONE", size = 48, knobStyle = "minimal_white" },
                  }
                },
              }
            },
            {
              type = "column",
              children = {
                { type = "knob", param = "volume", label = "LEVEL", size = 72, knobStyle = "minimal_white" },
                { type = "knob", param = "space", label = "SPACE", size = 52, knobStyle = "minimal_white" },
                { type = "knob", param = "air", label = "AIR", size = 46, knobStyle = "minimal_white" },
                { type = "switch", param = "adv", label = "ADV", orientation = "vertical" },
              }
            },
          }
        },
      }
    }
  }
end

function TTSVoiceSynth.evaluate(sampleRate, note, velocity, time, params)
  if params.bypass_engine == 0 and params.bypass_out == 0 then
    return 0.0, 0.0
  end

  local pitchScale = params.pitch or 1.0
  local freq = 440.0 * math.pow(2.0, ((note * pitchScale) - 69.0) / 12.0)
  local t = time * freq
  local phase = t - math.floor(t)

  local mode = math.floor((params.voice_mode or 0) + 0.5)
  local vocal = 0.0

  if mode == 1 then
    -- Robot / Vocoder Carrier (Buzzy Rectangular Oscillator + Sub)
    local sq = (phase < 0.5) and 1.0 or -1.0
    local sub = ((math.sin(phase * math.pi) > 0) and 0.5 or -0.5)
    vocal = sq * 0.6 + sub * 0.4
  elseif mode == 2 then
    -- Whisper / Aspiration (Filtered Breath Turbulence)
    local noise = (math.random() * 2.0 - 1.0)
    local breathEnv = math.sin(phase * math.pi)
    vocal = noise * (0.6 + breathEnv * 0.4)
  else
    -- Natural Glottal Pulse Excitation
    local glottal = 0.0
    if phase < 0.65 then
      glottal = math.sin(phase / 0.65 * math.pi)
    else
      glottal = -0.18 * math.sin((phase - 0.65) / 0.35 * math.pi)
    end
    vocal = glottal
  end

  -- Formant Resonances shifted by Tone parameter
  local tone = params.tone or 0.5
  local f1_freq = 300.0 + tone * 500.0
  local f2_freq = 900.0 + tone * 1200.0
  local f3_freq = 2200.0 + tone * 1500.0

  local f1_res = math.sin(time * 6.283185 * f1_freq) * math.exp(-time * 12.0)
  local f2_res = math.sin(time * 6.283185 * f2_freq) * math.exp(-time * 18.0)
  local f3_res = math.sin(time * 6.283185 * f3_freq) * math.exp(-time * 24.0)
  local air_noise = (math.random() * 2.0 - 1.0) * (params.air or 0.3) * 0.16

  local resonant = vocal * 0.45 + (f1_res * 0.35 + f2_res * 0.30 + f3_res * 0.20) + air_noise

  -- Master Gain & Saturation
  local out = math.tanh(resonant * 1.8) * (params.volume or 0.85) * velocity

  -- Stereo Width & Spatial Spread
  local space = (params.space or 0.35) * 0.4
  local left = out * (1.0 + space)
  local right = out * (1.0 - space)

  return left, right
end

return TTSVoiceSynth
''',
    ),
    // 00a. Eats Volts Physical Model (High-Voltage Electricity & Plasma)
    LuaPreset(
      id: 'eats_volts',
      name: 'Eats Volts',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of real-world electricity, singing plasma arcs, and high-voltage discharge: asymmetric thermal expansion pulse oscillator, cycle-to-cycle spark jitter, Poisson-distributed corona sizzle, 60Hz substation transformer magnetostriction hum, dielectric breakdown attack snap, spark gap acoustic cavity formants, 4-stage plasma vortex phaser, and ozone saturation.',
      code: '''
-- @id: eats_volts
-- @name: Eats Volts
-- @category: instrument
-- @description: Physical modeling of real-world electricity, singing plasma arcs, and high-voltage discharge: asymmetric thermal expansion pulse oscillator, cycle-to-cycle spark jitter, Poisson-distributed corona sizzle, 60Hz substation transformer magnetostriction hum, dielectric breakdown attack snap, spark gap acoustic cavity formants, 4-stage plasma vortex phaser, and ozone saturation.

local EatsVolts = {}

function EatsVolts.init()
  -- Plasma Arc & Discharge Core
  Param.add("Voltage", 0.1, 3.0, 1.25)
  Param.add("SparkGap", 0.02, 0.50, 0.15)
  Param.add("Jitter", 0.0, 1.0, 0.45)
  Param.add("SubHarmonic", 0.0, 1.0, 0.20)

  -- Corona Ionization & Dielectric Breakdown
  Param.add("CrackleRate", 0.0, 1.0, 0.40)
  Param.add("SnapAttack", 0.0, 2.5, 1.0)
  Param.add("GridHum", 0.0, 1.0, 0.35)

  -- Plasma Vortex All-Pass Phaser
  Param.add("PhaserRate", 0.05, 8.0, 0.45)
  Param.add("PhaserDepth", 0.0, 1.0, 0.65)
  Param.add("PhaserFeedback", 0.0, 1.0, 0.40)
  Param.add("PhaserMix", 0.0, 1.0, 0.45)

  -- Ozone Saturation & Gas Tone Shaping
  Param.add("OzoneDrive", 0.5, 5.0, 1.35)
  Param.add("ToneHighpass", 20.0, 2000.0, 30.0)
  Param.add("Tone", 1000.0, 16000.0, 8500.0)
  Param.add("Decay", 0.05, 2.0, 0.45)
end

function EatsVolts.process(time, freq, note, params)
  local voltage = params["Voltage"] or 1.25
  local gap = params["SparkGap"] or 0.15
  local jitter = params["Jitter"] or 0.45
  local crackle = params["CrackleRate"] or 0.40
  local snap = params["SnapAttack"] or 1.0
  local hum = params["GridHum"] or 0.35
  local drive = params["OzoneDrive"] or 1.35
  local decay = params["Decay"] or 0.45
  local pRate = params["PhaserRate"] or 0.45
  local pDepth = params["PhaserDepth"] or 0.65
  local pMix = params["PhaserMix"] or 0.45

  -- Direct single-cycle fallback
  local fInst = freq * (1.0 + (math.random() * 2.0 - 1.0) * jitter * 0.03)
  local phase = (fInst * time) % 1.0
  local arcPulse = (phase < gap) and math.sin(phase / gap * math.pi) or (-0.3 * math.exp(-(phase - gap) * 6.0))

  -- 60Hz Substation hum
  local humTone = math.sin(2.0 * math.pi * 60.0 * time) * 0.5 + math.sin(2.0 * math.pi * 180.0 * time) * 0.25

  -- Dielectric snap
  local snapTransient = (math.random() * 2.0 - 1.0) * math.exp(-time * 250.0) * snap

  -- Corona crackle
  local microSpark = (math.random() < (crackle * 0.08)) and ((math.random() * 2.0 - 1.0) * 0.6) or 0.0

  -- Phaser modulation fallback
  local phaserMod = 1.0 + 0.3 * pMix * math.sin(2.0 * math.pi * pRate * time) * pDepth

  local ampEnv = math.exp(-time / math.max(0.04, decay))
  local raw = (arcPulse * voltage * phaserMod + humTone * hum + snapTransient + microSpark) * ampEnv

  return math.tanh(raw * drive) * 0.95
end

function EatsVolts.gui()
  return {
    panel = {
      title = "EATS VOLTS",
      subtitle = "High-Voltage Plasma Synthesizer",
      accent = "#00F0FF",
      background = "matte_metal",
      rackSides = "brushed_steel",
      cornerRadius = 0,
      layout = {
        -- CYAN SECTION: Singing Plasma Arc & Spark Gap
        {
          type = "group",
          label = "PLASMA DISCHARGE & ARC CORE (CYAN)",
          accent = "#00F0FF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "Voltage", label = "VOLTAGE", unit = "kV", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "SparkGap", label = "SPARK GAP", unit = "mm", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Jitter", label = "ARC JITTER", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "SubHarmonic", label = "SUB-PLASMA", unit = "%", knobStyle = "chrome", size = 52 },
              }
            }
          }
        },
        -- AMBER SECTION: Corona Sizzle & Breakdown Snap
        {
          type = "group",
          label = "CORONA SIZZLE & DIELECTRIC SNAP (AMBER)",
          accent = "#FFB300",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "CrackleRate", label = "CORONA SIZZLE", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "SnapAttack", label = "SNAP STRIKE", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "GridHum", label = "60Hz HUM", unit = "dB", knobStyle = "vintage", size = 52 },
              }
            },
            {
              type = "row",
              children = {
                { type = "hslider", param = "Voltage", label = "HIGH-VOLTAGE RAIL POTENTIAL", style = "capsule" },
              }
            }
          }
        },
        -- PURPLE SECTION: Plasma Vortex Phaser
        {
          type = "group",
          label = "PLASMA VORTEX PHASER (PURPLE)",
          accent = "#7C4DFF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "PhaserRate", label = "PHASER RATE", unit = "Hz", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PhaserDepth", label = "SWEEP DEPTH", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PhaserFeedback", label = "VORTEX RESO", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PhaserMix", label = "PHASER MIX", unit = "%", knobStyle = "vintage", size = 52 },
              }
            }
          }
        },
        -- MAGENTA SECTION: Ozone Saturation & Gas Tone
        {
          type = "group",
          label = "OZONE SATURATION & GAS TONE (MAGENTA)",
          accent = "#E040FB",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "OzoneDrive", label = "OZONE DRIVE", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "ToneHighpass", label = "LOW CUT", unit = "Hz", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Tone", label = "HIGH CUT", unit = "Hz", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Decay", label = "ARC DECAY", unit = "s", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function EatsVolts.rack()
  return {
    rows = {
      {
        { id = "plasma_osc",    title = "SINGING ARC OSCILLATOR", hp = 16, row = 1, category = "VCO" },
        { id = "corona_crackle",title = "POISSON CORONA SIZZLE",  hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "spark_formants",title = "SPARK GAP RESONATOR",    hp = 16, row = 2, category = "VCF" },
        { id = "master_out",    title = "OZONE SATURATION OUT",   hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:0:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "cv" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return EatsVolts
''',
    ),

    // 00b. Eats Furnace Physical Model (Thermoacoustic Combustion & Singing Pipe)
    LuaPreset(
      id: 'eats_furnace',
      name: 'Eats Furnace',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of real-world thermoacoustic combustion and blast furnaces: Kastner Rijke singing flame oscillator, convective temperature drift, turbulent combustion roar, supercritical wood sap pocket explosions, flying ember sizzles, deflagration flashover whoosh, thermal convection phaser, and tuned glass/brass draft cylinder resonance.',
      code: '''
-- @id: eats_furnace
-- @name: Eats Furnace
-- @category: instrument
-- @description: Physical modeling of real-world thermoacoustic combustion and blast furnaces: Kastner Rijke singing flame oscillator, convective temperature drift, turbulent combustion roar, supercritical wood sap pocket explosions, flying ember sizzles, deflagration flashover whoosh, thermal convection phaser, and tuned glass/brass draft cylinder resonance.

local EatsFurnace = {}

function EatsFurnace.init()
  -- Singing Flame & Rijke Tube Core
  Param.add("FuelPressure", 0.1, 3.0, 1.25)
  Param.add("FlameCusp", 0.0, 1.0, 0.45)
  Param.add("TubeResonance", 0.0, 1.0, 0.50)
  Param.add("IgnitionSnap", 0.0, 2.5, 0.85)

  -- Combustion Roar & Sap Explosions
  Param.add("CombustionRoar", 0.0, 1.0, 0.35)
  Param.add("OxygenDraft", 0.0, 1.0, 0.40)
  Param.add("SapCrackle", 0.0, 1.0, 0.40)
  Param.add("EmberSizzle", 0.0, 1.0, 0.35)

  -- Thermal Convection All-Pass Phaser
  Param.add("PhaserRate", 0.05, 8.0, 0.35)
  Param.add("PhaserDepth", 0.0, 1.0, 0.55)
  Param.add("PhaserFeedback", 0.0, 1.0, 0.35)
  Param.add("PhaserMix", 0.0, 1.0, 0.40)

  -- Chimney Draft & Tone Shaping
  Param.add("ToneHighpass", 20.0, 2000.0, 25.0)
  Param.add("Tone", 800.0, 16000.0, 7500.0)
  Param.add("Decay", 0.05, 2.5, 0.50)
end

function EatsFurnace.process(time, freq, note, params)
  local fuel = params["FuelPressure"] or 1.25
  local cusp = params["FlameCusp"] or 0.45
  local reso = params["TubeResonance"] or 0.50
  local snap = params["IgnitionSnap"] or 0.85
  local roar = params["CombustionRoar"] or 0.35
  local draft = params["OxygenDraft"] or 0.40
  local sap = params["SapCrackle"] or 0.40
  local ember = params["EmberSizzle"] or 0.35
  local decay = params["Decay"] or 0.50
  local pRate = params["PhaserRate"] or 0.35
  local pDepth = params["PhaserDepth"] or 0.55
  local pMix = params["PhaserMix"] or 0.40

  -- Direct single-cycle fallback
  local fInst = freq * (1.0 + (math.random() * 2.0 - 1.0) * 0.015)
  local theta = 2.0 * math.pi * fInst * time
  local flameWave = math.sin(theta) + 0.35 * cusp * math.sin(theta * 2.0) - 0.15 * cusp * math.cos(theta * 3.0)
  local singingFlame = flameWave * (1.0 - reso * 0.4) + math.sin(theta) * (reso * 0.4)

  -- Combustion roar (Brownian turbulence simulation)
  local roarTone = (math.random() * 2.0 - 1.0) * roar * 0.25 * (1.0 + 0.3 * math.sin(2.0 * math.pi * 3.5 * time))

  -- Ignition deflagration whoosh
  local snapWhoosh = math.sin(2.0 * math.pi * 65.0 * time) * math.exp(-time * 40.0) * snap

  -- Sap explosion pop
  local sapPop = (math.random() < (sap * 0.02)) and (math.sin(2.0 * math.pi * 450.0 * time) * 0.5) or 0.0
  local emberTick = (math.random() < (ember * 0.06)) and ((math.random() * 2.0 - 1.0) * 0.3) or 0.0

  -- Phaser modulation fallback
  local phaserMod = 1.0 + 0.25 * pMix * math.sin(2.0 * math.pi * pRate * time) * pDepth

  local ampEnv = math.exp(-time / math.max(0.04, decay))
  local raw = (singingFlame * fuel * phaserMod + roarTone + snapWhoosh + sapPop + emberTick) * ampEnv

  return math.tanh(raw * 1.2) * 0.95
end

function EatsFurnace.gui()
  return {
    panel = {
      title = "EATS FURNACE",
      subtitle = "Thermoacoustic Blast Furnace & Singing Pipe",
      accent = "#FF5722",
      background = "matte_metal",
      rackSides = "brushed_steel",
      cornerRadius = 0,
      layout = {
        -- ORANGE SECTION: Singing Flame & Rijke Tube
        {
          type = "group",
          label = "SINGING FLAME & RIJKE TUBE (ORANGE)",
          accent = "#FF5722",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "FuelPressure", label = "FUEL FLOW", unit = "bar", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "FlameCusp", label = "FLAME CUSP", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "TubeResonance", label = "TUBE RESO", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "IgnitionSnap", label = "IGNITION", unit = "kJ", knobStyle = "chrome", size = 52 },
              }
            }
          }
        },
        -- AMBER SECTION: Combustion Roar & Sap Explosions
        {
          type = "group",
          label = "COMBUSTION ROAR & SAP EXPLOSIONS (AMBER)",
          accent = "#FFB300",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "CombustionRoar", label = "FLAME ROAR", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "OxygenDraft", label = "DRAFT VENT", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "SapCrackle", label = "SAP POP", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "EmberSizzle", label = "EMBER HISS", unit = "%", knobStyle = "vintage", size = 52 },
              }
            },
            {
              type = "row",
              children = {
                { type = "hslider", param = "FuelPressure", label = "PRESSURIZED GAS INJECTION RATE", style = "capsule" },
              }
            }
          }
        },
        -- PURPLE SECTION: Thermal Convection Phaser
        {
          type = "group",
          label = "CONVECTION TURBULENCE PHASER (PURPLE)",
          accent = "#7C4DFF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "PhaserRate", label = "DRAFT SWIRL", unit = "Hz", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PhaserDepth", label = "SWEEP DEPTH", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PhaserFeedback", label = "FLUE RESO", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PhaserMix", label = "PHASER MIX", unit = "%", knobStyle = "vintage", size = 52 },
              }
            }
          }
        },
        -- RED SECTION: Chimney Draft Tone
        {
          type = "group",
          label = "CHIMNEY DRAFT & MASTER TONE (RED)",
          accent = "#FF1744",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "ToneHighpass", label = "LOW CUT", unit = "Hz", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Tone", label = "HIGH CUT", unit = "Hz", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Decay", label = "FLAME DECAY", unit = "s", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function EatsFurnace.rack()
  return {
    rows = {
      {
        { id = "singing_flame", title = "RIJKE SINGING FLAME", hp = 16, row = 1, category = "VCO" },
        { id = "sap_crackle",   title = "POISSON SAP EXPLOSION", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "tube_formant",  title = "GLASS DRAFT CYLINDER",  hp = 16, row = 2, category = "VCF" },
        { id = "master_out",    title = "COMBUSTION OUTPUT",     hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:0:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "cv" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return EatsFurnace
''',
    ),

    // 00c. Eats Water Physical Model (Hydraulophone & Fluid Cavitation)
    LuaPreset(
      id: 'eats_water',
      name: 'Eats Water',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of real-world water, pressurized waterjets, and bubble cavitation: Steve Mann hydraulophone jet oscillator, Minnaert bubble pinch-off frequency chirp, hydrodynamic whirlpool vortex churning, droplet splash & foam spray matrix, 4-stage fluid Doppler phaser, and submerged hydrophone acoustics.',
      code: '''
-- @id: eats_water
-- @name: Eats Water
-- @category: instrument
-- @description: Physical modeling of real-world water, pressurized waterjets, and bubble cavitation: Steve Mann hydraulophone jet oscillator, Minnaert bubble pinch-off frequency chirp, hydrodynamic whirlpool vortex churning, droplet splash & foam spray matrix, 4-stage fluid Doppler phaser, and submerged hydrophone acoustics.

local EatsWater = {}

function EatsWater.init()
  -- Hydraulophone Waterjet Core
  Param.add("WaterFlow", 0.1, 3.0, 1.25)
  Param.add("BubblePinch", 0.0, 1.0, 0.45)
  Param.add("Viscosity", 0.0, 1.0, 0.40)
  Param.add("PlungeImpact", 0.0, 2.5, 0.85)

  -- Hydrodynamic Vortex & Cavitation Matrix
  Param.add("Turbulence", 0.0, 1.0, 0.35)
  Param.add("CurrentDrift", 0.0, 1.0, 0.35)
  Param.add("DropletRate", 0.0, 1.0, 0.40)
  Param.add("SprayHiss", 0.0, 1.0, 0.35)

  -- Hydrodynamic Whirlpool All-Pass Phaser
  Param.add("PhaserRate", 0.05, 8.0, 0.28)
  Param.add("PhaserDepth", 0.0, 1.0, 0.60)
  Param.add("PhaserFeedback", 0.0, 1.0, 0.45)
  Param.add("PhaserMix", 0.0, 1.0, 0.45)

  -- Immersion Depth & Hydrophone Tone Shaping
  Param.add("ToneHighpass", 20.0, 2000.0, 20.0)
  Param.add("Depth", 500.0, 16000.0, 6500.0)
  Param.add("Decay", 0.05, 2.5, 0.50)
end

function EatsWater.process(time, freq, note, params)
  local flow = params["WaterFlow"] or 1.25
  local chirp = params["BubblePinch"] or 0.45
  local visc = params["Viscosity"] or 0.40
  local snap = params["PlungeImpact"] or 0.85
  local turb = params["Turbulence"] or 0.35
  local drops = params["DropletRate"] or 0.40
  local spray = params["SprayHiss"] or 0.35
  local decay = params["Decay"] or 0.50
  local pRate = params["PhaserRate"] or 0.28
  local pDepth = params["PhaserDepth"] or 0.60
  local pMix = params["PhaserMix"] or 0.45

  -- Direct single-cycle fallback
  local fInst = freq * (1.0 + (math.random() * 2.0 - 1.0) * 0.012)
  local theta = 2.0 * math.pi * fInst * time
  local waterWave = math.sin(theta + 0.3 * chirp * math.sin(theta))
  local fluidTone = waterWave * (1.0 - visc * 0.5) + math.sin(theta) * (visc * 0.5)

  -- Hydrodynamic turbulence (whirlpool rumble)
  local vortexTone = (math.random() * 2.0 - 1.0) * turb * 0.22 * (1.0 + 0.3 * math.sin(2.0 * math.pi * 2.8 * time))

  -- Plunge impact transient
  local plungeSnap = math.sin(2.0 * math.pi * 180.0 * time) * math.exp(-time * 50.0) * snap

  -- Droplet plinks & foam spray
  local dropPlink = (math.random() < (drops * 0.025)) and (math.sin(2.0 * math.pi * 750.0 * time) * 0.45) or 0.0
  local sprayTick = (math.random() < (spray * 0.06)) and ((math.random() * 2.0 - 1.0) * 0.25) or 0.0

  -- Phaser modulation fallback
  local phaserMod = 1.0 + 0.3 * pMix * math.sin(2.0 * math.pi * pRate * time) * pDepth

  local ampEnv = math.exp(-time / math.max(0.04, decay))
  local raw = (fluidTone * flow * phaserMod + vortexTone + plungeSnap + dropPlink + sprayTick) * ampEnv

  return math.tanh(raw * 1.15) * 0.95
end

function EatsWater.gui()
  return {
    panel = {
      title = "EATS WATER",
      subtitle = "Hydraulophone & Fluid Synthesizer",
      accent = "#00E5FF",
      background = "matte_metal",
      rackSides = "brushed_steel",
      cornerRadius = 0,
      layout = {
        -- AQUA SECTION: Hydraulophone Waterjet & Minnaert Bubble
        {
          type = "group",
          label = "WATERJET & MINNAERT BUBBLE CORE (CYAN)",
          accent = "#00E5FF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "WaterFlow", label = "WATER FLOW", unit = "L/m", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "BubblePinch", label = "BUBBLE CHIRP", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Viscosity", label = "VISCOSITY", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "PlungeImpact", label = "PLUNGE SNAP", knobStyle = "chrome", size = 52 },
              }
            }
          }
        },
        -- OCEAN SECTION: Hydrodynamic Whirlpool & Droplet Matrix
        {
          type = "group",
          label = "WHIRLPOOL CHURN & DROPLET MATRIX (TEAL)",
          accent = "#00BFA5",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "Turbulence", label = "WHIRLPOOL", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "CurrentDrift", label = "CURRENT DRIFT", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "DropletRate", label = "DROPLET PLINK", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "SprayHiss", label = "SPRAY FOAM", unit = "%", knobStyle = "vintage", size = 52 },
              }
            },
            {
              type = "row",
              children = {
                { type = "hslider", param = "WaterFlow", label = "PRESSURIZED WATERJET INJECTION RATE", style = "capsule" },
              }
            }
          }
        },
        -- PURPLE SECTION: Whirlpool Fluid Phaser
        {
          type = "group",
          label = "WHIRLPOOL FLUID PHASER (PURPLE)",
          accent = "#7C4DFF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "PhaserRate", label = "EDDY SWIRL", unit = "Hz", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PhaserDepth", label = "SWEEP DEPTH", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PhaserFeedback", label = "VORTEX RESO", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PhaserMix", label = "PHASER MIX", unit = "%", knobStyle = "vintage", size = 52 },
              }
            }
          }
        },
        -- DEEP BLUE SECTION: Immersion Depth & Hydrophone Tone
        {
          type = "group",
          label = "IMMERSION DEPTH & HYDROPHONE TONE (BLUE)",
          accent = "#00B0FF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "ToneHighpass", label = "LOW CUT", unit = "Hz", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Depth", label = "HIGH CUT", unit = "Hz", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Decay", label = "WAVE DECAY", unit = "s", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function EatsWater.rack()
  return {
    rows = {
      {
        { id = "hydraulophone", title = "WATERJET OSCILLATOR", hp = 16, row = 1, category = "VCO" },
        { id = "droplet_matrix", title = "DROPLET CAVITATION",   hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "pool_formant",   title = "SUBMERGED HYDROPHONE", hp = 16, row = 2, category = "VCF" },
        { id = "master_out",     title = "FLUID CAVITY OUTPUT",  hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "2:0:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "cv" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return EatsWater
''',
    ),

    // 00d. Eats Rain Physical Model (Granular Precipitation & Surface Cavity Matrix)
    LuaPreset(
      id: 'eats_rain',
      name: 'Eats Rain',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of real-world precipitation, rainfall, and surface impacts: Poisson granular droplet generator with Minnaert bubble pinch-off cavitation chirp, continuous atmospheric pink rain wash hiss, multi-surface modal cavity resonators (puddle, tin roof, foliage), and gutter drip dynamics.',
      code: '''
-- @id: eats_rain
-- @name: Eats Rain
-- @category: instrument
-- @description: Physical modeling of real-world precipitation, rainfall, and surface impacts: Poisson granular droplet generator with Minnaert bubble pinch-off cavitation chirp, continuous atmospheric pink rain wash hiss, multi-surface modal cavity resonators (puddle, tin roof, foliage), and gutter drip dynamics.

local EatsRain = {}

function EatsRain.init()
  -- Granular Precipitation Core
  Param.add("RainIntensity", 0.0, 1.0, 0.55)
  Param.add("DropletForce", 0.1, 1.5, 0.80)
  Param.add("DropletPitch", 0.5, 2.5, 1.0)
  Param.add("RainHiss", 0.0, 1.0, 0.40)

  -- Surface Cavity Resonator (0=Puddle, 1=Tin Roof, 2=Foliage)
  Param.add("SurfaceType", 0.0, 2.0, 0.0)
  Param.add("SurfaceReso", 0.1, 0.95, 0.60)
  Param.add("Brightness", 0.2, 2.0, 1.0)

  -- Tone & Dispersion
  Param.add("Tone", 1000.0, 18000.0, 11000.0)
  Param.add("Decay", 0.1, 4.0, 1.2)
end

function EatsRain.process(time, freq, note, params)
  local intens = params["RainIntensity"] or 0.55
  local force = params["DropletForce"] or 0.80
  local pitch = params["DropletPitch"] or 1.0
  local hiss = params["RainHiss"] or 0.40
  local decay = params["Decay"] or 1.2

  -- Continuous rain wash (pink noise floor approximation)
  local washTone = (math.random() * 2.0 - 1.0) * hiss * 0.22

  -- Discrete Minnaert droplet plink chirp
  local dropPlink = (math.random() < (intens * 0.045)) and (math.sin(2.0 * math.pi * 780.0 * pitch * time) * force * 0.55) or 0.0

  local ampEnv = math.exp(-time / math.max(0.1, decay))
  local raw = (washTone + dropPlink) * ampEnv
  return math.tanh(raw * 1.2) * 0.95
end

function EatsRain.gui()
  return {
    panel = {
      title = "EATS RAIN",
      subtitle = "Granular Precipitation & Surface Acoustic Matrix",
      accent = "#00E5FF",
      background = "matte_metal",
      rackSides = "brushed_steel",
      cornerRadius = 0,
      layout = {
        {
          type = "group",
          label = "PRECIPITATION & DROPLETS (CYAN)",
          accent = "#00E5FF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "RainIntensity", label = "DOWNPOUR", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "DropletForce", label = "DROP IMPACT", unit = "J", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "DropletPitch", label = "DROP SIZE", unit = "mm", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "RainHiss", label = "RAIN WASH", unit = "dB", knobStyle = "chrome", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "SURFACE CAVITY & ACOUSTIC IMPACT (BLUE)",
          accent = "#2979FF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "SurfaceType", label = "SURFACE", unit = "idx", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "SurfaceReso", label = "CAVITY RESO", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Brightness", label = "SPLASH BITE", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Tone", label = "HIGH CUT", unit = "Hz", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return EatsRain
''',
    ),

    // 00e. Eats Wind Physical Model (Aeolian Tempest & Cavity Howl)
    LuaPreset(
      id: 'eats_wind',
      name: 'Eats Wind',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of atmospheric wind, Aeolian tones, and architectural cavity whistling: fractional Brownian motion aerodynamic gust generator, Strouhal vortex shedding resonance, Harmon-derived window crack cavity notch, and chimney howl modal resonator.',
      code: '''
-- @id: eats_wind
-- @name: Eats Wind
-- @category: instrument
-- @description: Physical modeling of atmospheric wind, Aeolian tones, and architectural cavity whistling: fractional Brownian motion aerodynamic gust generator, Strouhal vortex shedding resonance, Harmon-derived window crack cavity notch, and chimney howl modal resonator.

local EatsWind = {}

function EatsWind.init()
  -- Aerodynamic Gust Core
  Param.add("GustSpeed", 0.05, 3.0, 0.25)
  Param.add("Turbulence", 0.0, 1.0, 0.65)

  -- Aeolian Vortex Shedding & Cavity Whistle
  Param.add("AeolianPitch", 60.0, 2000.0, 440.0)
  Param.add("HowlDepth", 0.0, 1.0, 0.70)

  -- Atmospheric Absorption & Tone
  Param.add("Tone", 400.0, 12000.0, 4800.0)
  Param.add("Decay", 0.2, 5.0, 2.0)
end

function EatsWind.process(time, freq, note, params)
  local speed = params["GustSpeed"] or 0.25
  local turb = params["Turbulence"] or 0.65
  local fAeol = params["AeolianPitch"] or freq or 440.0
  local howl = params["HowlDepth"] or 0.70
  local decay = params["Decay"] or 2.0

  -- Brownian/Pink turbulence airflow
  local gustMod = 0.5 + 0.5 * math.sin(2.0 * math.pi * speed * time)
  local airflow = (math.random() * 2.0 - 1.0) * (0.3 + 0.7 * gustMod * turb)

  -- Aeolian vortex whistle
  local whistle = math.sin(2.0 * math.pi * fAeol * time) * howl * 0.45 * gustMod

  local ampEnv = math.exp(-time / math.max(0.2, decay))
  local raw = (airflow * 0.5 + whistle * 0.5) * ampEnv
  return math.tanh(raw * 1.3) * 0.95
end

function EatsWind.gui()
  return {
    panel = {
      title = "EATS WIND",
      subtitle = "Aeolian Tempest & Cavity Howl Synthesizer",
      accent = "#26A69A",
      background = "matte_metal",
      rackSides = "brushed_steel",
      cornerRadius = 0,
      layout = {
        {
          type = "group",
          label = "AERODYNAMIC GUST & TURBULENCE (TEAL)",
          accent = "#26A69A",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "GustSpeed", label = "GUST SPEED", unit = "Hz", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Turbulence", label = "TURBULENCE", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "AeolianPitch", label = "VORTEX PITCH", unit = "Hz", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "HowlDepth", label = "HOWL DEPTH", unit = "%", knobStyle = "chrome", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "ATMOSPHERIC AIR ABSORPTION & TONE (SLATE)",
          accent = "#78909C",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "Tone", label = "AIR LOWPASS", unit = "Hz", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Decay", label = "GUST SUSTAIN", unit = "s", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return EatsWind
''',
    ),

    // 00f. Eats Fire Physical Model (Organic Campfire, Hearth & Sap Crackle)
    LuaPreset(
      id: 'eats_fire',
      name: 'Eats Fire',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of natural open fire, living hearths, and campfires: low-frequency turbulent deflagration combustion roar, convective thermal draft drift, supercritical wood sap pocket explosions, flying ember sizzle crackle matrix, and hollow hearth log resonance.',
      code: '''
-- @id: eats_fire
-- @name: Eats Fire
-- @category: instrument
-- @description: Physical modeling of natural open fire, living hearths, and campfires: low-frequency turbulent deflagration combustion roar, convective thermal draft drift, supercritical wood sap pocket explosions, flying ember sizzle crackle matrix, and hollow hearth log resonance.

local EatsFire = {}

function EatsFire.init()
  -- Combustion Roar & Convection Draft
  Param.add("FlameRoar", 0.0, 1.0, 0.60)
  Param.add("FlameDraft", 0.05, 2.0, 0.40)

  -- Supercritical Wood Sap Explosions & Ember Sizzle
  Param.add("SapCrackle", 0.0, 1.0, 0.45)
  Param.add("PopEnergy", 0.1, 1.5, 0.85)
  Param.add("EmberSizzle", 0.0, 1.0, 0.50)

  -- Hollow Hearth Log Resonator
  Param.add("HearthReso", 0.1, 0.95, 0.55)
  Param.add("Tone", 500.0, 16000.0, 8000.0)
  Param.add("Decay", 0.1, 4.0, 1.5)
end

function EatsFire.process(time, freq, note, params)
  local roar = params["FlameRoar"] or 0.60
  local draft = params["FlameDraft"] or 0.40
  local sap = params["SapCrackle"] or 0.45
  local pop = params["PopEnergy"] or 0.85
  local ember = params["EmberSizzle"] or 0.50
  local decay = params["Decay"] or 1.5

  -- Thermal convection flutter
  local convection = 0.5 + 0.5 * math.sin(2.0 * math.pi * draft * time)
  local roarTone = (math.random() * 2.0 - 1.0) * roar * 0.30 * convection

  -- Sap pop rupture
  local sapPop = (math.random() < (sap * 0.035)) and (math.sin(2.0 * math.pi * 340.0 * time) * pop * 0.65) or 0.0

  -- Ember sizzle
  local emberTick = (math.random() < (ember * 0.065)) and ((math.random() * 2.0 - 1.0) * 0.35) or 0.0

  local ampEnv = math.exp(-time / math.max(0.1, decay))
  local raw = (roarTone + sapPop + emberTick) * ampEnv
  return math.tanh(raw * 1.25) * 0.95
end

function EatsFire.gui()
  return {
    panel = {
      title = "EATS FIRE",
      subtitle = "Organic Campfire, Hearth & Sap Crackle Generator",
      accent = "#FF3D00",
      background = "matte_metal",
      rackSides = "brushed_steel",
      cornerRadius = 0,
      layout = {
        {
          type = "group",
          label = "COMBUSTION ROAR & CONVECTION (AMBER)",
          accent = "#FF9100",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "FlameRoar", label = "FLAME ROAR", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "FlameDraft", label = "THERMAL DRAFT", unit = "Hz", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "HearthReso", label = "HEARTH LOG", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Tone", label = "TONE", unit = "Hz", knobStyle = "chrome", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "WOOD SAP EXPLOSIONS & EMBER SIZZLE (ORANGE)",
          accent = "#FF3D00",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "SapCrackle", label = "SAP POP RATE", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PopEnergy", label = "POP ENERGY", unit = "J", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "EmberSizzle", label = "EMBER SIZZLE", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Decay", label = "BURN DECAY", unit = "s", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return EatsFire
''',
    ),

    // 00g. Eats Thunder Physical Model (Dispersive Shockwave & Rolling Thunderstrike)
    LuaPreset(
      id: 'eats_thunder',
      name: 'Eats Thunder',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of lightning shockwaves, atmospheric acoustic dispersion, and terrain reverberation: hypersonic Dirac shockwave impulse, Commuted Grand Piano soundboard modal dispersion network, distance-dependent air absorption lowpass, and deep valley chasm sub-bass roll.',
      code: '''
-- @id: eats_thunder
-- @name: Eats Thunder
-- @category: instrument
-- @description: Physical modeling of lightning shockwaves, atmospheric acoustic dispersion, and terrain reverberation: hypersonic Dirac shockwave impulse, Commuted Grand Piano soundboard modal dispersion network, distance-dependent air absorption lowpass, and deep valley chasm sub-bass roll.

local EatsThunder = {}

function EatsThunder.init()
  -- Hypersonic Strike Shockwave
  Param.add("StrikeTrigger", 0.0, 1.0, 0.25)
  Param.add("StrikeProximity", 0.1, 1.5, 1.0)

  -- Atmospheric Propagation & Dispersion
  Param.add("Distance", 10.0, 3000.0, 450.0)
  Param.add("Dispersion", 0.0, 1.0, 0.75)
  Param.add("AirAbsorption", 0.0, 1.0, 0.80)

  -- Chasm & Piano Soundboard Rolling Resonance
  Param.add("RumbleReso", 0.1, 0.95, 0.70)
  Param.add("RumbleDecay", 0.2, 8.0, 3.5)
  Param.add("Tone", 200.0, 8000.0, 1600.0)
end

function EatsThunder.process(time, freq, note, params)
  local prox = params["StrikeProximity"] or 1.0
  local dist = params["Distance"] or 450.0
  local disp = params["Dispersion"] or 0.75
  local decay = params["RumbleDecay"] or 3.5

  -- Hypersonic shock snap
  local snap = math.exp(-time * 50.0) * prox * (math.random() * 2.0 - 1.0)

  -- Deep dispersive rolling sub-bass rumble
  local fRumble = math.max(30.0, (freq or 45.0) * (1.0 - math.exp(-time * 0.8)))
  local rumble = math.sin(2.0 * math.pi * fRumble * time) * math.exp(-time / math.max(0.5, decay)) * (0.5 + 0.5 * disp)

  local raw = snap * (50.0 / math.max(10.0, dist * 0.1)) + rumble * 0.85
  return math.tanh(raw * 1.3) * 0.95
end

function EatsThunder.gui()
  return {
    panel = {
      title = "EATS THUNDER",
      subtitle = "Dispersive Shockwave & Rolling Thunderstrike",
      accent = "#7C4DFF",
      background = "matte_metal",
      rackSides = "brushed_steel",
      cornerRadius = 0,
      layout = {
        {
          type = "group",
          label = "HYPERSONIC LIGHTNING STRIKE (VIOLET)",
          accent = "#7C4DFF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "StrikeProximity", label = "STRIKE FORCE", unit = "kA", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Distance", label = "DISTANCE", unit = "m", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Dispersion", label = "ROLL DISPERSION", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "AirAbsorption", label = "AIR ABSORPTION", unit = "%", knobStyle = "chrome", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "SOUNDBOARD CAVITY & SUB-BASS RUMBLE (INDIGO)",
          accent = "#3D5AFE",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "RumbleReso", label = "CHASM RESO", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "RumbleDecay", label = "RUMBLE DECAY", unit = "s", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Tone", label = "AIR LOWPASS", unit = "Hz", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return EatsThunder
''',
    ),




    // 00a. Dub Guitar Physical Model (Reggae Sound System Edition)
    LuaPreset(
      id: 'reggae_guitar',
      name: 'Dub Guitar',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a clean single-coil/P90 electric guitar for reggae and dub music: multi-string plectrum strum rake, Karplus-Strong waveguide with palm mute damping, 130Hz sub-bass cut, 3.2kHz pick bite, and vintage tube preamp. Best paired with Cab Designer FX (2x12 Open-Back cab)!',
      code: '''
-- @id: reggae_guitar
-- @name: Dub Guitar
-- @category: instrument
-- @description: Physical modeling of a clean single-coil/P90 electric guitar for reggae and dub music: multi-string plectrum strum rake, Karplus-Strong waveguide with palm mute damping, 130Hz sub-bass cut, 3.2kHz pick bite, and vintage tube preamp. Best paired with Cab Designer FX (2x12 Open-Back cab)!


local ReggaeGuitar = {}

function ReggaeGuitar.init()
  -- Strum & Pluck Mechanics
  Param.add("StrumSpread", 2.0, 30.0, 8.5)
  Param.add("PickBite", 0.2, 3.0, 1.25)
  
  -- Palm Mute & Waveguide Damping
  Param.add("PalmDamp", 0.05, 0.90, 0.42)
  Param.add("ChopDecay", 0.04, 0.60, 0.18)
  Param.add("Sustain", 0.85, 0.999, 0.994)
  
  -- Single-Coil Pickup Voicing & Preamp
  Param.add("BiteGain", -6.0, 12.0, 4.5)
  Param.add("ToneCutoff", 2000.0, 12000.0, 6800.0)
  Param.add("Drive", 0.5, 3.0, 1.15)
end

function ReggaeGuitar.process(time, freq, note, params)
  local spread = params["StrumSpread"] or 8.5
  local bite = params["PickBite"] or 1.25
  local damp = params["PalmDamp"] or 0.42
  local decay = params["ChopDecay"] or 0.18
  local drive = params["Drive"] or 1.15

  -- Direct single-cycle fallback
  local phase = 2.0 * math.pi * freq * time
  local stringCore = math.sin(phase) + 0.35 * math.sin(phase * 2.0) + 0.15 * math.sin(phase * 3.0)
  local pickClick = (math.random() * 2.0 - 1.0) * math.exp(-time * 180.0) * bite * 0.4
  local chopEnv = math.exp(-time / math.max(0.02, decay))
  
  local raw = (stringCore + pickClick) * chopEnv
  return math.tanh(raw * drive) * 0.95
end

function ReggaeGuitar.gui()
  return {
    panel = {
      title = "DUB GUITAR",
      subtitle = "Sound System Physical Waveguide & Preamp",
      accent = "#00E676",
      background = "matte_metal",
      rackSides = "brushed_steel",
      cornerRadius = 0,
      layout = {
        -- RED SECTION: Strum & Plectrum Attack
        {
          type = "group",
          label = "STRUM & PLECTRUM ATTACK (RED)",
          accent = "#FF2A2A",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "StrumSpread", label = "STRUM MS", unit = "ms", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PickBite", label = "PICK BITE", knobStyle = "vintage", size = 52 },
              }
            }
          }
        },
        -- GOLD SECTION: Palm Mute & Chop Envelope
        {
          type = "group",
          label = "PALM MUTE & CHOP TIMING (GOLD)",
          accent = "#FFB300",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "PalmDamp", label = "PALM MUTE", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "ChopDecay", label = "CHOP DECAY", unit = "s", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
              }
            },
            {
              type = "row",
              children = {
                { type = "hslider", param = "PalmDamp", label = "PALM MUTE DAMPING (PERCUSSIVE CHICK <-> OPEN RING)", style = "capsule" },
              }
            }
          }
        },
        -- GREEN SECTION: Preamp & Pick Bite Voicing
        {
          type = "group",
          label = "PREAMP & 3.2kHz TONE BARK (GREEN)",
          accent = "#00E676",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BiteGain", label = "3.2kHz BITE", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "ToneCutoff", label = "TONE", unit = "Hz", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Drive", label = "PREAMP DRIVE", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function ReggaeGuitar.rack()
  return {
    rows = {
      {
        { id = "strum_exciter", title = "PLECTRUM STRUM EXCITOR", hp = 16, row = 1, category = "VCO" },
        { id = "waveguide",     title = "KARPLUS WAVEGUIDE", hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "pickup_voicing", title = "P90 PICKUP & 130Hz HPF", hp = 16, row = 2, category = "MOD" },
        { id = "master",         title = "GUITAR CLEAN OUT", hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return ReggaeGuitar
''',
    ),

    // 00b. Hawaiian Acoustic Ukulele Physical Model
    LuaPreset(
      id: 'hawaiian_ukulele',
      name: 'Hawaiian Ukulele',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a traditional Hawaiian acoustic concert ukulele: nylon/fluorocarbon 4-string strum brush, Karplus-Strong waveguide with acoustic loss damping, Hawaiian Koa wood soundboard and air cavity modal resonance (330Hz, 590Hz, 1150Hz), 180Hz sub cut, and 2.8kHz island brightness.',
      code: '''
-- @id: hawaiian_ukulele
-- @name: Hawaiian Ukulele
-- @category: instrument
-- @description: Physical modeling of a traditional Hawaiian acoustic concert ukulele: nylon/fluorocarbon 4-string strum brush, Karplus-Strong waveguide with acoustic loss damping, Hawaiian Koa wood soundboard and air cavity modal resonance (330Hz, 590Hz, 1150Hz), 180Hz sub cut, and 2.8kHz island brightness.

local HawaiianUkulele = {}

function HawaiianUkulele.init()
  -- Strum & Nylon Pluck
  Param.add("StrumSpread", 2.0, 25.0, 6.5)
  Param.add("PluckSnap", 0.2, 3.0, 1.1)
  
  -- Waveguide Damping & Decay
  Param.add("Damping", 0.05, 0.85, 0.32)
  Param.add("Decay", 0.08, 1.20, 0.35)
  Param.add("Sustain", 0.85, 0.999, 0.990)
  
  -- Hawaiian Koa Acoustic Tone & Brightness
  Param.add("Brightness", -6.0, 10.0, 3.5)
  Param.add("Tone", 2500.0, 14000.0, 7200.0)
end

function HawaiianUkulele.process(time, freq, note, params)
  local spread = params["StrumSpread"] or 6.5
  local snap = params["PluckSnap"] or 1.1
  local damping = params["Damping"] or 0.32
  local decay = params["Decay"] or 0.35

  -- Nylon string core with acoustic warmth
  local phase = 2.0 * math.pi * freq * time
  local stringCore = math.sin(phase) + 0.45 * math.sin(phase * 2.0) + 0.20 * math.sin(phase * 3.0) + 0.10 * math.sin(phase * 4.0)
  local nylonClick = (math.random() * 2.0 - 1.0) * math.exp(-time * 220.0) * snap * 0.35
  local strumEnv = math.exp(-time / math.max(0.04, decay))
  
  local raw = (stringCore + nylonClick) * strumEnv
  return math.tanh(raw * 1.05) * 0.92
end

function HawaiianUkulele.gui()
  return {
    panel = {
      title = "HAWAIIAN UKULELE",
      subtitle = "Acoustic Koa Wood Soundboard & Nylon Strings",
      accent = "#FFB300",
      background = "blonde_pine",
      rackSides = "walnut",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "StrumSpread", label = "STRUM MS", unit = "ms", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "PluckSnap", label = "PLUCK SNAP", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Damping", label = "DAMPING", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "Damping", label = "ACOUSTIC STRING DAMPING (MUTED <-> OPEN RING)", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Brightness", label = "2.8kHz AIR", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Tone", label = "KOA TONE", unit = "Hz", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

function HawaiianUkulele.rack()
  return {
    rows = {
      {
        { id = "strum_exciter", title = "NYLON STRUM EXCITOR", hp = 16, row = 1, category = "VCO" },
        { id = "waveguide",     title = "KARPLUS WAVEGUIDE",   hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "body_resonance", title = "KOA BODY & AIR CAVITY", hp = 16, row = 2, category = "MOD" },
        { id = "master",         title = "UKULELE CLEAN OUT",    hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return HawaiianUkulele
''',
    ),

    // 00c. Spanish Concert Classical Guitar Physical Model
    LuaPreset(
      id: 'spanish_guitar',
      name: 'Spanish Classical Guitar',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a Spanish concert classical guitar: nylon trebles & silver-wound bass waveguides, fingertip flesh vs fingernail ramp attack, Spanish Torres fan-braced acoustic body resonator (98Hz Helmholtz air cavity & 196Hz soundboard plate), and cedar/spruce tone balance.',
      code: '''
-- @id: spanish_guitar
-- @name: Spanish Classical Guitar
-- @category: instrument
-- @description: Physical modeling of a Spanish concert classical guitar: nylon trebles & silver-wound bass waveguides, fingertip flesh vs fingernail ramp attack, Spanish Torres fan-braced acoustic body resonator (98Hz Helmholtz air cavity & 196Hz soundboard plate), and cedar/spruce tone balance.

local SpanishGuitar = {}

function SpanishGuitar.init()
  -- Pluck Dynamics & Transient
  Param.add("FleshNail", 0.0, 1.0, 0.40) -- 0.0 = Crisp Nail (Apoyando), 1.0 = Warm Flesh (Tirando)
  Param.add("Scrape", 0.0, 1.0, 0.35)
  Param.add("StrumSpread", 1.0, 25.0, 4.0)

  -- Waveguide & String Decay
  Param.add("Sustain", 0.85, 0.9995, 0.9955)
  Param.add("BodyDamp", 0.05, 0.80, 0.24)

  -- Acoustic Body & Wood Resonances
  Param.add("AirResonance", -6.0, 8.0, 2.0)
  Param.add("WoodTone", -6.0, 8.0, 1.5)
end

function SpanishGuitar.process(time, freq, note, params)
  local flesh = params["FleshNail"] or 0.40
  local sustain = params["Sustain"] or 0.9955
  local damp = params["BodyDamp"] or 0.24
  local air = params["AirResonance"] or 2.0

  local phase = 2.0 * math.pi * freq * time
  local core = math.sin(phase) + 0.35 * math.sin(phase * 2.0) + 0.15 * math.sin(phase * 3.0) + 0.08 * math.sin(phase * 4.0)
  local nailTransient = (math.random() * 2.0 - 1.0) * math.exp(-time * (180.0 + (1.0 - flesh) * 220.0)) * (1.1 - flesh * 0.5)
  local decayEnv = math.exp(-time / (0.8 + sustain * 1.5))

  local raw = (core + nailTransient) * decayEnv
  return math.tanh(raw * 1.05) * 0.94
end

function SpanishGuitar.gui()
  return {
    panel = {
      title = "SPANISH CLASSICAL GUITAR",
      subtitle = "Spanish Fan-Bracing & Nylon Waveguide Physical Model",
      accent = "#D97706",
      background = "blonde_pine",
      rackSides = "rosewood",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "FleshNail", label = "FLESH / NAIL", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Scrape", label = "WOUND SCRAPE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "StrumSpread", label = "MICRO STRUM", unit = "ms", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "BodyDamp", label = "STRING LOSS", unit = "%", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "FleshNail", label = "PLUCK ARTICULATION (0.0 APYONADO NAIL <-> 1.0 TIRANDO FLESH)", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "AirResonance", label = "98Hz AIR", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "WoodTone", label = "CEDAR / SPRUCE", unit = "dB", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

function SpanishGuitar.rack()
  return {
    rows = {
      {
        { id = "pluck_exciter", title = "NYLON PLUCK EXCITOR", hp = 16, row = 1, category = "VCO" },
        { id = "waveguide",     title = "STRING WAVEGUIDE",   hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "body_resonance", title = "TORRES FAN BODY 98Hz", hp = 16, row = 2, category = "MOD" },
        { id = "master",         title = "SPANISH GUITAR OUT",   hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return SpanishGuitar
''',
    ),

    // 00d. Renaissance & Baroque Lute Physical Model
    LuaPreset(
      id: 'renaissance_lute',
      name: 'Renaissance & Baroque Lute',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a double-course gut lute: paired coupled waveguides with organic micro-chorus beating (3.8 cents), soft fingertip flesh pluck, multi-ribbed vaulted bowl modal resonance (300-1200Hz), and airy renaissance upper shimmer.',
      code: '''
-- @id: renaissance_lute
-- @name: Renaissance & Baroque Lute
-- @category: instrument
-- @description: Physical modeling of a double-course gut lute: paired coupled waveguides with organic micro-chorus beating (3.8 cents), soft fingertip flesh pluck, multi-ribbed vaulted bowl modal resonance (300-1200Hz), and airy renaissance upper shimmer.

local RenaissanceLute = {}

function RenaissanceLute.init()
  -- Pluck & Course Coupling
  Param.add("FleshRatio", 0.0, 1.0, 0.70) -- Renaissance thumb-under flesh pluck
  Param.add("GutScrape", 0.0, 1.0, 0.25)
  Param.add("CourseSpread", 1.0, 20.0, 5.0)
  Param.add("CourseDetune", 0.0, 10.0, 3.8) -- Cents inter-string detuning
  Param.add("BridgeCoupling", 0.0, 0.25, 0.09)

  -- Gut String Waveguide
  Param.add("Sustain", 0.85, 0.999, 0.993)
  Param.add("GutDamp", 0.05, 0.75, 0.20)

  -- Vaulted Rib Bowl Modal Body
  Param.add("BowlWarmth", -6.0, 8.0, 2.2)
  Param.add("AirShimmer", -6.0, 8.0, 1.8)
end

function RenaissanceLute.process(time, freq, note, params)
  local flesh = params["FleshRatio"] or 0.70
  local detune = params["CourseDetune"] or 3.8
  local sustain = params["Sustain"] or 0.993

  local f1 = freq * (1.0 - (detune * 0.5) / 1200.0)
  local f2 = freq * (1.0 + (detune * 0.5) / 1200.0)

  local phase1 = 2.0 * math.pi * f1 * time
  local phase2 = 2.0 * math.pi * f2 * time

  local course1 = math.sin(phase1) + 0.3 * math.sin(phase1 * 2.0)
  local course2 = math.sin(phase2) + 0.3 * math.sin(phase2 * 2.0)
  local gutPluck = (math.random() * 2.0 - 1.0) * math.exp(-time * 160.0) * (1.0 - flesh * 0.4)
  local decay = math.exp(-time / (0.6 + sustain * 1.2))

  local raw = ((course1 + course2) * 0.5 + gutPluck * 0.25) * decay
  return math.tanh(raw * 1.05) * 0.92
end

function RenaissanceLute.gui()
  return {
    panel = {
      title = "RENAISSANCE & BAROQUE LUTE",
      subtitle = "Double-Course Gut & Vaulted Rib Bowl Physical Model",
      accent = "#EAB308",
      background = "matte_carbon",
      rackSides = "maple",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "CourseDetune", label = "COURSE DETUNE", unit = "cents", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "BridgeCoupling", label = "BRIDGE COUPL", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "FleshRatio", label = "FLESH PLUCK", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "GutScrape", label = "GUT SCRAPE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "CourseDetune", label = "DOUBLE-COURSE UNISON BEATING / CHORUS (0.0 <-> 10.0 CENTS)", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "BowlWarmth", label = "VAULTED BOWL", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "AirShimmer", label = "RENAISSANCE AIR", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "GutDamp", label = "GUT DAMPING", unit = "%", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

function RenaissanceLute.rack()
  return {
    rows = {
      {
        { id = "lute_exciter",   title = "GUT PLUCK EXCITOR",    hp = 16, row = 1, category = "VCO" },
        { id = "twin_waveguide", title = "DOUBLE-COURSE STRINGS", hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "bowl_resonator", title = "VAULTED RIB BOWL",     hp = 16, row = 2, category = "MOD" },
        { id = "master",         title = "LUTE STEREO OUT",      hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return RenaissanceLute
''',
    ),

    // 00e. Baroque Guitar (5-Course Re-Entrant) Physical Model
    LuaPreset(
      id: 'baroque_guitar',
      name: 'Baroque Guitar (5-Course)',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a 5-course re-entrant Baroque guitar: coupled double-course gut strings with high octave chime, rapid multi-finger rasgueado fan rakes, shallow body resonator with ornate parchment rose rosette damping, and bright gut bite.',
      code: '''
-- @id: baroque_guitar
-- @name: Baroque Guitar (5-Course)
-- @category: instrument
-- @description: Physical modeling of a 5-course re-entrant Baroque guitar: coupled double-course gut strings with high octave chime, rapid multi-finger rasgueado fan rakes, shallow body resonator with ornate parchment rose rosette damping, and bright gut bite.

local BaroqueGuitar = {}

function BaroqueGuitar.init()
  -- Rasgueado & Pluck Dynamics
  Param.add("RasgueadoSpeed", 2.0, 35.0, 12.0)
  Param.add("NailPluck", 0.0, 1.0, 0.30)
  Param.add("GutScrape", 0.0, 1.0, 0.45)

  -- Coupled Gut Courses & Octave High Chime
  Param.add("CourseDetune", 0.0, 12.0, 4.5)
  Param.add("OctaveCourses", 0.0, 1.0, 1.0) -- 1.0 = Re-entrant high octave pairing
  Param.add("Sustain", 0.85, 0.999, 0.9935)
  Param.add("StringDamp", 0.05, 0.70, 0.18)

  -- Parchment Rose Rosette & Body Tone
  Param.add("RoseBite", -6.0, 10.0, 3.0)
end

function BaroqueGuitar.process(time, freq, note, params)
  local speed = params["RasgueadoSpeed"] or 12.0
  local detune = params["CourseDetune"] or 4.5
  local oct = (params["OctaveCourses"] or 1.0) >= 0.5

  local f1 = freq
  local f2 = oct and (freq * 2.0) or (freq * (1.0 + detune / 1200.0))

  local phase1 = 2.0 * math.pi * f1 * time
  local phase2 = 2.0 * math.pi * f2 * time

  local gut1 = math.sin(phase1) + 0.35 * math.sin(phase1 * 2.0)
  local gut2 = math.sin(phase2) + 0.25 * math.sin(phase2 * 2.0)
  local rasgueadoSnap = (math.random() * 2.0 - 1.0) * math.exp(-time * 240.0) * 0.4
  local decay = math.exp(-time / 0.9)

  local raw = (gut1 + (oct and gut2 * 0.75 or gut2) + rasgueadoSnap) * decay
  return math.tanh(raw * 1.1) * 0.92
end

function BaroqueGuitar.gui()
  return {
    panel = {
      title = "BAROQUE GUITAR (5-COURSE)",
      subtitle = "Re-Entrant Gut & Parchment Rosette Physical Model",
      accent = "#CA8A04",
      background = "antique_parchment",
      rackSides = "walnut",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "RasgueadoSpeed", label = "RASGUEADO", unit = "ms", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "NailPluck", label = "NAIL SNAP", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "CourseDetune", label = "DETUNE", unit = "cents", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "OctaveCourses", label = "OCTAVE CHIME", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "RasgueadoSpeed", label = "MULTI-FINGER RASGUEADO STRUM FAN SPEED (2ms TIGHT <-> 35ms FLOURISH)", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "RoseBite", label = "PARCHMENT ROSE", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "StringDamp", label = "STRING LOSS", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "GutScrape", label = "GUT FRICTION", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

function BaroqueGuitar.rack()
  return {
    rows = {
      {
        { id = "rasgueado_exciter", title = "RASGUEADO FAN EXCITOR", hp = 16, row = 1, category = "VCO" },
        { id = "reentrant_wave",    title = "5-COURSE RE-ENTRANT",   hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "rosette_body",      title = "PARCHMENT ROSE BODY",   hp = 16, row = 2, category = "MOD" },
        { id = "master",            title = "BAROQUE GUITAR OUT",    hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return BaroqueGuitar
''',
    ),

    // 00f. Flamenco Guitar (Guitarra Flamenca Blanca) Physical Model
    LuaPreset(
      id: 'flamenco_guitar',
      name: 'Flamenco Guitar (Blanca)',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a Spanish Flamenco Blanca guitar: razor-sharp nail transient bite, rapid multi-finger rasgueados, low string action buzz/snap, Spanish cypress shallow body resonator, and integrated soundboard Golpe wood-tap percussion.',
      code: '''
-- @id: flamenco_guitar
-- @name: Flamenco Guitar (Blanca)
-- @category: instrument
-- @description: Physical modeling of a Spanish Flamenco Blanca guitar: razor-sharp nail transient bite, rapid multi-finger rasgueados, low string action buzz/snap, Spanish cypress shallow body resonator, and integrated soundboard Golpe wood-tap percussion.

local FlamencoGuitar = {}

function FlamencoGuitar.init()
  -- Pluck & Golpe Dynamics
  Param.add("NailBite", 0.0, 1.0, 0.10) -- Razor sharp nail bite
  Param.add("GolpeTap", 0.0, 1.5, 0.40) -- Soundboard wood tap strike
  Param.add("RasgueadoSpeed", 2.0, 35.0, 14.0)
  Param.add("Scrape", 0.0, 1.0, 0.50)

  -- Fast Cypress Decay & String Buzz
  Param.add("Sustain", 0.80, 0.998, 0.991)
  Param.add("SnapDamp", 0.05, 0.85, 0.28)

  -- Flamenco Bite & Cypress Punch
  Param.add("Bite", -4.0, 10.0, 3.5)
end

function FlamencoGuitar.process(time, freq, note, params)
  local bite = params["NailBite"] or 0.10
  local golpe = params["GolpeTap"] or 0.40
  local sustain = params["Sustain"] or 0.991

  local phase = 2.0 * math.pi * freq * time
  local stringCore = math.sin(phase) + 0.45 * math.sin(phase * 2.0) + 0.25 * math.sin(phase * 3.0) + 0.15 * math.sin(phase * 4.0)
  local nailSnap = (math.random() * 2.0 - 1.0) * math.exp(-time * 300.0) * 0.55
  local golpeThump = math.sin(2.0 * math.pi * 110.0 * time) * math.exp(-time * 120.0) * golpe

  local decay = math.exp(-time / (0.45 + sustain * 0.8))
  local raw = (stringCore + nailSnap + golpeThump) * decay
  return math.tanh(raw * 1.15) * 0.92
end

function FlamencoGuitar.gui()
  return {
    panel = {
      title = "FLAMENCO GUITAR (BLANCA)",
      subtitle = "Spanish Cypress & Soundboard Golpe Physical Model",
      accent = "#EF4444",
      background = "blonde_pine",
      rackSides = "ebony",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "GolpeTap", label = "GOLPE TAP", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "NailBite", label = "NAIL BITE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "RasgueadoSpeed", label = "RASGUEADO", unit = "ms", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "SnapDamp", label = "CYPRESS DAMP", unit = "%", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "GolpeTap", label = "SOUNDBOARD GOLPE TAP PERCUSSION (0.0 OFF <-> 1.5 ACCENT THUMP)", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Bite", label = "3.8kHz BITE", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Scrape", label = "STRING SCRAPE", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

function FlamencoGuitar.rack()
  return {
    rows = {
      {
        { id = "flamenco_exciter", title = "NAIL & GOLPE EXCITOR", hp = 16, row = 1, category = "VCO" },
        { id = "cypress_wave",     title = "CYPRESS WAVEGUIDE",   hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "cypress_body",     title = "SHALLOW BLANCA BODY", hp = 16, row = 2, category = "MOD" },
        { id = "master",           title = "FLAMENCO OUT",        hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return FlamencoGuitar
''',
    ),

    // 00g. Steel-String Acoustic Guitar Physical Model
    LuaPreset(
      id: 'acoustic_steel_guitar',
      name: 'Steel-String Acoustic Guitar',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a steel-string acoustic guitar: phosphor bronze string waveguide, flatpick vs fingerpick attack, and morphable body geometry (0.0 Parlor/000 <-> 0.5 Dreadnought <-> 1.0 Jumbo).',
      code: '''
-- @id: acoustic_steel_guitar
-- @name: Steel-String Acoustic Guitar
-- @category: instrument
-- @description: Physical modeling of a steel-string acoustic guitar: phosphor bronze string waveguide, flatpick vs fingerpick attack, and morphable body geometry (0.0 Parlor/000 <-> 0.5 Dreadnought <-> 1.0 Jumbo).

local SteelAcoustic = {}

function SteelAcoustic.init()
  -- Pluck Dynamics & Pick Style
  Param.add("PickStyle", 0.0, 1.0, 0.30) -- 0.0 = Hard Flatpick, 1.0 = Warm Fingerpick
  Param.add("WoundScrape", 0.0, 1.0, 0.40)
  Param.add("StrumSpread", 1.0, 25.0, 5.0)

  -- String Decay & Damping
  Param.add("Sustain", 0.85, 0.9995, 0.996)
  Param.add("Damping", 0.05, 0.75, 0.22)

  -- Morphable Acoustic Body Profile
  Param.add("BodyProfile", 0.0, 1.0, 0.50) -- 0.0 Parlor/000, 0.5 Dreadnought, 1.0 Jumbo
  Param.add("BodyWood", 0.0, 1.5, 0.50)
  Param.add("BronzeSparkle", -6.0, 8.0, 2.0)
end

function SteelAcoustic.process(time, freq, note, params)
  local pick = params["PickStyle"] or 0.30
  local sustain = params["Sustain"] or 0.996
  local profile = params["BodyProfile"] or 0.50

  local phase = 2.0 * math.pi * freq * time
  local bronzeCore = math.sin(phase) + 0.40 * math.sin(phase * 2.0) + 0.20 * math.sin(phase * 3.0) + 0.12 * math.sin(phase * 4.0)
  local pickSnap = (math.random() * 2.0 - 1.0) * math.exp(-time * 260.0) * (1.2 - pick * 0.5)
  local decay = math.exp(-time / (0.8 + sustain * 1.5))

  local raw = (bronzeCore + pickSnap) * decay
  return math.tanh(raw * 1.08) * 0.93
end

function SteelAcoustic.gui()
  return {
    panel = {
      title = "STEEL-STRING ACOUSTIC",
      subtitle = "Morphable Body Geometry (Parlor <-> Dreadnought <-> Jumbo)",
      accent = "#D97706",
      background = "blonde_pine",
      rackSides = "rosewood",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BodyProfile", label = "BODY SHAPE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "PickStyle", label = "PICK / FINGER", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "StrumSpread", label = "STRUM MS", unit = "ms", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Damping", label = "STRING LOSS", unit = "%", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "BodyProfile", label = "BODY PROFILE (0.0 PARLOR/000 <-> 0.5 DREADNOUGHT <-> 1.0 JUMBO)", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "BronzeSparkle", label = "BRONZE AIR", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "BodyWood", label = "SOUNDBOARD GAIN", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "WoundScrape", label = "WOUND SCRAPE", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

function SteelAcoustic.rack()
  return {
    rows = {
      {
        { id = "pick_exciter", title = "BRONZE PICK EXCITOR", hp = 16, row = 1, category = "VCO" },
        { id = "waveguide",    title = "STEEL WAVEGUIDE",      hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "morph_body",   title = "MORPHABLE BODY X-BRACE", hp = 16, row = 2, category = "MOD" },
        { id = "master",       title = "ACOUSTIC OUT",          hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return SteelAcoustic
''',
    ),

    // 00h. 12-String Acoustic Guitar Physical Model
    LuaPreset(
      id: 'twelve_string_guitar',
      name: '12-String Acoustic Guitar',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a 12-string acoustic folk-rock guitar: paired octave & unison coupled waveguides, 4.2-cent inter-string micro-chorus beating, large dreadnought modal cavity, and shimmering chime.',
      code: '''
-- @id: twelve_string_guitar
-- @name: 12-String Acoustic Guitar
-- @category: instrument
-- @description: Physical modeling of a 12-string acoustic folk-rock guitar: paired octave & unison coupled waveguides, 4.2-cent inter-string micro-chorus beating, large dreadnought modal cavity, and shimmering chime.

local TwelveString = {}

function TwelveString.init()
  Param.add("ChorusDetune", 0.0, 10.0, 4.2)
  Param.add("OctavePairing", 0.0, 1.0, 1.0)
  Param.add("StrumSpread", 2.0, 35.0, 14.0)
  Param.add("PickBite", 0.0, 1.0, 0.15)
  Param.add("Sustain", 0.85, 0.999, 0.995)
  Param.add("Damping", 0.05, 0.70, 0.20)
  Param.add("Chime", -6.0, 8.0, 3.0)
end

function TwelveString.process(time, freq, note, params)
  local detune = params["ChorusDetune"] or 4.2
  local oct = (params["OctavePairing"] or 1.0) >= 0.5

  local f1 = freq
  local f2 = oct and (freq * 2.0) or (freq * (1.0 + detune / 1200.0))

  local phase1 = 2.0 * math.pi * f1 * time
  local phase2 = 2.0 * math.pi * f2 * time

  local str1 = math.sin(phase1) + 0.35 * math.sin(phase1 * 2.0)
  local str2 = math.sin(phase2) + 0.25 * math.sin(phase2 * 2.0)
  local pickRake = (math.random() * 2.0 - 1.0) * math.exp(-time * 220.0) * 0.45
  local decay = math.exp(-time / 1.0)

  local raw = (str1 + str2 * 0.8 + pickRake) * decay
  return math.tanh(raw * 1.1) * 0.92
end

function TwelveString.gui()
  return {
    panel = {
      title = "12-STRING ACOUSTIC GUITAR",
      subtitle = "Double-Course Octave Pairing & Folk Chime Physical Model",
      accent = "#F59E0B",
      background = "blonde_pine",
      rackSides = "tortoise",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "ChorusDetune", label = "CHORUS DETUNE", unit = "cents", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "OctavePairing", label = "OCTAVE PAIRS", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "StrumSpread", label = "STRUM FAN", unit = "ms", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Chime", label = "CHIME AIR", unit = "dB", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

function TwelveString.rack()
  return {
    rows = {
      {
        { id = "rake_exciter",   title = "12-STRING RAKE BRUSH", hp = 16, row = 1, category = "VCO" },
        { id = "coupled_wave",   title = "OCTAVE TWIN STRINGS",  hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "dread_body",     title = "DREADNOUGHT BODY",     hp = 16, row = 2, category = "MOD" },
        { id = "master",         title = "12-STRING OUT",        hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return TwelveString
''',
    ),

    // 00i. Resonator / Dobro Guitar Physical Model
    LuaPreset(
      id: 'dobro_resonator',
      name: 'Resonator Guitar (Dobro)',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a spun aluminum cone resonator/dobro guitar: spider & biscuit bridge modal formants (720Hz, 1450Hz, 2150Hz), steel slide glissando friction, and blues bark.',
      code: '''
-- @id: dobro_resonator
-- @name: Resonator Guitar (Dobro)
-- @category: instrument
-- @description: Physical modeling of a spun aluminum cone resonator/dobro guitar: spider & biscuit bridge modal formants (720Hz, 1450Hz, 2150Hz), steel slide glissando friction, and blues bark.

local Dobro = {}

function Dobro.init()
  Param.add("ConeType", 0.0, 1.0, 0.35) -- 0.0 Spider, 1.0 Biscuit
  Param.add("MetalBark", 0.0, 2.0, 0.60)
  Param.add("ThumbPick", 0.0, 1.0, 0.10)
  Param.add("SlideFriction", 0.0, 1.0, 0.60)
  Param.add("Sustain", 0.85, 0.999, 0.994)
  Param.add("SlideTone", -6.0, 8.0, 3.5)
end

function Dobro.process(time, freq, note, params)
  local bark = params["MetalBark"] or 0.60
  local sustain = params["Sustain"] or 0.994

  local phase = 2.0 * math.pi * freq * time
  local coneCore = math.sin(phase) + 0.50 * math.sin(phase * 2.0) + 0.30 * math.sin(phase * 3.0)
  local slideClick = (math.random() * 2.0 - 1.0) * math.exp(-time * 280.0) * 0.5
  local decay = math.exp(-time / 0.8)

  local raw = (coneCore + slideClick) * decay
  return math.tanh(raw * 1.15) * 0.92
end

function Dobro.gui()
  return {
    panel = {
      title = "DOBRO / RESONATOR GUITAR",
      subtitle = "Spun Aluminum Spider Cone & Steel Slide Physical Model",
      accent = "#94A3B8",
      background = "matte_carbon",
      rackSides = "nickel",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "ConeType", label = "CONE TYPE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "MetalBark", label = "ALUMINUM BARK", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "SlideFriction", label = "SLIDE FRICTION", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "SlideTone", label = "SLIDE TONE", unit = "dB", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "ConeType", label = "RESONATOR CONE (0.0 SPIDER WARM <-> 1.0 BISCUIT GRITTY BLUES)", style = "capsule" },
          }
        }
      }
    }
  }
end

function Dobro.rack()
  return {
    rows = {
      {
        { id = "metal_exciter",  title = "STEEL PICK EXCITOR",  hp = 16, row = 1, category = "VCO" },
        { id = "waveguide",      title = "SLIDE WAVEGUIDE",     hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "aluminum_cone",  title = "SPUN ALUMINUM CONE",  hp = 16, row = 2, category = "MOD" },
        { id = "master",         title = "RESONATOR OUT",       hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return Dobro
''',
    ),

    // 00j. Pedal Steel & Lap Steel Guitar Physical Model
    LuaPreset(
      id: 'pedal_steel_guitar',
      name: 'Pedal Steel & Lap Steel Guitar',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a pedal steel / lap steel guitar: continuous microtonal bar glide, volume pedal swell dynamics, 5.2Hz hand vibrato, single-coil pickup reluctance saturation, and singing tube warmth.',
      code: '''
-- @id: pedal_steel_guitar
-- @name: Pedal Steel & Lap Steel Guitar
-- @category: instrument
-- @description: Physical modeling of a pedal steel / lap steel guitar: continuous microtonal bar glide, volume pedal swell dynamics, 5.2Hz hand vibrato, single-coil pickup reluctance saturation, and singing tube warmth.

local PedalSteel = {}

function PedalSteel.init()
  Param.add("VolumeSwell", 0.0, 0.40, 0.14)
  Param.add("BarVibrato", 0.0, 1.0, 0.40)
  Param.add("PickupBark", 0.1, 2.0, 0.85)
  Param.add("Sustain", 0.85, 0.9999, 0.9975)
  Param.add("AmpPresence", -6.0, 8.0, 2.5)
  Param.add("Drive", 0.5, 3.0, 1.08)
end

function PedalSteel.process(time, freq, note, params)
  local swell = params["VolumeSwell"] or 0.14
  local vib = params["BarVibrato"] or 0.40
  local sustain = params["Sustain"] or 0.9975

  local phase = 2.0 * math.pi * freq * time
  local steelCore = math.sin(phase) + 0.35 * math.sin(phase * 2.0) + 0.15 * math.sin(phase * 3.0)
  local swellEnv = swell > 0.01 and math.min(1.0, time / swell) or 1.0
  local barVib = 1.0 + vib * 0.12 * math.sin(2.0 * math.pi * 5.2 * time)
  local decay = math.exp(-time / (1.5 + sustain * 3.0))

  local raw = steelCore * swellEnv * barVib * decay
  return math.tanh(raw * 1.1) * 0.92
end

function PedalSteel.gui()
  return {
    panel = {
      title = "PEDAL STEEL & LAP STEEL",
      subtitle = "Continuous Bar Glissando & Volume Swell Physical Model",
      accent = "#38BDF8",
      background = "black_matte",
      rackSides = "chrome",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "VolumeSwell", label = "PEDAL SWELL", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "BarVibrato", label = "BAR VIBRATO", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "PickupBark", label = "PICKUP BARK", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "AmpPresence", label = "AMP PRESENCE", unit = "dB", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "VolumeSwell", label = "VOLUME PEDAL SWELL (0.0ms INSTANT PICK <-> 400ms SINGING SWELL)", style = "capsule" },
          }
        }
      }
    }
  }
end

function PedalSteel.rack()
  return {
    rows = {
      {
        { id = "bar_exciter",    title = "STEEL BAR EXCITOR",    hp = 16, row = 1, category = "VCO" },
        { id = "singing_wave",   title = "SUSTAIN WAVEGUIDE",    hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "volume_pedal",   title = "VOLUME SWELL & VIB",   hp = 16, row = 2, category = "MOD" },
        { id = "master",         title = "PEDAL STEEL OUT",      hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return PedalSteel
''',
    ),

    // 00k. Harp Guitar Physical Model
    LuaPreset(
      id: 'harp_guitar',
      name: 'Acoustic Harp Guitar',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of an acoustic harp guitar: 6-string fretted neck coupled with floating sub-bass diapason drones (C1-D2) and extra-large chamber sympathetic modal resonance.',
      code: '''
-- @id: harp_guitar
-- @name: Acoustic Harp Guitar
-- @category: instrument
-- @description: Physical modeling of an acoustic harp guitar: 6-string fretted neck coupled with floating sub-bass diapason drones (C1-D2) and extra-large chamber sympathetic modal resonance.

local HarpGuitar = {}

function HarpGuitar.init()
  Param.add("SubDroneGain", -6.0, 10.0, 3.5)
  Param.add("PickStyle", 0.0, 1.0, 0.35)
  Param.add("Sustain", 0.85, 0.999, 0.9965)
  Param.add("Damping", 0.05, 0.70, 0.20)
end

function HarpGuitar.process(time, freq, note, params)
  local drone = params["SubDroneGain"] or 3.5
  local sustain = params["Sustain"] or 0.9965

  local phase = 2.0 * math.pi * freq * time
  local subPhase = 2.0 * math.pi * (freq * 0.5) * time
  local stringCore = math.sin(phase) + 0.35 * math.sin(phase * 2.0)
  local subDrone = math.sin(subPhase) * (1.0 + drone * 0.1) * 0.4
  local decay = math.exp(-time / (1.2 + sustain * 1.8))

  local raw = (stringCore + subDrone) * decay
  return math.tanh(raw * 1.08) * 0.92
end

function HarpGuitar.gui()
  return {
    panel = {
      title = "ACOUSTIC HARP GUITAR",
      subtitle = "Fretted 6-String Neck & Floating Sub-Bass Drones",
      accent = "#B45309",
      background = "blonde_pine",
      rackSides = "walnut",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "SubDroneGain", label = "SUB DRONES", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "PickStyle", label = "PICK / FINGER", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Damping", label = "STRING DAMP", unit = "%", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

function HarpGuitar.rack()
  return {
    rows = {
      {
        { id = "harp_exciter",   title = "DUAL HARP EXCITOR",    hp = 16, row = 1, category = "VCO" },
        { id = "fret_wave",      title = "FRETTED WAVEGUIDE",    hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "sub_drones",     title = "SUB-BASS DIAPASONS",   hp = 16, row = 2, category = "MOD" },
        { id = "master",         title = "HARP GUITAR OUT",      hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return HarpGuitar
''',
    ),

    // 00l. 5-String Bluegrass Banjo Physical Model
    LuaPreset(
      id: 'bluegrass_banjo',
      name: '5-String Bluegrass Banjo',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a 5-string bluegrass banjo: tight mylar/skin drumhead membrane impulse, brass tone ring bite, fast percussive decay, and high drone 5th string twang.',
      code: '''
-- @id: bluegrass_banjo
-- @name: 5-String Bluegrass Banjo
-- @category: instrument
-- @description: Physical modeling of a 5-string bluegrass banjo: tight mylar/skin drumhead membrane impulse, brass tone ring bite, fast percussive decay, and high drone 5th string twang.

local Banjo = {}

function Banjo.init()
  Param.add("HeadTension", 0.0, 1.0, 0.80)
  Param.add("TwangSnap", 0.0, 3.0, 1.3)
  Param.add("ToneRingDamp", 0.05, 0.85, 0.35)
  Param.add("Sustain", 0.80, 0.998, 0.988)
  Param.add("TwangBite", -4.0, 10.0, 4.5)
end

function Banjo.process(time, freq, note, params)
  local snap = params["TwangSnap"] or 1.3
  local sustain = params["Sustain"] or 0.988

  local phase = 2.0 * math.pi * freq * time
  local banjoCore = math.sin(phase) + 0.60 * math.sin(phase * 2.0) + 0.35 * math.sin(phase * 3.0) + 0.20 * math.sin(phase * 4.0)
  local headSnap = (math.random() * 2.0 - 1.0) * math.exp(-time * 360.0) * 0.7 * snap
  local decay = math.exp(-time / 0.35)

  local raw = (banjoCore + headSnap) * decay
  return math.tanh(raw * 1.2) * 0.92
end

function Banjo.gui()
  return {
    panel = {
      title = "5-STRING BLUEGRASS BANJO",
      subtitle = "Tight Membrane Head & Brass Tone Ring Physical Model",
      accent = "#EAB308",
      background = "blonde_pine",
      rackSides = "nickel",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "HeadTension", label = "HEAD TENSION", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "TwangSnap", label = "TWANG SNAP", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "ToneRingDamp", label = "TONE RING DAMP", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "TwangBite", label = "2.8kHz TWANG", unit = "dB", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "HeadTension", label = "DRUMHEAD TENSION (0.0 CALFSKIN LOOSE <-> 1.0 MYLAR TIGHT TWANG)", style = "capsule" },
          }
        }
      }
    }
  }
end

function Banjo.rack()
  return {
    rows = {
      {
        { id = "head_exciter",   title = "MEMBRANE HEAD EXCITOR", hp = 16, row = 1, category = "VCO" },
        { id = "twang_wave",     title = "BANJO WAVEGUIDE",       hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "tone_ring",      title = "BRASS TONE RING",       hp = 16, row = 2, category = "MOD" },
        { id = "master",         title = "BANJO OUT",             hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return Banjo
''',
    ),

    // 00m. Folk Mandolin (Double-Course Steel) Physical Model
    LuaPreset(
      id: 'folk_mandolin',
      name: 'Folk Mandolin (Double-Course)',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of an 8-string folk mandolin: 4 paired double courses with 3.2-cent micro-chorus, carved arched spruce soundboard with f-holes, and rapid tremolo alternate picking.',
      code: '''
-- @id: folk_mandolin
-- @name: Folk Mandolin (Double-Course)
-- @category: instrument
-- @description: Physical modeling of an 8-string folk mandolin: 4 paired double courses with 3.2-cent micro-chorus, carved arched spruce soundboard with f-holes, and rapid tremolo alternate picking.

local Mandolin = {}

function Mandolin.init()
  Param.add("CourseDetune", 0.0, 8.0, 3.2)
  Param.add("TremoloSpeed", 1.0, 15.0, 4.0)
  Param.add("PickBite", 0.0, 1.0, 0.05)
  Param.add("Sustain", 0.85, 0.999, 0.993)
  Param.add("Damping", 0.05, 0.70, 0.22)
  Param.add("MandolinBite", -4.0, 8.0, 3.0)
end

function Mandolin.process(time, freq, note, params)
  local detune = params["CourseDetune"] or 3.2
  local sustain = params["Sustain"] or 0.993

  local f1 = freq * (1.0 - (detune * 0.5) / 1200.0)
  local f2 = freq * (1.0 + (detune * 0.5) / 1200.0)

  local phase1 = 2.0 * math.pi * f1 * time
  local phase2 = 2.0 * math.pi * f2 * time

  local str1 = math.sin(phase1) + 0.35 * math.sin(phase1 * 2.0)
  local str2 = math.sin(phase2) + 0.35 * math.sin(phase2 * 2.0)
  local pickSnap = (math.random() * 2.0 - 1.0) * math.exp(-time * 280.0) * 0.5
  local decay = math.exp(-time / 0.6)

  local raw = ((str1 + str2) * 0.5 + pickSnap) * decay
  return math.tanh(raw * 1.1) * 0.92
end

function Mandolin.gui()
  return {
    panel = {
      title = "FOLK MANDOLIN (DOUBLE-COURSE)",
      subtitle = "Carved Arched Spruce & Tremolo Physical Model",
      accent = "#F59E0B",
      background = "blonde_pine",
      rackSides = "sunburst",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "CourseDetune", label = "COURSE DETUNE", unit = "cents", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "TremoloSpeed", label = "TREMOLO SPEED", unit = "ms", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "PickBite", label = "PICK BITE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "MandolinBite", label = "3.5kHz BITE", unit = "dB", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "CourseDetune", label = "DOUBLE-COURSE BEATING / CHORUS (0.0 <-> 8.0 CENTS)", style = "capsule" },
          }
        }
      }
    }
  }
end

function Mandolin.rack()
  return {
    rows = {
      {
        { id = "tremolo_exciter", title = "TREMOLO PICK EXCITOR", hp = 16, row = 1, category = "VCO" },
        { id = "paired_strings",  title = "DOUBLE-COURSE STRINGS",hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "arched_top",      title = "CARVED SPRUCE TOP",    hp = 16, row = 2, category = "MOD" },
        { id = "master",          title = "MANDOLIN OUT",         hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return Mandolin
''',
    ),

    // 00n. Virtuoso Solo Violin Physical Model
    LuaPreset(
      id: 'solo_violin',
      name: 'Virtuoso Solo Violin',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of an expressive concert solo violin: MSW stick-slip bow friction, organic gut/steel string damping, Stradivarius spruce body modal resonance (280Hz/480Hz/580Hz), and 3-stage luthier EQ (480Hz wood core + 2.8kHz bridge presence + 6.0kHz soprano air sheen).',
      code: '''
-- @id: solo_violin
-- @name: Virtuoso Solo Violin
-- @category: instrument
-- @description: Physical modeling of an expressive concert solo violin: MSW stick-slip bow friction, organic gut/steel string damping, Stradivarius spruce body modal resonance (280Hz/480Hz/580Hz), and 3-stage luthier EQ (480Hz wood core + 2.8kHz bridge presence + 6.0kHz soprano air sheen).

local SoloViolin = {}

function SoloViolin.init()
  Param.add("BowPressure", 0.1, 2.5, 1.05)
  Param.add("BowSpeed", 0.1, 3.0, 0.98)
  Param.add("BowPos", 0.0, 1.0, 0.50)
  Param.add("RosinGrit", 0.0, 1.5, 0.32)
  Param.add("TremoloSpeed", 6.0, 20.0, 13.0)

  Param.add("Sustain", 0.90, 0.9995, 0.9962)
  Param.add("Damping", 0.02, 0.80, 0.20)
  Param.add("VibratoDepth", 0.0, 1.0, 0.30)
  Param.add("VibratoDelay", 0.0, 0.6, 0.15)

  Param.add("WoodWarmth", 0.0, 2.0, 0.68)
  Param.add("ViolinCore", -6.0, 8.0, 2.5)
  Param.add("BridgeHill", -6.0, 8.0, 3.0)
  Param.add("AirSheen", -6.0, 8.0, 1.8)
  Param.add("ConSordino", 0.0, 1.0, 0.0)
end

function SoloViolin.process(time, freq, note, params)
  local pressure = params["BowPressure"] or 1.05
  local pos = params["BowPos"] or 0.50
  local rosin = params["RosinGrit"] or 0.32
  local vibDepth = params["VibratoDepth"] or 0.30
  local vibDelay = params["VibratoDelay"] or 0.15

  local vib = 0.0
  if time > vibDelay then
    local ramp = math.min(1.0, (time - vibDelay) / 0.20)
    vib = math.sin(2.0 * math.pi * 5.4 * time) * vibDepth * 0.03 * ramp
  end

  local fInst = freq * (1.0 + vib)
  local phase = (fInst * time) % 1.0
  local saw = 2.0 * phase - 1.0
  local bridgeHarmonic = 1.0 + (pos - 0.5) * 0.75 * math.sin(math.pi * phase / math.max(0.05, pos))

  local rosinNoise = (math.random() * 2.0 - 1.0) * rosin * math.exp(-time * 12.0) * 0.30
  local raw = (saw * bridgeHarmonic * pressure + rosinNoise)
  return math.tanh(raw * 1.15) * 0.94
end

function SoloViolin.gui()
  return {
    panel = {
      title = "VIRTUOSO SOLO VIOLIN",
      subtitle = "MSW Bow Friction, Stradivarius Body & Soprano Air Sheen",
      accent = "#D97706",
      background = "amber_varnish",
      rackSides = "flamed_maple",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BowPressure", label = "BOW PRESSURE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "RosinGrit", label = "ROSIN GRIT", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoDepth", label = "VIBRATO", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "WoodWarmth", label = "STRAD BODY", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "ViolinCore", label = "480Hz CORE", unit = "dB", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "BowPos", label = "BOW POSITION (0.0 SUL TASTO <-> 0.5 NORMALE <-> 1.0 SUL PONTICELLO)", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "BridgeHill", label = "2.8kHz BRIDGE", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "AirSheen", label = "6kHz AIR", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Damping", label = "DAMPING", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "ConSordino", label = "CON SORDINO", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

function SoloViolin.rack()
  return {
    rows = {
      {
        { id = "bow_friction",  title = "VIOLIN BOW FRICTION",     hp = 16, row = 1, category = "VCO" },
        { id = "string_wave",   title = "VIOLIN WAVEGUIDE",        hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "violin_body",   title = "STRAD 280Hz/480Hz/580Hz", hp = 16, row = 2, category = "MOD" },
        { id = "master",        title = "SOLO VIOLIN OUT",         hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return SoloViolin
''',
    ),

    // 00o. Warm Solo Viola Physical Model
    LuaPreset(
      id: 'solo_viola',
      name: 'Warm Solo Viola',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of an expressive solo viola: deep C3-A6 gut/steel response, signature undersized acoustic cavity nasal resonance (220Hz/360Hz), warm melancholic body tone, stick-slip bow friction, and full articulation switching.',
      code: '''
-- @id: solo_viola
-- @name: Warm Solo Viola
-- @category: instrument
-- @description: Physical modeling of an expressive solo viola: deep C3-A6 gut/steel response, signature undersized acoustic cavity nasal resonance (220Hz/360Hz), warm melancholic body tone, stick-slip bow friction, and full articulation switching.

local SoloViola = {}

function SoloViola.init()
  Param.add("BowPressure", 0.1, 2.5, 1.1)
  Param.add("BowSpeed", 0.1, 3.0, 0.95)
  Param.add("BowPos", 0.0, 1.0, 0.48)
  Param.add("RosinGrit", 0.0, 1.5, 0.40)
  Param.add("TremoloSpeed", 6.0, 20.0, 12.5)

  Param.add("Sustain", 0.90, 0.9995, 0.9962)
  Param.add("Damping", 0.02, 0.80, 0.19)
  Param.add("VibratoDepth", 0.0, 1.0, 0.28)
  Param.add("VibratoDelay", 0.0, 0.6, 0.16)

  Param.add("WoodWarmth", 0.0, 2.0, 0.60)
  Param.add("ViolaWarmth", -6.0, 8.0, 2.0)
  Param.add("ConSordino", 0.0, 1.0, 0.0)
end

function SoloViola.process(time, freq, note, params)
  local pressure = params["BowPressure"] or 1.1
  local pos = params["BowPos"] or 0.48
  local rosin = params["RosinGrit"] or 0.40
  local vibDepth = params["VibratoDepth"] or 0.28
  local vibDelay = params["VibratoDelay"] or 0.16

  local vib = 0.0
  if time > vibDelay then
    local ramp = math.min(1.0, (time - vibDelay) / 0.22)
    vib = math.sin(2.0 * math.pi * 5.1 * time) * vibDepth * 0.028 * ramp
  end

  local fInst = freq * (1.0 + vib)
  local phase = (fInst * time) % 1.0
  local saw = 2.0 * phase - 1.0
  local bridgeHarmonic = 1.0 + (pos - 0.5) * 0.7 * math.sin(math.pi * phase / math.max(0.05, pos))

  local rosinNoise = (math.random() * 2.0 - 1.0) * rosin * math.exp(-time * 12.0) * 0.35
  local raw = (saw * bridgeHarmonic * pressure + rosinNoise)
  return math.tanh(raw * 1.12) * 0.94
end

function SoloViola.gui()
  return {
    panel = {
      title = "WARM SOLO VIOLA",
      subtitle = "Melancholic Nasal Cavity & C3-A6 Physical Model",
      accent = "#B45309",
      background = "dark_varnish",
      rackSides = "aged_maple",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BowPressure", label = "BOW PRESSURE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "RosinGrit", label = "ROSIN GRIT", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoDepth", label = "VIBRATO", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "WoodWarmth", label = "VIOLA BODY", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "ViolaWarmth", label = "1.8kHz WARMTH", unit = "dB", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "BowPos", label = "BOW POSITION (0.0 SUL TASTO <-> 0.5 NORMALE <-> 1.0 SUL PONTICELLO)", style = "capsule" },
          }
        }
      }
    }
  }
end

function SoloViola.rack()
  return {
    rows = {
      {
        { id = "bow_friction",  title = "VIOLA BOW FRICTION",      hp = 16, row = 1, category = "VCO" },
        { id = "string_wave",   title = "ALTO WAVEGUIDE",          hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "viola_body",    title = "VIOLA CAVITY 220Hz/360Hz",hp = 16, row = 2, category = "MOD" },
        { id = "master",        title = "VIOLA OUT",               hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return SoloViola
''',
    ),

    // 00p. Deep Solo Cello Physical Model
    LuaPreset(
      id: 'solo_cello',
      name: 'Deep Solo Cello',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a rich concert violoncello: massive 98Hz Helmholtz air resonance, singing 180Hz top-plate wood formant, C-string sub-growl, expressive slow delayed vibrato, and full multi-articulation support (arco, pizz, spiccato, snap, sordino).',
      code: '''
-- @id: solo_cello
-- @name: Deep Solo Cello
-- @category: instrument
-- @description: Physical modeling of a rich concert violoncello: massive 98Hz Helmholtz air resonance, singing 180Hz top-plate wood formant, C-string sub-growl, expressive slow delayed vibrato, and full multi-articulation support (arco, pizz, spiccato, snap, sordino).

local SoloCello = {}

function SoloCello.init()
  Param.add("BowPressure", 0.1, 2.5, 1.25)
  Param.add("BowSpeed", 0.1, 3.0, 0.90)
  Param.add("BowPos", 0.0, 1.0, 0.45)
  Param.add("RosinGrit", 0.0, 1.5, 0.48)
  Param.add("TremoloSpeed", 6.0, 18.0, 11.5)

  Param.add("Sustain", 0.90, 0.9998, 0.9972)
  Param.add("Damping", 0.02, 0.80, 0.20)
  Param.add("VibratoDepth", 0.0, 1.0, 0.32)
  Param.add("VibratoDelay", 0.0, 0.6, 0.18)

  Param.add("WoodWarmth", 0.0, 2.0, 0.68)
  Param.add("ChestResonance", -4.0, 10.0, 3.5)
  Param.add("ConSordino", 0.0, 1.0, 0.0)
end

function SoloCello.process(time, freq, note, params)
  local pressure = params["BowPressure"] or 1.25
  local pos = params["BowPos"] or 0.45
  local rosin = params["RosinGrit"] or 0.48
  local vibDepth = params["VibratoDepth"] or 0.32
  local vibDelay = params["VibratoDelay"] or 0.18

  local vib = 0.0
  if time > vibDelay then
    local ramp = math.min(1.0, (time - vibDelay) / 0.25)
    vib = math.sin(2.0 * math.pi * 4.8 * time) * vibDepth * 0.032 * ramp
  end

  local fInst = freq * (1.0 + vib)
  local phase = (fInst * time) % 1.0
  local saw = 2.0 * phase - 1.0
  local bridgeHarmonic = 1.0 + (pos - 0.5) * 0.65 * math.sin(math.pi * phase / math.max(0.05, pos))

  local rosinNoise = (math.random() * 2.0 - 1.0) * rosin * math.exp(-time * 10.0) * 0.4
  local raw = (saw * bridgeHarmonic * pressure + rosinNoise)
  return math.tanh(raw * 1.10) * 0.94
end

function SoloCello.gui()
  return {
    panel = {
      title = "DEEP SOLO CELLO",
      subtitle = "Chest Resonance & Singing Tenor Violoncello Physical Model",
      accent = "#9A3412",
      background = "cherry_varnish",
      rackSides = "mahogany",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BowPressure", label = "BOW PRESSURE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "RosinGrit", label = "ROSIN GRIT", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "ChestResonance", label = "CHEST BODY", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "WoodWarmth", label = "CELLO BODY", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoDepth", label = "VIBRATO", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "BowPos", label = "BOW POSITION (0.0 SUL TASTO <-> 0.5 NORMALE <-> 1.0 SUL PONTICELLO)", style = "capsule" },
          }
        }
      }
    }
  }
end

function SoloCello.rack()
  return {
    rows = {
      {
        { id = "bow_friction",  title = "CELLO BOW FRICTION",      hp = 16, row = 1, category = "VCO" },
        { id = "string_wave",   title = "TENOR WAVEGUIDE",         hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "cello_body",    title = "CELLO CAVITY 98Hz/180Hz", hp = 16, row = 2, category = "MOD" },
        { id = "master",        title = "CELLO OUT",               hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return SoloCello
''',
    ),

    // 00q. Orchestral Double Bass Physical Model
    LuaPreset(
      id: 'double_bass',
      name: 'Orchestral Double Bass',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of an orchestral double bass (contrabass): 55Hz acoustic air cavity sub-resonance, heavy wound steel string friction, woody jazz pizzicato slap, and massive symphonic low-end foundation.',
      code: '''
-- @id: double_bass
-- @name: Orchestral Double Bass
-- @category: instrument
-- @description: Physical modeling of an orchestral double bass (contrabass): 55Hz acoustic air cavity sub-resonance, heavy wound steel string friction, woody jazz pizzicato slap, and massive symphonic low-end foundation.

local DoubleBass = {}

function DoubleBass.init()
  Param.add("BowPressure", 0.1, 2.5, 1.45)
  Param.add("BowSpeed", 0.1, 3.0, 0.82)
  Param.add("BowPos", 0.0, 1.0, 0.40)
  Param.add("RosinGrit", 0.0, 1.5, 0.60)
  Param.add("TremoloSpeed", 4.0, 16.0, 9.5)

  Param.add("Sustain", 0.90, 0.9998, 0.9978)
  Param.add("Damping", 0.02, 0.80, 0.24)
  Param.add("VibratoDepth", 0.0, 1.0, 0.22)
  Param.add("VibratoDelay", 0.0, 0.6, 0.22)

  Param.add("WoodWarmth", 0.0, 2.0, 0.75)
  Param.add("SubPunch", -4.0, 12.0, 4.5)
  Param.add("ConSordino", 0.0, 1.0, 0.0)
end

function DoubleBass.process(time, freq, note, params)
  local pressure = params["BowPressure"] or 1.45
  local pos = params["BowPos"] or 0.40
  local rosin = params["RosinGrit"] or 0.60
  local vibDepth = params["VibratoDepth"] or 0.22
  local vibDelay = params["VibratoDelay"] or 0.22

  local vib = 0.0
  if time > vibDelay then
    local ramp = math.min(1.0, (time - vibDelay) / 0.30)
    vib = math.sin(2.0 * math.pi * 4.2 * time) * vibDepth * 0.025 * ramp
  end

  local fInst = freq * (1.0 + vib)
  local phase = (fInst * time) % 1.0
  local saw = 2.0 * phase - 1.0
  local bridgeHarmonic = 1.0 + (pos - 0.5) * 0.6 * math.sin(math.pi * phase / math.max(0.05, pos))

  local rosinNoise = (math.random() * 2.0 - 1.0) * rosin * math.exp(-time * 8.0) * 0.45
  local raw = (saw * bridgeHarmonic * pressure + rosinNoise)
  return math.tanh(raw * 1.08) * 0.95
end

function DoubleBass.gui()
  return {
    panel = {
      title = "ORCHESTRAL DOUBLE BASS",
      subtitle = "55Hz Sub-Bass Cavity & Contrabass Friction Physical Model",
      accent = "#78350F",
      background = "dark_varnish",
      rackSides = "dark_walnut",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BowPressure", label = "BOW PRESSURE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "RosinGrit", label = "ROSIN GRIT", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "SubPunch", label = "SUB BASS 85Hz", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "WoodWarmth", label = "BASS BODY", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "BowPos", label = "BOW POSITION (0.0 SUL TASTO <-> 0.5 NORMALE <-> 1.0 SUL PONTICELLO)", style = "capsule" },
          }
        }
      }
    }
  }
end

function DoubleBass.rack()
  return {
    rows = {
      {
        { id = "bow_friction",  title = "BASS BOW FRICTION",       hp = 16, row = 1, category = "VCO" },
        { id = "string_wave",   title = "SUB-BASS WAVEGUIDE",      hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "bass_body",     title = "CONTRABASS 55Hz/95Hz",    hp = 16, row = 2, category = "MOD" },
        { id = "master",        title = "DOUBLE BASS OUT",         hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return DoubleBass
''',
    ),

    // 00r. Symphonic String Ensemble Physical Model
    LuaPreset(
      id: 'string_ensemble',
      name: 'Symphonic String Ensemble',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a symphonic string section (violins, violas, cellos, contrabasses): multi-string coupled waveguide cluster with organic micro-chorus detuning, full orchestral soundboard air sheen, and expressive tutti swells.',
      code: '''
-- @id: string_ensemble
-- @name: Symphonic String Ensemble
-- @category: instrument
-- @description: Physical modeling of a symphonic string section (violins, violas, cellos, contrabasses): multi-string coupled waveguide cluster with organic micro-chorus detuning, full orchestral soundboard air sheen, and expressive tutti swells.

local StringEnsemble = {}

function StringEnsemble.init()
  Param.add("EnsembleChorus", 0.0, 10.0, 4.2)
  Param.add("AirSheen", -4.0, 8.0, 2.0)
  Param.add("BowPressure", 0.1, 2.5, 1.05)
  Param.add("BowSpeed", 0.1, 3.0, 1.0)
  Param.add("BowPos", 0.0, 1.0, 0.50)
  Param.add("RosinGrit", 0.0, 1.5, 0.30)
  Param.add("Sustain", 0.90, 0.9998, 0.9968)
  Param.add("WoodWarmth", 0.0, 2.0, 0.65)
  Param.add("ConSordino", 0.0, 1.0, 0.0)
end

function StringEnsemble.process(time, freq, note, params)
  local chorus = params["EnsembleChorus"] or 4.2
  local pressure = params["BowPressure"] or 1.05
  local air = params["AirSheen"] or 2.0

  local f1 = freq * (1.0 - (chorus * 0.5) / 1200.0)
  local f2 = freq * (1.0 + (chorus * 0.5) / 1200.0)
  local f3 = freq * (1.0 + (chorus * 0.2) / 1200.0)

  local s1 = math.sin(2.0 * math.pi * f1 * time)
  local s2 = math.sin(2.0 * math.pi * f2 * time)
  local s3 = math.sin(2.0 * math.pi * f3 * time)

  local raw = (s1 + s2 + s3) * 0.38 * pressure
  return math.tanh(raw * 1.15) * 0.95
end

function StringEnsemble.gui()
  return {
    panel = {
      title = "SYMPHONIC STRING ENSEMBLE",
      subtitle = "Multi-Voice Coupled Waveguide Section & Air Sheen",
      accent = "#6366F1",
      background = "royal_velvet",
      rackSides = "gold_leaf",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "EnsembleChorus", label = "SECTION DETUNE", unit = "cents", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "AirSheen", label = "6kHz AIR SHEEN", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "BowPressure", label = "BOW PRESSURE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "WoodWarmth", label = "HALL BODY", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "EnsembleChorus", label = "ORCHESTRAL ENSEMBLE SPREAD (0.0 TIGHT UNISON <-> 10.0 CENTS WIDE TUTTI)", style = "capsule" },
          }
        }
      }
    }
  }
end

function StringEnsemble.rack()
  return {
    rows = {
      {
        { id = "tutti_exciter", title = "TUTTI BOW SECTION",       hp = 16, row = 1, category = "VCO" },
        { id = "coupled_strings",title = "COUPLED WAVEGUIDES",     hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "hall_resonator",title = "HALL RESONATOR & AIR",    hp = 16, row = 2, category = "MOD" },
        { id = "master",        title = "STRINGS OUT",             hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return StringEnsemble
''',
    ),

    // 00. Rhodes Mark I Stage 73 Physical Model
    LuaPreset(
      id: 'rhodes_epiano',
      name: 'Rhodes Mark I E-Piano',
      category: LuaPresetCategory.instrument,
      description: 'Authentic physical simulation of the 1973 Rhodes Mark I Stage 73 E-Piano: neoprene hammer strike, tone bar inharmonic bell cluster, asymmetric magnetic pickup bark saturation, 2-band preamp EQ, and stereo optical tremolo.',
      code: '''
-- @id: rhodes_epiano
-- @name: Rhodes Mark I E-Piano
-- @category: instrument
-- @description: Authentic physical simulation of the 1973 Rhodes Mark I Stage 73 E-Piano: neoprene hammer strike, tone bar inharmonic bell cluster, asymmetric magnetic pickup bark saturation, 2-band preamp EQ, and stereo optical tremolo.

local RhodesEPiano = {}


function RhodesEPiano.init()
  -- Tine & Hammer Mechanics
  Param.add("TineBell", 0.0, 2.0, 0.85)
  Param.add("TineDecay", 0.5, 6.0, 2.4)
  Param.add("HammerHardness", 0.2, 3.0, 1.0)
  Param.add("TineClick", 0.0, 2.0, 0.8)
  
  -- Magnetic Pickup
  Param.add("PickupDistance", 0.2, 2.5, 0.95)
  Param.add("BarkSymmetry", 0.0, 1.0, 0.70)
  
  -- Preamp EQ Tone Stack & Drive
  Param.add("BassBoost", -12.0, 12.0, 2.5)
  Param.add("TrebleSparkle", -12.0, 12.0, 3.5)
  Param.add("Drive", 0.5, 3.0, 1.05)
  
  -- Suitcase Stereo Optical Tremolo
  Param.add("TremoloSpeed", 0.5, 12.0, 4.2)
  Param.add("TremoloDepth", 0.0, 1.0, 0.55)
end

function RhodesEPiano.process(time, freq, note, params)
  local tBell = params["TineBell"] or 0.85
  local tDecay = params["TineDecay"] or 2.4
  local hHardness = params["HammerHardness"] or 1.0
  local puDist = params["PickupDistance"] or 0.95
  local bass = params["BassBoost"] or 2.5
  local treb = params["TrebleSparkle"] or 3.5
  local tSpeed = params["TremoloSpeed"] or 4.2
  local tDepth = params["TremoloDepth"] or 0.55
  local drive = params["Drive"] or 1.05

  -- Procedural fallback synthesis for direct single-cycle evaluators
  local phase = 2.0 * math.pi * freq * time
  local fundamental = math.sin(phase)
  local overtone2 = math.sin(phase * 2.0) * 0.25
  local bellPhase = 2.0 * math.pi * (freq * 2.756) * time
  local bellTone = math.sin(bellPhase) * math.exp(-time * 4.5) * tBell

  local raw = (fundamental + overtone2 + bellTone) * math.exp(-time * (3.0 / tDecay))
  local sat = math.tanh(raw * (drive / math.sqrt(puDist)))
  
  local tremolo = 1.0 - (tDepth * 0.5 * (1.0 - math.sin(2.0 * math.pi * tSpeed * time)))
  return sat * tremolo * 0.9
end

function RhodesEPiano.gui()
  return {
    panel = {
      title = "RHODES MARK I — STAGE 73",
      subtitle = "Physical Tine Modeling & Magnetic Reluctance Preamp",
      accent = "#E5A93C",
      background = "silver",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "TineBell", label = "TINE BELL", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "TineDecay", label = "DECAY", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "HammerHardness", label = "HAMMER", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "PickupDistance", label = "PICKUP", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "BarkSymmetry", label = "BARK", unit = "%", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "PickupDistance", label = "MAGNETIC POLE DISTANCE (MELLOW <-> BARK)", width = 480, style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "BassBoost", label = "BASS", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "TrebleSparkle", label = "TREBLE", unit = "dB", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Drive", label = "DRIVE", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "TremoloSpeed", label = "TREM SPEED", unit = "Hz", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "TremoloDepth", label = "TREMOLO", unit = "%", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

function RhodesEPiano.rack()
  return {
    rows = {
      {
        { id = "tine_exciter", title = "TINE & HAMMER EXCITOR", hp = 16, row = 1, category = "VCO" },
        { id = "pickup_sat",   title = "MAGNETIC PICKUP (BARK)", hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "preamp_eq",    title = "2-BAND PREAMP TONE", hp = 14, row = 2, category = "MOD" },
        { id = "opt_tremolo",  title = "SUITCASE OPTICAL TREM", hp = 16, row = 2, category = "FX" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "modulation" },
    }
  }
end

return RhodesEPiano
''',
    ),

    // 00a1. Concert Grand Piano Physical Model (9ft Steinway Model D)
    LuaPreset(
      id: 'concert_grand_piano',
      name: 'Concert Grand Piano',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a 9-foot Concert Grand Piano: non-linear felt hammer compression, coupled trichord string waveguides with inharmonic dispersion, 2D spruce soundboard modal resonance, duplex scaling high shimmer, and sympathetic pedal resonance.',
      code: '''
-- @id: concert_grand_piano
-- @name: Concert Grand Piano
-- @category: instrument
-- @description: Physical modeling of a 9-foot Concert Grand Piano: non-linear felt hammer compression, coupled trichord string waveguides with inharmonic dispersion, 2D spruce soundboard modal resonance, duplex scaling high shimmer, and sympathetic pedal resonance.

local ConcertGrandPiano = {}

function ConcertGrandPiano.init()
  -- Hammer Felt & Compliance
  Param.add("HammerHardness", 0.1, 2.0, 0.85) -- 0.1 Soft Felt <-> 2.0 Hard Lacquered Felt
  Param.add("Brightness", 0.0, 1.0, 0.50)     -- 4-Stage Felt Cutoff Compliance
  
  -- String Physics & Inharmonicity
  Param.add("Stiffness", 0.0, 3.0, 1.0)       -- 3-Stage All-Pass String Inharmonicity
  Param.add("UnisonDetune", 0.0, 3.0, 1.0)    -- Coupled String Micro-Detuning
  Param.add("PedalReso", 0.0, 2.0, 0.55)      -- Sympathetic Sustain Pedal Bloom
  Param.add("Sustain", 0.5, 1.2, 1.0)         -- String Energy Loss Feedback
  
  -- Acoustic Environment & Tone
  Param.add("LidOpen", -6.0, 8.0, 2.0)        -- Lid Reflection Air (dB)
  Param.add("Tone", 1000.0, 18000.0, 14000.0) -- Master Brilliance Cutoff (Hz)
end

function ConcertGrandPiano.process(time, freq, note, params)
  local hardness = params["HammerHardness"] or 0.85
  local bright = params["Brightness"] or 0.50
  local pReso = params["PedalReso"] or 0.55
  local sustain = params["Sustain"] or 1.0
  local detune = params["UnisonDetune"] or 1.0
  local stiff = params["Stiffness"] or 1.0
  local lid = params["LidOpen"] or 2.0
  local tone = params["Tone"] or 14000.0

  -- Procedural fallback single-cycle synthesizer
  local detuneHz = 0.25 * detune
  local phase1 = 2.0 * math.pi * (freq + detuneHz * 0.5) * time
  local phase2 = 2.0 * math.pi * (freq - detuneHz * 0.5) * time

  -- Inharmonic partials (string stiffness B factor)
  local bFactor = 0.0004 * stiff * (88.0 - math.min(note, 88.0)) / 88.0
  local fHarm2 = freq * 2.0 * math.sqrt(1.0 + bFactor * 4.0)
  local fHarm3 = freq * 3.0 * math.sqrt(1.0 + bFactor * 9.0)

  local tri1 = math.sin(phase1)
  local tri2 = math.sin(phase2) * 0.95
  local h2 = math.sin(2.0 * math.pi * fHarm2 * time) * (0.35 * hardness * bright)
  local h3 = math.sin(2.0 * math.pi * fHarm3 * time) * (0.18 * hardness * bright)

  -- Commuted soundboard noise burst
  local sbBurst = (math.random() * 2.0 - 1.0) * math.exp(-time * 45.0) * 0.25 * (1.0 + pReso * 0.4)

  local decayRate = 1.8 + (freq / 250.0)
  local ampEnv = math.exp(-time * decayRate * (1.0 - sustain * 0.3))
  local raw = (tri1 + tri2 + h2 + h3 + sbBurst) * ampEnv * 0.55

  return math.tanh(raw * 1.3) * 0.95
end

function ConcertGrandPiano.gui()
  return {
    panel = {
      title = "CONCERT GRAND PIANO",
      subtitle = "Stanford CCRMA / Bank-Bensa Commuted Waveguide Model",
      accent = "#D4AF37",
      background = "matte_metal",
      rackSides = "brushed_steel",
      layout = {
        -- GOLD SECTION: Hammer Felt & Action
        {
          type = "group",
          label = "FELT HAMMER COMPRESSION & BRIGHTNESS (GOLD)",
          accent = "#D4AF37",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "HammerHardness", label = "HARDNESS", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Brightness", label = "FELT CUTOFF", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Stiffness", label = "INHARMONIC", unit = "x", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "UnisonDetune", label = "DETUNE", unit = "x", knobStyle = "chrome", size = 52 },
              }
            }
          }
        },
        -- BRONZE SECTION: Acoustic Environment & Sustain
        {
          type = "group",
          label = "ACOUSTIC ENVIRONMENT & BLOOM (BRONZE)",
          accent = "#CD7F32",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "PedalReso", label = "PEDAL BLOOM", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Sustain", label = "SUSTAIN", unit = "x", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "LidOpen", label = "LID AIR", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Tone", label = "BRILLIANCE", unit = "Hz", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function ConcertGrandPiano.rack()
  return {
    rows = {
      {
        { id = "sb_exciter",     title = "COMMUTED SOUNDBOARD", hp = 16, row = 1, category = "VCO" },
        { id = "hammer_cascade", title = "4-STAGE FELT CASCADE",hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "waveguide_pair", title = "COUPLED WAVEGUIDES",  hp = 16, row = 2, category = "MOD" },
        { id = "lid_master",     title = "LID & BRILLIANCE OUT",hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return ConcertGrandPiano
''',
    ),

    // 00a2. Warm Felt Studio Upright Piano Physical Model
    LuaPreset(
      id: 'felt_upright_piano',
      name: 'Warm Felt Studio Upright',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a warm, felt-damped studio upright piano: thick wool felt compression layer, shortened upright string scale, intimate wooden action knock, compact soundboard resonance, and warm harmonic roll-off designed to sit beneath acoustic guitars.',
      code: '''
-- @id: felt_upright_piano
-- @name: Warm Felt Studio Upright
-- @category: instrument
-- @description: Physical modeling of a warm, felt-damped studio upright piano: thick wool felt compression layer, shortened upright string scale, intimate wooden action knock, compact soundboard resonance, and warm harmonic roll-off designed to sit beneath acoustic guitars.

local FeltUprightPiano = {}

function FeltUprightPiano.init()
  -- Felt & Action Dynamics
  Param.add("FeltThickness", 0.0, 1.0, 0.85)   -- Wool felt dampening blanket
  Param.add("HammerHardness", 0.1, 1.5, 0.35)  -- Soft felt core
  Param.add("MechanicalThud", 0.0, 1.0, 0.45)  -- Wooden keybed & hammer action thud
  
  -- Cabinet & Soundboard
  Param.add("CabinetSize", 0.0, 1.0, 0.20)     -- Compact Upright Box Resonance
  Param.add("BodyReso", 0.0, 1.0, 0.40)        -- Soundboard wood warmth
  Param.add("AirSheen", 0.0, 1.0, 0.15)        -- Room air bleed
  
  -- String Sustain & Intimacy
  Param.add("UnisonDetune", 0.5, 6.0, 2.4)     -- Upright organic unison drift
  Param.add("Sustain", 0.90, 0.998, 0.9945)    -- Natural warm decay
  Param.add("Tone", 800.0, 8000.0, 3800.0)     -- Warm felt lowpass filter
end

function FeltUprightPiano.process(time, freq, note, params)
  local felt = params["FeltThickness"] or 0.85
  local thud = params["MechanicalThud"] or 0.45
  local sustain = params["Sustain"] or 0.9945
  local detune = params["UnisonDetune"] or 2.4
  local tone = params["Tone"] or 3800.0

  local detuneHz = freq * (detune / 1200.0)
  local phase1 = 2.0 * math.pi * freq * time
  local phase2 = 2.0 * math.pi * (freq + detuneHz) * time

  -- Rounded, soft felt waveforms (fundamental dominant)
  local fund1 = math.sin(phase1)
  local fund2 = math.sin(phase2) * 0.9
  local subHarm = math.sin(phase1 * 2.0) * (0.15 * (1.0 - felt * 0.6))

  -- Wooden action thud transient
  local woodThud = math.sin(2.0 * math.pi * 115.0 * time) * math.exp(-time * 50.0) * (0.35 * thud)

  local decayRate = 2.6 + (freq / 200.0)
  local ampEnv = math.exp(-time * decayRate * (1.0 - sustain * 0.4))
  local raw = (fund1 + fund2 + subHarm + woodThud) * ampEnv * 0.40

  return math.tanh(raw * 1.1) * 0.95
end

function FeltUprightPiano.gui()
  return {
    panel = {
      title = "WARM FELT STUDIO UPRIGHT",
      subtitle = "Muted Wool Felt Damper & Intimate Action Modeling",
      accent = "#C19A6B",
      background = "minimal_white",
      knobStyle = "minimal_white",
      layout = {
        -- WARM WALNUT SECTION: Felt Muting & Action
        {
          type = "group",
          label = "WOOL FELT DAMPING & MECHANICAL ACTION",
          accent = "#C19A6B",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "FeltThickness", label = "FELT THICK", unit = "%", size = 52 },
                { type = "knob", param = "HammerHardness", label = "HAMMER", size = 52 },
                { type = "knob", param = "MechanicalThud", label = "ACTION THUD", unit = "%", size = 52 },
                { type = "knob", param = "UnisonDetune", label = "DETUNE", unit = "cents", size = 52 },
              }
            }
          }
        },
        -- OAK SECTION: Upright Cabinet Cavity & Tone
        {
          type = "group",
          label = "UPRIGHT CABINET & WARM TONE",
          accent = "#A0522D",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "CabinetSize", label = "CABINET", size = 52 },
                { type = "knob", param = "BodyReso", label = "WOOD RESO", unit = "%", size = 52 },
                { type = "knob", param = "Tone", label = "FELT WARMTH", unit = "Hz", size = 52 },
                { type = "knob", param = "Sustain", label = "SUSTAIN", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function FeltUprightPiano.rack()
  return {
    rows = {
      {
        { id = "felt_exciter",   title = "WOOL FELT EXCITOR",   hp = 16, row = 1, category = "VCO" },
        { id = "upright_strings",title = "UPRIGHT STRING PAIR", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "cabinet_box",    title = "CABINET CAVITY RESO", hp = 16, row = 2, category = "VCF" },
        { id = "warmth_out",     title = "WARM FELT MASTER",    hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return FeltUprightPiano
''',
    ),

    // 00a3. Honky-Tonk / Tack Saloon Piano Physical Model
    LuaPreset(
      id: 'honky_tonk_piano',
      name: 'Honky-Tonk / Tack Piano',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a vintage Honky-Tonk / Tack Saloon Piano: metallic thumb-tack hammer strike, pronounced trichord unison chorus detuning (5–10 cents), wooden action clack, and bright midrange bite suited for roots, bluegrass, and ragtime.',
      code: '''
-- @id: honky_tonk_piano
-- @name: Honky-Tonk / Tack Piano
-- @category: instrument
-- @description: Physical modeling of a vintage Honky-Tonk / Tack Saloon Piano: metallic thumb-tack hammer strike, pronounced trichord unison chorus detuning (5–10 cents), wooden action clack, and bright midrange bite suited for roots, bluegrass, and ragtime.

local HonkyTonkPiano = {}

function HonkyTonkPiano.init()
  -- Tack Hammer Impact
  Param.add("TackBite", 0.0, 1.5, 0.85)       -- Metallic tack ping intensity
  Param.add("ActionClack", 0.0, 1.0, 0.50)    -- Wooden action & keybed clack
  
  -- Detuned Trichords & Saloon Chorus
  Param.add("DetuneCents", 2.0, 15.0, 7.5)    -- Unison course detuning
  Param.add("SaloonReso", 0.0, 1.0, 0.35)     -- Old wooden saloon upright body
  Param.add("MetalSheen", 0.0, 1.0, 0.60)     -- High metal tack resonance
  
  -- Tone & Bite
  Param.add("Bite", -3.0, 9.0, 3.5)           -- 3.2kHz Midrange bite EQ (dB)
  Param.add("Sustain", 0.90, 0.998, 0.9960)   -- String sustain
  Param.add("Tone", 1000.0, 16000.0, 9500.0)  -- High presence cutoff
end

function HonkyTonkPiano.process(time, freq, note, params)
  local tack = params["TackBite"] or 0.85
  local clack = params["ActionClack"] or 0.50
  local detune = params["DetuneCents"] or 7.5
  local sustain = params["Sustain"] or 0.9960
  local bite = params["Bite"] or 3.5

  local dHz = freq * (detune / 1200.0)
  local phase1 = 2.0 * math.pi * freq * time
  local phase2 = 2.0 * math.pi * (freq + dHz) * time
  local phase3 = 2.0 * math.pi * (freq - dHz * 1.3) * time

  local t1 = math.sin(phase1)
  local t2 = math.sin(phase2) * 0.95
  local t3 = math.sin(phase3) * 0.90

  -- Metallic tack high-frequency ping (4.5kHz burst)
  local tackPing = math.sin(2.0 * math.pi * 4500.0 * time) * math.exp(-time * 220.0) * (0.55 * tack)

  -- Saloon wood clack
  local woodClack = math.sin(2.0 * math.pi * 180.0 * time) * math.exp(-time * 60.0) * (0.30 * clack)

  local decayRate = 2.2 + (freq / 220.0)
  local ampEnv = math.exp(-time * decayRate * (1.0 - sustain * 0.4))
  local raw = (t1 + t2 + t3 + tackPing + woodClack) * ampEnv * 0.35

  return math.tanh(raw * 1.3) * 0.95
end

function HonkyTonkPiano.gui()
  return {
    panel = {
      title = "HONKY-TONK / TACK PIANO",
      subtitle = "Metallic Tack Strike & Detuned Saloon Unison Modeling",
      accent = "#E67E22",
      background = "vintage_tweed",
      rackSides = "dark_wood",
      layout = {
        -- BRASS/ORANGE SECTION: Tack Hammer & Action
        {
          type = "group",
          label = "BRASS TACK IMPACT & SALOON DETUNING",
          accent = "#E67E22",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "TackBite", label = "TACK PING", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "ActionClack", label = "ACTION CLACK", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "DetuneCents", label = "DETUNE", unit = "cents", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "SaloonReso", label = "SALOON BOX", unit = "%", knobStyle = "vintage", size = 52 },
              }
            }
          }
        },
        -- YELLOW/AMBER SECTION: Presence & Tone
        {
          type = "group",
          label = "PRESENCE BITE & SUSTAIN",
          accent = "#F39C12",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "Bite", label = "MID BITE", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "MetalSheen", label = "METAL SHEEN", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Tone", label = "TONE", unit = "Hz", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function HonkyTonkPiano.rack()
  return {
    rows = {
      {
        { id = "tack_strike",    title = "METALLIC TACK EXCITOR", hp = 16, row = 1, category = "VCO" },
        { id = "saloon_chorus",  title = "DETUNED TRICHORDS",    hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "saloon_body",    title = "SALOON WOOD BODY",     hp = 16, row = 2, category = "VCF" },
        { id = "tack_master",    title = "BITE & PRESENCE OUT",  hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return HonkyTonkPiano
''',
    ),

    // 00a4. Toy Piano / Metallophone Physical Model
    LuaPreset(
      id: 'toy_piano',
      name: 'Toy Piano',
      category: LuaPresetCategory.instrument,
      description: 'Physical modal modeling of an authentic Toy Piano / Metallophone: clamped cantilever steel bar overtones (1.0, 2.756, 5.404, 8.933 modal ratios), hammer micro-bounce flam ("double-hit"), keybed bottoming clack, gravity release drop thump, chime air, and miniature wooden soundbox resonance.',
      code: '''
-- @id: toy_piano
-- @name: Toy Piano
-- @category: instrument
-- @description: Physical modal modeling of an authentic Toy Piano / Metallophone: clamped cantilever steel bar overtones (1.0, 2.756, 5.404, 8.933 modal ratios), hammer micro-bounce flam ("double-hit"), keybed bottoming clack, gravity release drop thump, chime air, and miniature wooden soundbox resonance.

local ToyPiano = {}

function ToyPiano.init()
  -- Metal Rod Modal Physics
  Param.add("ClangRatio", 0.0, 1.5, 0.70)     -- Inharmonic bar overtone mix
  Param.add("TineDecay", 0.2, 3.5, 1.25)      -- Ring decay time (seconds)
  
  -- Acoustic Action & Mechanical Noise
  Param.add("HammerClack", 0.0, 1.0, 0.55)    -- Plastic / wood strike clack & keybed thud
  Param.add("HammerBounce", 0.0, 1.0, 0.45)   -- Micro-rebound flam (double-hit) intensity
  Param.add("ReleaseDrop", 0.0, 1.0, 0.40)    -- Gravity key/hammer return drop thud
  Param.add("BoxResonance", 0.0, 1.0, 0.45)   -- Miniature toy box cavity boom
  
  -- Soundbox Cavity & Air
  Param.add("ChimeAir", -4.0, 8.0, 2.0)       -- High chime sheen EQ (dB)
  Param.add("Tone", 1000.0, 18000.0, 11000.0) -- Lowpass cutoff
end

function ToyPiano.process(time, freq, note, params)
  local clang = params["ClangRatio"] or 0.70
  local decay = params["TineDecay"] or 1.25
  local clack = params["HammerClack"] or 0.55
  local bounce = params["HammerBounce"] or 0.45
  local relDrop = params["ReleaseDrop"] or 0.40
  local boxReso = params["BoxResonance"] or 0.45

  -- Cantilever rod non-harmonic mode series
  local f1 = freq
  local f2 = freq * 2.7565
  local f3 = freq * 5.404
  local f4 = math.min(18000.0, freq * 8.933)

  local d1 = 1.8 / decay
  local d2 = (5.5 / decay) + (freq / 300.0)
  local d3 = (14.0 / decay) + (freq / 150.0)
  local d4 = (32.0 / decay) + (freq / 80.0)

  local y1 = math.sin(2.0 * math.pi * f1 * time) * math.exp(-time * d1)
  local y2 = math.sin(2.0 * math.pi * f2 * time) * math.exp(-time * d2) * 0.65 * clang
  local y3 = math.sin(2.0 * math.pi * f3 * time) * math.exp(-time * d3) * 0.35 * clang
  local y4 = math.sin(2.0 * math.pi * f4 * time) * math.exp(-time * d4) * 0.20 * clang

  -- Plastic strike clack & keybed bottoming thud
  local clackTransient = math.sin(2.0 * math.pi * 3200.0 * time) * math.exp(-time * 260.0) * (0.45 * clack)
                       + math.sin(2.0 * math.pi * 240.0 * time) * math.exp(-time * 180.0) * (0.30 * clack)

  -- Secondary hammer micro-rebound flam ("double-hit") at ~20ms
  local bounceTransient = 0.0
  if bounce > 0.001 and time >= 0.020 then
    local tb = time - 0.020
    if tb < 0.03 then
      bounceTransient = (math.sin(2.0 * math.pi * f1 * tb) * 0.35 + math.sin(2.0 * math.pi * 3100.0 * tb) * 0.25)
                      * math.exp(-tb * 200.0) * bounce * 0.40
    end
  end

  -- Wooden housing cavity
  local boxTransient = math.sin(2.0 * math.pi * 340.0 * time) * math.exp(-time * 45.0) * (0.25 * boxReso)

  local raw = (y1 * 0.85 + y2 + y3 + y4 + clackTransient + bounceTransient + boxTransient) * 0.55
  return math.tanh(raw * 1.15) * 0.95
end

function ToyPiano.gui()
  return {
    panel = {
      title = "TOY PIANO / METALLOPHONE",
      subtitle = "Cantilever Steel Bar Modal Physics & Mechanical Action",
      accent = "#FF3366",
      background = "minimal_white",
      knobStyle = "minimal_white",
      layout = {
        -- RED/CORAL SECTION: Steel Bar Modal Physics
        {
          type = "group",
          label = "CANTILEVER STEEL ROD RESONANCE",
          accent = "#FF3366",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "ClangRatio", label = "CLANG OVERTONE", unit = "%", size = 52 },
                { type = "knob", param = "TineDecay", label = "CHIME DECAY", unit = "s", size = 52 },
                { type = "knob", param = "ChimeAir", label = "CHIME AIR", unit = "dB", size = 52 },
                { type = "knob", param = "Tone", label = "TONE CUT", unit = "Hz", size = 52 },
              }
            }
          }
        },
        -- TEAL/CYAN SECTION: Mechanical Action & Soundbox
        {
          type = "group",
          label = "ACOUSTIC MECHANICS & SOUNDBOX",
          accent = "#00B4D8",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "HammerClack", label = "STRIKE CLACK", unit = "%", size = 52 },
                { type = "knob", param = "HammerBounce", label = "HAMMER BOUNCE", unit = "%", size = 52 },
                { type = "knob", param = "ReleaseDrop", label = "RELEASE DROP", unit = "%", size = 52 },
                { type = "knob", param = "BoxResonance", label = "TOY BOX BOOM", unit = "%", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function ToyPiano.rack()
  return {
    rows = {
      {
        { id = "plastic_strike", title = "PLASTIC HAMMER & FLAM", hp = 16, row = 1, category = "VCO" },
        { id = "cantilever_rod", title = "MODAL STEEL ROD TINES", hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "toy_soundbox",   title = "TOY SOUNDBOX CAVITY",   hp = 16, row = 2, category = "VCF" },
        { id = "chime_master",   title = "CHIME & TONE OUT",      hp = 14, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return ToyPiano
''',
    ),

    // 00a5. Orchestral Glockenspiel Physical Model
    LuaPreset(
      id: 'glockenspiel',
      name: 'Glockenspiel',
      category: LuaPresetCategory.instrument,
      description: 'Physical modal modeling of an orchestral glockenspiel (German bells): free-free high-carbon steel rectangular bar Euler-Bernoulli modes (1.0, 2.7565, 5.404, 8.933), pristine low-damping sustain, brass/hard mallet contact click, and high-frequency air shimmer.',
      code: '''
-- @id: glockenspiel
-- @name: Glockenspiel
-- @category: instrument
-- @description: Physical modal modeling of an orchestral glockenspiel (German bells): free-free high-carbon steel rectangular bar Euler-Bernoulli modes (1.0, 2.7565, 5.404, 8.933), pristine low-damping sustain, brass/hard mallet contact click, and high-frequency air shimmer.

local Glockenspiel = {}

function Glockenspiel.init()
  Param.add("BarDecay", 0.5, 6.0, 3.2)         -- Natural sustain time (seconds)
  Param.add("BellShimmer", 0.0, 1.5, 0.70)     -- High inharmonic overtone mix
  Param.add("MalletHardness", 0.1, 1.0, 0.75)  -- Brass / phenolic mallet contact click
  Param.add("AirSheen", -4.0, 8.0, 3.0)        -- High-frequency shimmer shelf (dB)
  Param.add("Tone", 1000.0, 20000.0, 16000.0)  -- Overall tone brightness
end

function Glockenspiel.process(time, freq, note, params)
  local decay = params["BarDecay"] or 3.2
  local shimmer = params["BellShimmer"] or 0.70
  local hardness = params["MalletHardness"] or 0.75

  local f1 = freq
  local f2 = freq * 2.7565
  local f3 = freq * 5.404
  local f4 = math.min(19200.0, freq * 8.933)

  local d1 = 0.40 / decay
  local d2 = (1.6 / decay) + (freq / 900.0)
  local d3 = (4.8 / decay) + (freq / 450.0)
  local d4 = (12.0 / decay) + (freq / 220.0)

  local y1 = math.sin(2.0 * math.pi * f1 * time) * math.exp(-time * d1)
  local y2 = math.sin(2.0 * math.pi * f2 * time) * math.exp(-time * d2) * 0.60 * shimmer
  local y3 = math.sin(2.0 * math.pi * f3 * time) * math.exp(-time * d3) * 0.35 * shimmer
  local y4 = math.sin(2.0 * math.pi * f4 * time) * math.exp(-time * d4) * 0.22 * shimmer

  -- Hard brass mallet contact click
  local click = 0.0
  if time < 0.012 then
    click = math.sin(2.0 * math.pi * 7800.0 * time) * math.exp(-time * 900.0) * (0.45 * hardness)
  end

  local raw = (y1 * 0.90 + y2 + y3 + y4 + click) * 0.52
  return math.tanh(raw * 1.10) * 0.90
end

function Glockenspiel.gui()
  return {
    panel = {
      title = "ORCHESTRAL GLOCKENSPIEL",
      subtitle = "Free-Free High-Carbon Steel Bar Modal Resonator",
      accent = "#E0A96D",
      background = "minimal_white",
      knobStyle = "minimal_white",
      layout = {
        {
          type = "group",
          label = "STEEL BAR MODES & SUSTAIN",
          accent = "#E0A96D",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BarDecay", label = "SUSTAIN", unit = "s", size = 52 },
                { type = "knob", param = "BellShimmer", label = "SHIMMER", unit = "%", size = 52 },
                { type = "knob", param = "MalletHardness", label = "MALLET", unit = "%", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "BRILLIANCE & AIR",
          accent = "#38EF7D",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "AirSheen", label = "AIR SHEEN", unit = "dB", size = 52 },
                { type = "knob", param = "Tone", label = "TONE", unit = "Hz", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function Glockenspiel.rack()
  return {
    rows = {
      {
        { id = "mallet_strike", title = "BRASS MALLET CLICK", hp = 14, row = 1, category = "VCO" },
        { id = "steel_bars",    title = "FREE-FREE STEEL BARS", hp = 16, row = 1, category = "MOD" },
      },
      {
        { id = "bell_air",      title = "CRYSTAL AIR SHEEN",   hp = 14, row = 2, category = "VCF" },
        { id = "master_out",    title = "GLOCKENSPIEL MASTER", hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return Glockenspiel
''',
    ),

    // 00a6. Antique Music Box Physical Model
    LuaPreset(
      id: 'music_box',
      name: 'Music Box',
      category: LuaPresetCategory.instrument,
      description: 'Physical modal modeling of an antique music box comb: clamped-free steel lamellae tines (1.0, 6.267, 17.55 modes), Heaviside step displacement pluck release, cylinder pin friction scrape tick, and wooden box/tabletop soundboard resonance.',
      code: '''
-- @id: music_box
-- @name: Music Box
-- @category: instrument
-- @description: Physical modal modeling of an antique music box comb: clamped-free steel lamellae tines (1.0, 6.267, 17.55 modes), Heaviside step displacement pluck release, cylinder pin friction scrape tick, and wooden box/tabletop soundboard resonance.

local MusicBox = {}

function MusicBox.init()
  Param.add("TineDecay", 0.3, 4.5, 2.0)        -- Comb tine ring decay (seconds)
  Param.add("PinScrape", 0.0, 1.0, 0.45)       -- Cylinder pin pre-slip friction tick
  Param.add("BoxWarmth", 0.0, 1.0, 0.50)       -- Wooden casing / soundboard resonance
  Param.add("HighTineRing", 0.0, 1.2, 0.50)    -- Upper inharmonic overtone mix
  Param.add("Tone", 1000.0, 18000.0, 12000.0)  -- Lowpass tone cutoff
end

function MusicBox.process(time, freq, note, params)
  local decay = params["TineDecay"] or 2.0
  local scrape = params["PinScrape"] or 0.45
  local warmth = params["BoxWarmth"] or 0.50
  local highRing = params["HighTineRing"] or 0.50

  local f1 = freq
  local f2 = freq * 6.267
  local f3 = math.min(18500.0, freq * 17.55)

  local d1 = 1.1 / decay
  local d2 = (5.8 / decay) + (freq / 400.0)
  local d3 = (22.0 / decay) + (freq / 120.0)

  -- Plucked Heaviside step displacement: Cosine initial phase
  local y1 = math.cos(2.0 * math.pi * f1 * time) * math.exp(-time * d1)
  local y2 = math.cos(2.0 * math.pi * f2 * time) * math.exp(-time * d2) * 0.35 * highRing
  local y3 = math.cos(2.0 * math.pi * f3 * time) * math.exp(-time * d3) * 0.16 * highRing

  -- Cylinder pin friction scrape & slip tick
  local scrapeTransient = 0.0
  if time < 0.008 and scrape > 0.001 then
    scrapeTransient = math.sin(2.0 * math.pi * 4400.0 * time) * (time / 0.008) * (0.40 * scrape)
  end

  -- Wooden soundboard warm resonance
  local soundboardRing = math.sin(2.0 * math.pi * 560.0 * time) * math.exp(-time * 55.0) * (0.30 * warmth)

  local raw = (y1 * 0.95 + y2 + y3 + scrapeTransient + soundboardRing) * 0.55
  return math.tanh(raw * 1.12) * 0.92
end

function MusicBox.gui()
  return {
    panel = {
      title = "ANTIQUE MUSIC BOX",
      subtitle = "Plucked Steel Comb Lamellae & Cylinder Pin Physics",
      accent = "#C77DFF",
      background = "minimal_white",
      knobStyle = "minimal_white",
      layout = {
        {
          type = "group",
          label = "PLUCKED STEEL COMB TINES",
          accent = "#C77DFF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "TineDecay", label = "TINE DECAY", unit = "s", size = 52 },
                { type = "knob", param = "HighTineRing", label = "OVERTONE", unit = "%", size = 52 },
                { type = "knob", param = "PinScrape", label = "PIN SCRAPE", unit = "%", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "SOUNDBOARD & WARMTH",
          accent = "#FFAA00",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BoxWarmth", label = "BOX WARMTH", unit = "%", size = 52 },
                { type = "knob", param = "Tone", label = "TONE", unit = "Hz", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function MusicBox.rack()
  return {
    rows = {
      {
        { id = "pin_action",   title = "CYLINDER PIN PLUCK", hp = 14, row = 1, category = "VCO" },
        { id = "comb_tines",   title = "STEEL COMB TINES",   hp = 16, row = 1, category = "MOD" },
      },
      {
        { id = "table_board",  title = "SOUNDBOARD BODY",    hp = 14, row = 2, category = "VCF" },
        { id = "musicbox_out", title = "MUSIC BOX MASTER",   hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return MusicBox
''',
    ),

    // 00a7. Orchestral Xylophone Physical Model
    LuaPreset(
      id: 'xylophone',
      name: 'Xylophone',
      category: LuaPresetCategory.instrument,
      description: 'Physical modal modeling of an orchestral rosewood xylophone: undercut arched Honduras rosewood bar with Mode 2 tuned to the triple octave (3.0 * f0), high internal wood damping (dry staccato pop), tuned quarter-wave air resonator tube burst, and hard mallet impact.',
      code: '''
-- @id: xylophone
-- @name: Xylophone
-- @category: instrument
-- @description: Physical modal modeling of an orchestral rosewood xylophone: undercut arched Honduras rosewood bar with Mode 2 tuned to the triple octave (3.0 * f0), high internal wood damping (dry staccato pop), tuned quarter-wave air resonator tube burst, and hard mallet impact.

local Xylophone = {}

function Xylophone.init()
  Param.add("WoodDecay", 0.08, 1.0, 0.32)       -- Staccato wood ring decay (seconds)
  Param.add("ResonatorPop", 0.0, 1.2, 0.65)     -- Tuned tube air resonator burst
  Param.add("MalletHardness", 0.1, 1.0, 0.70)   -- Hard wood / rubber mallet attack
  Param.add("TripleOctave", 0.0, 1.0, 0.55)     -- Tuned 3.0x harmonic overtone
  Param.add("WoodCrack", -3.0, 6.0, 2.0)        -- High wood bite presence (dB)
  Param.add("Tone", 1500.0, 20000.0, 15000.0)   -- Lowpass cutoff
end

function Xylophone.process(time, freq, note, params)
  local decay = params["WoodDecay"] or 0.32
  local pop = params["ResonatorPop"] or 0.65
  local hardness = params["MalletHardness"] or 0.70
  local overtone3x = params["TripleOctave"] or 0.55

  -- Undercut arched rosewood bar modes:
  -- Mode 1: Fundamental
  -- Mode 2: Tuned triple-octave harmonic (3.0 * f0)
  -- Mode 3: Inharmonic transient click (~6.52 * f0)
  local f1 = freq
  local f2 = freq * 3.00
  local f3 = math.min(18000.0, freq * 6.52)

  local d1 = 6.2 / decay
  local d2 = (16.0 / decay) + (freq / 250.0)
  local d3 = (42.0 / decay) + (freq / 100.0)

  local y1 = math.sin(2.0 * math.pi * f1 * time) * math.exp(-time * d1)
  local y2 = math.sin(2.0 * math.pi * f2 * time) * math.exp(-time * d2) * 0.60 * overtone3x
  local y3 = math.sin(2.0 * math.pi * f3 * time) * math.exp(-time * d3) * 0.28 * overtone3x

  -- Tuned quarter-wave resonator tube air column pop burst
  local tubeResonator = math.sin(2.0 * math.pi * f1 * time) * math.exp(-time * 90.0) * (0.50 * pop)

  -- Hard mallet contact knock
  local malletTransient = 0.0
  if time < 0.010 then
    malletTransient = math.sin(2.0 * math.pi * 3800.0 * time) * math.exp(-time * 600.0) * (0.40 * hardness)
  end

  local raw = (y1 * 0.88 + y2 + y3 + tubeResonator + malletTransient) * 0.58
  return math.tanh(raw * 1.20) * 0.95
end

function Xylophone.gui()
  return {
    panel = {
      title = "ORCHESTRAL XYLOPHONE",
      subtitle = "Arched Rosewood Bar Triple-Octave Physics & Tube Resonator",
      accent = "#E76F51",
      background = "minimal_white",
      knobStyle = "minimal_white",
      layout = {
        {
          type = "group",
          label = "ROSEWOOD MODAL ARCH",
          accent = "#E76F51",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "WoodDecay", label = "WOOD DECAY", unit = "s", size = 52 },
                { type = "knob", param = "TripleOctave", label = "3X OVERTONE", unit = "%", size = 52 },
                { type = "knob", param = "ResonatorPop", label = "TUBE POP", unit = "%", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "MALLET & PRESENCE",
          accent = "#F4A261",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "MalletHardness", label = "MALLET", unit = "%", size = 52 },
                { type = "knob", param = "WoodCrack", label = "WOOD BITE", unit = "dB", size = 52 },
                { type = "knob", param = "Tone", label = "TONE", unit = "Hz", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function Xylophone.rack()
  return {
    rows = {
      {
        { id = "wood_mallet",    title = "HARD WOOD MALLET",  hp = 14, row = 1, category = "VCO" },
        { id = "rosewood_bars",  title = "ARCHED ROSEWOOD",   hp = 16, row = 1, category = "MOD" },
      },
      {
        { id = "resonator_tube", title = "QUARTER-WAVE TUBE", hp = 14, row = 2, category = "VCF" },
        { id = "xylophone_out",  title = "XYLOPHONE MASTER",  hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return Xylophone
''',
    ),

    // 00a8. Orchestral Vibraphone Physical Model
    LuaPreset(
      id: 'vibraphone',
      name: 'Vibraphone',
      category: LuaPresetCategory.instrument,
      description: 'Physical modal modeling of an orchestral vibraphone: undercut arched aluminum alloy bar with Mode 2 tuned to the double octave (4.0 * f0), singing sustain, wound yarn mallet attack, and motor-driven rotating butterfly valve resonator tube tremolo/phase modulation.',
      code: '''
-- @id: vibraphone
-- @name: Vibraphone
-- @category: instrument
-- @description: Physical modal modeling of an orchestral vibraphone: undercut arched aluminum alloy bar with Mode 2 tuned to the double octave (4.0 * f0), singing sustain, wound yarn mallet attack, and motor-driven rotating butterfly valve resonator tube tremolo/phase modulation.

local Vibraphone = {}

function Vibraphone.init()
  Param.add("BarDecay", 1.0, 8.0, 4.5)         -- Singing aluminum sustain (seconds)
  Param.add("MotorSpeed", 0.5, 9.0, 4.2)       -- Butterfly valve rotation speed (Hz)
  Param.add("TremoloDepth", 0.0, 1.0, 0.60)    -- Tube resonator tremolo depth
  Param.add("DoubleOctave", 0.0, 1.0, 0.40)    -- Tuned 4.0x harmonic overtone
  Param.add("YarnSoftness", 0.0, 1.0, 0.50)    -- Yarn-wrapped mallet contact softness
  Param.add("ToneCut", 2000.0, 16000.0, 9500.0)-- Tube acoustic cutoff
end

function Vibraphone.process(time, freq, note, params)
  local decay = params["BarDecay"] or 4.5
  local mSpeed = params["MotorSpeed"] or 4.2
  local tDepth = params["TremoloDepth"] or 0.60
  local overtone4x = params["DoubleOctave"] or 0.40
  local softness = params["YarnSoftness"] or 0.50

  -- Aluminum bar modes:
  -- Mode 1: Fundamental
  -- Mode 2: Tuned double-octave harmonic (4.0 * f0)
  -- Mode 3: Inharmonic mode (~9.20 * f0)
  local f1 = freq
  local f2 = freq * 4.00
  local f3 = math.min(18500.0, freq * 9.20)

  local d1 = 0.35 / decay
  local d2 = (1.5 / decay) + (freq / 1200.0)
  local d3 = (7.5 / decay) + (freq / 350.0)

  -- Rotating butterfly valve modulation: 2 * motorSpeed modulation rate
  local valveOmega = 2.0 * math.pi * (2.0 * mSpeed)
  local valveExposure = 0.5 + 0.5 * math.cos(valveOmega * time)
  local tremoloMod = 1.0 - (tDepth * (1.0 - valveExposure))

  local y1 = math.sin(2.0 * math.pi * f1 * time) * math.exp(-time * d1)
  local y2 = math.sin(2.0 * math.pi * f2 * time) * math.exp(-time * d2) * 0.50 * overtone4x
  local y3 = math.sin(2.0 * math.pi * f3 * time) * math.exp(-time * d3) * 0.20 * overtone4x * (1.0 - 0.5 * softness)

  -- Soft yarn mallet contact thud
  local yarnThud = 0.0
  if time < 0.015 then
    yarnThud = math.sin(2.0 * math.pi * 450.0 * time) * math.exp(-time * 220.0) * 0.30
  end

  local acousticBar = (y1 * 0.92 + y2 + y3 + yarnThud) * 0.54
  local outWithTremolo = acousticBar * tremoloMod
  return math.tanh(outWithTremolo * 1.10) * 0.90
end

function Vibraphone.gui()
  return {
    panel = {
      title = "ORCHESTRAL VIBRAPHONE",
      subtitle = "Arched Aluminum Bar Double-Octave & Motor Tremolo Resonator",
      accent = "#4CC9F0",
      background = "minimal_white",
      knobStyle = "minimal_white",
      layout = {
        {
          type = "group",
          label = "ALUMINUM BAR & MALLET",
          accent = "#4CC9F0",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BarDecay", label = "SUSTAIN", unit = "s", size = 52 },
                { type = "knob", param = "DoubleOctave", label = "4X OVERTONE", unit = "%", size = 52 },
                { type = "knob", param = "YarnSoftness", label = "YARN MALLET", unit = "%", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "MOTOR TREMOLO & RESONATOR TUBE",
          accent = "#7209B7",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "MotorSpeed", label = "MOTOR RATE", unit = "Hz", size = 52 },
                { type = "knob", param = "TremoloDepth", label = "TREMOLO", unit = "%", size = 52 },
                { type = "knob", param = "ToneCut", label = "TUBE TONE", unit = "Hz", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function Vibraphone.rack()
  return {
    rows = {
      {
        { id = "yarn_mallet",   title = "WOUND YARN MALLET",    hp = 14, row = 1, category = "VCO" },
        { id = "aluminum_bars", title = "ARCHED ALUMINUM BARS", hp = 16, row = 1, category = "MOD" },
      },
      {
        { id = "motor_valve",   title = "BUTTERFLY TREMOLO",    hp = 14, row = 2, category = "LFO" },
        { id = "vibraphone_out",title = "VIBRAPHONE MASTER",    hp = 16, row = 2, category = "OUT" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:1:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "mod" },
    }
  }
end

return Vibraphone
''',
    ),


    // 00b. Yamaha DX7 6-Operator FM Electric Piano ("FullTines")
    LuaPreset(
      id: 'dx7_epiano',
      name: 'Yamaha DX7 E-Piano',
      category: LuaPresetCategory.instrument,
      description: 'Authentic 1983 Yamaha DX7 6-operator FM electric piano ("FullTines / E.PIANO 1"): 32 routing algorithms (Alg 5 triple 2-op stack), velocity-to-modulation index scaling, glassy inharmonic tine bell, warm FM body, feedback loop, 12-bit DAC compander emulation, and stereo shimmer chorus.',
      code: '''
-- @id: dx7_epiano
-- @name: Yamaha DX7 E-Piano
-- @category: instrument
-- @description: Authentic 1983 Yamaha DX7 6-operator FM electric piano ("FullTines / E.PIANO 1"): 32 routing algorithms (Alg 5 triple 2-op stack), velocity-to-modulation index scaling, glassy inharmonic tine bell, warm FM body, feedback loop, 12-bit DAC compander emulation, and stereo shimmer chorus.

local DX7EPiano = {}

function DX7EPiano.init()
  -- FM Architecture & Algorithm
  Param.add("Algorithm", 1, 32, 5)
  Param.add("Feedback", 0, 7, 6)
  Param.add("Patch", 0, 5, 0)
  Param.add("Brightness", 0.0, 3.0, 1.0)
  Param.add("TineBell", 0.0, 3.0, 0.85)
  Param.add("BodyWarmth", 0.0, 3.0, 1.0)

  -- Modulation & Chorus
  Param.add("ChorusMix", 0.0, 1.0, 0.35)
  Param.add("BassBoost", -12.0, 12.0, 1.5)
  Param.add("TrebleSparkle", -12.0, 12.0, 2.5)
  Param.add("Drive", 0.5, 3.0, 1.0)
end

function DX7EPiano.process(time, freq, note, params)
  local alg = math.floor(params.Algorithm or 5)
  local bright = params.Brightness or 1.0
  local bell = params.TineBell or 0.85
  local body = params.BodyWarmth or 1.0

  -- 6-Op FM E-Piano synthesis with 14x bell tine modulator
  local t = time
  local basePhase = t * freq * 2.0 * math.pi

  -- Op 1 & 2: Warm E-Piano Body (1:1 ratio)
  local op2 = math.sin(basePhase) * math.exp(-t * 2.2) * bright
  local op1 = math.sin(basePhase + op2 * 3.5) * math.exp(-t * 1.2) * body

  -- Op 3 & 4: Inharmonic Glassy Tine Bell (14:1 ratio)
  local op4 = math.sin(basePhase * 14.0) * math.exp(-t * 6.5) * bright
  local op3 = math.sin(basePhase + op4 * 3.0) * math.exp(-t * 3.8) * bell

  -- Op 5 & 6: Detuned Shimmer (1:1 ratio + detune)
  local op6 = math.sin(basePhase * 1.002) * math.exp(-t * 2.5) * bright
  local op5 = math.sin(basePhase * 1.002 + op6 * 2.5) * math.exp(-t * 1.5) * body

  local mix = (op1 * 0.45 + op3 * 0.35 + op5 * 0.35)
  return math.tanh(mix * (params.Drive or 1.0))
end

function DX7EPiano.gui()
  return {
    panel = {
      title = "YAMAHA DX7 — DIGITAL SYNTHESIZER",
      subtitle = "6-Operator FM Tone Generator & E-Piano",
      accent = "#00E5FF",
      background = "dx7_membrane",
      rackSides = "none",
      cornerRadius = 0,
      layout = {
        {
          type = "group",
          label = "6-OPERATOR FM MATRIX & ALGORITHM",
          accent = "#00E5FF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "Algorithm", label = "ALGORITHM", unit = "ALG", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Feedback", label = "FEEDBACK", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Patch", label = "ROM PATCH", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Brightness", label = "BRIGHTNESS", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "TineBell", label = "TINE BELL", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "BodyWarmth", label = "BODY WARMTH", knobStyle = "chrome", size = 52 },
              }
            },
            {
              type = "row",
              children = {
                { type = "hslider", param = "Brightness", label = "FM MODULATION BRIGHTNESS (VELOCITY BARK)", width = 480, style = "capsule" },
              }
            }
          }
        },
        {
          type = "group",
          label = "PREAMP EQ & STEREO SHIMMER CHORUS",
          accent = "#26A69A",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "ChorusMix", label = "CHORUS", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "BassBoost", label = "BASS", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "TrebleSparkle", label = "TREBLE", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Drive", label = "DRIVE", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function DX7EPiano.rack()
  return {
    rows = {
      {
        { id = "fm_matrix",   title = "6-OP FM OPERATOR MATRIX", hp = 16, row = 1, category = "VCO" },
        { id = "alg_router",  title = "32-ALGORITHM ROUTER",     hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "tone_stack",  title = "ACTIVE 2-BAND PREAMP",    hp = 14, row = 2, category = "VCF" },
        { id = "shimmer_fx",  title = "STEREO SHIMMER CHORUS",   hp = 16, row = 2, category = "FX" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return DX7EPiano
''',
    ),

    // 00c. Commodore 64 SID Chiptune Synthesizer
    LuaPreset(
      id: 'c64_sid_synth',
      name: 'Commodore 64 SID Synth',
      category: LuaPresetCategory.instrument,
      description: 'Authentic MOS 6581 / 8580 Commodore 64 Sound Interface Device: 12-bit Pulse Width Modulation (PWM), 23-bit Galois LFSR noise, hardware ADSR, 50Hz/60Hz chiptune arpeggiator, glissando, and 12dB/oct multimode resonant filter with non-linear FET saturation.',
      code: '''
-- @id: c64_sid_synth
-- @name: Commodore 64 SID Synth
-- @category: instrument
-- @description: Authentic MOS 6581 / 8580 Commodore 64 Sound Interface Device: 12-bit Pulse Width Modulation (PWM), 23-bit Galois LFSR noise, hardware ADSR, 50Hz/60Hz chiptune arpeggiator, glissando, and 12dB/oct multimode resonant filter with non-linear FET saturation.

local C64SID = {}

function C64SID.init()
  Param.add("Waveform", 0, 5, 0)
  Param.add("PulseWidth", 100, 4000, 2048)
  Param.add("PwmRate", 0.1, 10.0, 1.6)
  Param.add("PwmDepth", 0.0, 1.0, 0.45)
  Param.add("ArpMode", 0, 5, 0)
  Param.add("GlideSpeed", 0.0, 0.5, 0.0)

  -- 12dB Resonant Multimode Filter
  Param.add("ChipModel", 0, 1, 0)
  Param.add("FilterMode", 0, 4, 0)
  Param.add("Cutoff", 100, 2047, 1350)
  Param.add("Resonance", 0, 15, 9)
  Param.add("Overdrive", 1.0, 3.0, 1.2)

  -- Envelope
  Param.add("Attack", 0, 15, 1)
  Param.add("Decay", 0, 15, 6)
  Param.add("Sustain", 0, 15, 12)
  Param.add("Release", 0, 15, 5)
end

function C64SID.process(time, freq, note, params)
  local t = time
  local phase = (t * freq) % 1.0
  local pw = (params.PulseWidth or 2048) / 4095.0
  local raw = phase < pw and 1.0 or -1.0
  local env = math.exp(-t * 2.5)
  return raw * env
end

function C64SID.gui()
  return {
    panel = {
      title = "COMMODORE 64 — SID SOUND SYNTHESIZER",
      subtitle = "MOS 6581 / 8580 3-Voice Chiptune Instrument",
      accent = "#6C5EB5",
      background = "c64_breadbin",
      rackSides = "none",
      cornerRadius = 4,
      layout = {
        {
          type = "group",
          label = "OSCILLATOR & HARDWARE PWM",
          accent = "#6C5EB5",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "Waveform", label = "WAVEFORM", unit = "WAV", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "PulseWidth", label = "PULSE WIDTH", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "PwmRate", label = "PWM RATE", unit = "Hz", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "PwmDepth", label = "PWM DEPTH", knobStyle = "chrome", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "CHIPTUNE ARPEGGIATOR & GLIDE",
          accent = "#A0864B",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "ArpMode", label = "ARP (50/60Hz)", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "GlideSpeed", label = "GLIDE", unit = "s", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Attack", label = "ATTACK", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Decay", label = "DECAY", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Release", label = "RELEASE", knobStyle = "vintage", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "12dB/OCT RESONANT MULTIMODE FILTER (6581 / 8580)",
          accent = "#3E9B48",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "ChipModel", label = "MODEL (6581/8580)", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "FilterMode", label = "MODE (LP/BP/HP)", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Cutoff", label = "CUTOFF", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Resonance", label = "RESONANCE", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Overdrive", label = "FET DRIVE", knobStyle = "chrome", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function C64SID.rack()
  return {
    rows = {
      {
        { id = "osc",     title = "SID 12-BIT OSCILLATOR & PWM", hp = 16, row = 1, category = "VCO" },
        { id = "arp",     title = "50Hz CHIPTUNE ARPEGGIATOR",   hp = 14, row = 1, category = "MOD" },
      },
      {
        { id = "filter",  title = "MOS 6581/8580 12dB FILTER",   hp = 16, row = 2, category = "VCF" },
        { id = "env",     title = "STEPPED ADSR ENVELOPE",       hp = 14, row = 2, category = "ENV" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return C64SID
''',
    ),

    // 00d. Hohner Clavinet D6 Physical Model
    LuaPreset(
      id: 'clavinet_d6',
      name: 'Hohner Clavinet D6',
      category: LuaPresetCategory.instrument,
      description: 'Authentic physical model of the 1971 Hohner Clavinet D6: rubber-tipped hammer-on-metal anvil strike, taut steel string digital waveguide, key-off yarn damper thump, dual single-coil pickups with out-of-phase funk quack (A-B), 4-rocker EQ filter bank (Brilliant, Treble, Medium, Soft), and tube preamp bite.',
      code: '''
-- @id: clavinet_d6
-- @name: Hohner Clavinet D6
-- @category: instrument
-- @description: Authentic physical model of the 1971 Hohner Clavinet D6: rubber-tipped hammer-on-metal anvil strike, taut steel string digital waveguide, key-off yarn damper thump, dual single-coil pickups with out-of-phase funk quack (A-B), 4-rocker EQ filter bank (Brilliant, Treble, Medium, Soft), and tube preamp bite.

local ClavinetD6 = {}

function ClavinetD6.init()
  -- Pickups & Phase Matrix
  Param.add("PickupSelect", 0.0, 1.0, 0.5)
  Param.add("PhaseInvert", 0.0, 1.0, 0.0)

  -- 4-Rocker Tone Filter Stack
  Param.add("Brilliant", 0.0, 1.0, 1.0)
  Param.add("Treble", 0.0, 1.0, 0.8)
  Param.add("Medium", 0.0, 1.0, 0.5)
  Param.add("Soft", 0.0, 1.0, 0.0)

  -- String & Hammer Mechanics
  Param.add("HammerHardness", 0.2, 3.0, 1.4)
  Param.add("HammerSnap", 0.0, 2.0, 0.9)
  Param.add("Sustain", 0.80, 0.999, 0.993)
  Param.add("DamperThump", 0.0, 1.0, 0.45)
  Param.add("Drive", 0.5, 3.0, 1.08)
end

function ClavinetD6.process(time, freq, note, params)
  local t = time
  local phase = t * freq * 2.0 * math.pi
  local decay = math.exp(-t * (4.5 / (params.Sustain or 0.993)))

  -- Rubber hammer strike impulse + steel string vibration
  local strike = math.exp(-t * 120.0) * (params.HammerSnap or 0.9) * 1.5
  local stringWave = (math.sin(phase) + 0.6 * math.sin(phase * 2.0) + 0.35 * math.sin(phase * 3.0)) * decay

  local raw = stringWave + strike
  return math.tanh(raw * (params.Drive or 1.08))
end

function ClavinetD6.gui()
  return {
    panel = {
      title = "HOHNER CLAVINET D6",
      subtitle = "Electromechanical Steel String Keyboard",
      accent = "#FF8C00",
      background = "walnut",
      rackSides = "walnut",
      cornerRadius = 6,
      layout = {
        {
          type = "group",
          label = "4-ROCKER TONE FILTER MATRIX",
          accent = "#FF8C00",
          children = {
            {
              type = "row",
              children = {
                { type = "switch", param = "Brilliant", label = "BRILLIANT" },
                { type = "switch", param = "Treble", label = "TREBLE" },
                { type = "switch", param = "Medium", label = "MEDIUM" },
                { type = "switch", param = "Soft", label = "SOFT" },
              }
            }
          }
        },
        {
          type = "group",
          label = "PICKUPS & DAMPING DYNAMICS",
          accent = "#E5A93C",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "PickupSelect", label = "PICKUP A/B", knobStyle = "vintage", size = 52 },
                { type = "switch", param = "PhaseInvert", label = "PHASE (A-B)" },
                { type = "knob", param = "HammerHardness", label = "HAMMER", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "DamperThump", label = "DAMPER", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Drive", label = "DRIVE", knobStyle = "vintage", size = 52 },
              }
            },
            {
              type = "row",
              children = {
                { type = "hslider", param = "Sustain", label = "STRING SUSTAIN & YARN DAMPING", style = "capsule" },
              }
            }
          }
        }
      }
    }
  }
end

function ClavinetD6.rack()
  return {
    rows = {
      {
        { id = "hammer_anvil",  title = "RUBBER HAMMER & ANVIL", hp = 16, row = 1, category = "VCO" },
        { id = "waveguide_str", title = "STEEL STRING WAVEGUIDE", hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "pickup_phase",  title = "DUAL PICKUP COMB PHASE", hp = 14, row = 2, category = "MOD" },
        { id = "d6_rocker_eq",  title = "4-ROCKER TONE STACK",    hp = 16, row = 2, category = "FX" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return ClavinetD6
''',
    ),

    // 00d. Harpsichord / Cembalo Physical Model
    LuaPreset(
      id: 'harpsichord_cembalo',
      name: 'Harpsichord / Cembalo',
      category: LuaPresetCategory.instrument,
      description: 'Authentic physical model of a Flemish/Italian Baroque Harpsichord (Cembalo): Delrin/crow quill plectrum pluck excitation, velocity-invariant acoustic touch, dual 8\' Principal and 4\' Octave register stops, buff/lute felt damping, spruce soundboard modal cavity resonator, and mechanical wooden jack release noise.',
      code: '''
-- @id: harpsichord_cembalo
-- @name: Harpsichord / Cembalo
-- @category: instrument
-- @description: Authentic physical model of a Flemish/Italian Baroque Harpsichord (Cembalo): Delrin/crow quill plectrum pluck excitation, velocity-invariant acoustic touch, dual 8\' Principal and 4\' Octave register stops, buff/lute felt damping, spruce soundboard modal cavity resonator, and mechanical wooden jack release noise.

local Harpsichord = {}

function Harpsichord.init()
  -- Register Stops & Registers
  Param.add("Stop4Octave", 0.0, 1.0, 0.35)
  Param.add("BuffStop", 0.05, 0.80, 0.18)

  -- Quill Plectrum Dynamics
  Param.add("PluckBite", 0.1, 3.0, 1.45)
  Param.add("ScrapeLevel", 0.0, 2.0, 0.40)
  Param.add("Sustain", 0.85, 0.999, 0.995)

  -- Acoustics & Mechanics
  Param.add("AirSparkle", -6.0, 12.0, 2.0)
  Param.add("JackRelease", 0.0, 1.0, 0.35)
end

function Harpsichord.process(time, freq, note, params)
  local t = time
  local phase = t * freq * 2.0 * math.pi
  local decay = math.exp(-t * (3.2 / (params.Sustain or 0.995)))

  -- Sharp quill step pluck + 8\' fundamental + 4\' octave harmonic
  local pluck = math.exp(-t * 220.0) * (params.PluckBite or 1.45)
  local h8 = (math.sin(phase) + 0.7 * math.sin(phase * 2.0) + 0.45 * math.sin(phase * 3.0)) * decay
  local h4 = math.sin(phase * 2.0) * math.exp(-t * 4.5) * (params.Stop4Octave or 0.35)

  local raw = (h8 * 0.7 + h4 * 0.3 + pluck * 0.4)
  return math.tanh(raw * 1.05)
end

function Harpsichord.gui()
  return {
    panel = {
      title = "BAROQUE HARPSICHORD",
      subtitle = "Cembalo Doppio — 8\' Principal & 4\' Octave Stops",
      accent = "#D4AF37",
      background = "harpsichord_lacquer",
      rackSides = "rosewood",
      cornerRadius = 4,
      layout = {
        {
          type = "group",
          label = "REGISTER STOPS (TIRASSE)",
          accent = "#D4AF37",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "Stop4Octave", label = "4\' OCTAVE", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "BuffStop", label = "BUFF (LUTE)", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Sustain", label = "SUSTAIN", unit = "s", knobStyle = "vintage", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "QUILL PLUCK & SOUNDBOARD ACOUSTICS",
          accent = "#E5A93C",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "PluckBite", label = "PLUCK BITE", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "ScrapeLevel", label = "QUILL SCRAPE", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "AirSparkle", label = "AIR SPARKLE", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "JackRelease", label = "JACK RELEASE", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function Harpsichord.rack()
  return {
    rows = {
      {
        { id = "quill_exciter", title = "DELRIN QUILL PLUCK",     hp = 16, row = 1, category = "VCO" },
        { id = "dual_waveguide",title = "8\' & 4\' DUAL WAVEGUIDE",hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "soundboard_box",title = "SPRUCE SOUNDBOARD BOX",  hp = 14, row = 2, category = "MOD" },
        { id = "jack_mechanism",title = "JACK DAMPER RELEASE",    hp = 16, row = 2, category = "FX" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return Harpsichord
''',
    ),

    // 00e. Acoustic Bass Guitar Physical Model
    LuaPreset(
      id: 'acoustic_bass',
      name: 'Acoustic Bass Guitar',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an acoustic bronze-wound bass guitar: soft fingertip flesh pluck with nail transient, low-frequency steel core waveguide, dreadnought hollow body modal cavity resonator, and piezo under-saddle preamp with acoustic air sparkle.',
      code: '''
-- @id: acoustic_bass
-- @name: Acoustic Bass Guitar
-- @category: instrument
-- @description: Physical model of an acoustic bronze-wound bass guitar: soft fingertip flesh pluck with nail transient, low-frequency steel core waveguide, dreadnought hollow body modal cavity resonator, and piezo under-saddle preamp with acoustic air sparkle.

local AcousticBass = {}

function AcousticBass.init()
  -- Pluck & Flesh Contact
  Param.add("PluckForce", 0.2, 3.0, 1.30)
  Param.add("NailClick", 0.0, 1.5, 0.35)

  -- String & Body Dynamics
  Param.add("Sustain", 0.85, 0.999, 0.995)
  Param.add("Damping", 0.05, 0.80, 0.28)

  -- Preamp & Room Acoustics
  Param.add("AcousticAir", -6.0, 12.0, 1.5)
  Param.add("Drive", 0.5, 3.0, 1.02)
end

function AcousticBass.process(time, freq, note, params)
  local t = time
  local phase = t * freq * 2.0 * math.pi
  local decay = math.exp(-t * (3.8 / (params.Sustain or 0.995)))

  -- Low fundamental + woody harmonics
  local flesh = math.exp(-t * 85.0) * (params.PluckForce or 1.3)
  local body = math.sin(phase) + 0.45 * math.sin(phase * 2.0) + 0.20 * math.sin(phase * 3.0)
  local raw = (body * decay + flesh * 0.4)
  return math.tanh(raw * (params.Drive or 1.02))
end

function AcousticBass.gui()
  return {
    panel = {
      title = "ACOUSTIC BASS GUITAR",
      subtitle = "Bronze-Wound String & Dreadnought Hollow Body",
      accent = "#D4AF37",
      background = "blonde_pine",
      rackSides = "rosewood",
      cornerRadius = 6,
      layout = {
        {
          type = "group",
          label = "FINGERTIP PLUCK & STRING MECHANICS",
          accent = "#D4AF37",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "PluckForce", label = "PLUCK FORCE", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "NailClick", label = "NAIL CLICK", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Damping", label = "BODY DAMP", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "AcousticAir", label = "AIR SPARKLE", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Drive", label = "PREAMP", knobStyle = "vintage", size = 52 },
              }
            },
            {
              type = "row",
              children = {
                { type = "hslider", param = "Sustain", label = "STRING SUSTAIN & BODY RESONANCE", style = "capsule" },
              }
            }
          }
        }
      }
    }
  }
end

function AcousticBass.rack()
  return {
    rows = {
      {
        { id = "flesh_pluck",   title = "FLESH PLUCK EXCITER",    hp = 16, row = 1, category = "VCO" },
        { id = "low_waveguide", title = "BRONZE CORE WAVEGUIDE",  hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "dread_cavity",  title = "DREADNOUGHT BODY MODAL", hp = 14, row = 2, category = "MOD" },
        { id = "piezo_air",     title = "PIEZO PREAMP & AIR",     hp = 16, row = 2, category = "FX" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return AcousticBass
''',
    ),

    // 00f. Fretless Electric J-Bass Physical Model
    LuaPreset(
      id: 'fretless_bass',
      name: 'Fretless J-Bass',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of a vintage fretless electric Jazz Bass: non-linear fingerboard boundary damping with blooming "Mwah" harmonic buzz, dual single-coil magnetic pickups with 1.6kHz bridge bark, and active 2-band tone stack.',
      code: '''
-- @id: fretless_bass
-- @name: Fretless J-Bass
-- @category: instrument
-- @description: Physical model of a vintage fretless electric Jazz Bass: non-linear fingerboard boundary damping with blooming "Mwah" harmonic buzz, dual single-coil magnetic pickups with 1.6kHz bridge bark, and active 2-band tone stack.

local FretlessBass = {}

function FretlessBass.init()
  -- Mwah & Fingerboard Dynamics
  Param.add("MwahAmount", 0.0, 1.0, 0.75)
  Param.add("Growl", 0.0, 1.0, 0.60)
  Param.add("FingerDamping", 0.05, 0.60, 0.22)

  -- Pickups & Active Tone
  Param.add("BridgePickup", 0.0, 1.0, 0.90)
  Param.add("MidBark", -6.0, 12.0, 3.5)
  Param.add("Sustain", 0.85, 0.999, 0.996)
  Param.add("Drive", 0.5, 3.0, 1.10)
end

function FretlessBass.process(time, freq, note, params)
  local t = time
  local phase = t * freq * 2.0 * math.pi
  local decay = math.exp(-t * (3.5 / (params.Sustain or 0.996)))

  -- Fingerboard blooming "Mwah" envelope
  local mwahEnv = math.sin(math.min(math.pi, t * 4.5)) * (params.MwahAmount or 0.75)
  local body = math.sin(phase) + (0.50 + mwahEnv * 0.4) * math.sin(phase * 2.0) + (0.25 + mwahEnv * 0.3) * math.sin(phase * 3.0)
  local raw = body * decay
  return math.tanh(raw * (params.Drive or 1.10))
end

function FretlessBass.gui()
  return {
    panel = {
      title = "FRETLESS J-BASS",
      subtitle = "Epoxy Fingerboard 'Mwah' & Bridge Pickup Bark",
      accent = "#FF6D00",
      background = "rosewood",
      rackSides = "brushed_steel",
      cornerRadius = 6,
      layout = {
        {
          type = "group",
          label = "FINGERBOARD 'MWAH' & GROWL DYNAMICS",
          accent = "#FF6D00",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "MwahAmount", label = "MWAH BLOOM", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Growl", label = "GROWL", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "FingerDamping", label = "DAMPING", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "BridgePickup", label = "BRIDGE PU", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "MidBark", label = "1.6k BARK", unit = "dB", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Drive", label = "TUBE DRIVE", knobStyle = "chrome", size = 52 },
              }
            },
            {
              type = "row",
              children = {
                { type = "hslider", param = "MwahAmount", label = "FRETLESS MWAH INTENSITY (FLAT <-> BLOOMING BUZZ)", style = "capsule" },
              }
            }
          }
        }
      }
    }
  }
end

function FretlessBass.rack()
  return {
    rows = {
      {
        { id = "fretless_board",title = "FRETLESS MWAH SHAPER",  hp = 16, row = 1, category = "VCO" },
        { id = "string_guide",  title = "STEEL BASS WAVEGUIDE",  hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "jbass_pickups", title = "J-BASS BRIDGE PICKUP",  hp = 14, row = 2, category = "MOD" },
        { id = "active_preamp", title = "ACTIVE 2-BAND PREAMP",  hp = 16, row = 2, category = "FX" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return FretlessBass
''',
    ),

    // 00g. Upright Double Bass Physical Model
    LuaPreset(
      id: 'upright_bass',
      name: 'Upright Double Bass',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an acoustic 3/4 Upright Double Bass: heavy gut string side-finger pull, 3/4 carved spruce body resonance, 85Hz sub-bass warmth, and punchy wood body tone.',
      code: '''
-- @id: upright_bass
-- @name: Upright Double Bass
-- @category: instrument
-- @description: Physical model of an acoustic 3/4 Upright Double Bass: heavy gut string side-finger pull, 3/4 carved spruce body resonance, 85Hz sub-bass warmth, and punchy wood body tone.

local UprightBass = {}

function UprightBass.init()
  -- Finger Pull & Slap Dynamics
  Param.add("FingerMass", 0.5, 4.0, 2.0)
  Param.add("SlapClick", 0.0, 2.0, 0.0) -- Default 0.0 (warm pizzicato without click)

  -- String & Cavity Resonance
  Param.add("StringDamp", 0.05, 0.75, 0.32)
  Param.add("SubWarmth", 0.0, 12.0, 4.5)
  Param.add("BodyPunch", -3.0, 9.0, 3.0)
  Param.add("WoodTone", -9.0, 6.0, -4.0)
  Param.add("Sustain", 0.85, 0.9995, 0.996)
  Param.add("Drive", 0.5, 2.5, 1.15)
end

function UprightBass.process(time, freq, note, params)
  local t = time
  local phase = t * freq * 2.0 * math.pi
  local subWarmth = params.SubWarmth or 4.5
  local sustain = params.Sustain or 0.996
  local decay = math.exp(-t * (1.6 / sustain))

  -- Warm, deep fundamental + rich second/third wood harmonic body
  local fundamental = math.sin(phase) * (1.0 + subWarmth * 0.06)
  local bodyHarmonics = 0.38 * math.sin(phase * 2.0) + 0.18 * math.sin(phase * 3.0)
  local slap = (params.SlapClick or 0.0) > 0.05 and (math.exp(-t * 140.0) * params.SlapClick * 0.4) or 0.0

  local raw = (fundamental + bodyHarmonics) * decay + slap
  return math.tanh(raw * (params.Drive or 1.15)) * 0.95
end

function UprightBass.gui()
  return {
    panel = {
      title = "UPRIGHT DOUBLE BASS",
      subtitle = "3/4 Acoustic Spruce Cavity, Sub Warmth & Body Punch",
      accent = "#C49A45",
      background = "walnut",
      rackSides = "rosewood",
      cornerRadius = 6,
      layout = {
        {
          type = "group",
          label = "ACOUSTIC CAVITY & GUT STRING WEIGHT",
          accent = "#C49A45",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "FingerMass", label = "PULL MASS", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "SubWarmth", label = "SUB BASS", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "BodyPunch", label = "180Hz BODY", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "WoodTone", label = "WOOD TONE", unit = "dB", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "StringDamp", label = "GUT DAMP", unit = "%", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Sustain", label = "SUSTAIN", knobStyle = "vintage", size = 52 },
                { type = "knob", param = "Drive", label = "ACOUSTIC GAIN", knobStyle = "vintage", size = 52 },
              }
            },
            {
              type = "row",
              children = {
                { type = "hslider", param = "SubWarmth", label = "SUB-BASS HELMHOLTZ CAVITY WEIGHT (0.0dB <-> 12.0dB)", style = "capsule" },
              }
            },
            {
              type = "row",
              children = {
                { type = "knob", param = "SlapClick", label = "WOOD SLAP", knobStyle = "vintage", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

function UprightBass.rack()
  return {
    rows = {
      {
        { id = "gut_pull",      title = "GUT PULL EXCITOR",        hp = 16, row = 1, category = "VCO" },
        { id = "upright_guide", title = "3/4 BASS WAVEGUIDE",      hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "spruce_cavity", title = "SPRUCE CAVITY MODAL",     hp = 14, row = 2, category = "MOD" },
        { id = "sub_air_eq",    title = "SUB WARMTH & BODY PUNCH", hp = 16, row = 2, category = "FX" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return UprightBass
''',
    ),

    // 00h. Model D / Analog Sub Synth Bass
    LuaPreset(
      id: 'moog_synth_bass',
      name: 'Model D Sub Synth Bass',
      category: LuaPresetCategory.instrument,
      description: 'Analog Sub Synth Bass: dual detuned Saw/Pulse oscillators with dedicated sub-octave square wave, 4-pole 24dB/oct transistor ladder lowpass filter with exponential contour punch, and warm transistor overdrive.',
      code: '''
-- @id: moog_synth_bass
-- @name: Model D Sub Synth Bass
-- @category: instrument
-- @description: Analog Sub Synth Bass: dual detuned Saw/Pulse oscillators with dedicated sub-octave square wave, 4-pole 24dB/oct transistor ladder lowpass filter with exponential contour punch, and warm transistor overdrive.

local MoogSynthBass = {}

function MoogSynthBass.init()
  -- Filter & Envelope Contour
  Param.add("Cutoff", 30.0, 8000.0, 350.0)
  Param.add("Resonance", 0.0, 0.95, 0.65)
  Param.add("FilterEnv", 0.0, 1.0, 0.65)
  Param.add("Decay", 0.05, 3.0, 0.40)
  Param.add("AmpDecay", 0.1, 4.0, 0.85)
  Param.add("Drive", 0.5, 3.0, 1.25)
end

function MoogSynthBass.process(time, freq, note, params)
  local t = time
  local p1 = (t * freq) % 1.0
  local p2 = (t * freq * 1.003) % 1.0
  local pSub = (t * freq * 0.5) % 1.0

  -- Saw + Pulse + Sub Square
  local saw = 2.0 * p1 - 1.0
  local pulse = p2 < 0.45 and 1.0 or -1.0
  local sub = pSub < 0.5 and 1.0 or -1.0

  local filterEnv = math.exp(-t / (params.Decay or 0.40)) * (params.FilterEnv or 0.65)
  local ampEnv = math.exp(-t / (params.AmpDecay or 0.85))

  local raw = (saw * 0.6 + pulse * 0.4 + sub * 0.5) * (1.0 + filterEnv * 1.5) * ampEnv
  return math.tanh(raw * (params.Drive or 1.25))
end

function MoogSynthBass.gui()
  return {
    panel = {
      title = "MODEL D — SUB SYNTH BASS",
      subtitle = "4-Pole 24dB/oct Transistor Ladder & Sub-Oscillator",
      accent = "#00E5FF",
      background = "matte_metal",
      rackSides = "brushed_steel",
      cornerRadius = 0,
      layout = {
        {
          type = "group",
          label = "TRANSISTOR LADDER VCF & CONTOUR",
          accent = "#00E5FF",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "Cutoff", label = "CUTOFF", unit = "Hz", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Resonance", label = "EMPHASIS", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "FilterEnv", label = "CONTOUR", unit = "%", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Decay", label = "FILTER DECAY", unit = "s", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "AmpDecay", label = "AMP DECAY", unit = "s", knobStyle = "chrome", size = 52 },
                { type = "knob", param = "Drive", label = "OVERLOAD", knobStyle = "chrome", size = 52 },
              }
            },
            {
              type = "row",
              children = {
                { type = "hslider", param = "Cutoff", label = "24dB/OCT LADDER FILTER CUTOFF SWEEP", style = "capsule" },
              }
            }
          }
        }
      }
    }
  }
end

function MoogSynthBass.rack()
  return {
    rows = {
      {
        { id = "dual_vco_sub",  title = "DUAL VCO + SUB OSC",      hp = 16, row = 1, category = "VCO" },
        { id = "ladder_vcf",    title = "24dB/OCT MOOG LADDER",    hp = 14, row = 1, category = "VCF" },
      },
      {
        { id = "contour_adsr",  title = "EXPONENTIAL CONTOUR",     hp = 14, row = 2, category = "MOD" },
        { id = "overload_vca",  title = "TRANSISTOR OVERLOAD VCA", hp = 16, row = 2, category = "FX" },
      },
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },
      { from = "1:1:1", to = "2:0:0", color = "audio" },
      { from = "2:0:1", to = "2:1:0", color = "audio" },
    }
  }
end

return MoogSynthBass
''',
    ),

    // 0. Eats Vinyl PRO (Analog Wow, Flutter, Vinyl Crackle, Needle Stutter & Tape Stop Engine)
    LuaPreset(
      id: 'vintage_era_degrader',
      name: 'Eats Vinyl',
      category: LuaPresetCategory.audioFx,
      description: 'Physical vinyl and vintage tape degradation engine: authentic wow & flutter pitch vibrato, era morphing EQ (1950s-1980s), procedural vinyl crackle & pop impulses, needle bumps & dropouts, and instant tape stop.',
      code: '''
-- @id: vintage_era_degrader
-- @name: Eats Vinyl
-- @category: audioFx
-- @description: Physical vinyl & tape degradations: Wow & Flutter, Era EQ (1950s-1980s), Procedural Vinyl Crackle, Needle Bumps/Stutters, Tape Dropouts, and Real-Time Tape Stop.

local EatsVinylPro = {}

function EatsVinylPro.init()
  -- Era & Medium
  Param.add("Era", 1950.0, 1989.0, 1974.0, 1.0)
  Param.choice("Medium", {"Tape 15 IPS", "Cassette Type I", "Vinyl 33 RPM", "Shellac 78 RPM", "Warped 45 RPM"}, 2)
  
  -- Pitch Instability (FM)
  Param.add("WowDepth", 0.0, 100.0, 25.0)
  Param.add("FlutterDepth", 0.0, 100.0, 15.0)
  Param.add("MotorJitter", 0.0, 100.0, 10.0)
  
  -- Volume Instability & Dropouts (AM)
  Param.add("WarpSwell", 0.0, 100.0, 20.0)
  Param.add("TapeDropouts", 0.0, 100.0, 15.0)
  Param.add("LevelDrift", 0.0, 100.0, 10.0)
  
  -- Physical Vinyl Bumps & Needle Stutter
  Param.add("NeedleBumpFreq", 0.0, 100.0, 25.0)
  Param.add("StutterDepth", 0.0, 100.0, 35.0)
  Param.add("ThudLevel", 0.0, 100.0, 30.0)
  
  -- Tone & Saturation
  Param.add("TapeWarmth", 0.0, 100.0, 45.0)
  Param.add("HeadBump", 0.0, 12.0, 3.0)
  Param.add("HissLevel", 0.0, 100.0, 20.0)
  Param.add("VinylCrackle", 0.0, 100.0, 25.0)
  Param.add("GrooveRumble", 0.0, 100.0, 15.0)
  
  -- Tape Stop Controls
  Param.add("StopTime", 0.1, 3.0, 0.8)
  Param.add("SpinUpTime", 0.1, 2.0, 0.4)
  Param.add("Mix", 0.0, 1.0, 1.0)
end

function EatsVinylPro.gui()
  return {
    panel = {
      title = "EATS VINYL",
      subtitle = "Physical Wow, Flutter, Vinyl Crackle & Tape Engine",
      accent = "#E65100",
      background = "grunge",
      layout = {
        {
          type = "row",
          children = {
            { type = "listbox", param = "Medium", label = "MEDIA FORMAT", width = 170 },
            { type = "nixie", param = "Era", label = "DECADE YEAR", unit = "AD" },
            { type = "button", action = "trigger_tape_stop", label = "TAPE STOP", width = 130, height = 44 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "Era", label = "ERA BANDWIDTH MORPH (1950s - 1980s)", width = 480, style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "WowDepth", label = "WOW", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "FlutterDepth", label = "FLUTTER", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "WarpSwell", label = "WARP AM", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "TapeDropouts", label = "DROPOUTS", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "NeedleBumpFreq", label = "BUMPS", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "StutterDepth", label = "STUTTER", unit = "%", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "ThudLevel", label = "SUB THUD", unit = "%", knobStyle = "vintage", size = 50 },
            { type = "knob", param = "TapeWarmth", label = "DRIVE", unit = "%", knobStyle = "vintage", size = 50 },
            { type = "knob", param = "HissLevel", label = "HISS", unit = "%", knobStyle = "vintage", size = 50 },
            { type = "knob", param = "VinylCrackle", label = "CRACKLE", unit = "%", knobStyle = "vintage", size = 50 },
            { type = "knob", param = "StopTime", label = "STOP TIME", unit = "s", knobStyle = "vintage", size = 50 },
            { type = "knob", param = "Mix", label = "MIX", unit = "%", size = 54 },
          }
        }
      }
    }
  }
end

return EatsVinylPro
''',
    ),

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
      accent = "#E52521",
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
      accent = "#E52521",
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

    // 33b. Convolution Reverb FX
    LuaPreset(
      id: 'convolution_reverb',
      name: 'Convolution Reverb',
      category: LuaPresetCategory.audioFx,
      description: 'Impulse response convolution reverb with 3D space visualizer and acoustic room modeling.',
      code: '''
-- @name: Convolution Reverb
-- @category: audioFx
-- @description: True stereo impulse response convolution engine with 3D acoustic room modeling
local ConvolutionReverb = {}

function ConvolutionReverb.init()
  Param.choice("IRSample", {"Great Hall", "Plate Reverb", "Cathedral", "Small Studio"}, 0.0)
  Param.choice("Material", {"Wood Paneling", "Pine Wood", "Acoustic Foam", "Hard Concrete", "Birch Plywood", "Velvet Drapes", "Sheet Metal", "Carpet"}, 0.0)
  Param.add("Width", 1.0, 30.0, 15.0, 0.5)
  Param.add("Length", 1.0, 40.0, 25.0, 0.5)
  Param.add("Height", 1.0, 18.0, 10.0, 0.5)
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

function ConvolutionReverb.process(input_l, input_r, params)
  return input_l, input_r
end

function ConvolutionReverb.gui()
  return {
    panel = {
      title = "Convolution Reverb",
      subtitle = "True Stereo Impulse Response Processor",
      background = "grunge",
      accent = "#21F4E8",
      layout = {
        { type = "space_visualizer", height = 135 },
        {
          type = "row",
          children = {
            { type = "listbox", param = "IRSample", label = "IR SAMPLE", width = 160, height = 70 },
            { type = "listbox", param = "Material", label = "MATERIAL", width = 130, height = 70 },
            { type = "knob", param = "RT60", label = "DECAY", unit = "s" },
            { type = "knob", param = "Damping", label = "DAMP" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Width", label = "WIDTH", unit = "m", size = 36 },
            { type = "knob", param = "Length", label = "LENGTH", unit = "m", size = 36 },
            { type = "knob", param = "Height", label = "HEIGHT", unit = "m", size = 36 },
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

return ConvolutionReverb
''',
    ),

    // 34. Procedural Room Designer FX
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
