import 'dart:math' as math;
import 'dart:typed_data';
import 'fm_chip_engine.dart'; // For DeterministicPRNG

/// Authentic SNES 16-Bit S-DSP Waveform Types (BRR encoded single-cycle & multi-cycle wavetables).
enum SNESWaveform {
  sine,
  square,
  pulse25,
  pulse12,
  sawtooth,
  triangle,
  organ,
  strings,
  flute,
  slapBass,
  chime,
  noise,
}

/// S-DSP Envelope Modes
enum SNESEnvelopeMode {
  adsr,
  gainDirect,
  gainLinearDecrease,
  gainExpDecrease,
  gainLinearIncrease,
  gainBentIncrease,
}

/// Represents a single voice channel (Channel 0..7) in the 16-Bit S-DSP.
class SNESVoice {
  final int index;

  // Pitch & Sample Playback
  double pitch = 1.0; // Pitch multiplier relative to base frequency
  double basePitchHz = 440.0;
  SNESWaveform waveform = SNESWaveform.square;
  double phase = 0.0;
  double lastOutput = 0.0;

  // Volume & Panning (-128 to 127 in hardware, normalized -1.0 to 1.0)
  double volumeLeft = 0.7;
  double volumeRight = 0.7;

  // Envelope Generator
  SNESEnvelopeMode envMode = SNESEnvelopeMode.adsr;
  double attack = 0.005; // Seconds
  double decay = 0.25; // Seconds
  double sustain = 0.4; // 0.0 to 1.0
  double release = 0.2; // Seconds
  double gainLevel = 1.0; // For direct/gain modes

  // Pitch Sweeps & Arpeggios
  double startFreqMult = 1.0;
  double endFreqMult = 1.0;
  double sweepDuration = 0.0;
  List<int> arpeggioNotes = [];
  double arpeggioSpeed = 0.05; // Seconds per note

  // Vibrato / Pitch LFO
  double vibratoRate = 0.0; // Hz
  double vibratoDepth = 0.0; // Semitones / depth

  // S-DSP Noise Mode
  bool noiseEnabled = false;
  int noiseRate = 8; // 0..14 clock rate
  double noiseMix = 0.0;

  // Cross-Channel Pitch Modulation (PMOD: Voice n-1 modulates Voice n)
  bool pmodEnabled = false;

  // Echo Enable
  bool echoEnabled = true;

  // Voice Enabled (Key On)
  bool enabled = true;

  SNESVoice({required this.index}) {
    enabled = (index == 0);
  }

  void reset() {
    enabled = (index == 0);
    phase = 0.0;
    lastOutput = 0.0;
    startFreqMult = 1.0;
    endFreqMult = 1.0;
    sweepDuration = 0.0;
    arpeggioNotes = [];
    vibratoRate = 0.0;
    vibratoDepth = 0.0;
    noiseEnabled = false;
    noiseMix = 0.0;
    pmodEnabled = false;
    echoEnabled = true;
    waveform = SNESWaveform.square;
    envMode = SNESEnvelopeMode.adsr;
    attack = 0.005;
    decay = 0.25;
    sustain = 0.4;
    release = 0.2;
    gainLevel = 1.0;
  }

  /// Calculates envelope gain at given time in seconds.
  double evaluateEnvelope(double time, double duration) {
    switch (envMode) {
      case SNESEnvelopeMode.gainDirect:
        return gainLevel.clamp(0.0, 1.0);

      case SNESEnvelopeMode.gainLinearDecrease:
        final progress = (time / math.max(0.01, decay)).clamp(0.0, 1.0);
        return (1.0 - progress).clamp(0.0, 1.0);

      case SNESEnvelopeMode.gainExpDecrease:
        return math.exp(-time / math.max(0.01, decay)).clamp(0.0, 1.0);

      case SNESEnvelopeMode.gainLinearIncrease:
        final progress = (time / math.max(0.001, attack)).clamp(0.0, 1.0);
        return progress;

      case SNESEnvelopeMode.gainBentIncrease:
        final progress = (time / math.max(0.001, attack)).clamp(0.0, 1.0);
        return progress < 0.75 ? (progress * 0.5) : (0.375 + (progress - 0.75) * 2.5);

      case SNESEnvelopeMode.adsr:
      default:
        final a = math.max(0.0001, attack);
        final d = math.max(0.001, decay);
        final s = sustain.clamp(0.0, 1.0);
        final r = math.max(0.001, release);
        final gate = math.max(a + d, duration);

        if (time < a) {
          return (time / a).clamp(0.0, 1.0);
        } else if (time < a + d) {
          final decProg = (time - a) / d;
          return 1.0 - (decProg * (1.0 - s));
        } else if (time < gate) {
          return s;
        } else {
          final relProg = (time - gate) / r;
          return (s * math.max(0.0, 1.0 - relProg)).clamp(0.0, 1.0);
        }
    }
  }

  static const double _twoPi = 2.0 * math.pi;
  static const double _invTwoPi = 1.0 / (2.0 * math.pi);

  /// Evaluates S-DSP BRR wavetable sample with authentic Gaussian low-pass curve.
  double evaluateWaveform(double ph) {
    final double normPhase = ph < 0 ? ((ph % _twoPi) + _twoPi) : (ph >= _twoPi ? (ph % _twoPi) : ph);
    final double normPos = normPhase * _invTwoPi; // 0.0 to 1.0

    switch (waveform) {
      case SNESWaveform.sine:
        return math.sin(normPhase);

      case SNESWaveform.square:
        // 50% duty cycle with Gaussian-smoothed edge
        final sqr = normPos < 0.5 ? 1.0 : -1.0;
        return _gaussianSmooth(sqr, normPos, 0.5);

      case SNESWaveform.pulse25:
        // 25% duty cycle classic SNES pulse
        final sqr = normPos < 0.25 ? 1.0 : -1.0;
        return _gaussianSmooth(sqr, normPos, 0.25);

      case SNESWaveform.pulse12:
        // 12.5% duty cycle sharp pulse
        final sqr = normPos < 0.125 ? 1.0 : -1.0;
        return _gaussianSmooth(sqr, normPos, 0.125);

      case SNESWaveform.sawtooth:
        // Anti-aliased band-limited ramp
        return (2.0 * normPos - 1.0) * 0.9;

      case SNESWaveform.triangle:
        return (2.0 / math.pi) * math.asin(math.sin(normPhase).clamp(-1.0, 1.0));

      case SNESWaveform.organ:
        // Dual harmonic organ wave (1st + 2nd + 4th harmonics)
        final s1 = math.sin(normPhase);
        final s2 = math.sin(normPhase * 2.0) * 0.5;
        final s4 = math.sin(normPhase * 4.0) * 0.25;
        return (s1 + s2 + s4) * 0.57;

      case SNESWaveform.strings:
        // Warm rich multi-saw strings
        final saw1 = 2.0 * normPos - 1.0;
        final saw2 = 2.0 * ((normPos * 2.0) % 1.0) - 1.0;
        return (saw1 * 0.6 + saw2 * 0.4);

      case SNESWaveform.flute:
        // Pure breathy sine + subtle 3rd harmonic
        return math.sin(normPhase) * 0.85 + math.sin(normPhase * 3.0) * 0.15;

      case SNESWaveform.slapBass:
        // Punchy resonant transient wavetable
        final b1 = math.sin(normPhase);
        final b2 = math.sin(normPhase * 3.0) * 0.4;
        return (b1 + b2) * 0.7;

      case SNESWaveform.chime:
        // Inharmonic metallic bell chime
        final c1 = math.sin(normPhase);
        final c2 = math.sin(normPhase * 2.76) * 0.4;
        final c3 = math.sin(normPhase * 5.4) * 0.25;
        return (c1 + c2 + c3) * 0.6;

      case SNESWaveform.noise:
        return 0.0; // Evaluated in voice noise generator
    }
  }

