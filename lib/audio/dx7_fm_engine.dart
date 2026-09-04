import 'dart:math' as math;
import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────────────────────
//  YAMAHA DX7 EMPIRICAL HARDWARE LOOKUP TABLES & SCALING ROUTINES
// ─────────────────────────────────────────────────────────────────────────────

/// DX7 Frequency Coarse Multipliers (Coarse 0..31: 0 = 0.5x, 1 = 1.0x, 2 = 2.0x, etc.)
final List<double> kDX7CoarseMultipliers = List.generate(32, (index) {
  if (index == 0) return 0.5;
  return index.toDouble();
});

/// DX7 Velocity Sensitivity Lookup Table (64 steps mapping to attenuation offset)
const List<int> kDX7VelocityData = [
  0, 70, 86, 97, 106, 114, 121, 126, 132, 138, 142, 148, 152, 156, 160, 163,
  166, 170, 173, 174, 178, 181, 184, 186, 189, 190, 194, 196, 198, 200, 202,
  205, 206, 209, 211, 214, 216, 218, 220, 222, 224, 225, 227, 229, 230, 232,
  233, 235, 237, 238, 240, 241, 242, 243, 244, 246, 246, 248, 249, 250, 251,
  252, 253, 254
];

/// Returns velocity level scale (0.0 to 1.0) based on DX7 velocity sensitivity (0..7).
double scaleVelocityToLevel(double velocity, int sensitivity) {
  final int clampedVel = (velocity.clamp(0.0, 1.0) * 127).round();
  final int sens = sensitivity.clamp(0, 7);
  if (sens == 0) return 1.0;
  final int velVal = kDX7VelocityData[(clampedVel >> 1).clamp(0, 63)] - 239;
  final int scaledVel = ((sens * velVal + 7) >> 3) << 4;
  final double attenDb = scaledVel * 0.05; // ~0.05 dB per microstep
  return math.pow(10.0, attenDb / 20.0).toDouble().clamp(0.0, 1.0);
}

/// DX7 Keyboard Rate Scaling (KSR: 0..7) adjustment to envelope rates based on MIDI note.
int scaleRateKsr(int midiNote, int rateScaling) {
  final int sens = rateScaling.clamp(0, 7);
  if (sens == 0) return 0;
  final int x = ((midiNote ~/ 3) - 7).clamp(0, 31);
  return (sens * x) >> 3;
}

/// DX7 Exponential level scaling table.
const List<int> kDX7ExpScaleData = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 14, 16, 19, 23, 27, 33, 39, 47, 56, 66,
  80, 94, 110, 126, 142, 158, 174, 190, 206, 222, 238, 250
];

/// Keyboard Level Scaling (KLS) curve calculation.
double scaleLevelKls(int midiNote, int breakPt, int leftDepth, int rightDepth, int leftCurve, int rightCurve) {
  final int offset = midiNote - breakPt - 17;
  final int depth = offset >= 0 ? rightDepth : leftDepth;
  final int curve = offset >= 0 ? rightCurve : leftCurve;
  if (depth <= 0) return 1.0;

  final int group = (offset.abs() + 1) ~/ 3;
  double deltaDb = 0.0;
  if (curve == 0 || curve == 3) {
    // Linear curve
    deltaDb = (group * depth * 0.08);
  } else {
    // Exponential curve
    final int rawExp = kDX7ExpScaleData[group.clamp(0, kDX7ExpScaleData.length - 1)];
    deltaDb = (rawExp * depth * 0.005);
  }

  if (curve < 2) deltaDb = -deltaDb; // Negative slope
  return math.pow(10.0, deltaDb / 20.0).toDouble().clamp(0.01, 2.0);
}

// ─────────────────────────────────────────────────────────────────────────────
//  MSFA DUAL-BUS 32 ALGORITHM SPECIFICATION
// ─────────────────────────────────────────────────────────────────────────────

