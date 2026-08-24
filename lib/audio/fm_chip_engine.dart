import 'dart:math' as math;
import 'dart:typed_data';

/// Operator Waveforms supported across OPN2 (sine) and OPL3 / SFXR extended modes.
enum FMWaveform {
  sine,
  square,
  saw,
  triangle,
  halfSine,
  absSine,
  noise,
}

/// Fast, deterministic pseudo-random number generator (Mulberry32).
/// Used for reproducible SFXR seeds, noise sequences, and procedural sound mutations.
class DeterministicPRNG {
  int _state;

  DeterministicPRNG(int seed) : _state = (seed <= 0 ? 42 : seed) & 0xFFFFFFFF;

  /// Resets generator to a new seed.
  void seed(int newSeed) {
    _state = (newSeed <= 0 ? 42 : newSeed) & 0xFFFFFFFF;
  }

  /// Returns pseudo-random double in range [0.0, 1.0)
  double nextDouble() {
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (_state & 0x7FFFFFFF) / 2147483648.0;
  }

  /// Returns random int in range [min, max] inclusive
  int nextInt(int min, int max) {
    if (max <= min) return min;
    return min + (nextDouble() * (max - min + 1)).floor();
  }

  /// Returns random double in range [min, max]
  double nextRange(double min, double max) {
    return min + nextDouble() * (max - min);
  }

  /// Returns boolean with given probability of true (default 0.5)
  bool nextBool([double chance = 0.5]) {
    return nextDouble() < chance;
  }
}

/// Represents one operator in a 4-operator FM sound chip (YM2612 / OPN2 / OPL3).
class FMOperator {
  double multiplier = 1.0; // Frequency multiplier (0.5, 1.0..15.0)
  double _totalLevel = 0.0;
  double _tlAtten = 1.0; // Cached linear attenuation

  double get totalLevel => _totalLevel;
  set totalLevel(double value) {
    _totalLevel = value;
    _tlAtten = math.pow(10.0, -(value.clamp(0.0, 127.0) * 0.75) / 20.0).toDouble();
  }

  double attack = 0.005; // Attack time in seconds
  double decay = 0.3; // Decay time in seconds
  double sustain = 0.6; // Sustain gain level (0.0 to 1.0)
  double release = 0.4; // Release time in seconds
  double detune = 0.0; // Pitch detune in Hz
  FMWaveform waveform = FMWaveform.sine; // Oscillator waveform

  // DSP state
  double phase = 0.0;
  double lastOutput = 0.0;
  double prevOutput = 0.0; // For feedback averaging

  FMOperator({
    this.multiplier = 1.0,
    double totalLevel = 0.0,
    this.attack = 0.005,
    this.decay = 0.3,
    this.sustain = 0.6,
    this.release = 0.4,
    this.detune = 0.0,
    this.waveform = FMWaveform.sine,
  }) {
    this.totalLevel = totalLevel;
  }

  /// Evaluates operator envelope gain (0.0 to 1.0) taking Total Level into account.
  double evaluateEnvelope(double time, double duration) {
    final a = math.max(0.0001, attack);
    final d = math.max(0.001, decay);
    final s = sustain.clamp(0.0, 1.0);
    final r = math.max(0.001, release);
    final gate = math.max(a + d, duration);

    double env;
    if (time < a) {
      env = (time / a).clamp(0.0, 1.0);
    } else if (time < a + d) {
      final decayProgress = (time - a) / d;
      env = 1.0 - (decayProgress * (1.0 - s));
    } else if (time < gate) {
      env = s;
    } else {
      final releaseProgress = (time - gate) / r;
      env = (s * math.max(0.0, 1.0 - releaseProgress)).clamp(0.0, 1.0);
    }

    return (env * _tlAtten).toDouble();
  }