  /// 4-point Gaussian smoothing emulation
  static double _gaussianSmooth(double rawVal, double normPos, double transitionPoint) {
    const edgeWidth = 0.03;
    final dist1 = (normPos - 0.0).abs();
    final dist2 = (normPos - transitionPoint).abs();
    final dist3 = (normPos - 1.0).abs();

    if (dist1 < edgeWidth || dist2 < edgeWidth || dist3 < edgeWidth) {
      return rawVal * 0.85; // Slight Gaussian roll-off at transitions
    }
    return rawVal;
  }
}

/// 8-Tap FIR Echo & Reverb DSP Unit (Emulates hardware S-DSP Echo).
class SNESEchoUnit {
  static const int maxEchoDelaySamples = 131072; // Power of 2 (2^17) covering ~2.97s stereo ring buffer
  static const int maxEchoDelayMask = 131071;
  final Float32List _echoBufferLeft = Float32List(maxEchoDelaySamples);
  final Float32List _echoBufferRight = Float32List(maxEchoDelaySamples);
  int _writeIndex = 0;

  // Echo Parameters
  bool enabled = true;
  double feedback = 0.45; // -1.0 to 1.0
  double volume = 0.4; // 0.0 to 1.0
  int _delayMs = 120; // 0 to 480 ms (Hardware EDL register: 0..15 * 16ms)
  int get delayMs => _delayMs;
  set delayMs(int val) {
    _delayMs = val.clamp(16, 480);
    _cachedDelaySamples = ((_delayMs / 1000.0) * 44100.0).toInt().clamp(64, maxEchoDelaySamples - 64);
  }
  int _cachedDelaySamples = (120 * 44.1).toInt();

  // 8-Tap Programmable FIR Filter Coefficients (C0..C7)
  List<double> firCoefficients = [0.34, 0.45, -0.12, 0.10, -0.05, 0.08, -0.04, 0.02];

  void reset() {
    _echoBufferLeft.fillRange(0, maxEchoDelaySamples, 0.0);
    _echoBufferRight.fillRange(0, maxEchoDelaySamples, 0.0);
    _writeIndex = 0;
    enabled = false;
    volume = 0.0;
  }

  /// Sets one of the classic built-in SNES FIR filter profiles.
  void setFIRProfile(String profileName) {
    switch (profileName.toLowerCase()) {
      case 'dark_reverb':
      case 'dark_hall':
        firCoefficients = [0.5, 0.35, 0.15, 0.05, -0.02, 0.02, -0.01, 0.01];
        break;
      case 'metallic_chorus':
      case 'metallic':
        firCoefficients = [0.25, -0.35, 0.45, -0.25, 0.15, -0.1, 0.05, -0.02];
        break;
      case 'slapback':
        firCoefficients = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        break;
      case 'surround_reverb':
      default:
        firCoefficients = [0.34, 0.45, -0.12, 0.10, -0.05, 0.08, -0.04, 0.02];
        break;
    }
  }

  final Float32List _echoResult = Float32List(2);

  /// Processes stereo sample through 8-tap FIR echo buffer and returns [leftWet, rightWet].
  Float32List processStereo(double leftDry, double rightDry) {
    if (!enabled || volume <= 0.001) {
      _echoResult[0] = leftDry;
      _echoResult[1] = rightDry;
      return _echoResult;
    }

    final int baseReadIdx = _writeIndex - _cachedDelaySamples;
    double leftFir = 0.0;
    double rightFir = 0.0;

    for (int tap = 0; tap < 8; tap++) {
      final int tapIndex = (baseReadIdx - (tap << 2)) & maxEchoDelayMask;
      final double coeff = firCoefficients[tap];
      leftFir += _echoBufferLeft[tapIndex] * coeff;
      rightFir += _echoBufferRight[tapIndex] * coeff;
    }

    // Write dry + feedback into ring buffer
    _echoBufferLeft[_writeIndex] = (leftDry + (leftFir * feedback)).clamp(-1.5, 1.5);
    _echoBufferRight[_writeIndex] = (rightDry + (rightFir * feedback)).clamp(-1.5, 1.5);
    _writeIndex = (_writeIndex + 1) & maxEchoDelayMask;

    final outL = (leftDry * (1.0 - volume * 0.5)) + (leftFir * volume);
    final outR = (rightDry * (1.0 - volume * 0.5)) + (rightFir * volume);

    _echoResult[0] = outL.clamp(-1.0, 1.0);
    _echoResult[1] = outR.clamp(-1.0, 1.0);
    return _echoResult;
  }
}

/// Comprehensive SPC700 / S-DSP Sound Chip Engine (SNES Sound Emulation).
class SNESDSPEngine {
  final List<SNESVoice> voices = List.generate(8, (i) => SNESVoice(index: i));
  final SNESEchoUnit echo = SNESEchoUnit();

  // S-DSP Noise LFSR
  int _noiseLfsr = 0x4000;
  int _noiseClockCounter = 0;

  // Master Volume
  double masterVolume = 0.85;

  // Deterministic PRNG for sound FX seeds and micro-variations
  int seed = 42;
  late final DeterministicPRNG prng;

  SNESDSPEngine({int seed = 42}) {
    this.seed = seed;
    prng = DeterministicPRNG(seed);
  }

  void setSeed(int newSeed) {
    seed = newSeed;
    prng.seed(newSeed);
  }

  void reset() {
    for (final v in voices) {
      v.reset();
    }
    echo.reset();
    _noiseLfsr = 0x4000;
    _noiseClockCounter = 0;
  }

  /// Writes directly to an S-DSP chip register (0x00 to 0x7F).
  void writeRegister(int reg, int value) {
    final v = value & 0xFF;
    final voiceIdx = (reg >> 4) & 0x07;
    final regType = reg & 0x0F;

    if (voiceIdx < 8 && regType < 0x08) {
      final voice = voices[voiceIdx];
      switch (regType) {
        case 0x00: // VOL_L
          voice.volumeLeft = (v >= 128 ? v - 256 : v) / 127.0;
          break;
        case 0x01: // VOL_R
          voice.volumeRight = (v >= 128 ? v - 256 : v) / 127.0;
          break;
        case 0x02: // P_LOW (Pitch Low Byte)
          voice.pitch = (voice.pitch.floor() & 0x3F00 | v) / 4096.0;
          break;
        case 0x03: // P_HIGH (Pitch High Byte)
          voice.pitch = (((v & 0x3F) << 8) | ((voice.pitch * 4096).toInt() & 0xFF)) / 4096.0;
          break;
        case 0x04: // SCRN (Source Number)
          final wIdx = v % SNESWaveform.values.length;
          voice.waveform = SNESWaveform.values[wIdx];
          break;
        case 0x05: // ADSR1 (Attack / Decay)
          voice.attack = math.max(0.001, (15 - ((v >> 4) & 0x0F)) * 0.03);
          voice.decay = math.max(0.01, (7 - (v & 0x07)) * 0.1);
          voice.envMode = (v & 0x80) != 0 ? SNESEnvelopeMode.adsr : SNESEnvelopeMode.gainDirect;
          break;
        case 0x06: // ADSR2 (Sustain / Release)
          voice.sustain = ((v >> 5) & 0x07) / 7.0;
          voice.release = math.max(0.005, (31 - (v & 0x1F)) * 0.05);
          break;
        case 0x07: // GAIN
          if ((v & 0x80) == 0) {
            voice.envMode = SNESEnvelopeMode.gainDirect;
            voice.gainLevel = (v & 0x7F) / 127.0;
          } else {
            final mode = (v >> 5) & 0x03;
            if (mode == 0) voice.envMode = SNESEnvelopeMode.gainLinearDecrease;
            if (mode == 1) voice.envMode = SNESEnvelopeMode.gainExpDecrease;
            if (mode == 2) voice.envMode = SNESEnvelopeMode.gainLinearIncrease;
            if (mode == 3) voice.envMode = SNESEnvelopeMode.gainBentIncrease;
            voice.decay = math.max(0.01, (31 - (v & 0x1F)) * 0.08);
          }
          break;
      }
      return;
    }

    // Global DSP Registers (0x0D..0x7D)
    switch (reg) {
      case 0x0D: // EFB (Echo Feedback)
        echo.feedback = (v >= 128 ? v - 256 : v) / 128.0;
        break;
      case 0x2D: // PMOD (Pitch Modulation on channels 1..7)
        for (int i = 1; i < 8; i++) {
          voices[i].pmodEnabled = (v & (1 << i)) != 0;
        }
        break;
      case 0x3D: // NON (Noise On channels 0..7)
        for (int i = 0; i < 8; i++) {
          voices[i].noiseEnabled = (v & (1 << i)) != 0;
        }
        break;
      case 0x4D: // EON (Echo On channels 0..7)
        for (int i = 0; i < 8; i++) {
          voices[i].echoEnabled = (v & (1 << i)) != 0;
        }
        break;
      case 0x6C: // FLG (Noise clock rate & Echo mute)
        echo.enabled = (v & 0x20) == 0;
        final nClock = v & 0x1F;
        for (final voice in voices) {
          voice.noiseRate = nClock.clamp(0, 14);
        }
        break;
      case 0x7D: // EDL (Echo Delay: 0..15)
        echo.delayMs = (v & 0x0F) * 16 + 16;
        break;
    }
  }

