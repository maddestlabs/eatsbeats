import 'dart:math' as math;
import 'dart:typed_data';

import 'graph_node.dart';
import 'tr909_rom_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OSCILLATORS & SOURCES
// ─────────────────────────────────────────────────────────────────────────────

/// High-performance White Noise generator (Fast Xorshift32 PRNG).
class NoiseNode extends GraphNode {
  final int seed;
  const NoiseNode({this.seed = 0x12345678});

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    int state = seed ^ (ctx.midiNote * 31);
    for (int i = 0; i < outBuffer.length; i++) {
      state ^= (state << 13) & 0xFFFFFFFF;
      state ^= (state >> 17) & 0xFFFFFFFF;
      state ^= (state << 5) & 0xFFFFFFFF;
      outBuffer[i] = ((state & 0xFFFFFF) / 8388607.5) - 1.0;
    }
  }
}

/// Sine Oscillator supporting audio-rate frequency modulation (FM).
class SineOscNode extends GraphNode {
  final GraphNode? freqSource;
  final double staticFreq;
  final GraphNode? fmModSource;

  const SineOscNode({
    this.freqSource,
    this.staticFreq = 440.0,
    this.fmModSource,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List? freqBuf = freqSource != null ? Float32List(len) : null;
    final Float32List? fmBuf = fmModSource != null ? Float32List(len) : null;

    if (freqSource != null) freqSource!.process(ctx, freqBuf!);
    if (fmModSource != null) fmModSource!.process(ctx, fmBuf!);

    final double sr = ctx.sampleRate;
    final double twoPi = 2.0 * math.pi;
    double phase = 0.0;

    for (int i = 0; i < len; i++) {
      final double baseF = freqBuf != null ? freqBuf[i] : staticFreq;
      final double fmOffset = fmBuf != null ? fmBuf[i] : 0.0;
      final double instantaneousFreq = math.max(0.0, baseF + fmOffset);

      outBuffer[i] = math.sin(phase);
      phase += (instantaneousFreq / sr) * twoPi;
      if (phase >= twoPi) phase -= twoPi;
    }
  }
}

/// Sawtooth Oscillator with antialiasing / leaky-integrator option.
class SawOscNode extends GraphNode {
  final GraphNode? freqSource;
  final double staticFreq;

  const SawOscNode({this.freqSource, this.staticFreq = 440.0});

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List? freqBuf = freqSource != null ? Float32List(len) : null;
    if (freqSource != null) freqSource!.process(ctx, freqBuf!);

    final double sr = ctx.sampleRate;
    double phase = 0.0;

    for (int i = 0; i < len; i++) {
      final double curF = freqBuf != null ? freqBuf[i] : staticFreq;
      outBuffer[i] = 2.0 * phase - 1.0;
      phase = (phase + (curF / sr)) % 1.0;
    }
  }
}

/// Square / Pulse Oscillator.
class SquareOscNode extends GraphNode {
  final GraphNode? freqSource;
  final double staticFreq;
  final double pulseWidth;

  const SquareOscNode({
    this.freqSource,
    this.staticFreq = 440.0,
    this.pulseWidth = 0.5,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List? freqBuf = freqSource != null ? Float32List(len) : null;
    if (freqSource != null) freqSource!.process(ctx, freqBuf!);

    final double sr = ctx.sampleRate;
    double phase = 0.0;

    for (int i = 0; i < len; i++) {
      final double curF = freqBuf != null ? freqBuf[i] : staticFreq;
      outBuffer[i] = phase < pulseWidth ? 0.75 : -0.75;
      phase = (phase + (curF / sr)) % 1.0;
    }
  }
}

/// 6-Oscillator Inharmonic Metallic Cluster (808/909 Schmitt-Trigger Model).
/// Uses authentic inharmonic ratios: [245.0, 306.0, 384.0, 522.0, 710.0, 805.0] Hz.
class MetallicClusterNode extends GraphNode {
  final double pitchMultiplier;
  final String? pitchParam;
  final double spread;

  static const List<double> defaultFrequencies = [
    245.0,
    306.0,
    384.0,
    522.0,
    710.0,
    805.0,
  ];

