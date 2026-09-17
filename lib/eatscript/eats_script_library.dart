import 'gm_standard_drum_kit_preset.dart';
import 'modular_drumpad_kit_preset.dart';
import 'ambient_pad_preset.dart';
import 'pipe_family_presets.dart';
import 'brass_reed_family_presets.dart';
import 'eats_builtin_presets.g.dart';
import 'eats_script_engine.dart';
import 'eats_transpiler.dart';

// Aliases for Eatscript definitions & branding
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
      case EatScriptCategory.instrument:
        return 'INSTRUMENT';
      case EatScriptCategory.audioFx:
        return 'AUDIO FX';
      case EatScriptCategory.midiFx:
        return 'MIDI FX';
      case EatScriptCategory.midiSeq:
        return 'MIDI SEQ';
      case EatScriptCategory.noteSplitter:
        return 'NOTE SPLITTER';
      case EatScriptCategory.projectAction:
      case EatScriptCategory.utility:
      case EatScriptCategory.macro:
        return 'MACRO';
    }
  }

  static EatScriptCategory parse(String categoryStr) {
    final clean = categoryStr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (clean.contains('macro') || clean.contains('project') || clean.contains('action') || clean.contains('songgen') || clean.contains('generator') || clean.contains('transpos')) {
      return EatScriptCategory.macro;
    }
    if (clean.contains('split') || clean.contains('separator') || clean.contains('demux')) {
      return EatScriptCategory.noteSplitter;
    }
    if (clean.contains('midiseq') || clean.contains('seq') || clean.contains('pattern')) {
      return EatScriptCategory.midiSeq;
    }
    if (clean.contains('audiofx') || clean.contains('effect') || clean.contains('fx')) {
      if (clean.contains('midi')) return EatScriptCategory.midiFx;
      return EatScriptCategory.audioFx;
    }
    if (clean.contains('midi')) return EatScriptCategory.midiFx;
    if (clean.contains('util')) return EatScriptCategory.macro;
    return EatScriptCategory.instrument;
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

  bool get isInstrument => category == EatScriptCategory.instrument;
  bool get isAudioFx => category == EatScriptCategory.audioFx;
  bool get isMidiFx => category == EatScriptCategory.midiFx;
  bool get isMidiSeq => category == EatScriptCategory.midiSeq;
  bool get isNoteSplitter => category == EatScriptCategory.noteSplitter;
  bool get isProjectAction => category == EatScriptCategory.projectAction || category == EatScriptCategory.macro;
  bool get isUtility => category == EatScriptCategory.utility || category == EatScriptCategory.macro;
  bool get isMacro => category == EatScriptCategory.macro || category == EatScriptCategory.projectAction || category == EatScriptCategory.utility;

  /// Returns the script formatted as Eatscript, transpiling Eatscript on demand.
  String get eatCode {
    if (EatScriptEngine.isEatScript(code)) return code;
    return EatTranspiler.transpileEatScriptPreset(code);
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
  static final List<EatScriptDef> _customScripts = [];

  static List<EatScriptDef> get scripts => [
        GmStandardDrumKitPreset.preset,
        ModularDrumpadKitPreset.preset,
        ...EatBuiltinPresets.presets,
        ...PipeFamilyPresets.all,
        ...BrassReedFamilyPresets.all,
        ..._customScripts,
      ];
  static List<EatScriptDef> get presets => scripts; // Compatibility alias

  static List<EatScriptDef> getScriptsByCategory(EatScriptCategory category) {
    if (category == EatScriptCategory.macro) {
      return scripts.where((p) => p.isMacro).toList();
    }
    return scripts.where((p) => p.category == category).toList();
  }

  static List<EatScriptDef> getMacros() => scripts.where((p) => p.isMacro).toList();

  static List<EatScriptDef> getPresetsByCategory(EatScriptCategory category) => getScriptsByCategory(category);

  static void registerCustomScript(EatScriptDef script) {
    _customScripts.removeWhere((p) => p.id == script.id || p.name == script.name);
    _customScripts.add(script);
  }

  static void registerCustomPreset(EatScriptDef script) => registerCustomScript(script);

  static EatScriptDef parseFromEatScript(String scriptCode, {String fallbackName = 'Custom Script'}) =>
      parseFromScript(scriptCode, fallbackName: fallbackName);

  static EatScriptDef parseFromScript(String eatScriptCode, {String fallbackName = 'Custom Script'}) {
    String name = fallbackName;
    EatScriptCategory category = EatScriptCategory.instrument;
    String description = '';
    final List<String> tags = [];

    final lines = eatScriptCode.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      final clean = trimmed.startsWith('--') ? trimmed.substring(2).trim() : (trimmed.startsWith('#') ? trimmed.substring(1).trim() : trimmed);
      if (clean.startsWith('@name:')) {
        name = clean.substring(6).trim();
      } else if (clean.startsWith('@category:')) {
        category = EatScriptCategory.parse(clean.substring(10).trim());
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

    if (!eatScriptCode.contains('@category:')) {
      if (eatScriptCode.contains('processSignal') || eatScriptCode.contains('evaluateEffect')) {
        category = EatScriptCategory.audioFx;
      } else if (eatScriptCode.contains('transform_notes') || eatScriptCode.contains('midi_fx')) {
        category = EatScriptCategory.midiFx;
      }
    }

    if (description.isEmpty) {
      description = '$name ${category == EatScriptCategory.audioFx ? 'DSP audio effect' : (category == EatScriptCategory.midiFx ? 'MIDI effect transformer' : 'synthesizer instrument')}';
    }

    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    final script = EatScriptDef(
      id: id,
      name: name,
      category: category,
      description: description,
      code: eatScriptCode,
      tags: tags,
    );

    registerCustomScript(script);
    return script;
  }

  static EatScriptDef? getScriptById(String id) {
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

  static EatScriptDef? getPresetById(String id) => getScriptById(id);

  static EatScriptDef? findMatchingPreset(String eatScriptCode, {String? fallbackName}) => findMatchingScript(eatScriptCode, fallbackName: fallbackName);

  static EatScriptDef? findMatchingScript(String eatScriptCode, {String? fallbackName}) {
    if (eatScriptCode.trim().isEmpty && (fallbackName == null || fallbackName.isEmpty)) {
      return null;
    }

    // 1. Check for explicit @id: or @name:
    final lines = eatScriptCode.split('\n');
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
    if (eatScriptCode.contains('modular_drumpad_kit') ||
        eatScriptCode.contains('ModularDrumpadKit') ||
        eatScriptCode.contains('Modular Drum Machine')) {
      return getPresetById('modular_drumpad_kit');
    }
    if (eatScriptCode.contains('gm_standard_drum_kit') ||
        eatScriptCode.contains('GmStandardDrumKit') ||
        eatScriptCode.contains('GM Standard Drum Kit')) {
      return getPresetById('gm_standard_drum_kit');
    }
    if (eatScriptCode.contains('FmAcousticKick') || eatScriptCode.contains('Dual-Mic FM Acoustic Kick') || eatScriptCode.contains('NearPitchStart') || eatScriptCode.contains('fm_acoustic_kick')) {
      return getPresetById('fm_acoustic_kick');
    }
    if (eatScriptCode.contains('FmAcousticSnare') || eatScriptCode.contains('Dual-Mic FM Acoustic Snare') || eatScriptCode.contains('WireCutoff') || eatScriptCode.contains('fm_acoustic_snare')) {
      return getPresetById('fm_acoustic_snare');
    }
    if (eatScriptCode.contains('FmAcousticTom') || eatScriptCode.contains('FM Acoustic Tom') || eatScriptCode.contains('fm_acoustic_tom') || eatScriptCode.contains('TomPitchStart')) {
      return getPresetById('fm_acoustic_tom');
    }
    if (eatScriptCode.contains('FmAcousticHiHat') || eatScriptCode.contains('FM Acoustic Hi-Hat') || eatScriptCode.contains('fm_acoustic_hihat')) {
      return getPresetById('fm_acoustic_hihat');
    }
    if (eatScriptCode.contains('Analog808Kick') || eatScriptCode.contains('Analog 808 Kick') || eatScriptCode.contains('analog_808_kick')) {
      return getPresetById('analog_808_kick');
    }
    if (eatScriptCode.contains('Analog808Snare') || eatScriptCode.contains('Analog 808 Snare') || eatScriptCode.contains('analog_808_snare')) {
      return getPresetById('analog_808_snare');
    }
    if (eatScriptCode.contains('Analog808HiHat') || eatScriptCode.contains('Analog 808 Hi-Hat') || eatScriptCode.contains('analog_808_hihat')) {
      return getPresetById('analog_808_hihat');
    }
    if (eatScriptCode.contains('Analog808Cowbell') || eatScriptCode.contains('Analog 808 Cowbell') || eatScriptCode.contains('analog_808_cowbell')) {
      return getPresetById('analog_808_cowbell');
    }
    if (eatScriptCode.contains('Analog808Tom') || eatScriptCode.contains('Analog 808 Tom') || eatScriptCode.contains('analog_808_tom')) {
      return getPresetById('analog_808_tom');
    }
    if (eatScriptCode.contains('Analog909Kick') || eatScriptCode.contains('Analog 909 Kick') || eatScriptCode.contains('analog_909_kick')) {
      return getPresetById('analog_909_kick');
    }
    if (eatScriptCode.contains('Analog909Snare') || eatScriptCode.contains('Analog 909 Snare') || eatScriptCode.contains('analog_909_snare')) {
      return getPresetById('analog_909_snare');
    }
    if (eatScriptCode.contains('Analog909ClosedHiHat') || eatScriptCode.contains('Analog 909 Closed Hi-Hat') || eatScriptCode.contains('analog_909_closed_hihat') || eatScriptCode.contains('analog_909_hihat') || eatScriptCode.contains('Analog 909 Hi-Hat') || eatScriptCode.contains('Analog909HiHat')) {
      return getPresetById('analog_909_closed_hihat');
    }
    if (eatScriptCode.contains('Analog909OpenHiHat') || eatScriptCode.contains('Analog 909 Open Hi-Hat') || eatScriptCode.contains('analog_909_open_hihat')) {
      return getPresetById('analog_909_open_hihat');
    }
    if (eatScriptCode.contains('Analog909Clap') || eatScriptCode.contains('Analog 909 Clap') || eatScriptCode.contains('analog_909_clap') || eatScriptCode.contains('Analog 909 Handclap')) {
      return getPresetById('analog_909_clap');
    }
    if (eatScriptCode.contains('Analog909Rimshot') || eatScriptCode.contains('Analog 909 Rimshot') || eatScriptCode.contains('analog_909_rimshot')) {
      return getPresetById('analog_909_rimshot');
    }
    if (eatScriptCode.contains('Eats303') || eatScriptCode.contains('Eats-303') || eatScriptCode.contains('eats_303') ||
        eatScriptCode.contains('JC303') || eatScriptCode.contains('JC-303') || eatScriptCode.contains('Acid303') ||
        eatScriptCode.contains('TB303') || eatScriptCode.contains('jc_303') || eatScriptCode.contains('acid_303')) {
      return getPresetById('eats_303');
    }
    if (eatScriptCode.contains('YM2612')) {
      return getPresetById('ym2612_synth');
    }
    if (eatScriptCode.contains('SNESSFX') || eatScriptCode.contains('SFXR')) {
      return getPresetById('eats_sfxr');
    }
    if (eatScriptCode.contains('Nibbles') || eatScriptCode.contains('nibbles') || eatScriptCode.contains('eats_nibbles') || eatScriptCode.contains('Eats-Nibbles')) {
      return getPresetById('eats_nibbles');
    }
    if (eatScriptCode.contains('CyberRunner') || eatScriptCode.contains('Cyber Runner') || eatScriptCode.contains('eats_runner') || eatScriptCode.contains('Eats-Runner')) {
      return getPresetById('eats_runner');
    }
    if (eatScriptCode.contains('Oscilloscope') || eatScriptCode.contains('eats_scope') || eatScriptCode.contains('Eats-Scope') || eatScriptCode.contains('Scope')) {
      return getPresetById('eats_scope');
    }
    if (eatScriptCode.contains('Spectrum') || eatScriptCode.contains('eats_spectrum') || eatScriptCode.contains('Eats-Spectrum') || eatScriptCode.contains('Analyzer')) {
      return getPresetById('eats_spectrum');
    }
    if (eatScriptCode.contains('Limiter') || eatScriptCode.contains('master_limiter') || eatScriptCode.contains('Master Limiter')) {
      return getPresetById('master_limiter');
    }
    if (eatScriptCode.contains('Compressor') || eatScriptCode.contains('dynamics_compressor') || eatScriptCode.contains('Dynamics Compressor')) {
      return getPresetById('dynamics_compressor');
    }
    if (eatScriptCode.contains('RoomDesigner') || eatScriptCode.contains('room_designer') || eatScriptCode.contains('Room Designer')) {
      return getPresetById('room_designer');
    }
    if (eatScriptCode.contains('CabDesigner') || eatScriptCode.contains('cab_designer') || eatScriptCode.contains('Cab Designer')) {
      return getPresetById('cab_designer');
    }
    if (eatScriptCode.contains('StereoDelay') || eatScriptCode.contains('stereo_delay') || eatScriptCode.contains('Stereo Delay')) {
      return getPresetById('stereo_delay');
    }
    if (eatScriptCode.contains('FilterFX') || eatScriptCode.contains('lowpass_filter') || eatScriptCode.contains('Lowpass Filter')) {
      return getPresetById('lowpass_filter');
    }
    if (eatScriptCode.contains('VintageDegrader') || eatScriptCode.contains('vintage_era_degrader') || eatScriptCode.contains('Vintage Era Degrader') || eatScriptCode.contains('Eats Vinyl') || eatScriptCode.contains('eats_vinyl') || eatScriptCode.contains('Era Bandwidth Morph')) {
      return getPresetById('vintage_era_degrader');
    }
    if (eatScriptCode.contains('PolyLeadSynth')) {
      return getPresetById('poly_lead');
    }
    if (eatScriptCode.contains('RhodesEPiano') || eatScriptCode.contains('rhodes_epiano') || eatScriptCode.contains('Rhodes Mark I') || eatScriptCode.contains('Stage 73')) {
      return getPresetById('rhodes_epiano');
    }
    if (eatScriptCode.contains('ReggaeGuitar') || eatScriptCode.contains('reggae_guitar') || eatScriptCode.contains('Reggae Skank') || eatScriptCode.contains('Dub Guitar') || eatScriptCode.contains('Dub Chop') || eatScriptCode.contains('SkankGuitar') || eatScriptCode.contains('DubGuitar')) {
      return getPresetById('reggae_guitar');
    }
    if (eatScriptCode.contains('HawaiianUkulele') || eatScriptCode.contains('hawaiian_ukulele') || eatScriptCode.contains('Ukulele') || (eatScriptCode.contains('PluckSnap') && eatScriptCode.contains('StrumSpread'))) {
      return getPresetById('hawaiian_ukulele');
    }
    if (eatScriptCode.contains('SpanishGuitar') || eatScriptCode.contains('spanish_guitar') || eatScriptCode.contains('ClassicalGuitar') || eatScriptCode.contains('classical_guitar') || eatScriptCode.contains('Spanish Guitar') || eatScriptCode.contains('Classical Guitar') || (eatScriptCode.contains('FleshNail') && eatScriptCode.contains('AirResonance'))) {
      return getPresetById('spanish_guitar');
    }
    if (eatScriptCode.contains('RenaissanceLute') || eatScriptCode.contains('renaissance_lute') || eatScriptCode.contains('BaroqueLute') || eatScriptCode.contains('baroque_lute') || eatScriptCode.contains('Lute') || eatScriptCode.contains('Vihuela') || (eatScriptCode.contains('CourseDetune') && eatScriptCode.contains('BowlWarmth'))) {
      return getPresetById('renaissance_lute');
    }
    if (eatScriptCode.contains('BaroqueGuitar') || eatScriptCode.contains('baroque_guitar') || eatScriptCode.contains('5-Course Guitar') || eatScriptCode.contains('Chitarra Spagnola') || (eatScriptCode.contains('RoseBite') && eatScriptCode.contains('RasgueadoSpeed'))) {
      return getPresetById('baroque_guitar');
    }
    if (eatScriptCode.contains('FlamencoGuitar') || eatScriptCode.contains('flamenco_guitar') || eatScriptCode.contains('Guitarra Flamenca') || eatScriptCode.contains('Flamenco') || (eatScriptCode.contains('GolpeTap') && eatScriptCode.contains('SnapDamp'))) {
      return getPresetById('flamenco_guitar');
    }
    if (eatScriptCode.contains('SteelAcousticGuitar') || eatScriptCode.contains('acoustic_steel_guitar') || eatScriptCode.contains('Steel Acoustic') || (eatScriptCode.contains('BodyProfile') && eatScriptCode.contains('BronzeSparkle'))) {
      return getPresetById('acoustic_steel_guitar');
    }
    if (eatScriptCode.contains('TwelveStringGuitar') || eatScriptCode.contains('twelve_string_guitar') || eatScriptCode.contains('12-String') || (eatScriptCode.contains('ChorusDetune') && eatScriptCode.contains('OctavePairing'))) {
      return getPresetById('twelve_string_guitar');
    }
    if (eatScriptCode.contains('DobroResonator') || eatScriptCode.contains('dobro_resonator') || eatScriptCode.contains('Dobro') || eatScriptCode.contains('Resonator') || (eatScriptCode.contains('ConeType') && eatScriptCode.contains('MetalBark'))) {
      return getPresetById('dobro_resonator');
    }
    if (eatScriptCode.contains('PedalSteelGuitar') || eatScriptCode.contains('pedal_steel_guitar') || eatScriptCode.contains('Pedal Steel') || (eatScriptCode.contains('VolumeSwell') && eatScriptCode.contains('BarVibrato'))) {
      return getPresetById('pedal_steel_guitar');
    }
    if (eatScriptCode.contains('HarpGuitar') || eatScriptCode.contains('harp_guitar') || eatScriptCode.contains('Harp Guitar') || (eatScriptCode.contains('SubDroneGain') && eatScriptCode.contains('PickStyle'))) {
      return getPresetById('harp_guitar');
    }
    if (eatScriptCode.contains('BluegrassBanjo') || eatScriptCode.contains('bluegrass_banjo') || eatScriptCode.contains('Banjo') || (eatScriptCode.contains('HeadTension') && eatScriptCode.contains('TwangSnap'))) {
      return getPresetById('bluegrass_banjo');
    }
    if (eatScriptCode.contains('FolkMandolin') || eatScriptCode.contains('folk_mandolin') || eatScriptCode.contains('Mandolin') || (eatScriptCode.contains('TremoloSpeed') && eatScriptCode.contains('MandolinBite'))) {
      return getPresetById('folk_mandolin');
    }
    if (eatScriptCode.contains('SoloViolin') || eatScriptCode.contains('solo_violin') || eatScriptCode.contains('Virtuoso Solo Violin') || (eatScriptCode.contains('BowPressure') && eatScriptCode.contains('BridgeBite'))) {
      return getPresetById('solo_violin');
    }
    if (eatScriptCode.contains('SoloViola') || eatScriptCode.contains('solo_viola') || eatScriptCode.contains('Warm Solo Viola') || (eatScriptCode.contains('BowPressure') && eatScriptCode.contains('ViolaWarmth'))) {
      return getPresetById('solo_viola');
    }
    if (eatScriptCode.contains('SoloCello') || eatScriptCode.contains('solo_cello') || eatScriptCode.contains('Deep Solo Cello') || (eatScriptCode.contains('BowPressure') && eatScriptCode.contains('ChestResonance'))) {
      return getPresetById('solo_cello');
    }
    if (eatScriptCode.contains('DoubleBass') || eatScriptCode.contains('double_bass') || eatScriptCode.contains('Orchestral Double Bass') || eatScriptCode.contains('Contrabass') || (eatScriptCode.contains('BowPressure') && eatScriptCode.contains('SubPunch'))) {
      return getPresetById('double_bass');
    }
    if (eatScriptCode.contains('StringEnsemble') || eatScriptCode.contains('string_ensemble') || eatScriptCode.contains('Symphonic String Ensemble') || eatScriptCode.contains('Orchestral Strings') || (eatScriptCode.contains('EnsembleChorus') && eatScriptCode.contains('AirSheen'))) {
      return getPresetById('string_ensemble');
    }

    if (eatScriptCode.contains('EatsVolts') || eatScriptCode.contains('eats_volts') || eatScriptCode.contains('Eats Volts') || eatScriptCode.contains('VoltaicPlasmaSynth') || eatScriptCode.contains('voltaic_plasma_synth') || eatScriptCode.contains('VOLTAIC') || eatScriptCode.contains('Plasma Arc') || eatScriptCode.contains('Singing Arc') || (eatScriptCode.contains('SparkGap') && eatScriptCode.contains('CrackleRate'))) {
      return getPresetById('eats_volts');
    }
    if (eatScriptCode.contains('EatsFurnace') || eatScriptCode.contains('eats_furnace') || eatScriptCode.contains('Eats Furnace') || eatScriptCode.contains('PyrophoneSynth') || eatScriptCode.contains('pyrophone_synth') || eatScriptCode.contains('PYROPHONE') || eatScriptCode.contains('Thermoacoustic') || eatScriptCode.contains('Singing Flame') || eatScriptCode.contains('Rijke Tube') || (eatScriptCode.contains('FuelPressure') && eatScriptCode.contains('FlameCusp'))) {
      return getPresetById('eats_furnace');
    }
    if (eatScriptCode.contains('EatsFXRain') || eatScriptCode.contains('eatsfx_rain') || eatScriptCode.contains('EatsFX Rain') || eatScriptCode.contains('EatsRain') || eatScriptCode.contains('eats_rain') || eatScriptCode.contains('Eats Rain') || eatScriptCode.contains('RainIntensity') || (eatScriptCode.contains('RainHiss') && eatScriptCode.contains('DropletForce'))) {
      return getPresetById('eatsfx_rain');
    }
    if (eatScriptCode.contains('EatsFXWind') || eatScriptCode.contains('eatsfx_wind') || eatScriptCode.contains('EatsFX Wind') || eatScriptCode.contains('EatsWind') || eatScriptCode.contains('eats_wind') || eatScriptCode.contains('Eats Wind') || eatScriptCode.contains('AeolianPitch') || (eatScriptCode.contains('GustSpeed') && eatScriptCode.contains('HowlDepth'))) {
      return getPresetById('eatsfx_wind');
    }
    if (eatScriptCode.contains('EatsFXFire') || eatScriptCode.contains('eatsfx_fire') || eatScriptCode.contains('EatsFX Fire') || eatScriptCode.contains('EatsFire') || eatScriptCode.contains('eats_fire') || eatScriptCode.contains('Eats Fire') || eatScriptCode.contains('SapCrackle') || (eatScriptCode.contains('FlameRoar') && eatScriptCode.contains('EmberSizzle'))) {
      return getPresetById('eatsfx_fire');
    }
    if (eatScriptCode.contains('EatsWater') || eatScriptCode.contains('eats_water') || eatScriptCode.contains('Eats Water') || eatScriptCode.contains('Hydraulophone') || (eatScriptCode.contains('WaterFlow') && eatScriptCode.contains('BubblePinch'))) {
      return getPresetById('eats_water');
    }
    if (eatScriptCode.contains('DX7EPiano') || eatScriptCode.contains('dx7_epiano') || eatScriptCode.contains('DX7') || eatScriptCode.contains('FullTines')) {
      return getPresetById('dx7_epiano');
    }
    if (eatScriptCode.contains('ClavinetD6') || eatScriptCode.contains('clavinet_d6') || eatScriptCode.contains('Clavinet') || eatScriptCode.contains('Hohner Clav')) {
      return getPresetById('clavinet_d6');
    }
    if (eatScriptCode.contains('TTSVoiceSynth') || eatScriptCode.contains('tts_voice_synth') || eatScriptCode.contains('TTS Voice Synth') || eatScriptCode.contains('Vocal Formant') || eatScriptCode.contains('Formant Synth')) {
      return getPresetById('tts_voice_synth');
    }
    if (eatScriptCode.contains('Harpsichord') || eatScriptCode.contains('harpsichord_cembalo') || eatScriptCode.contains('Cembalo') || eatScriptCode.contains('Virginal')) {
      return getPresetById('harpsichord_cembalo');
    }
    if (eatScriptCode.contains('ConcertGrandPiano') || eatScriptCode.contains('concert_grand_piano') || eatScriptCode.contains('Concert Grand') || eatScriptCode.contains('Grand Piano') || (eatScriptCode.contains('HammerHardness') && eatScriptCode.contains('Stiffness')) || (eatScriptCode.contains('HammerHardness') && eatScriptCode.contains('Brightness')) || (eatScriptCode.contains('HammerHardness') && eatScriptCode.contains('Soundboard') && eatScriptCode.contains('PedalReso'))) {
      return getPresetById('concert_grand_piano');
    }
    if (eatScriptCode.contains('FeltUprightPiano') || eatScriptCode.contains('felt_upright_piano') || eatScriptCode.contains('Felt Piano') || eatScriptCode.contains('Studio Upright') || (eatScriptCode.contains('FeltThickness') && eatScriptCode.contains('MechanicalThud'))) {
      return getPresetById('felt_upright_piano');
    }
    if (eatScriptCode.contains('HonkyTonkPiano') || eatScriptCode.contains('honky_tonk_piano') || eatScriptCode.contains('Honky Tonk') || eatScriptCode.contains('Tack Piano') || (eatScriptCode.contains('TackBite') && eatScriptCode.contains('ActionClack'))) {
      return getPresetById('honky_tonk_piano');
    }
    if (eatScriptCode.contains('ToyPiano') || eatScriptCode.contains('toy_piano') || eatScriptCode.contains('Toy Piano') || (eatScriptCode.contains('ClangRatio') && eatScriptCode.contains('TineDecay'))) {
      return getPresetById('toy_piano');
    }
    if (eatScriptCode.contains('Glockenspiel') || eatScriptCode.contains('glockenspiel') || (eatScriptCode.contains('BarDecay') && eatScriptCode.contains('BellShimmer')) || (eatScriptCode.contains('BellShimmer') && eatScriptCode.contains('MalletHardness'))) {
      return getPresetById('glockenspiel');
    }
    if (eatScriptCode.contains('MusicBox') || eatScriptCode.contains('music_box') || eatScriptCode.contains('Music Box') || (eatScriptCode.contains('PinScrape') && eatScriptCode.contains('BoxWarmth')) || (eatScriptCode.contains('PinScrape') && eatScriptCode.contains('HighTineRing'))) {
      return getPresetById('music_box');
    }
    if (eatScriptCode.contains('Xylophone') || eatScriptCode.contains('xylophone') || (eatScriptCode.contains('WoodDecay') && eatScriptCode.contains('TripleOctave')) || (eatScriptCode.contains('WoodDecay') && eatScriptCode.contains('ResonatorPop'))) {
      return getPresetById('xylophone');
    }
    if (eatScriptCode.contains('Vibraphone') || eatScriptCode.contains('vibraphone') || (eatScriptCode.contains('MotorSpeed') && eatScriptCode.contains('TremoloDepth')) || (eatScriptCode.contains('DoubleOctave') && eatScriptCode.contains('TremoloDepth'))) {
      return getPresetById('vibraphone');
    }
    if (eatScriptCode.contains('TinkleBell') || eatScriptCode.contains('tinkle_bell') || eatScriptCode.contains('Tinkle Bell') || eatScriptCode.contains('WindChime') || (eatScriptCode.contains('ChimeDecay') && eatScriptCode.contains('BreezeFlutter'))) {
      return getPresetById('tinkle_bell');
    }
    if (eatScriptCode.contains('Woodblock') || eatScriptCode.contains('woodblock') || eatScriptCode.contains('Wood Block') || eatScriptCode.contains('TempleBlock') || (eatScriptCode.contains('WoodDecay') && eatScriptCode.contains('CavityPop'))) {
      return getPresetById('woodblock');
    }
    if (eatScriptCode.contains('AgogoBell') || eatScriptCode.contains('agogo_bell') || eatScriptCode.contains('Agogo Bell') || eatScriptCode.contains('Agogo') || (eatScriptCode.contains('BellDecay') && eatScriptCode.contains('ClangRatio'))) {
      return getPresetById('agogo_bell');
    }
    if (eatScriptCode.contains('SteelDrums') || eatScriptCode.contains('steel_drums') || eatScriptCode.contains('Steel Drums') || eatScriptCode.contains('SteelPan') || eatScriptCode.contains('steelpan') || (eatScriptCode.contains('PanDecay') && eatScriptCode.contains('OctaveHarmonic'))) {
      return getPresetById('steel_drums');
    }
    if (eatScriptCode.contains('TaikoDrum') || eatScriptCode.contains('taiko_drum') || eatScriptCode.contains('Taiko Drum') || eatScriptCode.contains('Taiko') || eatScriptCode.contains('Surdo') || (eatScriptCode.contains('DrumDecay') && eatScriptCode.contains('PitchSag'))) {
      return getPresetById('taiko_drum');
    }
    if (eatScriptCode.contains('MelodicTom') || eatScriptCode.contains('melodic_tom') || eatScriptCode.contains('Melodic Tom') || (eatScriptCode.contains('TomDecay') && eatScriptCode.contains('HeadCoupling'))) {
      return getPresetById('melodic_tom');
    }
    if (eatScriptCode.contains('SimmonsSynthDrum') || eatScriptCode.contains('simmons_synth_drum') || eatScriptCode.contains('Simmons SDS') || eatScriptCode.contains('SynthDrum') || eatScriptCode.contains('synth_drum') || (eatScriptCode.contains('PitchDrop') && eatScriptCode.contains('SweepTime'))) {
      return getPresetById('synth_drum');
    }
    if (eatScriptCode.contains('ReverseCymbal') || eatScriptCode.contains('reverse_cymbal') || eatScriptCode.contains('Reverse Cymbal') || (eatScriptCode.contains('SwellDuration') && eatScriptCode.contains('CrescendoCurve'))) {
      return getPresetById('reverse_cymbal');
    }
    if (eatScriptCode.contains('ConcertPiccolo') || eatScriptCode.contains('concert_piccolo') || eatScriptCode.contains('Piccolo')) {
      return getPresetById('concert_piccolo');
    }
    if (eatScriptCode.contains('ConcertFlute') || eatScriptCode.contains('concert_flute') || eatScriptCode.contains('Flute')) {
      return getPresetById('concert_flute');
    }
    if (eatScriptCode.contains('WoodenRecorder') || eatScriptCode.contains('wooden_recorder') || eatScriptCode.contains('Recorder') || eatScriptCode.contains('Blockflöte')) {
      return getPresetById('wooden_recorder');
    }
    if (eatScriptCode.contains('PanFlute') || eatScriptCode.contains('pan_flute') || eatScriptCode.contains('Pan Flute') || eatScriptCode.contains('Zampoña') || eatScriptCode.contains('Siku')) {
      return getPresetById('pan_flute');
    }
    if (eatScriptCode.contains('BlownBottle') || eatScriptCode.contains('blown_bottle') || eatScriptCode.contains('Blown Bottle')) {
      return getPresetById('blown_bottle');
    }
    if (eatScriptCode.contains('Shakuhachi') || eatScriptCode.contains('shakuhachi_bamboo') || eatScriptCode.contains('Muraiki')) {
      return getPresetById('shakuhachi_bamboo');
    }
    if (eatScriptCode.contains('TinWhistle') || eatScriptCode.contains('tin_whistle') || eatScriptCode.contains('Pennywhistle') || eatScriptCode.contains('Tin Whistle')) {
      return getPresetById('tin_whistle');
    }
    if (eatScriptCode.contains('SweetOcarina') || eatScriptCode.contains('sweet_ocarina') || eatScriptCode.contains('Ocarina')) {
      return getPresetById('sweet_ocarina');
    }
    if (eatScriptCode.contains('OrchestralTrumpet') || eatScriptCode.contains('orchestral_trumpet') || eatScriptCode.contains('Trumpet')) {
      return getPresetById('orchestral_trumpet');
    }
    if (eatScriptCode.contains('TenorTrombone') || eatScriptCode.contains('tenor_trombone') || eatScriptCode.contains('Trombone')) {
      return getPresetById('tenor_trombone');
    }
    if (eatScriptCode.contains('Tuba') || eatScriptCode.contains('tuba_brass')) {
      return getPresetById('tuba_brass');
    }
    if (eatScriptCode.contains('MutedTrumpet') || eatScriptCode.contains('muted_trumpet')) {
      return getPresetById('muted_trumpet');
    }
    if (eatScriptCode.contains('FrenchHorn') || eatScriptCode.contains('french_horn') || eatScriptCode.contains('French Horn')) {
      return getPresetById('french_horn');
    }
    if (eatScriptCode.contains('BrassSection') || eatScriptCode.contains('brass_section') || eatScriptCode.contains('Brass Section')) {
      return getPresetById('brass_section');
    }
    if (eatScriptCode.contains('SopranoSax') || eatScriptCode.contains('soprano_sax') || eatScriptCode.contains('Soprano Sax')) {
      return getPresetById('soprano_sax');
    }
    if (eatScriptCode.contains('AltoSax') || eatScriptCode.contains('alto_sax') || eatScriptCode.contains('Alto Sax')) {
      return getPresetById('alto_sax');
    }
    if (eatScriptCode.contains('TenorSax') || eatScriptCode.contains('tenor_sax') || eatScriptCode.contains('Tenor Sax')) {
      return getPresetById('tenor_sax');
    }
    if (eatScriptCode.contains('BaritoneSax') || eatScriptCode.contains('baritone_sax') || eatScriptCode.contains('Baritone Sax')) {
      return getPresetById('baritone_sax');
    }
    if (eatScriptCode.contains('Oboe') || eatScriptCode.contains('oboe_woodwind')) {
      return getPresetById('oboe_woodwind');
    }
    if (eatScriptCode.contains('EnglishHorn') || eatScriptCode.contains('english_horn') || eatScriptCode.contains('English Horn')) {
      return getPresetById('english_horn');
    }
    if (eatScriptCode.contains('Bassoon') || eatScriptCode.contains('bassoon_woodwind')) {
      return getPresetById('bassoon_woodwind');
    }
    if (eatScriptCode.contains('Clarinet') || eatScriptCode.contains('clarinet_woodwind')) {
      return getPresetById('clarinet_woodwind');
    }
    if (eatScriptCode.contains('Sitar') || eatScriptCode.contains('sitar_jawari') || eatScriptCode.contains('Jawari')) {
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