  /// Evaluates next noise sample from S-DSP 15-bit Galois LFSR.
  double _stepNoise(int clockRate) {
    final stepInterval = math.max(1, 16 - clockRate);
    _noiseClockCounter++;
    if (_noiseClockCounter >= stepInterval) {
      _noiseClockCounter = 0;
      final feedbackBit = ((_noiseLfsr & 0x01) ^ ((_noiseLfsr >> 1) & 0x01));
      _noiseLfsr = ((_noiseLfsr >> 1) | (feedbackBit << 14)) & 0x7FFF;
    }
    return (_noiseLfsr / 16384.0) - 1.0;
  }

  final Float32List _stereoResult = Float32List(2);

  /// Evaluates stereo sample for all active S-DSP voices at [time] seconds.
  Float32List evaluateStereoSample({
    required double time,
    required double baseFreq,
    double duration = 0.4,
    int sampleIndex = 0,
  }) {
    if (baseFreq <= 0) {
      _stereoResult[0] = 0.0;
      _stereoResult[1] = 0.0;
      return _stereoResult;
    }

    double dryLeft = 0.0;
    double dryRight = 0.0;
    double echoLeft = 0.0;
    double echoRight = 0.0;

    double prevVoiceOut = 0.0;

    // Fast path for single voice mode (e.g. standard synth patches where only voice 0 is enabled)
    final bool isSingleVoice0 = voices[0].enabled &&
        !voices[1].enabled &&
        !voices[2].enabled &&
        !voices[3].enabled &&
        !voices[4].enabled &&
        !voices[5].enabled &&
        !voices[6].enabled &&
        !voices[7].enabled;

    if (isSingleVoice0) {
      final voice = voices[0];
      double curFreq = (baseFreq > 0 ? baseFreq : voice.basePitchHz) * voice.pitch;

      if (voice.sweepDuration > 0.001 && time < voice.sweepDuration) {
        final prog = (time / voice.sweepDuration).clamp(0.0, 1.0);
        final curve = voice.startFreqMult > voice.endFreqMult
            ? math.pow(1.0 - prog, 2.2).toDouble()
            : math.pow(prog, 1.4).toDouble();
        final mult = voice.endFreqMult + (voice.startFreqMult - voice.endFreqMult) * curve;
        curFreq *= mult;
      }

      if (voice.arpeggioNotes.isNotEmpty) {
        final arpIdx = (time / math.max(0.01, voice.arpeggioSpeed)).floor() % voice.arpeggioNotes.length;
        final semi = voice.arpeggioNotes[arpIdx];
        curFreq *= math.pow(2.0, semi / 12.0);
      }

      if (voice.vibratoDepth > 0.001 && voice.vibratoRate > 0.1) {
        final vib = math.sin(2.0 * math.pi * voice.vibratoRate * time) * (voice.vibratoDepth / 12.0);
        // Fast vibrato approximation: 2^x ≈ 1.0 + 0.693147 * x for small vibrato depths
        curFreq *= (1.0 + 0.693147 * vib);
      }

      voice.phase += (2.0 * math.pi * curFreq) / 44100.0;
      if (voice.phase >= 2.0 * math.pi) {
        voice.phase -= 2.0 * math.pi;
      }

      final env = voice.evaluateEnvelope(time, duration);

      double rawSample = 0.0;
      if (voice.noiseEnabled || voice.waveform == SNESWaveform.noise) {
        rawSample = _stepNoise(voice.noiseRate);
      } else {
        rawSample = voice.evaluateWaveform(voice.phase);
      }

      if (voice.noiseMix > 0.001 && !voice.noiseEnabled) {
        final noise = _stepNoise(voice.noiseRate);
        rawSample = (rawSample * (1.0 - voice.noiseMix)) + (noise * voice.noiseMix);
      }

      final voiceOut = rawSample * env;
      voice.lastOutput = voiceOut;

      dryLeft = voiceOut * voice.volumeLeft;
      dryRight = voiceOut * voice.volumeRight;

      if (voice.echoEnabled) {
        echoLeft = dryLeft;
        echoRight = dryRight;
      }
    } else {
      for (int i = 0; i < 8; i++) {
        final voice = voices[i];
        if (!voice.enabled) continue;

        // 1. Pitch Trajectory (Pitch Sweeps, Arpeggios, Vibrato)
        double curFreq = (baseFreq > 0 ? baseFreq : voice.basePitchHz) * voice.pitch;

        if (voice.sweepDuration > 0.001 && time < voice.sweepDuration) {
          final prog = (time / voice.sweepDuration).clamp(0.0, 1.0);
          final curve = voice.startFreqMult > voice.endFreqMult
              ? math.pow(1.0 - prog, 2.2).toDouble() // Fast downward snappy zap
              : math.pow(prog, 1.4).toDouble(); // Smooth upward scoop
          final mult = voice.endFreqMult + (voice.startFreqMult - voice.endFreqMult) * curve;
          curFreq *= mult;
        }

        if (voice.arpeggioNotes.isNotEmpty) {
          final arpIdx = (time / math.max(0.01, voice.arpeggioSpeed)).floor() % voice.arpeggioNotes.length;
          final semi = voice.arpeggioNotes[arpIdx];
          curFreq *= math.pow(2.0, semi / 12.0);
        }

        if (voice.vibratoDepth > 0.001 && voice.vibratoRate > 0.1) {
          final vib = math.sin(2.0 * math.pi * voice.vibratoRate * time) * (voice.vibratoDepth / 12.0);
          curFreq *= (1.0 + 0.693147 * vib);
        }

        // 2. Cross-Channel Pitch Modulation (PMOD from Voice n-1)
        if (voice.pmodEnabled && i > 0) {
          final pmodFactor = 1.0 + (prevVoiceOut * 1.5);
          curFreq *= math.max(0.05, pmodFactor);
        }

        // 3. Phase Accumulator
        voice.phase += (2.0 * math.pi * curFreq) / 44100.0;
        if (voice.phase >= 2.0 * math.pi) {
          voice.phase -= 2.0 * math.pi;
        }

        // 4. Envelope Generator
        final env = voice.evaluateEnvelope(time, duration);

        // 5. Wavetable or Noise Signal
        double rawSample = 0.0;
        if (voice.noiseEnabled || voice.waveform == SNESWaveform.noise) {
          rawSample = _stepNoise(voice.noiseRate);
        } else {
          rawSample = voice.evaluateWaveform(voice.phase);
        }

        // Blend optional noise mix
        if (voice.noiseMix > 0.001 && !voice.noiseEnabled) {
          final noise = _stepNoise(voice.noiseRate);
          rawSample = (rawSample * (1.0 - voice.noiseMix)) + (noise * voice.noiseMix);
        }

        final voiceOut = rawSample * env;
        voice.lastOutput = voiceOut;
        prevVoiceOut = voiceOut;

        // Stereo Distribution
        final vl = voiceOut * voice.volumeLeft;
        final vr = voiceOut * voice.volumeRight;

        dryLeft += vl;
        dryRight += vr;

        if (voice.echoEnabled) {
          echoLeft += vl;
          echoRight += vr;
        }
      }
    }

    // Process through 8-Tap FIR Echo Reverb
    final wetEcho = echo.processStereo(echoLeft, echoRight);

    final finalLeft = (dryLeft * 0.7 + wetEcho[0] * 0.3) * masterVolume;
    final finalRight = (dryRight * 0.7 + wetEcho[1] * 0.3) * masterVolume;

    _stereoResult[0] = finalLeft.clamp(-1.0, 1.0);
    _stereoResult[1] = finalRight.clamp(-1.0, 1.0);
    return _stereoResult;
  }