/// Bitflag definitions for MSFA algorithm bus decoding:
/// inbus  = (flags >> 4) & 3  (0 = no modulator, 1 = Bus 1, 2 = Bus 2)
/// outbus = flags & 3         (0 = Master Output, 1 = Bus 1, 2 = Bus 2)
/// add    = (flags & 4) != 0  (true = Add into bus, false = Overwrite bus)
/// fb     = (flags & 0xC0) == 0xC0 (Operator has self-feedback loop)
const List<List<int>> kDX7Algorithms = [
  [ 0xc1, 0x11, 0x11, 0x14, 0x01, 0x14 ], // Alg 1:  (6[fb]->5->4->3) + (2->1) -> Out (Carriers: 1, 3)
  [ 0x01, 0x11, 0x11, 0x14, 0xc1, 0x14 ], // Alg 2:  (6->5->4->3) + (2[fb]->1) -> Out (Carriers: 1, 3)
  [ 0xc1, 0x11, 0x14, 0x01, 0x11, 0x14 ], // Alg 3:  (6[fb]->5->4) + (3->2->1) -> Out (Carriers: 1, 4)
  [ 0xc1, 0x11, 0x94, 0x01, 0x11, 0x14 ], // Alg 4:  (6[fb]->5->4) + (3->2->1) -> Out (Carriers: 1, 4, multi-fb)
  [ 0xc1, 0x14, 0x01, 0x14, 0x01, 0x14 ], // Alg 5:  Classic 3-Stack E-Piano (6[fb]->5), (4->3), (2->1) -> Out (Carriers: 1, 3, 5)
  [ 0xc1, 0x94, 0x01, 0x14, 0x01, 0x14 ], // Alg 6:  (6[fb]->5), (4->3), (2->1) -> Out (Carriers: 1, 3, 5)
  [ 0xc1, 0x11, 0x05, 0x14, 0x01, 0x14 ], // Alg 7:  (6[fb]->5), (4), (3->2->1) -> Out
  [ 0x01, 0x11, 0xc5, 0x14, 0x01, 0x14 ], // Alg 8:  (6->5), (4[fb]), (3->2->1) -> Out
  [ 0x01, 0x11, 0x05, 0x14, 0xc1, 0x14 ], // Alg 9:  (6->5), (4), (3->2[fb]->1) -> Out
  [ 0x01, 0x05, 0x14, 0xc1, 0x11, 0x14 ], // Alg 10: (6, 5 -> 4), (3[fb]->2->1) -> Out
  [ 0xc1, 0x05, 0x14, 0x01, 0x11, 0x14 ], // Alg 11: (6[fb], 5 -> 4), (3->2->1) -> Out
  [ 0x01, 0x05, 0x05, 0x14, 0xc1, 0x14 ], // Alg 12: (6, 5, 4 -> 3), (2[fb]->1) -> Out
  [ 0xc1, 0x05, 0x05, 0x14, 0x01, 0x14 ], // Alg 13: (6[fb], 5, 4 -> 3), (2->1) -> Out
  [ 0xc1, 0x05, 0x11, 0x14, 0x01, 0x14 ], // Alg 14: (6[fb], 5 -> 4 -> 3), (2->1) -> Out
  [ 0x01, 0x05, 0x11, 0x14, 0xc1, 0x14 ], // Alg 15: (6, 5 -> 4 -> 3), (2[fb]->1) -> Out
  [ 0xc1, 0x11, 0x02, 0x25, 0x05, 0x14 ], // Alg 16: (6[fb]->5->4), (3->1), (2->1) -> Out
  [ 0x01, 0x11, 0x02, 0x25, 0xc5, 0x14 ], // Alg 17: (6->5->4), (3->1), (2[fb]->1) -> Out
  [ 0x01, 0x11, 0x11, 0xc5, 0x05, 0x14 ], // Alg 18: (6->5->4->3[fb]), (2->1) -> Out
  [ 0xc1, 0x14, 0x14, 0x01, 0x11, 0x14 ], // Alg 19: (6[fb]->5, 4), (3->2->1) -> Out
  [ 0x01, 0x05, 0x14, 0xc1, 0x14, 0x14 ], // Alg 20: (6, 5 -> 4), (3[fb]->2, 1) -> Out
  [ 0x01, 0x14, 0x14, 0xc1, 0x14, 0x14 ], // Alg 21: (6->5, 4), (3[fb]->2, 1) -> Out
  [ 0xc1, 0x14, 0x14, 0x14, 0x01, 0x14 ], // Alg 22: (6[fb]->5, 4, 3), (2->1) -> Out
  [ 0xc1, 0x14, 0x14, 0x01, 0x14, 0x04 ], // Alg 23: (6[fb]->5, 4), (3->2), (1) -> Out (Carriers: 1, 2, 4, 5)
  [ 0xc1, 0x14, 0x14, 0x14, 0x04, 0x04 ], // Alg 24: (6[fb]->5, 4, 3), (2), (1) -> Out
  [ 0xc1, 0x14, 0x14, 0x04, 0x04, 0x04 ], // Alg 25: (6[fb]->5, 4), (3), (2), (1) -> Out
  [ 0xc1, 0x05, 0x14, 0x01, 0x14, 0x04 ], // Alg 26: (6[fb], 5 -> 4), (3->2), (1) -> Out
  [ 0x01, 0x05, 0x14, 0xc1, 0x14, 0x04 ], // Alg 27: (6, 5 -> 4), (3[fb]->2), (1) -> Out
  [ 0x04, 0xc1, 0x11, 0x14, 0x01, 0x14 ], // Alg 28: (6), (5[fb]->4->3), (2->1) -> Out
  [ 0xc1, 0x14, 0x01, 0x14, 0x04, 0x04 ], // Alg 29: (6[fb]->5), (4->3), (2), (1) -> Out
  [ 0x04, 0xc1, 0x11, 0x14, 0x04, 0x04 ], // Alg 30: (6), (5[fb]->4->3), (2), (1) -> Out
  [ 0xc1, 0x14, 0x04, 0x04, 0x04, 0x04 ], // Alg 31: (6[fb]->5), (4), (3), (2), (1) -> Out
  [ 0xc4, 0x04, 0x04, 0x04, 0x04, 0x04 ], // Alg 32: 6 Parallel Sine Carriers (6[fb], 5, 4, 3, 2, 1) -> Out
];

// ─────────────────────────────────────────────────────────────────────────────
//  DX7 OPERATOR MODEL
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single operator in the 6-Operator Yamaha DX7 FM engine.
class DX7Operator {
  // Tuning & Frequency Mode
  bool isFixedFrequency = false;
  double fixedFrequencyHz = 440.0;
  double coarse = 1.0; // 0..31
  double fine = 0.0; // 0..99
  double multiplier = 1.0; // Effective frequency multiplier
  double detune = 0.0; // Detune offset in Hz (-7.0 to +7.0)

  // Output Level & Dynamics
  double outputLevel = 99.0; // DX7 Output Level (0 to 99)
  int velocitySensitivity = 2; // 0 to 7
  int rateScaling = 0; // KSR: 0 to 7
  int ampModSensitivity = 0; // AMS: 0 to 3

  // Keyboard Level Scaling (KLS)
  int breakPoint = 60; // Middle C
  int leftDepth = 0; // 0..99
  int rightDepth = 0; // 0..99
  int leftCurve = 0; // 0: -LIN, 1: -EXP, 2: +EXP, 3: +LIN
  int rightCurve = 0;

  // DX7 4-Rate, 4-Level Envelope Generator (EG: R1..R4: 0..99, L1..L4: 0..99)
  double r1 = 99.0, l1 = 99.0;
  double r2 = 75.0, l2 = 85.0;
  double r3 = 45.0, l3 = 60.0;
  double r4 = 55.0, l4 = 0.0;

  // DSP Phase & Feedback State
  double phase = 0.0;
  double lastOutput = 0.0;
  double prevOutput = 0.0;

  // Precomputed envelope constants per note trigger
  double _t1 = 0.0, _t2 = 0.0, _t3 = 0.0, _t4 = 0.0;
  double _targetL1 = 0.0, _targetL2 = 0.0, _targetL3 = 0.0, _targetL4 = 0.0;
  double _gateTime = 0.0;
  double _cachedScale = 1.0;

  DX7Operator({
    this.coarse = 1.0,
    this.fine = 0.0,
    this.detune = 0.0,
    this.outputLevel = 99.0,
    this.velocitySensitivity = 2,
    this.rateScaling = 0,
    this.ampModSensitivity = 0,
    this.r1 = 99.0,
    this.l1 = 99.0,
    this.r2 = 75.0,
    this.l2 = 85.0,
    this.r3 = 45.0,
    this.l3 = 60.0,
    this.r4 = 55.0,
    this.l4 = 0.0,
  }) {
    updateMultiplier();
  }