  /// Evaluates the oscillator output waveform for the given phase.
  double evaluateWaveform(double ph) {
    final normPhase = ph % (2.0 * math.pi);
    switch (waveform) {
      case FMWaveform.square:
        return math.sin(ph) >= 0.0 ? 1.0 : -1.0;
      case FMWaveform.triangle:
        return (2.0 / math.pi) * math.asin(math.sin(ph).clamp(-1.0, 1.0));
      case FMWaveform.saw:
        return 2.0 * (normPhase / (2.0 * math.pi)) - 1.0;
      case FMWaveform.halfSine:
        final s = math.sin(ph);
        return s > 0.0 ? s : 0.0;
      case FMWaveform.absSine:
        return math.sin(ph).abs();
      case FMWaveform.noise:
      case FMWaveform.sine:
      default:
        return math.sin(ph);
    }
  }

  void reset() {
    phase = 0.0;
    lastOutput = 0.0;
    prevOutput = 0.0;
    waveform = FMWaveform.sine;
  }
}

/// High-accuracy 4-Operator Hardware FM Sound Engine (Modelled after YM2612 & YMF262/OPL3).
class FMChipVoice {
  final List<FMOperator> operators = List.generate(4, (_) => FMOperator());
  int algorithm = 4; // 0..7
  int feedback = 4; // 0..7 (Feedback on Operator 1)

  // Pitch sweep (for SFXR sound effects: laser, jump, drop)
  double startFreqMult = 1.0;
  double endFreqMult = 1.0;
  double sweepDuration = 0.0;

  // Noise modulation mode (for explosions, snares, hits)
  bool noiseMode = false;
  double noiseMix = 0.0;

  // Controllable PRNG Seed
  int seed = 42;
  late final DeterministicPRNG prng;

  FMChipVoice({int algorithm = 4, int feedback = 4, int seed = 42}) {
    this.algorithm = algorithm.clamp(0, 7);
    this.feedback = feedback.clamp(0, 7);
    this.seed = seed;
    prng = DeterministicPRNG(seed);
  }

  void setSeed(int newSeed) {
    seed = newSeed;
    prng.seed(newSeed);
  }

  void reset() {
    startFreqMult = 1.0;
    endFreqMult = 1.0;
    sweepDuration = 0.0;
    noiseMode = false;
    noiseMix = 0.0;
    for (final op in operators) {
      op.reset();
    }
  }

  /// Writes directly to a chip register in authentic YM2612 / OPN2 address space.
  void writeRegister(int port, int reg, int value) {
    final v = value & 0xFF;

    // Feedback & Algorithm: 0xB0 (Channel 1..3 / 4..6)
    if ((reg & 0xF0) == 0xB0) {
      algorithm = v & 0x07;
      feedback = (v >> 3) & 0x07;
      return;
    }

    // Operator registers: 0x30..0x9F
    final opIndex = (reg >> 2) & 0x03;
    final op = operators[opIndex];
    final regGroup = reg & 0xF0;

    switch (regGroup) {
      case 0x30: // DT (Detune) & MULT (Multiplier)
        final multRaw = v & 0x0F;
        op.multiplier = multRaw == 0 ? 0.5 : multRaw.toDouble();
        final dtRaw = (v >> 4) & 0x07;
        op.detune = (dtRaw - 3) * 1.5;
        break;
      case 0x40: // TL (Total Level: 0..127)
        op.totalLevel = (v & 0x7F).toDouble();
        break;
      case 0x50: // AR (Attack Rate: 0..31)
        final arRaw = v & 0x1F;
        op.attack = arRaw == 0 ? 2.0 : math.max(0.001, (31 - arRaw) * 0.05);
        break;
      case 0x60: // DR (Decay Rate: 0..31)
        final drRaw = v & 0x1F;
        op.decay = drRaw == 0 ? 4.0 : math.max(0.01, (31 - drRaw) * 0.1);
        break;
      case 0x70: // SR (Sustain Rate: 0..31)
        final srRaw = v & 0x1F;
        op.release = srRaw == 0 ? 4.0 : math.max(0.01, (31 - srRaw) * 0.15);
        break;
      case 0x80: // SL (Sustain Level: 0..15) & RR (Release Rate: 0..15)
        final slRaw = (v >> 4) & 0x0F;
        op.sustain = 1.0 - (slRaw / 15.0);
        final rrRaw = v & 0x0F;
        op.release = rrRaw == 0 ? 2.0 : math.max(0.01, (15 - rrRaw) * 0.15);
        break;
    }
  }