  /// Synthesizes complete Float32List mono audio buffer for a note.
  Float32List synthesizeBuffer({
    required double freq,
    required double durationSec,
    double volume = 0.85,
  }) {
    final numSamples = (44100 * durationSec).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);
    for (final v in voices) {
      v.phase = 0.0;
      v.lastOutput = 0.0;
    }

    for (int i = 0; i < numSamples; i++) {
      final time = i / 44100.0;
      final stereo = evaluateStereoSample(
        time: time,
        baseFreq: freq,
        duration: durationSec,
        sampleIndex: i,
      );
      // Mono mixdown
      buffer[i] = ((stereo[0] + stereo[1]) * 0.5 * volume).clamp(-1.0, 1.0);
    }

    return buffer;
  }
}

/// Procedural Sound Effect Generator Suite built on the SNES S-DSP / SPC700 architecture.
class SNESSFXRGenerator {
  /// Configures the S-DSP from a preset archetype index (0..8) with deterministic PRNG seed variation.
  static void configureFromType(SNESDSPEngine dsp, int sfxType, {int seed = 42}) {
    dsp.setSeed(seed);
    final prng = dsp.prng;

    switch (sfxType) {
      case 0: // Laser / Zap
        configureLaser(dsp, prng);
        break;
      case 1: // Explosion
        configureExplosion(dsp, prng);
        break;
      case 2: // Powerup / 1-Up
        configurePowerup(dsp, prng);
        break;
      case 3: // Coin
        configureCoin(dsp, prng);
        break;
      case 4: // Jump
        configureJump(dsp, prng);
        break;
      case 5: // Hurt / Damage
        configureHurt(dsp, prng);
        break;
      case 6: // Lose / Game Over
        configureLose(dsp, prng);
        break;
      case 7: // Button / Click / Beep
        configureButton(dsp, prng);
        break;
      case 8: // Warp / Teleport
        configureWarp(dsp, prng);
        break;
      case 9: // Mutate
        configureLaser(dsp, prng);
        mutate(dsp, prng);
        break;
      default:
        // Custom SNES preset
        break;
    }
  }

  /// Laser / Zap: Fast downward exponential pitch dive with S-DSP pulse wavetable.
  static void configureLaser(SNESDSPEngine dsp, [DeterministicPRNG? prng]) {
    dsp.reset();
    final v = dsp.voices[0];
    v.waveform = SNESWaveform.sawtooth;
    v.startFreqMult = prng != null ? prng.nextRange(2.6, 3.6) : 3.0;
    v.endFreqMult = prng != null ? prng.nextRange(0.1, 0.22) : 0.15;
    v.sweepDuration = prng != null ? prng.nextRange(0.10, 0.16) : 0.13;
    v.attack = 0.001;
    v.decay = prng != null ? prng.nextRange(0.10, 0.16) : 0.13;
    v.sustain = 0.0;
    v.release = 0.01;
    dsp.echo.enabled = false;
    dsp.echo.volume = 0.0;
  }

  /// Explosion: S-DSP hardware noise generator with exponential decay and deep FIR echo.
  static void configureExplosion(SNESDSPEngine dsp, [DeterministicPRNG? prng]) {
    dsp.reset();
    final v = dsp.voices[0];
    v.noiseEnabled = true;
    v.noiseRate = prng != null ? prng.nextInt(4, 9) : 6; // Deep crunchy noise
    v.startFreqMult = 1.4;
    v.endFreqMult = 0.2;
    v.sweepDuration = 0.4;
    v.envMode = SNESEnvelopeMode.gainExpDecrease;
    v.decay = prng != null ? prng.nextRange(0.35, 0.6) : 0.45;
    dsp.echo.enabled = true;
    dsp.echo.volume = 0.45;
    dsp.echo.delayMs = 160;
    dsp.echo.feedback = 0.55;
    dsp.echo.setFIRProfile('dark_hall');
  }

  /// Powerup / 1-Up: Rapid ascending major arpeggio with shimmering chime wavetable and lush reverb.
  static void configurePowerup(SNESDSPEngine dsp, [DeterministicPRNG? prng]) {
    dsp.reset();
    final v = dsp.voices[0];
    v.waveform = SNESWaveform.chime;
    v.arpeggioNotes = [0, 4, 7, 12, 16]; // Root, Major 3rd, 5th, Octave, 10th
    v.arpeggioSpeed = prng != null ? prng.nextRange(0.035, 0.055) : 0.045;
    v.attack = 0.002;
    v.decay = 0.35;
    v.sustain = 0.2;
    v.release = 0.25;
    dsp.echo.enabled = true;
    dsp.echo.volume = 0.5;
    dsp.echo.delayMs = 128;
    dsp.echo.feedback = 0.5;
    dsp.echo.setFIRProfile('surround_reverb');
  }

  /// Coin: Crisp dual-tone high bell chime with rapid decay.
  static void configureCoin(SNESDSPEngine dsp, [DeterministicPRNG? prng]) {
    dsp.reset();
    final v = dsp.voices[0];
    v.waveform = SNESWaveform.pulse25;
    v.arpeggioNotes = [0, 12]; // Octave jump
    v.arpeggioSpeed = 0.04;
    v.attack = 0.001;
    v.decay = prng != null ? prng.nextRange(0.18, 0.28) : 0.22;
    v.sustain = 0.0;
    v.release = 0.05;
    dsp.echo.enabled = false;
  }

  /// Jump / Bounce: Rubbery upward frequency scoop with SNES triangle wavetable.
  static void configureJump(SNESDSPEngine dsp, [DeterministicPRNG? prng]) {
    dsp.reset();
    final v = dsp.voices[0];
    v.waveform = SNESWaveform.triangle;
    v.startFreqMult = prng != null ? prng.nextRange(0.4, 0.55) : 0.45;
    v.endFreqMult = prng != null ? prng.nextRange(1.5, 1.9) : 1.7;
    v.sweepDuration = prng != null ? prng.nextRange(0.12, 0.20) : 0.16;
    v.attack = 0.002;
    v.decay = 0.18;
    v.sustain = 0.0;
    v.release = 0.02;
    dsp.echo.enabled = false;
    dsp.echo.volume = 0.0;
  }

  /// Hurt / Damage: Sharp downward crunch with noise modulation transient.
  static void configureHurt(SNESDSPEngine dsp, [DeterministicPRNG? prng]) {
    dsp.reset();
    final v1 = dsp.voices[0];
    v1.waveform = SNESWaveform.square;
    v1.startFreqMult = 1.8;
    v1.endFreqMult = 0.4;
    v1.sweepDuration = 0.09;
    v1.attack = 0.001;
    v1.decay = 0.12;
    v1.sustain = 0.0;
    v1.noiseMix = prng != null ? prng.nextRange(0.3, 0.6) : 0.45;
    dsp.echo.enabled = false;
  }

  /// Lose / Game Over: Descending sorrowful minor arpeggio with pitch wobble and dark reverb.
  static void configureLose(SNESDSPEngine dsp, [DeterministicPRNG? prng]) {
    dsp.reset();
    final v = dsp.voices[0];
    v.waveform = SNESWaveform.sawtooth;
    // Sad minor descent: Root -> Minor 3rd down -> 5th down -> Octave down
    v.arpeggioNotes = [0, -3, -7, -12];
    v.arpeggioSpeed = prng != null ? prng.nextRange(0.06, 0.09) : 0.075;
    v.vibratoRate = 6.5;
    v.vibratoDepth = 0.15; // Slow sorrowful pitch droop
    v.attack = 0.005;
    v.decay = 0.45;
    v.sustain = 0.1;
    v.release = 0.25;
    dsp.echo.enabled = true;
    dsp.echo.volume = 0.55;
    dsp.echo.delayMs = 180;
    dsp.echo.feedback = 0.6;
    dsp.echo.setFIRProfile('dark_hall');
  }