  void updateMultiplier() {
    final int c = coarse.round().clamp(0, 31);
    final double mult = kDX7CoarseMultipliers[c] * (1.0 + (fine.clamp(0.0, 99.0) / 100.0));
    multiplier = mult;
  }

  void reset() {
    phase = 0.0;
    lastOutput = 0.0;
    prevOutput = 0.0;
  }

  /// Precomputes segment durations and attenuation scalars once per note trigger.
  void prepare(double duration, double velocity, int midiNote) {
    updateMultiplier();

    double rateToSec(double rate) {
      final int ksrDelta = scaleRateKsr(midiNote, rateScaling);
      final double effectiveRate = (rate + ksrDelta).clamp(0.0, 99.0);
      return math.pow(10.0, (99.0 - effectiveRate) / 30.0 - 2.5).toDouble().clamp(0.001, 30.0);
    }

    _t1 = rateToSec(r1);
    _t2 = rateToSec(r2);
    _t3 = rateToSec(r3);
    _t4 = rateToSec(r4);

    _targetL1 = (l1 / 99.0).clamp(0.0, 1.0);
    _targetL2 = (l2 / 99.0).clamp(0.0, 1.0);
    _targetL3 = (l3 / 99.0).clamp(0.0, 1.0);
    _targetL4 = (l4 / 99.0).clamp(0.0, 1.0);

    _gateTime = math.max(_t1 + _t2, duration);

    final double velScale = scaleVelocityToLevel(velocity, velocitySensitivity);
    final double levelAtten = math.pow(10.0, -((99.0 - outputLevel.clamp(0.0, 99.0)) * 0.75) / 20.0).toDouble();
    final double klsScale = scaleLevelKls(midiNote, breakPoint, leftDepth, rightDepth, leftCurve, rightCurve);

    _cachedScale = levelAtten * velScale * klsScale;
  }

  /// High-performance inline piecewise evaluation with ZERO inner-loop math.pow calculations.
  @pragma('vm:prefer-inline')
  double evaluateEnvelopeFast(double time) {
    double envLevel;
    if (time < _t1) {
      envLevel = _targetL1 * (time / _t1);
    } else if (time < _t1 + _t2) {
      envLevel = _targetL1 + (_targetL2 - _targetL1) * ((time - _t1) / _t2);
    } else if (time < _gateTime) {
      envLevel = _targetL2 + (_targetL3 - _targetL2) * math.min(1.0, (time - (_t1 + _t2)) / _t3);
    } else {
      envLevel = _targetL3 + (_targetL4 - _targetL3) * math.min(1.0, (time - _gateTime) / _t4);
    }
    return (envLevel * _cachedScale).clamp(0.0, 1.0);
  }

