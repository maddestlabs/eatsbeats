import 'dart:math' as math;
import 'dart:typed_data';

/// Diagnostic summary of comparison between synthesized audio and reference audio.
class AudioComparisonScore {
  final double spectralDistance;      // Multi-scale STFT loss (lower is better, 0.0 is identical)
  final double envelopeCorrelation;    // RMS temporal envelope correlation (-1.0 to 1.0, 1.0 is identical)
  final double overallSimilarity;     // 0.0 to 100.0% (higher is better)
  final double centroidDelta;         // Average difference in spectral brightness (Hz)
  final double highFreqDelta;         // High-frequency energy difference (positive = synth is brighter)
  final double transientDelta;        // Difference in initial 50ms transient energy
  final double decayDelta;            // Difference in tail decay slope

  AudioComparisonScore({
    required this.spectralDistance,
    required this.envelopeCorrelation,
    required this.overallSimilarity,
    required this.centroidDelta,
    required this.highFreqDelta,
    required this.transientDelta,
    required this.decayDelta,
  });

  /// Formats a diagnostic markdown report ideal for prompt feedback to Gemini.
  String toMarkdownReport({String title = 'Audio Comparison Report'}) {
    final buffer = StringBuffer();
    buffer.writeln('### $title');
    buffer.writeln('- **Overall Similarity**: ${overallSimilarity.toStringAsFixed(1)}%');
    buffer.writeln('- **Multi-scale Spectral Distance**: ${spectralDistance.toStringAsFixed(4)}');
    buffer.writeln('- **Envelope Correlation**: ${envelopeCorrelation.toStringAsFixed(4)}');
    buffer.writeln('- **Brightness (Centroid Delta)**: ${centroidDelta >= 0 ? '+' : ''}${centroidDelta.toStringAsFixed(1)} Hz');
    buffer.writeln('- **High-Frequency Squelch**: ${highFreqDelta > 0.05 ? "Too bright / harsh" : highFreqDelta < -0.05 ? "Too dark / deficient high harmonics" : "Well balanced"} (${highFreqDelta.toStringAsFixed(3)})');
    buffer.writeln('- **Transient Accent Punch**: ${transientDelta > 0.05 ? "Overshooting attack peak" : transientDelta < -0.05 ? "Lacks transient snap / accent pulse too weak" : "Accurate attack profile"} (${transientDelta.toStringAsFixed(3)})');
    buffer.writeln('- **Decay Curve**: ${decayDelta > 0.05 ? "Rings out too long / decay too slow" : decayDelta < -0.05 ? "Choked too quickly / decay too fast" : "Matched decay trajectory"} (${decayDelta.toStringAsFixed(3)})');
    return buffer.toString();
  }
}