  /// Button / Click / Beep: Crisp 2-shot UI confirmation blip.
  static void configureButton(SNESDSPEngine dsp, [DeterministicPRNG? prng]) {
    dsp.reset();
    final v = dsp.voices[0];
    v.waveform = SNESWaveform.pulse25;
    final stepInterval = prng != null ? prng.nextRange(0.020, 0.026) : 0.024;
    v.arpeggioNotes = [0, 7]; // 2-shot blip: Root tone -> Fifth up
    v.arpeggioSpeed = stepInterval;
    v.startFreqMult = 1.0;
    v.endFreqMult = 1.15;
    v.sweepDuration = 0.05;
    v.attack = 0.0005;
    v.decay = 0.055;
    v.sustain = 0.0;
    v.release = 0.005;
    dsp.echo.enabled = false;
    dsp.echo.volume = 0.0;
  }

  /// Warp / Teleport: Rapid alternating pitch wobble with S-DSP echo.
  static void configureWarp(SNESDSPEngine dsp, [DeterministicPRNG? prng]) {
    dsp.reset();
    final v = dsp.voices[0];
    v.waveform = SNESWaveform.chime;
    v.vibratoRate = prng != null ? prng.nextRange(18.0, 28.0) : 22.0; // Fast alien wobble
    v.vibratoDepth = 0.4;
    v.attack = 0.01;
    v.decay = 0.35;
    v.sustain = 0.2;
    v.release = 0.2;
    dsp.echo.enabled = true;
    dsp.echo.volume = 0.4;
    dsp.echo.delayMs = 120;
    dsp.echo.setFIRProfile('metallic');
  }

  /// Mutates S-DSP voice parameters subtly within retro musical sweet spots.
  static void mutate(SNESDSPEngine dsp, [DeterministicPRNG? prng]) {
    final r = prng ?? dsp.prng;
    final v = dsp.voices[0];

    if (r.nextBool(0.6)) {
      final wIdx = r.nextInt(0, SNESWaveform.values.length - 1);
      v.waveform = SNESWaveform.values[wIdx];
    }
    if (r.nextBool(0.5)) {
      v.startFreqMult = (v.startFreqMult + r.nextRange(-0.4, 0.4)).clamp(0.2, 4.0);
    }
    if (r.nextBool(0.5)) {
      v.decay = (v.decay * r.nextRange(0.8, 1.3)).clamp(0.02, 2.0);
    }
    if (r.nextBool(0.4)) {
      dsp.echo.feedback = (dsp.echo.feedback + r.nextRange(-0.15, 0.15)).clamp(0.0, 0.85);
    }
  }

  /// Returns the curated list of suitable SNES BRR wavetables for each SFX archetype.
  static List<SNESWaveform> getCandidateWaveformsForType(int sfxType) {
    switch (sfxType) {
      case 0: // Laser / Zap
        return const [
          SNESWaveform.sawtooth,
          SNESWaveform.pulse12,
          SNESWaveform.pulse25,
          SNESWaveform.square,
          SNESWaveform.sine,
          SNESWaveform.triangle,
        ];
      case 1: // Explosion
        return const [
          SNESWaveform.noise,
          SNESWaveform.triangle,
          SNESWaveform.square,
          SNESWaveform.sawtooth,
          SNESWaveform.slapBass,
        ];
      case 2: // Powerup / 1-Up
        return const [
          SNESWaveform.chime,
          SNESWaveform.sine,
          SNESWaveform.triangle,
          SNESWaveform.flute,
          SNESWaveform.square,
          SNESWaveform.pulse25,
          SNESWaveform.organ,
        ];
      case 3: // Coin
        return const [
          SNESWaveform.pulse25,
          SNESWaveform.pulse12,
          SNESWaveform.chime,
          SNESWaveform.sine,
          SNESWaveform.triangle,
          SNESWaveform.square,
        ];
      case 4: // Jump
        return const [
          SNESWaveform.triangle,
          SNESWaveform.square,
          SNESWaveform.pulse25,
          SNESWaveform.pulse12,
          SNESWaveform.sine,
          SNESWaveform.slapBass,
        ];
      case 5: // Hurt / Damage
        return const [
          SNESWaveform.square,
          SNESWaveform.noise,
          SNESWaveform.sawtooth,
          SNESWaveform.triangle,
          SNESWaveform.pulse12,
          SNESWaveform.slapBass,
        ];
      case 6: // Lose / Game Over
        return const [
          SNESWaveform.sawtooth,
          SNESWaveform.triangle,
          SNESWaveform.organ,
          SNESWaveform.slapBass,
          SNESWaveform.noise,
          SNESWaveform.strings,
        ];
      case 7: // Button / Click / Beep
        return const [
          SNESWaveform.pulse25,
          SNESWaveform.pulse12,
          SNESWaveform.sine,
          SNESWaveform.triangle,
          SNESWaveform.square,
          SNESWaveform.chime,
        ];
      case 8: // Warp / Teleport
        return const [
          SNESWaveform.chime,
          SNESWaveform.organ,
          SNESWaveform.strings,
          SNESWaveform.flute,
          SNESWaveform.sine,
          SNESWaveform.triangle,
        ];
      default: // Mutate (9) / Custom SNES (10)
        return SNESWaveform.values;
    }
  }