  /// Computes a single audio sample at [time] seconds for frequency [baseFreq].
  double evaluateSample({
    required double time,
    required double baseFreq,
    double duration = 0.4,
    int sampleIndex = 0,
  }) {
    if (baseFreq <= 0) return 0.0;

    // 1. Calculate instantaneous pitch frequency (with pitch sweep if active)
    double currentFreq = baseFreq;
    if (sweepDuration > 0.001 && time < sweepDuration) {
      final progress = (time / sweepDuration).clamp(0.0, 1.0);
      final mult = startFreqMult + (endFreqMult - startFreqMult) * progress;
      currentFreq = baseFreq * mult;
    }

    // 2. Evaluate envelopes for all 4 operators
    final env1 = operators[0].evaluateEnvelope(time, duration);
    final env2 = operators[1].evaluateEnvelope(time, duration);
    final env3 = operators[2].evaluateEnvelope(time, duration);
    final env4 = operators[3].evaluateEnvelope(time, duration);

    // 3. Operator 1 with self-feedback modulation
    final op1Freq = (currentFreq + operators[0].detune) * operators[0].multiplier;
    operators[0].phase += (2.0 * math.pi * op1Freq) / 44100.0;

    double fbMod = 0.0;
    if (feedback > 0) {
      final fbAmount = math.pow(2.0, feedback - 1) * 0.5;
      fbMod = ((operators[0].lastOutput + operators[0].prevOutput) * 0.5) * fbAmount;
    }

    final op1Out = operators[0].evaluateWaveform(operators[0].phase + fbMod) * env1;
    operators[0].prevOutput = operators[0].lastOutput;
    operators[0].lastOutput = op1Out;

    // 4. Operators 2, 3, 4 phase progression
    final op2Freq = (currentFreq + operators[1].detune) * operators[1].multiplier;
    final op3Freq = (currentFreq + operators[2].detune) * operators[2].multiplier;
    final op4Freq = (currentFreq + operators[3].detune) * operators[3].multiplier;

    operators[1].phase += (2.0 * math.pi * op2Freq) / 44100.0;
    operators[2].phase += (2.0 * math.pi * op3Freq) / 44100.0;
    operators[3].phase += (2.0 * math.pi * op4Freq) / 44100.0;

    // 5. FM Algorithm Matrix Routing (OPN / OPN2 Algorithms 0–7)
    double output = 0.0;
    const modScale = 4.0; // Standard FM modulation index scaling

    switch (algorithm) {
      case 0: // Op1 -> Op2 -> Op3 -> Op4 -> Output (Full serial stack)
        final op2 = operators[1].evaluateWaveform(operators[1].phase + op1Out * modScale) * env2;
        final op3 = operators[2].evaluateWaveform(operators[2].phase + op2 * modScale) * env3;
        final op4 = operators[3].evaluateWaveform(operators[3].phase + op3 * modScale) * env4;
        output = op4;
        break;

      case 1: // (Op1 + Op2) -> Op3 -> Op4 -> Output
        final op2 = operators[1].evaluateWaveform(operators[1].phase) * env2;
        final op3 = operators[2].evaluateWaveform(operators[2].phase + (op1Out + op2) * modScale) * env3;
        final op4 = operators[3].evaluateWaveform(operators[3].phase + op3 * modScale) * env4;
        output = op4;
        break;

      case 2: // Op1 + (Op2 -> Op3) -> Op4 -> Output
        final op2 = operators[1].evaluateWaveform(operators[1].phase) * env2;
        final op3 = operators[2].evaluateWaveform(operators[2].phase + op2 * modScale) * env3;
        final op4 = operators[3].evaluateWaveform(operators[3].phase + (op1Out + op3) * modScale) * env4;
        output = op4;
        break;

      case 3: // (Op1 -> Op2) + Op3 -> Op4 -> Output
        final op2 = operators[1].evaluateWaveform(operators[1].phase + op1Out * modScale) * env2;
        final op3 = operators[2].evaluateWaveform(operators[2].phase) * env3;
        final op4 = operators[3].evaluateWaveform(operators[3].phase + (op2 + op3) * modScale) * env4;
        output = op4;
        break;

      case 4: // (Op1 -> Op2) + (Op3 -> Op4) -> Output (Classic dual 2-op FM)
        final op2 = operators[1].evaluateWaveform(operators[1].phase + op1Out * modScale) * env2;
        final op3 = operators[2].evaluateWaveform(operators[2].phase) * env3;
        final op4 = operators[3].evaluateWaveform(operators[3].phase + op3 * modScale) * env4;
        output = (op2 + op4) * 0.7;
        break;

      case 5: // Op1 -> (Op2 + Op3 + Op4) -> Output
        final op2 = operators[1].evaluateWaveform(operators[1].phase + op1Out * modScale) * env2;
        final op3 = operators[2].evaluateWaveform(operators[2].phase + op1Out * modScale) * env3;
        final op4 = operators[3].evaluateWaveform(operators[3].phase + op1Out * modScale) * env4;
        output = (op2 + op3 + op4) * 0.5;
        break;

      case 6: // (Op1 -> Op2) + Op3 + Op4 -> Output
        final op2 = operators[1].evaluateWaveform(operators[1].phase + op1Out * modScale) * env2;
        final op3 = operators[2].evaluateWaveform(operators[2].phase) * env3;
        final op4 = operators[3].evaluateWaveform(operators[3].phase) * env4;
        output = (op2 + op3 + op4) * 0.5;
        break;

      case 7: // Op1 + Op2 + Op3 + Op4 -> Output (Pure additive 4-op)
      default:
        final op2 = operators[1].evaluateWaveform(operators[1].phase) * env2;
        final op3 = operators[2].evaluateWaveform(operators[2].phase) * env3;
        final op4 = operators[3].evaluateWaveform(operators[3].phase) * env4;
        output = (op1Out + op2 + op3 + op4) * 0.35;
        break;
    }

    // 6. Optional noise modulation for SFXR percussion/explosions
    if (noiseMode && noiseMix > 0.0) {
      final noise = ((sampleIndex * 1664525 + 1013904223) & 0x7FFFFFFF) / 2147483647.0 * 2.0 - 1.0;
      output = output * (1.0 - noiseMix) + noise * env4 * noiseMix;
    }

    return output.clamp(-1.0, 1.0);
  }

