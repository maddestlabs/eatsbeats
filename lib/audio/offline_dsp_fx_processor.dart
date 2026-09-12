import 'dart:math' as math;
import 'dart:typed_data';

import '../models/track_model.dart';
import '../eatscript/eat_dsp_synthesizer.dart';
import 'convolver_engine.dart';
import 'procedural_ir_generator.dart';
import 'snes_dsp_engine.dart';

/// Pure-Dart offline DSP processor that executes Track and Master FX racks,
/// including parametric EQ, dynamic filters, delays, distortion, bitcrushers,
/// compressors, tape warmth, and Eatscript custom effects.
class OfflineDspFxProcessor {
  /// Applies a track's 4-band Parametric EQ in place on a mono audio buffer.
  static void processTrackEq(
    Float32List buffer, {
    required TrackChannel track,
    int sampleRate = 44100,
  }) {
    if (!track.eqEnabled) return;
    _apply4BandEq(
      buffer,
      hpfFreq: track.eqHpf,
      lowGainDb: track.eqLowGain,
      midFreq: track.eqMidFreq,
      midGainDb: track.eqMidGain,
      midQ: track.eqMidQ,
      highGainDb: track.eqHighGain,
      sampleRate: sampleRate,
    );
  }

  /// Applies Master bus 4-band Parametric EQ in place on stereo buffers.
  static void processMasterEq(
    Float32List left,
    Float32List right, {
    double subCutFreq = 25.0,
    double lowGainDb = 0.0,
    double midFreq = 1000.0,
    double midGainDb = 0.0,
    double highGainDb = 0.0,
    int sampleRate = 44100,
  }) {
    _apply4BandEq(
      left,
      hpfFreq: subCutFreq,
      lowGainDb: lowGainDb,
      midFreq: midFreq,
      midGainDb: midGainDb,
      midQ: 1.0,
      highGainDb: highGainDb,
      sampleRate: sampleRate,
    );
    _apply4BandEq(
      right,
      hpfFreq: subCutFreq,
      lowGainDb: lowGainDb,
      midFreq: midFreq,
      midGainDb: midGainDb,
      midQ: 1.0,
      highGainDb: highGainDb,
      sampleRate: sampleRate,
    );
  }

  /// Applies a track's audio FX chain sequentially on a mono buffer.
  static void processTrackFx(
    Float32List buffer, {
    required List<FXInsert> fxRack,
    double bpm = 120.0,
    int sampleRate = 44100,
  }) {
    if (fxRack.isEmpty || buffer.isEmpty) return;

    for (final fx in fxRack) {
      if (!fx.enabled || fx.mix <= 0.0) continue;
      _applySingleFxMono(buffer, fx, bpm: bpm, sampleRate: sampleRate);
    }
  }