  /// Generates a complete parameter map corresponding to a specific archetype and seed.
  static Map<String, double> generateParamsForType(int sfxType, {int seed = 42}) {
    final prng = DeterministicPRNG(seed);
    final candidates = getCandidateWaveformsForType(sfxType);
    final chosenWaveform = candidates[prng.nextInt(0, candidates.length - 1)];

    final map = <String, double>{
      'SFXType': sfxType.toDouble(),
      'Seed': seed.toDouble(),
      'Waveform': chosenWaveform.index.toDouble(),
      'Attack': 0.005,
      'Decay': 0.25,
      'Sustain': 0.1,
      'Release': 0.2,
      'PitchSweep': 0.0,
      'SweepSpeed': 0.16,
      'VibratoRate': 0.0,
      'VibratoDepth': 0.0,
      'ArpSpeed': 0.05,
      'EchoDelay': 120.0,
      'EchoFeedback': 0.45,
      'EchoVolume': 0.0,
      'NoiseMix': 0.0,
    };

    switch (sfxType) {
      case 0: // Laser / Zap
        map['Attack'] = 0.001;
        map['Decay'] = prng.nextRange(0.08, 0.16);
        map['Sustain'] = 0.0;
        map['Release'] = 0.02;
        map['PitchSweep'] = prng.nextRange(-1.8, -0.9);
        map['SweepSpeed'] = prng.nextRange(0.08, 0.15);
        map['EchoVolume'] = 0.0;
        break;
      case 1: // Explosion
        map['Attack'] = 0.002;
        map['Decay'] = prng.nextRange(0.35, 0.65);
        map['Sustain'] = 0.0;
        map['Release'] = 0.15;
        map['PitchSweep'] = prng.nextRange(-1.2, -0.4);
        map['NoiseMix'] = chosenWaveform == SNESWaveform.noise ? 1.0 : prng.nextRange(0.4, 0.85);
        map['EchoDelay'] = 160.0;
        map['EchoFeedback'] = 0.55;
        map['EchoVolume'] = 0.45;
        break;
      case 2: // Powerup / 1-Up
        map['Attack'] = 0.002;
        map['Decay'] = prng.nextRange(0.28, 0.42);
        map['Sustain'] = 0.2;
        map['Release'] = 0.25;
        map['ArpSpeed'] = prng.nextRange(0.035, 0.055);
        map['EchoDelay'] = 128.0;
        map['EchoFeedback'] = 0.5;
        map['EchoVolume'] = 0.5;
        break;
      case 3: // Coin
        map['Attack'] = 0.001;
        map['Decay'] = prng.nextRange(0.16, 0.26);
        map['Sustain'] = 0.0;
        map['Release'] = 0.05;
        map['ArpSpeed'] = 0.04;
        map['EchoVolume'] = 0.0;
        break;
      case 4: // Jump
        map['Attack'] = 0.002;
        map['Decay'] = prng.nextRange(0.14, 0.22);
        map['Sustain'] = 0.0;
        map['Release'] = 0.02;
        map['PitchSweep'] = prng.nextRange(0.6, 1.4);
        map['SweepSpeed'] = prng.nextRange(0.12, 0.20);
        map['EchoVolume'] = 0.0;
        break;
      case 5: // Hurt / Damage
        map['Attack'] = 0.001;
        map['Decay'] = prng.nextRange(0.09, 0.16);
        map['Sustain'] = 0.0;
        map['Release'] = 0.02;
        map['PitchSweep'] = prng.nextRange(-1.4, -0.6);
        map['NoiseMix'] = prng.nextRange(0.3, 0.6);
        map['EchoVolume'] = 0.0;
        break;
      case 6: // Lose / Game Over
        map['Attack'] = 0.005;
        map['Decay'] = prng.nextRange(0.38, 0.55);
        map['Sustain'] = 0.1;
        map['Release'] = 0.25;
        map['VibratoRate'] = 6.5;
        map['VibratoDepth'] = prng.nextRange(0.1, 0.25);
        map['ArpSpeed'] = prng.nextRange(0.06, 0.09);
        map['EchoDelay'] = 180.0;
        map['EchoFeedback'] = 0.6;
        map['EchoVolume'] = 0.55;
        break;
      case 7: // Button / Click / Beep
        map['Attack'] = 0.0005;
        map['Decay'] = prng.nextRange(0.04, 0.07);
        map['Sustain'] = 0.0;
        map['Release'] = 0.005;
        map['ArpSpeed'] = prng.nextRange(0.020, 0.026);
        map['EchoVolume'] = 0.0;
        break;
      case 8: // Warp / Teleport
        map['Attack'] = 0.01;
        map['Decay'] = prng.nextRange(0.28, 0.42);
        map['Sustain'] = 0.2;
        map['Release'] = 0.2;
        map['VibratoRate'] = prng.nextRange(18.0, 28.0);
        map['VibratoDepth'] = 0.4;
        map['EchoDelay'] = 120.0;
        map['EchoFeedback'] = 0.5;
        map['EchoVolume'] = 0.4;
        break;
      case 9: // Mutate
        final base = generateParamsForType(prng.nextInt(0, 8), seed: seed);
        final mutated = mutateParams(base, seed: seed + 1);
        mutated['SFXType'] = 9.0;
        mutated['Seed'] = seed.toDouble();
        return mutated;
      default: // Custom SNES
        map['Waveform'] = chosenWaveform.index.toDouble();
        map['Attack'] = prng.nextRange(0.001, 0.2);
        map['Decay'] = prng.nextRange(0.05, 1.0);
        map['Sustain'] = prng.nextRange(0.0, 0.8);
        map['Release'] = prng.nextRange(0.05, 0.8);
        map['PitchSweep'] = prng.nextRange(-1.5, 1.5);
        map['EchoVolume'] = prng.nextRange(0.0, 0.6);
        break;
    }
    return map;
  }

  /// Mutates a parameter dictionary subtly within retro sweet spots.
  static Map<String, double> mutateParams(Map<String, double> currentParams, {int seed = 42}) {
    final prng = DeterministicPRNG(seed);
    final mutated = Map<String, double>.from(currentParams);

    if (prng.nextBool(0.6)) {
      mutated['Waveform'] = prng.nextInt(0, SNESWaveform.values.length - 1).toDouble();
    }
    if (mutated.containsKey('Attack') && prng.nextBool(0.5)) {
      mutated['Attack'] = (mutated['Attack']! * prng.nextRange(0.7, 1.4)).clamp(0.001, 0.5);
    }
    if (mutated.containsKey('Decay') && prng.nextBool(0.5)) {
      mutated['Decay'] = (mutated['Decay']! * prng.nextRange(0.7, 1.4)).clamp(0.01, 2.0);
    }
    if (mutated.containsKey('PitchSweep') && prng.nextBool(0.5)) {
      mutated['PitchSweep'] = (mutated['PitchSweep']! + prng.nextRange(-0.4, 0.4)).clamp(-2.0, 2.0);
    }
    if (mutated.containsKey('EchoVolume') && prng.nextBool(0.4)) {
      mutated['EchoVolume'] = (mutated['EchoVolume']! + prng.nextRange(-0.2, 0.2)).clamp(0.0, 1.0);
    }
    if (mutated.containsKey('EchoDelay') && prng.nextBool(0.3)) {
      mutated['EchoDelay'] = (mutated['EchoDelay']! + prng.nextInt(-32, 32)).clamp(16.0, 480.0);
    }
    mutated['Seed'] = seed.toDouble();
    return mutated;
  }
}

