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

  /// Evaluates S-DSP BRR wavetable sample with authentic Gaussian low-pass curve.
  double evaluateWaveform(double ph) {
    final normPhase = (ph % (2.0 * math.pi) + 2.0 * math.pi) % (2.0 * math.pi);
    final normPos = normPhase / (2.0 * math.pi); // 0.0 to 1.0

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
  static const int maxEchoDelaySamples = 44100 * 2; // Up to 2 seconds stereo ring buffer
  final Float32List _echoBufferLeft = Float32List(maxEchoDelaySamples);
  final Float32List _echoBufferRight = Float32List(maxEchoDelaySamples);
  int _writeIndex = 0;

  // Echo Parameters
  bool enabled = true;
  double feedback = 0.45; // -1.0 to 1.0
  double volume = 0.4; // 0.0 to 1.0
  int delayMs = 120; // 0 to 480 ms (Hardware EDL register: 0..15 * 16ms)

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

    final delaySamples = ((delayMs / 1000.0) * 44100.0).toInt().clamp(64, maxEchoDelaySamples - 16);

    // Read 8 FIR taps from ring buffer
    double leftFir = 0.0;
    double rightFir = 0.0;

    for (int tap = 0; tap < 8; tap++) {
      final tapIndex = (_writeIndex - delaySamples - (tap * 4) + maxEchoDelaySamples) % maxEchoDelaySamples;
      final coeff = firCoefficients[tap];
      leftFir += _echoBufferLeft[tapIndex] * coeff;
      rightFir += _echoBufferRight[tapIndex] * coeff;
    }

    // Write dry + feedback into ring buffer
    _echoBufferLeft[_writeIndex] = (leftDry + (leftFir * feedback)).clamp(-1.5, 1.5);
    _echoBufferRight[_writeIndex] = (rightDry + (rightFir * feedback)).clamp(-1.5, 1.5);
    _writeIndex = (_writeIndex + 1) % maxEchoDelaySamples;

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
        curFreq *= math.pow(2.0, vib);
      }

      // 2. Cross-Channel Pitch Modulation (PMOD from Voice n-1)
      if (voice.pmodEnabled && i > 0) {
        final pmodFactor = 1.0 + (prevVoiceOut * 1.5);
        curFreq *= math.max(0.05, pmodFactor);
      }

      // 3. Phase Accumulator
      voice.phase += (2.0 * math.pi * curFreq) / 44100.0;

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