  /// Synthesizes a complete Float32List audio buffer for a note.
  Float32List synthesizeBuffer({
    required double freq,
    required double durationSec,
    double volume = 0.8,
  }) {
    final int numSamples = (44100 * durationSec).toInt().clamp(1, 441000);
    final buffer = Float32List(numSamples);
    reset();

    for (int i = 0; i < numSamples; i++) {
      final time = i / 44100.0;
      final raw = evaluateSample(
        time: time,
        baseFreq: freq,
        duration: durationSec,
        sampleIndex: i,
      );
      buffer[i] = (raw * volume).clamp(-1.0, 1.0);
    }

    return buffer;
  }
}

/// Procedural SFXR sound generator library built entirely on 4-Op FM hardware chips.
/// Every sound effect generated is a real FM patch that is chromatically playable as an instrument!
class SFXRGenerator {
  /// Applies a preset based on [sfxType] index (0: Laser, 1: Explosion, 2: Powerup, 3: Coin, 4: Jump, 5: Hit, 6: Mutate, 7: Custom FM)
  /// using the provided [seed] for deterministic micro-variations.
  static void configureFromType(FMChipVoice voice, int sfxType, {int seed = 42}) {
    voice.setSeed(seed);
    final prng = voice.prng;

    switch (sfxType) {
      case 0: // Laser
        configureLaser(voice, prng);
        break;
      case 1: // Explosion
        configureExplosion(voice, prng);
        break;
      case 2: // Powerup
        configurePowerup(voice, prng);
        break;
      case 3: // Coin
        configureCoin(voice, prng);
        break;
      case 4: // Jump
        configureJump(voice, prng);
        break;
      case 5: // Hit / Hurt
        configureHit(voice, prng);
        break;
      case 6: // Mutate
        configureLaser(voice, prng);
        mutate(voice, prng);
        break;
      case 7: // Custom FM
      default:
        // Keep baseline FM settings
        break;
    }
  }

