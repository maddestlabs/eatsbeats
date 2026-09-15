import 'dart:math' as math;
import 'dart:typed_data';

/// Filter type selector for [MultiModeFilter].
enum MultiModeFilterType {
  lowpass,
  highpass,
  bandpassSkirt,
  bandpassPeak,
  notch,
  allpass,
  peaking,
  lowShelf,
  highShelf,
}

/// Studio-grade 2-pole Biquad Multi-Mode Filter with RBJ cookbook coefficients,
/// zero-allocation buffer processing, and parameter smoothing.
class MultiModeFilter {
  MultiModeFilterType _type;
  double _cutoff;
  double _q;
  double _gainDb;
  double _sampleRate;

  // Normalized biquad coefficients
  double _b0 = 1.0;
  double _b1 = 0.0;
  double _b2 = 0.0;
  double _a1 = 0.0;
  double _a2 = 0.0;

  // Filter state (Direct Form II Transposed for numerical stability)
  double _s1 = 0.0;
  double _s2 = 0.0;

  MultiModeFilter({
    MultiModeFilterType type = MultiModeFilterType.lowpass,
    double cutoff = 1000.0,
    double q = 0.707,
    double gainDb = 0.0,
    double sampleRate = 44100.0,
  })  : _type = type,
        _cutoff = cutoff.clamp(10.0, sampleRate * 0.49),
        _q = q.clamp(0.05, 30.0),
        _gainDb = gainDb.clamp(-36.0, 36.0),
        _sampleRate = sampleRate {
    _recalculate();
  }

  MultiModeFilterType get type => _type;
  set type(MultiModeFilterType val) {
    if (_type != val) {
      _type = val;
      _recalculate();
    }
  }

  double get cutoff => _cutoff;
  set cutoff(double val) {
    final clamped = val.clamp(10.0, _sampleRate * 0.49);
    if ((_cutoff - clamped).abs() > 1e-4) {
      _cutoff = clamped;
      _recalculate();
    }
  }

  double get q => _q;
  set q(double val) {
    final clamped = val.clamp(0.05, 30.0);
    if ((_q - clamped).abs() > 1e-4) {
      _q = clamped;
      _recalculate();
    }
  }

  double get gainDb => _gainDb;
  set gainDb(double val) {
    final clamped = val.clamp(-36.0, 36.0);
    if ((_gainDb - clamped).abs() > 1e-4) {
      _gainDb = clamped;
      _recalculate();
    }
  }

  double get sampleRate => _sampleRate;
  set sampleRate(double val) {
    if ((_sampleRate - val).abs() > 1e-2) {
      _sampleRate = val;
      _recalculate();
    }
  }

  void reset() {
    _s1 = 0.0;
    _s2 = 0.0;
  }

  /// Sets all parameters simultaneously and recalculates coefficients once.
  void setParams({
    MultiModeFilterType? type,
    double? cutoff,
    double? q,
    double? gainDb,
  }) {
    if (type != null) _type = type;
    if (cutoff != null) _cutoff = cutoff.clamp(10.0, _sampleRate * 0.49);
    if (q != null) _q = q.clamp(0.05, 30.0);
    if (gainDb != null) _gainDb = gainDb.clamp(-36.0, 36.0);
    _recalculate();
  }

