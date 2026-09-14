import 'dart:math' as math;
import 'dart:typed_data';

/// Voice state retaining history for TB-303 oscillators, envelopes, and filter stages.
class EatsTb303VoiceState {
  double phase = 0.0;
  double subPhase = 0.0;
  double lastFreq = 0.0;
  double startFreq = 0.0;
  double lastEnv = 1.0;
  double mainEnv = 1.0;
  double ampEnv = 1.0;
  double rc1 = 0.0;
  double rc2 = 0.0;
  double stage1 = 0.0;
  double stage2 = 0.0;
  double stage3 = 0.0;
  double stage4 = 0.0;
  double feedbackHpX1 = 0.0;
  double feedbackHpY1 = 0.0;
  double preHpX1 = 0.0;
  double preHpY1 = 0.0;
  double postHpX1 = 0.0;
  double postHpY1 = 0.0;

  void reset() {
    phase = 0.0;
    subPhase = 0.0;
    lastFreq = 0.0;
    startFreq = 0.0;
    lastEnv = 1.0;
    mainEnv = 1.0;
    ampEnv = 1.0;
    rc1 = 0.0;
    rc2 = 0.0;
    stage1 = 0.0;
    stage2 = 0.0;
    stage3 = 0.0;
    stage4 = 0.0;
    feedbackHpX1 = 0.0;
    feedbackHpY1 = 0.0;
    preHpX1 = 0.0;
    preHpY1 = 0.0;
    postHpX1 = 0.0;
    postHpY1 = 0.0;
  }
}

/// Core DSP Synthesis Engine for TB-303 Acid Bassline emulation.
/// Implements the authentic Robin Schmidt Open303 and Mystran diode ladder DSP.
/// Pure Dart - zero Flutter dependencies for headless CLI calibration & DAW playback.
class EatsTb303Core {
  static final Map<String, EatsTb303VoiceState> _voiceStates = {};

  static EatsTb303VoiceState getVoice(String key) {
    return _voiceStates.putIfAbsent(key, () => EatsTb303VoiceState());
  }

  static void clearVoice(String trackId) {
    _voiceStates.remove(trackId);
  }

  static void clearAllVoices() {
    _voiceStates.clear();
  }