  /// Laser / Zap sound effect: fast downward frequency sweep with bright metallic FM mod.
  static void configureLaser(FMChipVoice voice, [DeterministicPRNG? prng]) {
    voice.reset();
    voice.algorithm = 4; // Dual 2-op
    voice.feedback = 6;
    voice.startFreqMult = prng != null ? prng.nextRange(2.0, 3.2) : 2.4;
    voice.endFreqMult = prng != null ? prng.nextRange(0.1, 0.3) : 0.2;
    voice.sweepDuration = prng != null ? prng.nextRange(0.12, 0.24) : 0.18;
    voice.noiseMode = false;
    voice.noiseMix = 0.0;

    // Op 1 (Modulator 1)
    voice.operators[0].multiplier = prng != null ? prng.nextInt(2, 4).toDouble() : 3.0;
    voice.operators[0].detune = prng != null ? prng.nextRange(-2.0, 2.0) : 0.0;
    voice.operators[0].totalLevel = 8.0;
    voice.operators[0].attack = 0.001;
    voice.operators[0].decay = 0.12;
    voice.operators[0].sustain = 0.0;

    // Op 2 (Carrier 1)
    voice.operators[1].multiplier = 1.0;
    voice.operators[1].totalLevel = 0.0;
    voice.operators[1].attack = 0.001;
    voice.operators[1].decay = 0.18;
    voice.operators[1].sustain = 0.0;

    // Op 3 (Modulator 2)
    voice.operators[2].multiplier = prng != null ? prng.nextInt(4, 7).toDouble() : 5.0;
    voice.operators[2].detune = prng != null ? prng.nextRange(-3.0, 3.0) : 0.0;
    voice.operators[2].totalLevel = 18.0;
    voice.operators[2].attack = 0.001;
    voice.operators[2].decay = 0.08;
    voice.operators[2].sustain = 0.0;

    // Op 4 (Carrier 2)
    voice.operators[3].multiplier = 2.0;
    voice.operators[3].totalLevel = 6.0;
    voice.operators[3].attack = 0.001;
    voice.operators[3].decay = 0.15;
    voice.operators[3].sustain = 0.0;
  }

  /// Explosion sound effect: low pitch drop with noise modulation and deep rumble decay.
  static void configureExplosion(FMChipVoice voice, [DeterministicPRNG? prng]) {
    voice.reset();
    voice.algorithm = 0; // Stacked serial
    voice.feedback = 7; // Max feedback
    voice.startFreqMult = prng != null ? prng.nextRange(1.2, 1.8) : 1.5;
    voice.endFreqMult = prng != null ? prng.nextRange(0.15, 0.35) : 0.25;
    voice.sweepDuration = prng != null ? prng.nextRange(0.35, 0.55) : 0.45;
    voice.noiseMode = true;
    voice.noiseMix = prng != null ? prng.nextRange(0.5, 0.8) : 0.65;

    voice.operators[0].multiplier = 0.5;
    voice.operators[0].totalLevel = 0.0;
    voice.operators[0].attack = 0.005;
    voice.operators[0].decay = 0.4;
    voice.operators[0].sustain = 0.1;

    voice.operators[1].multiplier = 1.0;
    voice.operators[1].totalLevel = 10.0;
    voice.operators[1].attack = 0.01;
    voice.operators[1].decay = 0.35;
    voice.operators[1].sustain = 0.0;

    voice.operators[2].multiplier = 0.5;
    voice.operators[2].totalLevel = 5.0;
    voice.operators[2].attack = 0.01;
    voice.operators[2].decay = 0.45;
    voice.operators[2].sustain = 0.0;

    voice.operators[3].multiplier = 0.5;
    voice.operators[3].totalLevel = 0.0;
    voice.operators[3].attack = 0.005;
    voice.operators[3].decay = 0.5;
    voice.operators[3].sustain = 0.0;
  }

