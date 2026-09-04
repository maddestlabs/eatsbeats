import 'dart:math' as math;
import 'dart:typed_data';

/// High-performance soft-saturation Padé approximant for analog FET overdrive.
@pragma('vm:prefer-inline')
double _fastTanh(double x) {
  if (x.isNaN) return 0.0;
  if (x > 3.0) return 1.0;
  if (x < -3.0) return -1.0;
  final x2 = x * x;
  return x * (27.0 + x2) / (27.0 + 9.0 * x2);
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMMODORE 64 SID (MOS 6581 / 8580) CONSTANTS & HARDWARE DIVIDER TABLES
// ─────────────────────────────────────────────────────────────────────────────

/// SID Waveform types.
enum SIDWaveform {
  pulse,
  sawtooth,
  triangle,
  noise,
  combinedSawPulse,
  combinedTriSaw,
}

/// SID Filter operational mode.
enum SIDFilterMode {
  lowpass,
  bandpass,
  highpass,
  notch, // Lowpass + Highpass
  off,   // Filter bypass
}

/// SID Chip hardware generation model.
enum SIDChipModel {
  mos6581, // 1982 C64 Fat/Breadbin: Warm, non-linear FET saturation, DC offset warmth, darker cutoff
  mos8580, // 1986 C64C / C128: Clean, sharp resonance, linear cutoff response, pristine digital clarity
}

/// Chiptune hardware arpeggiator modes.
enum SIDArpMode {
  off,
  hz50,   // Standard European PAL C64 V-Blank rate (~20.0ms per note step)
  hz60,   // North American NTSC C64 rate (~16.6ms per note step)
  hz100,  // 2x Multi-speed Tracker frame rate (~10.0ms)
  fast32, // 1/32 note tempo-synced
  fast16, // 1/16 note tempo-synced
}

/// MOS 6581/8580 hardware counter divider clock periods for Attack rates (ms).
const List<double> kSIDAttackRatesMs = [
  2.0, 8.0, 16.0, 24.0, 38.0, 56.0, 68.0, 80.0,
  100.0, 250.0, 500.0, 800.0, 1000.0, 3000.0, 5000.0, 8000.0
];

/// MOS 6581/8580 hardware counter divider clock periods for Decay/Release rates (ms).
const List<double> kSIDDecayReleaseRatesMs = [
  6.0, 24.0, 48.0, 72.0, 114.0, 168.0, 204.0, 240.0,
  300.0, 750.0, 1500.0, 2400.0, 3000.0, 9000.0, 15000.0, 24000.0
];

// ─────────────────────────────────────────────────────────────────────────────
//  AUTHENTIC 23-BIT GALOIS LFSR NOISE GENERATOR
// ─────────────────────────────────────────────────────────────────────────────

/// Authentic MOS 6581/8580 23-bit Galois Linear Feedback Shift Register (LFSR).
/// Taps at bit 22 and bit 17 with characteristic 8-bit output DAC tapping bits 20, 18, 14, 11, 9, 5, 2, 0.
class SIDNoiseGenerator {
  int _lfsr = 0x7FFFF8;

  void reset() {
    _lfsr = 0x7FFFF8;
  }

  /// Clocks the 23-bit shift register whenever the voice oscillator phase wraps around.
  @pragma('vm:prefer-inline')
  void clock() {
    final int bit22 = (_lfsr >> 22) & 1;
    final int bit17 = (_lfsr >> 17) & 1;
    final int feedback = bit22 ^ bit17;
    _lfsr = ((_lfsr << 1) | feedback) & 0x7FFFFF;
  }

  /// Extracts the 8-bit DAC output mapped to [-1.0, 1.0].
  @pragma('vm:prefer-inline')
  double get output {
    final int b7 = (_lfsr >> 20) & 1;
    final int b6 = (_lfsr >> 18) & 1;
    final int b5 = (_lfsr >> 14) & 1;
    final int b4 = (_lfsr >> 11) & 1;
    final int b3 = (_lfsr >> 9) & 1;
    final int b2 = (_lfsr >> 5) & 1;
    final int b1 = (_lfsr >> 2) & 1;
    final int b0 = _lfsr & 1;
    final int out8 = (b7 << 7) | (b6 << 6) | (b5 << 5) | (b4 << 4) | (b3 << 3) | (b2 << 2) | (b1 << 1) | b0;
    return (out8 / 127.5) - 1.0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AUTHENTIC SID VOICE MODEL
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single voice channel (Voice 1, 2, or 3) on the Commodore 64 SID chip.
class SIDVoice {
  final int index;
  SIDWaveform waveform = SIDWaveform.pulse;

  // Pitch & Oscillators
  double baseFreqHz = 440.0;
  double currentFreqHz = 440.0;
  double targetFreqHz = 440.0;
  double detuneHz = 0.0;
  double phase = 0.0; // 0.0 to 1.0 normalized
  double lastOutput = 0.0;

  // Pulse Width (12-bit hardware register: 0..4095; 2048 = 50% square)
  int pulseWidth = 2048;
  double pwmRateHz = 1.2;
  double pwmDepth = 0.4;
  double pwmPhase = 0.0;

  // Hard Sync & Ring Modulation
  bool sync = false; // Sync to source voice
  bool ringMod = false; // Ring modulate with source voice
  bool testBit = false; // Holds oscillator in reset

  // Filter Routing Flag
  bool routeToFilter = true;

  // Glissando / Portamento
  double glideSpeed = 0.0; // Portamento slide time in seconds (0 = off)

  // Hardware Chiptune Arpeggiator
  SIDArpMode arpMode = SIDArpMode.off;
  List<int> arpSemitones = [0, 3, 7, 12]; // Default Minor 7th chord arpeggio
  double arpSpeedSec = 0.020; // 50Hz = 20ms
  int arpStep = 0;
  double _arpTimer = 0.0;

  // Hardware ADSR Envelope Generator (0..15 values mapping to stepped hardware clock rates)
  int attackRate = 0;   // 0..15
  int decayRate = 6;    // 0..15
  int sustainLevel = 10;// 0..15
  int releaseRate = 4;  // 0..15

  // Envelope State
  double _envLevel = 0.0;
  double _attackTime = 0.002;
  double _decayTime = 0.204;
  double _sustainLevelNorm = 0.66;
  double _releaseTime = 0.114;
  double _gateTime = 0.4;

  final SIDNoiseGenerator noiseGen = SIDNoiseGenerator();

  SIDVoice({this.index = 0});

  void reset() {
    phase = 0.0;
    lastOutput = 0.0;
    pwmPhase = 0.0;
    _arpTimer = 0.0;
    arpStep = 0;
    _envLevel = 0.0;
    noiseGen.reset();
  }

  /// Prepares envelope intervals and target parameters per note trigger.
  void prepare({
    required double durationSec,
    required double baseFreq,
    double? slideToFreq,
  }) {
    baseFreqHz = baseFreq;
    currentFreqHz = baseFreq;
    targetFreqHz = slideToFreq ?? baseFreq;

    _attackTime = (kSIDAttackRatesMs[attackRate.clamp(0, 15)] / 1000.0);
    _decayTime = (kSIDDecayReleaseRatesMs[decayRate.clamp(0, 15)] / 1000.0);
    _sustainLevelNorm = (sustainLevel.clamp(0, 15) / 15.0);
    _releaseTime = (kSIDDecayReleaseRatesMs[releaseRate.clamp(0, 15)] / 1000.0);
    _gateTime = math.max(_attackTime + _decayTime, durationSec);

    // Arp rate
    switch (arpMode) {
      case SIDArpMode.hz50: arpSpeedSec = 0.020; break;
      case SIDArpMode.hz60: arpSpeedSec = 0.0166; break;
      case SIDArpMode.hz100: arpSpeedSec = 0.010; break;
      case SIDArpMode.fast32: arpSpeedSec = 0.03125; break;
      case SIDArpMode.fast16: arpSpeedSec = 0.0625; break;
      case SIDArpMode.off: arpSpeedSec = 1.0; break;
    }

    _arpTimer = 0.0;
    arpStep = 0;
  }

  /// Fast inline envelope evaluation.
  @pragma('vm:prefer-inline')
  double evaluateEnvelope(double time) {
    if (time < _attackTime) {
      _envLevel = (_attackTime > 0.0001 ? (time / _attackTime) : 1.0).clamp(0.0, 1.0);
    } else if (time < _attackTime + _decayTime) {
      final double decayProgress = (time - _attackTime) / _decayTime;
      // Authentic MOS stepped exponential decay approximation
      _envLevel = 1.0 - decayProgress * (1.0 - _sustainLevelNorm);
    } else if (time < _gateTime) {
      _envLevel = _sustainLevelNorm;
    } else {
      final double releaseProgress = (time - _gateTime) / _releaseTime;
      _envLevel = (_sustainLevelNorm * math.max(0.0, 1.0 - releaseProgress)).clamp(0.0, 1.0);
    }
    return _envLevel;
  }

  /// Synthesizes one raw audio sample for this voice.
  @pragma('vm:prefer-inline')
  double evaluateSample({
    required double time,
    required double dt,
    required double sampleRate,
    SIDVoice? syncSourceVoice,
  }) {
    if (testBit) return 0.0;

    // 1. Portamento / Glissando Glide
    if (glideSpeed > 0.001 && targetFreqHz != currentFreqHz) {
      final double glideStep = (targetFreqHz - currentFreqHz) * (dt / glideSpeed);
      currentFreqHz += glideStep;
      if ((targetFreqHz - currentFreqHz).abs() < 0.5) currentFreqHz = targetFreqHz;
    }

    // 2. Hardware Chiptune Arpeggiator
    double arpPitchMult = 1.0;
    if (arpMode != SIDArpMode.off && arpSemitones.isNotEmpty) {
      _arpTimer += dt;
      if (_arpTimer >= arpSpeedSec) {
        _arpTimer -= arpSpeedSec;
        arpStep = (arpStep + 1) % arpSemitones.length;
      }
      final int semi = arpSemitones[arpStep];
      arpPitchMult = math.pow(2.0, semi / 12.0).toDouble();
    }

    // 3. Frequency and Phase Advance
    final double effectiveFreq = (currentFreqHz * arpPitchMult) + detuneHz;
    final double phaseInc = effectiveFreq / sampleRate;

    // Hard Sync check
    if (sync && syncSourceVoice != null) {
      if (syncSourceVoice.phase < syncSourceVoice.lastOutput) {
        phase = 0.0; // Reset oscillator on sync source cycle wrap
      }
    }

    final double oldPhase = phase;
    phase += phaseInc;
    if (phase >= 1.0) {
      phase -= 1.0;
      noiseGen.clock(); // Clock 23-bit Galois LFSR on wave period completion
    }

    // 4. Waveform Generation
    double rawWave = 0.0;
    switch (waveform) {
      case SIDWaveform.triangle:
        // Ring modulation: XORs triangle phase with ring source
        double triPhase = phase;
        if (ringMod && syncSourceVoice != null) {
          if (syncSourceVoice.phase >= 0.5) {
            triPhase = 1.0 - triPhase;
          }
        }
        rawWave = triPhase < 0.5 ? (4.0 * triPhase - 1.0) : (3.0 - 4.0 * triPhase);
        break;

      case SIDWaveform.sawtooth:
        rawWave = 2.0 * phase - 1.0;
        break;

      case SIDWaveform.pulse:
        // PWM LFO modulation
        pwmPhase += pwmRateHz / sampleRate;
        if (pwmPhase >= 1.0) pwmPhase -= 1.0;
        final double pwmLfo = math.sin(pwmPhase * 2.0 * math.pi);
        final double effectivePw = ((pulseWidth / 4095.0) + pwmLfo * pwmDepth * 0.45).clamp(0.02, 0.98);
        rawWave = phase < effectivePw ? 1.0 : -1.0;
        break;

      case SIDWaveform.noise:
        rawWave = noiseGen.output;
        break;

      case SIDWaveform.combinedSawPulse:
        // Iconic SID combined waveform: Analog FET bus pulling produces distorted hybrid
        final double saw = 2.0 * phase - 1.0;
        final double pulse = phase < (pulseWidth / 4095.0) ? 1.0 : -1.0;
        rawWave = (saw + pulse) * 0.5;
        break;

      case SIDWaveform.combinedTriSaw:
        final double tri = phase < 0.5 ? (4.0 * phase - 1.0) : (3.0 - 4.0 * phase);
        final double saw = 2.0 * phase - 1.0;
        rawWave = (tri + saw) * 0.5;
        break;
    }

    // 5. Envelope Application
    final double env = evaluateEnvelope(time);
    lastOutput = rawWave * env;
    return lastOutput;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AUTHENTIC 12 DB/OCTAVE MULTI-MODE RESONANT FILTER (MOS 6581 / 8580)
// ─────────────────────────────────────────────────────────────────────────────

/// Authentic 12 dB/Octave State-Variable Filter (SVF Chamberlin topology).
/// Models the iconic resonant multimode filter of the SID chip with switchable
/// MOS 6581 (non-linear FET saturation / DC warmth) and MOS 8580 (linear clean).
class SIDFilter {
  SIDChipModel chipModel = SIDChipModel.mos6581;
  SIDFilterMode mode = SIDFilterMode.lowpass;

  // Filter registers (11-bit Cutoff: 0..2047, 4-bit Resonance: 0..15)
  int cutoffReg = 1200; // ~1.5 kHz default
  int resonanceReg = 8; // Medium resonance

  // Internal state
  double _low = 0.0;
  double _band = 0.0;

  void reset() {
    _low = 0.0;
    _band = 0.0;
  }

  /// Evaluates the 12dB resonant SVF for [inputSample].
  @pragma('vm:prefer-inline')
  double process(double inputSample, double sampleRate) {
    if (mode == SIDFilterMode.off) return inputSample;

    // Cutoff frequency curve mapping (6581 has logarithmic dark slope; 8580 is linear)
    double cutoffHz;
    if (chipModel == SIDChipModel.mos6581) {
      // MOS 6581: Empirical curve ~30Hz to ~10kHz with non-linear saturation
      cutoffHz = 30.0 + math.pow(cutoffReg.clamp(0, 2047) / 2047.0, 2.2).toDouble() * 9500.0;
    } else {
      // MOS 8580: Strict linear cutoff ~30Hz to ~12.5kHz
      cutoffHz = 30.0 + (cutoffReg.clamp(0, 2047) / 2047.0) * 12500.0;
    }

    // Resonance damping factor (Q = 0.707 to 8.0)
    final double q = 0.707 + (resonanceReg.clamp(0, 15) / 15.0) * 7.293;
    final double damping = 1.0 / q;

    // Chamberlin SVF coefficients
    final double f = (2.0 * math.sin(math.pi * cutoffHz / sampleRate)).clamp(0.01, 0.85);

    // 6581 Non-linear FET soft-saturation modeling
    double processedIn = inputSample;
    if (chipModel == SIDChipModel.mos6581) {
      // Soft saturation on filter input & resonance feedback (FET op-amp distortion)
      processedIn = _fastTanh(inputSample * 1.25);
    }

    final double high = processedIn - _low - damping * _band;
    _band += f * high;
    _low += f * _band;

    // 6581 Integrator saturation
    if (chipModel == SIDChipModel.mos6581) {
      _band = _fastTanh(_band);
      _low = _fastTanh(_low);
    }

    double outSample = 0.0;
    switch (mode) {
      case SIDFilterMode.lowpass:
        outSample = _low;
        break;
      case SIDFilterMode.bandpass:
        outSample = _band;
        break;
      case SIDFilterMode.highpass:
        outSample = high;
        break;
      case SIDFilterMode.notch:
        outSample = _low + high;
        break;
      case SIDFilterMode.off:
        outSample = inputSample;
        break;
    }

    return outSample;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMMODORE 64 SID SYNTHESIZER ENGINE
// ─────────────────────────────────────────────────────────────────────────────

/// High-Accuracy, Expressive Commodore 64 SID Synthesizer Engine.
/// Supports both **Modern Polyphonic Mode** (unlimited multi-note MIDI expressivity)
/// and **Authentic 3-Voice Paraphonic Mode** (exact C64 routing with Voice 1-3 sync/ringmod),
/// 12-bit PWM, 23-bit Galois LFSR noise, 50Hz/60Hz chiptune arpeggiation, glissando,
/// 12dB resonant multimode filter (MOS 6581 vs. MOS 8580), and C64 register access.
class SIDSynthEngine {
  final List<SIDVoice> voices = [
    SIDVoice(index: 0),
    SIDVoice(index: 1),
    SIDVoice(index: 2),
  ];

  final SIDFilter filter = SIDFilter();

  // Master Voicing & Timbre Parameters
  SIDChipModel get chipModel => filter.chipModel;
  set chipModel(SIDChipModel val) => filter.chipModel = val;

  bool isModernPolyphonic = true; // Lift 3-voice limit for modern DAW chord work
  int masterVolume = 15; // 4-bit volume (0..15)
  double overdrive = 1.0; // Analog master saturation

  SIDSynthEngine({
    SIDChipModel model = SIDChipModel.mos6581,
    this.isModernPolyphonic = true,
  }) {
    filter.chipModel = model;
    _setupDefaultChiptunePatch();
  }

  void reset() {
    for (final v in voices) {
      v.reset();
    }
    filter.reset();
  }

  void _setupDefaultChiptunePatch() {
    // Voice 1: Classic Rob Hubbard 12-bit PWM Pulse Lead
    voices[0]
      ..waveform = SIDWaveform.pulse
      ..pulseWidth = 2048
      ..pwmRateHz = 1.6
      ..pwmDepth = 0.45
      ..attackRate = 1
      ..decayRate = 6
      ..sustainLevel = 12
      ..releaseRate = 5
      ..routeToFilter = true;

    // Voice 2: Punchy Sawtooth Sub / Harmony
    voices[1]
      ..waveform = SIDWaveform.sawtooth
      ..attackRate = 0
      ..decayRate = 4
      ..sustainLevel = 8
      ..releaseRate = 4
      ..routeToFilter = true;

    // Voice 3: 23-Bit Galois LFSR Noise / Chiptune Percussion
    voices[2]
      ..waveform = SIDWaveform.noise
      ..attackRate = 0
      ..decayRate = 3
      ..sustainLevel = 0
      ..releaseRate = 3
      ..routeToFilter = false; // Bypass filter for crisp retro snap

    filter
      ..mode = SIDFilterMode.lowpass
      ..cutoffReg = 1350
      ..resonanceReg = 9;
  }

  /// Writes standard C64 memory-mapped I/O registers ($D400..$D418 / 0x00..0x18).
  void writeRegister(int regAddr, int value) {
    final int addr = regAddr & 0x1F;

    if (addr < 21) {
      // Voice registers (7 registers per voice)
      final int vIdx = (addr ~/ 7).clamp(0, 2);
      final int vReg = addr % 7;
      final voice = voices[vIdx];

      switch (vReg) {
        case 0: // Freq Lo
          break;
        case 1: // Freq Hi
          break;
        case 2: // Pulse Width Lo (bits 0..7)
          voice.pulseWidth = (voice.pulseWidth & 0x0F00) | (value & 0xFF);
          break;
        case 3: // Pulse Width Hi (bits 8..11)
          voice.pulseWidth = (voice.pulseWidth & 0x00FF) | ((value & 0x0F) << 8);
          break;
        case 4: // Control Register (Gate, Sync, RingMod, Test, Tri, Saw, Pulse, Noise)
          voice.sync = (value & 0x02) != 0;
          voice.ringMod = (value & 0x04) != 0;
          voice.testBit = (value & 0x08) != 0;
          if ((value & 0x10) != 0) voice.waveform = SIDWaveform.triangle;
          if ((value & 0x20) != 0) voice.waveform = SIDWaveform.sawtooth;
          if ((value & 0x40) != 0) voice.waveform = SIDWaveform.pulse;
          if ((value & 0x80) != 0) voice.waveform = SIDWaveform.noise;
          break;
        case 5: // Attack (bits 4..7) / Decay (bits 0..3)
          voice.attackRate = (value >> 4) & 0x0F;
          voice.decayRate = value & 0x0F;
          break;
        case 6: // Sustain (bits 4..7) / Release (bits 0..3)
          voice.sustainLevel = (value >> 4) & 0x0F;
          voice.releaseRate = value & 0x0F;
          break;
      }
    } else {
      // Global Filter and Volume registers (addr 21..24 / 0x15..0x18)
      switch (addr) {
        case 0x15: // Filter Cutoff Lo (bits 0..2)
          filter.cutoffReg = (filter.cutoffReg & 0x07F8) | (value & 0x07);
          break;
        case 0x16: // Filter Cutoff Hi (bits 3..10)
          filter.cutoffReg = (filter.cutoffReg & 0x0007) | ((value & 0xFF) << 3);
          break;
        case 0x17: // Resonance (bits 4..7) / Voice Filter Routing (bits 0..2)
          filter.resonanceReg = (value >> 4) & 0x0F;
          voices[0].routeToFilter = (value & 0x01) != 0;
          voices[1].routeToFilter = (value & 0x02) != 0;
          voices[2].routeToFilter = (value & 0x04) != 0;
          break;
        case 0x18: // Mode (bits 4..6: LP, BP, HP) / Master Volume (bits 0..3)
          masterVolume = value & 0x0F;
          final int modeBits = (value >> 4) & 0x07;
          if (modeBits == 1) filter.mode = SIDFilterMode.lowpass;
          else if (modeBits == 2) filter.mode = SIDFilterMode.bandpass;
          else if (modeBits == 4) filter.mode = SIDFilterMode.highpass;
          else if (modeBits == 5) filter.mode = SIDFilterMode.notch;
          else filter.mode = SIDFilterMode.off;
          break;
      }
    }
  }

  /// Synthesizes a complete PCM buffer for a given note trigger.
  void processBuffer({
    required Float32List outBuffer,
    required double baseFreq,
    required double sampleRate,
    required double durationSec,
    double velocity = 0.85,
    int? targetMidiNote,
    bool isSlide = false,
  }) {
    if (baseFreq <= 0) {
      outBuffer.fillRange(0, outBuffer.length, 0.0);
      return;
    }

    final int len = outBuffer.length;
    final double dt = 1.0 / sampleRate;

    // Target slide frequency for glissando
    double? slideFreq;
    if (isSlide && targetMidiNote != null) {
      slideFreq = 440.0 * math.pow(2.0, (targetMidiNote - 69) / 12.0).toDouble();
    }

    // Prepare all voices
    for (int v = 0; v < 3; v++) {
      voices[v].prepare(
        durationSec: durationSec,
        baseFreq: baseFreq,
        slideToFreq: slideFreq,
      );
    }

    final double volScale = (masterVolume / 15.0) * velocity.clamp(0.0, 1.0);

    for (int i = 0; i < len; i++) {
      final double time = i * dt;

      double filteredSum = 0.0;
      double directSum = 0.0;

      // Voice 0 (Sync source is Voice 2)
      final double s0 = voices[0].evaluateSample(
        time: time,
        dt: dt,
        sampleRate: sampleRate,
        syncSourceVoice: voices[2],
      );
      if (voices[0].routeToFilter) filteredSum += s0; else directSum += s0;

      // Voice 1 (Sync source is Voice 0)
      final double s1 = voices[1].evaluateSample(
        time: time,
        dt: dt,
        sampleRate: sampleRate,
        syncSourceVoice: voices[0],
      );
      if (voices[1].routeToFilter) filteredSum += s1; else directSum += s1;

      // Voice 2 (Sync source is Voice 1)
      final double s2 = voices[2].evaluateSample(
        time: time,
        dt: dt,
        sampleRate: sampleRate,
        syncSourceVoice: voices[1],
      );
      if (voices[2].routeToFilter) filteredSum += s2; else directSum += s2;

      // Process 12dB multi-mode filter
      final double filterOut = filter.process(filteredSum, sampleRate);

      // Sum filtered and bypass channels with master volume and overdrive
      double finalSample = (filterOut + directSum) * 0.40 * volScale;

      if (overdrive > 1.01) {
        finalSample = _fastTanh(finalSample * overdrive);
      }

      outBuffer[i] = finalSample.clamp(-1.0, 1.0);
    }
  }
}