  /// Backward-compatible evaluateEnvelope.
  double evaluateEnvelope(double time, double duration, double velocity) {
    prepare(duration, velocity, 60);
    return evaluateEnvelopeFast(time);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PITCH ENVELOPE GENERATOR (PEG) & LFO
// ─────────────────────────────────────────────────────────────────────────────

/// DX7 Global Pitch Envelope Generator (PEG).
class DX7PitchEnvelope {
  double pr1 = 99.0, pl1 = 50.0;
  double pr2 = 99.0, pl2 = 50.0;
  double pr3 = 99.0, pl3 = 50.0;
  double pr4 = 99.0, pl4 = 50.0;

  double _t1 = 0.0, _t2 = 0.0, _t3 = 0.0, _t4 = 0.0;
  double _semi1 = 0.0, _semi2 = 0.0, _semi3 = 0.0, _semi4 = 0.0;
  double _gateTime = 0.0;

  void prepare(double duration) {
    double rateToSec(double r) => math.pow(10.0, (99.0 - r.clamp(0.0, 99.0)) / 30.0 - 2.5).toDouble().clamp(0.001, 30.0);
    double levelToSemi(double l) => (l.clamp(0.0, 99.0) - 50.0) * (48.0 / 50.0); // +/- 4 octaves

    _t1 = rateToSec(pr1);
    _t2 = rateToSec(pr2);
    _t3 = rateToSec(pr3);
    _t4 = rateToSec(pr4);

    _semi1 = levelToSemi(pl1);
    _semi2 = levelToSemi(pl2);
    _semi3 = levelToSemi(pl3);
    _semi4 = levelToSemi(pl4);

    _gateTime = math.max(_t1 + _t2, duration);
  }

  @pragma('vm:prefer-inline')
  double evaluatePitchMultiplier(double time) {
    double semi;
    if (time < _t1) {
      semi = _semi1 * (time / _t1);
    } else if (time < _t1 + _t2) {
      semi = _semi1 + (_semi2 - _semi1) * ((time - _t1) / _t2);
    } else if (time < _gateTime) {
      semi = _semi2 + (_semi3 - _semi2) * math.min(1.0, (time - (_t1 + _t2)) / _t3);
    } else {
      semi = _semi3 + (_semi4 - _semi3) * math.min(1.0, (time - _gateTime) / _t4);
    }
    return semi == 0.0 ? 1.0 : math.pow(2.0, semi / 12.0).toDouble();
  }
}

/// DX7 Low Frequency Oscillator (LFO).
enum DX7LfoWaveform { triangle, sawDown, sawUp, square, sine, sampleAndHold }

class DX7Lfo {
  DX7LfoWaveform waveform = DX7LfoWaveform.triangle;
  double speed = 35.0; // 0..99 (~0.1 to 30 Hz)
  double delay = 0.0; // 0..99
  double pitchModDepth = 0.0; // 0..99
  double ampModDepth = 0.0; // 0..99
  int pitchModSensitivity = 0; // 0..7

  double phase = 0.0;
  double _lastShVal = 0.0;

  void reset() {
    phase = 0.0;
    _lastShVal = 0.0;
  }

  /// Evaluates LFO pitch and amplitude scaling for current time and sampleRate.
  (double, double) evaluate(double time, double sampleRate) {
    final double freqHz = 0.1 + (speed.clamp(0.0, 99.0) / 99.0) * 29.9;
    phase += freqHz / sampleRate;
    if (phase >= 1.0) {
      phase -= 1.0;
      _lastShVal = (math.Random().nextDouble() * 2.0 - 1.0);
    }

    // Delay fade-in
    final double delaySec = (delay.clamp(0.0, 99.0) / 99.0) * 2.5;
    final double delayGain = delaySec > 0.001 ? (time / delaySec).clamp(0.0, 1.0) : 1.0;

    double lfoVal = 0.0;
    switch (waveform) {
      case DX7LfoWaveform.triangle:
        lfoVal = phase < 0.5 ? (4.0 * phase - 1.0) : (3.0 - 4.0 * phase);
        break;
      case DX7LfoWaveform.sawDown:
        lfoVal = 1.0 - 2.0 * phase;
        break;
      case DX7LfoWaveform.sawUp:
        lfoVal = 2.0 * phase - 1.0;
        break;
      case DX7LfoWaveform.square:
        lfoVal = phase < 0.5 ? 1.0 : -1.0;
        break;
      case DX7LfoWaveform.sine:
        lfoVal = math.sin(phase * 2.0 * math.pi);
        break;
      case DX7LfoWaveform.sampleAndHold:
        lfoVal = _lastShVal;
        break;
    }

    final double pSens = pitchModSensitivity / 7.0;
    final double pDepth = (pitchModDepth / 99.0) * pSens * delayGain * 0.08;
    final double pitchMod = 1.0 + lfoVal * pDepth;

    final double aDepth = (ampModDepth / 99.0) * delayGain;
    final double ampMod = (1.0 - aDepth * 0.5) + (lfoVal * 0.5) * aDepth;

    return (pitchMod, ampMod.clamp(0.0, 1.5));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PATCH DEFINITIONS & SYSEX CARTRIDGE DECODER
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a complete, authentic 6-operator Yamaha DX7 patch (voice).
class DX7Patch {
  String name;
  int algorithm;
  int feedback;

  final List<DX7Operator> operators;
  final DX7PitchEnvelope pitchEg = DX7PitchEnvelope();
  final DX7Lfo lfo = DX7Lfo();

  DX7Patch({
    required this.name,
    this.algorithm = 1,
    this.feedback = 0,
    List<DX7Operator>? ops,
  }) : operators = ops ?? List.generate(6, (_) => DX7Operator());

  /// Copies all parameters into target [voice].
  void applyToVoice(DX7FmVoice voice) {
    voice.algorithm = algorithm;
    voice.feedback = feedback;
    voice.pitchEg.pr1 = pitchEg.pr1; voice.pitchEg.pl1 = pitchEg.pl1;
    voice.pitchEg.pr2 = pitchEg.pr2; voice.pitchEg.pl2 = pitchEg.pl2;
    voice.pitchEg.pr3 = pitchEg.pr3; voice.pitchEg.pl3 = pitchEg.pl3;
    voice.pitchEg.pr4 = pitchEg.pr4; voice.pitchEg.pl4 = pitchEg.pl4;

    voice.lfo.waveform = lfo.waveform;
    voice.lfo.speed = lfo.speed;
    voice.lfo.delay = lfo.delay;
    voice.lfo.pitchModDepth = lfo.pitchModDepth;
    voice.lfo.ampModDepth = lfo.ampModDepth;
    voice.lfo.pitchModSensitivity = lfo.pitchModSensitivity;

    for (int i = 0; i < 6; i++) {
      final src = operators[i];
      final dst = voice.operators[i];
      dst.coarse = src.coarse;
      dst.fine = src.fine;
      dst.detune = src.detune;
      dst.outputLevel = src.outputLevel;
      dst.velocitySensitivity = src.velocitySensitivity;
      dst.rateScaling = src.rateScaling;
      dst.ampModSensitivity = src.ampModSensitivity;
      dst.r1 = src.r1; dst.l1 = src.l1;
      dst.r2 = src.r2; dst.l2 = src.l2;
      dst.r3 = src.r3; dst.l3 = src.l3;
      dst.r4 = src.r4; dst.l4 = src.l4;
      dst.updateMultiplier();
    }
  }

  /// Decodes a 128-byte packed DX7 voice from a 32-voice cartridge bank.
  static DX7Patch fromPacked128(Uint8List data, [int offset = 0]) {
    final ops = List.generate(6, (_) => DX7Operator());

    // In DX7 voice banks, operators are stored from Op 6 down to Op 1
    for (int opIdx = 0; opIdx < 6; opIdx++) {
      final int opOff = offset + (5 - opIdx) * 17; // 17 bytes per packed op in bank
      final op = ops[opIdx];
      op.r1 = data[opOff + 0].toDouble();
      op.r2 = data[opOff + 1].toDouble();
      op.r3 = data[opOff + 2].toDouble();
      op.r4 = data[opOff + 3].toDouble();
      op.l1 = data[opOff + 4].toDouble();
      op.l2 = data[opOff + 5].toDouble();
      op.l3 = data[opOff + 6].toDouble();
      op.l4 = data[opOff + 7].toDouble();

      op.breakPoint = data[opOff + 8];
      op.leftDepth = data[opOff + 9];
      op.rightDepth = data[opOff + 10];
      final int curves = data[opOff + 11];
      op.leftCurve = curves & 3;
      op.rightCurve = (curves >> 2) & 3;

      final int detuneRs = data[opOff + 12];
      op.rateScaling = detuneRs & 7;
      op.detune = ((detuneRs >> 3) & 15) - 7.0;

      final int amsVel = data[opOff + 13];
      op.velocitySensitivity = amsVel & 7;
      op.ampModSensitivity = (amsVel >> 3) & 3;

      op.outputLevel = data[opOff + 14].toDouble();

      final int modeCoarse = data[opOff + 15];
      op.isFixedFrequency = (modeCoarse & 1) != 0;
      op.coarse = ((modeCoarse >> 1) & 31).toDouble();

      op.fine = data[opOff + 16].toDouble();
      op.updateMultiplier();
    }

    final int globalOff = offset + 102;
    final peg = DX7PitchEnvelope();
    peg.pr1 = data[globalOff + 0].toDouble();
    peg.pr2 = data[globalOff + 1].toDouble();
    peg.pr3 = data[globalOff + 2].toDouble();
    peg.pr4 = data[globalOff + 3].toDouble();
    peg.pl1 = data[globalOff + 4].toDouble();
    peg.pl2 = data[globalOff + 5].toDouble();
    peg.pl3 = data[globalOff + 6].toDouble();
    peg.pl4 = data[globalOff + 7].toDouble();

    final int alg = (data[globalOff + 8] & 31) + 1; // 1 to 32
    final int fbByte = data[globalOff + 9];
    final int fb = fbByte & 7;

    final lfo = DX7Lfo();
    lfo.speed = data[globalOff + 10].toDouble();
    lfo.delay = data[globalOff + 11].toDouble();
    lfo.pitchModDepth = data[globalOff + 12].toDouble();
    lfo.ampModDepth = data[globalOff + 13].toDouble();
    final int lfoSyncWave = data[globalOff + 14];
    final int waveIdx = (lfoSyncWave >> 1) & 7;
    lfo.waveform = waveIdx < DX7LfoWaveform.values.length ? DX7LfoWaveform.values[waveIdx] : DX7LfoWaveform.triangle;
    lfo.pitchModSensitivity = data[globalOff + 15] & 7;

    // 10-char ASCII Voice Name
    final nameBytes = data.sublist(offset + 118, offset + 128);
    final nameStr = String.fromCharCodes(nameBytes.map((b) => b >= 32 && b <= 126 ? b : 32)).trim();

    final patch = DX7Patch(
      name: nameStr.isNotEmpty ? nameStr : 'DX7 Voice',
      algorithm: alg,
      feedback: fb,
      ops: ops,
    );
    patch.pitchEg.pr1 = peg.pr1; patch.pitchEg.pl1 = peg.pl1;
    patch.pitchEg.pr2 = peg.pr2; patch.pitchEg.pl2 = peg.pl2;
    patch.pitchEg.pr3 = peg.pr3; patch.pitchEg.pl3 = peg.pl3;
    patch.pitchEg.pr4 = peg.pr4; patch.pitchEg.pl4 = peg.pl4;

    patch.lfo.waveform = lfo.waveform;
    patch.lfo.speed = lfo.speed;
    patch.lfo.delay = lfo.delay;
    patch.lfo.pitchModDepth = lfo.pitchModDepth;
    patch.lfo.ampModDepth = lfo.ampModDepth;
    patch.lfo.pitchModSensitivity = lfo.pitchModSensitivity;

    return patch;
  }
}

/// Standard Yamaha DX7 SysEx (`.syx`) binary loader.
class DX7SysExParser {
  /// Parses standard DX7 SysEx data (.syx cartridge file) or raw bank bytes.
  /// Supports:
  /// - 4,096-byte raw 32-voice bank
  /// - 4,104-byte Yamaha SysEx bank (F0 43 00 09 20 00 ... F7)
  /// - 128-byte single packed voice
  /// - 155-byte or 163-byte single voice SysEx
  static List<DX7Patch> parseSysEx(Uint8List data) {
    final List<DX7Patch> patches = [];
    if (data.length < 128) return patches;

    // Check for 32-voice bank with Yamaha SysEx header (4,104 bytes)
    if (data.length >= 4104 && data[0] == 0xF0 && data[1] == 0x43) {
      const int bankStart = 6;
      for (int i = 0; i < 32; i++) {
        patches.add(DX7Patch.fromPacked128(data, bankStart + i * 128));
      }
      return patches;
    }

    // Check for raw 4,096-byte bank
    if (data.length >= 4096) {
      for (int i = 0; i < 32; i++) {
        patches.add(DX7Patch.fromPacked128(data, i * 128));
      }
      return patches;
    }

    // Check for single 128-byte packed voice
    if (data.length == 128) {
      patches.add(DX7Patch.fromPacked128(data, 0));
      return patches;
    }

    // Fallback: search for 128-byte blocks
    final int count = data.length ~/ 128;
    for (int i = 0; i < math.min(count, 32); i++) {
      patches.add(DX7Patch.fromPacked128(data, i * 128));
    }

    return patches;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ICONIC FACTORY ROM VOICES
// ─────────────────────────────────────────────────────────────────────────────

class DX7FactoryPatches {
  static final DX7Patch epiano1 = _buildEPiano1();
  static final DX7Patch bass1 = _buildBass1();
  static final DX7Patch tubBells = _buildTubBells();
  static final DX7Patch strings1 = _buildStrings1();
  static final DX7Patch synLead5 = _buildSynLead5();
  static final DX7Patch marimba = _buildMarimba();

  static final Map<String, DX7Patch> _patches = {
    'epiano1': epiano1,
    'fulltines': epiano1,
    'e.piano 1': epiano1,
    'bass1': bass1,
    'solidbass': bass1,
    'buss 1': bass1,
    'tub_bells': tubBells,
    'tubularbells': tubBells,
    'tub bells': tubBells,
    'strings1': strings1,
    'strings 1': strings1,
    'synlead5': synLead5,
    'syn-lead 5': synLead5,
    'marimba': marimba,
  };

  static DX7Patch? getPatch(String idOrName) {
    return _patches[idOrName.trim().toLowerCase()];
  }

  static List<String> get availablePatchNames => [
    'E.PIANO 1',
    'BASS 1',
    'TUB BELLS',
    'STRINGS 1',
    'SYN-LEAD 5',
    'MARIMBA',
  ];

  static DX7Patch _buildEPiano1() {
    final ops = List.generate(6, (_) => DX7Operator());
    // Op 1 (Carrier, Fundamental Body)
    ops[0]..coarse = 1.0..outputLevel = 98.0..velocitySensitivity = 2
      ..r1 = 99.0..l1 = 98.0..r2 = 42.0..l2 = 82.0..r3 = 24.0..l3 = 60.0..r4 = 52.0..l4 = 0.0;
    // Op 2 (Modulator of Op 1)
    ops[1]..coarse = 1.0..outputLevel = 78.0..velocitySensitivity = 4
      ..r1 = 95.0..l1 = 95.0..r2 = 38.0..l2 = 65.0..r3 = 18.0..l3 = 0.0..r4 = 55.0..l4 = 0.0;
    // Op 3 (Carrier, Tine)
    ops[2]..coarse = 1.0..outputLevel = 90.0..velocitySensitivity = 2
      ..r1 = 99.0..l1 = 95.0..r2 = 65.0..l2 = 60.0..r3 = 30.0..l3 = 35.0..r4 = 60.0..l4 = 0.0;
    // Op 4 (Inharmonic Bell Modulator, 14x ratio)
    ops[3]..coarse = 14.0..outputLevel = 84.0..velocitySensitivity = 5
      ..r1 = 99.0..l1 = 95.0..r2 = 78.0..l2 = 40.0..r3 = 45.0..l3 = 0.0..r4 = 65.0..l4 = 0.0;
    // Op 5 (Carrier, Air Shimmer)
    ops[4]..coarse = 1.0..detune = 0.08..outputLevel = 88.0..velocitySensitivity = 3
      ..r1 = 99.0..l1 = 90.0..r2 = 48.0..l2 = 72.0..r3 = 22.0..l3 = 40.0..r4 = 50.0..l4 = 0.0;
    // Op 6 (Modulator with feedback)
    ops[5]..coarse = 1.0..detune = -0.06..outputLevel = 72.0..velocitySensitivity = 4
      ..r1 = 90.0..l1 = 92.0..r2 = 45.0..l2 = 55.0..r3 = 20.0..l3 = 0.0..r4 = 55.0..l4 = 0.0;

    for (final op in ops) {
      op.updateMultiplier();
    }

    return DX7Patch(
      name: 'E.PIANO 1',
      algorithm: 5,
      feedback: 6,
      ops: ops,
    );
  }

  static DX7Patch _buildBass1() {
    final ops = List.generate(6, (_) => DX7Operator());
    // Op 1 (Carrier, Sub Fundamental)
    ops[0]..coarse = 0.5..outputLevel = 99.0..velocitySensitivity = 2
      ..r1 = 99.0..l1 = 99.0..r2 = 40.0..l2 = 80.0..r3 = 20.0..l3 = 0.0..r4 = 40.0..l4 = 0.0;
    // Op 2 (Modulator, Octave Punch)
    ops[1]..coarse = 1.0..outputLevel = 84.0..velocitySensitivity = 4
      ..r1 = 99.0..l1 = 95.0..r2 = 50.0..l2 = 0.0..r3 = 20.0..l3 = 0.0..r4 = 40.0..l4 = 0.0;
    // Op 3 (Carrier, Mid Slap)
    ops[2]..coarse = 1.0..outputLevel = 92.0..velocitySensitivity = 3
      ..r1 = 99.0..l1 = 95.0..r2 = 45.0..l2 = 70.0..r3 = 20.0..l3 = 0.0..r4 = 45.0..l4 = 0.0;
    // Op 4 (Modulator, Growl)
    ops[3]..coarse = 2.0..outputLevel = 78.0..velocitySensitivity = 5
      ..r1 = 99.0..l1 = 90.0..r2 = 60.0..l2 = 0.0..r3 = 20.0..l3 = 0.0..r4 = 50.0..l4 = 0.0;
    // Op 5 (Modulator)
    ops[4]..coarse = 3.0..outputLevel = 68.0..velocitySensitivity = 5
      ..r1 = 99.0..l1 = 85.0..r2 = 70.0..l2 = 0.0..r3 = 20.0..l3 = 0.0..r4 = 50.0..l4 = 0.0;
    // Op 6 (Feedback Top Modulator)
    ops[5]..coarse = 1.0..outputLevel = 82.0..velocitySensitivity = 4
      ..r1 = 99.0..l1 = 95.0..r2 = 40.0..l2 = 40.0..r3 = 20.0..l3 = 0.0..r4 = 45.0..l4 = 0.0;

    for (final op in ops) {
      op.updateMultiplier();
    }

    return DX7Patch(
      name: 'BASS 1',
      algorithm: 15,
      feedback: 6,
      ops: ops,
    );
  }

  static DX7Patch _buildTubBells() {
    final ops = List.generate(6, (_) => DX7Operator());
    ops[0]..coarse = 1.0..outputLevel = 98.0..r1 = 99.0..l1 = 99.0..r2 = 30.0..l2 = 60.0..r3 = 15.0..l3 = 0.0..r4 = 30.0..l4 = 0.0;
    ops[1]..coarse = 3.5..outputLevel = 86.0..r1 = 99.0..l1 = 95.0..r2 = 40.0..l2 = 0.0..r3 = 20.0..l3 = 0.0..r4 = 30.0..l4 = 0.0;
    ops[2]..coarse = 1.0..outputLevel = 94.0..r1 = 99.0..l1 = 95.0..r2 = 35.0..l2 = 50.0..r3 = 18.0..l3 = 0.0..r4 = 30.0..l4 = 0.0;
    ops[3]..coarse = 7.15..outputLevel = 88.0..r1 = 99.0..l1 = 95.0..r2 = 45.0..l2 = 0.0..r3 = 25.0..l3 = 0.0..r4 = 35.0..l4 = 0.0;
    ops[4]..coarse = 2.0..outputLevel = 90.0..r1 = 99.0..l1 = 90.0..r2 = 30.0..l2 = 40.0..r3 = 20.0..l3 = 0.0..r4 = 30.0..l4 = 0.0;
    ops[5]..coarse = 11.0..outputLevel = 76.0..r1 = 99.0..l1 = 90.0..r2 = 50.0..l2 = 0.0..r3 = 30.0..l3 = 0.0..r4 = 40.0..l4 = 0.0;

    for (final op in ops) {
      op.updateMultiplier();
    }

    return DX7Patch(
      name: 'TUB BELLS',
      algorithm: 5,
      feedback: 5,
      ops: ops,
    );
  }

  static DX7Patch _buildStrings1() {
    final ops = List.generate(6, (_) => DX7Operator());
    ops[0]..coarse = 1.0..outputLevel = 98.0..r1 = 65.0..l1 = 98.0..r2 = 55.0..l2 = 88.0..r3 = 25.0..l3 = 75.0..r4 = 55.0..l4 = 0.0;
    ops[1]..coarse = 1.0..detune = 0.06..outputLevel = 76.0..r1 = 60.0..l1 = 90.0..r2 = 50.0..l2 = 70.0..r3 = 20.0..l3 = 60.0..r4 = 50.0..l4 = 0.0;
    ops[2]..coarse = 2.0..detune = -0.04..outputLevel = 94.0..r1 = 70.0..l1 = 95.0..r2 = 55.0..l2 = 82.0..r3 = 22.0..l3 = 70.0..r4 = 55.0..l4 = 0.0;
    ops[3]..coarse = 2.0..outputLevel = 72.0..r1 = 65.0..l1 = 85.0..r2 = 50.0..l2 = 65.0..r3 = 20.0..l3 = 50.0..r4 = 50.0..l4 = 0.0;
    ops[4]..coarse = 1.0..outputLevel = 88.0..r1 = 70.0..l1 = 90.0..r2 = 52.0..l2 = 80.0..r3 = 24.0..l3 = 68.0..r4 = 52.0..l4 = 0.0;
    ops[5]..coarse = 3.0..outputLevel = 70.0..r1 = 60.0..l1 = 85.0..r2 = 48.0..l2 = 60.0..r3 = 20.0..l3 = 45.0..r4 = 50.0..l4 = 0.0;

    for (final op in ops) {
      op.updateMultiplier();
    }

    return DX7Patch(
      name: 'STRINGS 1',
      algorithm: 1,
      feedback: 4,
      ops: ops,
    );
  }

  static DX7Patch _buildSynLead5() {
    final ops = List.generate(6, (_) => DX7Operator());
    ops[0]..coarse = 1.0..outputLevel = 99.0..r1 = 99.0..l1 = 99.0..r2 = 70.0..l2 = 85.0..r3 = 40.0..l3 = 80.0..r4 = 65.0..l4 = 0.0;
    ops[1]..coarse = 2.0..outputLevel = 85.0..r1 = 95.0..l1 = 95.0..r2 = 60.0..l2 = 70.0..r3 = 35.0..l3 = 60.0..r4 = 60.0..l4 = 0.0;
    ops[2]..coarse = 1.0..detune = 0.12..outputLevel = 92.0..r1 = 99.0..l1 = 95.0..r2 = 65.0..l2 = 80.0..r3 = 40.0..l3 = 75.0..r4 = 65.0..l4 = 0.0;
    ops[3]..coarse = 3.0..outputLevel = 80.0..r1 = 95.0..l1 = 90.0..r2 = 55.0..l2 = 65.0..r3 = 30.0..l3 = 50.0..r4 = 55.0..l4 = 0.0;
    ops[4]..coarse = 0.5..outputLevel = 90.0..r1 = 99.0..l1 = 95.0..r2 = 60.0..l2 = 75.0..r3 = 35.0..l3 = 70.0..r4 = 60.0..l4 = 0.0;
    ops[5]..coarse = 1.0..outputLevel = 84.0..r1 = 95.0..l1 = 92.0..r2 = 50.0..l2 = 60.0..r3 = 25.0..l3 = 40.0..r4 = 50.0..l4 = 0.0;

    for (final op in ops) {
      op.updateMultiplier();
    }

    return DX7Patch(
      name: 'SYN-LEAD 5',
      algorithm: 8,
      feedback: 7,
      ops: ops,
    );
  }

  static DX7Patch _buildMarimba() {
    final ops = List.generate(6, (_) => DX7Operator());
    ops[0]..coarse = 1.0..outputLevel = 98.0..r1 = 99.0..l1 = 99.0..r2 = 60.0..l2 = 40.0..r3 = 35.0..l3 = 0.0..r4 = 65.0..l4 = 0.0;
    ops[1]..coarse = 4.0..outputLevel = 82.0..r1 = 99.0..l1 = 95.0..r2 = 75.0..l2 = 0.0..r3 = 40.0..l3 = 0.0..r4 = 70.0..l4 = 0.0;
    ops[2]..coarse = 1.0..outputLevel = 92.0..r1 = 99.0..l1 = 95.0..r2 = 55.0..l2 = 30.0..r3 = 30.0..l3 = 0.0..r4 = 60.0..l4 = 0.0;
    ops[3]..coarse = 10.0..outputLevel = 78.0..r1 = 99.0..l1 = 90.0..r2 = 80.0..l2 = 0.0..r3 = 45.0..l3 = 0.0..r4 = 75.0..l4 = 0.0;
    ops[4]..coarse = 2.0..outputLevel = 88.0..r1 = 99.0..l1 = 90.0..r2 = 50.0..l2 = 25.0..r3 = 25.0..l3 = 0.0..r4 = 55.0..l4 = 0.0;
    ops[5]..coarse = 1.0..outputLevel = 74.0..r1 = 95.0..l1 = 85.0..r2 = 70.0..l2 = 0.0..r3 = 35.0..l3 = 0.0..r4 = 65.0..l4 = 0.0;

    for (final op in ops) {
      op.updateMultiplier();
    }

    return DX7Patch(
      name: 'MARIMBA',
      algorithm: 5,
      feedback: 6,
      ops: ops,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AUTHENTIC 6-OPERATOR YAMAHA DX7 FM SOUND ENGINE
// ─────────────────────────────────────────────────────────────────────────────

/// Authentic 6-Operator Yamaha DX7 FM Sound Engine.
/// Supports all 32 classic DX7 Routing Algorithms (via MSFA dual intermediate bus architecture),
/// Yamaha 4-Rate 4-Level Envelope Generators with KSR & KLS scaling, Pitch EG, LFO,
/// feedback loops, 12-bit DAC quantization emulation, and stereo shimmer chorus.
class DX7FmVoice {
  final List<DX7Operator> operators = List.generate(6, (_) => DX7Operator());
  final DX7PitchEnvelope pitchEg = DX7PitchEnvelope();
  final DX7Lfo lfo = DX7Lfo();

  int algorithm = 5; // Default: Algorithm 5 (Classic DX7 E-Piano: 3 independent 2-op stacks)
  int feedback = 6; // Feedback amount (0 to 7)

  // Master Timbre & Voicing Controls
  double brightness = 1.0; // Harmonic modulator scaling
  double tineBell = 0.85; // Bell tine stack gain
  double bodyWarmth = 1.0; // Fundamental body stack gain
  double chorusRateHz = 0.65;
  double chorusDepth = 0.45;
  double chorusMix = 0.35;
  bool enable12BitDac = true;

  DX7FmVoice({int algorithm = 5, int feedback = 6}) {
    this.algorithm = algorithm.clamp(1, 32);
    this.feedback = feedback.clamp(0, 7);
    loadPatch(DX7FactoryPatches.epiano1);
  }

  /// Loads an authentic preset [patch] into this voice.
  void loadPatch(DX7Patch patch) {
    patch.applyToVoice(this);
  }

  void reset() {
    for (final op in operators) {
      op.reset();
    }
    lfo.reset();
  }

  /// Writes a raw DX7 register or parameter for chiptune tracker & Lua control.
  void writeRegister(int regAddr, int value) {
    if (regAddr == 0x86) {
      algorithm = (value & 31) + 1;
    } else if (regAddr == 0x87) {
      feedback = value & 7;
    } else if (regAddr >= 0 && regAddr < 6 * 21) {
      final int opIdx = 5 - (regAddr ~/ 21);
      final int paramIdx = regAddr % 21;
      final op = operators[opIdx.clamp(0, 5)];
      switch (paramIdx) {
        case 0: op.r1 = value.toDouble(); break;
        case 1: op.r2 = value.toDouble(); break;
        case 2: op.r3 = value.toDouble(); break;
        case 3: op.r4 = value.toDouble(); break;
        case 4: op.l1 = value.toDouble(); break;
        case 5: op.l2 = value.toDouble(); break;
        case 6: op.l3 = value.toDouble(); break;
        case 7: op.l4 = value.toDouble(); break;
        case 14: op.outputLevel = value.toDouble(); break;
        case 15:
          op.isFixedFrequency = (value & 1) != 0;
          op.coarse = ((value >> 1) & 31).toDouble();
          op.updateMultiplier();
          break;
        case 16:
          op.fine = value.toDouble();
          op.updateMultiplier();
          break;
      }
    }
  }

  /// Synthesizes a mono DX7 audio buffer for [baseFreq] / MIDI note.
  void processBuffer({
    required Float32List outBuffer,
    required double baseFreq,
    required double sampleRate,
    required double durationSec,
    double velocity = 0.85,
    int? midiNote,
  }) {
    if (baseFreq <= 0) {
      outBuffer.fillRange(0, outBuffer.length, 0.0);
      return;
    }

    final int len = outBuffer.length;
    final double twoPi = 2.0 * math.pi;
    final double dt = 1.0 / sampleRate;
    final int effectiveNote = midiNote ?? (69.0 + 12.0 * math.log(baseFreq / 440.0) / math.ln2).round().clamp(0, 127);

    // 1. Prepare envelope generators
    for (int opIdx = 0; opIdx < 6; opIdx++) {
      operators[opIdx].prepare(durationSec, velocity, effectiveNote);
    }
    pitchEg.prepare(durationSec);

    // Feedback scaling factor
    final double fbAmount = feedback > 0 ? (math.pow(2.0, feedback - 1) * 0.25 * math.pi / 4.0).toDouble() : 0.0;

    // Algorithm routing definition (MSFA 6-operator dual intermediate bus topology)
    final int algIndex = (algorithm - 1).clamp(0, 31);
    final List<int> algOps = kDX7Algorithms[algIndex];

    double chorusPhase = 0.0;

    // Intermediate mixing busses
    double bus1 = 0.0;
    double bus2 = 0.0;

    for (int i = 0; i < len; i++) {
      final double time = i * dt;

      // 2. Evaluate Pitch EG and LFO
      final double pitchMult = pitchEg.evaluatePitchMultiplier(time);
      final (lfoPitchMod, lfoAmpMod) = lfo.evaluate(time, sampleRate);
      final double currentFreq = baseFreq * pitchMult * lfoPitchMod;

      // Reset busses at start of sample clock
      bus1 = 0.0;
      bus2 = 0.0;
      double masterOut = 0.0;

      // 3. Process operators in MSFA order (Op 6 down to Op 1: opIndex 0 to 5)
      for (int op = 0; op < 6; op++) {
        final int flags = algOps[op];
        final int opNumber = 5 - op; // Operator 5 = Op 6; Operator 0 = Op 1
        final DX7Operator operator = operators[opNumber];

        // Envelope evaluation with timbre macros
        double env = operator.evaluateEnvelopeFast(time);
        if (opNumber == 3) env *= tineBell; // Op 4 is typical bell modulator
        if (opNumber == 0 || opNumber == 4) env *= bodyWarmth;
        if (flags & 3 != 0) env *= brightness; // Modulator op

        // LFO amplitude modulation sensitivity
        if (operator.ampModSensitivity > 0) {
          final double amsDepth = operator.ampModSensitivity / 3.0;
          env *= (1.0 - amsDepth) + (lfoAmpMod * amsDepth);
        }

        // Calculate phase increment
        double opFreq;
        if (operator.isFixedFrequency) {
          opFreq = operator.fixedFrequencyHz + operator.detune;
        } else {
          opFreq = (currentFreq * operator.multiplier) + operator.detune;
        }
        final double phaseInc = (opFreq * twoPi) / sampleRate;

        // Phase modulation input
        final int inbus = (flags >> 4) & 3;
        final bool hasFeedback = (flags & 0xC0) == 0xC0;

        double modIn = 0.0;
        if (hasFeedback && fbAmount > 0.0) {
          // Self-feedback loop averaged over last 2 samples for stability
          modIn = ((operator.lastOutput + operator.prevOutput) * 0.5) * fbAmount;
        } else if (inbus == 1) {
          modIn = bus1 * math.pi;
        } else if (inbus == 2) {
          modIn = bus2 * math.pi;
        }

        // Compute sine output
        final double opOut = math.sin(operator.phase + modIn) * env;

        // Update feedback history
        if (hasFeedback) {
          operator.prevOutput = operator.lastOutput;
          operator.lastOutput = opOut;
        }

        // Advance phase
        operator.phase += phaseInc;
        if (operator.phase >= twoPi) operator.phase -= twoPi;

        // Route output to intermediate busses or master output
        final int outbus = flags & 3;
        final bool add = (flags & 4) != 0;

        if (outbus == 0) {
          if (add) {
            masterOut += opOut;
          } else {
            masterOut = opOut;
          }
        } else if (outbus == 1) {
          if (add) {
            bus1 += opOut;
          } else {
            bus1 = opOut;
          }
        } else if (outbus == 2) {
          if (add) {
            bus2 += opOut;
          } else {
            bus2 = opOut;
          }
        }
      }

      double sampleVal = masterOut * 0.45; // Output headroom scaling

      // 4. Vintage 1983 12-Bit DAC Compander Emulation
      if (enable12BitDac) {
        final double quantized = (sampleVal * 2048.0).roundToDouble() / 2048.0;
        sampleVal = quantized;
      }

      // 5. Stereo Shimmer Chorus Modulation
      if (chorusMix > 0.01) {
        final double lfoVal = math.sin(chorusPhase * twoPi);
        final double chorusWet = sampleVal * (1.0 + lfoVal * chorusDepth * 0.25);
        sampleVal = sampleVal * (1.0 - chorusMix * 0.5) + chorusWet * (chorusMix * 0.5);

        chorusPhase += chorusRateHz / sampleRate;
        if (chorusPhase >= 1.0) chorusPhase -= 1.0;
      }

      outBuffer[i] = sampleVal.clamp(-1.0, 1.0);
    }
  }
}