  /// Powerup / Item pickup: fast upward sweep with shimmering bells.
  static void configurePowerup(FMChipVoice voice, [DeterministicPRNG? prng]) {
    voice.reset();
    voice.algorithm = 5; // Multi-carrier
    voice.feedback = 3;
    voice.startFreqMult = prng != null ? prng.nextRange(0.3, 0.6) : 0.4;
    voice.endFreqMult = prng != null ? prng.nextRange(1.5, 2.2) : 1.8;
    voice.sweepDuration = prng != null ? prng.nextRange(0.18, 0.3) : 0.22;
    voice.noiseMode = false;
    voice.noiseMix = 0.0;

    voice.operators[0].multiplier = 1.0;
    voice.operators[0].totalLevel = 12.0;
    voice.operators[0].attack = 0.001;
    voice.operators[0].decay = 0.2;
    voice.operators[0].sustain = 0.3;

    voice.operators[1].multiplier = 2.0;
    voice.operators[1].totalLevel = 0.0;
    voice.operators[1].attack = 0.001;
    voice.operators[1].decay = 0.25;
    voice.operators[1].sustain = 0.2;

    voice.operators[2].multiplier = prng != null ? prng.nextInt(3, 5).toDouble() : 4.0;
    voice.operators[2].totalLevel = 10.0;
    voice.operators[2].attack = 0.01;
    voice.operators[2].decay = 0.22;
    voice.operators[2].sustain = 0.1;

    voice.operators[3].multiplier = prng != null ? prng.nextInt(6, 9).toDouble() : 7.0;
    voice.operators[3].totalLevel = 16.0;
    voice.operators[3].attack = 0.02;
    voice.operators[3].decay = 0.25;
    voice.operators[3].sustain = 0.1;
  }

  /// Coin clink: crisp dual-tone bell chime.
  static void configureCoin(FMChipVoice voice, [DeterministicPRNG? prng]) {
    voice.reset();
    voice.algorithm = 4;
    voice.feedback = 2;
    voice.startFreqMult = 1.0;
    voice.endFreqMult = prng != null ? prng.nextRange(1.2, 1.5) : 1.33;
    voice.sweepDuration = 0.04;
    voice.noiseMode = false;
    voice.noiseMix = 0.0;

    voice.operators[0].multiplier = prng != null ? prng.nextRange(3.0, 4.0) : 3.5;
    voice.operators[0].totalLevel = 14.0;
    voice.operators[0].attack = 0.001;
    voice.operators[0].decay = 0.25;
    voice.operators[0].sustain = 0.0;

    voice.operators[1].multiplier = 1.0;
    voice.operators[1].totalLevel = 0.0;
    voice.operators[1].attack = 0.001;
    voice.operators[1].decay = 0.35;
    voice.operators[1].sustain = 0.0;

    voice.operators[2].multiplier = prng != null ? prng.nextInt(4, 6).toDouble() : 5.0;
    voice.operators[2].totalLevel = 20.0;
    voice.operators[2].attack = 0.001;
    voice.operators[2].decay = 0.2;
    voice.operators[2].sustain = 0.0;

    voice.operators[3].multiplier = 2.0;
    voice.operators[3].totalLevel = 4.0;
    voice.operators[3].attack = 0.001;
    voice.operators[3].decay = 0.3;
    voice.operators[3].sustain = 0.0;
  }