/// Pure-Dart DSP Synthesis Engine for the 16-Bit S-DSP Console Drum Kit (Notes 35–81).
///
/// Synthesizes authentic retro drum sounds on the Sony SPC700 / S-DSP architecture:
/// - Kick Drums (35, 36): Rapid downward pitch sweep on low-frequency Triangle / Sine with transient click.
/// - Snare Drums (38, 40): Tuned resonant pulse body + 15-bit S-DSP LFSR noise burst.
/// - Side Stick & Rimshot (37): High-tuned wood click with fast decay.
/// - Hand Clap (39): Multi-impulse staggered noise strikes.
/// - Hi-Hats (42 Closed, 44 Pedal, 46 Open): High-clock LFSR noise with ADSR shaping.
/// - Toms (41, 43, 45, 47, 48, 50): Pitched downward sweeps across 6 GM tom registers.
/// - Cymbals (49/57 Crash, 51/59 Ride, 52/55 Splash/China): Metallic inharmonic chime wave + filtered noise wash + FIR echo.
/// - Percussion (54 Tambourine, 56 Cowbell, 58 Vibraslap, 75 Claves, 76/77 Woodblocks, 80/81 Triangles): Dual-pulse intervals and retro metallic chimes.
class SNESDrumKitEngine {
  /// Synthesizes a mono Float32List audio buffer for a given General MIDI [note] (35–81).
  static Float32List synthesizeBuffer({
    required int note,
    required double durationSec,
    double velocity = 0.9,
    Map<String, double>? params,
    bool isAccent = false,
  }) {
    final double vel = (isAccent ? 1.0 : velocity).clamp(0.05, 1.0);
    final double tune = params?['MasterTune'] ?? 0.0;
    final double pitchMult = math.pow(2.0, tune / 12.0).toDouble();

    final double kickPunch = params?['KickPunch'] ?? 130.0;
    final double snareNoise = params?['SnareNoise'] ?? 0.65;
    final double tomDecayMult = params?['TomDecay'] ?? 0.35;
    final double cymbalDecayMult = params?['CymbalDecay'] ?? 0.80;
    final double warmth = params?['GaussianWarmth'] ?? 0.70;

    final double echoDelay = params?['EchoDelay'] ?? 128.0;
    final double echoFeedback = params?['EchoFeedback'] ?? 0.35;
    final double echoVolume = params?['EchoVolume'] ?? 0.25;

    // Allocate S-DSP engine for this drum hit
    final dsp = SNESDSPEngine(seed: 42 + note);
    dsp.masterVolume = 0.95;
    dsp.echo.enabled = echoVolume > 0.01;
    dsp.echo.delayMs = echoDelay.toInt().clamp(16, 480);
    dsp.echo.feedback = echoFeedback.clamp(0.0, 0.95);
    dsp.echo.volume = echoVolume.clamp(0.0, 1.0);

    double soundDuration = 0.25;
    final v0 = dsp.voices[0];
    final v1 = dsp.voices[1];
    v1.enabled = false;

    switch (note) {
      // 1. Kick Drums (Acoustic 35, Electric/Standard 36)
      case 35:
      case 36:
        soundDuration = 0.22;
        v0.waveform = SNESWaveform.triangle;
        v0.basePitchHz = (note == 35 ? 46.0 : 52.0) * pitchMult;
        v0.startFreqMult = (kickPunch / v0.basePitchHz).clamp(1.5, 4.5);
        v0.endFreqMult = 0.75;
        v0.sweepDuration = 0.075;
        v0.attack = 0.0005;
        v0.decay = 0.16;
        v0.sustain = 0.0;
        v0.release = 0.02;
        v0.noiseMix = 0.06; // Subtle click transient
        dsp.echo.enabled = false; // Keep kick punchy & dry
        break;

      // 2. Snare Drums (Acoustic 38, Electric 40)
      case 38:
      case 40:
        soundDuration = 0.26;
        // Voice 0: Tone body (Pulse 25%)
        v0.waveform = SNESWaveform.pulse25;
        v0.basePitchHz = (note == 38 ? 185.0 : 210.0) * pitchMult;
        v0.startFreqMult = 1.4;
        v0.endFreqMult = 0.85;
        v0.sweepDuration = 0.04;
        v0.attack = 0.0005;
        v0.decay = 0.12;
        v0.sustain = 0.0;
        v0.release = 0.02;
        v0.volumeLeft = 0.6;
        v0.volumeRight = 0.6;

        // Voice 1: Crunchy LFSR noise snare wires
        v1.enabled = true;
        v1.noiseEnabled = true;
        v1.noiseRate = 9; // Authentic mid-range crunch
        v1.attack = 0.001;
        v1.decay = (0.16 * (0.5 + snareNoise * 0.7)).clamp(0.06, 0.35);
        v1.sustain = 0.0;
        v1.release = 0.03;
        v1.volumeLeft = 0.7 * snareNoise;
        v1.volumeRight = 0.7 * snareNoise;
        dsp.echo.volume = echoVolume * 0.5;
        break;

      // 3. Side Stick / Rimshot (37)
      case 37:
        soundDuration = 0.08;
        v0.waveform = SNESWaveform.pulse12;
        v0.basePitchHz = 420.0 * pitchMult;
        v0.startFreqMult = 1.5;
        v0.endFreqMult = 0.8;
        v0.sweepDuration = 0.015;
        v0.attack = 0.0002;
        v0.decay = 0.045;
        v0.sustain = 0.0;
        v0.release = 0.01;
        v0.noiseMix = 0.15;
        dsp.echo.enabled = false;
        break;

      // 4. Hand Clap (39)
      case 39:
        soundDuration = 0.30;
        v0.waveform = SNESWaveform.noise;
        v0.noiseEnabled = true;
        v0.noiseRate = 11;
        v0.arpeggioNotes = [0, 4, 7]; // Staggered transient
        v0.arpeggioSpeed = 0.018;
        v0.attack = 0.001;
        v0.decay = 0.18;
        v0.sustain = 0.0;
        v0.release = 0.04;
        dsp.echo.setFIRProfile('slapback');
        dsp.echo.volume = math.max(0.2, echoVolume);
        break;

      // 5. Closed Hi-Hat (42) & Pedal Hi-Hat (44)
      case 42:
      case 44:
        soundDuration = 0.09;
        v0.waveform = SNESWaveform.noise;
        v0.noiseEnabled = true;
        v0.noiseRate = 13; // Crisp high-frequency sizzle
        v0.attack = 0.0005;
        v0.decay = (note == 42 ? 0.038 : 0.048) * cymbalDecayMult;
        v0.sustain = 0.0;
        v0.release = 0.01;
        dsp.echo.enabled = false;
        break;

      // 6. Open Hi-Hat (46)
      case 46:
        soundDuration = 0.45;
        v0.waveform = SNESWaveform.noise;
        v0.noiseEnabled = true;
        v0.noiseRate = 12;
        v0.attack = 0.001;
        v0.decay = (0.28 * cymbalDecayMult).clamp(0.08, 0.8);
        v0.sustain = 0.0;
        v0.release = 0.05;
        dsp.echo.volume = echoVolume * 0.4;
        break;

      // 7. Toms (41 Floor Low, 43 Floor High, 45 Low, 47 Low-Mid, 48 Hi-Mid, 50 High)
      case 41:
      case 43:
      case 45:
      case 47:
      case 48:
      case 50:
        final tomPitches = {41: 75.0, 43: 95.0, 45: 120.0, 47: 150.0, 48: 185.0, 50: 230.0};
        final baseTomHz = (tomPitches[note] ?? 130.0) * pitchMult;
        soundDuration = (0.35 * tomDecayMult).clamp(0.12, 0.7);
        v0.waveform = SNESWaveform.triangle;
        v0.basePitchHz = baseTomHz;
        v0.startFreqMult = 1.6;
        v0.endFreqMult = 0.9;
        v0.sweepDuration = 0.06;
        v0.attack = 0.001;
        v0.decay = soundDuration * 0.85;
        v0.sustain = 0.0;
        v0.release = 0.03;
        v0.noiseMix = 0.08;
        dsp.echo.setFIRProfile('surround_reverb');
        dsp.echo.volume = echoVolume * 0.4;
        break;

      // 8. Crash Cymbals (Crash 1: 49, Splash: 55, Crash 2: 57, China: 52)
      case 49:
      case 52:
      case 55:
      case 57:
        soundDuration = (0.9 * cymbalDecayMult).clamp(0.3, 2.0);
        // Voice 0: Inharmonic Chime wavetable ring
        v0.waveform = SNESWaveform.chime;
        v0.basePitchHz = (note == 55 ? 580.0 : 440.0) * pitchMult;
        v0.attack = 0.001;
        v0.decay = soundDuration * 0.6;
        v0.sustain = 0.0;
        v0.release = 0.1;
        v0.volumeLeft = 0.55;
        v0.volumeRight = 0.55;

        // Voice 1: Shimmering noise wash
        v1.enabled = true;
        v1.noiseEnabled = true;
        v1.noiseRate = 12;
        v1.attack = 0.002;
        v1.decay = soundDuration * 0.8;
        v1.sustain = 0.0;
        v1.release = 0.15;
        v1.volumeLeft = 0.65;
        v1.volumeRight = 0.65;

        dsp.echo.setFIRProfile('dark_hall');
        dsp.echo.volume = math.max(0.35, echoVolume);
        dsp.echo.delayMs = 160;
        break;

      // 9. Ride Cymbals (Ride 1: 51, Ride Bell: 53, Ride 2: 59)
      case 51:
      case 53:
      case 59:
        soundDuration = (0.55 * cymbalDecayMult).clamp(0.2, 1.2);
        v0.waveform = SNESWaveform.chime;
        v0.basePitchHz = (note == 53 ? 620.0 : 490.0) * pitchMult;
        v0.attack = 0.0005;
        v0.decay = soundDuration * 0.7;
        v0.sustain = 0.0;
        v0.release = 0.08;
        v0.noiseMix = 0.22;
        dsp.echo.volume = echoVolume * 0.35;
        break;

      // 10. Tambourine (54) & Shakers / Maracas (69, 70)
      case 54:
      case 69:
      case 70:
        soundDuration = 0.14;
        v0.waveform = SNESWaveform.noise;
        v0.noiseEnabled = true;
        v0.noiseRate = 14;
        v0.arpeggioNotes = [0, 5];
        v0.arpeggioSpeed = 0.022;
        v0.attack = 0.001;
        v0.decay = 0.08;
        v0.sustain = 0.0;
        v0.release = 0.02;
        dsp.echo.volume = echoVolume * 0.3;
        break;

      // 11. Cowbell (56)
      case 56:
        soundDuration = 0.22;
        v0.waveform = SNESWaveform.pulse12;
        v0.basePitchHz = 560.0 * pitchMult;
        v0.attack = 0.0005;
        v0.decay = 0.14;
        v0.sustain = 0.0;
        v0.release = 0.02;

        v1.enabled = true;
        v1.waveform = SNESWaveform.pulse25;
        v1.basePitchHz = 840.0 * pitchMult;
        v1.attack = 0.0005;
        v1.decay = 0.09;
        v1.sustain = 0.0;
        v1.release = 0.02;
        v1.volumeLeft = 0.6;
        v1.volumeRight = 0.6;
        dsp.echo.volume = echoVolume * 0.25;
        break;

      // 12. Claves (75) & Woodblocks (76 Hi, 77 Low)
      case 75:
      case 76:
      case 77:
        soundDuration = 0.09;
        v0.waveform = SNESWaveform.triangle;
        v0.basePitchHz = (note == 75 ? 980.0 : (note == 76 ? 740.0 : 540.0)) * pitchMult;
        v0.attack = 0.0002;
        v0.decay = 0.055;
        v0.sustain = 0.0;
        v0.release = 0.01;
        v0.noiseMix = 0.12;
        dsp.echo.enabled = false;
        break;

      // 13. Triangles (Open 80, Mute 81)
      case 80:
      case 81:
        soundDuration = note == 80 ? 0.6 : 0.06;
        v0.waveform = SNESWaveform.sine;
        v0.basePitchHz = 1480.0 * pitchMult;
        v0.attack = 0.0005;
        v0.decay = soundDuration * 0.8;
        v0.sustain = 0.0;
        v0.release = 0.04;

        v1.enabled = true;
        v1.waveform = SNESWaveform.chime;
        v1.basePitchHz = 2960.0 * pitchMult;
        v1.attack = 0.0005;
        v1.decay = soundDuration * 0.4;
        v1.sustain = 0.0;
        v1.release = 0.02;
        v1.volumeLeft = 0.4;
        v1.volumeRight = 0.4;
        dsp.echo.volume = echoVolume * 0.4;
        break;

      default:
        // Generic S-DSP Percussion Transient
        soundDuration = 0.18;
        v0.waveform = SNESWaveform.triangle;
        v0.basePitchHz = (120.0 + (note % 24) * 15.0) * pitchMult;
        v0.startFreqMult = 1.3;
        v0.endFreqMult = 0.8;
        v0.sweepDuration = 0.04;
        v0.attack = 0.001;
        v0.decay = 0.12;
        v0.sustain = 0.0;
        v0.release = 0.02;
        v0.noiseMix = 0.25;
        break;
    }

    final int numSamples = (44100 * soundDuration).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);

