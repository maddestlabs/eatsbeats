import 'dart:math' as math;
import 'dart:typed_data';

/// High-performance circular delay line with fractional linear interpolation.
class DelayLine {
  final Float32List _buffer;
  final int _mask;
  int _writeIdx = 0;

  DelayLine(int maxSamples)
      : _mask = (1 << (32 - (maxSamples - 1).bitLength)) - 1,
        _buffer = Float32List(1 << (32 - (maxSamples - 1).bitLength));

  void write(double sample) {
    _buffer[_writeIdx] = sample;
    _writeIdx = (_writeIdx + 1) & _mask;
  }

  double readFractional(double delaySamples) {
    double readPos = _writeIdx - delaySamples;
    while (readPos < 0) {
      readPos += _buffer.length;
    }
    while (readPos >= _buffer.length) {
      readPos -= _buffer.length;
    }
    final int idx0 = readPos.floor() & _mask;
    final int idx1 = (idx0 + 1) & _mask;
    final double frac = readPos - readPos.floor();
    return _buffer[idx0] * (1.0 - frac) + _buffer[idx1] * frac;
  }

  void reset() {
    _buffer.fillRange(0, _buffer.length, 0.0);
    _writeIdx = 0;
  }
}

/// Stereo Multi-Voice Chorus & Flanger.
class EatChorus {
  final double sampleRate;
  final DelayLine _delayL;
  final DelayLine _delayR;

  double rateHz;
  double depthMs;
  double baseDelayMs;
  double feedback;
  double mix;

  double _phase = 0.0;

  EatChorus({
    this.sampleRate = 44100.0,
    this.rateHz = 1.2,
    this.depthMs = 2.5,
    this.baseDelayMs = 12.0,
    this.feedback = 0.2,
    this.mix = 0.5,
  })  : _delayL = DelayLine(4410),
        _delayR = DelayLine(4410);

  void reset() {
    _delayL.reset();
    _delayR.reset();
    _phase = 0.0;
  }

  void processStereo(Float32List left, Float32List right) {
    final double twoPi = 2.0 * math.pi;
    final double phaseInc = (twoPi * rateHz) / sampleRate;

    final int len = left.length;
    for (int i = 0; i < len; i++) {
      final double inL = left[i];
      final double inR = right[i];

      // Quadrature LFOs (Left 0°, Right 90°)
      final double modL = (math.sin(_phase) + 1.0) * 0.5 * depthMs;
      final double modR = (math.cos(_phase) + 1.0) * 0.5 * depthMs;
      _phase += phaseInc;
      if (_phase >= twoPi) _phase -= twoPi;

      final double dSamplesL = (baseDelayMs + modL) * (sampleRate / 1000.0);
      final double dSamplesR = (baseDelayMs + modR) * (sampleRate / 1000.0);

      final double wetL = _delayL.readFractional(dSamplesL);
      final double wetR = _delayR.readFractional(dSamplesR);

      _delayL.write(inL + wetL * feedback);
      _delayR.write(inR + wetR * feedback);

      left[i] = (inL * (1.0 - mix) + wetL * mix).clamp(-1.5, 1.5);
      right[i] = (inR * (1.0 - mix) + wetR * mix).clamp(-1.5, 1.5);
    }
  }
}

/// Stereo Tape / Ping-Pong Delay with analog tape saturation and damping.
class EatTapeDelay {
  final double sampleRate;
  final DelayLine _delayL;
  final DelayLine _delayR;

  double timeMs;
  double feedback;
  double damping;
  double mix;
  bool isPingPong;

  double _filterStateL = 0.0;
  double _filterStateR = 0.0;

  EatTapeDelay({
    this.sampleRate = 44100.0,
    this.timeMs = 350.0,
    this.feedback = 0.45,
    this.damping = 0.3,
    this.mix = 0.4,
    this.isPingPong = true,
  })  : _delayL = DelayLine(88200),
        _delayR = DelayLine(88200);

  void reset() {
    _delayL.reset();
    _delayR.reset();
    _filterStateL = 0.0;
    _filterStateR = 0.0;
  }

  void processStereo(Float32List left, Float32List right) {
    final double delaySamplesL = (timeMs * sampleRate / 1000.0).clamp(1.0, 88000.0);
    final double delaySamplesR = isPingPong
        ? (timeMs * 1.5 * sampleRate / 1000.0).clamp(1.0, 88000.0)
        : delaySamplesL;

    final double dampAlpha = (1.0 - damping).clamp(0.05, 1.0);

    final int len = left.length;
    for (int i = 0; i < len; i++) {
      final double inL = left[i];
      final double inR = right[i];

      final double wetL = _delayL.readFractional(delaySamplesL);
      final double wetR = _delayR.readFractional(delaySamplesR);

      // Lowpass damping filter on feedback loop
      _filterStateL = _filterStateL + dampAlpha * (wetL - _filterStateL);
      _filterStateR = _filterStateR + dampAlpha * (wetR - _filterStateR);

      // Soft tape saturation on feedback
      final double fbL = _fastTanh(_filterStateL * feedback * 1.2);
      final double fbR = _fastTanh(_filterStateR * feedback * 1.2);

      if (isPingPong) {
        _delayL.write(inL + fbR);
        _delayR.write(inR + fbL);
      } else {
        _delayL.write(inL + fbL);
        _delayR.write(inR + fbR);
      }

      left[i] = (inL * (1.0 - mix) + wetL * mix).clamp(-1.5, 1.5);
      right[i] = (inR * (1.0 - mix) + wetR * mix).clamp(-1.5, 1.5);
    }
  }

  static double _fastTanh(double x) {
    if (x.isNaN) return 0.0;
    if (x > 3.0) return 1.0;
    if (x < -3.0) return -1.0;
    final x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);
  }
}