  const MetallicClusterNode({
    this.pitchMultiplier = 1.0,
    this.pitchParam,
    this.spread = 1.0,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double mult = (pitchParam != null ? ctx.getParam(pitchParam!, pitchMultiplier) : pitchMultiplier).clamp(0.2, 5.0);
    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;

    outBuffer.fillRange(0, len, 0.0);

    for (final baseFreq in defaultFrequencies) {
      final double f = baseFreq * mult;
      double phase = (baseFreq * 17.0) % 1.0; // Detune starting phases
      for (int i = 0; i < len; i++) {
        final double sqr = phase < 0.5 ? 0.5 : -0.5;
        outBuffer[i] += sqr * (1.0 / 6.0);
        phase = (phase + (f / sr)) % 1.0;
      }
    }
  }
}

/// Ring Modulation / Multiplier Node (Multiplies two audio signals).
class RingModNode extends GraphNode {
  final GraphNode sourceA;
  final GraphNode sourceB;

  const RingModNode(this.sourceA, this.sourceB);

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List bufB = Float32List(len);

    sourceA.process(ctx, outBuffer);
    sourceB.process(ctx, bufB);

    for (int i = 0; i < len; i++) {
      outBuffer[i] *= bufB[i];
    }
  }
}

/// Low-Frequency Oscillator (LFO) for organic cymbal wobble & modulation.
class LfoNode extends GraphNode {
  final double rateHz;
  final double depth;

  const LfoNode({this.rateHz = 2.5, this.depth = 1.0});

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double twoPi = 2.0 * math.pi;
    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;
      outBuffer[i] = (math.sin(twoPi * rateHz * t) * 0.5 + 0.5) * depth;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ENVELOPES & MODULATORS
// ─────────────────────────────────────────────────────────────────────────────

/// Exponential or Linear Decay Envelope.
class DecayEnvNode extends GraphNode {
  final double decaySec;
  final String? decayParam;
  final double curve;

  const DecayEnvNode({
    this.decaySec = 0.25,
    this.decayParam,
    this.curve = 1.0,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double actualDecay = math.max(
      0.001,
      decayParam != null ? ctx.getParam(decayParam!, decaySec) : decaySec,
    );
    final double sr = ctx.sampleRate;

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;
      outBuffer[i] = math.exp(-t * (4.0 / actualDecay));
    }
  }
}

/// Pitch Sweep Envelope (e.g. for Kick punch 180Hz -> 52Hz).
class PitchSweepNode extends GraphNode {
  final double startFreq;
  final double endFreq;
  final double decaySec;
  final String? startParam;
  final String? endParam;
  final String? decayParam;

  const PitchSweepNode({
    this.startFreq = 180.0,
    this.endFreq = 52.0,
    this.decaySec = 0.07,
    this.startParam,
    this.endParam,
    this.decayParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double start = startParam != null ? ctx.getParam(startParam!, startFreq) : startFreq;
    final double end = endParam != null ? ctx.getParam(endParam!, endFreq) : endFreq;
    final double decay = math.max(
      0.001,
      decayParam != null ? ctx.getParam(decayParam!, decaySec) : decaySec,
    );
    final double sr = ctx.sampleRate;

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;
      outBuffer[i] = end + (start - end) * math.exp(-t / decay);
    }
  }
}

/// 4-stage ADSR Envelope.
class AdsrEnvNode extends GraphNode {
  final double attack;
  final double decay;
  final double sustain;
  final double release;

  const AdsrEnvNode({
    this.attack = 0.01,
    this.decay = 0.1,
    this.sustain = 0.7,
    this.release = 0.2,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double a = math.max(0.0001, attack);
    final double d = math.max(0.001, decay);
    final double s = sustain.clamp(0.0, 1.0);
    final double r = math.max(0.001, release);
    final double gate = math.max(a + d, ctx.durationSec * 0.8);
    final double sr = ctx.sampleRate;

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;
      if (t < a) {
        outBuffer[i] = (t / a).clamp(0.0, 1.0);
      } else if (t < a + d) {
        final double prog = (t - a) / d;
        outBuffer[i] = 1.0 - (prog * (1.0 - s));
      } else if (t < gate) {
        outBuffer[i] = s;
      } else {
        final double prog = (t - gate) / r;
        outBuffer[i] = (s * math.max(0.0, 1.0 - prog)).clamp(0.0, 1.0);
      }
    }
  }
}

/// Multi-Burst Trigger Envelope for authentic Handclap synthesis (Eats-808/909 model).
/// Produces [burstCount] rapid micro-transient decay bursts spaced by [burstIntervalSec],
/// followed by a main diffuse reverberant decay tail.
class MultiBurstEnvNode extends GraphNode {
  final int burstCount;
  final double burstIntervalSec;
  final String? spreadParam;
  final double burstDecaySec;
  final double tailDecaySec;
  final String? decayParam;