/// Pure Dart audio analysis and metric comparison engine.
class AudioMetrics {
  /// Compares [synth] audio buffer against [reference] audio buffer at [sampleRate].
  static AudioComparisonScore compare(
    Float32List synth,
    Float32List reference, {
    int sampleRate = 44100,
  }) {
    final int minLength = math.min(synth.length, reference.length);
    if (minLength < 128) {
      return AudioComparisonScore(
        spectralDistance: 1.0,
        envelopeCorrelation: 0.0,
        overallSimilarity: 0.0,
        centroidDelta: 0.0,
        highFreqDelta: 0.0,
        transientDelta: 0.0,
        decayDelta: 0.0,
      );
    }

    // Normalize peak levels to avoid pure volume scaling bias
    final normSynth = _normalizePeak(synth, minLength);
    final normRef = _normalizePeak(reference, minLength);

    // 1. Multi-Scale Spectral Distance (STFT L1 + Log-magnitude)
    final mssLoss2048 = _calcStftLoss(normSynth, normRef, 2048, 512);
    final mssLoss1024 = _calcStftLoss(normSynth, normRef, 1024, 256);
    final mssLoss512 = _calcStftLoss(normSynth, normRef, 512, 128);
    final totalSpectralLoss = (mssLoss2048 * 0.4) + (mssLoss1024 * 0.35) + (mssLoss512 * 0.25);

    // 2. RMS Temporal Envelope Correlation
    final envSynth = _calcRmsEnvelope(normSynth, minLength, sampleRate);
    final envRef = _calcRmsEnvelope(normRef, minLength, sampleRate);
    final correlation = _calcCorrelation(envSynth, envRef);

    // 3. Spectral Centroid delta
    final centroidSynth = _calcSpectralCentroid(normSynth, sampleRate);
    final centroidRef = _calcSpectralCentroid(normRef, sampleRate);
    final centroidDelta = centroidSynth - centroidRef;

    // 4. High-frequency energy ratio delta (> 2.5 kHz)
    final hfSynth = _calcHighFreqRatio(normSynth, sampleRate, 2500.0);
    final hfRef = _calcHighFreqRatio(normRef, sampleRate, 2500.0);
    final highFreqDelta = hfSynth - hfRef;

    // 5. Transient energy (first 40ms)
    final int transientSamples = (sampleRate * 0.040).toInt().clamp(10, minLength);
    final tSynth = _calcRms(normSynth, 0, transientSamples);
    final tRef = _calcRms(normRef, 0, transientSamples);
    final transientDelta = tSynth - tRef;

    // 6. Decay tail energy (last 50% of the note)
    final int half = minLength ~/ 2;
    final dSynth = _calcRms(normSynth, half, minLength - half);
    final dRef = _calcRms(normRef, half, minLength - half);
    final decayDelta = dSynth - dRef;

    // Overall similarity percentage (0 to 100%)
    final spectralScore = (1.0 / (1.0 + totalSpectralLoss * 1.5)) * 60.0;
    final envelopeScore = math.max(0.0, correlation) * 40.0;
    final similarity = (spectralScore + envelopeScore).clamp(0.0, 100.0);

    return AudioComparisonScore(
      spectralDistance: totalSpectralLoss,
      envelopeCorrelation: correlation,
      overallSimilarity: similarity,
      centroidDelta: centroidDelta,
      highFreqDelta: highFreqDelta,
      transientDelta: transientDelta,
      decayDelta: decayDelta,
    );
  }

  static Float32List _normalizePeak(Float32List input, int length) {
    double maxAmp = 0.0;
    for (int i = 0; i < length; i++) {
      final a = input[i].abs();
      if (a > maxAmp) maxAmp = a;
    }
    final out = Float32List(length);
    if (maxAmp < 1e-6) return out;
    final scale = 0.95 / maxAmp;
    for (int i = 0; i < length; i++) {
      out[i] = input[i] * scale;
    }
    return out;
  }

  static double _calcStftLoss(Float32List a, Float32List b, int fftSize, int hopSize) {
    if (a.length < fftSize || b.length < fftSize) return 1.0;

    final window = _hannWindow(fftSize);
    final numFrames = (math.min(a.length, b.length) - fftSize) ~/ hopSize;
    if (numFrames <= 0) return 1.0;

    double totalLoss = 0.0;
    final realA = Float64List(fftSize);
    final imagA = Float64List(fftSize);
    final realB = Float64List(fftSize);
    final imagB = Float64List(fftSize);

    for (int f = 0; f < numFrames; f++) {
      final offset = f * hopSize;
      for (int i = 0; i < fftSize; i++) {
        realA[i] = a[offset + i] * window[i];
        imagA[i] = 0.0;
        realB[i] = b[offset + i] * window[i];
        imagB[i] = 0.0;
      }

      _fft(realA, imagA);
      _fft(realB, imagB);

      final halfFft = fftSize ~/ 2;
      double frameLoss = 0.0;
      for (int k = 0; k < halfFft; k++) {
        final magA = math.sqrt(realA[k] * realA[k] + imagA[k] * imagA[k]);
        final magB = math.sqrt(realB[k] * realB[k] + imagB[k] * imagB[k]);

        // Linear L1 loss + Log-magnitude loss
        final l1 = (magA - magB).abs();
        final logLoss = (math.log(1.0 + magA * 10.0) - math.log(1.0 + magB * 10.0)).abs();
        frameLoss += (l1 * 0.5 + logLoss * 0.5);
      }
      totalLoss += (frameLoss / halfFft);
    }

    return totalLoss / numFrames;
  }

