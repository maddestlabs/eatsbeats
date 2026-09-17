import '../audio/graph/graph_evaluator.dart';
import '../audio/graph/graph_node.dart';
import 'eats_synth_type.dart';

/// Descriptor for physical / graph-based DSP models in Eatsbeats.
class EatGraphModelDescriptor {
  final GraphNode Function() builder;
  final double defaultVelocity;
  final bool isPianoVelocity;

  const EatGraphModelDescriptor({
    required this.builder,
    this.defaultVelocity = 1.0,
    this.isPianoVelocity = false,
  });
}

/// Canonical registry and deterministic dispatcher for Eatscript DSP engines.
class EatEngineRegistry {
  static final RegExp _engineHeaderRegex = RegExp(
    r'(?:--|#)\s*@(?:engine|dsp|model):\s*([\w\-]+)',
    caseSensitive: false,
  );

  static final RegExp _useEngineRegex = RegExp(
    r'''eat\.(?:use_engine|engine)\s*\(\s*['"]([\w\-]+)['"]\s*\)''',
    caseSensitive: false,
  );

  /// Normalized map of canonical engine IDs to Graph Model Descriptors.
  static final Map<String, EatGraphModelDescriptor> graphModels = {
    // --- Drums & Percussion ---
    'analog_808_kick': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAnalog808Kick, defaultVelocity: 0.85),
    'analog_808_snare': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAnalog808Snare, defaultVelocity: 0.85),
    'analog_808_hihat': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAnalog808HiHat, defaultVelocity: 0.85),
    'analog_808_cowbell': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAnalog808Cowbell, defaultVelocity: 0.85),
    'analog_808_tom': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAnalog808Tom, defaultVelocity: 0.85),
    'analog_909_kick': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAnalog909Kick, defaultVelocity: 0.85),
    'analog_909_snare': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAnalog909Snare, defaultVelocity: 0.85),
    'analog_909_closed_hihat': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAnalog909ClosedHiHat, defaultVelocity: 0.85),
    'analog_909_open_hihat': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAnalog909OpenHiHat, defaultVelocity: 0.85),
    'analog_909_clap': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAnalog909Clap, defaultVelocity: 0.85),
    'analog_909_rimshot': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAnalog909Rimshot, defaultVelocity: 0.85),
    'fm_acoustic_kick': const EatGraphModelDescriptor(builder: GraphEvaluator.buildDualMicFmAcousticKick),
    'fm_acoustic_snare': const EatGraphModelDescriptor(builder: GraphEvaluator.buildDualMicFmAcousticSnare, defaultVelocity: 0.85),
    'fm_acoustic_tom': const EatGraphModelDescriptor(builder: GraphEvaluator.buildDualMicFmAcousticTom, defaultVelocity: 0.85),
    'fm_acoustic_hihat': const EatGraphModelDescriptor(builder: GraphEvaluator.buildDualMicFmAcousticHiHat, defaultVelocity: 0.85),

    // --- Keyboards & Physical Pianos ---
    'rhodes_epiano': const EatGraphModelDescriptor(builder: GraphEvaluator.buildRhodesEPiano),
    'concert_grand_piano': const EatGraphModelDescriptor(builder: GraphEvaluator.buildConcertGrandPiano, isPianoVelocity: true),
    'felt_upright_piano': const EatGraphModelDescriptor(builder: GraphEvaluator.buildFeltUprightPiano, isPianoVelocity: true),
    'honky_tonk_piano': const EatGraphModelDescriptor(builder: GraphEvaluator.buildHonkyTonkPiano, isPianoVelocity: true),
    'toy_piano': const EatGraphModelDescriptor(builder: GraphEvaluator.buildToyPiano, isPianoVelocity: true),
    'glockenspiel': const EatGraphModelDescriptor(builder: GraphEvaluator.buildGlockenspiel),
    'music_box': const EatGraphModelDescriptor(builder: GraphEvaluator.buildMusicBox),
    'xylophone': const EatGraphModelDescriptor(builder: GraphEvaluator.buildXylophone),
    'vibraphone': const EatGraphModelDescriptor(builder: GraphEvaluator.buildVibraphone),
    'tinkle_bell': const EatGraphModelDescriptor(builder: GraphEvaluator.buildTinkleBell),
    'steel_drums': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSteelDrums),
    'dx7_epiano': const EatGraphModelDescriptor(builder: GraphEvaluator.buildDX7EPiano),
    'clavinet_d6': const EatGraphModelDescriptor(builder: GraphEvaluator.buildClavinetD6),
    'harpsichord': const EatGraphModelDescriptor(builder: GraphEvaluator.buildHarpsichord),

    // --- Basses ---
    'moog_synth_bass': const EatGraphModelDescriptor(builder: GraphEvaluator.buildMoogSynthBass),
    'acoustic_bass': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAcousticBass),
    'fretless_bass': const EatGraphModelDescriptor(builder: GraphEvaluator.buildFretlessBass),
    'upright_bass': const EatGraphModelDescriptor(builder: GraphEvaluator.buildUprightBass),

    // --- Plucked Strings & Guitars ---
    'spanish_guitar': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSpanishGuitar),
    'flamenco_guitar': const EatGraphModelDescriptor(builder: GraphEvaluator.buildFlamencoGuitar),
    'steel_acoustic_guitar': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSteelAcousticGuitar),
    'twelve_string_guitar': const EatGraphModelDescriptor(builder: GraphEvaluator.buildTwelveStringGuitar),
    'dobro_resonator': const EatGraphModelDescriptor(builder: GraphEvaluator.buildDobroResonator),
    'pedal_steel_guitar': const EatGraphModelDescriptor(builder: GraphEvaluator.buildPedalSteelGuitar),
    'harp_guitar': const EatGraphModelDescriptor(builder: GraphEvaluator.buildHarpGuitar),
    'bluegrass_banjo': const EatGraphModelDescriptor(builder: GraphEvaluator.buildBluegrassBanjo),
    'folk_mandolin': const EatGraphModelDescriptor(builder: GraphEvaluator.buildFolkMandolin),
    'reggae_guitar': const EatGraphModelDescriptor(builder: GraphEvaluator.buildReggaeGuitar),
    'hawaiian_ukulele': const EatGraphModelDescriptor(builder: GraphEvaluator.buildHawaiianUkulele),
    'renaissance_lute': const EatGraphModelDescriptor(builder: GraphEvaluator.buildRenaissanceLute),
    'baroque_guitar': const EatGraphModelDescriptor(builder: GraphEvaluator.buildBaroqueGuitar),
    'solo_violin': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSoloViolin),
    'solo_viola': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSoloViola),
    'solo_cello': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSoloCello),
    'double_bass': const EatGraphModelDescriptor(builder: GraphEvaluator.buildDoubleBass),
    'string_ensemble': const EatGraphModelDescriptor(builder: GraphEvaluator.buildStringEnsemble),
    'sitar': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSitar),

    // --- Brass & Reeds ---
    'orchestral_trumpet': const EatGraphModelDescriptor(builder: GraphEvaluator.buildOrchestralTrumpet),
    'tenor_trombone': const EatGraphModelDescriptor(builder: GraphEvaluator.buildTenorTrombone),
    'tuba': const EatGraphModelDescriptor(builder: GraphEvaluator.buildTuba),
    'muted_trumpet': const EatGraphModelDescriptor(builder: GraphEvaluator.buildMutedTrumpet),
    'french_horn': const EatGraphModelDescriptor(builder: GraphEvaluator.buildFrenchHorn),
    'brass_section': const EatGraphModelDescriptor(builder: GraphEvaluator.buildBrassSection),
    'soprano_sax': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSopranoSax),
    'alto_sax': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAltoSax),
    'tenor_sax': const EatGraphModelDescriptor(builder: GraphEvaluator.buildTenorSax),
    'baritone_sax': const EatGraphModelDescriptor(builder: GraphEvaluator.buildBaritoneSax),
    'concert_flute': const EatGraphModelDescriptor(builder: GraphEvaluator.buildConcertFlute),
    'concert_piccolo': const EatGraphModelDescriptor(builder: GraphEvaluator.buildConcertPiccolo),
    'wooden_recorder': const EatGraphModelDescriptor(builder: GraphEvaluator.buildWoodenRecorder),
    'pan_flute': const EatGraphModelDescriptor(builder: GraphEvaluator.buildPanFlute),
    'tin_whistle': const EatGraphModelDescriptor(builder: GraphEvaluator.buildTinWhistle),
    'sweet_ocarina': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSweetOcarina),
    'shakuhachi': const EatGraphModelDescriptor(builder: GraphEvaluator.buildShakuhachi),
    'blown_bottle': const EatGraphModelDescriptor(builder: GraphEvaluator.buildBlownBottle),
    'oboe': const EatGraphModelDescriptor(builder: GraphEvaluator.buildOboe),
    'english_horn': const EatGraphModelDescriptor(builder: GraphEvaluator.buildEnglishHorn),
    'bassoon': const EatGraphModelDescriptor(builder: GraphEvaluator.buildBassoon),
    'clarinet': const EatGraphModelDescriptor(builder: GraphEvaluator.buildClarinet),

    // --- Chiptune & Experimental Models ---
    'c64_sid': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSIDSynth),
    'c64_sid_synth': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSIDSynth),
    'sid_synth': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSIDSynth),
    'voltaic_plasma': const EatGraphModelDescriptor(builder: GraphEvaluator.buildVoltaicPlasmaSynth, defaultVelocity: 0.85),
    'eats_furnace': const EatGraphModelDescriptor(builder: GraphEvaluator.buildEatsFurnaceSynth, defaultVelocity: 0.85),
    'fx_rain': const EatGraphModelDescriptor(builder: GraphEvaluator.buildEatsFXRainSynth, defaultVelocity: 0.85),
    'fx_wind': const EatGraphModelDescriptor(builder: GraphEvaluator.buildEatsFXWindSynth, defaultVelocity: 0.85),
    'fx_fire': const EatGraphModelDescriptor(builder: GraphEvaluator.buildEatsFXFireSynth, defaultVelocity: 0.85),
    'fx_water': const EatGraphModelDescriptor(builder: GraphEvaluator.buildEatsWaterSynth, defaultVelocity: 0.85),
    'melodic_tom': const EatGraphModelDescriptor(builder: GraphEvaluator.buildMelodicTom),
    'reverse_cymbal': const EatGraphModelDescriptor(builder: GraphEvaluator.buildReverseCymbal),
    'taiko_drum': const EatGraphModelDescriptor(builder: GraphEvaluator.buildTaikoDrum),
    'acoustic_steel_guitar': const EatGraphModelDescriptor(builder: GraphEvaluator.buildSteelAcousticGuitar),
    'harpsichord_cembalo': const EatGraphModelDescriptor(builder: GraphEvaluator.buildHarpsichord),
    'banjo': const EatGraphModelDescriptor(builder: GraphEvaluator.buildBluegrassBanjo),
    'mandolin': const EatGraphModelDescriptor(builder: GraphEvaluator.buildFolkMandolin),
    'dobro': const EatGraphModelDescriptor(builder: GraphEvaluator.buildDobroResonator),
    'pedal_steel': const EatGraphModelDescriptor(builder: GraphEvaluator.buildPedalSteelGuitar),
    'twelve_string': const EatGraphModelDescriptor(builder: GraphEvaluator.buildTwelveStringGuitar),

    // --- Ambient & Synthesizer Pads ---
    'ambient_pad': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAmbientPad, defaultVelocity: 0.9),
    'super_pad': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAmbientPad, defaultVelocity: 0.9),
    'astral_pad': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAmbientPad, defaultVelocity: 0.9),
    'analog_pad': const EatGraphModelDescriptor(builder: GraphEvaluator.buildAmbientPad, defaultVelocity: 0.9),
  };

  /// Explicit mapping for specialized synth types (TB-303, SNES, YM2612, etc.)
  static final Map<String, EatSynthType> specializedSynthTypes = {
    'tb303': EatSynthType.acid303,
    'acid303': EatSynthType.acid303,
    'eats303': EatSynthType.acid303,
    'eats_303': EatSynthType.acid303,
    'jc303': EatSynthType.acid303,
    'snes_dsp': EatSynthType.snesDsp,
    'snes_synth': EatSynthType.snesDsp,
    'snes_console_synth': EatSynthType.snesDsp,
    'ym2612': EatSynthType.ym2612,
    'ym2612_synth': EatSynthType.ym2612,
    'fm_synth': EatSynthType.fmSynth,
    'procedural_kick': EatSynthType.proceduralKick,
    'procedural_snare': EatSynthType.proceduralSnare,
    'procedural_hihat': EatSynthType.proceduralHiHat,
    'gm_drum_kit': EatSynthType.gmDrumKit,
    'snes_drum_kit': EatSynthType.snesDrumKit,
    'sid_drum_kit': EatSynthType.sidDrumKit,
    'c64_sid_drum_kit': EatSynthType.sidDrumKit,
    'poly_synth': EatSynthType.polySynth,
    'poly_lead': EatSynthType.polySynth,
    'sub_bass_synth': EatSynthType.polySynth,
  };

  /// Explicit mapping for audio effects.
  static final Map<String, EatFxType> audioFxTypes = {
    'stereo_delay': EatFxType.stereoDelay,
    'delay': EatFxType.stereoDelay,
    'stereo_chorus': EatFxType.stereoChorus,
    'chorus': EatFxType.stereoChorus,
    'snes_downsample': EatFxType.snesDownsample,
    'snes_downsampler': EatFxType.snesDownsample,
    'bitcrusher': EatFxType.bitcrush,
    'bitcrush': EatFxType.bitcrush,
    'tube_distortion': EatFxType.tubeDistortion,
    'distortion': EatFxType.tubeDistortion,
    'lowpass': EatFxType.lowpass,
    'cab_designer': EatFxType.fallback,
    'compressor': EatFxType.fallback,
    'sidechain_compressor': EatFxType.fallback,
    'limiter': EatFxType.fallback,
    'brickwall_limiter': EatFxType.fallback,
    'parametric_eq': EatFxType.fallback,
    'multimode_filter': EatFxType.fallback,
  };

  static final RegExp _idHeaderRegex = RegExp(
    r'(?:--|#)\s*@id:\s*([\w\-]+)',
    caseSensitive: false,
  );

  /// Detects an explicitly declared engine ID from code headers or `eat.use_engine(...)`.
  static String? detectEngineId(String code) {
    final headerMatch = _engineHeaderRegex.firstMatch(code);
    if (headerMatch != null) {
      return normalizeId(headerMatch.group(1)!);
    }

    final fnMatch = _useEngineRegex.firstMatch(code);
    if (fnMatch != null) {
      return normalizeId(fnMatch.group(1)!);
    }

    final idMatch = _idHeaderRegex.firstMatch(code);
    if (idMatch != null) {
      final normId = normalizeId(idMatch.group(1)!);
      if (isRegistered(normId)) {
        return normId;
      }
    }

    return null;
  }

  /// Normalizes any raw engine string into snake_case format.
  static String normalizeId(String id) {
    return id.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  /// Checks if a given normalized engine ID is recognized.
  static bool isRegistered(String id) {
    final norm = normalizeId(id);
    return graphModels.containsKey(norm) ||
        specializedSynthTypes.containsKey(norm) ||
        audioFxTypes.containsKey(norm);
  }

  /// Returns a sorted list of all unique registered engine IDs.
  static List<String> get allEngineIds {
    final ids = <String>{
      ...graphModels.keys,
      ...specializedSynthTypes.keys,
      ...audioFxTypes.keys,
    };
    return ids.toList()..sort();
  }
}