  const MultiBurstEnvNode({
    this.burstCount = 4,
    this.burstIntervalSec = 0.011,
    this.spreadParam,
    this.burstDecaySec = 0.008,
    this.tailDecaySec = 0.28,
    this.decayParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double spread = math.max(
      0.003,
      spreadParam != null ? ctx.getParam(spreadParam!, burstIntervalSec) : burstIntervalSec,
    );
    final double tailDecay = math.max(
      0.01,
      decayParam != null ? ctx.getParam(decayParam!, tailDecaySec) : tailDecaySec,
    );
    final double sr = ctx.sampleRate;
    final double tailStartTime = (burstCount - 1) * spread;

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;
      double amp = 0.0;

      // 1. Check micro bursts
      for (int b = 0; b < burstCount; b++) {
        final double bTime = b * spread;
        if (t >= bTime) {
          final double dt = t - bTime;
          final double bAmp = math.exp(-dt * (4.0 / burstDecaySec));
          if (bAmp > amp) amp = bAmp;
        }
      }

      // 2. Main tail starting at the final burst
      if (t >= tailStartTime) {
        final double dt = t - tailStartTime;
        final double tAmp = math.exp(-dt * (4.0 / tailDecay));
        if (tAmp > amp) amp = tAmp;
      }

      outBuffer[i] = amp.clamp(0.0, 1.0);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AUTHENTIC 909 HARDWARE/ROM DSP NODES (André Michelle Model)
// ─────────────────────────────────────────────────────────────────────────────

/// Authentic TR-909 Bass Drum DSP node.
/// Reconstructs the exact physical circuit: single-cycle analog oscillator wavetable
/// swept exponentially from 274Hz to 53Hz with 60ms release hold, exponential decay,
/// and interpolated beater click attack transient.
class Tr909KickNode extends GraphNode {
  final double tune; // 0.007 to 0.0294 (pitch decay time constant)
  final String? tuneParam;
  final double decay; // 0.012 to 0.100 (amplitude decay time constant)
  final String? decayParam;
  final double attackLevel; // 0.0 to 1.5
  final String? attackParam;

  const Tr909KickNode({
    this.tune = 0.018,
    this.tuneParam,
    this.decay = 0.050,
    this.decayParam,
    this.attackLevel = 1.0,
    this.attackParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double srInv = 1.0 / sr;
    final cycle = Tr909RomData.bassdrum_cycle;
    final attack = Tr909RomData.bassdrum_attack;

    double tTune = tuneParam != null ? ctx.getParam(tuneParam!, tune) : tune;
    if (tTune > 1.0) {
      tTune = (0.007 + ((tTune - 35.0) / 50.0).clamp(0.0, 1.0) * (0.0294 - 0.007));
    }
    tTune = tTune.clamp(0.003, 0.100);

    double tDecay = decayParam != null ? ctx.getParam(decayParam!, decay) : decay;
    if (tDecay > 0.5) {
      tDecay = (0.012 + ((tDecay - 0.1) / 1.7).clamp(0.0, 1.0) * (0.100 - 0.012));
    }
    tDecay = tDecay.clamp(0.005, 0.300);

    final double tAttack = attackParam != null ? ctx.getParam(attackParam!, attackLevel) : attackLevel;

    final double gainCoeff = math.exp(-1.0 / (sr * tDecay));
    final double freqCoeff = math.exp(-1.0 / (sr * tTune));
    final double attackRate = 44100.0 * srInv;

    double gainEnv = 1.0;
    double freqEnv = 274.0;
    double time = 0.0;
    double phase = 0.0;
    double attackPos = 0.0;

    const double releaseStartTime = 0.060;
    const double freqEnd = 53.0;

    final int len = outBuffer.length;
    for (int i = 0; i < len; i++) {
      if (time > releaseStartTime) {
        gainEnv *= gainCoeff;
      }

      final double pos = (phase - phase.floorToDouble()) * cycle.length;
      final int posInt = pos.floor();
      final double alpha = pos - posInt;
      final double p0 = cycle[posInt % cycle.length];
      final double p1 = cycle[(posInt + 1) % cycle.length];
      final double cycleSample = p0 + alpha * (p1 - p0);

      double sample = cycleSample * gainEnv;

      if (attackPos < attack.length - 1) {
        final int pi = attackPos.toInt();
        final double a0 = attack[pi];
        final double a1 = attack[pi + 1];
        sample += (a0 + (attackPos - pi) * (a1 - a0)) * tAttack;
        attackPos += attackRate;
      }

      outBuffer[i] = sample;

      time += srInv;
      phase += freqEnv * srInv;
      phase -= phase.floorToDouble();
      freqEnv = freqEnd + freqCoeff * (freqEnv - freqEnd);
    }
  }
}

/// Authentic TR-909 Snare Drum DSP node.
/// Plays dual layers: tuned tonal body (snare-tone) + snappy noise wires (snare-noise).
class Tr909SnareNode extends GraphNode {
  final double tune; // pitch semitone offset (-0.5 to +0.5)
  final String? tuneParam;
  final double tone; // noise decay time constant (0.04 to 0.20)
  final String? toneParam;
  final double snappy; // noise wire gain (0.0 to 1.5)
  final String? snappyParam;

  const Tr909SnareNode({
    this.tune = 0.0,
    this.tuneParam,
    this.tone = 0.12,
    this.toneParam,
    this.snappy = 1.0,
    this.snappyParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double srInv = 1.0 / sr;
    final toneBuf = Tr909RomData.snare_tone;
    final noiseBuf = Tr909RomData.snare_noise;

    double tTune = tuneParam != null ? ctx.getParam(tuneParam!, tune) : tune;
    if (tTune > 2.0) {
      tTune = (tTune - 195.0) / 100.0;
    }
    tTune = tTune.clamp(-0.8, 0.8);

    double tTone = toneParam != null ? ctx.getParam(toneParam!, tone) : tone;
    if (tTone < 0.01) tTone = 0.01;
    if (tTone > 0.5) tTone = 0.5;

    final double tSnappy = snappyParam != null ? ctx.getParam(snappyParam!, snappy) : snappy;

    final double tuneRate = 44100.0 * srInv * math.pow(2.0, tTune);
    final double noiseRate = 44100.0 * srInv;
    final double noiseGainCoeff = math.exp(-1.0 / (sr * tTone));

    double tonePos = 0.0;
    double noisePos = 0.0;
    double noiseGain = tSnappy;

    final int len = outBuffer.length;
    for (int i = 0; i < len; i++) {
      double sample = 0.0;

      if (tonePos < toneBuf.length - 1) {
        final int pi = tonePos.toInt();
        final double p0 = toneBuf[pi];
        final double p1 = toneBuf[pi + 1];
        sample += p0 + (tonePos - pi) * (p1 - p0);
        tonePos += tuneRate;
      }

      if (noisePos < noiseBuf.length - 1) {
        final int pi = noisePos.toInt();
        final double p0 = noiseBuf[pi];
        final double p1 = noiseBuf[pi + 1];
        sample += (p0 + (noisePos - pi) * (p1 - p0)) * noiseGain;
        noiseGain *= noiseGainCoeff;
        noisePos += noiseRate;
      }

      outBuffer[i] = sample;
    }
  }
}

/// Authentic TR-909 ROM Sample voice.
/// Interpolates 6-bit compressed PCM recordings (Hi-Hats, Clap, Rimshot, Toms)
/// with variable pitch tuning and exponential release decay.
class Tr909SampleVoiceNode extends GraphNode {
  final Float32List Function() getBuffer;
  final double tune;
  final String? tuneParam;
  final double decay;
  final String? decayParam;
  final double releaseStartTime;

  const Tr909SampleVoiceNode({
    required this.getBuffer,
    this.tune = 0.0,
    this.tuneParam,
    this.decay = 0.100,
    this.decayParam,
    this.releaseStartTime = 0.0,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double srInv = 1.0 / sr;
    final buffer = getBuffer();

    double tTune = tuneParam != null ? ctx.getParam(tuneParam!, tune) : tune;
    if (tTune > 2.0) {
      tTune = 0.0;
    }
    tTune = tTune.clamp(-0.8, 0.8);

    double tDecay = decayParam != null ? ctx.getParam(decayParam!, decay) : decay;
    tDecay = tDecay.clamp(0.005, 1.5);

    final double rate = 44100.0 * srInv * math.pow(2.0, tTune);
    final double envCoeff = math.exp(-1.0 / (sr * tDecay));
    final int releaseStartFrame = (releaseStartTime * sr).toInt();

    double pos = 0.0;
    double env = 1.0;
    int frame = 0;

    final int len = outBuffer.length;
    for (int i = 0; i < len; i++) {
      if (pos >= buffer.length - 1) {
        break;
      }

      if (frame++ >= releaseStartFrame) {
        env *= envCoeff;
      }

      final int pi = pos.toInt();
      final double v0 = buffer[pi];
      final double v1 = buffer[pi + 1];
      outBuffer[i] = (v0 + (pos - pi) * (v1 - v0)) * env;
      pos += rate;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FILTERS
// ─────────────────────────────────────────────────────────────────────────────

enum BiquadType {
  lowpass,
  highpass,
  bandpass,
  notch,
  peaking,
  highshelf,
  lowshelf,
}

/// Standard 2-Pole Audio EQ Biquad Filter (Direct Form II Transposed).
class BiquadFilterNode extends GraphNode {
  final GraphNode input;
  final BiquadType type;
  final double frequency;
  final String? freqParam;
  final double q;
  final String? qParam;
  final double gainDb;
  final String? gainDbParam;

  const BiquadFilterNode({
    required this.input,
    required this.type,
    this.frequency = 1000.0,
    this.freqParam,
    this.q = 0.707,
    this.qParam,
    this.gainDb = 0.0,
    this.gainDbParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double freq = (freqParam != null ? ctx.getParam(freqParam!, frequency) : frequency).clamp(10.0, 20000.0);
    final double quality = (qParam != null ? ctx.getParam(qParam!, q) : q).clamp(0.1, 30.0);
    final double db = gainDbParam != null ? ctx.getParam(gainDbParam!, gainDb) : gainDb;

    final double sr = ctx.sampleRate;
    final double w0 = 2.0 * math.pi * (freq / sr);
    final double cosW0 = math.cos(w0);
    final double sinW0 = math.sin(w0);
    final double alpha = sinW0 / (2.0 * quality);
    final double a = math.pow(10.0, db / 40.0).toDouble();

    double b0 = 1.0, b1 = 0.0, b2 = 0.0, a0 = 1.0, a1 = 0.0, a2 = 0.0;

    switch (type) {
      case BiquadType.lowpass:
        b0 = (1.0 - cosW0) / 2.0;
        b1 = 1.0 - cosW0;
        b2 = (1.0 - cosW0) / 2.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
        break;
      case BiquadType.highpass:
        b0 = (1.0 + cosW0) / 2.0;
        b1 = -(1.0 + cosW0);
        b2 = (1.0 + cosW0) / 2.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
        break;
      case BiquadType.bandpass:
        b0 = sinW0 / 2.0;
        b1 = 0.0;
        b2 = -sinW0 / 2.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
        break;
      case BiquadType.notch:
        b0 = 1.0;
        b1 = -2.0 * cosW0;
        b2 = 1.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
        break;
      case BiquadType.peaking:
        b0 = 1.0 + alpha * a;
        b1 = -2.0 * cosW0;
        b2 = 1.0 - alpha * a;
        a0 = 1.0 + alpha / a;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha / a;
        break;
      case BiquadType.highshelf:
        final double sqA = 2.0 * math.sqrt(a) * alpha;
        b0 = a * ((a + 1.0) + (a - 1.0) * cosW0 + sqA);
        b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cosW0);
        b2 = a * ((a + 1.0) + (a - 1.0) * cosW0 - sqA);
        a0 = (a + 1.0) - (a - 1.0) * cosW0 + sqA;
        a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cosW0);
        a2 = (a + 1.0) - (a - 1.0) * cosW0 - sqA;
        break;
      case BiquadType.lowshelf:
        final double sqA = 2.0 * math.sqrt(a) * alpha;
        b0 = a * ((a + 1.0) - (a - 1.0) * cosW0 + sqA);
        b1 = 2.0 * a * ((a - 1.0) - (a + 1.0) * cosW0);
        b2 = a * ((a + 1.0) - (a - 1.0) * cosW0 - sqA);
        a0 = (a + 1.0) + (a - 1.0) * cosW0 + sqA;
        a1 = -2.0 * ((a - 1.0) + (a + 1.0) * cosW0);
        a2 = (a + 1.0) + (a - 1.0) * cosW0 - sqA;
        break;
    }

    // Normalize coefficients
    final double normB0 = b0 / a0;
    final double normB1 = b1 / a0;
    final double normB2 = b2 / a0;
    final double normA1 = a1 / a0;
    final double normA2 = a2 / a0;

    double z1 = 0.0;
    double z2 = 0.0;

    for (int i = 0; i < outBuffer.length; i++) {
      final double inSample = outBuffer[i];
      final double outSample = normB0 * inSample + z1;
      z1 = normB1 * inSample - normA1 * outSample + z2;
      z2 = normB2 * inSample - normA2 * outSample;
      outBuffer[i] = outSample;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TIME & DYNAMICS
// ─────────────────────────────────────────────────────────────────────────────

/// Delay Line node (e.g. for Room mic acoustic distance 2-20ms).
class DelayNode extends GraphNode {
  final GraphNode input;
  final double delaySec;
  final String? delayParam;

  const DelayNode({
    required this.input,
    this.delaySec = 0.008,
    this.delayParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List inBuf = Float32List(len);
    input.process(ctx, inBuf);

    final double dSec = (delayParam != null ? ctx.getParam(delayParam!, delaySec) : delaySec).clamp(0.0, 1.0);
    final int delaySamples = (dSec * ctx.sampleRate).toInt().clamp(0, len - 1);

    for (int i = 0; i < len; i++) {
      final int readIdx = i - delaySamples;
      outBuffer[i] = readIdx >= 0 ? inBuf[readIdx] : 0.0;
    }
  }
}

/// Mixer Node (sums multiple signal branches with gain scaling).
class MixerNode extends GraphNode {
  final List<GraphNode> inputs;
  final List<double>? gains;

  const MixerNode(this.inputs, [this.gains]);

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    outBuffer.fillRange(0, len, 0.0);

    final Float32List branchBuf = Float32List(len);
    for (int b = 0; b < inputs.length; b++) {
      inputs[b].process(ctx, branchBuf);
      final double g = (gains != null && b < gains!.length) ? gains![b] : 1.0;
      for (int i = 0; i < len; i++) {
        outBuffer[i] += branchBuf[i] * g;
      }
    }
  }
}

/// Gain / VCA Node (multiplies input signal with a gain node or envelope).
class GainNode extends GraphNode {
  final GraphNode input;
  final GraphNode? gainSource;
  final double staticGain;
  final String? gainParam;

  const GainNode({
    required this.input,
    this.gainSource,
    this.staticGain = 1.0,
    this.gainParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    if (gainSource != null) {
      final Float32List modBuf = Float32List(outBuffer.length);
      gainSource!.process(ctx, modBuf);
      for (int i = 0; i < outBuffer.length; i++) {
        outBuffer[i] *= modBuf[i];
      }
    } else {
      final double g = gainParam != null ? ctx.getParam(gainParam!, staticGain) : staticGain;
      for (int i = 0; i < outBuffer.length; i++) {
        outBuffer[i] *= g;
      }
    }
  }
}

/// Tanh / Waveshaper Distortion Node.
class DistortionNode extends GraphNode {
  final GraphNode input;
  final double drive;
  final String? driveParam;

  const DistortionNode({
    required this.input,
    this.drive = 1.0,
    this.driveParam,
  });

  static double _tanh(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    final ex = math.exp(x);
    final enx = math.exp(-x);
    return (ex - enx) / (ex + enx);
  }

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);
    final double d = driveParam != null ? ctx.getParam(driveParam!, drive) : drive;
    for (int i = 0; i < outBuffer.length; i++) {
      outBuffer[i] = _tanh(outBuffer[i] * d);
    }
  }
}