  static Float64List _hannWindow(int size) {
    final w = Float64List(size);
    for (int i = 0; i < size; i++) {
      w[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (size - 1)));
    }
    return w;
  }

  /// In-place Cooley-Tukey Radix-2 Decimation-in-Time FFT
  static void _fft(Float64List real, Float64List imag) {
    final n = real.length;
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        final tempR = real[i];
        real[i] = real[j];
        real[j] = tempR;
        final tempI = imag[i];
        imag[i] = imag[j];
        imag[j] = tempI;
      }
      int k = n ~/ 2;
      while (k <= j) {
        j -= k;
        k ~/= 2;
      }
      j += k;
    }

    for (int len = 2; len <= n; len <<= 1) {
      final halfLen = len ~/ 2;
      final angle = -2.0 * math.pi / len;
      final wstepR = math.cos(angle);
      final wstepI = math.sin(angle);

      for (int i = 0; i < n; i += len) {
        double wR = 1.0;
        double wI = 0.0;
        for (int k = 0; k < halfLen; k++) {
          final uR = real[i + k];
          final uI = imag[i + k];
          final vR = real[i + k + halfLen] * wR - imag[i + k + halfLen] * wI;
          final vI = real[i + k + halfLen] * wI + imag[i + k + halfLen] * wR;

          real[i + k] = uR + vR;
          imag[i + k] = uI + vI;
          real[i + k + halfLen] = uR - vR;
          imag[i + k + halfLen] = uI - vI;

          final nextWR = wR * wstepR - wI * wstepI;
          wI = wR * wstepI + wI * wstepR;
          wR = nextWR;
        }
      }
    }
  }

  static Float64List _calcRmsEnvelope(Float32List audio, int length, int sampleRate) {
    final windowSize = (sampleRate * 0.010).toInt().clamp(32, 512); // 10ms window
    final numWindows = length ~/ windowSize;
    final env = Float64List(numWindows);

    for (int w = 0; w < numWindows; w++) {
      double sum = 0.0;
      final start = w * windowSize;
      for (int i = 0; i < windowSize; i++) {
        final s = audio[start + i];
        sum += s * s;
      }
      env[w] = math.sqrt(sum / windowSize);
    }
    return env;
  }

  static double _calcCorrelation(Float64List a, Float64List b) {
    final n = math.min(a.length, b.length);
    if (n < 2) return 0.0;

    double meanA = 0.0, meanB = 0.0;
    for (int i = 0; i < n; i++) {
      meanA += a[i];
      meanB += b[i];
    }
    meanA /= n;
    meanB /= n;

    double num = 0.0, denA = 0.0, denB = 0.0;
    for (int i = 0; i < n; i++) {
      final da = a[i] - meanA;
      final db = b[i] - meanB;
      num += da * db;
      denA += da * da;
      denB += db * db;
    }

    final den = math.sqrt(denA * denB);
    return den > 1e-9 ? (num / den).clamp(-1.0, 1.0) : 0.0;
  }

  static double _calcSpectralCentroid(Float32List audio, int sampleRate) {
    const size = 1024;
    if (audio.length < size) return 1000.0;

    final real = Float64List(size);
    final imag = Float64List(size);
    final window = _hannWindow(size);

    for (int i = 0; i < size; i++) {
      real[i] = audio[i] * window[i];
      imag[i] = 0.0;
    }
    _fft(real, imag);

    double num = 0.0, den = 0.0;
    final half = size ~/ 2;
    final freqBinHz = sampleRate / size;

    for (int k = 0; k < half; k++) {
      final mag = math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
      final freq = k * freqBinHz;
      num += freq * mag;
      den += mag;
    }

    return den > 1e-9 ? num / den : 1000.0;
  }

  static double _calcHighFreqRatio(Float32List audio, int sampleRate, double cutoffHz) {
    const size = 1024;
    if (audio.length < size) return 0.0;

    final real = Float64List(size);
    final imag = Float64List(size);
    final window = _hannWindow(size);

    for (int i = 0; i < size; i++) {
      real[i] = audio[i] * window[i];
      imag[i] = 0.0;
    }
    _fft(real, imag);

    final half = size ~/ 2;
    final freqBinHz = sampleRate / size;
    double highEnergy = 0.0;
    double totalEnergy = 0.0;

    for (int k = 0; k < half; k++) {
      final mag = math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
      final energy = mag * mag;
      totalEnergy += energy;
      if (k * freqBinHz >= cutoffHz) {
        highEnergy += energy;
      }
    }

    return totalEnergy > 1e-9 ? highEnergy / totalEnergy : 0.0;
  }

  static double _calcRms(Float32List audio, int start, int count) {
    if (count <= 0) return 0.0;
    double sum = 0.0;
    final end = math.min(start + count, audio.length);
    for (int i = start; i < end; i++) {
      final s = audio[i];
      sum += s * s;
    }
    return math.sqrt(sum / count);
  }
}
