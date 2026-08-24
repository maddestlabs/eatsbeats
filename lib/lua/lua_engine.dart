import 'dart:math' as math;
import 'dart:typed_data';

import '../audio/fm_chip_engine.dart';
import '../audio/graph/graph_evaluator.dart';
import '../audio/snes_dsp_engine.dart';
import '../audio/time_context.dart';
import '../models/automation_model.dart';
import 'lua_gui_model.dart';
import 'lua_gui_parser.dart';

class LuaParamDef {
  final String name;
  final double min;
  final double max;
  final double defaultValue;
  final double step;
  final List<String> options;

  LuaParamDef({
    required this.name,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.step = 0.0,
    this.options = const [],
  });

  bool get isInteger =>
      step >= 1.0 ||
      options.isNotEmpty ||
      name.toLowerCase().contains('preset') ||
      name.toLowerCase().contains('bank') ||
      name.toLowerCase().contains('program') ||
      name.toLowerCase().contains('seed') ||
      name.toLowerCase().contains('algorithm') ||
      name.toLowerCase().contains('feedback') ||
      name.toLowerCase().contains('index');

  String getFormattedValue(double value) {
    if (options.isNotEmpty) {
      final idx = value.round().clamp(0, options.length - 1);
      return options[idx];
    }
    if (isInteger) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class LuaCompilationResult {
  final bool isSuccess;
  final String errorMessage;
  final int errorLine;
  final List<LuaParamDef> params;
  final String scriptType; // 'synth', 'drum', or 'effect'
  final LuaGuiPanelDef? guiLayout;

  LuaCompilationResult({
    required this.isSuccess,
    this.errorMessage = '',
    this.errorLine = 0,
    required this.params,
    required this.scriptType,
    this.guiLayout,
  });
}

class LuaEngine {
  static double _fastRnd(int seed) {
    int x = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return (x / 2147483647.0) * 2.0 - 1.0;
  }

  static double _tanh(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    final ex = math.exp(x);
    final enx = math.exp(-x);
    return (ex - enx) / (ex + enx);
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

  static final RegExp _paramRegExp = RegExp(
    "Param\\.add\\(\\s*[\"']([^\"']+)[\"']\\s*,\\s*([\\d\\.-]+)\\s*,\\s*([\\d\\.-]+)\\s*,\\s*([\\d\\.-]+)(?:\\s*,\\s*([\\d\\.-]+))?\\s*\\)",
  );

  static final RegExp _choiceParamRegExp = RegExp(
    "Param\\.choice\\(\\s*[\"']([^\"']+)[\"']\\s*,\\s*\\{([^\\}]+)\\}\\s*(?:,\\s*([\\d\\.-]+))?\\s*\\)",
  );

  static final RegExp _v1ParamRegExp = RegExp(
    "getParam\\(\\s*[\"']([^\"']+)[\"']\\s*\\)",
  );

  static final RegExp _clipParamRegExp = RegExp(
    "registerParam\\(\\s*[\"']([^\"']+)[\"']\\s*,\\s*([\\d\\.-]+)\\s*,\\s*([\\d\\.-]+)\\s*,\\s*([\\d\\.-]+)\\s*\\)",
  );

  static final Map<String, LuaCompilationResult> _compilationCache = {};

  /// Clears the compilation cache if needed.
  static void clearCompilationCache() {
    _compilationCache.clear();
  }

  static LuaCompilationResult compile(String code) {
    if (code.trim().isEmpty) {
      return LuaCompilationResult(
        isSuccess: false,
        errorMessage: 'Lua script code is empty.',
        params: [],
        scriptType: 'synth',
      );
    }

    final cached = _compilationCache[code];
    if (cached != null) return cached;

    try {
      final positionedParams = <MapEntry<int, LuaParamDef>>[];

      // 1. Parse Param.add("Name", min, max, default, [step])
      final matches = _paramRegExp.allMatches(code);
      for (final m in matches) {
        final name = m.group(1)!;
        final minVal = double.tryParse(m.group(2)!) ?? 0.0;
        final maxVal = double.tryParse(m.group(3)!) ?? 1.0;
        final defVal = double.tryParse(m.group(4)!) ?? minVal;
        final stepVal = (m.groupCount >= 5 && m.group(5) != null) ? (double.tryParse(m.group(5)!) ?? 0.0) : 0.0;

        positionedParams.add(MapEntry(
          m.start,
          LuaParamDef(
            name: name,
            min: minVal,
            max: maxVal,
            defaultValue: defVal,
            step: stepVal,
          ),
        ));
      }

      // 2. Parse Param.choice("Name", {"Opt1", "Opt2", ...}, [defaultIdx])
      final choiceMatches = _choiceParamRegExp.allMatches(code);
      for (final m in choiceMatches) {
        final name = m.group(1)!;
        final rawOpts = m.group(2)!;
        final defIdx = (m.groupCount >= 3 && m.group(3) != null) ? (double.tryParse(m.group(3)!) ?? 0.0) : 0.0;

        final optsList = rawOpts
            .split(',')
            .map((s) => s.trim().replaceAll(RegExp("^[\"']|[\"']\$"), ''))
            .where((s) => s.isNotEmpty)
            .toList();

        final maxVal = math.max(0, optsList.length - 1).toDouble();

        if (!positionedParams.any((e) => e.value.name == name)) {
          positionedParams.add(MapEntry(
            m.start,
            LuaParamDef(
              name: name,
              min: 0.0,
              max: maxVal,
              defaultValue: defIdx.clamp(0.0, maxVal),
              step: 1.0,
              options: optsList,
            ),
          ));
        }
      }

      // Check for clip:registerParam
      final clipMatches = _clipParamRegExp.allMatches(code);
      for (final m in clipMatches) {
        final name = m.group(1)!;
        final minVal = double.tryParse(m.group(2)!) ?? 0.0;
        final maxVal = double.tryParse(m.group(3)!) ?? 1.0;
        final defVal = double.tryParse(m.group(4)!) ?? minVal;
        if (!positionedParams.any((e) => e.value.name == name)) {
          positionedParams.add(MapEntry(
            m.start,
            LuaParamDef(
              name: name,
              min: minVal,
              max: maxVal,
              defaultValue: defVal,
            ),
          ));
        }
      }

      // Sort in source order
      positionedParams.sort((a, b) => a.key.compareTo(b.key));
      final params = positionedParams.map((e) => e.value).toList();

      // Check for eatsbits.v1 / eatbits.v1 Param handles in Lua scripts
      final v1Matches = _v1ParamRegExp.allMatches(code);
      for (final m in v1Matches) {
        final name = m.group(1)!;
        if (!params.any((p) => p.name == name)) {
          params.add(LuaParamDef(
            name: name,
            min: 0.0,
            max: 1.0,
            defaultValue: 0.5,
          ));
        }
      }

      String scriptType = 'synth';
      if (code.contains('processSignal') || code.contains('StereoDelayFX') || code.contains('Bitcrusher')) {
        scriptType = 'effect';
      }

      // Check basic Lua syntax markers or eatsbits.v1 / eatbits.v1 scripts
      final isV1Script = code.contains('eatsbits.v1') || code.contains('eatbits.v1') || code.contains('Eatsbits.v1') || code.contains('Eatbits.v1') || code.contains('eatsbits') || code.contains('eatbits');
      final hasFunctionOrLocal = code.contains('function') || code.contains('local') || code.contains('Param.add') || code.contains('--');

      if (!hasFunctionOrLocal && !isV1Script) {
        return LuaCompilationResult(
          isSuccess: false,
          errorMessage: 'Lua Syntax Error: Missing function definition or script structure.',
          errorLine: 1,
          params: [],
          scriptType: scriptType,
        );
      }

      final guiLayout = LuaGuiParser.parseFromCode(code);

      final result = LuaCompilationResult(
        isSuccess: true,
        errorMessage: 'Compiled successfully (Lua Live Scripting - eatsbits.v1 Target)! Active parameters: ${params.length}${guiLayout != null ? " [Custom Hardware GUI Active]" : ""}',
        params: params,
        scriptType: scriptType,
        guiLayout: guiLayout,
      );
      if (_compilationCache.length > 256) {
        _compilationCache.remove(_compilationCache.keys.first);
      }
      _compilationCache[code] = result;
      return result;
    } catch (e) {
      return LuaCompilationResult(
        isSuccess: false,
        errorMessage: 'Lua Compilation Error: ${e.toString()}',
        params: [],
        scriptType: 'synth',
      );
    }
  }

  // Voice state map for stateful synthesis
  static final Map<String, _AcidVoiceState> _acidVoiceStates = {};
  static final Map<String, _HiHatVoiceState> _hihatVoiceStates = {};
  static final Map<String, _SnareVoiceState> _snareVoiceStates = {};
  static final Map<String, FMChipVoice> _fmChipVoices = {};
  static final Map<String, SNESDSPEngine> _snesDspEngines = {};

  // Fast synthesis of complete buffer avoiding redundant per-sample parsing
  static Float32List synthesizeBuffer({
    required String code,
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    int? targetMidiNote,
    bool isSlide = false,
    bool isAccent = false,
    String? trackId,
  }) {
    // 0. Physical Acoustic & Analog 808 Graph Synthesis
    if (code.contains('FmAcousticKick') ||
        code.contains('NearPitchStart') ||
        code.contains('fm_acoustic_kick') ||
        code.contains('Dual-Mic FM Acoustic Kick')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildDualMicFmAcousticKick(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('FmAcousticSnare') ||
        code.contains('fm_acoustic_snare') ||
        code.contains('Dual-Mic FM Acoustic Snare') ||
        code.contains('WireCutoff')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildDualMicFmAcousticSnare(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('FmAcousticTom') ||
        code.contains('fm_acoustic_tom') ||
        code.contains('FM Acoustic Tom') ||
        code.contains('TomPitchStart')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildDualMicFmAcousticTom(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('FmAcousticHiHat') ||
        code.contains('fm_acoustic_hihat') ||
        code.contains('FM Acoustic Hi-Hat')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildDualMicFmAcousticHiHat(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('Analog808Kick') ||
        code.contains('analog_808_kick') ||
        code.contains('Analog 808 Kick')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAnalog808Kick(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('Analog808Snare') ||
        code.contains('analog_808_snare') ||
        code.contains('Analog 808 Snare')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAnalog808Snare(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('Analog808HiHat') ||
        code.contains('analog_808_hihat') ||
        code.contains('Analog 808 Hi-Hat')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAnalog808HiHat(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('Analog808Cowbell') ||
        code.contains('analog_808_cowbell') ||
        code.contains('Analog 808 Cowbell')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAnalog808Cowbell(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('Analog808Tom') ||
        code.contains('analog_808_tom') ||
        code.contains('Analog 808 Tom')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAnalog808Tom(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('Analog909Kick') ||
        code.contains('analog_909_kick') ||
        code.contains('Analog 909 Kick')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAnalog909Kick(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('Analog909Snare') ||
        code.contains('analog_909_snare') ||
        code.contains('Analog 909 Snare')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAnalog909Snare(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('Analog909ClosedHiHat') ||
        code.contains('analog_909_closed_hihat') ||
        code.contains('Analog 909 Closed Hi-Hat') ||
        code.contains('Analog909HiHat') ||
        code.contains('analog_909_hihat') ||
        code.contains('Analog 909 Hi-Hat')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAnalog909ClosedHiHat(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('Analog909OpenHiHat') ||
        code.contains('analog_909_open_hihat') ||
        code.contains('Analog 909 Open Hi-Hat')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAnalog909OpenHiHat(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('Analog909Clap') ||
        code.contains('analog_909_clap') ||
        code.contains('Analog 909 Clap') ||
        code.contains('Analog 909 Handclap')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAnalog909Clap(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    if (code.contains('Analog909Rimshot') ||
        code.contains('analog_909_rimshot') ||
        code.contains('Analog 909 Rimshot')) {
      return GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAnalog909Rimshot(),
        durationSec: durationSec,
        freq: freq,
        note: note,
        params: params,
        velocity: isAccent ? 1.0 : 0.85,
        isAccent: isAccent,
        isSlide: isSlide,
        targetMidiNote: targetMidiNote,
      );
    }

    final int numSamples = (44100 * durationSec).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);

    // 1. Procedural Kick Fast Synthesis
    if (code.contains('ProceduralKick') || code.contains('StartFreq')) {
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

    // 1. Eats-303 Acid Bass Fast Synthesis (Modelled after midilab/jc303 & Open303)
    if (code.contains('Eats303') || code.contains('Eats-303') || code.contains('eats_303') || code.contains('JC303') || code.contains('JC-303') || code.contains('Acid303') || code.contains('TB303') || ((code.contains('Overdrive') || code.contains('Drive')) && code.contains('Resonance') && code.contains('Slide'))) {
      if (freq <= 0) return buffer;

      // Extract parameter values with sensible defaults and range mappings
      final waveType = params['Waveform'] ?? 0.0;
      final rawCutoff = params['Cutoff'] ?? 1600.0;
      final cutoff = rawCutoff > 10.0 ? rawCutoff : (200.0 * math.pow(2.0, rawCutoff * 4.5));
      final res = params['Resonance'] ?? 8.0;
      final envMod = params['EnvMod'] ?? 0.75;
      final rawDecay = params['Decay'] ?? 0.28;
      // Normal decay ranges from ~200ms to ~2000ms
      final normalDecay = rawDecay <= 1.0 ? (0.200 + rawDecay * 1.800) : rawDecay;
      final accentParam = params['Accent'] ?? 0.6;
      final drive = params['Overdrive'] ?? params['Drive'] ?? 0.3;
      final slideParam = params['Slide'] ?? params['Portamento'] ?? params['Glide'] ?? 0.0;
      final double glideTime = slideParam > 0.01 ? (0.010 + slideParam * 0.200) : 0.060;

      // Extended TB-303 / Devil Fish mod parameters
      final tuningOffset = params['Tuning'] ?? params['Pitch'] ?? 0.0;
      final octaveShift = (params['Octave'] ?? 0.0).round();
      final subVolume = params['SubVolume'] ?? params['SubOscVolume'] ?? 0.0;
      final subWave = params['SubWaveform'] ?? 0.0;

      final voiceKey = trackId ?? 'default_303';
      final vState = _acidVoiceStates.putIfAbsent(voiceKey, () => _AcidVoiceState());

      // Base note frequency adjusted by octave and tuning
      final effectiveFreq = freq * math.pow(2.0, octaveShift + (tuningOffset / 12.0));

      if (!isSlide && slideParam <= 0.01) {
        vState.lastEnv = 1.0;
        vState.startFreq = effectiveFreq;
        vState.phase = 0.0;
        vState.subPhase = 0.0;
        vState.stage1 = 0.0;
        vState.stage2 = 0.0;
        vState.stage3 = 0.0;
        vState.stage4 = 0.0;
        vState.hpfX1 = 0.0;
        vState.hpfY1 = 0.0;
        vState.feedbackHpfX1 = 0.0;
        vState.feedbackHpfY1 = 0.0;
      } else {
        vState.startFreq = vState.lastFreq > 0 ? vState.lastFreq : effectiveFreq;
      }

      final bool hasAccent = isAccent || (accentParam > 0.7 && !isSlide);

      // In TB-303 / JC-303, an accented note overrides decay to snappy ~200ms
      final double activeDecay = hasAccent ? 0.200 : normalDecay.clamp(0.03, 3.0);
      final double envBoost = hasAccent ? (1.0 + accentParam * 1.25) : 1.0;
      final double kRes = (res > 1.0 ? (res / 16.0 * 3.85) : (res * 3.85)).clamp(0.0, 3.92);
      final double gain = drive > 0.02 ? (1.0 + (drive * 3.5)) : 1.0;
      final int fadeSamples = (44100 * 0.04).toInt().clamp(64, math.max(1, numSamples ~/ 4));

      double targetFreq = effectiveFreq;
      if (targetMidiNote != null && targetMidiNote > 0) {
        targetFreq = 440.0 * math.pow(2.0, ((targetMidiNote + octaveShift * 12) - 69 + tuningOffset) / 12.0);
      } else if (isSlide || slideParam > 0.01) {
        targetFreq = targetMidiNote != null
            ? (440.0 * math.pow(2.0, ((targetMidiNote + octaveShift * 12) - 69 + tuningOffset) / 12.0))
            : effectiveFreq;
      }

      // Feedback HPF alpha at 150 Hz (Open303 / JC-303 topology)
      const double hpCutoffHz = 150.0;
      const double hpAlpha = 1.0 / (1.0 + (2.0 * math.pi * hpCutoffHz / 44100.0));

      for (int i = 0; i < numSamples; i++) {
        final time = i / 44100.0;

        // Exponential pitch glide for portamento slide
        double currentFreq = effectiveFreq;
        if (targetFreq != effectiveFreq || isSlide || slideParam > 0.01 || (vState.startFreq != effectiveFreq)) {
          currentFreq = targetFreq + (vState.startFreq - targetFreq) * math.exp(-time / glideTime);
        }
        vState.lastFreq = currentFreq;

        // Main 303 Oscillator: Leaky Integrator Saw & Differentiated Square
        vState.phase = (vState.phase + (currentFreq / 44100.0)) % 1.0;
        final normPhase = vState.phase;

        // 303 Sawtooth: Ramp with highpass filtering and phase distortion
        final sawRaw = 2.0 * normPhase - 1.0;
        final sawHP = sawRaw - 0.85 * math.exp(-time * 12.0);

        // 303 Square: Asymmetric pulse wave with curved droop and soft saturation
        final sqrRaw = normPhase < 0.48 ? 0.78 : -0.78;
        final mainOsc = (1.0 - waveType) * sawHP + waveType * sqrRaw;

        // Optional Sub-Oscillator (-1 or -2 octaves)
        double subOsc = 0.0;
        if (subVolume > 0.01) {
          vState.subPhase = (vState.subPhase + (currentFreq * 0.5 / 44100.0)) % 1.0;
          final subNorm = vState.subPhase;
          subOsc = subWave > 0.5 ? (subNorm < 0.5 ? 0.7 : -0.7) : math.sin(2.0 * math.pi * subNorm);
        }

        final combinedOsc = mainOsc * (1.0 - subVolume * 0.4) + subOsc * (subVolume * 0.6);

        // Filter Envelope: Soft attack (~3ms) followed by exponential decay
        final softAttack = 1.0 - math.exp(-time / 0.003);
        final envDecayCurve = math.exp(-time / activeDecay);
        final baseEnv = isSlide ? (vState.lastEnv * envDecayCurve) : (softAttack * envDecayCurve);
        vState.lastEnv = baseEnv;

        // Accent Pulse: Rapid ~35ms transient cutoff boost
        final accentPulse = hasAccent ? (accentParam * 0.55 * math.exp(-time / 0.035)) : 0.0;

        // Exponential cutoff sweep modulation (up to 5.5 octaves)
        final modCutoff = (cutoff * math.pow(2.0, (baseEnv + accentPulse) * envMod * 5.2 * envBoost)).clamp(30.0, 18000.0);
        final fNorm = (modCutoff / 44100.0 * math.pi * 2.0).clamp(0.005, 0.85);

        // Non-linear 150 Hz Feedback High-Pass Loop (Signature 303 Diode Ladder)
        final rawFeedback = kRes * _tanh(vState.stage4 * 0.50);
        final feedbackHP = hpAlpha * (vState.feedbackHpfY1 + rawFeedback - vState.feedbackHpfX1);
        vState.feedbackHpfX1 = rawFeedback;
        vState.feedbackHpfY1 = feedbackHP;

        final inputWithRes = _tanh(combinedOsc - feedbackHP);

        // 4-Pole 24dB Diode Ladder Cascade with Stage Non-Linearities
        vState.stage1 += fNorm * (inputWithRes - vState.stage1);
        vState.stage2 += fNorm * (_tanh(vState.stage1) - vState.stage2);
        vState.stage3 += fNorm * (_tanh(vState.stage2) - vState.stage3);
        vState.stage4 += fNorm * (_tanh(vState.stage3) - vState.stage4);
        final filtered = vState.stage4 * (1.0 + kRes * 0.20);

        // DC-blocking post-filter high-pass
        final hpfOut = 0.985 * (vState.hpfY1 + filtered - vState.hpfX1);
        vState.hpfX1 = filtered;
        vState.hpfY1 = hpfOut;

        // VCA Stage & Accent Boost (+6 to +10 dB)
        double output = hpfOut * (hasAccent ? (1.35 + accentParam * 0.45) : 1.0);

        // Overdrive Saturation Stage
        if (drive > 0.02) {
          output = _tanh(output * gain);
        }

        final samplesRemaining = numSamples - 1 - i;
        double boundaryFade = 1.0;
        if (samplesRemaining < fadeSamples && fadeSamples > 0) {
          final norm = (samplesRemaining / fadeSamples).clamp(0.0, 1.0);
          boundaryFade = 0.5 * (1.0 - math.cos(math.pi * norm));
        }

        buffer[i] = (output * boundaryFade).clamp(-1.0, 1.0);
      }
      return buffer;
    }

    // 2. Procedural Snare Fast Synthesis
    if (code.contains('ProceduralSnare') || code.contains('Snappy')) {
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

    // 3. Procedural Hi-Hat Fast Synthesis
    if (code.contains('ProceduralHiHat') || code.contains('Metallic')) {
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

    // 4. Dual-Op FM Synth Fast Synthesis
    if (code.contains('FMSynth') || code.contains('ModRatio')) {
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

    // 5. SNES S-DSP / SFXR Engine
    if (code.contains('SNES') || code.contains('S-DSP') || code.contains('SPC700') || code.contains('SNESSFX') || code.contains('SFXR')) {
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

    // 6. Yamaha YM2612 / OPN2 / OPL3 FM Chip Engine
    if (code.contains('YM2612') || code.contains('OPN2') || code.contains('OPL3') || code.contains('FMChip')) {
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

    // Default Fallback Synth: Sawtooth + Sub Octave
    if (freq <= 0) return buffer;
    final cutoff = params['Cutoff'] ?? 3000.0;
    final cutoffNorm = cutoff / 5000.0;

    for (int i = 0; i < numSamples; i++) {
      final time = i / 44100.0;
      final phase = time * freq;
      final saw = 2.0 * (phase - (phase + 0.5).floorToDouble());
      final sub = math.sin(2.0 * math.pi * (freq * 0.5) * time);
      final env = math.exp(-time / 0.3);
      final raw = (saw * 0.7 + sub * 0.3) * env;
      buffer[i] = (raw * cutoffNorm).clamp(-1.0, 1.0);
    }
    return buffer;
  }

  // DSP Math & Synthesis Evaluator for Lua custom synths and drum engines
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
  }) {
    // 0. Procedural Kick Drum
    if (code.contains('ProceduralKick') || code.contains('StartFreq')) {
      final startF = params['StartFreq'] ?? 160.0;
      final endF = params['EndFreq'] ?? 42.0;
      final pDecay = params['PitchDecay'] ?? 0.035;
      final aDecay = params['AmpDecay'] ?? 0.35;
      final click = params['Click'] ?? 0.0;

      final curFreq = endF + (startF - endF) * math.exp(-time / pDecay.clamp(0.005, 0.5));
      final subSine = math.sin(2.0 * math.pi * curFreq * time);
      // Zero-allocation LCG noise — no heap object created per sample
      final clickTransient = _fastRnd(sampleIndex * 1664525 + 1013904223) * math.exp(-time * 150.0) * click;

      // Exponential amplitude envelope decaying to < 1% by time = aDecay
      final env = math.exp(-time * 4.0 / aDecay.clamp(0.01, 10.0));

      final rawOutput = (subSine * 0.85 + clickTransient * 0.15) * env;

      // Smooth raised-cosine boundary fade-out over final 40ms of playback buffer
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

    // 1. Eats-303 Acid Bass Engine (Modelled after midilab/jc303 & Open303)
    if (code.contains('Eats303') || code.contains('Eats-303') || code.contains('eats_303') || code.contains('JC303') || code.contains('JC-303') || code.contains('Acid303') || code.contains('TB303') || ((code.contains('Overdrive') || code.contains('Drive')) && code.contains('Resonance') && code.contains('Slide'))) {
      if (freq <= 0) return 0.0;

      final waveType = params['Waveform'] ?? 0.0;
      final rawCutoff = params['Cutoff'] ?? 1600.0;
      final cutoff = rawCutoff > 10.0 ? rawCutoff : (200.0 * math.pow(2.0, rawCutoff * 4.5));
      final res = params['Resonance'] ?? 8.0;
      final envMod = params['EnvMod'] ?? 0.75;
      final rawDecay = params['Decay'] ?? 0.28;
      final normalDecay = rawDecay <= 1.0 ? (0.200 + rawDecay * 1.800) : rawDecay;
      final accentParam = params['Accent'] ?? 0.6;
      final drive = params['Overdrive'] ?? params['Drive'] ?? 0.3;
      final slideParam = params['Slide'] ?? params['Portamento'] ?? params['Glide'] ?? 0.0;
      final double glideTime = slideParam > 0.01 ? (0.010 + slideParam * 0.200) : 0.060;

      final tuningOffset = params['Tuning'] ?? params['Pitch'] ?? 0.0;
      final octaveShift = (params['Octave'] ?? 0.0).round();
      final subVolume = params['SubVolume'] ?? params['SubOscVolume'] ?? 0.0;
      final subWave = params['SubWaveform'] ?? 0.0;

      final voiceKey = trackId ?? 'default_303';
      final vState = _acidVoiceStates.putIfAbsent(voiceKey, () => _AcidVoiceState());

      final effectiveFreq = freq * math.pow(2.0, octaveShift + (tuningOffset / 12.0));

      if (sampleIndex == 0) {
        if (!isSlide && slideParam <= 0.01) {
          vState.lastEnv = 1.0;
          vState.startFreq = effectiveFreq;
          vState.phase = 0.0;
          vState.subPhase = 0.0;
          vState.stage1 = 0.0;
          vState.stage2 = 0.0;
          vState.stage3 = 0.0;
          vState.stage4 = 0.0;
          vState.hpfX1 = 0.0;
          vState.hpfY1 = 0.0;
          vState.feedbackHpfX1 = 0.0;
          vState.feedbackHpfY1 = 0.0;
        } else {
          vState.startFreq = vState.lastFreq > 0 ? vState.lastFreq : effectiveFreq;
        }
      }

      final bool hasAccent = isAccent || (accentParam > 0.7 && !isSlide);
      final double activeDecay = hasAccent ? 0.200 : normalDecay.clamp(0.03, 3.0);
      final double envBoost = hasAccent ? (1.0 + accentParam * 1.25) : 1.0;
      final double kRes = (res > 1.0 ? (res / 16.0 * 3.85) : (res * 3.85)).clamp(0.0, 3.92);
      final double gain = drive > 0.02 ? (1.0 + (drive * 3.5)) : 1.0;

      double targetFreq = effectiveFreq;
      if (targetMidiNote != null && targetMidiNote > 0) {
        targetFreq = 440.0 * math.pow(2.0, ((targetMidiNote + octaveShift * 12) - 69 + tuningOffset) / 12.0);
      } else if (isSlide || slideParam > 0.01) {
        targetFreq = targetMidiNote != null
            ? (440.0 * math.pow(2.0, ((targetMidiNote + octaveShift * 12) - 69 + tuningOffset) / 12.0))
            : effectiveFreq;
      }

      double currentFreq = effectiveFreq;
      if (targetFreq != effectiveFreq || isSlide || slideParam > 0.01 || (vState.startFreq != effectiveFreq)) {
        currentFreq = targetFreq + (vState.startFreq - targetFreq) * math.exp(-time / glideTime);
      }
      vState.lastFreq = currentFreq;

      vState.phase = (vState.phase + (currentFreq / 44100.0)) % 1.0;
      final normPhase = vState.phase;

      final sawRaw = 2.0 * normPhase - 1.0;
      final sawHP = sawRaw - 0.85 * math.exp(-time * 12.0);
      final sqrRaw = normPhase < 0.48 ? 0.78 : -0.78;
      final mainOsc = (1.0 - waveType) * sawHP + waveType * sqrRaw;

      double subOsc = 0.0;
      if (subVolume > 0.01) {
        vState.subPhase = (vState.subPhase + (currentFreq * 0.5 / 44100.0)) % 1.0;
        final subNorm = vState.subPhase;
        subOsc = subWave > 0.5 ? (subNorm < 0.5 ? 0.7 : -0.7) : math.sin(2.0 * math.pi * subNorm);
      }
      final combinedOsc = mainOsc * (1.0 - subVolume * 0.4) + subOsc * (subVolume * 0.6);

      final softAttack = 1.0 - math.exp(-time / 0.003);
      final envDecayCurve = math.exp(-time / activeDecay);
      final baseEnv = isSlide ? (vState.lastEnv * envDecayCurve) : (softAttack * envDecayCurve);
      vState.lastEnv = baseEnv;

      final accentPulse = hasAccent ? (accentParam * 0.55 * math.exp(-time / 0.035)) : 0.0;

      final modCutoff = (cutoff * math.pow(2.0, (baseEnv + accentPulse) * envMod * 5.2 * envBoost)).clamp(30.0, 18000.0);
      final fNorm = (modCutoff / 44100.0 * math.pi * 2.0).clamp(0.005, 0.85);

      const double hpCutoffHz = 150.0;
      const double hpAlpha = 1.0 / (1.0 + (2.0 * math.pi * hpCutoffHz / 44100.0));
      final rawFeedback = kRes * _tanh(vState.stage4 * 0.50);
      final feedbackHP = hpAlpha * (vState.feedbackHpfY1 + rawFeedback - vState.feedbackHpfX1);
      vState.feedbackHpfX1 = rawFeedback;
      vState.feedbackHpfY1 = feedbackHP;

      final inputWithRes = _tanh(combinedOsc - feedbackHP);

      vState.stage1 += fNorm * (inputWithRes - vState.stage1);
      vState.stage2 += fNorm * (_tanh(vState.stage1) - vState.stage2);
      vState.stage3 += fNorm * (_tanh(vState.stage2) - vState.stage3);
      vState.stage4 += fNorm * (_tanh(vState.stage3) - vState.stage4);
      final filtered = vState.stage4 * (1.0 + kRes * 0.20);

      final hpfOut = 0.985 * (vState.hpfY1 + filtered - vState.hpfX1);
      vState.hpfX1 = filtered;
      vState.hpfY1 = hpfOut;

      double output = hpfOut * (hasAccent ? (1.35 + accentParam * 0.45) : 1.0);
      if (drive > 0.02) {
        output = _tanh(output * gain);
      }

      final fadeSamples = (44100 * 0.04).toInt().clamp(64, math.max(1, totalSamples ~/ 4));
      final samplesRemaining = totalSamples - 1 - sampleIndex;
      double boundaryFade = 1.0;
      if (samplesRemaining < fadeSamples && fadeSamples > 0) {
        final norm = (samplesRemaining / fadeSamples).clamp(0.0, 1.0);
        boundaryFade = 0.5 * (1.0 - math.cos(math.pi * norm));
      }

      return (output * boundaryFade).clamp(-1.0, 1.0);
    }

    // 2. Procedural Snare Drum
    else if (code.contains('ProceduralSnare') || code.contains('Snappy')) {
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

      // High-pass filter noise wires ~ 1800Hz
      final alpha = 1.0 / (1.0 + (2.0 * math.pi * 1800.0 / 44100.0));
      vState.y1 = alpha * (vState.y1 + noise - vState.x1);
      vState.x1 = noise;
      final filteredNoise = vState.y1 * noiseEnv;

      final click = _fastRnd(sampleIndex * 1103515245 + 12345) * math.exp(-time * 250.0) * 0.25;

      final output = (tonalCore * (1.0 - snappy * 0.6) + filteredNoise * (snappy * 1.2) + click);
      return _tanh(output * 1.3);
    }

    // 3. Procedural Hi-Hat
    else if (code.contains('ProceduralHiHat') || code.contains('Metallic')) {
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

      // Cascaded 2-Pole High-Pass Filter for controllable, clean sizzle
      final alpha = 1.0 / (1.0 + (2.0 * math.pi * cutoff.clamp(1000.0, 18000.0) / 44100.0));
      vState.y1 = alpha * (vState.y1 + rawSignal - vState.x1);
      vState.x1 = rawSignal;

      vState.y2 = alpha * (vState.y2 + vState.y1 - vState.x2);
      vState.x2 = vState.y1;

      final output = _tanh(vState.y2 * env * 1.1);
      return output.clamp(-1.0, 1.0);
    }

    // 4. Dual-Op FM Synth
    else if (code.contains('FMSynth') || code.contains('ModRatio')) {
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

    // 5. SNES Sony S-DSP & Procedural SFXR Sound Engine
    else if (code.contains('SNES') || code.contains('S-DSP') || code.contains('SPC700') || code.contains('SNESSFX') || code.contains('SFXR')) {
      final voiceKey = trackId ?? 'default_snes';
      final dsp = _snesDspEngines.putIfAbsent(voiceKey, () => SNESDSPEngine());

      if (sampleIndex == 0) {
        final seed = (params['Seed'] ?? 42.0).toInt();

        // 1. Configure baseline archetype template if SFXType is provided
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

        // 2. Apply live parameter overlays so sliders/automations directly modulate the sound
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
            // Modulate archetype frequency end multiplier by user pitch sweep slider
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

        // Direct S-DSP register pokes
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

    // 6. Yamaha YM2612 / OPN2 / OPL3 Hardware FM Chip Engine
    else if (code.contains('YM2612') || code.contains('OPN2') || code.contains('OPL3') || code.contains('FMChip')) {
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

    // Default Fallback Synth: Sawtooth + Sub Octave
    else {
      if (freq <= 0) return 0.0;

      final cutoff = params['Cutoff'] ?? 3000.0;
      final phase = time * freq;
      final saw = 2.0 * (phase - (phase + 0.5).floorToDouble());
      final sub = math.sin(2.0 * math.pi * (freq * 0.5) * time);

      final env = math.exp(-time / 0.3);
      final raw = (saw * 0.7 + sub * 0.3) * env;
      return (raw * (cutoff / 5000.0)).clamp(-1.0, 1.0);
    }
  }

  // DSP Math & Synthesis Evaluator for Lua custom FX
  static double evaluateEffect({
    required String code,
    required double inputSample,
    required double time,
    required Map<String, double> params,
  }) {
    final lower = code.toLowerCase().replaceAll(' ', '').replaceAll('_', '');

    if (lower.contains('stereodelay') || lower.contains('delay') || lower.contains('timems')) {
      final feedback = params['Feedback'] ?? 0.45;
      final mix = params['Mix'] ?? 0.4;

      final echo = inputSample * feedback;
      return (inputSample * (1.0 - mix)) + (echo * mix);
    } else if (lower.contains('stereochorus') || lower.contains('chorus') || lower.contains('depthms')) {
      final mix = params['Mix'] ?? 0.5;
      final rate = params['RateHz'] ?? 1.2;

      final lfo = math.sin(2.0 * math.pi * rate * time);
      final wet = inputSample * (0.8 + lfo * 0.2);

      return (inputSample * (1.0 - mix)) + (wet * mix);
    } else if (lower.contains('bitcrush') || lower.contains('downsample')) {
      final bits = params['Bits'] ?? 8.0;
      final downsample = params['Downsample'] ?? 4.0;
      final mix = params['Mix'] ?? 0.8;

      final steps = math.pow(2.0, bits.clamp(2.0, 16.0));
      final quantized = (inputSample * steps).floorToDouble() / steps;

      final holdSample = (time * 44100 % downsample < 1.0) ? quantized : quantized * 0.9;
      return (inputSample * (1.0 - mix)) + (holdSample * mix);
    } else if (lower.contains('tubedistortion') || lower.contains('distortion') || lower.contains('warmtube') || lower.contains('drive') || lower.contains('outgain')) {
      final rawDrive = params['Drive'] ?? 6.0;
      // If drive is in normalized 0.0..1.0 range, scale to 1.0..20.0x
      final effectiveDrive = rawDrive <= 1.0 ? (1.0 + rawDrive * 19.0) : rawDrive;
      final outGain = params['OutGain'] ?? (rawDrive <= 1.0 ? 0.75 : 0.7);

      final driven = inputSample * effectiveDrive;
      // Hyperbolic tangent soft clipping saturation
      final clipped = _tanh(driven);
      return (clipped * outGain).clamp(-1.0, 1.0);
    } else if (lower.contains('lowpass') || lower.contains('biquadfilter') || lower.contains('filter')) {
      final cutoff = params['Cutoff'] ?? 3500.0;
      final fNorm = (cutoff / 44100.0 * math.pi * 2.0).clamp(0.01, 0.95);
      return (inputSample * fNorm).clamp(-1.0, 1.0);
    } else {
      return (inputSample * 1.2).clamp(-1.0, 1.0);
    }
  }

  /// Evaluates an automation lane at a specific step and time context.
  /// If the lane has custom Lua code, parses and executes procedural generators
  /// (e.g. LFOs, custom envelopes, mathematical formulas), otherwise evaluates
  /// breakpoint keyframes with easing interpolation.
  static double evaluateAutomation({
    required AutomationLane lane,
    required double step,
    TimeContext? timeCtx,
  }) {
    if (!lane.enabled) return lane.target.defaultValue;

    if (!lane.isCustomLua || lane.luaScriptCode.trim().isEmpty) {
      return lane.evaluateAtStep(step, timeCtx);
    }

    final code = lane.luaScriptCode;
    final lower = code.toLowerCase();

    // 1. Procedural LFO generator: lfo(rate, depth, [center])
    if (lower.contains('lfo') || lower.contains('sine')) {
      final rate = _extractParam(code, 'rate') ?? 1.0;
      final depth = _extractParam(code, 'depth') ?? (lane.target.max - lane.target.min) * 0.5;
      final center = _extractParam(code, 'center') ?? lane.target.defaultValue;
      final beat = timeCtx?.currentBeat ?? (step / 4.0);
      final val = center + math.sin(2.0 * math.pi * rate * (beat / 4.0)) * depth;
      return lane.target.isDiscrete
          ? val.roundToDouble().clamp(lane.target.min, lane.target.max)
          : val.clamp(lane.target.min, lane.target.max);
    }

    // 2. Procedural Ramp / Saw LFO: ramp(rate, min, max)
    if (lower.contains('ramp') || lower.contains('saw')) {
      final rate = _extractParam(code, 'rate') ?? 1.0;
      final beat = timeCtx?.currentBeat ?? (step / 4.0);
      final phase = (beat * rate) % 1.0;
      final val = lane.target.min + (lane.target.max - lane.target.min) * phase;
      return lane.target.isDiscrete
          ? val.roundToDouble().clamp(lane.target.min, lane.target.max)
          : val.clamp(lane.target.min, lane.target.max);
    }

    // 3. Procedural ADSR / Envelope in Lua
    if (lower.contains('adsr') || lower.contains('env')) {
      final attack = _extractParam(code, 'attack') ?? 0.1;
      final decay = _extractParam(code, 'decay') ?? 0.3;
      final sustain = _extractParam(code, 'sustain') ?? 0.5;
      final release = _extractParam(code, 'release') ?? 0.4;
      final time = timeCtx?.audioTimeSeconds ?? (step * 0.125);
      final env = evaluateAdsr(time, attack, decay, sustain, release);
      final val = lane.target.min + (lane.target.max - lane.target.min) * env;
      return val.clamp(lane.target.min, lane.target.max);
    }

    // Default: fallback to breakpoint interpolation
    return lane.evaluateAtStep(step, timeCtx);
  }

  static double? _extractParam(String code, String name) {
    final reg = RegExp('$name\\s*=\\s*([\\d\\.-]+)', caseSensitive: false);
    final match = reg.firstMatch(code);
    if (match != null && match.group(1) != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }
}

class _AcidVoiceState {
  double phase = 0.0;
  double subPhase = 0.0;
  double lastEnv = 1.0;
  double lastFreq = 0.0;
  double startFreq = 0.0;
  double stage1 = 0.0;
  double stage2 = 0.0;
  double stage3 = 0.0;
  double stage4 = 0.0;
  double hpfX1 = 0.0;
  double hpfY1 = 0.0;
  double feedbackHpfX1 = 0.0;
  double feedbackHpfY1 = 0.0;
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