  /// Jump / Bounce: rising resonant tone with rubbery modulation.
  static void configureJump(FMChipVoice voice, [DeterministicPRNG? prng]) {
    voice.reset();
    voice.algorithm = 2;
    voice.feedback = 5;
    voice.startFreqMult = prng != null ? prng.nextRange(0.5, 0.7) : 0.6;
    voice.endFreqMult = prng != null ? prng.nextRange(1.3, 1.6) : 1.4;
    voice.sweepDuration = prng != null ? prng.nextRange(0.12, 0.2) : 0.15;
    voice.noiseMode = false;
    voice.noiseMix = 0.0;

    voice.operators[0].multiplier = 1.0;
    voice.operators[0].totalLevel = 15.0;
    voice.operators[0].attack = 0.005;
    voice.operators[0].decay = 0.15;
    voice.operators[0].sustain = 0.0;

    voice.operators[1].multiplier = 2.0;
    voice.operators[1].totalLevel = 8.0;
    voice.operators[1].attack = 0.005;
    voice.operators[1].decay = 0.16;
    voice.operators[1].sustain = 0.0;

    voice.operators[2].multiplier = 1.0;
    voice.operators[2].totalLevel = 0.0;
    voice.operators[2].attack = 0.001;
    voice.operators[2].decay = 0.2;
    voice.operators[2].sustain = 0.0;

    voice.operators[3].multiplier = 1.0;
    voice.operators[3].totalLevel = 0.0;
    voice.operators[3].attack = 0.001;
    voice.operators[3].decay = 0.2;
    voice.operators[3].sustain = 0.0;
  }

  /// Hit / Hurt sound effect: punchy FM burst with fast decay and noise thud.
  static void configureHit(FMChipVoice voice, [DeterministicPRNG? prng]) {
    voice.reset();
    voice.algorithm = 1;
    voice.feedback = 6;
    voice.startFreqMult = 1.8;
    voice.endFreqMult = 0.4;
    voice.sweepDuration = 0.1;
    voice.noiseMode = true;
    voice.noiseMix = prng != null ? prng.nextRange(0.3, 0.6) : 0.45;

    voice.operators[0].multiplier = 1.0;
    voice.operators[0].totalLevel = 6.0;
    voice.operators[0].attack = 0.001;
    voice.operators[0].decay = 0.12;
    voice.operators[0].sustain = 0.0;

    voice.operators[1].multiplier = 0.5;
    voice.operators[1].totalLevel = 10.0;
    voice.operators[1].attack = 0.001;
    voice.operators[1].decay = 0.15;
    voice.operators[1].sustain = 0.0;

    voice.operators[2].multiplier = 1.0;
    voice.operators[2].totalLevel = 0.0;
    voice.operators[2].attack = 0.001;
    voice.operators[2].decay = 0.15;
    voice.operators[2].sustain = 0.0;

    voice.operators[3].multiplier = 1.0;
    voice.operators[3].totalLevel = 0.0;
    voice.operators[3].attack = 0.001;
    voice.operators[3].decay = 0.18;
    voice.operators[3].sustain = 0.0;
  }

  /// Mutates current voice parameters subtly within musical sweet spots using deterministic PRNG.
  static void mutate(FMChipVoice voice, [DeterministicPRNG? prng]) {
    final r = prng ?? voice.prng;
    voice.feedback = (voice.feedback + (r.nextInt(-1, 1))).clamp(0, 7);
    for (final op in voice.operators) {
      if (r.nextBool(0.6)) {
        op.multiplier = (op.multiplier + r.nextRange(-0.5, 0.5)).clamp(0.5, 12.0);
      }
      if (r.nextBool(0.6)) {
        op.totalLevel = (op.totalLevel + r.nextRange(-8.0, 8.0)).clamp(0.0, 100.0);
      }
      if (r.nextBool(0.5)) {
        op.decay = (op.decay * r.nextRange(0.8, 1.3)).clamp(0.02, 2.0);
      }
    }
  }
}