  /// High-performance rational Pade approximation of tanh for smooth saturation.
  static double tanh(double x) {
    if (x < -3.0) return -1.0;
    if (x > 3.0) return 1.0;
    final x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);
  }

  /// Open303 empirical constants for envelope modulation scaler and offset
  static const double _c0 = 313.8152786059267;
  static const double _c1 = 2394.411986817546;
  static const double _oF = 0.048292930943553;
  static const double _oC = 0.294391201442418;
  static const double _sLoF = 3.773996325111173;
  static const double _sLoC = 0.736965594166206;
  static const double _sHiF = 4.194548788411135;
  static const double _sHiC = 0.864344900642434;

  /// Synthesizes a mono audio buffer for a note event.
  static Float32List synthesizeBuffer({
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
    double sampleRate = 44100.0,
  }) {
    final int numSamples = (sampleRate * durationSec).toInt().clamp(1, (sampleRate * 10).toInt());
    final buffer = Float32List(numSamples);

    if (freq <= 0) return buffer;

    // 1. Parameter extraction with authentic 303 calibration curves
    final waveType = params['Waveform'] ?? 0.0;

    final rawCutoff = params['Cutoff'] ?? 1400.0;
    // Map raw cutoff to 0.0..1.0 where 0.0=314Hz, 1.0=2394Hz
    final double normCutoff = rawCutoff > 10.0
        ? (math.log(rawCutoff.clamp(314.0, 3500.0) / 314.0) / math.log(2394.0 / 314.0)).clamp(0.0, 1.2)
        : rawCutoff.clamp(0.0, 1.2);
    final double nominalCutoff = 314.0 * math.pow(2394.0 / 314.0, normCutoff);

    final rawRes = params['Resonance'] ?? 8.0;
    final double normRes = (rawRes > 16.0 ? (rawRes / 100.0) : (rawRes > 1.0 ? (rawRes / 16.0) : rawRes)).clamp(0.0, 1.0);

    final rawEnv = params['EnvMod'] ?? 0.75;
    final double normEnv = (rawEnv > 1.0 ? (rawEnv / 100.0) : rawEnv).clamp(0.0, 1.0);

    final rawDecay = params['Decay'] ?? 0.5;
    // Open303 decay range: 200ms to 2000ms
    final double normDecay = (rawDecay > 10.0
            ? (math.log(rawDecay.clamp(200.0, 2000.0) / 200.0) / math.log(2000.0 / 200.0))
            : rawDecay)
        .clamp(0.0, 1.0);
    final double decayMs = 200.0 * math.pow(2000.0 / 200.0, normDecay);

    final rawAccent = params['Accent'] ?? 0.0;
    final double normAccent = (rawAccent > 1.0 ? (rawAccent / 100.0) : rawAccent).clamp(0.0, 1.0);

    final drive = params['Overdrive'] ?? params['Drive'] ?? 0.3;
    final slideParam = params['Slide'] ?? params['Portamento'] ?? params['Glide'] ?? 0.0;
    final double glideTime = slideParam > 0.01 ? (0.010 + slideParam * 0.200) : 0.060;

    // Extended parameters (Devil Fish / Octave mods)
    final tuningOffset = params['Tuning'] ?? params['Pitch'] ?? 0.0;
    final octaveShift = (params['Octave'] ?? 0.0).round();
    final subVolume = params['SubVolume'] ?? params['SubOscVolume'] ?? 0.0;
    final subWave = params['SubWaveform'] ?? 0.0;

    final voiceKey = trackId ?? 'default_303';
    final vState = getVoice(voiceKey);

    final effectiveFreq = freq * math.pow(2.0, octaveShift + (tuningOffset / 12.0));

    if (!isSlide && slideParam <= 0.01) {
      vState.reset();
      vState.startFreq = effectiveFreq;
    } else {
      vState.startFreq = vState.lastFreq > 0 ? vState.lastFreq : effectiveFreq;
    }

    final bool hasAccent = isAccent ||
        (velocity > 0.75) ||
        (articulation != null && articulation.toLowerCase().contains('accent'));
    final double accentGain = hasAccent ? normAccent : 0.0;
    final double activeDecayMs = hasAccent ? 200.0 : decayMs;

    double targetFreq = effectiveFreq;
    if (targetMidiNote != null && targetMidiNote > 0) {
      targetFreq = 440.0 * math.pow(2.0, ((targetMidiNote + octaveShift * 12) - 69 + tuningOffset) / 12.0);
    } else if (isSlide || slideParam > 0.01) {
      targetFreq = targetMidiNote != null
          ? (440.0 * math.pow(2.0, ((targetMidiNote + octaveShift * 12) - 69 + tuningOffset) / 12.0))
          : effectiveFreq;
    }

    // 2. Open303 Scaler and Offset calculations
    // Pot taper: TB-303 envelope depth pot exhibits audio taper
    final double e = math.pow(normEnv, 2.0).toDouble();
    final double c = (math.log(nominalCutoff / _c0) / math.log(_c1 / _c0)).clamp(0.0, 1.0);
    final double sLo = _sLoF * e + _sLoC;
    final double sHi = _sHiF * e + _sHiC;
    final double envScaler = (1.0 - c) * sLo + c * sHi;
    final double envOffset = _oF * c + _oC;

    // Filter coefficients & envelope decay rates
    final double decayCoeff = math.exp(-1.0 / (sampleRate * 0.001 * activeDecayMs));
    final double ampDecayCoeff = math.exp(-1.0 / (sampleRate * 0.001 * 1230.0));
    final double rc1Coeff = math.exp(-1.0 / (sampleRate * 0.001 * 3.0));
    final double rc2Coeff = math.exp(-1.0 / (sampleRate * 0.001 * 3.0));

    // Skewed resonance parameter r (self-oscillation matching Open303)
    final double r = (1.0 - math.exp(-3.0 * normRes)) / (1.0 - math.exp(-3.0));

    // 4x internal oversampling for diode ladder stability & warmth
    const int oversampling = 4;
    final double filterRate = sampleRate * oversampling;

    // 150 Hz feedback highpass filter coefficient
    final double fbHpX = math.exp(-2.0 * math.pi * 150.0 / filterRate);
    final double fbHpB0 = 0.5 * (1.0 + fbHpX);
    final double fbHpB1 = -0.5 * (1.0 + fbHpX);
    final double fbHpA1 = fbHpX;

    // 44.486 Hz pre-filter highpass filter coefficient
    final double preHpX = math.exp(-2.0 * math.pi * 44.486 / filterRate);
    final double preHpB0 = 0.5 * (1.0 + preHpX);
    final double preHpB1 = -0.5 * (1.0 + preHpX);
    final double preHpA1 = preHpX;

    final double driveGain = drive > 0.02 ? (1.0 + drive * 3.5) : 1.0;
    final int fadeSamples = (sampleRate * 0.04).toInt().clamp(64, math.max(1, numSamples ~/ 4));

    for (int i = 0; i < numSamples; i++) {
      final time = i / sampleRate;

      // Pitch glide for portamento slide
      double currentFreq = effectiveFreq;
      if (targetFreq != effectiveFreq || isSlide || slideParam > 0.01 || (vState.startFreq != effectiveFreq)) {
        currentFreq = targetFreq + (vState.startFreq - targetFreq) * math.exp(-time / glideTime);
      }
      vState.lastFreq = currentFreq;

      // Envelope stepping
      vState.mainEnv *= decayCoeff;
      vState.lastEnv = vState.mainEnv;
      vState.rc1 = vState.mainEnv + rc1Coeff * (vState.rc1 - vState.mainEnv);

      double tmp1 = envScaler * (vState.rc1 - envOffset);
      double tmp2 = 0.0;
      if (hasAccent) {
        vState.rc2 = vState.mainEnv + rc2Coeff * (vState.rc2 - vState.mainEnv);
        tmp2 = accentGain * vState.rc2;
      }

      final double instCutoff = (nominalCutoff * math.pow(2.0, tmp1 + tmp2)).clamp(60.0, 18000.0);

      // Mystran & Kunn Diode Ladder coefficient calculations
      final double wc = 2.0 * math.pi * instCutoff / filterRate;
      final double fx = wc * (1.0 / math.sqrt2) / (2.0 * math.pi);
      final double b0 = (0.00045522346 + 6.1922189 * fx) /
          (1.0 + 12.358354 * fx + 4.4156345 * (fx * fx));
      double k = fx *
              (fx *
                      (fx *
                              (fx *
                                      (fx * (fx + 7198.6997) - 5837.7917) -
                                  476.47308) +
                          614.95611) +
                  213.87126) +
          16.998792;
      double g = k * (1.0 / 17.0);
      g = (g - 1.0) * r + 1.0;
      g = g * (1.0 + r);
      k = k * r;

      // Amp envelope
      vState.ampEnv *= ampDecayCoeff;
      final double totalAmp = vState.ampEnv + 0.45 * vState.mainEnv + (hasAccent ? 2.5 * accentGain * vState.mainEnv : 0.0);

      // Oversampled filter processing loop
      final double phaseInc = currentFreq / filterRate;
      double filtered = 0.0;

      for (int step = 0; step < oversampling; step++) {
        vState.phase = (vState.phase + phaseInc) % 1.0;
        final normPhase = vState.phase;

        // 303 Saw: Inverted ramp wave
        final sawRaw = 2.0 * normPhase - 1.0;
        // 303 Square: Asymmetric pulse wave
        final sqrRaw = normPhase < 0.48 ? 0.85 : -0.85;

        final osc = (1.0 - waveType) * sawRaw + waveType * sqrRaw;

        // Sub-oscillator (-1 octave)
        double subOsc = 0.0;
        if (subVolume > 0.01) {
          vState.subPhase = (vState.subPhase + phaseInc * 0.5) % 1.0;
          subOsc = subWave > 0.5
              ? (vState.subPhase < 0.5 ? 0.7 : -0.7)
              : math.sin(2.0 * math.pi * vState.subPhase);
        }
        final rawInput = osc * (1.0 - subVolume * 0.4) + subOsc * (subVolume * 0.6);

        // Pre-filter Highpass
        final preHpOut = preHpB0 * (-rawInput) + preHpB1 * vState.preHpX1 + preHpA1 * vState.preHpY1;
        vState.preHpX1 = -rawInput;
        vState.preHpY1 = preHpOut;

        // Feedback Highpass
        final fbHpIn = k * vState.stage4;
        final fbHpOut = fbHpB0 * fbHpIn + fbHpB1 * vState.feedbackHpX1 + fbHpA1 * vState.feedbackHpY1;
        vState.feedbackHpX1 = fbHpIn;
        vState.feedbackHpY1 = fbHpOut;

        // Diode ladder stage coupling
        final y0 = preHpOut - fbHpOut;
        vState.stage1 += 2.0 * b0 * (y0 - vState.stage1 + vState.stage2);
        vState.stage2 += b0 * (vState.stage1 - 2.0 * vState.stage2 + vState.stage3);
        vState.stage3 += b0 * (vState.stage2 - 2.0 * vState.stage3 + vState.stage4);
        vState.stage4 += b0 * (vState.stage3 - 2.0 * vState.stage4);

        filtered = 2.0 * g * vState.stage4;
      }

      // Post-filter DC blocking highpass (24 Hz)
      final postHpOut = 0.985 * (vState.postHpY1 + filtered - vState.postHpX1);
      vState.postHpX1 = filtered;
      vState.postHpY1 = postHpOut;

      // VCA Stage & Saturation
      double output = postHpOut * totalAmp * 0.45;
      if (drive > 0.02) {
        output = tanh(output * driveGain);
      }

      if (output.isNaN || output.isInfinite) output = 0.0;

      // Anti-click tail boundary fade
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

  /// Synthesizes a single audio sample for real-time sample-by-sample graph processing.
  static double synthesizeSample({
    required double freq,
    required int note,
    required Map<String, double> params,
    required int sampleIndex,
    required int totalSamples,
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
    double sampleRate = 44100.0,
  }) {
    if (freq <= 0) return 0.0;

    final waveType = params['Waveform'] ?? 0.0;
    final rawCutoff = params['Cutoff'] ?? 1400.0;
    final double normCutoff = rawCutoff > 10.0
        ? (math.log(rawCutoff.clamp(314.0, 3500.0) / 314.0) / math.log(2394.0 / 314.0)).clamp(0.0, 1.2)
        : rawCutoff.clamp(0.0, 1.2);
    final double nominalCutoff = 314.0 * math.pow(2394.0 / 314.0, normCutoff);

    final rawRes = params['Resonance'] ?? 8.0;
    final double normRes = (rawRes > 16.0 ? (rawRes / 100.0) : (rawRes > 1.0 ? (rawRes / 16.0) : rawRes)).clamp(0.0, 1.0);

    final rawEnv = params['EnvMod'] ?? 0.75;
    final double normEnv = (rawEnv > 1.0 ? (rawEnv / 100.0) : rawEnv).clamp(0.0, 1.0);

    final rawDecay = params['Decay'] ?? 0.5;
    final double normDecay = (rawDecay > 10.0
            ? (math.log(rawDecay.clamp(200.0, 2000.0) / 200.0) / math.log(2000.0 / 200.0))
            : rawDecay)
        .clamp(0.0, 1.0);
    final double decayMs = 200.0 * math.pow(2000.0 / 200.0, normDecay);

    final rawAccent = params['Accent'] ?? 0.0;
    final double normAccent = (rawAccent > 1.0 ? (rawAccent / 100.0) : rawAccent).clamp(0.0, 1.0);

    final drive = params['Overdrive'] ?? params['Drive'] ?? 0.3;
    final slideParam = params['Slide'] ?? params['Portamento'] ?? params['Glide'] ?? 0.0;
    final double glideTime = slideParam > 0.01 ? (0.010 + slideParam * 0.200) : 0.060;

    final tuningOffset = params['Tuning'] ?? params['Pitch'] ?? 0.0;
    final octaveShift = (params['Octave'] ?? 0.0).round();
    final subVolume = params['SubVolume'] ?? params['SubOscVolume'] ?? 0.0;
    final subWave = params['SubWaveform'] ?? 0.0;

    final voiceKey = trackId ?? 'default_303';
    final vState = getVoice(voiceKey);

    final effectiveFreq = freq * math.pow(2.0, octaveShift + (tuningOffset / 12.0));

    if (sampleIndex == 0) {
      if (!isSlide && slideParam <= 0.01) {
        vState.reset();
        vState.startFreq = effectiveFreq;
      } else {
        vState.startFreq = vState.lastFreq > 0 ? vState.lastFreq : effectiveFreq;
      }
    }

    final bool hasAccent = isAccent ||
        (velocity > 0.75) ||
        (articulation != null && articulation.toLowerCase().contains('accent'));
    final double accentGain = hasAccent ? normAccent : 0.0;
    final double activeDecayMs = hasAccent ? 200.0 : decayMs;

    double targetFreq = effectiveFreq;
    if (targetMidiNote != null && targetMidiNote > 0) {
      targetFreq = 440.0 * math.pow(2.0, ((targetMidiNote + octaveShift * 12) - 69 + tuningOffset) / 12.0);
    } else if (isSlide || slideParam > 0.01) {
      targetFreq = targetMidiNote != null
          ? (440.0 * math.pow(2.0, ((targetMidiNote + octaveShift * 12) - 69 + tuningOffset) / 12.0))
          : effectiveFreq;
    }

    final double e = math.pow(normEnv, 2.0).toDouble();
    final double c = (math.log(nominalCutoff / _c0) / math.log(_c1 / _c0)).clamp(0.0, 1.0);
    final double sLo = _sLoF * e + _sLoC;
    final double sHi = _sHiF * e + _sHiC;
    final double envScaler = (1.0 - c) * sLo + c * sHi;
    final double envOffset = _oF * c + _oC;

    final double decayCoeff = math.exp(-1.0 / (sampleRate * 0.001 * activeDecayMs));
    final double ampDecayCoeff = math.exp(-1.0 / (sampleRate * 0.001 * 1230.0));
    final double rc1Coeff = math.exp(-1.0 / (sampleRate * 0.001 * 3.0));
    final double rc2Coeff = math.exp(-1.0 / (sampleRate * 0.001 * 3.0));

    final double r = (1.0 - math.exp(-3.0 * normRes)) / (1.0 - math.exp(-3.0));

    const int oversampling = 4;
    final double filterRate = sampleRate * oversampling;

    final double fbHpX = math.exp(-2.0 * math.pi * 150.0 / filterRate);
    final double fbHpB0 = 0.5 * (1.0 + fbHpX);
    final double fbHpB1 = -0.5 * (1.0 + fbHpX);
    final double fbHpA1 = fbHpX;

    final double preHpX = math.exp(-2.0 * math.pi * 44.486 / filterRate);
    final double preHpB0 = 0.5 * (1.0 + preHpX);
    final double preHpB1 = -0.5 * (1.0 + preHpX);
    final double preHpA1 = preHpX;

    final double driveGain = drive > 0.02 ? (1.0 + drive * 3.5) : 1.0;
    final time = sampleIndex / sampleRate;

    double currentFreq = effectiveFreq;
    if (targetFreq != effectiveFreq || isSlide || slideParam > 0.01 || (vState.startFreq != effectiveFreq)) {
      currentFreq = targetFreq + (vState.startFreq - targetFreq) * math.exp(-time / glideTime);
    }
    vState.lastFreq = currentFreq;

    vState.mainEnv *= decayCoeff;
    vState.lastEnv = vState.mainEnv;
    vState.rc1 = vState.mainEnv + rc1Coeff * (vState.rc1 - vState.mainEnv);

    double tmp1 = envScaler * (vState.rc1 - envOffset);
    double tmp2 = 0.0;
    if (hasAccent) {
      vState.rc2 = vState.mainEnv + rc2Coeff * (vState.rc2 - vState.mainEnv);
      tmp2 = accentGain * vState.rc2;
    }

    final double instCutoff = (nominalCutoff * math.pow(2.0, tmp1 + tmp2)).clamp(60.0, 18000.0);

    final double wc = 2.0 * math.pi * instCutoff / filterRate;
    final double fx = wc * (1.0 / math.sqrt2) / (2.0 * math.pi);
    final double b0 = (0.00045522346 + 6.1922189 * fx) /
        (1.0 + 12.358354 * fx + 4.4156345 * (fx * fx));
    double k = fx *
            (fx *
                    (fx *
                            (fx *
                                    (fx * (fx + 7198.6997) - 5837.7917) -
                                476.47308) +
                        614.95611) +
                213.87126) +
        16.998792;
    double g = k * (1.0 / 17.0);
    g = (g - 1.0) * r + 1.0;
    g = g * (1.0 + r);
    k = k * r;

    vState.ampEnv *= ampDecayCoeff;
    final double totalAmp = vState.ampEnv + 0.45 * vState.mainEnv + (hasAccent ? 2.5 * accentGain * vState.mainEnv : 0.0);

    final double phaseInc = currentFreq / filterRate;
    double filtered = 0.0;

    for (int step = 0; step < oversampling; step++) {
      vState.phase = (vState.phase + phaseInc) % 1.0;
      final normPhase = vState.phase;

      final sawRaw = 2.0 * normPhase - 1.0;
      final sqrRaw = normPhase < 0.48 ? 0.85 : -0.85;

      final osc = (1.0 - waveType) * sawRaw + waveType * sqrRaw;

      double subOsc = 0.0;
      if (subVolume > 0.01) {
        vState.subPhase = (vState.subPhase + phaseInc * 0.5) % 1.0;
        subOsc = subWave > 0.5
            ? (vState.subPhase < 0.5 ? 0.7 : -0.7)
            : math.sin(2.0 * math.pi * vState.subPhase);
      }
      final rawInput = osc * (1.0 - subVolume * 0.4) + subOsc * (subVolume * 0.6);

      final preHpOut = preHpB0 * (-rawInput) + preHpB1 * vState.preHpX1 + preHpA1 * vState.preHpY1;
      vState.preHpX1 = -rawInput;
      vState.preHpY1 = preHpOut;

      final fbHpIn = k * vState.stage4;
      final fbHpOut = fbHpB0 * fbHpIn + fbHpB1 * vState.feedbackHpX1 + fbHpA1 * vState.feedbackHpY1;
      vState.feedbackHpX1 = fbHpIn;
      vState.feedbackHpY1 = fbHpOut;

      final y0 = preHpOut - fbHpOut;
      vState.stage1 += 2.0 * b0 * (y0 - vState.stage1 + vState.stage2);
      vState.stage2 += b0 * (vState.stage1 - 2.0 * vState.stage2 + vState.stage3);
      vState.stage3 += b0 * (vState.stage2 - 2.0 * vState.stage3 + vState.stage4);
      vState.stage4 += b0 * (vState.stage3 - 2.0 * vState.stage4);

      filtered = 2.0 * g * vState.stage4;
    }

    final postHpOut = 0.985 * (vState.postHpY1 + filtered - vState.postHpX1);
    vState.postHpX1 = filtered;
    vState.postHpY1 = postHpOut;

    double output = postHpOut * totalAmp * 0.45;
    if (drive > 0.02) {
      output = tanh(output * driveGain);
    }

    if (output.isNaN || output.isInfinite) output = 0.0;

    final fadeSamples = (sampleRate * 0.04).toInt().clamp(64, math.max(1, totalSamples ~/ 4));
    final samplesRemaining = totalSamples - 1 - sampleIndex;
    double boundaryFade = 1.0;
    if (samplesRemaining < fadeSamples && fadeSamples > 0) {
      final norm = (samplesRemaining / fadeSamples).clamp(0.0, 1.0);
      boundaryFade = 0.5 * (1.0 - math.cos(math.pi * norm));
    }

    return (output * boundaryFade).clamp(-1.0, 1.0);
  }
}
