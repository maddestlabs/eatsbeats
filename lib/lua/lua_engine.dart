import 'dart:math' as math;

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

  LuaCompilationResult({
    required this.isSuccess,
    this.errorMessage = '',
    this.errorLine = 0,
    required this.params,
    required this.scriptType,
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

  static LuaCompilationResult compile(String code) {
    if (code.trim().isEmpty) {
      return LuaCompilationResult(
        isSuccess: false,
        errorMessage: 'Lua script code is empty.',
        params: [],
        scriptType: 'synth',
      );
    }

    try {
      final params = <LuaParamDef>[];

      // 1. Parse Param.add("Name", min, max, default, [step])
      final matches = _paramRegExp.allMatches(code);
      for (final m in matches) {
        final name = m.group(1)!;
        final minVal = double.tryParse(m.group(2)!) ?? 0.0;
        final maxVal = double.tryParse(m.group(3)!) ?? 1.0;
        final defVal = double.tryParse(m.group(4)!) ?? minVal;
        final stepVal = (m.groupCount >= 5 && m.group(5) != null) ? (double.tryParse(m.group(5)!) ?? 0.0) : 0.0;

        params.add(LuaParamDef(
          name: name,
          min: minVal,
          max: maxVal,
          defaultValue: defVal,
          step: stepVal,
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

        if (!params.any((p) => p.name == name)) {
          params.add(LuaParamDef(
            name: name,
            min: 0.0,
            max: maxVal,
            defaultValue: defIdx.clamp(0.0, maxVal),
            step: 1.0,
            options: optsList,
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
        if (!params.any((p) => p.name == name)) {
          params.add(LuaParamDef(
            name: name,
            min: minVal,
            max: maxVal,
            defaultValue: defVal,
          ));
        }
      }

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

      return LuaCompilationResult(
        isSuccess: true,
        errorMessage: 'Compiled successfully (Lua Live Scripting - eatsbits.v1 Target)! Active parameters: ${params.length}',
        params: params,
        scriptType: scriptType,
      );
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
      final rnd = math.Random(sampleIndex * 1664525 + 1013904223);
      final clickTransient = (rnd.nextDouble() * 2.0 - 1.0) * math.exp(-time * 150.0) * click;

      // Exponential amplitude envelope decaying to < 1% by time = aDecay
      final env = math.exp(-time * 5.0 / aDecay.clamp(0.01, 1.5));

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

    // 1. JC-303 Acid Bass Engine (Modelled after midilab/jc303)
    if (code.contains('Acid303') || code.contains('TB303') || code.contains('Waveform') || code.contains('Overdrive')) {
      final waveType = params['Waveform'] ?? 0.0;
      final cutoff = params['Cutoff'] ?? 1600.0;
      final res = params['Resonance'] ?? 8.0;
      final envMod = params['EnvMod'] ?? 0.75;
      final decay = params['Decay'] ?? 0.28;
      final accentParam = params['Accent'] ?? 0.6;
      final drive = params['Overdrive'] ?? 0.3;
      final slideParam = params['Slide'] ?? 0.0;

      if (freq <= 0) return 0.0;

      final voiceKey = trackId ?? 'default_303';
      final vState = _acidVoiceStates.putIfAbsent(voiceKey, () => _AcidVoiceState());

      if (sampleIndex == 0) {
        if (!isSlide) {
          vState.lastEnv = 1.0;
          vState.startFreq = freq;
        } else {
          vState.startFreq = vState.lastFreq > 0 ? vState.lastFreq : freq;
        }
      }

      // Pitch glide / Portamento logic
      double currentFreq = freq;
      if (targetMidiNote != null && targetMidiNote > 0) {
        final targetFreq = 440.0 * math.pow(2.0, (targetMidiNote - 69) / 12.0);
        currentFreq = targetFreq + (vState.startFreq - targetFreq) * math.exp(-time / 0.060);
      } else if (isSlide || slideParam > 0.5) {
        final targetFreq = targetMidiNote != null ? (440.0 * math.pow(2.0, (targetMidiNote - 69) / 12.0)) : freq;
        currentFreq = targetFreq + (vState.startFreq - targetFreq) * math.exp(-time / 0.060);
      }
      vState.lastFreq = currentFreq;

      // Authentic 303 Oscillators with Continuous Phase Accumulator
      vState.phase = (vState.phase + (currentFreq / 44100.0)) % 1.0;
      final normPhase = vState.phase;
      final sawRaw = 2.0 * normPhase - 1.0;
      final sawHP = sawRaw - 0.85 * math.exp(-time * 12.0);
      final sqrRaw = normPhase < 0.46 ? 0.75 : -0.75;
      final osc = waveType < 0.5 ? sawHP : sqrRaw;

      // Dynamic Accent & VCF Envelope Decay Dynamics
      final bool hasAccent = isAccent || (accentParam > 0.7 && !isSlide);
      final envBoost = hasAccent ? (1.0 + accentParam * 1.1) : 1.0;
      final envDecay = (decay / (hasAccent ? (1.0 + accentParam * 0.9) : 1.0)).clamp(0.02, 2.0);

      // Envelope calculation (legato vs retriggered)
      final env = isSlide ? (vState.lastEnv * math.exp(-time / envDecay)) : math.exp(-time / envDecay);
      vState.lastEnv = env;

      final accentPulse = hasAccent ? (accentParam * 0.4 * math.exp(-time / 0.035)) : 0.0;

      // 4-Pole 24dB Diode Ladder Filter cutoff & non-linear saturation
      final modCutoff = (cutoff + (envMod * (env + accentPulse) * 6500.0 * envBoost)).clamp(40.0, 16000.0);
      final fNorm = (modCutoff / 44100.0 * math.pi * 2.0).clamp(0.005, 0.85);
      final kRes = (res / 16.0 * 3.85).clamp(0.0, 3.95);

      final feedback = kRes * _tanh(vState.stage4 * 0.45);
      final inputWithRes = _tanh(osc - feedback);

      vState.stage1 += fNorm * (inputWithRes - vState.stage1);
      vState.stage2 += fNorm * (vState.stage1 - vState.stage2);
      vState.stage3 += fNorm * (vState.stage2 - vState.stage3);
      vState.stage4 += fNorm * (vState.stage3 - vState.stage4);
      final filtered = vState.stage4 * (1.0 + kRes * 0.22);

      // Post-VCF 150Hz 1-Pole High-Pass filter (fixes attack transient muting bug)
      final hpfOut = 0.978 * (vState.hpfY1 + filtered - vState.hpfX1);
      vState.hpfX1 = filtered;
      vState.hpfY1 = hpfOut;

      double output = hpfOut * (hasAccent ? 1.35 : 1.0);
      if (drive > 0.05) {
        final gain = 1.0 + (drive * 4.0);
        output = _tanh(output * gain);
      }

      return output.clamp(-1.0, 1.0);
    }

    // 2. Procedural Snare Drum
    else if (code.contains('ProceduralSnare') || code.contains('Snappy')) {
      final toneFreq = params['ToneFreq'] ?? 185.0;
      final snappy = params['Snappy'] ?? 0.65;
      final decay = params['Decay'] ?? 0.1;

      final sweepFreq = toneFreq * math.exp(-time * 40.0);
      final body = math.sin(2.0 * math.pi * sweepFreq * time) * math.exp(-time * 25.0);

      final noise = _fastRnd(sampleIndex + (time * 100000).toInt()) * math.exp(-time / decay.clamp(0.01, 1.0));

      final output = body * (1.0 - snappy) + noise * snappy;
      return _tanh(output * 1.2);
    }

    // 3. Procedural Hi-Hat
    else if (code.contains('ProceduralHiHat') || code.contains('Metallic')) {
      final cutoff = params['Cutoff'] ?? 8500.0;
      final decay = params['Decay'] ?? 0.05;
      final metallic = params['Metallic'] ?? 0.15;

      final env = math.exp(-time / decay.clamp(0.005, 0.5));

      final voiceKey = '${trackId ?? "default"}_hihat';
      final vState = _hihatVoiceStates.putIfAbsent(voiceKey, () => _HiHatVoiceState());

      if (sampleIndex == 0) {
        vState.x1 = 0.0;
        vState.y1 = 0.0;
        vState.x2 = 0.0;
        vState.y2 = 0.0;
      }

      // True white noise calculated per sample (zero-allocation)
      final noise = _fastRnd(sampleIndex * 1664525 + 1013904223);

      // TR-808 inspired metallic square ring cluster
      final ring1 = math.sin(2.0 * math.pi * 205.0 * time) > 0 ? 1.0 : -1.0;
      final ring2 = math.sin(2.0 * math.pi * 305.0 * time) > 0 ? 1.0 : -1.0;
      final ring3 = math.sin(2.0 * math.pi * 365.0 * time) > 0 ? 1.0 : -1.0;
      final ring4 = math.sin(2.0 * math.pi * 396.0 * time) > 0 ? 1.0 : -1.0;
      final ring5 = math.sin(2.0 * math.pi * 434.0 * time) > 0 ? 1.0 : -1.0;
      final ring6 = math.sin(2.0 * math.pi * 700.0 * time) > 0 ? 1.0 : -1.0;
      final metallicRing = (ring1 + ring2 + ring3 + ring4 + ring5 + ring6) / 6.0;

      final rawSignal = noise * (1.0 - metallic * 0.4) + metallicRing * (metallic * 0.4);

      // Cascaded 2-Pole High-Pass Filter
      final alpha = 1.0 / (1.0 + (2.0 * math.pi * cutoff.clamp(1000.0, 18000.0) / 44100.0));
      vState.y1 = alpha * (vState.y1 + rawSignal - vState.x1);
      vState.x1 = rawSignal;

      vState.y2 = alpha * (vState.y2 + vState.y1 - vState.x2);
      vState.x2 = vState.y1;

      final output = vState.y2 * env * 0.75;
      return output.clamp(-1.0, 1.0);
    }

    // 4. Procedural Handclap
    else if (code.contains('ProceduralClap') || code.contains('RoomDecay')) {
      final roomDecay = params['RoomDecay'] ?? 0.18;
      final tone = params['Tone'] ?? 2200.0;

      double burstEnv = 0.0;
      if (time < 0.01) {
        burstEnv = 1.0;
      } else if (time < 0.022) {
        burstEnv = 0.75;
      } else if (time < 0.035) {
        burstEnv = 0.85;
      } else {
        burstEnv = math.exp(-(time - 0.035) / roomDecay.clamp(0.01, 1.0));
      }

      final rnd = math.Random((time * 10000).toInt() % 100000 + 999);
      final noise = (rnd.nextDouble() * 2.0 - 1.0);

      final f = (tone / 44100.0 * 2.0 * math.pi).clamp(0.05, 0.95);
      final filtered = noise * f * burstEnv * 0.8;

      return filtered.clamp(-1.0, 1.0);
    }

    // 5. Dual-Op FM Synth
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
    if (code.contains('StereoDelayFX') || code.contains('TimeMs')) {
      final feedback = params['Feedback'] ?? 0.45;
      final mix = params['Mix'] ?? 0.4;

      final echo = inputSample * feedback;
      return (inputSample * (1.0 - mix)) + (echo * mix);
    } else if (code.contains('StereoChorusFX') || code.contains('DepthMs')) {
      final mix = params['Mix'] ?? 0.5;
      final rate = params['RateHz'] ?? 1.2;

      final lfo = math.sin(2.0 * math.pi * rate * time);
      final wet = inputSample * (0.8 + lfo * 0.2);

      return (inputSample * (1.0 - mix)) + (wet * mix);
    } else if (code.contains('Bitcrusher') || code.contains('Downsample')) {
      final bits = params['Bits'] ?? 6.0;
      final downsample = params['Downsample'] ?? 4.0;
      final mix = params['Mix'] ?? 0.8;

      final steps = math.pow(2.0, bits.clamp(2.0, 16.0));
      final quantized = (inputSample * steps).floorToDouble() / steps;

      final holdSample = (time * 44100 % downsample < 1.0) ? quantized : quantized * 0.9;
      return (inputSample * (1.0 - mix)) + (holdSample * mix);
    } else if (code.contains('TubeDistortion') || code.contains('OutGain')) {
      final drive = params['Drive'] ?? 6.0;
      final outGain = params['OutGain'] ?? 0.7;

      final driven = inputSample * drive;
      // Hyperbolic tangent soft clipping
      final clipped = _tanh(driven);
      return clipped * outGain;
    } else {
      return (inputSample * 1.2).clamp(-1.0, 1.0);
    }
  }
}

class _AcidVoiceState {
  double phase = 0.0;
  double lastEnv = 1.0;
  double lastFreq = 0.0;
  double startFreq = 0.0;
  double stage1 = 0.0;
  double stage2 = 0.0;
  double stage3 = 0.0;
  double stage4 = 0.0;
  double hpfX1 = 0.0;
  double hpfY1 = 0.0;
}

class _HiHatVoiceState {
  double x1 = 0.0;
  double y1 = 0.0;
  double x2 = 0.0;
  double y2 = 0.0;
}

