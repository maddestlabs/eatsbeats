import 'dart:math' as math;
import 'dart:typed_data';

import '../audio/drum/gm_drum_kit_engine.dart';
import '../audio/fm_chip_engine.dart';
import '../audio/graph/graph_evaluator.dart';
import '../audio/snes_dsp_engine.dart';
import '../audio/time_context.dart';
import '../models/automation_model.dart';
import '../models/track_model.dart';
import '../audio/sid_dsp_engine.dart';
import 'eats_synth_type.dart';
import 'eats_tb303_core.dart';
import 'eats_engine_registry.dart';

typedef EatSynthBufferExecutor = Float32List Function({
  required double durationSec,
  required double freq,
  required int note,
  required Map<String, double> params,
  int? targetMidiNote,
  bool isSlide,
  bool isAccent,
  String? trackId,
  String? articulation,
  double releaseVelocity,
  List<List<double>>? pitchBendPoints,
  List<List<double>>? pressurePoints,
  List<List<double>>? timbrePoints,
  double velocity,
});

typedef _GraphModelDescriptor = EatGraphModelDescriptor;


/// Pure-Dart DSP Synthesis Engine for Eatscript instruments, drums, physical models & automation.
class EatDspSynthesizer {
  static final Map<String, EatSynthBufferExecutor> _bufferExecutorCache = {};
  static final Map<String, EatSynthType> _synthTypeCache = {};
  static final Map<String, EatFxType> _fxTypeCache = {};
  static final Map<String, AutomationScriptType> _automationScriptTypeCache = {};
  static final Map<String, RegExp> _paramRegexCache = {};
  static final Map<String, Map<String, double?>> _automationParamCache = {};

  static void clearDispatchCaches() {
    _bufferExecutorCache.clear();
    _synthTypeCache.clear();
    _fxTypeCache.clear();
    _automationScriptTypeCache.clear();
    _paramRegexCache.clear();
    _automationParamCache.clear();
  }

  static RegExp _getParamRegex(String name) =>
      _paramRegexCache.putIfAbsent(name, () => RegExp('$name\\s*=\\s*([\\d\\.-]+)', caseSensitive: false));

  static EatSynthType resolveSynthType(String code) {
    final cached = _synthTypeCache[code];
    if (cached != null) return cached;
    _resolveBufferExecutor(code);
    return _synthTypeCache[code] ?? EatSynthType.defaultSynth;
  }

  static EatFxType resolveFxType(String code) {
    return _fxTypeCache.putIfAbsent(code, () => _detectFxType(code));
  }

  static AutomationScriptType resolveAutomationScriptType(String code) {
    return _automationScriptTypeCache.putIfAbsent(code, () => _detectAutomationScriptType(code));
  }

  static double _fastRnd(int seed) {
    int x = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return (x / 2147483647.0) * 2.0 - 1.0;
  }