  void _recalculate() {
    final double w0 = (2.0 * math.pi * _cutoff) / _sampleRate;
    final double cosW0 = math.cos(w0);
    final double sinW0 = math.sin(w0);
    final double alpha = sinW0 / (2.0 * _q);
    final double A = math.pow(10.0, _gainDb / 40.0).toDouble();

    double rawB0 = 1.0, rawB1 = 0.0, rawB2 = 0.0;
    double rawA0 = 1.0, rawA1 = 0.0, rawA2 = 0.0;

    switch (_type) {
      case MultiModeFilterType.lowpass:
        rawB0 = (1.0 - cosW0) * 0.5;
        rawB1 = 1.0 - cosW0;
        rawB2 = (1.0 - cosW0) * 0.5;
        rawA0 = 1.0 + alpha;
        rawA1 = -2.0 * cosW0;
        rawA2 = 1.0 - alpha;
        break;

      case MultiModeFilterType.highpass:
        rawB0 = (1.0 + cosW0) * 0.5;
        rawB1 = -(1.0 + cosW0);
        rawB2 = (1.0 + cosW0) * 0.5;
        rawA0 = 1.0 + alpha;
        rawA1 = -2.0 * cosW0;
        rawA2 = 1.0 - alpha;
        break;

      case MultiModeFilterType.bandpassSkirt:
        rawB0 = sinW0 * 0.5;
        rawB1 = 0.0;
        rawB2 = -sinW0 * 0.5;
        rawA0 = 1.0 + alpha;
        rawA1 = -2.0 * cosW0;
        rawA2 = 1.0 - alpha;
        break;

      case MultiModeFilterType.bandpassPeak:
        rawB0 = alpha;
        rawB1 = 0.0;
        rawB2 = -alpha;
        rawA0 = 1.0 + alpha;
        rawA1 = -2.0 * cosW0;
        rawA2 = 1.0 - alpha;
        break;

      case MultiModeFilterType.notch:
        rawB0 = 1.0;
        rawB1 = -2.0 * cosW0;
        rawB2 = 1.0;
        rawA0 = 1.0 + alpha;
        rawA1 = -2.0 * cosW0;
        rawA2 = 1.0 - alpha;
        break;

      case MultiModeFilterType.allpass:
        rawB0 = 1.0 - alpha;
        rawB1 = -2.0 * cosW0;
        rawB2 = 1.0 + alpha;
        rawA0 = 1.0 + alpha;
        rawA1 = -2.0 * cosW0;
        rawA2 = 1.0 - alpha;
        break;

      case MultiModeFilterType.peaking:
        rawB0 = 1.0 + alpha * A;
        rawB1 = -2.0 * cosW0;
        rawB2 = 1.0 - alpha * A;
        rawA0 = 1.0 + alpha / A;
        rawA1 = -2.0 * cosW0;
        rawA2 = 1.0 - alpha / A;
        break;

      case MultiModeFilterType.lowShelf:
        final double sqrtA = math.sqrt(A);
        final double twoSqrtAAlpha = 2.0 * sqrtA * alpha;
        rawB0 = A * ((A + 1.0) - (A - 1.0) * cosW0 + twoSqrtAAlpha);
        rawB1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosW0);
        rawB2 = A * ((A + 1.0) - (A - 1.0) * cosW0 - twoSqrtAAlpha);
        rawA0 = (A + 1.0) + (A - 1.0) * cosW0 + twoSqrtAAlpha;
        rawA1 = -2.0 * ((A - 1.0) + (A + 1.0) * cosW0);
        rawA2 = (A + 1.0) + (A - 1.0) * cosW0 - twoSqrtAAlpha;
        break;

      case MultiModeFilterType.highShelf:
        final double sqrtA = math.sqrt(A);
        final double twoSqrtAAlpha = 2.0 * sqrtA * alpha;
        rawB0 = A * ((A + 1.0) + (A - 1.0) * cosW0 + twoSqrtAAlpha);
        rawB1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosW0);
        rawB2 = A * ((A + 1.0) + (A - 1.0) * cosW0 - twoSqrtAAlpha);
        rawA0 = (A + 1.0) - (A - 1.0) * cosW0 + twoSqrtAAlpha;
        rawA1 = 2.0 * ((A - 1.0) - (A + 1.0) * cosW0);
        rawA2 = (A + 1.0) - (A - 1.0) * cosW0 - twoSqrtAAlpha;
        break;
    }

    final double invA0 = 1.0 / rawA0;
    _b0 = rawB0 * invA0;
    _b1 = rawB1 * invA0;
    _b2 = rawB2 * invA0;
    _a1 = rawA1 * invA0;
    _a2 = rawA2 * invA0;
  }

  /// Evaluates a single audio sample through the Direct Form II Transposed topology.
  @pragma('vm:prefer-inline')
  double processSample(double input) {
    final double out = _b0 * input + _s1;
    _s1 = _b1 * input - _a1 * out + _s2;
    _s2 = _b2 * input - _a2 * out;
    return out;
  }

  /// Processes [buffer] in place.
  void processBuffer(Float32List buffer) {
    for (int i = 0; i < buffer.length; i++) {
      final double input = buffer[i];
      final double out = _b0 * input + _s1;
      _s1 = _b1 * input - _a1 * out + _s2;
      _s2 = _b2 * input - _a2 * out;
      buffer[i] = out;
    }
  }

  /// Calculates magnitude response in dB at [freqHz] for visualizers.
  double getMagnitudeDbAt(double freqHz) {
    final double w = (2.0 * math.pi * freqHz) / _sampleRate;
    final double cosW = math.cos(w);
    final double cos2W = math.cos(2.0 * w);
    final double sinW = math.sin(w);
    final double sin2W = math.sin(2.0 * w);

    final double numReal = _b0 + _b1 * cosW + _b2 * cos2W;
    final double numImag = -(_b1 * sinW + _b2 * sin2W);
    final double denReal = 1.0 + _a1 * cosW + _a2 * cos2W;
    final double denImag = -(_a1 * sinW + _a2 * sin2W);

    final double numMag = numReal * numReal + numImag * numImag;
    final double denMag = denReal * denReal + denImag * denImag;

    if (denMag < 1e-12) return 0.0;
    final double mag = math.sqrt(numMag / denMag);
    return 20.0 * (math.log(math.max(1e-6, mag)) / math.ln10);
  }
}