  /// Applies the Master bus audio FX chain sequentially across stereo buffers.
  static void processStereoFx(
    Float32List left,
    Float32List right, {
    required List<FXInsert> fxRack,
    double bpm = 120.0,
    int sampleRate = 44100,
  }) {
    if (fxRack.isEmpty || left.isEmpty) return;

    for (final fx in fxRack) {
      if (!fx.enabled || fx.mix <= 0.0) continue;
      _applySingleFxStereo(left, right, fx, bpm: bpm, sampleRate: sampleRate);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Single Effect Dispatchers
  // ──────────────────────────────────────────────────────────────────────────

  static void _applySingleFxMono(
    Float32List buffer,
    FXInsert fx, {
    double bpm = 120.0,
    int sampleRate = 44100,
  }) {
    final mix = fx.mix.clamp(0.0, 1.0);

    switch (fx.type) {
      case FXType.biquadFilter:
        final cutoff = fx.params['cutoff'] ?? fx.params['Cutoff'] ?? 2500.0;
        final res = fx.params['resonance'] ?? fx.params['Resonance'] ?? 1.0;
        final filterType = (fx.params['filterType'] ?? 0.0).toInt();
        _applyBiquad(buffer, cutoff: cutoff, q: res, type: filterType, sampleRate: sampleRate, mix: mix);
        break;

      case FXType.delay:
        final timeMs = fx.params['TimeMs'] ?? fx.params['delayTime'] ?? 300.0;
        final feedback = (fx.params['Feedback'] ?? fx.params['feedback'] ?? 0.4).clamp(0.0, 0.95);
        _applyDelayMono(buffer, timeMs: timeMs, feedback: feedback, mix: mix, sampleRate: sampleRate);
        break;

      case FXType.distortion:
        final drive = fx.params['Drive'] ?? fx.params['drive'] ?? 4.0;
        final tone = fx.params['Tone'] ?? fx.params['tone'] ?? 4000.0;
        _applyDistortion(buffer, drive: drive, tone: tone, mix: mix, sampleRate: sampleRate);
        break;

      case FXType.bitcrusher:
        final bits = (fx.params['Bits'] ?? fx.params['bits'] ?? 8.0).clamp(2.0, 16.0);
        final downsample = (fx.params['Downsample'] ?? fx.params['downsample'] ?? 4.0).clamp(1.0, 32.0);
        _applyBitcrusher(buffer, bits: bits, downsample: downsample, mix: mix);
        break;

      case FXType.vintageTape:
        final drive = fx.params['Drive'] ?? 1.8;
        _applyTapeWarmth(buffer, drive: drive, mix: mix, sampleRate: sampleRate);
        break;

      case FXType.compressor:
        final thresholdDb = fx.params['Threshold'] ?? -16.0;
        final ratio = fx.params['Ratio'] ?? 4.0;
        final attackMs = fx.params['Attack'] ?? 15.0;
        final releaseMs = fx.params['Release'] ?? 100.0;
        _applyCompressor(buffer, thresholdDb: thresholdDb, ratio: ratio, attackMs: attackMs, releaseMs: releaseMs, mix: mix, sampleRate: sampleRate);
        break;

      case FXType.limiter:
        final ceilingDb = fx.params['Ceiling'] ?? -0.3;
        _applyLimiter(buffer, ceilingDb: ceilingDb);
        break;

      case FXType.convolutionReverb:
        final preDelayMs = fx.params['PreDelayMs'] ?? 15.0;
        final irName = fx.irSampleName ?? 'Great Hall';
        _applyConvolutionReverbMono(buffer, irName: irName, preDelayMs: preDelayMs, mix: mix, sampleRate: sampleRate);
        break;

      case FXType.eatScriptFX:
        if (fx.eatScriptCode != null && fx.eatScriptCode!.isNotEmpty) {
          if (fx.presetId == 'snes_downsampler' || fx.eatScriptCode!.contains('SNESDownsampler')) {
            final rateIdx = (fx.eatScriptParams['SampleRate'] ?? 2.0).toInt();
            final brrBits = fx.eatScriptParams['BRRBits'] ?? 4.0;
            final gFilter = fx.eatScriptParams['GaussianFilter'] ?? 0.85;
            final drive = fx.eatScriptParams['Drive'] ?? 1.0;
            SNESDownsamplerEngine.processBuffer(
              buffer,
              rateIndex: rateIdx,
              brrBits: brrBits,
              gaussianFilter: gFilter,
              drive: drive,
              mix: mix,
              hostSampleRate: sampleRate,
            );
          } else {
            _applyEatScriptDsp(buffer, code: fx.eatScriptCode!, params: fx.eatScriptParams, mix: mix, sampleRate: sampleRate);
          }
        }
        break;
    }
  }

  static void _applySingleFxStereo(
    Float32List left,
    Float32List right,
    FXInsert fx, {
    double bpm = 120.0,
    int sampleRate = 44100,
  }) {
    final mix = fx.mix.clamp(0.0, 1.0);

    switch (fx.type) {
      case FXType.delay:
        final timeMs = fx.params['TimeMs'] ?? fx.params['delayTime'] ?? 350.0;
        final feedback = (fx.params['Feedback'] ?? fx.params['feedback'] ?? 0.45).clamp(0.0, 0.95);
        // Ping-pong stereo spread
        _applyDelayMono(left, timeMs: timeMs, feedback: feedback, mix: mix, sampleRate: sampleRate);
        _applyDelayMono(right, timeMs: timeMs * 1.333, feedback: feedback * 0.9, mix: mix, sampleRate: sampleRate);
        break;

      case FXType.convolutionReverb:
        final preDelayMs = fx.params['PreDelayMs'] ?? 15.0;
        final irName = fx.irSampleName ?? 'Great Hall';
        _applyConvolutionReverbStereo(left, right, irName: irName, preDelayMs: preDelayMs, mix: mix, sampleRate: sampleRate);
        break;

      default:
        _applySingleFxMono(left, fx, bpm: bpm, sampleRate: sampleRate);
        _applySingleFxMono(right, fx, bpm: bpm, sampleRate: sampleRate);
        break;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DSP Primitive Algorithms (Biquad, Delay, Distortion, Dynamics)
  // ──────────────────────────────────────────────────────────────────────────

  static void _apply4BandEq(
    Float32List buffer, {
    double hpfFreq = 25.0,
    double lowGainDb = 0.0,
    double midFreq = 1000.0,
    double midGainDb = 0.0,
    double midQ = 1.0,
    double highGainDb = 0.0,
    int sampleRate = 44100,
  }) {
    final fs = sampleRate.toDouble();

    // 1. Sub HPF (12 dB/oct Butterworth Highpass)
    if (hpfFreq > 20.0) {
      final f = _BiquadCoeffs.highPass(fs, hpfFreq, 0.707);
      _filterInPlace(buffer, f);
    }

    // 2. Low Shelf (80 Hz)
    if (lowGainDb.abs() > 0.1) {
      final f = _BiquadCoeffs.lowShelf(fs, 100.0, lowGainDb);
      _filterInPlace(buffer, f);
    }

    // 3. Parametric Mid Peak
    if (midGainDb.abs() > 0.1) {
      final f = _BiquadCoeffs.peakingEQ(fs, midFreq, midQ, midGainDb);
      _filterInPlace(buffer, f);
    }

    // 4. High Shelf (8000 Hz)
    if (highGainDb.abs() > 0.1) {
      final f = _BiquadCoeffs.highShelf(fs, 8000.0, highGainDb);
      _filterInPlace(buffer, f);
    }
  }

  static void _applyBiquad(
    Float32List buffer, {
    required double cutoff,
    required double q,
    required int type, // 0 = lowpass, 1 = highpass, 2 = bandpass, 3 = notch
    required int sampleRate,
    required double mix,
  }) {
    final fs = sampleRate.toDouble();
    _BiquadCoeffs coeffs;
    switch (type) {
      case 1:
        coeffs = _BiquadCoeffs.highPass(fs, cutoff, q);
        break;
      case 2:
        coeffs = _BiquadCoeffs.bandPass(fs, cutoff, q);
        break;
      default:
        coeffs = _BiquadCoeffs.lowPass(fs, cutoff, q);
        break;
    }

    if (mix >= 0.99) {
      _filterInPlace(buffer, coeffs);
    } else {
      final dry = Float32List.fromList(buffer);
      _filterInPlace(buffer, coeffs);
      for (int i = 0; i < buffer.length; i++) {
        buffer[i] = (dry[i] * (1.0 - mix)) + (buffer[i] * mix);
      }
    }
  }

  static void _applyDelayMono(
    Float32List buffer, {
    required double timeMs,
    required double feedback,
    required double mix,
    required int sampleRate,
  }) {
    final int delaySamples = math.max(1, (timeMs * sampleRate / 1000.0).round());
    if (delaySamples >= buffer.length) return;

    final Float32List delayLine = Float32List(delaySamples);
    int delayIdx = 0;

    for (int i = 0; i < buffer.length; i++) {
      final dry = buffer[i];
      final delayedSample = delayLine[delayIdx];

      // Damped feedback with gentle lowpass to keep echoes natural
      final newDelayValue = dry + (delayedSample * feedback);
      delayLine[delayIdx] = newDelayValue;

      delayIdx = (delayIdx + 1) % delaySamples;
      buffer[i] = (dry * (1.0 - mix)) + (delayedSample * mix);
    }
  }

  static void _applyDistortion(
    Float32List buffer, {
    required double drive,
    required double tone,
    required double mix,
    required int sampleRate,
  }) {
    final double safeDrive = math.max(1.0, drive);
    final toneFilter = _BiquadCoeffs.lowPass(sampleRate.toDouble(), tone, 0.707);

    for (int i = 0; i < buffer.length; i++) {
      final dry = buffer[i];
      final driven = dry * safeDrive;
      // Hyperbolic tangent soft saturation
      final sat = (math.exp(driven) - math.exp(-driven)) / (math.exp(driven) + math.exp(-driven));
      buffer[i] = (dry * (1.0 - mix)) + ((sat / math.sqrt(safeDrive)) * mix);
    }

    _filterInPlace(buffer, toneFilter);
  }

  static void _applyBitcrusher(
    Float32List buffer, {
    required double bits,
    required double downsample,
    required double mix,
  }) {
    final double steps = math.pow(2.0, bits).toDouble();
    final int downsampleInt = math.max(1, downsample.round());
    double heldSample = 0.0;

    for (int i = 0; i < buffer.length; i++) {
      final dry = buffer[i];
      if (i % downsampleInt == 0) {
        // Quantize amplitude
        heldSample = (dry * steps).roundToDouble() / steps;
      }
      buffer[i] = (dry * (1.0 - mix)) + (heldSample * mix);
    }
  }

  static void _applyTapeWarmth(
    Float32List buffer, {
    required double drive,
    required double mix,
    required int sampleRate,
  }) {
    final fs = sampleRate.toDouble();
    final warmShelf = _BiquadCoeffs.lowShelf(fs, 90.0, 2.0 * drive);
    final highRollOff = _BiquadCoeffs.lowPass(fs, 13500.0, 0.707);

    for (int i = 0; i < buffer.length; i++) {
      final dry = buffer[i];
      final x = dry * drive;
      // Asymmetrical tape saturation
      final sat = x - (0.15 * x * x) - (0.05 * x * x * x);
      buffer[i] = (dry * (1.0 - mix)) + (sat.clamp(-1.0, 1.0) * mix);
    }

    _filterInPlace(buffer, warmShelf);
    _filterInPlace(buffer, highRollOff);
  }

  static void _applyCompressor(
    Float32List buffer, {
    required double thresholdDb,
    required double ratio,
    required double attackMs,
    required double releaseMs,
    required double mix,
    required int sampleRate,
  }) {
    final double threshLin = math.pow(10.0, thresholdDb / 20.0).toDouble();
    final double attackCoeff = math.exp(-1.0 / (attackMs * sampleRate / 1000.0));
    final double releaseCoeff = math.exp(-1.0 / (releaseMs * sampleRate / 1000.0));
    double env = 0.0;

    for (int i = 0; i < buffer.length; i++) {
      final dry = buffer[i];
      final absVal = dry.abs();

      if (absVal > env) {
        env = attackCoeff * env + (1.0 - attackCoeff) * absVal;
      } else {
        env = releaseCoeff * env + (1.0 - releaseCoeff) * absVal;
      }

      double gain = 1.0;
      if (env > threshLin && env > 0.0001) {
        final envDb = 20.0 * math.log(env) / math.ln10;
        final compressedDb = thresholdDb + (envDb - thresholdDb) / ratio;
        gain = math.pow(10.0, (compressedDb - envDb) / 20.0).toDouble();
      }

      final wet = dry * gain;
      buffer[i] = (dry * (1.0 - mix)) + (wet * mix);
    }
  }

  static void _applyLimiter(Float32List buffer, {required double ceilingDb}) {
    final double ceiling = math.pow(10.0, ceilingDb / 20.0).toDouble().clamp(0.05, 1.0);
    double maxPeak = 0.0;
    for (int i = 0; i < buffer.length; i++) {
      final absVal = buffer[i].abs();
      if (absVal > maxPeak) maxPeak = absVal;
    }

    if (maxPeak > ceiling) {
      final double attenuation = ceiling / maxPeak;
      for (int i = 0; i < buffer.length; i++) {
        buffer[i] *= attenuation;
      }
    }
  }

  static void _applyConvolutionReverbMono(
    Float32List buffer, {
    required String irName,
    required double preDelayMs,
    required double mix,
    required int sampleRate,
  }) {
    final stereo = ConvolverEngine.instance.getIrStereoSample(irName) ??
        ConvolverEngine.instance.getIrStereoSample('Great Hall');
    if (stereo != null && stereo.left.isNotEmpty) {
      _convolveWithIr(buffer, stereo.left, preDelayMs: preDelayMs, mix: mix, sampleRate: sampleRate);
    }
  }

  static void _applyConvolutionReverbStereo(
    Float32List left,
    Float32List right, {
    required String irName,
    required double preDelayMs,
    required double mix,
    required int sampleRate,
  }) {
    final stereo = ConvolverEngine.instance.getIrStereoSample(irName) ??
        ConvolverEngine.instance.getIrStereoSample('Great Hall');
    if (stereo != null && stereo.left.isNotEmpty && stereo.right.isNotEmpty) {
      _convolveWithIr(left, stereo.left, preDelayMs: preDelayMs, mix: mix, sampleRate: sampleRate);
      _convolveWithIr(right, stereo.right, preDelayMs: preDelayMs, mix: mix, sampleRate: sampleRate);
    }
  }

  static void _convolveWithIr(
    Float32List buffer,
    List<double> ir, {
    required double preDelayMs,
    required double mix,
    required int sampleRate,
  }) {
    if (buffer.isEmpty || ir.isEmpty) return;

    // Use up to 2048 samples of the impulse response for pristine acoustic space modeling
    final int irLen = math.min(ir.length, 2048);
    final int preDelaySamples = (preDelayMs * sampleRate / 1000.0).round();
    final Float32List dry = Float32List.fromList(buffer);

    // Normalize IR power
    double energy = 0.0;
    for (int k = 0; k < irLen; k++) {
      energy += ir[k].abs();
    }
    final double norm = energy > 0.0 ? (1.5 / math.max(1.0, math.sqrt(energy))) : 1.0;

    for (int i = 0; i < buffer.length; i++) {
      double wet = 0.0;
      final int maxK = math.min(irLen, i - preDelaySamples + 1);
      final int startK = math.max(0, i - preDelaySamples - dry.length + 1);

      for (int k = startK; k < maxK; k++) {
        final int srcIdx = i - preDelaySamples - k;
        if (srcIdx >= 0 && srcIdx < dry.length) {
          wet += dry[srcIdx] * ir[k];
        }
      }

      wet *= norm;
      buffer[i] = (dry[i] * (1.0 - mix)) + (wet * mix);
    }
  }

  static void _applyEatScriptDsp(
    Float32List buffer, {
    required String code,
    required Map<String, double> params,
    required double mix,
    required int sampleRate,
  }) {
    final double fs = sampleRate.toDouble();
    for (int i = 0; i < buffer.length; i++) {
      final dry = buffer[i];
      final t = i / fs;
      final wet = EatDspSynthesizer.evaluateEffect(
        code: code,
        inputSample: dry,
        time: t,
        params: params,
      );
      buffer[i] = (dry * (1.0 - mix)) + (wet * mix);
    }
  }

  static void _filterInPlace(Float32List buffer, _BiquadCoeffs f) {
    double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (int i = 0; i < buffer.length; i++) {
      final x = buffer[i];
      final y = f.b0 * x + f.b1 * x1 + f.b2 * x2 - f.a1 * y1 - f.a2 * y2;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
      buffer[i] = y;
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Biquad Filter Formula Helper (RBJ Audio EQ Cookbook)
// ────────────────────────────────────────────────────────────────────────────

class _BiquadCoeffs {
  final double b0, b1, b2, a1, a2;

  _BiquadCoeffs({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });

  factory _BiquadCoeffs.lowPass(double fs, double fc, double q) {
    final w0 = 2.0 * math.pi * fc.clamp(20.0, fs * 0.49) / fs;
    final alpha = math.sin(w0) / (2.0 * math.max(0.1, q));
    final cosw0 = math.cos(w0);

    final a0 = 1.0 + alpha;
    return _BiquadCoeffs(
      b0: ((1.0 - cosw0) / 2.0) / a0,
      b1: (1.0 - cosw0) / a0,
      b2: ((1.0 - cosw0) / 2.0) / a0,
      a1: (-2.0 * cosw0) / a0,
      a2: (1.0 - alpha) / a0,
    );
  }

  factory _BiquadCoeffs.highPass(double fs, double fc, double q) {
    final w0 = 2.0 * math.pi * fc.clamp(20.0, fs * 0.49) / fs;
    final alpha = math.sin(w0) / (2.0 * math.max(0.1, q));
    final cosw0 = math.cos(w0);

    final a0 = 1.0 + alpha;
    return _BiquadCoeffs(
      b0: ((1.0 + cosw0) / 2.0) / a0,
      b1: (-(1.0 + cosw0)) / a0,
      b2: ((1.0 + cosw0) / 2.0) / a0,
      a1: (-2.0 * cosw0) / a0,
      a2: (1.0 - alpha) / a0,
    );
  }

  factory _BiquadCoeffs.bandPass(double fs, double fc, double q) {
    final w0 = 2.0 * math.pi * fc.clamp(20.0, fs * 0.49) / fs;
    final alpha = math.sin(w0) / (2.0 * math.max(0.1, q));
    final cosw0 = math.cos(w0);

    final a0 = 1.0 + alpha;
    return _BiquadCoeffs(
      b0: (alpha) / a0,
      b1: 0.0,
      b2: (-alpha) / a0,
      a1: (-2.0 * cosw0) / a0,
      a2: (1.0 - alpha) / a0,
    );
  }

  factory _BiquadCoeffs.peakingEQ(double fs, double fc, double q, double gainDb) {
    final a = math.pow(10.0, gainDb / 40.0).toDouble();
    final w0 = 2.0 * math.pi * fc.clamp(20.0, fs * 0.49) / fs;
    final alpha = math.sin(w0) / (2.0 * math.max(0.1, q));
    final cosw0 = math.cos(w0);

    final a0 = 1.0 + alpha / a;
    return _BiquadCoeffs(
      b0: (1.0 + alpha * a) / a0,
      b1: (-2.0 * cosw0) / a0,
      b2: (1.0 - alpha * a) / a0,
      a1: (-2.0 * cosw0) / a0,
      a2: (1.0 - alpha / a) / a0,
    );
  }

  factory _BiquadCoeffs.lowShelf(double fs, double fc, double gainDb) {
    final a = math.pow(10.0, gainDb / 40.0).toDouble();
    final w0 = 2.0 * math.pi * fc.clamp(20.0, fs * 0.49) / fs;
    final alpha = math.sin(w0) / 2.0 * math.sqrt(2.0);
    final cosw0 = math.cos(w0);
    final twoSqrtAa = 2.0 * math.sqrt(a) * alpha;

    final a0 = (a + 1.0) + (a - 1.0) * cosw0 + twoSqrtAa;
    return _BiquadCoeffs(
      b0: (a * ((a + 1.0) - (a - 1.0) * cosw0 + twoSqrtAa)) / a0,
      b1: (2.0 * a * ((a - 1.0) - (a + 1.0) * cosw0)) / a0,
      b2: (a * ((a + 1.0) - (a - 1.0) * cosw0 - twoSqrtAa)) / a0,
      a1: (-2.0 * ((a - 1.0) + (a + 1.0) * cosw0)) / a0,
      a2: ((a + 1.0) + (a - 1.0) * cosw0 - twoSqrtAa) / a0,
    );
  }

  factory _BiquadCoeffs.highShelf(double fs, double fc, double gainDb) {
    final a = math.pow(10.0, gainDb / 40.0).toDouble();
    final w0 = 2.0 * math.pi * fc.clamp(20.0, fs * 0.49) / fs;
    final alpha = math.sin(w0) / 2.0 * math.sqrt(2.0);
    final cosw0 = math.cos(w0);
    final twoSqrtAa = 2.0 * math.sqrt(a) * alpha;

    final a0 = (a + 1.0) - (a - 1.0) * cosw0 + twoSqrtAa;
    return _BiquadCoeffs(
      b0: (a * ((a + 1.0) + (a - 1.0) * cosw0 + twoSqrtAa)) / a0,
      b1: (-2.0 * a * ((a - 1.0) + (a + 1.0) * cosw0)) / a0,
      b2: (a * ((a + 1.0) + (a - 1.0) * cosw0 - twoSqrtAa)) / a0,
      a1: (2.0 * ((a - 1.0) - (a + 1.0) * cosw0)) / a0,
      a2: ((a + 1.0) - (a - 1.0) * cosw0 - twoSqrtAa) / a0,
    );
  }
}