  static double _tanh(double x) {
    if (x.isNaN) return 0.0;
    if (x > 3.0) return 1.0;
    if (x < -3.0) return -1.0;
    final x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);
  }

  /// Evaluates a 4-stage ADSR envelope at [time] seconds.
  /// [attack]: Attack time in seconds (0.0 to N)
  /// [decay]: Decay time in seconds (0.0 to N)
  /// [sustain]: Sustain gain level (0.0 to 1.0)
  /// [release]: Release time in seconds (0.001 to N)
  /// [duration]: Note active gate duration before release phase (default 0.4s)
  static double evaluateAdsr(
    double time,
    double attack,
    double decay,
    double sustain,
    double release, [
    double duration = 0.4,
  ]) {
    final a = math.max(0.0, attack);
    final d = math.max(0.001, decay);
    final s = sustain.clamp(0.0, 1.0);
    final r = math.max(0.001, release);
    final gate = math.max(a + d, duration);

    if (time < a) {
      if (a <= 0.0001) return 1.0;
      return (time / a).clamp(0.0, 1.0);
    } else if (time < a + d) {
      final decayProgress = (time - a) / d;
      return 1.0 - (decayProgress * (1.0 - s));
    } else if (time < gate) {
      return s;
    } else {
      final releaseProgress = (time - gate) / r;
      return (s * math.max(0.0, 1.0 - releaseProgress)).clamp(0.0, 1.0);
    }
  }

  /// Evaluates a 2-stage Attack-Release envelope at [time] seconds.
  static double evaluateEnv(
    double time,
    double attack,
    double release, [
    double duration = 0.4,
  ]) {
    return evaluateAdsr(time, attack, 0.001, 1.0, release, duration);
  }

  static final Map<String, _HiHatVoiceState> _hihatVoiceStates = {};
  static final Map<String, _SnareVoiceState> _snareVoiceStates = {};
  static final Map<String, FMChipVoice> _fmChipVoices = {};
  static final Map<String, SNESDSPEngine> _snesDspEngines = {};

  /// Resets persistent DSP voice states for a given [trackId] or all tracks when loading/transitioning songs.
  static void resetVoiceStates([String? trackId]) {
    GmDrumKitEngine.resetVoiceStates(trackId);
    if (trackId != null) {
      EatsTb303Core.clearVoice(trackId);
      _hihatVoiceStates.remove(trackId);
      _snareVoiceStates.remove(trackId);
      _fmChipVoices.remove(trackId);
      _snesDspEngines.remove(trackId);
    } else {
      EatsTb303Core.clearAllVoices();
      _hihatVoiceStates.clear();
      _snareVoiceStates.clear();
      _fmChipVoices.clear();
      _snesDspEngines.clear();
    }
  }

  static Float32List synthesizeBuffer({
    required String code,
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    int? fromMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
    EatSynthType? synthType,
  }) {
    final effSynthType = synthType ?? resolveSynthType(code);
    if (effSynthType == EatSynthType.acid303) {
      return _synthesizeAcid303Buffer(
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        targetMidiNote: targetMidiNote,
        fromMidiNote: fromMidiNote,
        isSlide: isSlide,
        isAccent: isAccent,
        trackId: trackId,
        articulation: articulation,
        releaseVelocity: releaseVelocity,
        pitchBendPoints: pitchBendPoints,
        pressurePoints: pressurePoints,
        timbrePoints: timbrePoints,
        velocity: velocity,
      );
    }

    final cached = _bufferExecutorCache[code];
    if (cached != null) {
      return cached(
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        targetMidiNote: targetMidiNote,
        isSlide: isSlide,
        isAccent: isAccent,
        trackId: trackId,
        articulation: articulation,
        releaseVelocity: releaseVelocity,
        pitchBendPoints: pitchBendPoints,
        pressurePoints: pressurePoints,
        timbrePoints: timbrePoints,
        velocity: velocity,
      );
    }

    final executor = _resolveBufferExecutor(code);
    return executor(
      durationSec: durationSec,
      freq: freq,
      note: note,
      params: params,
      targetMidiNote: targetMidiNote,
      isSlide: isSlide,
      isAccent: isAccent,
      trackId: trackId,
      articulation: articulation,
      releaseVelocity: releaseVelocity,
      pitchBendPoints: pitchBendPoints,
      pressurePoints: pressurePoints,
      timbrePoints: timbrePoints,
      velocity: velocity,
    );
  }

  static _GraphModelDescriptor? _detectGraphModel(String code) {
    // 1. Explicit deterministic engine resolution first
    final explicitId = EatEngineRegistry.detectEngineId(code);
    if (explicitId != null && EatEngineRegistry.graphModels.containsKey(explicitId)) {
      return EatEngineRegistry.graphModels[explicitId];
    }

    // 2. Legacy heuristic fallback
    if (code.contains('FmAcousticKick') ||
        code.contains('NearPitchStart') ||
        code.contains('fm_acoustic_kick') ||
        code.contains('Dual-Mic FM Acoustic Kick')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildDualMicFmAcousticKick);
    }
    if (code.contains('FmAcousticSnare') ||
        code.contains('fm_acoustic_snare') ||
        code.contains('Dual-Mic FM Acoustic Snare') ||
        code.contains('WireCutoff')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildDualMicFmAcousticSnare, defaultVelocity: 0.85);
    }
    if (code.contains('FmAcousticTom') ||
        code.contains('fm_acoustic_tom') ||
        code.contains('FM Acoustic Tom') ||
        code.contains('TomPitchStart')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildDualMicFmAcousticTom, defaultVelocity: 0.85);
    }
    if (code.contains('FmAcousticHiHat') ||
        code.contains('fm_acoustic_hihat') ||
        code.contains('FM Acoustic Hi-Hat')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildDualMicFmAcousticHiHat, defaultVelocity: 0.85);
    }
    if (code.contains('Analog808Kick') ||
        code.contains('analog_808_kick') ||
        code.contains('Analog 808 Kick')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAnalog808Kick, defaultVelocity: 0.85);
    }
    if (code.contains('Analog808Snare') ||
        code.contains('analog_808_snare') ||
        code.contains('Analog 808 Snare')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAnalog808Snare, defaultVelocity: 0.85);
    }
    if (code.contains('Analog808HiHat') ||
        code.contains('analog_808_hihat') ||
        code.contains('Analog 808 Hi-Hat')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAnalog808HiHat, defaultVelocity: 0.85);
    }
    if (code.contains('Analog808Cowbell') ||
        code.contains('analog_808_cowbell') ||
        code.contains('Analog 808 Cowbell')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAnalog808Cowbell, defaultVelocity: 0.85);
    }
    if (code.contains('Analog808Tom') ||
        code.contains('analog_808_tom') ||
        code.contains('Analog 808 Tom')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAnalog808Tom, defaultVelocity: 0.85);
    }
    if (code.contains('Analog909Kick') ||
        code.contains('analog_909_kick') ||
        code.contains('Analog 909 Kick')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAnalog909Kick, defaultVelocity: 0.85);
    }
    if (code.contains('Analog909Snare') ||
        code.contains('analog_909_snare') ||
        code.contains('Analog 909 Snare')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAnalog909Snare, defaultVelocity: 0.85);
    }
    if (code.contains('Analog909ClosedHiHat') ||
        code.contains('analog_909_closed_hihat') ||
        code.contains('Analog 909 Closed Hi-Hat') ||
        code.contains('Analog909HiHat') ||
        code.contains('analog_909_hihat') ||
        code.contains('Analog 909 Hi-Hat')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAnalog909ClosedHiHat, defaultVelocity: 0.85);
    }
    if (code.contains('Analog909OpenHiHat') ||
        code.contains('analog_909_open_hihat') ||
        code.contains('Analog 909 Open Hi-Hat')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAnalog909OpenHiHat, defaultVelocity: 0.85);
    }
    if (code.contains('Analog909Clap') ||
        code.contains('analog_909_clap') ||
        code.contains('Analog 909 Clap') ||
        code.contains('Analog 909 Handclap')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAnalog909Clap, defaultVelocity: 0.85);
    }
    if (code.contains('Analog909Rimshot') ||
        code.contains('analog_909_rimshot') ||
        code.contains('Analog 909 Rimshot')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAnalog909Rimshot, defaultVelocity: 0.85);
    }
    if (code.contains('RhodesEPiano') ||
        code.contains('rhodes_epiano') ||
        code.contains('Rhodes Mark I') ||
        code.contains('Rhodes E-Piano') ||
        code.contains('Stage 73') ||
        (code.contains('TineBell') && code.contains('PickupDistance'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildRhodesEPiano);
    }
    if (code.contains('ConcertGrandPiano') ||
        code.contains('concert_grand_piano') ||
        code.contains('Concert Grand') ||
        code.contains('Grand Piano') ||
        code.contains('Steinway') ||
        (code.contains('HammerHardness') && code.contains('Stiffness')) ||
        (code.contains('HammerHardness') && code.contains('Brightness')) ||
        (code.contains('HammerHardness') && code.contains('Soundboard') && code.contains('PedalReso'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildConcertGrandPiano, isPianoVelocity: true);
    }
    if (code.contains('FeltUprightPiano') ||
        code.contains('felt_upright_piano') ||
        code.contains('Felt Piano') ||
        code.contains('Upright Piano') ||
        code.contains('Studio Upright') ||
        (code.contains('FeltThickness') && code.contains('MechanicalThud'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildFeltUprightPiano, isPianoVelocity: true);
    }
    if (code.contains('HonkyTonkPiano') ||
        code.contains('honky_tonk_piano') ||
        code.contains('Honky Tonk') ||
        code.contains('Tack Piano') ||
        code.contains('Saloon Piano') ||
        (code.contains('TackBite') && code.contains('ActionClack'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildHonkyTonkPiano, isPianoVelocity: true);
    }
    if (code.contains('ToyPiano') ||
        code.contains('toy_piano') ||
        code.contains('Toy Piano') ||
        code.contains('Metallophone') ||
        (code.contains('ClangRatio') && code.contains('TineDecay'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildToyPiano, isPianoVelocity: true);
    }
    if (code.contains('Glockenspiel') ||
        code.contains('glockenspiel') ||
        (code.contains('BarDecay') && code.contains('BellShimmer')) ||
        (code.contains('BellShimmer') && code.contains('MalletHardness'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildGlockenspiel);
    }
    if (code.contains('MusicBox') ||
        code.contains('music_box') ||
        code.contains('Music Box') ||
        (code.contains('PinScrape') && code.contains('BoxWarmth')) ||
        (code.contains('PinScrape') && code.contains('HighTineRing'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildMusicBox);
    }
    if (code.contains('Xylophone') ||
        code.contains('xylophone') ||
        (code.contains('WoodDecay') && code.contains('TripleOctave')) ||
        (code.contains('WoodDecay') && code.contains('ResonatorPop'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildXylophone);
    }
    if (code.contains('Vibraphone') ||
        code.contains('vibraphone') ||
        (code.contains('MotorSpeed') && code.contains('TremoloDepth')) ||
        (code.contains('DoubleOctave') && code.contains('TremoloDepth'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildVibraphone);
    }
    if (code.contains('TinkleBell') ||
        code.contains('tinkle_bell') ||
        code.contains('Tinkle Bell') ||
        code.contains('WindChime') ||
        code.contains('Wind Chime') ||
        (code.contains('ChimeDecay') && code.contains('BreezeFlutter')) ||
        (code.contains('ChimeDecay') && code.contains('GlassAir'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildTinkleBell);
    }
    if (code.contains('Woodblock') ||
        code.contains('woodblock') ||
        code.contains('Wood Block') ||
        code.contains('TempleBlock') ||
        code.contains('Temple Block') ||
        (code.contains('WoodDecay') && code.contains('CavityPop')) ||
        (code.contains('WoodHardness') && code.contains('SlitTuning'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildWoodblock);
    }
    if (code.contains('AgogoBell') ||
        code.contains('agogo_bell') ||
        code.contains('Agogo Bell') ||
        code.contains('Agogo') ||
        (code.contains('BellDecay') && code.contains('ClangRatio') && code.contains('StickHardness'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAgogoBell);
    }
    if (code.contains('SteelDrums') ||
        code.contains('steel_drums') ||
        code.contains('Steel Drums') ||
        code.contains('SteelPan') ||
        code.contains('Steel Pan') ||
        code.contains('steelpan') ||
        (code.contains('PanDecay') && code.contains('OctaveHarmonic')) ||
        (code.contains('BowlSympathy') && code.contains('MalletSoftness'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildSteelDrums);
    }
    if (code.contains('TaikoDrum') ||
        code.contains('taiko_drum') ||
        code.contains('Taiko Drum') ||
        code.contains('Taiko') ||
        code.contains('Surdo') ||
        (code.contains('DrumDecay') && code.contains('PitchSag') && code.contains('BachiImpact')) ||
        (code.contains('BarrelBoom') && code.contains('BachiImpact'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildTaikoDrum);
    }
    if (code.contains('MelodicTom') ||
        code.contains('melodic_tom') ||
        code.contains('Melodic Tom') ||
        (code.contains('TomDecay') && code.contains('HeadCoupling')) ||
        (code.contains('HeadCoupling') && code.contains('StickCrack'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildMelodicTom);
    }
    if (code.contains('SimmonsSynthDrum') ||
        code.contains('simmons_synth_drum') ||
        code.contains('Simmons SDS') ||
        code.contains('SynthDrum') ||
        code.contains('synth_drum') ||
        code.contains('Synth Drum') ||
        (code.contains('PitchDrop') && code.contains('SweepTime')) ||
        (code.contains('ClickLevel') && code.contains('FilterReso'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildSimmonsSynthDrum);
    }
    if (code.contains('ReverseCymbal') ||
        code.contains('reverse_cymbal') ||
        code.contains('Reverse Cymbal') ||
        (code.contains('SwellDuration') && code.contains('CrescendoCurve')) ||
        (code.contains('CrescendoCurve') && code.contains('ChokeSnap'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildReverseCymbal);
    }
    if (code.contains('ReggaeGuitar') ||
        code.contains('reggae_guitar') ||
        code.contains('Reggae Skank') ||
        code.contains('Dub Chop') ||
        code.contains('SkankGuitar') ||
        code.contains('DubGuitar') ||
        (code.contains('PalmDamp') && code.contains('StrumSpread'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildReggaeGuitar);
    }
    if (code.contains('HawaiianUkulele') ||
        code.contains('hawaiian_ukulele') ||
        code.contains('Ukulele') ||
        (code.contains('PluckSnap') && code.contains('StrumSpread'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildHawaiianUkulele);
    }
    if (code.contains('SpanishGuitar') ||
        code.contains('spanish_guitar') ||
        code.contains('ClassicalGuitar') ||
        code.contains('classical_guitar') ||
        code.contains('Spanish Guitar') ||
        code.contains('Classical Guitar') ||
        (code.contains('FleshNail') && code.contains('AirResonance'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildSpanishGuitar);
    }
    if (code.contains('RenaissanceLute') ||
        code.contains('renaissance_lute') ||
        code.contains('BaroqueLute') ||
        code.contains('baroque_lute') ||
        code.contains('Lute') ||
        code.contains('Vihuela') ||
        (code.contains('CourseDetune') && code.contains('BowlWarmth'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildRenaissanceLute);
    }
    if (code.contains('BaroqueGuitar') ||
        code.contains('baroque_guitar') ||
        code.contains('5-Course Guitar') ||
        code.contains('Chitarra Spagnola') ||
        (code.contains('RoseBite') && code.contains('RasgueadoSpeed'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildBaroqueGuitar);
    }
    if (code.contains('FlamencoGuitar') ||
        code.contains('flamenco_guitar') ||
        code.contains('Guitarra Flamenca') ||
        code.contains('Flamenco') ||
        (code.contains('GolpeTap') && code.contains('SnapDamp'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildFlamencoGuitar);
    }
    if (code.contains('SteelAcousticGuitar') ||
        code.contains('acoustic_steel_guitar') ||
        code.contains('Acoustic Guitar') ||
        code.contains('Steel Guitar') ||
        code.contains('Dreadnought') ||
        (code.contains('BodyProfile') && code.contains('BronzeSparkle'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildSteelAcousticGuitar);
    }
    if (code.contains('TwelveStringGuitar') ||
        code.contains('twelve_string_guitar') ||
        code.contains('12-String') ||
        code.contains('12 String') ||
        (code.contains('ChorusDetune') && code.contains('OctavePairing'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildTwelveStringGuitar);
    }
    if (code.contains('DobroResonator') ||
        code.contains('dobro_resonator') ||
        code.contains('Dobro') ||
        code.contains('Resonator Guitar') ||
        (code.contains('ConeType') && code.contains('MetalBark'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildDobroResonator);
    }
    if (code.contains('PedalSteelGuitar') ||
        code.contains('pedal_steel_guitar') ||
        code.contains('Pedal Steel') ||
        code.contains('Lap Steel') ||
        (code.contains('VolumeSwell') && code.contains('BarVibrato'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildPedalSteelGuitar);
    }
    if (code.contains('HarpGuitar') ||
        code.contains('harp_guitar') ||
        code.contains('Harp Guitar') ||
        (code.contains('SubDroneGain') && code.contains('PickStyle'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildHarpGuitar);
    }
    if (code.contains('BluegrassBanjo') ||
        code.contains('bluegrass_banjo') ||
        code.contains('Banjo') ||
        code.contains('5-String Banjo') ||
        (code.contains('HeadTension') && code.contains('TwangSnap'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildBluegrassBanjo);
    }
    if (code.contains('FolkMandolin') ||
        code.contains('folk_mandolin') ||
        code.contains('Mandolin') ||
        (code.contains('TremoloSpeed') && code.contains('MandolinBite'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildFolkMandolin);
    }
    if (code.contains('SoloViolin') ||
        code.contains('solo_violin') ||
        code.contains('Virtuoso Solo Violin') ||
        (code.contains('BowPressure') && code.contains('BridgeBite'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildSoloViolin);
    }
    if (code.contains('SoloViola') ||
        code.contains('solo_viola') ||
        code.contains('Warm Solo Viola') ||
        (code.contains('BowPressure') && code.contains('ViolaWarmth'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildSoloViola);
    }
    if (code.contains('SoloCello') ||
        code.contains('solo_cello') ||
        code.contains('Deep Solo Cello') ||
        (code.contains('BowPressure') && code.contains('ChestResonance'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildSoloCello);
    }
    if ((code.contains('DoubleBass') ||
        code.contains('double_bass') ||
        code.contains('Orchestral Double Bass') ||
        code.contains('Contrabass') ||
        (code.contains('BowPressure') && code.contains('SubPunch'))) &&
        !code.contains('upright_bass') &&
        !code.contains('UprightBass') &&
        !code.contains('Upright Double Bass') &&
        !code.contains('FingerMass')) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildDoubleBass);
    }
    if (code.contains('StringEnsemble') ||
        code.contains('string_ensemble') ||
        code.contains('Symphonic String Ensemble') ||
        code.contains('Orchestral Strings') ||
        (code.contains('EnsembleChorus') && code.contains('AirSheen'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildStringEnsemble);
    }
    if (code.contains('VoltaicPlasmaSynth') ||
        code.contains('voltaic_plasma_synth') ||
        code.contains('EatsVolts') ||
        code.contains('eats_volts') ||
        code.contains('Eats Volts') ||
        code.contains('VOLTAIC') ||
        code.contains('Plasma Arc') ||
        code.contains('Singing Arc') ||
        (code.contains('SparkGap') && code.contains('CrackleRate'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildVoltaicPlasmaSynth, defaultVelocity: 0.85);
    }
    if (code.contains('EatsFurnace') ||
        code.contains('eats_furnace') ||
        code.contains('Eats Furnace') ||
        code.contains('PyrophoneSynth') ||
        code.contains('pyrophone_synth') ||
        code.contains('PYROPHONE') ||
        code.contains('Thermoacoustic') ||
        code.contains('Singing Flame') ||
        code.contains('Rijke Tube') ||
        (code.contains('FuelPressure') && code.contains('FlameCusp'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildEatsFurnaceSynth, defaultVelocity: 0.85);
    }
    if (code.contains('EatsFXRain') ||
        code.contains('eatsfx_rain') ||
        code.contains('EatsFX Rain') ||
        code.contains('EatsRain') ||
        code.contains('eats_rain') ||
        code.contains('Eats Rain') ||
        code.contains('RainIntensity') ||
        (code.contains('RainHiss') && code.contains('DropletForce'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildEatsFXRainSynth, defaultVelocity: 0.85);
    }
    if (code.contains('EatsFXWind') ||
        code.contains('eatsfx_wind') ||
        code.contains('EatsFX Wind') ||
        code.contains('EatsWind') ||
        code.contains('eats_wind') ||
        code.contains('Eats Wind') ||
        code.contains('AeolianPitch') ||
        (code.contains('GustSpeed') && code.contains('HowlDepth'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildEatsFXWindSynth, defaultVelocity: 0.85);
    }
    if (code.contains('EatsFXFire') ||
        code.contains('eatsfx_fire') ||
        code.contains('EatsFX Fire') ||
        code.contains('EatsFire') ||
        code.contains('eats_fire') ||
        code.contains('Eats Fire') ||
        code.contains('SapCrackle') ||
        (code.contains('FlameRoar') && code.contains('EmberSizzle'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildEatsFXFireSynth, defaultVelocity: 0.85);
    }
    if (code.contains('EatsWaterSynth') ||
        code.contains('eats_water') ||
        code.contains('EatsWater') ||
        code.contains('Eats Water') ||
        code.contains('Hydraulophone') ||
        code.contains('Minnaert') ||
        (code.contains('WaterFlow') && code.contains('BubblePinch'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildEatsWaterSynth, defaultVelocity: 0.85);
    }
    if (code.contains('DX7EPiano') ||
        code.contains('dx7_epiano') ||
        code.contains('DX7') ||
        code.contains('FullTines') ||
        (code.contains('Algorithm') && code.contains('TineBell') && code.contains('BodyWarmth'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildDX7EPiano);
    }
    if (code.contains('C64SID') ||
        code.contains('c64_sid') ||
        code.contains('MOS6581') ||
        code.contains('MOS8580') ||
        code.contains('Commodore 64') ||
        (code.contains('PulseWidth') && code.contains('PwmRate') && code.contains('ArpMode'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildSIDSynth);
    }
    if (code.contains('ClavinetD6') ||
        code.contains('clavinet_d6') ||
        code.contains('Clavinet') ||
        code.contains('Hohner Clav') ||
        (code.contains('PickupSelect') && code.contains('Brilliant') && code.contains('Treble'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildClavinetD6);
    }
    if (code.contains('Harpsichord') ||
        code.contains('harpsichord_cembalo') ||
        code.contains('Cembalo') ||
        code.contains('Virginal') ||
        (code.contains('PluckBite') && code.contains('Stop4Octave'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildHarpsichord);
    }
    if (code.contains('AcousticBass') ||
        code.contains('acoustic_bass') ||
        code.contains('Acoustic Bass') ||
        (code.contains('PluckForce') && code.contains('AcousticAir'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAcousticBass);
    }
    if (code.contains('FretlessBass') ||
        code.contains('fretless_bass') ||
        code.contains('Fretless') ||
        (code.contains('MwahAmount') && code.contains('BridgePickup'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildFretlessBass);
    }
    if (code.contains('UprightBass') ||
        code.contains('upright_bass') ||
        code.contains('DoubleBass') ||
        code.contains('Upright Bass') ||
        code.contains('acoustic_upright_bass') ||
        (code.contains('FingerMass') && (code.contains('SlapClick') || code.contains('FingerFlesh')))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildUprightBass);
    }
    if (code.contains('MoogSynthBass') ||
        code.contains('moog_synth_bass') ||
        code.contains('Model D') ||
        code.contains('Sub Synth Bass') ||
        (code.contains('FilterEnv') && code.contains('AmpDecay') && code.contains('Resonance'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildMoogSynthBass);
    }
    if (code.contains('ConcertPiccolo') ||
        code.contains('concert_piccolo') ||
        (code.contains('ChiffAttack') && code.contains('AirTurbulence') && code.contains('BoreResonance'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildConcertPiccolo);
    }
    if (code.contains('ConcertFlute') ||
        code.contains('concert_flute') ||
        (code.contains('EmbouchureChiff') && code.contains('SilverWarmth'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildConcertFlute);
    }
    if (code.contains('WoodenRecorder') ||
        code.contains('wooden_recorder') ||
        (code.contains('FippleChiff') && code.contains('WoodWarmth'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildWoodenRecorder);
    }
    if (code.contains('PanFlute') ||
        code.contains('pan_flute') ||
        (code.contains('CaneResonance') && code.contains('BreathAir'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildPanFlute);
    }
    if (code.contains('BlownBottle') ||
        code.contains('blown_bottle') ||
        (code.contains('GlassTone') && code.contains('MouthChiff'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildBlownBottle);
    }
    if (code.contains('Shakuhachi') ||
        code.contains('shakuhachi_bamboo') ||
        (code.contains('MuraikiBreath') && code.contains('BambooWarmth'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildShakuhachi);
    }
    if (code.contains('TinWhistle') ||
        code.contains('tin_whistle') ||
        (code.contains('ChirpChiff') && code.contains('TinBodyTone'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildTinWhistle);
    }
    if (code.contains('SweetOcarina') ||
        code.contains('sweet_ocarina') ||
        (code.contains('CeramicSweetness') && code.contains('SoftChiff'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildSweetOcarina);
    }
    if (code.contains('OrchestralTrumpet') ||
        code.contains('orchestral_trumpet') ||
        code.contains('Trumpet') ||
        (code.contains('BrassBite') && code.contains('LipTension'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildOrchestralTrumpet);
    }
    if (code.contains('TenorTrombone') ||
        code.contains('tenor_trombone') ||
        code.contains('Trombone') ||
        (code.contains('SlidePresence') && code.contains('Warmth'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildTenorTrombone);
    }
    if (code.contains('Tuba') ||
        code.contains('tuba_brass') ||
        (code.contains('SubChest') && code.contains('TubaBody'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildTuba);
    }
    if (code.contains('MutedTrumpet') ||
        code.contains('muted_trumpet') ||
        (code.contains('HarmonBite') && code.contains('StemDepth'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildMutedTrumpet);
    }
    if (code.contains('FrenchHorn') ||
        code.contains('french_horn') ||
        code.contains('French Horn') ||
        (code.contains('HornWarmth') && code.contains('BellMellow'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildFrenchHorn);
    }
    if (code.contains('BrassSection') ||
        code.contains('brass_section') ||
        code.contains('Brass Section') ||
        (code.contains('EnsembleAir') && code.contains('BreathPressure'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildBrassSection);
    }
    if (code.contains('SopranoSax') ||
        code.contains('soprano_sax') ||
        code.contains('Soprano Sax') ||
        (code.contains('ReedBite') && code.contains('ReedStiffness'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildSopranoSax);
    }
    if (code.contains('AltoSax') ||
        code.contains('alto_sax') ||
        code.contains('Alto Sax') ||
        (code.contains('SaxBody') && code.contains('ReedBite'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildAltoSax);
    }
    if (code.contains('TenorSax') ||
        code.contains('tenor_sax') ||
        code.contains('Tenor Sax') ||
        (code.contains('SmokyWarmth') && code.contains('TenorPresence'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildTenorSax);
    }
    if (code.contains('BaritoneSax') ||
        code.contains('baritone_sax') ||
        code.contains('Baritone Sax') ||
        (code.contains('BariWeight') && code.contains('BariBark'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildBaritoneSax);
    }
    if (code.contains('Oboe') ||
        code.contains('oboe_woodwind') ||
        (code.contains('NasalFormant1') && code.contains('NasalFormant2'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildOboe);
    }
    if (code.contains('EnglishHorn') ||
        code.contains('english_horn') ||
        code.contains('English Horn') ||
        (code.contains('PearBellWarmth') && code.contains('DoubleReedSweetness'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildEnglishHorn);
    }
    if (code.contains('Bassoon') ||
        code.contains('bassoon_woodwind') ||
        (code.contains('MapleBore') && code.contains('BassoonFormant'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildBassoon);
    }
    if (code.contains('Clarinet') ||
        code.contains('clarinet_woodwind') ||
        (code.contains('BlackwoodCore') && code.contains('ChalumeauWarmth'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildClarinet);
    }
    if (code.contains('Sitar') ||
        code.contains('sitar_jawari') ||
        (code.contains('JawariBuzz') && code.contains('TumbaResonance'))) {
      return const _GraphModelDescriptor(builder: GraphEvaluator.buildSitar);
    }
    return null;
  }

  static EatSynthBufferExecutor _resolveBufferExecutor(String code) {
    // 1. Explicit deterministic engine resolution
    final explicitId = EatEngineRegistry.detectEngineId(code);
    if (explicitId != null) {
      if (explicitId == 'tb303' || explicitId == 'acid303' || explicitId == 'eats303' || explicitId == 'jc303') {
        _synthTypeCache[code] = EatSynthType.acid303;
        return _bufferExecutorCache[code] = _synthesizeAcid303Buffer;
      }
      if (explicitId == 'procedural_kick') {
        _synthTypeCache[code] = EatSynthType.proceduralKick;
        return _bufferExecutorCache[code] = _synthesizeProceduralKickBuffer;
      }
      if (explicitId == 'procedural_snare') {
        _synthTypeCache[code] = EatSynthType.proceduralSnare;
        return _bufferExecutorCache[code] = _synthesizeProceduralSnareBuffer;
      }
      if (explicitId == 'procedural_hihat') {
        _synthTypeCache[code] = EatSynthType.proceduralHiHat;
        return _bufferExecutorCache[code] = _synthesizeProceduralHiHatBuffer;
      }
      if (explicitId == 'fm_synth') {
        _synthTypeCache[code] = EatSynthType.fmSynth;
        return _bufferExecutorCache[code] = _synthesizeFmSynthBuffer;
      }
      if (explicitId == 'snes_dsp' || explicitId == 'snes_synth') {
        _synthTypeCache[code] = EatSynthType.snesDsp;
        return _bufferExecutorCache[code] = ({
          required double durationSec,
          required double freq,
          required int note,
          required Map<String, double> params,
          int? targetMidiNote,
          bool isSlide = false,
          bool isAccent = false,
          String? trackId,
          String? articulation,
          double releaseVelocity = 0.5,
          List<List<double>>? pitchBendPoints,
          List<List<double>>? pressurePoints,
          List<List<double>>? timbrePoints,
          double velocity = 0.9,
        }) => _synthesizeSnesDspBuffer(
          code: code,
          durationSec: durationSec,
          freq: freq,
          note: note,
          params: params,
          targetMidiNote: targetMidiNote,
          isSlide: isSlide,
          isAccent: isAccent,
          trackId: trackId,
          articulation: articulation,
          releaseVelocity: releaseVelocity,
          pitchBendPoints: pitchBendPoints,
          pressurePoints: pressurePoints,
          timbrePoints: timbrePoints,
          velocity: velocity,
        );
      }
      if (explicitId == 'ym2612') {
        _synthTypeCache[code] = EatSynthType.ym2612;
        return _bufferExecutorCache[code] = _synthesizeYm2612Buffer;
      }
      if (explicitId == 'poly_synth' || explicitId == 'poly_lead' || explicitId == 'sub_bass_synth') {
        _synthTypeCache[code] = EatSynthType.polySynth;
        return _bufferExecutorCache[code] = _synthesizePolySynthBuffer;
      }
      if (explicitId == 'gm_drum_kit') {
        _synthTypeCache[code] = EatSynthType.gmDrumKit;
        return _bufferExecutorCache[code] = ({
          required double durationSec,
          required double freq,
          required int note,
          required Map<String, double> params,
          int? targetMidiNote,
          bool isSlide = false,
          bool isAccent = false,
          String? trackId,
          String? articulation,
          double releaseVelocity = 0.5,
          List<List<double>>? pitchBendPoints,
          List<List<double>>? pressurePoints,
          List<List<double>>? timbrePoints,
          double velocity = 0.9,
        }) => GmDrumKitEngine.synthesizeBuffer(
          note: note,
          durationSec: durationSec,
          velocity: isAccent ? 1.0 : velocity,
          params: params,
          isAccent: isAccent,
          trackId: trackId,
        );
      }
      if (explicitId == 'snes_drum_kit') {
        _synthTypeCache[code] = EatSynthType.snesDrumKit;
        return _bufferExecutorCache[code] = ({
          required double durationSec,
          required double freq,
          required int note,
          required Map<String, double> params,
          int? targetMidiNote,
          bool isSlide = false,
          bool isAccent = false,
          String? trackId,
          String? articulation,
          double releaseVelocity = 0.5,
          List<List<double>>? pitchBendPoints,
          List<List<double>>? pressurePoints,
          List<List<double>>? timbrePoints,
          double velocity = 0.9,
        }) => SNESDrumKitEngine.synthesizeBuffer(
          note: note,
          durationSec: durationSec,
          velocity: isAccent ? 1.0 : velocity,
          params: params,
          isAccent: isAccent,
        );
      }
      if (explicitId == 'sid_drum_kit') {
        _synthTypeCache[code] = EatSynthType.sidDrumKit;
        return _bufferExecutorCache[code] = ({
          required double durationSec,
          required double freq,
          required int note,
          required Map<String, double> params,
          int? targetMidiNote,
          bool isSlide = false,
          bool isAccent = false,
          String? trackId,
          String? articulation,
          double releaseVelocity = 0.5,
          List<List<double>>? pitchBendPoints,
          List<List<double>>? pressurePoints,
          List<List<double>>? timbrePoints,
          double velocity = 0.9,
        }) => SIDDrumKitEngine.synthesizeBuffer(
          note: note,
          durationSec: durationSec,
          velocity: isAccent ? 1.0 : velocity,
          params: params,
        );
      }
      if (EatEngineRegistry.graphModels.containsKey(explicitId)) {
        final desc = EatEngineRegistry.graphModels[explicitId]!;
        _synthTypeCache[code] = EatSynthType.physicalModel;
        return _bufferExecutorCache[code] = ({
          required double durationSec,
          required double freq,
          required int note,
          required Map<String, double> params,
          int? targetMidiNote,
          bool isSlide = false,
          bool isAccent = false,
          String? trackId,
          String? articulation,
          double releaseVelocity = 0.5,
          List<List<double>>? pitchBendPoints,
          List<List<double>>? pressurePoints,
          List<List<double>>? timbrePoints,
          double velocity = 0.9,
        }) {
          final vel = desc.isPianoVelocity
              ? (isAccent && velocity <= 0.85 ? (velocity * 1.2).clamp(0.0, 1.0) : velocity)
              : (desc.defaultVelocity != 1.0
                  ? (isAccent ? 1.0 : desc.defaultVelocity)
                  : (isAccent ? 1.0 : velocity));

          return GraphEvaluator.evaluate(
            root: desc.builder(),
            durationSec: durationSec,
            freq: freq,
            note: note,
            params: params,
            velocity: vel,
            isAccent: isAccent,
            isSlide: isSlide,
            targetMidiNote: targetMidiNote,
            articulation: articulation,
            releaseVelocity: releaseVelocity,
            pitchBendPoints: pitchBendPoints,
            pressurePoints: pressurePoints,
            timbrePoints: timbrePoints,
          );
        };
      }
    }

    // 2. Legacy heuristic fallback
    // 0a. General MIDI Standard Drum Kit & Modular Drum Machine (Notes 35–81)
    if (code.contains('gm_standard_drum_kit') ||
        code.contains('GmStandardDrumKit') ||
        code.contains('GM Standard Drum Kit') ||
        code.contains('modular_drumpad_kit') ||
        code.contains('ModularDrumpadKit') ||
        code.contains('Modular Drum Machine')) {
      _synthTypeCache[code] = EatSynthType.gmDrumKit;
      return _bufferExecutorCache[code] = ({
        required double durationSec,
        required double freq,
        required int note,
        required Map<String, double> params,
        int? targetMidiNote,
        bool isSlide = false,
        bool isAccent = false,
        String? trackId,
        String? articulation,
        double releaseVelocity = 0.5,
        List<List<double>>? pitchBendPoints,
        List<List<double>>? pressurePoints,
        List<List<double>>? timbrePoints,
        double velocity = 0.9,
      }) => GmDrumKitEngine.synthesizeBuffer(
        note: note,
        durationSec: durationSec,
        velocity: isAccent ? 1.0 : velocity,
        params: params,
        isAccent: isAccent,
        trackId: trackId,
      );
    }

    // 0a-2. 16-Bit S-DSP Console Drum Kit (Notes 35–81)
    if (code.contains('snes_drum_kit') ||
        code.contains('SNESDrumKit') ||
        code.contains('SNES Drum Kit')) {
      _synthTypeCache[code] = EatSynthType.snesDrumKit;
      return _bufferExecutorCache[code] = ({
        required double durationSec,
        required double freq,
        required int note,
        required Map<String, double> params,
        int? targetMidiNote,
        bool isSlide = false,
        bool isAccent = false,
        String? trackId,
        String? articulation,
        double releaseVelocity = 0.5,
        List<List<double>>? pitchBendPoints,
        List<List<double>>? pressurePoints,
        List<List<double>>? timbrePoints,
        double velocity = 0.9,
      }) => SNESDrumKitEngine.synthesizeBuffer(
        note: note,
        durationSec: durationSec,
        velocity: isAccent ? 1.0 : velocity,
        params: params,
        isAccent: isAccent,
      );
    }

    // 0a-3. Commodore 64 SID Chiptune Drum Kit (Notes 35–81)
    if (code.contains('c64_sid_drum_kit') ||
        code.contains('SIDDrumKit') ||
        code.contains('C64 SID Drum Kit')) {
      _synthTypeCache[code] = EatSynthType.sidDrumKit;
      return _bufferExecutorCache[code] = ({
        required double durationSec,
        required double freq,
        required int note,
        required Map<String, double> params,
        int? targetMidiNote,
        bool isSlide = false,
        bool isAccent = false,
        String? trackId,
        String? articulation,
        double releaseVelocity = 0.5,
        List<List<double>>? pitchBendPoints,
        List<List<double>>? pressurePoints,
        List<List<double>>? timbrePoints,
        double velocity = 0.9,
      }) => SIDDrumKitEngine.synthesizeBuffer(
        note: note,
        durationSec: durationSec,
        velocity: isAccent ? 1.0 : velocity,
        params: params,
      );
    }

    // Physical Acoustic & Analog 808 Graph Models
    final modelDesc = _detectGraphModel(code);
    if (modelDesc != null) {
      _synthTypeCache[code] = EatSynthType.physicalModel;
      return _bufferExecutorCache[code] = ({
        required double durationSec,
        required double freq,
        required int note,
        required Map<String, double> params,
        int? targetMidiNote,
        bool isSlide = false,
        bool isAccent = false,
        String? trackId,
        String? articulation,
        double releaseVelocity = 0.5,
        List<List<double>>? pitchBendPoints,
        List<List<double>>? pressurePoints,
        List<List<double>>? timbrePoints,
        double velocity = 0.9,
      }) {
        final vel = modelDesc.isPianoVelocity
            ? (isAccent && velocity <= 0.85 ? (velocity * 1.2).clamp(0.0, 1.0) : velocity)
            : (modelDesc.defaultVelocity != 1.0
                ? (isAccent ? 1.0 : modelDesc.defaultVelocity)
                : (isAccent ? 1.0 : velocity));

        return GraphEvaluator.evaluate(
          root: modelDesc.builder(),
          durationSec: durationSec,
          freq: freq,
          note: note,
          params: params,
          velocity: vel,
          isAccent: isAccent,
          isSlide: isSlide,
          targetMidiNote: targetMidiNote,
          articulation: articulation,
          releaseVelocity: releaseVelocity,
          pitchBendPoints: pitchBendPoints,
          pressurePoints: pressurePoints,
          timbrePoints: timbrePoints,
        );
      };
    }

    // Procedural Kick
    if (code.contains('ProceduralKick') || code.contains('StartFreq')) {
      _synthTypeCache[code] = EatSynthType.proceduralKick;
      return _bufferExecutorCache[code] = _synthesizeProceduralKickBuffer;
    }

    // Eats303 Acid Bass
    if (code.contains('Eats303') ||
        code.contains('Eats-303') ||
        code.contains('eats_303') ||
        code.contains('JC303') ||
        code.contains('JC-303') ||
        code.contains('Acid303') ||
        code.contains('TB303') ||
        ((code.contains('Overdrive') || code.contains('Drive')) &&
            code.contains('Resonance') &&
            code.contains('Slide'))) {
      _synthTypeCache[code] = EatSynthType.acid303;
      return _bufferExecutorCache[code] = _synthesizeAcid303Buffer;
    }

    // Procedural Snare
    if (code.contains('ProceduralSnare') || code.contains('Snappy')) {
      _synthTypeCache[code] = EatSynthType.proceduralSnare;
      return _bufferExecutorCache[code] = _synthesizeProceduralSnareBuffer;
    }

    // Procedural Hi-Hat
    if (code.contains('ProceduralHiHat') || code.contains('Metallic')) {
      _synthTypeCache[code] = EatSynthType.proceduralHiHat;
      return _bufferExecutorCache[code] = _synthesizeProceduralHiHatBuffer;
    }

    // Dual-Op FM Synth
    if (code.contains('FMSynth') || code.contains('ModRatio')) {
      _synthTypeCache[code] = EatSynthType.fmSynth;
      return _bufferExecutorCache[code] = _synthesizeFmSynthBuffer;
    }

    // SNES S-DSP / SFXR
    if (code.contains('SNES') ||
        code.contains('S-DSP') ||
        code.contains('SPC700') ||
        code.contains('SNESSFX') ||
        code.contains('SFXR')) {
      _synthTypeCache[code] = EatSynthType.snesDsp;
      return _bufferExecutorCache[code] = ({
        required double durationSec,
        required double freq,
        required int note,
        required Map<String, double> params,
        int? targetMidiNote,
        bool isSlide = false,
        bool isAccent = false,
        String? trackId,
        String? articulation,
        double releaseVelocity = 0.5,
        List<List<double>>? pitchBendPoints,
        List<List<double>>? pressurePoints,
        List<List<double>>? timbrePoints,
        double velocity = 0.9,
      }) => _synthesizeSnesDspBuffer(
        code: code,
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        targetMidiNote: targetMidiNote,
        isSlide: isSlide,
        isAccent: isAccent,
        trackId: trackId,
        articulation: articulation,
        releaseVelocity: releaseVelocity,
        pitchBendPoints: pitchBendPoints,
        pressurePoints: pressurePoints,
        timbrePoints: timbrePoints,
        velocity: velocity,
      );
    }

    // YM2612 FM Chip
    if (code.contains('YM2612') ||
        code.contains('OPN2') ||
        code.contains('OPL3') ||
        code.contains('FMChip')) {
      _synthTypeCache[code] = EatSynthType.ym2612;
      return _bufferExecutorCache[code] = _synthesizeYm2612Buffer;
    }

    // Poly Synth / Sub Bass / Poly Lead
    if (code.contains('PolyLeadSynth') ||
        code.contains('poly_synth') ||
        code.contains('poly_lead') ||
        code.contains('Poly Synth') ||
        code.contains('Poly Lead Synth') ||
        code.contains('sub_bass_synth') ||
        code.contains('SubBassSynth')) {
      _synthTypeCache[code] = EatSynthType.polySynth;
      return _bufferExecutorCache[code] = _synthesizePolySynthBuffer;
    }

    // Default Fallback Synth
    _synthTypeCache[code] = EatSynthType.defaultSynth;
    return _bufferExecutorCache[code] = _synthesizeFallbackSynthBuffer;
  }

  static Float32List _synthesizeProceduralKickBuffer({
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
  }) {
    final int numSamples = (44100 * durationSec).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);

      final startF = params['StartFreq'] ?? 160.0;
      final endF = params['EndFreq'] ?? 42.0;
      final pDecay = (params['PitchDecay'] ?? 0.035).clamp(0.005, 0.5);
      final aDecay = (params['AmpDecay'] ?? 0.35).clamp(0.01, 10.0);
      final click = params['Click'] ?? 0.0;
      final fadeSamples = (44100 * 0.04).toInt().clamp(64, math.max(1, numSamples ~/ 4));

      for (int i = 0; i < numSamples; i++) {
        final time = i / 44100.0;
        final curFreq = endF + (startF - endF) * math.exp(-time / pDecay);
        final subSine = math.sin(2.0 * math.pi * curFreq * time);
        final clickTransient = _fastRnd(i * 1664525 + 1013904223) * math.exp(-time * 150.0) * click;
        final env = math.exp(-time * 4.0 / aDecay);
        final rawOutput = (subSine * 0.85 + clickTransient * 0.15) * env;

        final samplesRemaining = numSamples - 1 - i;
        double boundaryFade = 1.0;
        if (samplesRemaining < fadeSamples) {
          final norm = (samplesRemaining / fadeSamples).clamp(0.0, 1.0);
          boundaryFade = 0.5 * (1.0 - math.cos(math.pi * norm));
        }
        buffer[i] = _tanh(rawOutput * boundaryFade * 1.3);
      }
      return buffer;
  }
  static Float32List _synthesizeAcid303Buffer({
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    int? fromMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
  }) {
    return EatsTb303Core.synthesizeBuffer(
      durationSec: durationSec,
      freq: freq,
      note: note,
      params: params,
      targetMidiNote: targetMidiNote,
      fromMidiNote: fromMidiNote,
      isSlide: isSlide,
      isAccent: isAccent,
      trackId: trackId,
      articulation: articulation,
      releaseVelocity: releaseVelocity,
      pitchBendPoints: pitchBendPoints,
      pressurePoints: pressurePoints,
      timbrePoints: timbrePoints,
      velocity: velocity,
    );
  }
  static Float32List _synthesizeProceduralSnareBuffer({
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
  }) {
    final int numSamples = (44100 * durationSec).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);

      double toneFreq = params['ToneFreq'] ?? 185.0;
      double snappy = params['Snappy'] ?? 0.65;
      double decay = params['Decay'] ?? 0.18;
      final variation = params['Variation'] ?? 0.0;

      if (variation > 0.001) {
        final vOffset = (math.sin(note * 12.9898) * 0.5 + 0.5) * variation;
        toneFreq = toneFreq * (1.0 + (vOffset - 0.5 * variation) * 0.08);
        decay = decay * (1.0 + (vOffset - 0.5 * variation) * 0.15);
      }

      final voiceKey = '${trackId ?? "default"}_snare';
      final vState = _snareVoiceStates.putIfAbsent(voiceKey, () => _SnareVoiceState());
      vState.x1 = 0.0;
      vState.y1 = 0.0;

      final alpha = 1.0 / (1.0 + (2.0 * math.pi * 1800.0 / 44100.0));
      final decaySafe = math.max(0.01, decay);

      for (int i = 0; i < numSamples; i++) {
        final time = i / 44100.0;
        final sweepFreq = toneFreq * (1.0 + 1.2 * math.exp(-time * 60.0));
        final body = math.sin(2.0 * math.pi * sweepFreq * time) * math.exp(-time * 22.0);
        final overtone = math.sin(2.0 * math.pi * (toneFreq * 1.75) * time) * math.exp(-time * 30.0) * 0.35;
        final tonalCore = body + overtone;

        final noise = _fastRnd(i * 1664525 + 1013904223);
        final noiseEnv = math.exp(-time / decaySafe);

        vState.y1 = alpha * (vState.y1 + noise - vState.x1);
        vState.x1 = noise;
        final filteredNoise = vState.y1 * noiseEnv;

        final click = _fastRnd(i * 1103515245 + 12345) * math.exp(-time * 250.0) * 0.25;
        final output = (tonalCore * (1.0 - snappy * 0.6) + filteredNoise * (snappy * 1.2) + click);
        buffer[i] = _tanh(output * 1.3);
      }
      return buffer;
  }
  static Float32List _synthesizeProceduralHiHatBuffer({
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
  }) {
    final int numSamples = (44100 * durationSec).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);

      double cutoff = params['Cutoff'] ?? 7500.0;
      double decay = params['Decay'] ?? 0.06;
      final metallic = params['Metallic'] ?? 0.15;
      final variation = params['Variation'] ?? 0.0;

      if (variation > 0.001) {
        final vOffset = (math.sin(note * 78.233) * 0.5 + 0.5) * variation;
        cutoff = (cutoff * (1.0 + (vOffset - 0.5 * variation) * 0.12)).clamp(1000.0, 18000.0);
        decay = decay * (1.0 + (vOffset - 0.5 * variation) * 0.18);
      }

      final voiceKey = '${trackId ?? "default"}_hihat';
      final vState = _hihatVoiceStates.putIfAbsent(voiceKey, () => _HiHatVoiceState());
      vState.x1 = 0.0;
      vState.y1 = 0.0;
      vState.x2 = 0.0;
      vState.y2 = 0.0;

      final alpha = 1.0 / (1.0 + (2.0 * math.pi * cutoff.clamp(1000.0, 18000.0) / 44100.0));
      final decaySafe = math.max(0.005, decay);

      for (int i = 0; i < numSamples; i++) {
        final time = i / 44100.0;
        final env = math.exp(-time / decaySafe);
        final noise = _fastRnd(i * 1664525 + 1013904223);

        final ring1 = math.sin(2.0 * math.pi * 320.0 * time);
        final ring2 = math.sin(2.0 * math.pi * 540.0 * time);
        final ring3 = math.sin(2.0 * math.pi * 890.0 * time);
        final metallicRing = (ring1 + ring2 + ring3) * 0.333;

        final rawSignal = noise * (1.0 - metallic * 0.3) + metallicRing * (metallic * 0.3);

        vState.y1 = alpha * (vState.y1 + rawSignal - vState.x1);
        vState.x1 = rawSignal;

        vState.y2 = alpha * (vState.y2 + vState.y1 - vState.x2);
        vState.x2 = vState.y1;

        final output = _tanh(vState.y2 * env * 1.1);
        buffer[i] = output.clamp(-1.0, 1.0);
      }
      return buffer;
  }
  static Float32List _synthesizeFmSynthBuffer({
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
  }) {
    final int numSamples = (44100 * durationSec).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);

      if (freq <= 0) return buffer;
      final ratio = params['ModRatio'] ?? 2.0;
      final index = params['ModIndex'] ?? 3.5;
      final attack = params['Attack'] ?? 0.005;
      final release = params['Release'] ?? 0.4;
      final modFreq = freq * ratio;

      for (int i = 0; i < numSamples; i++) {
        final time = i / 44100.0;
        double env = 1.0;
        if (time < attack) {
          env = time / attack;
        } else {
          env = math.exp(-(time - attack) / release);
        }

        final modulator = math.sin(2.0 * math.pi * modFreq * time) * (index * env);
        final carrier = math.sin(2.0 * math.pi * freq * time + modulator);
        buffer[i] = (carrier * env * 0.8).clamp(-1.0, 1.0);
      }
      return buffer;
  }
  static Float32List _synthesizeSnesDspBuffer({
    required String code,
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
  }) {
    final int numSamples = (44100 * durationSec).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);

      final voiceKey = trackId ?? 'default_snes';
      final dsp = _snesDspEngines.putIfAbsent(voiceKey, () => SNESDSPEngine());

      final seed = (params['Seed'] ?? 42.0).toInt();
      if (code.contains('SNESConsole') || code.contains('SNES Synth') || (!params.containsKey('SFXType') && !code.contains('SNESSFX') && !code.contains('Laser') && !code.contains('Explosion') && !code.contains('Powerup') && !code.contains('Coin') && !code.contains('Jump') && !code.contains('Hurt') && !code.contains('Lose') && !code.contains('Button') && !code.contains('Warp'))) {
        dsp.reset();
        final v = dsp.voices[0];
        v.startFreqMult = 1.0;
        v.endFreqMult = 1.0;
        v.sweepDuration = 0.0;
        v.noiseEnabled = false;
        v.noiseMix = 0.0;
        v.vibratoRate = 0.0;
        v.vibratoDepth = 0.0;
        v.arpeggioNotes = const [];
      } else if (params.containsKey('SFXType')) {
        final sfxIdx = params['SFXType']!.toInt().clamp(0, 10);
        SNESSFXRGenerator.configureFromType(dsp, sfxIdx, seed: seed);
      } else if (code.contains('Laser')) {
        SNESSFXRGenerator.configureLaser(dsp, DeterministicPRNG(seed));
      } else if (code.contains('Explosion')) {
        SNESSFXRGenerator.configureExplosion(dsp, DeterministicPRNG(seed));
      } else if (code.contains('Powerup')) {
        SNESSFXRGenerator.configurePowerup(dsp, DeterministicPRNG(seed));
      } else if (code.contains('Coin')) {
        SNESSFXRGenerator.configureCoin(dsp, DeterministicPRNG(seed));
      } else if (code.contains('Jump')) {
        SNESSFXRGenerator.configureJump(dsp, DeterministicPRNG(seed));
      } else if (code.contains('Hurt')) {
        SNESSFXRGenerator.configureHurt(dsp, DeterministicPRNG(seed));
      } else if (code.contains('Lose')) {
        SNESSFXRGenerator.configureLose(dsp, DeterministicPRNG(seed));
      } else if (code.contains('Button')) {
        SNESSFXRGenerator.configureButton(dsp, DeterministicPRNG(seed));
      } else if (code.contains('Warp')) {
        SNESSFXRGenerator.configureWarp(dsp, DeterministicPRNG(seed));
      } else {
        dsp.reset();
      }

      final v0 = dsp.voices[0];
      final isCustom = (params['SFXType']?.toInt() ?? 10) == 10;

      if (params.containsKey('Waveform')) {
        final wIdx = params['Waveform']!.toInt().clamp(0, SNESWaveform.values.length - 1);
        v0.waveform = SNESWaveform.values[wIdx];
      }
      if (params.containsKey('Attack')) {
        v0.attack = params['Attack']!.clamp(0.0005, 2.0);
      }
      if (params.containsKey('Decay')) {
        v0.decay = params['Decay']!.clamp(0.005, 3.0);
      }
      if (params.containsKey('Sustain')) {
        v0.sustain = params['Sustain']!.clamp(0.0, 1.0);
      }
      if (params.containsKey('Release')) {
        v0.release = params['Release']!.clamp(0.005, 3.0);
      }
      if (params.containsKey('PitchSweep')) {
        final sweep = params['PitchSweep']!;
        if (isCustom) {
          if (sweep >= 0) {
            v0.startFreqMult = 1.0;
            v0.endFreqMult = 1.0 + sweep;
          } else {
            v0.startFreqMult = 1.0 - sweep;
            v0.endFreqMult = 1.0;
          }
        } else if (sweep != 0.0) {
          v0.endFreqMult = (v0.endFreqMult + sweep).clamp(0.02, 10.0);
        }
      }
      if (params.containsKey('SweepSpeed')) {
        v0.sweepDuration = params['SweepSpeed']!.clamp(0.005, 2.0);
      }
      if (params.containsKey('VibratoRate') && (isCustom || params['VibratoRate']! > 0.0)) {
        v0.vibratoRate = params['VibratoRate']!.clamp(0.0, 30.0);
      }
      if (params.containsKey('VibratoDepth') && (isCustom || params['VibratoDepth']! > 0.0)) {
        v0.vibratoDepth = params['VibratoDepth']!.clamp(0.0, 2.0);
      }
      if (params.containsKey('ArpSpeed')) {
        v0.arpeggioSpeed = params['ArpSpeed']!.clamp(0.01, 1.0);
      }
      if (params.containsKey('EchoDelay')) {
        dsp.echo.delayMs = params['EchoDelay']!.toInt().clamp(16, 480);
      }
      if (params.containsKey('EchoFeedback')) {
        dsp.echo.feedback = params['EchoFeedback']!.clamp(0.0, 0.95);
      }
      if (params.containsKey('EchoVolume')) {
        final evol = params['EchoVolume']!.clamp(0.0, 1.0);
        dsp.echo.volume = evol;
        dsp.echo.enabled = evol > 0.01;
      }
      if (params.containsKey('NoiseMix')) {
        v0.noiseMix = params['NoiseMix']!.clamp(0.0, 1.0);
      }

      for (final entry in params.entries) {
        if (entry.key.startsWith('reg_0x') || entry.key.startsWith('0x')) {
          final regHex = entry.key.replaceFirst('reg_', '');
          final regAddr = int.tryParse(regHex);
          if (regAddr != null) {
            dsp.writeRegister(regAddr, entry.value.toInt());
          }
        }
      }

      for (int i = 0; i < numSamples; i++) {
        final stereo = dsp.evaluateStereoSample(
          time: i / 44100.0,
          baseFreq: freq,
          duration: durationSec,
          sampleIndex: i,
        );
        buffer[i] = ((stereo[0] + stereo[1]) * 0.5).clamp(-1.0, 1.0);
      }
      return buffer;
  }
  static Float32List _synthesizeYm2612Buffer({
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
  }) {
    final int numSamples = (44100 * durationSec).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);

      final voiceKey = trackId ?? 'default_fm';
      final voice = _fmChipVoices.putIfAbsent(voiceKey, () => FMChipVoice());

      voice.algorithm = (params['Algorithm'] ?? 4.0).toInt().clamp(0, 7);
      voice.feedback = (params['Feedback'] ?? 4.0).toInt().clamp(0, 7);

      voice.operators[0].multiplier = params['Op1_Mult'] ?? 1.0;
      voice.operators[0].totalLevel = params['Op1_TL'] ?? 10.0;
      voice.operators[0].attack = params['Op1_Attack'] ?? 0.005;
      voice.operators[0].decay = params['Op1_Decay'] ?? 0.3;

      voice.operators[1].multiplier = params['Op2_Mult'] ?? 2.0;
      voice.operators[1].totalLevel = params['Op2_TL'] ?? 0.0;
      voice.operators[1].attack = params['Op2_Attack'] ?? 0.005;
      voice.operators[1].decay = params['Op2_Decay'] ?? 0.35;

      voice.operators[2].multiplier = params['Op3_Mult'] ?? 3.0;
      voice.operators[2].totalLevel = params['Op3_TL'] ?? 20.0;

      voice.operators[3].multiplier = params['Op4_Mult'] ?? 1.0;
      voice.operators[3].totalLevel = params['Op4_TL'] ?? 0.0;

      for (final entry in params.entries) {
        if (entry.key.startsWith('reg_0x') || entry.key.startsWith('0x')) {
          final regHex = entry.key.replaceFirst('reg_', '');
          final regAddr = int.tryParse(regHex);
          if (regAddr != null) {
            voice.writeRegister(0, regAddr, entry.value.toInt());
          }
        }
      }

      for (int i = 0; i < numSamples; i++) {
        buffer[i] = voice.evaluateSample(
          time: i / 44100.0,
          baseFreq: freq,
          duration: durationSec,
          sampleIndex: i,
        );
      }
      return buffer;
  }
  static double _resolveParam(Map<String, double> params, List<String> aliases, double fallback) {
    for (final a in aliases) {
      if (params.containsKey(a)) return params[a]!;
    }
    for (final a in aliases) {
      final cleanA = a.toLowerCase().replaceAll('_', '');
      for (final entry in params.entries) {
        final cleanKey = entry.key.toLowerCase().replaceAll('_', '');
        if (cleanKey == cleanA) return entry.value;
      }
    }
    return fallback;
  }

  static Float32List _synthesizePolySynthBuffer({
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
  }) {
    final int numSamples = (44100 * durationSec).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);

    if (freq <= 0) return buffer;

    // 1. Resolve Waveform & Oscillator Parameters
    final double rawWaveform = _resolveParam(params, ['waveform', 'osc_type', 'shape', 'osc', 'wave'], 0.0);
    final int waveIdx = rawWaveform.round().clamp(0, 5);
    final double pulseWidth = _resolveParam(params, ['pulse_width', 'pw', 'pwm'], 0.5).clamp(0.05, 0.95);
    final double subLevel = _resolveParam(params, ['sub_level', 'sub_osc', 'sub'], 0.0).clamp(0.0, 1.0);
    final double subOctave = _resolveParam(params, ['sub_octave', 'sub_oct'], 1.0);
    final double subWaveform = _resolveParam(params, ['sub_waveform', 'sub_wave', 'sub_shape'], 0.0);
    final bool subIsSquare = subWaveform >= 0.5;
    final double detune = _resolveParam(params, ['detune', 'detune_cents', 'osc2_detune'], 0.0).clamp(0.0, 50.0);
    final double osc2Mix = _resolveParam(params, ['osc2_mix', 'detune_mix', 'osc_mix'], 0.5).clamp(0.0, 1.0);

    // 2. Resolve Envelopes (ADSR)
    final double attack = _resolveParam(params, ['attack', 'amp_attack', 'a'], 0.005).clamp(0.0005, 5.0);
    final double decay = _resolveParam(params, ['decay', 'amp_decay', 'd'], 0.15).clamp(0.005, 10.0);
    final double sustain = _resolveParam(params, ['sustain', 'amp_sustain', 's'], 0.75).clamp(0.0, 1.0);
    final double release = _resolveParam(params, ['release', 'amp_release', 'r'], 0.20).clamp(0.005, 10.0);

    // 3. Resolve State-Variable Filter (SVF) Parameters
    final double cutoff = _resolveParam(params, ['cutoff', 'filter_cutoff', 'fc'], 5000.0).clamp(20.0, 20000.0);
    final double resonance = _resolveParam(params, ['resonance', 'reso', 'q'], 1.5).clamp(0.1, 10.0);
    final double filterEnv = _resolveParam(params, ['filter_env', 'env_mod', 'filter_mod'], 0.0).clamp(-2.0, 2.0);
    final double filterDecay = _resolveParam(params, ['filter_decay', 'f_decay'], 0.25).clamp(0.01, 5.0);
    final int filterMode = _resolveParam(params, ['filter_mode', 'f_mode', 'mode'], 0.0).round().clamp(0, 2);

    // 4. Resolve Saturation, Drive & Articulation
    final double drive = _resolveParam(params, ['drive', 'distortion', 'saturation'], 0.0).clamp(0.0, 10.0);

    final art = articulation?.toLowerCase();
    final isStaccato = (art == 'muted' || art == 'palm_mute' || art == 'staccato');
    final baseFreq = (art == 'harmonics') ? freq * 2.0 : freq;
    final double? targetFreq = (isSlide && targetMidiNote != null && targetMidiNote > 0)
        ? 440.0 * math.pow(2.0, (targetMidiNote - 69) / 12.0)
        : null;

    final subMult = (subOctave >= 1.5) ? 0.25 : 0.5;
    final bool hasDetune = detune > 0.001;
    final double detuneRatio = hasDetune ? math.pow(2.0, detune / 1200.0).toDouble() : 1.0;

    double phase1 = 0.0;
    double phase2 = 0.0;
    double subPhase = 0.0;
    double low = 0.0;
    double band = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final time = i / 44100.0;
      final normTime = numSamples > 1 ? i / (numSamples - 1) : 0.0;

      final bend = Note.interpolateCurve(pitchBendPoints, normTime, 0.0);
      final press = Note.interpolateCurve(pressurePoints, normTime, velocity);
      final timbre = Note.interpolateCurve(timbrePoints, normTime, 0.5);

      // Pitch glide interpolation
      double curF = baseFreq;
      if (targetFreq != null) {
        final glideNorm = (normTime * 1.5).clamp(0.0, 1.0);
        curF = baseFreq + (targetFreq - baseFreq) * glideNorm;
      }
      final curFreq = math.max(10.0, curF * math.pow(2.0, bend / 12.0));
      final subFreq = curFreq * subMult;

      // Phase accumulators
      phase1 = (phase1 + (curFreq / 44100.0)) % 1.0;
      subPhase = (subPhase + (subFreq / 44100.0)) % 1.0;

      // Osc 1 wave calculation
      double osc1;
      switch (waveIdx) {
        case 0: // Saw
          osc1 = 2.0 * phase1 - 1.0;
          break;
        case 1: // Sine
          osc1 = math.sin(2.0 * math.pi * phase1);
          break;
        case 2: // Square
          osc1 = phase1 < 0.5 ? 1.0 : -1.0;
          break;
        case 3: // Triangle
          osc1 = 2.0 * (2.0 * (phase1 - (phase1 + 0.5).floorToDouble())).abs() - 1.0;
          break;
        case 4: // Pulse
          osc1 = phase1 < pulseWidth ? 1.0 : -1.0;
          break;
        case 5: // Noise
        default:
          osc1 = _fastRnd(i * 1103515245 + 12345);
          break;
      }

      double osc = osc1;

      // Osc 2 (Dual Osc Detune) - zero cost when detune == 0
      if (hasDetune && waveIdx != 5) {
        phase2 = (phase2 + ((curFreq * detuneRatio) / 44100.0)) % 1.0;
        double osc2;
        switch (waveIdx) {
          case 0:
            osc2 = 2.0 * phase2 - 1.0;
            break;
          case 1:
            osc2 = math.sin(2.0 * math.pi * phase2);
            break;
          case 2:
            osc2 = phase2 < 0.5 ? 1.0 : -1.0;
            break;
          case 3:
            osc2 = 2.0 * (2.0 * (phase2 - (phase2 + 0.5).floorToDouble())).abs() - 1.0;
            break;
          case 4:
            osc2 = phase2 < pulseWidth ? 1.0 : -1.0;
            break;
          default:
            osc2 = 2.0 * phase2 - 1.0;
            break;
        }
        osc = osc1 * (1.0 - osc2Mix * 0.5) + osc2 * (osc2Mix * 0.5);
      }

      // Add Sub-Oscillator (Octave -1 / -2 sine or square)
      if (subLevel > 0.001) {
        final subSig = subIsSquare
            ? (subPhase < 0.5 ? 1.0 : -1.0)
            : math.sin(2.0 * math.pi * subPhase);
        osc += subSig * subLevel;
      }

      // Dynamic Envelopes: Amp ADSR and Filter Decay Envelope
      double env = evaluateAdsr(time, attack, decay, sustain, release, durationSec);
      if (isStaccato) {
        env *= math.exp(-time / 0.08);
      }
      final filterEnvContour = math.exp(-time / filterDecay);

      // Resonant State-Variable Lowpass / Bandpass / Highpass Filter (Chamberlin SVF)
      final double dynCutoff = (cutoff * math.pow(2.0, filterEnv * 2.5 * filterEnvContour + (timbre - 0.5) * 1.5)).clamp(20.0, 20000.0);
      final double f = (2.0 * math.sin(math.pi * (dynCutoff / 44100.0))).clamp(0.001, 0.85);
      final double q = (1.0 / resonance).clamp(0.05, 10.0);

      low += f * band;
      final double high = osc - low - q * band;
      band += f * high;

      double filtered;
      if (filterMode == 1) {
        filtered = band;
      } else if (filterMode == 2) {
        filtered = high;
      } else {
        filtered = low;
      }

      // Soft Saturation / Overdrive
      double out;
      if (drive > 0.001) {
        out = _tanh(filtered * (1.0 + drive * 2.5));
      } else {
        out = filtered.clamp(-1.0, 1.0);
      }

      // Apply Amplitude Envelope, Pressure, Dynamics & Accent
      out *= env * press * (isAccent ? 1.25 : 1.0);

      // Boundary fade-in/fade-out to eliminate clicks
      if (i < 64) {
        out *= (i / 64.0);
      } else if (i > numSamples - 64) {
        out *= ((numSamples - i) / 64.0);
      }

      buffer[i] = out.clamp(-1.0, 1.0);
    }
    return buffer;
  }

  static Float32List _synthesizeFallbackSynthBuffer({
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
    double velocity = 0.9,
  }) {
    final int numSamples = (44100 * durationSec).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);

    if (freq <= 0) return buffer;

    // 1. Resolve User / Synthesizer Parameters flexibly
    final double rawWaveform = _resolveParam(params, ['waveform', 'osc_type', 'shape', 'osc'], 0.0);
    final double pulseWidth = _resolveParam(params, ['pulse_width', 'pw', 'pwm'], 0.5).clamp(0.05, 0.95);
    final double subLevel = _resolveParam(params, ['sub_osc', 'sub', 'sub_level'], 0.0).clamp(0.0, 1.0);
    final double noiseLevel = _resolveParam(params, ['noise', 'noise_level'], 0.0).clamp(0.0, 1.0);

    final double attack = _resolveParam(params, ['attack', 'amp_attack'], 0.005).clamp(0.0005, 5.0);
    final double decay = _resolveParam(params, ['decay', 'amp_decay'], 0.15).clamp(0.005, 10.0);
    final double sustain = _resolveParam(params, ['sustain', 'amp_sustain'], 0.75).clamp(0.0, 1.0);
    final double release = _resolveParam(params, ['release', 'amp_release'], 0.15).clamp(0.005, 10.0);

    final double cutoff = _resolveParam(params, ['cutoff', 'filter_cutoff', 'fc'], 4000.0).clamp(20.0, 20000.0);
    final double resonance = _resolveParam(params, ['resonance', 'reso', 'q'], 0.7).clamp(0.1, 10.0);
    final double envMod = _resolveParam(params, ['env_mod', 'filter_env', 'mod_depth'], 0.0).clamp(-2.0, 2.0);
    final double drive = _resolveParam(params, ['drive', 'distortion', 'saturation'], 0.0).clamp(0.0, 10.0);

    final art = articulation?.toLowerCase();
    final isStaccato = (art == 'muted' || art == 'palm_mute' || art == 'staccato');
    final baseFreq = (art == 'harmonics') ? freq * 2.0 : freq;
    final double? targetFreq = (isSlide && targetMidiNote != null && targetMidiNote > 0)
        ? 440.0 * math.pow(2.0, (targetMidiNote - 69) / 12.0)
        : null;

    double phase = 0.0;
    double subPhase = 0.0;
    double low = 0.0;
    double band = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final time = i / 44100.0;
      final normTime = numSamples > 1 ? i / (numSamples - 1) : 0.0;

      final bend = Note.interpolateCurve(pitchBendPoints, normTime, 0.0);
      final press = Note.interpolateCurve(pressurePoints, normTime, velocity);
      final timbre = Note.interpolateCurve(timbrePoints, normTime, 0.5);

      // Pitch glide interpolation
      double curF = baseFreq;
      if (targetFreq != null) {
        final glideNorm = (normTime * 1.5).clamp(0.0, 1.0);
        curF = baseFreq + (targetFreq - baseFreq) * glideNorm;
      }
      final curFreq = math.max(10.0, curF * math.pow(2.0, bend / 12.0));

      // Phase accumulation
      phase = (phase + (curFreq / 44100.0)) % 1.0;
      subPhase = (subPhase + ((curFreq * 0.5) / 44100.0)) % 1.0;

      // Oscillator wave generation
      final double saw = 2.0 * phase - 1.0;
      final double sqr = phase < pulseWidth ? 1.0 : -1.0;
      final double tri = 2.0 * (2.0 * (phase - (phase + 0.5).floorToDouble())).abs() - 1.0;
      final double sin = math.sin(2.0 * math.pi * phase);

      // Multi-waveform morphing / selection
      double osc;
      final w = rawWaveform.clamp(0.0, 3.0);
      if (w <= 1.0) {
        osc = saw * (1.0 - w) + sqr * w;
      } else if (w <= 2.0) {
        final t = w - 1.0;
        osc = sqr * (1.0 - t) + tri * t;
      } else {
        final t = w - 2.0;
        osc = tri * (1.0 - t) + sin * t;
      }

      // Add Sub-Oscillator & Noise
      if (subLevel > 0.001) {
        osc += math.sin(2.0 * math.pi * subPhase) * subLevel * 0.6;
      }
      if (noiseLevel > 0.001) {
        osc += _fastRnd(i * 1103515245 + 12345) * noiseLevel * 0.5;
      }

      // Dynamic Envelope
      double env = evaluateAdsr(time, attack, decay, sustain, release, durationSec);
      if (isStaccato) {
        env *= math.exp(-time / 0.08);
      }

      // Resonant State-Variable Lowpass Filter (Chamberlin SVF)
      final double dynCutoff = (cutoff * math.pow(2.0, envMod * 2.5 * env + (timbre - 0.5) * 1.5)).clamp(20.0, 20000.0);
      final double f = (2.0 * math.sin(math.pi * (dynCutoff / 44100.0))).clamp(0.001, 0.85);
      final double q = (1.0 / resonance).clamp(0.1, 10.0);

      low += f * band;
      final double high = osc - low - q * band;
      band += f * high;
      final double filtered = low;

      // Soft Saturation / Overdrive
      double out;
      if (drive > 0.001) {
        out = _tanh(filtered * (1.0 + drive * 2.5));
      } else {
        out = filtered.clamp(-1.0, 1.0);
      }

      // Apply Envelope, Pressure, Dynamics & Accent
      out *= env * press * (isAccent ? 1.2 : 1.0);

      // Boundary fade-in/fade-out to eliminate clicks
      if (i < 64) {
        out *= (i / 64.0);
      } else if (i > numSamples - 64) {
        out *= ((numSamples - i) / 64.0);
      }

      buffer[i] = out.clamp(-1.0, 1.0);
    }
    return buffer;
  }
  // DSP Math & Synthesis Evaluator for custom synths and drum engines
  static double evaluateSynth({
    required String code,
    required double time,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
    int sampleIndex = 0,
    int totalSamples = 1,
    EatSynthType? synthType,
  }) {
    final type = synthType ?? resolveSynthType(code);
    switch (type) {
      case EatSynthType.proceduralKick: {
        final startF = params['StartFreq'] ?? 160.0;
        final endF = params['EndFreq'] ?? 42.0;
        final pDecay = params['PitchDecay'] ?? 0.035;
        final aDecay = params['AmpDecay'] ?? 0.35;
        final click = params['Click'] ?? 0.0;

        final curFreq = endF + (startF - endF) * math.exp(-time / pDecay.clamp(0.005, 0.5));
        final subSine = math.sin(2.0 * math.pi * curFreq * time);
        final clickTransient = _fastRnd(sampleIndex * 1664525 + 1013904223) * math.exp(-time * 150.0) * click;
        final env = math.exp(-time * 4.0 / aDecay.clamp(0.01, 10.0));
        final rawOutput = (subSine * 0.85 + clickTransient * 0.15) * env;

        final fadeSamples = (44100 * 0.04).toInt().clamp(64, math.max(1, totalSamples ~/ 4));
        final samplesRemaining = totalSamples - 1 - sampleIndex;
        double boundaryFade = 1.0;
        if (samplesRemaining < fadeSamples) {
          final norm = (samplesRemaining / fadeSamples).clamp(0.0, 1.0);
          boundaryFade = 0.5 * (1.0 - math.cos(math.pi * norm));
        }

        final output = rawOutput * boundaryFade;
        return _tanh(output * 1.3);
      }

      case EatSynthType.acid303: {
        return EatsTb303Core.synthesizeSample(
          freq: freq,
          note: note,
          params: params,
          sampleIndex: sampleIndex,
          totalSamples: totalSamples,
          targetMidiNote: targetMidiNote,
          isSlide: isSlide,
          isAccent: isAccent,
          trackId: trackId,
        );
      }

      case EatSynthType.proceduralSnare: {
        double toneFreq = params['ToneFreq'] ?? 185.0;
        double snappy = params['Snappy'] ?? 0.65;
        double decay = params['Decay'] ?? 0.18;
        final variation = params['Variation'] ?? 0.0;

        if (variation > 0.001) {
          final vOffset = (math.sin(note * 12.9898) * 0.5 + 0.5) * variation;
          toneFreq = toneFreq * (1.0 + (vOffset - 0.5 * variation) * 0.08);
          decay = decay * (1.0 + (vOffset - 0.5 * variation) * 0.15);
        }

        final voiceKey = '${trackId ?? "default"}_snare';
        final vState = _snareVoiceStates.putIfAbsent(voiceKey, () => _SnareVoiceState());
        if (sampleIndex == 0) {
          vState.x1 = 0.0;
          vState.y1 = 0.0;
        }

        final sweepFreq = toneFreq * (1.0 + 1.2 * math.exp(-time * 60.0));
        final body = math.sin(2.0 * math.pi * sweepFreq * time) * math.exp(-time * 22.0);
        final overtone = math.sin(2.0 * math.pi * (toneFreq * 1.75) * time) * math.exp(-time * 30.0) * 0.35;
        final tonalCore = body + overtone;

        final noise = _fastRnd(sampleIndex * 1664525 + 1013904223);
        final noiseEnv = math.exp(-time / math.max(0.01, decay));

        final alpha = 1.0 / (1.0 + (2.0 * math.pi * 1800.0 / 44100.0));
        vState.y1 = alpha * (vState.y1 + noise - vState.x1);
        vState.x1 = noise;
        final filteredNoise = vState.y1 * noiseEnv;

        final click = _fastRnd(sampleIndex * 1103515245 + 12345) * math.exp(-time * 250.0) * 0.25;

        final output = (tonalCore * (1.0 - snappy * 0.6) + filteredNoise * (snappy * 1.2) + click);
        return _tanh(output * 1.3);
      }

      case EatSynthType.proceduralHiHat: {
        double cutoff = params['Cutoff'] ?? 7500.0;
        double decay = params['Decay'] ?? 0.06;
        final metallic = params['Metallic'] ?? 0.15;
        final variation = params['Variation'] ?? 0.0;

        if (variation > 0.001) {
          final vOffset = (math.sin(note * 78.233) * 0.5 + 0.5) * variation;
          cutoff = (cutoff * (1.0 + (vOffset - 0.5 * variation) * 0.12)).clamp(1000.0, 18000.0);
          decay = decay * (1.0 + (vOffset - 0.5 * variation) * 0.18);
        }

        final env = math.exp(-time / math.max(0.005, decay));

        final voiceKey = '${trackId ?? "default"}_hihat';
        final vState = _hihatVoiceStates.putIfAbsent(voiceKey, () => _HiHatVoiceState());

        if (sampleIndex == 0) {
          vState.x1 = 0.0;
          vState.y1 = 0.0;
          vState.x2 = 0.0;
          vState.y2 = 0.0;
        }

        final noise = _fastRnd(sampleIndex * 1664525 + 1013904223);

        final ring1 = math.sin(2.0 * math.pi * 320.0 * time);
        final ring2 = math.sin(2.0 * math.pi * 540.0 * time);
        final ring3 = math.sin(2.0 * math.pi * 890.0 * time);
        final metallicRing = (ring1 + ring2 + ring3) * 0.333;

        final rawSignal = noise * (1.0 - metallic * 0.3) + metallicRing * (metallic * 0.3);

        final alpha = 1.0 / (1.0 + (2.0 * math.pi * cutoff.clamp(1000.0, 18000.0) / 44100.0));
        vState.y1 = alpha * (vState.y1 + rawSignal - vState.x1);
        vState.x1 = rawSignal;

        vState.y2 = alpha * (vState.y2 + vState.y1 - vState.x2);
        vState.x2 = vState.y1;

        final output = _tanh(vState.y2 * env * 1.1);
        return output.clamp(-1.0, 1.0);
      }

      case EatSynthType.fmSynth: {
        final ratio = params['ModRatio'] ?? 2.0;
        final index = params['ModIndex'] ?? 3.5;
        final attack = params['Attack'] ?? 0.005;
        final release = params['Release'] ?? 0.4;

        if (freq <= 0) return 0.0;

        double env = 1.0;
        if (time < attack) {
          env = time / attack;
        } else {
          env = math.exp(-(time - attack) / release);
        }

        final modFreq = freq * ratio;
        final modulator = math.sin(2.0 * math.pi * modFreq * time) * (index * env);
        final carrier = math.sin(2.0 * math.pi * freq * time + modulator);

        return (carrier * env * 0.8).clamp(-1.0, 1.0);
      }

      case EatSynthType.snesDsp: {
        final voiceKey = trackId ?? 'default_snes';
        final dsp = _snesDspEngines.putIfAbsent(voiceKey, () => SNESDSPEngine());

        if (sampleIndex == 0) {
          final seed = (params['Seed'] ?? 42.0).toInt();

          if (code.contains('SNESConsole') || code.contains('SNES Synth') || (!params.containsKey('SFXType') && !code.contains('SNESSFX') && !code.contains('Laser') && !code.contains('Explosion') && !code.contains('Powerup') && !code.contains('Coin') && !code.contains('Jump') && !code.contains('Hurt') && !code.contains('Lose') && !code.contains('Button') && !code.contains('Warp'))) {
            dsp.reset();
            final v = dsp.voices[0];
            v.startFreqMult = 1.0;
            v.endFreqMult = 1.0;
            v.sweepDuration = 0.0;
            v.noiseEnabled = false;
            v.noiseMix = 0.0;
            v.vibratoRate = 0.0;
            v.vibratoDepth = 0.0;
            v.arpeggioNotes = const [];
          } else if (params.containsKey('SFXType')) {
            final sfxIdx = params['SFXType']!.toInt().clamp(0, 10);
            SNESSFXRGenerator.configureFromType(dsp, sfxIdx, seed: seed);
          } else if (code.contains('Laser')) {
            SNESSFXRGenerator.configureLaser(dsp, DeterministicPRNG(seed));
          } else if (code.contains('Explosion')) {
            SNESSFXRGenerator.configureExplosion(dsp, DeterministicPRNG(seed));
          } else if (code.contains('Powerup')) {
            SNESSFXRGenerator.configurePowerup(dsp, DeterministicPRNG(seed));
          } else if (code.contains('Coin')) {
            SNESSFXRGenerator.configureCoin(dsp, DeterministicPRNG(seed));
          } else if (code.contains('Jump')) {
            SNESSFXRGenerator.configureJump(dsp, DeterministicPRNG(seed));
          } else if (code.contains('Hurt')) {
            SNESSFXRGenerator.configureHurt(dsp, DeterministicPRNG(seed));
          } else if (code.contains('Lose')) {
            SNESSFXRGenerator.configureLose(dsp, DeterministicPRNG(seed));
          } else if (code.contains('Button')) {
            SNESSFXRGenerator.configureButton(dsp, DeterministicPRNG(seed));
          } else if (code.contains('Warp')) {
            SNESSFXRGenerator.configureWarp(dsp, DeterministicPRNG(seed));
          } else {
            dsp.reset();
          }

          final v0 = dsp.voices[0];
          final isCustom = (params['SFXType']?.toInt() ?? 10) == 10;

          if (params.containsKey('Waveform')) {
            final wIdx = params['Waveform']!.toInt().clamp(0, SNESWaveform.values.length - 1);
            v0.waveform = SNESWaveform.values[wIdx];
          }
          if (params.containsKey('Attack')) {
            v0.attack = params['Attack']!.clamp(0.0005, 2.0);
          }
          if (params.containsKey('Decay')) {
            v0.decay = params['Decay']!.clamp(0.005, 3.0);
          }
          if (params.containsKey('Sustain')) {
            v0.sustain = params['Sustain']!.clamp(0.0, 1.0);
          }
          if (params.containsKey('Release')) {
            v0.release = params['Release']!.clamp(0.005, 3.0);
          }
          if (params.containsKey('PitchSweep')) {
            final sweep = params['PitchSweep']!;
            if (isCustom) {
              if (sweep >= 0) {
                v0.startFreqMult = 1.0;
                v0.endFreqMult = 1.0 + sweep;
              } else {
                v0.startFreqMult = 1.0 - sweep;
                v0.endFreqMult = 1.0;
              }
            } else if (sweep != 0.0) {
              v0.endFreqMult = (v0.endFreqMult + sweep).clamp(0.02, 10.0);
            }
          }
          if (params.containsKey('SweepSpeed')) {
            v0.sweepDuration = params['SweepSpeed']!.clamp(0.005, 2.0);
          }
          if (params.containsKey('VibratoRate') && (isCustom || params['VibratoRate']! > 0.0)) {
            v0.vibratoRate = params['VibratoRate']!.clamp(0.0, 30.0);
          }
          if (params.containsKey('VibratoDepth') && (isCustom || params['VibratoDepth']! > 0.0)) {
            v0.vibratoDepth = params['VibratoDepth']!.clamp(0.0, 2.0);
          }
          if (params.containsKey('ArpSpeed')) {
            v0.arpeggioSpeed = params['ArpSpeed']!.clamp(0.01, 1.0);
          }
          if (params.containsKey('EchoDelay')) {
            dsp.echo.delayMs = params['EchoDelay']!.toInt().clamp(16, 480);
          }
          if (params.containsKey('EchoFeedback')) {
            dsp.echo.feedback = params['EchoFeedback']!.clamp(0.0, 0.95);
          }
          if (params.containsKey('EchoVolume')) {
            final evol = params['EchoVolume']!.clamp(0.0, 1.0);
            dsp.echo.volume = evol;
            dsp.echo.enabled = evol > 0.01;
          }
          if (params.containsKey('NoiseMix')) {
            final nm = params['NoiseMix']!.clamp(0.0, 1.0);
            v0.noiseMix = nm;
          }

          for (final entry in params.entries) {
            if (entry.key.startsWith('reg_0x') || entry.key.startsWith('0x')) {
              final regHex = entry.key.replaceFirst('reg_', '');
              final regAddr = int.tryParse(regHex);
              if (regAddr != null) {
                dsp.writeRegister(regAddr, entry.value.toInt());
              }
            }
          }
        }

        final stereo = dsp.evaluateStereoSample(
          time: time,
          baseFreq: freq,
          duration: 0.4,
          sampleIndex: sampleIndex,
        );
        return ((stereo[0] + stereo[1]) * 0.5).clamp(-1.0, 1.0);
      }

      case EatSynthType.ym2612: {
        final voiceKey = trackId ?? 'default_fm';
        final voice = _fmChipVoices.putIfAbsent(voiceKey, () => FMChipVoice());

        if (sampleIndex == 0) {
          voice.algorithm = (params['Algorithm'] ?? 4.0).toInt().clamp(0, 7);
          voice.feedback = (params['Feedback'] ?? 4.0).toInt().clamp(0, 7);

          voice.operators[0].multiplier = params['Op1_Mult'] ?? 1.0;
          voice.operators[0].totalLevel = params['Op1_TL'] ?? 10.0;
          voice.operators[0].attack = params['Op1_Attack'] ?? 0.005;
          voice.operators[0].decay = params['Op1_Decay'] ?? 0.3;

          voice.operators[1].multiplier = params['Op2_Mult'] ?? 2.0;
          voice.operators[1].totalLevel = params['Op2_TL'] ?? 0.0;
          voice.operators[1].attack = params['Op2_Attack'] ?? 0.005;
          voice.operators[1].decay = params['Op2_Decay'] ?? 0.35;

          voice.operators[2].multiplier = params['Op3_Mult'] ?? 3.0;
          voice.operators[2].totalLevel = params['Op3_TL'] ?? 20.0;

          voice.operators[3].multiplier = params['Op4_Mult'] ?? 1.0;
          voice.operators[3].totalLevel = params['Op4_TL'] ?? 0.0;

          for (final entry in params.entries) {
            if (entry.key.startsWith('reg_0x') || entry.key.startsWith('0x')) {
              final regHex = entry.key.replaceFirst('reg_', '');
              final regAddr = int.tryParse(regHex);
              if (regAddr != null) {
                voice.writeRegister(0, regAddr, entry.value.toInt());
              }
            }
          }
        }

        return voice.evaluateSample(
          time: time,
          baseFreq: freq,
          duration: 0.4,
          sampleIndex: sampleIndex,
        );
      }

      case EatSynthType.polySynth: {
        if (freq <= 0) return 0.0;
        final double rawWaveform = _resolveParam(params, ['waveform', 'osc_type', 'shape', 'osc', 'wave'], 0.0);
        final int waveIdx = rawWaveform.round().clamp(0, 5);
        final double pulseWidth = _resolveParam(params, ['pulse_width', 'pw', 'pwm'], 0.5).clamp(0.05, 0.95);
        final double subLevel = _resolveParam(params, ['sub_level', 'sub_osc', 'sub'], 0.0).clamp(0.0, 1.0);
        final double attack = _resolveParam(params, ['attack', 'amp_attack', 'a'], 0.005).clamp(0.0005, 5.0);
        final double decay = _resolveParam(params, ['decay', 'amp_decay', 'd'], 0.15).clamp(0.005, 10.0);
        final double sustain = _resolveParam(params, ['sustain', 'amp_sustain', 's'], 0.75).clamp(0.0, 1.0);
        final double release = _resolveParam(params, ['release', 'amp_release', 'r'], 0.20).clamp(0.005, 10.0);
        final double cutoff = _resolveParam(params, ['cutoff', 'filter_cutoff', 'fc'], 5000.0).clamp(20.0, 20000.0);
        final double drive = _resolveParam(params, ['drive', 'distortion'], 0.0).clamp(0.0, 10.0);

        final phase = (time * freq) % 1.0;
        double osc;
        switch (waveIdx) {
          case 0:
            osc = 2.0 * phase - 1.0;
            break;
          case 1:
            osc = math.sin(2.0 * math.pi * phase);
            break;
          case 2:
            osc = phase < 0.5 ? 1.0 : -1.0;
            break;
          case 3:
            osc = 2.0 * (2.0 * (phase - (phase + 0.5).floorToDouble())).abs() - 1.0;
            break;
          case 4:
            osc = phase < pulseWidth ? 1.0 : -1.0;
            break;
          case 5:
          default:
            osc = _fastRnd(sampleIndex * 1103515245 + 12345);
            break;
        }

        if (subLevel > 0.001) {
          final subPhase = (time * freq * 0.5) % 1.0;
          osc += math.sin(2.0 * math.pi * subPhase) * subLevel;
        }

        final env = evaluateAdsr(time, attack, decay, sustain, release, 0.4);
        final filtered = osc * (cutoff / 5000.0).clamp(0.1, 1.2);
        final raw = drive > 0.001 ? _tanh(filtered * (1.0 + drive * 2.0)) : filtered;
        return (raw * env).clamp(-1.0, 1.0);
      }

      default: {
        if (freq <= 0) return 0.0;

        final double rawWaveform = _resolveParam(params, ['waveform', 'osc_type', 'shape', 'osc'], 0.0);
        final double pulseWidth = _resolveParam(params, ['pulse_width', 'pw', 'pwm'], 0.5).clamp(0.05, 0.95);
        final double attack = _resolveParam(params, ['attack', 'amp_attack'], 0.005).clamp(0.0005, 5.0);
        final double decay = _resolveParam(params, ['decay', 'amp_decay'], 0.15).clamp(0.005, 10.0);
        final double sustain = _resolveParam(params, ['sustain', 'amp_sustain'], 0.75).clamp(0.0, 1.0);
        final double release = _resolveParam(params, ['release', 'amp_release'], 0.15).clamp(0.005, 10.0);
        final double cutoff = _resolveParam(params, ['cutoff', 'filter_cutoff', 'fc'], 4000.0).clamp(20.0, 20000.0);
        final double drive = _resolveParam(params, ['drive', 'distortion'], 0.0).clamp(0.0, 10.0);

        final phase = (time * freq) % 1.0;
        final saw = 2.0 * phase - 1.0;
        final sqr = phase < pulseWidth ? 1.0 : -1.0;
        final tri = 2.0 * (2.0 * (phase - (phase + 0.5).floorToDouble())).abs() - 1.0;
        final sin = math.sin(2.0 * math.pi * phase);

        double osc;
        final w = rawWaveform.clamp(0.0, 3.0);
        if (w <= 1.0) {
          osc = saw * (1.0 - w) + sqr * w;
        } else if (w <= 2.0) {
          osc = sqr * (2.0 - w) + tri * (w - 1.0);
        } else {
          osc = tri * (3.0 - w) + sin * (w - 2.0);
        }

        final env = evaluateAdsr(time, attack, decay, sustain, release, 0.4);
        final filtered = osc * (cutoff / 5000.0).clamp(0.1, 1.2);
        final raw = drive > 0.001 ? _tanh(filtered * (1.0 + drive * 2.0)) : filtered;
        return (raw * env).clamp(-1.0, 1.0);
      }
    }
  }

  // DSP Math & Synthesis Evaluator for custom FX
  static double evaluateEffect({
    required String code,
    required double inputSample,
    required double time,
    required Map<String, double> params,
    EatFxType? fxType,
  }) {
    final type = fxType ?? resolveFxType(code);

    switch (type) {
      case EatFxType.stereoDelay:
        final feedback = params['Feedback'] ?? 0.45;
        final mix = params['Mix'] ?? 0.4;

        final echo = inputSample * feedback;
        return (inputSample * (1.0 - mix)) + (echo * mix);

      case EatFxType.stereoChorus:
        final mix = params['Mix'] ?? 0.5;
        final rate = params['RateHz'] ?? 1.2;

        final lfo = math.sin(2.0 * math.pi * rate * time);
        final wet = inputSample * (0.8 + lfo * 0.2);

        return (inputSample * (1.0 - mix)) + (wet * mix);

      case EatFxType.snesDownsample:
        return SNESDownsamplerEngine.evaluateSample(
          inputSample: inputSample,
          time: time,
          params: params,
        );

      case EatFxType.bitcrush:
        final bits = params['Bits'] ?? 8.0;
        final downsample = params['Downsample'] ?? 4.0;
        final mix = params['Mix'] ?? 0.8;

        final steps = math.pow(2.0, bits.clamp(2.0, 16.0));
        final quantized = (inputSample * steps).floorToDouble() / steps;

        final holdSample = (time * 44100 % downsample < 1.0) ? quantized : quantized * 0.9;
        return (inputSample * (1.0 - mix)) + (holdSample * mix);

      case EatFxType.tubeDistortion:
        final rawDrive = params['Drive'] ?? 6.0;
        final effectiveDrive = rawDrive <= 1.0 ? (1.0 + rawDrive * 19.0) : rawDrive;
        final outGain = params['OutGain'] ?? (rawDrive <= 1.0 ? 0.75 : 0.7);

        final driven = inputSample * effectiveDrive;
        final clipped = _tanh(driven);
        return (clipped * outGain).clamp(-1.0, 1.0);

      case EatFxType.lowpass:
        final cutoff = params['Cutoff'] ?? 3500.0;
        final fNorm = (cutoff / 44100.0 * math.pi * 2.0).clamp(0.01, 0.95);
        return (inputSample * fNorm).clamp(-1.0, 1.0);

      case EatFxType.fallback:
        return (inputSample * 1.2).clamp(-1.0, 1.0);
    }
  }

  static EatFxType _detectFxType(String code) {
    final explicitId = EatEngineRegistry.detectEngineId(code);
    if (explicitId != null && EatEngineRegistry.audioFxTypes.containsKey(explicitId)) {
      return EatEngineRegistry.audioFxTypes[explicitId]!;
    }

    final lower = code.toLowerCase().replaceAll(' ', '').replaceAll('_', '');

    if (lower.contains('stereodelay') || lower.contains('delay') || lower.contains('timems')) {
      return EatFxType.stereoDelay;
    } else if (lower.contains('stereochorus') || lower.contains('chorus') || lower.contains('depthms')) {
      return EatFxType.stereoChorus;
    } else if (lower.contains('snesdownsample') || lower.contains('snesdownsampler') || lower.contains('brr')) {
      return EatFxType.snesDownsample;
    } else if (lower.contains('bitcrush') || lower.contains('downsample')) {
      return EatFxType.bitcrush;
    } else if (lower.contains('tubedistortion') || lower.contains('distortion') || lower.contains('warmtube') || lower.contains('drive') || lower.contains('outgain')) {
      return EatFxType.tubeDistortion;
    } else if (lower.contains('lowpass') || lower.contains('biquadfilter') || lower.contains('filter')) {
      return EatFxType.lowpass;
    } else {
      return EatFxType.fallback;
    }
  }

  static AutomationScriptType _detectAutomationScriptType(String code) {
    final lower = code.toLowerCase();
    if (lower.contains('lfo') || lower.contains('sine')) return AutomationScriptType.lfo;
    if (lower.contains('ramp') || lower.contains('saw')) return AutomationScriptType.ramp;
    if (lower.contains('adsr') || lower.contains('env')) return AutomationScriptType.adsr;
    return AutomationScriptType.breakpoint;
  }

  /// Evaluates an automation lane at a specific step and time context.
  /// If the lane has custom script code, executes procedural generators
  /// (e.g. LFOs, custom envelopes, mathematical formulas), otherwise evaluates
  /// breakpoint keyframes with easing interpolation.
  static double evaluateAutomation({
    required AutomationLane lane,
    required double step,
    TimeContext? timeCtx,
  }) {
    if (!lane.enabled) return lane.target.defaultValue;

    if (!lane.isCustomEatScript || lane.eatScriptCode.trim().isEmpty) {
      return lane.evaluateAtStep(step, timeCtx);
    }

    final code = lane.eatScriptCode;
    final scriptType = resolveAutomationScriptType(code);

    switch (scriptType) {
      case AutomationScriptType.lfo:
        final rate = _extractParam(code, 'rate') ?? 1.0;
        final depth = _extractParam(code, 'depth') ?? (lane.target.max - lane.target.min) * 0.5;
        final center = _extractParam(code, 'center') ?? lane.target.defaultValue;
        final beat = timeCtx?.currentBeat ?? (step / 4.0);
        final val = center + math.sin(2.0 * math.pi * rate * (beat / 4.0)) * depth;
        return lane.target.isDiscrete
            ? val.roundToDouble().clamp(lane.target.min, lane.target.max)
            : val.clamp(lane.target.min, lane.target.max);

      case AutomationScriptType.ramp:
        final rate = _extractParam(code, 'rate') ?? 1.0;
        final beat = timeCtx?.currentBeat ?? (step / 4.0);
        final phase = (beat * rate) % 1.0;
        final val = lane.target.min + (lane.target.max - lane.target.min) * phase;
        return lane.target.isDiscrete
            ? val.roundToDouble().clamp(lane.target.min, lane.target.max)
            : val.clamp(lane.target.min, lane.target.max);

      case AutomationScriptType.adsr:
        final attack = _extractParam(code, 'attack') ?? 0.1;
        final decay = _extractParam(code, 'decay') ?? 0.3;
        final sustain = _extractParam(code, 'sustain') ?? 0.5;
        final release = _extractParam(code, 'release') ?? 0.4;
        final time = timeCtx?.audioTimeSeconds ?? (step * 0.125);
        final env = evaluateAdsr(time, attack, decay, sustain, release);
        final val = lane.target.min + (lane.target.max - lane.target.min) * env;
        return val.clamp(lane.target.min, lane.target.max);

      case AutomationScriptType.breakpoint:
        return lane.evaluateAtStep(step, timeCtx);
    }
  }

  static double? _extractParam(String code, String name) {
    final codeParams = _automationParamCache.putIfAbsent(code, () => <String, double?>{});
    if (codeParams.containsKey(name)) {
      return codeParams[name];
    }
    final reg = _getParamRegex(name);
    final match = reg.firstMatch(code);
    final val = (match != null && match.group(1) != null)
        ? double.tryParse(match.group(1)!)
        : null;
    codeParams[name] = val;
    return val;
  }
}


class _HiHatVoiceState {
  double x1 = 0.0;
  double y1 = 0.0;
  double x2 = 0.0;
  double y2 = 0.0;
}

class _SnareVoiceState {
  double x1 = 0.0;
  double y1 = 0.0;
}


