import 'dart:math' as math;
import 'dart:typed_data';

/// Studio Dynamic Range Compressor with logarithmic decibel ballistics,
/// soft-knee smoothing, auto-makeup gain, and external sidechain input.
class EatCompressor {
  final double sampleRate;

  double thresholdDb;
  double ratio;
  double kneeDb;
  double attackMs;
  double releaseMs;
  double makeupGainDb;
  double mix;
  bool isRms;

  // Ballistics state
  double _detectorDb = -96.0;
  double _gainReductionDb = 0.0;
  double _rmsSum = 0.0;
  int _rmsCount = 0;
  final int _rmsWindow;

  EatCompressor({
    this.sampleRate = 44100.0,
    this.thresholdDb = -18.0,
    this.ratio = 4.0,
    this.kneeDb = 6.0,
    this.attackMs = 15.0,
    this.releaseMs = 100.0,
    this.makeupGainDb = 0.0,
    this.mix = 1.0,
    this.isRms = false,
  }) : _rmsWindow = (44100.0 * 0.01).toInt().clamp(16, 1024);

  void reset() {
    _detectorDb = -96.0;
    _gainReductionDb = 0.0;
    _rmsSum = 0.0;
    _rmsCount = 0;
  }

  /// Processes [buffer] in place.
  /// If [sidechainBuffer] is provided, dynamic envelope detection is driven by
  /// the sidechain signal while compression is applied to [buffer].
  void process(Float32List buffer, {Float32List? sidechainBuffer}) {
    if (buffer.isEmpty) return;

    final double attackCoeff = math.exp(-1.0 / (math.max(0.1, attackMs) * sampleRate / 1000.0));
    final double releaseCoeff = math.exp(-1.0 / (math.max(1.0, releaseMs) * sampleRate / 1000.0));
    final double makeupLin = math.pow(10.0, makeupGainDb / 20.0).toDouble();
    final double halfKnee = kneeDb * 0.5;

    final int len = buffer.length;
    final sc = sidechainBuffer ?? buffer;
    final int scLen = sc.length;

    for (int i = 0; i < len; i++) {
      final double dry = buffer[i];
      final double detInput = i < scLen ? sc[i] : dry;

      // 1. Level Detection (Peak or RMS)
      double inputLevelDb;
      if (isRms) {
        _rmsSum += detInput * detInput;
        _rmsCount++;
        if (_rmsCount >= _rmsWindow) {
          final double rms = math.sqrt(_rmsSum / _rmsCount);
          _detectorDb = 20.0 * math.log(math.max(1e-6, rms)) / math.ln10;
          _rmsSum = 0.0;
          _rmsCount = 0;
        }
        inputLevelDb = _detectorDb;
      } else {
        final double peak = detInput.abs();
        final double peakDb = 20.0 * math.log(math.max(1e-6, peak)) / math.ln10;
        inputLevelDb = peakDb;
      }

      // 2. Static Characteristic with Soft Knee
      double targetDb = inputLevelDb;
      final double delta = inputLevelDb - thresholdDb;

      if (kneeDb > 0.1 && delta.abs() <= halfKnee) {
        // Within soft-knee transition
        final double kneeFactor = (delta + halfKnee) / kneeDb;
        final double cDb = thresholdDb + delta / ratio;
        targetDb = inputLevelDb * (1.0 - kneeFactor) + cDb * kneeFactor;
      } else if (delta > 0) {
        // Above knee: full compression ratio
        targetDb = thresholdDb + delta / ratio;
      }

      final double desiredGrDb = targetDb - inputLevelDb; // Always <= 0.0

      // 3. Ballistics (Attack / Release filter on gain reduction in dB)
      if (desiredGrDb < _gainReductionDb) {
        // Signal increasing / compressing: Attack
        _gainReductionDb = attackCoeff * _gainReductionDb + (1.0 - attackCoeff) * desiredGrDb;
      } else {
        // Signal decaying / returning to 0dB: Release
        _gainReductionDb = releaseCoeff * _gainReductionDb + (1.0 - releaseCoeff) * desiredGrDb;
      }

      // 4. Linear Gain Multiplication & Makeup
      final double gainLin = math.pow(10.0, _gainReductionDb / 20.0).toDouble() * makeupLin;
      final double wet = dry * gainLin;

      // 5. Dry / Wet Mix
      buffer[i] = (dry * (1.0 - mix) + wet * mix).clamp(-2.0, 2.0);
    }
  }
}

/// Zero-overshoot Brickwall Peak Limiter with circular lookahead delay buffer.
class EatLimiter {
  final double sampleRate;
  double ceilingDb;
  double thresholdDb;
  double releaseMs;
  double lookaheadMs;

  late Float32List _delayBuffer;
  int _delayWriteIdx = 0;
  int _delayLength = 0;

  double _gainReduction = 1.0;

  EatLimiter({
    this.sampleRate = 44100.0,
    this.ceilingDb = -0.1,
    this.thresholdDb = -1.0,
    this.releaseMs = 50.0,
    this.lookaheadMs = 2.0,
  }) {
    _initBuffer();
  }

  void _initBuffer() {
    _delayLength = (sampleRate * (lookaheadMs / 1000.0)).toInt().clamp(8, 2048);
    _delayBuffer = Float32List(_delayLength);
    _delayWriteIdx = 0;
    _gainReduction = 1.0;
  }

  void reset() {
    _delayBuffer.fillRange(0, _delayBuffer.length, 0.0);
    _delayWriteIdx = 0;
    _gainReduction = 1.0;
  }

  /// Processes [buffer] in place, ensuring no peak exceeds [ceilingDb].
  void process(Float32List buffer) {
    if (buffer.isEmpty) return;

    final double ceilingLin = math.pow(10.0, ceilingDb / 20.0).toDouble().clamp(0.01, 1.0);
    final double releaseCoeff = math.exp(-1.0 / (math.max(1.0, releaseMs) * sampleRate / 1000.0));

    final int len = buffer.length;
    for (int i = 0; i < len; i++) {
      final double input = buffer[i];

      // Read delayed sample
      final int readIdx = (_delayWriteIdx + 1) % _delayLength;
      final double delayedSample = _delayBuffer[readIdx];

      // Store current sample into lookahead ring buffer
      _delayBuffer[_delayWriteIdx] = input;
      _delayWriteIdx = (_delayWriteIdx + 1) % _delayLength;

      // Lookahead peak detection on incoming input
      final double peak = input.abs();
      double targetGain = 1.0;
      if (peak > ceilingLin) {
        targetGain = ceilingLin / peak;
      }

      // Ballistics: Instant attack when targetGain < current, exponential release otherwise
      if (targetGain < _gainReduction) {
        _gainReduction = targetGain;
      } else {
        _gainReduction = releaseCoeff * _gainReduction + (1.0 - releaseCoeff) * targetGain;
      }

      // Apply lookahead gain to delayed sample
      final double limited = delayedSample * _gainReduction;
      buffer[i] = limited.clamp(-ceilingLin, ceilingLin);
    }
  }
}