    for (final v in dsp.voices) {
      v.phase = 0.0;
      v.lastOutput = 0.0;
    }

    for (int i = 0; i < numSamples; i++) {
      final t = i / 44100.0;
      final stereo = dsp.evaluateStereoSample(
        time: t,
        baseFreq: v0.basePitchHz,
        duration: soundDuration,
        sampleIndex: i,
      );
      // Mono mixdown with velocity
      buffer[i] = ((stereo[0] + stereo[1]) * 0.5 * vel).clamp(-1.0, 1.0);
    }

    // Apply optional 4-point Gaussian warmth roll-off
    if (warmth > 0.05) {
      _applyGaussianWarmth(buffer, warmth);
    }

    return buffer;
  }

  /// 4-point Gaussian FIR smoothing kernel [0.0625, 0.4375, 0.4375, 0.0625]
  static void _applyGaussianWarmth(Float32List buffer, double intensity) {
    if (buffer.length < 4) return;
    final kAmount = intensity.clamp(0.0, 1.0);
    double s0 = buffer[0], s1 = buffer[0], s2 = buffer[1], s3 = buffer[2];
    for (int i = 0; i < buffer.length - 3; i++) {
      s0 = s1;
      s1 = s2;
      s2 = s3;
      s3 = buffer[i + 3];
      final smoothed = s0 * 0.0625 + s1 * 0.4375 + s2 * 0.4375 + s3 * 0.0625;
      buffer[i] = buffer[i] * (1.0 - kAmount) + smoothed * kAmount;
    }
  }
}

/// Pure-Dart DSP Engine for the SNES Downsampler / BRR Audio Degrader.
///
/// Accurately emulates SPC700 hardware characteristics:
/// - Selectable sample rates: 32 kHz, 22.05 kHz, 16 kHz, 11.025 kHz, 8 kHz.
/// - 4-bit BRR block non-linear delta quantization.
/// - 4-point Gaussian low-pass smoothing ("The SNES Blanket").
class SNESDownsamplerEngine {
  static const List<double> supportedRates = [
    32000.0, // 0: Native SPC700 DAC
    22050.0, // 1: Hi-Fi SNES sample
    16000.0, // 2: Standard SNES sample
    11025.0, // 3: Budget SNES rhythm/bass
    8000.0,  // 4: Lo-Fi voice/SFX
  ];

  /// Processes an audio buffer in-place.
  static void processBuffer(
    Float32List buffer, {
    int rateIndex = 2,
    double brrBits = 4.0,
    double gaussianFilter = 0.85,
    double drive = 1.0,
    double mix = 1.0,
    int hostSampleRate = 44100,
  }) {
    if (buffer.isEmpty) return;
    final rIdx = rateIndex.clamp(0, supportedRates.length - 1);
    final targetRate = supportedRates[rIdx];
    final double stepInterval = hostSampleRate / targetRate;
    final int stepInt = math.max(1, stepInterval.round());

    final double bits = brrBits.clamp(2.0, 8.0);
    final double steps = math.pow(2.0, bits).toDouble();
    final double drv = drive.clamp(0.5, 4.0);
    final double kMix = mix.clamp(0.0, 1.0);
    final double gFilter = gaussianFilter.clamp(0.0, 1.0);

    final dry = Float32List.fromList(buffer);
    double heldSample = 0.0;

    // 1. Pre-drive, sample-and-hold downsampling, and non-linear BRR quantization
    for (int i = 0; i < buffer.length; i++) {
      if (i % stepInt == 0) {
        final driven = (dry[i] * drv).clamp(-1.5, 1.5);
        // Non-linear companding resembling 4-bit BRR block ADPCM range scaling
        final companded = math.sin(driven.clamp(-1.0, 1.0) * (math.pi * 0.5));
        heldSample = (companded * steps).roundToDouble() / steps;
      }
      buffer[i] = heldSample;
    }

    // 2. Hardware 4-point Gaussian filter smoothing kernel
    if (gFilter > 0.01 && buffer.length > 4) {
      double s0 = buffer[0], s1 = buffer[0], s2 = buffer[1], s3 = buffer[2];
      for (int i = 0; i < buffer.length - 3; i++) {
        s0 = s1;
        s1 = s2;
        s2 = s3;
        s3 = buffer[i + 3];
        final smoothed = s0 * 0.0625 + s1 * 0.4375 + s2 * 0.4375 + s3 * 0.0625;
        buffer[i] = buffer[i] * (1.0 - gFilter) + smoothed * gFilter;
      }
    }

    // 3. Dry/Wet Mix
    if (kMix < 0.999) {
      for (int i = 0; i < buffer.length; i++) {
        buffer[i] = dry[i] * (1.0 - kMix) + buffer[i] * kMix;
      }
    }
  }

  /// Evaluates single sample for real-time streaming FX.
  static double evaluateSample({
    required double inputSample,
    required double time,
    required Map<String, double> params,
    int hostSampleRate = 44100,
  }) {
    final rawRateIdx = (params['SampleRate'] ?? 2.0).toInt().clamp(0, supportedRates.length - 1);
    final targetRate = supportedRates[rawRateIdx];
    final double stepInterval = hostSampleRate / targetRate;

    final double bits = (params['BRRBits'] ?? 4.0).clamp(2.0, 8.0);
    final double steps = math.pow(2.0, bits).toDouble();
    final double drv = (params['Drive'] ?? 1.0).clamp(0.5, 4.0);
    final double mix = (params['Mix'] ?? 1.0).clamp(0.0, 1.0);
    final double gFilter = (params['GaussianFilter'] ?? 0.85).clamp(0.0, 1.0);

    final driven = (inputSample * drv).clamp(-1.5, 1.5);
    final companded = math.sin(driven.clamp(-1.0, 1.0) * (math.pi * 0.5));
    final quantized = (companded * steps).roundToDouble() / steps;

    // Simulate S-DSP sample hold & Gaussian smoothing
    final samplePos = (time * hostSampleRate) % stepInterval;
    final holdSample = samplePos < 1.0 ? quantized : quantized * (1.0 - gFilter * 0.1);

    return (inputSample * (1.0 - mix)) + (holdSample * mix);
  }
}

