import 'dart:math' as math;
import 'dart:typed_data';

import 'graph_node.dart';
import 'tr909_rom_data.dart';
import 'piano_physical_tables.dart';
import '../dx7_fm_engine.dart';
import '../sid_dsp_engine.dart';

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
  final double? staticFreq;
  final GraphNode? fmModSource;

  const SineOscNode({
    this.freqSource,
    this.staticFreq,
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
    final double defaultFreq = staticFreq ?? (ctx.freq > 0 ? ctx.freq : 440.0);
    double phase = 0.0;

    for (int i = 0; i < len; i++) {
      final double baseF = freqBuf != null ? freqBuf[i] : defaultFreq;
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
  final double? staticFreq;

  const SawOscNode({this.freqSource, this.staticFreq});

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List? freqBuf = freqSource != null ? Float32List(len) : null;
    if (freqSource != null) freqSource!.process(ctx, freqBuf!);

    final double sr = ctx.sampleRate;
    final double defaultFreq = staticFreq ?? (ctx.freq > 0 ? ctx.freq : 440.0);
    double phase = 0.0;

    for (int i = 0; i < len; i++) {
      final double curF = freqBuf != null ? freqBuf[i] : defaultFreq;
      outBuffer[i] = 2.0 * phase - 1.0;
      phase = (phase + (curF / sr)) % 1.0;
    }
  }
}

/// Square / Pulse Oscillator.
class SquareOscNode extends GraphNode {
  final GraphNode? freqSource;
  final double? staticFreq;
  final double pulseWidth;

  const SquareOscNode({
    this.freqSource,
    this.staticFreq,
    this.pulseWidth = 0.5,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List? freqBuf = freqSource != null ? Float32List(len) : null;
    if (freqSource != null) freqSource!.process(ctx, freqBuf!);

    final double sr = ctx.sampleRate;
    final double defaultFreq = staticFreq ?? (ctx.freq > 0 ? ctx.freq : 440.0);
    double phase = 0.0;

    for (int i = 0; i < len; i++) {
      final double curF = freqBuf != null ? freqBuf[i] : defaultFreq;
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
    final Float32List bufB = ctx.acquireScratch(len);

    sourceA.process(ctx, outBuffer);
    sourceB.process(ctx, bufB);

    for (int i = 0; i < len; i++) {
      outBuffer[i] *= bufB[i];
    }
    ctx.releaseScratch();
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
    double actualDecay = math.max(
      0.001,
      decayParam != null ? ctx.getParam(decayParam!, decaySec) : decaySec,
    );

    final art = ctx.articulation?.toLowerCase();
    if (art == 'muted' || art == 'palm_mute' || art == 'staccato' || art == 'chop' || art == 'ghost') {
      actualDecay = math.min(actualDecay, 0.07);
    } else if (art == 'harmonics' || art == 'flageolet') {
      actualDecay = actualDecay * 1.4;
    }

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;

    for (int i = 0; i < len; i++) {
      final double t = i / sr;
      final double normTime = len > 1 ? i / (len - 1) : 0.0;
      final double press = ctx.pressurePoints != null ? ctx.getPressureAt(normTime) : 1.0;
      final double env = math.exp(-t * (4.0 / actualDecay));
      outBuffer[i] = env * press;
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
    final int len = outBuffer.length;

    final int aSamples = math.min(len, (a * sr).round());
    final int dSamples = math.min(len, ((a + d) * sr).round());
    final int gateSamples = math.min(len, (gate * sr).round());

    // 1. Attack Phase (0.0 to 1.0 linear ramp)
    if (aSamples > 0) {
      final double aStep = 1.0 / aSamples;
      for (int i = 0; i < aSamples; i++) {
        outBuffer[i] = (i * aStep).clamp(0.0, 1.0);
      }
    }

    // 2. Decay Phase (1.0 down to sustain)
    if (dSamples > aSamples) {
      final int dLen = dSamples - aSamples;
      final double dStep = (1.0 - s) / dLen;
      for (int i = aSamples; i < dSamples; i++) {
        outBuffer[i] = (1.0 - (i - aSamples) * dStep).clamp(0.0, 1.0);
      }
    }

    // 3. Sustain Phase
    if (gateSamples > dSamples) {
      outBuffer.fillRange(dSamples, gateSamples, s);
    }

    // 4. Release Phase (sustain down to 0.0)
    if (len > gateSamples) {
      final int rLen = math.max(1, (r * sr).round());
      final double rStep = s / rLen;
      for (int i = gateSamples; i < len; i++) {
        final double val = s - (i - gateSamples) * rStep;
        outBuffer[i] = val > 0.0 ? val : 0.0;
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

    final Float32List branchBuf = ctx.acquireScratch(len);
    for (int b = 0; b < inputs.length; b++) {
      inputs[b].process(ctx, branchBuf);
      final double g = (gains != null && b < gains!.length) ? gains![b] : 1.0;
      for (int i = 0; i < len; i++) {
        outBuffer[i] += branchBuf[i] * g;
      }
    }
    ctx.releaseScratch();
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
      final Float32List modBuf = ctx.acquireScratch(outBuffer.length);
      gainSource!.process(ctx, modBuf);
      for (int i = 0; i < outBuffer.length; i++) {
        outBuffer[i] *= modBuf[i];
      }
      ctx.releaseScratch();
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

// ─────────────────────────────────────────────────────────────────────────────
//  PHYSICAL MODELING & ACOUSTIC PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

/// Neoprene / Felt Hammer Impact Transient Exciter.
/// Synthesizes the mechanical strike transient of a piano/EP piano hammer against
/// a tuning fork/tine/string with velocity-dependent pulse width and hardness.
class HammerExciterNode extends GraphNode {
  final double hardness; // 0.1 (soft felt) to 2.0 (hard neoprene/wood)
  final String? hardnessParam;
  final double clickLevel;
  final String? clickLevelParam;

  const HammerExciterNode({
    this.hardness = 1.0,
    this.hardnessParam,
    this.clickLevel = 1.0,
    this.clickLevelParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double h = (hardnessParam != null ? ctx.getParam(hardnessParam!, hardness) : hardness).clamp(0.1, 4.0);
    final double click = (clickLevelParam != null ? ctx.getParam(clickLevelParam!, clickLevel) : clickLevel).clamp(0.0, 3.0);
    final double vel = ctx.velocity.clamp(0.1, 1.0);
    final double sr = ctx.sampleRate;

    // Contact duration shortens with higher velocity and harder hammer (0.8ms to 4.5ms)
    final double contactSec = (0.0035 / (math.pow(vel, 0.4) * h)).clamp(0.0004, 0.010);
    final int contactSamples = (contactSec * sr).toInt().clamp(4, outBuffer.length ~/ 2);

    outBuffer.fillRange(0, outBuffer.length, 0.0);

    // 1. Raised-cosine force pulse (Hertzian contact model)
    for (int i = 0; i < contactSamples; i++) {
      final double phase = (i / contactSamples) * math.pi;
      final double force = math.pow(math.sin(phase), 1.5 + (1.0 - vel) * 0.8).toDouble();
      outBuffer[i] = force * vel;
    }

    // 2. High-frequency micro-click transient (neoprene tip friction)
    if (click > 0.01) {
      int state = 0x5A5A5A5A ^ (ctx.midiNote * 73);
      final int clickLen = math.min(outBuffer.length, (0.004 * sr).toInt());
      for (int i = 0; i < clickLen; i++) {
        state ^= (state << 13) & 0xFFFFFFFF;
        state ^= (state >> 17) & 0xFFFFFFFF;
        state ^= (state << 5) & 0xFFFFFFFF;
        final double noise = ((state & 0xFFFFFF) / 8388607.5) - 1.0;
        final double env = math.exp(-i / (sr * 0.0008));
        outBuffer[i] += noise * env * click * 0.25 * vel;
      }
    }
  }
}

/// Plectrum / Guitar Pick Strum Exciter Node.
/// Models the rapid micro-brush of a guitar pick across multiple strings.
/// Produces a multi-tap comb impulse with adjustable strum spread (down/up stroke),
/// pick scrape noise, and velocity dynamics.
class PlectrumStrumExciterNode extends GraphNode {
  final double strumSpreadMs; // Strum duration across strings (2.0 to 25.0 ms)
  final String? strumSpreadParam;
  final double pickBite; // Pick attack transient brightness
  final String? pickBiteParam;

  const PlectrumStrumExciterNode({
    this.strumSpreadMs = 8.0,
    this.strumSpreadParam,
    this.pickBite = 1.0,
    this.pickBiteParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double spreadMs = (strumSpreadParam != null ? ctx.getParam(strumSpreadParam!, strumSpreadMs) : strumSpreadMs).clamp(1.0, 40.0);
    final double bite = (pickBiteParam != null ? ctx.getParam(pickBiteParam!, pickBite) : pickBite).clamp(0.0, 3.0);
    final double vel = ctx.velocity.clamp(0.1, 1.0);
    final double sr = ctx.sampleRate;

    outBuffer.fillRange(0, outBuffer.length, 0.0);

    // 4 string pluck taps representing a reggae chord chop brush
    const int numTaps = 4;
    final double tapSpacingSec = (spreadMs / 1000.0) / (numTaps - 1);

    for (int t = 0; t < numTaps; t++) {
      final double tapTime = t * tapSpacingSec;
      final int startSample = (tapTime * sr).toInt();
      if (startSample >= outBuffer.length) break;

      // Contact pulse
      final int pulseLen = ((0.0015 / (vel * bite + 0.2)) * sr).toInt().clamp(3, 120);
      final double tapGain = (0.7 + 0.3 * (t / numTaps)) * vel;

      for (int i = 0; i < pulseLen && (startSample + i) < outBuffer.length; i++) {
        final double phase = (i / pulseLen) * math.pi;
        final double pulse = math.sin(phase);
        outBuffer[startSample + i] += pulse * tapGain;
      }

      // Pick scrape noise
      int state = 0x1337BEEF ^ (ctx.midiNote * 37 + t * 91);
      final int scrapeLen = ((0.0025 * sr)).toInt();
      for (int i = 0; i < scrapeLen && (startSample + i) < outBuffer.length; i++) {
        state ^= (state << 13) & 0xFFFFFFFF;
        state ^= (state >> 17) & 0xFFFFFFFF;
        state ^= (state << 5) & 0xFFFFFFFF;
        final double noise = ((state & 0xFFFFFF) / 8388607.5) - 1.0;
        final double env = math.exp(-i / (sr * 0.0006));
        outBuffer[startSample + i] += noise * env * bite * 0.35 * vel;
      }
    }
  }
}

/// Asymmetric Magnetic Pickup Saturation.
/// Models the electromagnetic pickup behavior in Rhodes/Wurlitzer/Guitars.
/// As the vibrating metal tine/string swings closer to the magnet pole piece,
/// the magnetic flux changes non-linearly, generating warm 2nd-order even harmonics
/// and soft limiting on hard strikes.
class PickupSaturationNode extends GraphNode {
  final GraphNode input;
  final double distance; // Pickup distance: 0.1 (very close/barky) to 2.0 (far/mellow)
  final String? distanceParam;
  final double symmetry; // 0.0 (symmetric) to 1.0 (strong 2nd harmonic bark)
  final String? symmetryParam;

  const PickupSaturationNode({
    required this.input,
    this.distance = 1.0,
    this.distanceParam,
    this.symmetry = 0.65,
    this.symmetryParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double dist = (distanceParam != null ? ctx.getParam(distanceParam!, distance) : distance).clamp(0.1, 3.0);
    final double sym = (symmetryParam != null ? ctx.getParam(symmetryParam!, symmetry) : symmetry).clamp(0.0, 1.0);

    // Closer pickup -> higher drive & stronger magnetic non-linearity
    final double gain = 1.0 / math.sqrt(dist);
    final double alpha = 0.35 * sym * (1.5 / dist); // 2nd harmonic quadratic term
    final double beta = 0.15 * (1.0 / dist);        // 3rd harmonic cubic term

    for (int i = 0; i < outBuffer.length; i++) {
      final double x = outBuffer[i] * gain;
      // Asymmetric magnetic reluctance polynomial: y = x + alpha*x^2 - beta*x^3
      double y = x + (alpha * x * x.abs()) - (beta * x * x * x);
      // Soft-clip boundary
      if (y > 1.2) y = 1.2 + 0.1 * DistortionNode._tanh(y - 1.2);
      if (y < -1.2) y = -1.2 + 0.1 * DistortionNode._tanh(y + 1.2);
      outBuffer[i] = y * 0.9;
    }
  }
}

/// Parallel Modal Resonator Bank.
/// Emulates the mechanical resonant modes of acoustic bodies, soundboards,
/// tone bars, and xylophone/marimba bars using parallel 2nd-order bandpass resonators.
class ModalResonatorBankNode extends GraphNode {
  final GraphNode input;
  final List<double> modeFreqRatios; // Multipliers relative to fundamental
  final List<double> modeGains;       // Relative amplitude per mode
  final List<double> modeQFactors;    // Q factor (decay sharpness) per mode

  const ModalResonatorBankNode({
    required this.input,
    required this.modeFreqRatios,
    required this.modeGains,
    required this.modeQFactors,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List inBuf = Float32List(len);
    input.process(ctx, inBuf);
    outBuffer.fillRange(0, len, 0.0);

    final double baseF = ctx.freq > 0 ? ctx.freq : 440.0;
    final double sr = ctx.sampleRate;

    for (int m = 0; m < modeFreqRatios.length; m++) {
      final double ratio = modeFreqRatios[m];
      final double g = m < modeGains.length ? modeGains[m] : 0.5;
      final double q = m < modeQFactors.length ? modeQFactors[m] : 10.0;

      final double f = (baseF * ratio).clamp(20.0, sr * 0.48);
      final double w0 = 2.0 * math.pi * (f / sr);
      final double alpha = math.sin(w0) / (2.0 * q);

      final double b0 = alpha;
      final double b1 = 0.0;
      final double b2 = -alpha;
      final double a0 = 1.0 + alpha;
      final double a1 = -2.0 * math.cos(w0);
      final double a2 = 1.0 - alpha;

      final double normB0 = (b0 / a0) * g;
      final double normB1 = (b1 / a0) * g;
      final double normB2 = (b2 / a0) * g;
      final double normA1 = a1 / a0;
      final double normA2 = a2 / a0;

      double z1 = 0.0;
      double z2 = 0.0;

      for (int i = 0; i < len; i++) {
        final double inSample = inBuf[i];
        final double outSample = normB0 * inSample + z1;
        z1 = normB1 * inSample - normA1 * outSample + z2;
        z2 = normB2 * inSample - normA2 * outSample;
        outBuffer[i] += outSample;
      }
    }
  }
}

/// Digital Waveguide with 1-Pole Loop Loss Filtering (Karplus-Strong Extension).
/// Synthesizes acoustic strings, nylon/steel guitars, harps, and bowed physics.
class WaveguideNode extends GraphNode {
  final GraphNode exciter;
  final double feedback;
  final String? feedbackParam;
  final double damping; // High frequency damping (0.0 = bright, 1.0 = dark/muffled)
  final String? dampingParam;

  const WaveguideNode({
    required this.exciter,
    this.feedback = 0.995,
    this.feedbackParam,
    this.damping = 0.25,
    this.dampingParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    exciter.process(ctx, outBuffer);

    double baseFreq = ctx.freq > 10.0 ? ctx.freq : 440.0;
    final double sr = ctx.sampleRate;
    double fb = (feedbackParam != null ? ctx.getParam(feedbackParam!, feedback) : feedback).clamp(0.80, 0.9999);
    double damp = (dampingParam != null ? ctx.getParam(dampingParam!, damping) : damping).clamp(0.01, 0.95);

    final art = ctx.articulation?.toLowerCase();
    if (art == 'muted' || art == 'palm_mute' || art == 'chop') {
      damp = math.max(damp, 0.72);
      fb = math.min(fb, 0.94);
    } else if (art == 'harmonics' || art == 'flageolet') {
      baseFreq *= 2.0;
      fb = math.max(fb, 0.997);
      damp = math.min(damp, 0.12);
    } else if (art == 'slap' || art == 'pop') {
      damp = math.min(damp, 0.10);
      fb = math.max(fb, 0.992);
    } else if (art == 'open' || art == 'sustain' || art == 'lead') {
      damp = math.min(damp, 0.20);
      fb = math.max(fb, 0.996);
    } else if (art == 'hammer_on' || art == 'pull_off' || art == 'slide') {
      fb = math.max(fb, 0.995);
    }

    final double maxDelaySamples = sr / 20.0; // Support down to 20Hz
    final int bufSize = maxDelaySamples.toInt() + 16;
    final delayLine = Float32List(bufSize);
    int writeIdx = 0;
    double filterState = 0.0;

    for (int i = 0; i < len; i++) {
      final double inSample = outBuffer[i];
      final double normTime = len > 1 ? i / (len - 1) : 0.0;
      final double bendSemitones = ctx.getPitchBendAt(normTime);
      final double pressure = ctx.getPressureAt(normTime);
      final double timbre = ctx.getTimbreAt(normTime);

      final double curFreq = (baseFreq * math.pow(2.0, bendSemitones / 12.0)).clamp(20.0, 20000.0);
      final double delaySamples = (sr / curFreq).clamp(2.0, bufSize - 4.0);
      final int intDelay = delaySamples.floor();
      final double frac = delaySamples - intDelay;

      // Read from delay line with linear fractional interpolation
      final double readPos = writeIdx - delaySamples;
      double readIdxD = readPos >= 0 ? readPos : (readPos + bufSize);
      while (readIdxD >= bufSize) readIdxD -= bufSize;
      while (readIdxD < 0) readIdxD += bufSize;

      final int i0 = readIdxD.toInt() % bufSize;
      final int i1 = (i0 + 1) % bufSize;
      final double delayedSample = delayLine[i0] + frac * (delayLine[i1] - delayLine[i0]);

      // MPE dynamic damping & feedback modulation
      final double curDamp = (damp * (1.0 - (timbre - 0.5) * 0.4) + pressure * 0.15).clamp(0.01, 0.98);
      final double curFb = (fb * (1.0 - pressure * 0.04)).clamp(0.80, 0.9999);

      // 1-Pole Lowpass loop damping filter
      filterState = (1.0 - curDamp) * delayedSample + curDamp * filterState;
      final double loopSample = filterState * curFb;

      // Write excitation + recirculating string wave
      delayLine[writeIdx] = inSample + loopSample;
      writeIdx = (writeIdx + 1) % bufSize;

      outBuffer[i] = inSample + loopSample;
    }
  }
}

/// Vintage Optical Tremolo & Stereo Auto-Pan Node.
/// Models the iconic stereo suitcase Rhodes optical light/photocell vibrato circuit.
class StereoTremoloNode extends GraphNode {
  final GraphNode input;
  final double rateHz;
  final String? rateParam;
  final double depth;
  final String? depthParam;
  final double stereoPhaseOffset; // 0.0 (mono tremolo) to 1.0 (180° ping-pong auto-pan)

  const StereoTremoloNode({
    required this.input,
    this.rateHz = 4.5,
    this.rateParam,
    this.depth = 0.65,
    this.depthParam,
    this.stereoPhaseOffset = 1.0,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double rate = (rateParam != null ? ctx.getParam(rateParam!, rateHz) : rateHz).clamp(0.5, 15.0);
    final double dep = (depthParam != null ? ctx.getParam(depthParam!, depth) : depth).clamp(0.0, 1.0);
    final double sr = ctx.sampleRate;
    final double twoPi = 2.0 * math.pi;

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;
      // Optical light bulb rise/fall smoothing curve
      final double lfo = math.sin(twoPi * rate * t);
      final double lfoShaped = math.pow((lfo + 1.0) * 0.5, 1.2).toDouble();
      final double gainMod = (1.0 - dep) + dep * lfoShaped;
      outBuffer[i] *= gainMod;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HIGH-VOLTAGE ELECTRICITY & PLASMA DSP PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

/// Singing Plasma Arc Oscillator Node.
/// Synthesizes the acoustic shockwave generated by a modulated spark discharge.
/// Generates an asymmetric thermal expansion impulse with cycle-to-cycle stochastic jitter,
/// duty cycle (spark gap) control, and optional sub-harmonic frequency division.
class PlasmaArcOscNode extends GraphNode {
  final GraphNode? freqSource;
  final double? staticFreq;
  final double sparkWidth; // Duty cycle: 0.02 (sharp needle spark) to 0.5 (heavy buzzing arc)
  final String? sparkWidthParam;
  final double jitter; // Micro-stochastic jitter: 0.0 (clean digital) to 1.0 (violent arc tear)
  final String? jitterParam;
  final double subHarmonic; // Sub-octave plasma division: 0.0 to 1.0
  final String? subHarmonicParam;

  const PlasmaArcOscNode({
    this.freqSource,
    this.staticFreq,
    this.sparkWidth = 0.15,
    this.sparkWidthParam,
    this.jitter = 0.35,
    this.jitterParam,
    this.subHarmonic = 0.0,
    this.subHarmonicParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List? freqBuf = freqSource != null ? Float32List(len) : null;
    if (freqSource != null) freqSource!.process(ctx, freqBuf!);

    final double sr = ctx.sampleRate;
    final double defaultFreq = staticFreq ?? (ctx.freq > 0 ? ctx.freq : 220.0);
    final double baseWidth = (sparkWidthParam != null ? ctx.getParam(sparkWidthParam!, sparkWidth) : sparkWidth).clamp(0.02, 0.60);
    final double baseJitter = (jitterParam != null ? ctx.getParam(jitterParam!, jitter) : jitter).clamp(0.0, 1.0);
    final double sub = (subHarmonicParam != null ? ctx.getParam(subHarmonicParam!, subHarmonic) : subHarmonic).clamp(0.0, 1.0);

    double phase = 0.0;
    double subPhase = 0.0;
    int rngState = 0xDEADBEEF ^ (ctx.midiNote * 59);

    for (int i = 0; i < len; i++) {
      final double curF = freqBuf != null ? freqBuf[i] : defaultFreq;

      // Cycle-to-cycle micro-stochastic spark jitter (wobbles instantaneous period)
      rngState ^= (rngState << 13) & 0xFFFFFFFF;
      rngState ^= (rngState >> 17) & 0xFFFFFFFF;
      rngState ^= (rngState << 5) & 0xFFFFFFFF;
      final double rnd = ((rngState & 0xFFFFFF) / 8388607.5) - 1.0;
      final double jitterFactor = 1.0 + (rnd * baseJitter * 0.04);
      final double fInst = math.max(10.0, curF * jitterFactor);

      // Asymmetric thermal expansion pulse: sharp explosive leading edge + exponential cooling relaxation tail
      final double w = baseWidth;
      double sample = 0.0;
      if (phase < w) {
        final double normP = phase / w;
        sample = math.sin(normP * math.pi) * math.exp(-normP * 1.5);
      } else {
        final double normTail = (phase - w) / (1.0 - w);
        sample = -0.35 * math.exp(-normTail * 6.0) * math.sin(normTail * math.pi * 0.5);
      }

      // Add sub-harmonic sub-octave plasma rumble if configured
      if (sub > 0.001) {
        final double subSample = math.sin(subPhase * 2.0 * math.pi) * 0.6;
        sample = sample * (1.0 - sub * 0.4) + subSample * sub;
      }

      outBuffer[i] = sample.clamp(-1.0, 1.0);

      // Phase increment
      final double phaseInc = fInst / sr;
      phase += phaseInc;
      if (phase >= 1.0) phase -= 1.0;

      subPhase += (fInst * 0.5) / sr;
      if (subPhase >= 1.0) subPhase -= 1.0;
    }
  }
}

/// Stochastic Corona Discharge & Ion Sizzle Node.
/// Generates Poisson-distributed micro-spark impulses passed through highpass/bandpass
/// resonators, modeling high-voltage corona leakage and ion wind.
class PoissonCrackleNode extends GraphNode {
  final double density; // Micro-spark burst density: 0.0 to 1.0
  final String? densityParam;
  final double sizzleBright; // Brightness/cutoff of ionization: 0.0 to 1.0
  final String? sizzleBrightParam;

  const PoissonCrackleNode({
    this.density = 0.40,
    this.densityParam,
    this.sizzleBright = 0.70,
    this.sizzleBrightParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double dens = (densityParam != null ? ctx.getParam(densityParam!, density) : density).clamp(0.0, 1.0);
    final double bright = (sizzleBrightParam != null ? ctx.getParam(sizzleBrightParam!, sizzleBright) : sizzleBright).clamp(0.1, 1.0);

    if (dens <= 0.001) {
      outBuffer.fillRange(0, outBuffer.length, 0.0);
      return;
    }

    final double sr = ctx.sampleRate;
    final double threshold = (dens * 0.08) * (0.5 + 0.5 * ctx.velocity);
    int rngState = 0xCAFEBABE ^ (ctx.midiNote * 43);

    // 2-pole Highpass Filter for crisp air sizzle (~4.5kHz - 10kHz)
    final double cutoffHz = (3500.0 + bright * 6500.0).clamp(1000.0, sr * 0.45);
    final double w0 = 2.0 * math.pi * (cutoffHz / sr);
    final double alpha = math.sin(w0) / (2.0 * 1.8);
    final double cosW = math.cos(w0);

    final double b0 = (1.0 + cosW) / 2.0;
    final double b1 = -(1.0 + cosW);
    final double b2 = (1.0 + cosW) / 2.0;
    final double a0 = 1.0 + alpha;
    final double a1 = -2.0 * cosW;
    final double a2 = 1.0 - alpha;

    final double nb0 = b0 / a0;
    final double nb1 = b1 / a0;
    final double nb2 = b2 / a0;
    final double na1 = a1 / a0;
    final double na2 = a2 / a0;

    double x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;

    for (int i = 0; i < outBuffer.length; i++) {
      rngState ^= (rngState << 13) & 0xFFFFFFFF;
      rngState ^= (rngState >> 17) & 0xFFFFFFFF;
      rngState ^= (rngState << 5) & 0xFFFFFFFF;
      final double r0 = (rngState & 0xFFFFFF) / 16777215.0;

      double rawSpark = 0.0;
      if (r0 < threshold) {
        rngState ^= (rngState << 13) & 0xFFFFFFFF;
        final double r1 = ((rngState & 0xFFFFFF) / 8388607.5) - 1.0;
        rawSpark = r1 * (0.4 + 0.6 * r0 / threshold);
      }

      // Filter micro-spark through ionization resonator
      final double y = nb0 * rawSpark + nb1 * x1 + nb2 * x2 - na1 * y1 - na2 * y2;
      x2 = x1;
      x1 = rawSpark;
      y2 = y1;
      y1 = y;

      outBuffer[i] = (y * 1.8).clamp(-1.0, 1.0);
    }
  }
}

/// 50Hz/60Hz Substation Transformer Magnetostriction & Power Grid Hum Node.
/// Models the magnetic core vibration and ground bleed with rich odd harmonics
/// (60Hz, 180Hz, 300Hz, 420Hz) and subtle 120Hz magnetic flux ripple.
class SubstationHumNode extends GraphNode {
  static final Float32List _humTable = _buildHumTable();

  static Float32List _buildHumTable() {
    const int size = 2048;
    final table = Float32List(size);
    const double twoPi = 2.0 * math.pi;
    for (int i = 0; i < size; i++) {
      final double phase = i / size;
      final double rad = phase * twoPi;
      final double h1 = math.sin(rad) * 0.50;
      final double h2 = math.sin(rad * 2.0) * 0.35;
      final double h3 = math.sin(rad * 3.0) * 0.25;
      final double h5 = math.sin(rad * 5.0) * 0.15;
      final double h7 = math.sin(rad * 7.0) * 0.08;
      final double ripple = 0.85 + 0.15 * math.sin(rad * 2.0);
      table[i] = ((h1 + h2 + h3 + h5 + h7) * ripple).clamp(-1.0, 1.0);
    }
    return table;
  }

  final double humLevel; // 0.0 (clean isolated) to 1.0 (heavy industrial substation)
  final String? humLevelParam;
  final double mainsFreq; // 50.0 (EU) or 60.0 (US)
  final String? mainsFreqParam;

  const SubstationHumNode({
    this.humLevel = 0.35,
    this.humLevelParam,
    this.mainsFreq = 60.0,
    this.mainsFreqParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double level = (humLevelParam != null ? ctx.getParam(humLevelParam!, humLevel) : humLevel).clamp(0.0, 1.0);
    if (level <= 0.001) {
      outBuffer.fillRange(0, outBuffer.length, 0.0);
      return;
    }

    final double f0 = (mainsFreqParam != null ? ctx.getParam(mainsFreqParam!, mainsFreq) : mainsFreq).clamp(40.0, 70.0);
    final double sr = ctx.sampleRate;
    final double phaseStep = f0 / sr;
    double phase = 0.0;
    const int mask = 2047;

    for (int i = 0; i < outBuffer.length; i++) {
      final int idx = (phase * 2048.0).toInt() & mask;
      outBuffer[i] = _humTable[idx] * level;
      phase += phaseStep;
      if (phase >= 1.0) phase -= 1.0;
    }
  }
}

/// Dielectric Breakdown Snap & Sputter Exciter Node.
/// Synthesizes the explosive initial breakdown voltage snap on Note-On (attack)
/// and trailing plasma sputter as current collapses on Note-Off (release).
class BreakdownExciterNode extends GraphNode {
  final double snapLevel; // Attack snap intensity: 0.0 to 2.0
  final String? snapLevelParam;
  final double sputterDecay; // Extinction sputter time: 0.02 to 0.30s
  final String? sputterDecayParam;

  const BreakdownExciterNode({
    this.snapLevel = 1.0,
    this.snapLevelParam,
    this.sputterDecay = 0.06,
    this.sputterDecayParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double snap = (snapLevelParam != null ? ctx.getParam(snapLevelParam!, snapLevel) : snapLevel).clamp(0.0, 3.0);
    final double sputter = (sputterDecayParam != null ? ctx.getParam(sputterDecayParam!, sputterDecay) : sputterDecay).clamp(0.01, 0.40);
    final double sr = ctx.sampleRate;
    final double vel = ctx.velocity.clamp(0.1, 1.0);

    outBuffer.fillRange(0, outBuffer.length, 0.0);

    // 1. Initial Breakdown Snap (3ms sharp explosive pressure wave)
    if (snap > 0.01) {
      final int snapSamples = (0.0035 * sr).toInt().clamp(4, outBuffer.length ~/ 2);
      int rng = 0x19283746 ^ (ctx.midiNote * 67);
      final double decayStep = math.exp(-1.0 / (sr * 0.0007));
      double env = 1.0;
      final double freqStep = (math.pi * 3.0) / snapSamples;
      for (int i = 0; i < snapSamples; i++) {
        rng ^= (rng << 13) & 0xFFFFFFFF;
        rng ^= (rng >> 17) & 0xFFFFFFFF;
        rng ^= (rng << 5) & 0xFFFFFFFF;
        final double n = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;
        final double shockWave = math.sin(i * freqStep) * env;
        outBuffer[i] = (shockWave * 0.7 + n * 0.3 * env) * snap * vel;
        env *= decayStep;
      }
    }

    // 2. Trailing Plasma Extinguish Sputter near end of duration
    final double gateEnd = ctx.durationSec * 0.85;
    final int gateSample = (gateEnd * sr).toInt();
    if (gateSample < outBuffer.length) {
      int rng = 0x98765432 ^ (ctx.midiNote * 83);
      final int sputterLen = (sputter * sr).toInt().clamp(10, outBuffer.length - gateSample);
      final double decayStep = math.exp(-4.0 / sputterLen);
      double env = 1.0;
      for (int i = 0; i < sputterLen; i++) {
        final double tNorm = i / sputterLen;
        rng ^= (rng << 13) & 0xFFFFFFFF;
        rng ^= (rng >> 17) & 0xFFFFFFFF;
        rng ^= (rng << 5) & 0xFFFFFFFF;
        final double n = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;
        // Intermittent dying sparks
        if ((rng & 0xFF) < (120 * (1.0 - tNorm))) {
          outBuffer[gateSample + i] += n * env * 0.45 * vel;
        }
        env *= decayStep;
      }
    }
  }
}

/// Ozone & High-Voltage Dielectric Saturation Node.
/// Simulates non-linear plasma channel resistance and ozone dielectric saturation.
/// Asymmetric soft/hard curve with high-order odd/even harmonic generation.
class OzoneSaturationNode extends GraphNode {
  final GraphNode input;
  final double drive; // Overdrive intensity: 1.0 to 5.0
  final String? driveParam;
  final double bias; // Dielectric DC bias/asymmetry: 0.0 to 0.5
  final String? biasParam;

  const OzoneSaturationNode({
    required this.input,
    this.drive = 1.2,
    this.driveParam,
    this.bias = 0.12,
    this.biasParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double d = (driveParam != null ? ctx.getParam(driveParam!, drive) : drive).clamp(0.5, 8.0);
    final double b = (biasParam != null ? ctx.getParam(biasParam!, bias) : bias).clamp(0.0, 0.8);

    for (int i = 0; i < outBuffer.length; i++) {
      final double x = (outBuffer[i] + b) * d;
      // Arc non-linear resistance polynomial + smooth soft clip
      double y = x / (1.0 + x.abs());
      y = y - (b * 0.8); // Remove DC offset
      outBuffer[i] = (y * 1.15).clamp(-1.0, 1.0);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  THERMOACOUSTIC COMBUSTION & SINGING FLAME DSP PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

/// Thermoacoustic Singing Flame (Rijke Tube / Pyrophone) Oscillator Node.
/// Synthesizes acoustic standing waves generated by convective heat release inside
/// a tuned acoustic draft tube (Rayleigh thermoacoustic criterion).
/// Produces a warm, singing flame-front expansion wave with convective temperature
/// drift, flame cusp harmonics, and standing wave tube resonance.
class ThermoacousticFlameOscNode extends GraphNode {
  final GraphNode? freqSource;
  final double? staticFreq;
  final double flameCusp; // Flame-front non-linearity / harmonics: 0.0 to 1.0
  final String? flameCuspParam;
  final double thermalDrift; // Convection temperature wobble / shimmer: 0.0 to 1.0
  final String? thermalDriftParam;
  final double tubeResonance; // Glass cylinder acoustic purity: 0.0 to 1.0
  final String? tubeResonanceParam;

  const ThermoacousticFlameOscNode({
    this.freqSource,
    this.staticFreq,
    this.flameCusp = 0.45,
    this.flameCuspParam,
    this.thermalDrift = 0.30,
    this.thermalDriftParam,
    this.tubeResonance = 0.50,
    this.tubeResonanceParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List? freqBuf = freqSource != null ? Float32List(len) : null;
    if (freqSource != null) freqSource!.process(ctx, freqBuf!);

    final double sr = ctx.sampleRate;
    final double defaultFreq = staticFreq ?? (ctx.freq > 0 ? ctx.freq : 261.63);
    final double cusp = (flameCuspParam != null ? ctx.getParam(flameCuspParam!, flameCusp) : flameCusp).clamp(0.0, 1.0);
    final double drift = (thermalDriftParam != null ? ctx.getParam(thermalDriftParam!, thermalDrift) : thermalDrift).clamp(0.0, 1.0);
    final double reso = (tubeResonanceParam != null ? ctx.getParam(tubeResonanceParam!, tubeResonance) : tubeResonance).clamp(0.0, 1.0);

    double phase = 0.0;
    double lfoPhase = 0.0;
    int rngState = 0x51731942 ^ (ctx.midiNote * 53);

    for (int i = 0; i < len; i++) {
      final double curF = freqBuf != null ? freqBuf[i] : defaultFreq;

      // Convective thermal air-speed drift (slow 3.2Hz temperature wobble + micro-shimmer)
      rngState ^= (rngState << 13) & 0xFFFFFFFF;
      rngState ^= (rngState >> 17) & 0xFFFFFFFF;
      rngState ^= (rngState << 5) & 0xFFFFFFFF;
      final double noiseShimmer = ((rngState & 0xFFFFFF) / 8388607.5) - 1.0;
      final double lfoWobble = math.sin(lfoPhase * 2.0 * math.pi) * 0.7 + noiseShimmer * 0.3;
      final double driftFactor = 1.0 + (lfoWobble * drift * 0.015);
      final double fInst = math.max(10.0, curF * driftFactor);

      // Phase accumulator
      final double theta = phase * 2.0 * math.pi;

      // Flame Cusp Non-Linear Thermal Expansion Waveform:
      // Combines fundamental expansion sine with even (flame-front asymmetry) and odd (thermal damping) harmonics
      final double fund = math.sin(theta);
      final double h2 = math.sin(theta * 2.0) * (0.35 * cusp);
      final double h3 = -math.cos(theta * 3.0) * (0.15 * cusp);
      final double flameWave = fund + h2 + h3;

      // Glass / Brass Rijke tube standing wave resonant blend
      final double sample = flameWave * (1.0 - reso * 0.4) + fund * (reso * 0.4);

      outBuffer[i] = sample.clamp(-1.0, 1.0);

      phase += fInst / sr;
      if (phase >= 1.0) phase -= 1.0;

      lfoPhase += 3.2 / sr;
      if (lfoPhase >= 1.0) lfoPhase -= 1.0;
    }
  }
}

/// Turbulent Combustion Roar & Vortex Shedding Node.
/// Synthesizes the deep, low-frequency atmospheric roar of raging flames,
/// draft updrafts, and chaotic air vortex shedding (60Hz - 450Hz).
class CombustionRoarNode extends GraphNode {
  final double roarLevel; // 0.0 (silent) to 1.0 (roaring furnace)
  final String? roarLevelParam;
  final double draftFlutter; // Convective draft flutter speed/intensity: 0.0 to 1.0
  final String? draftFlutterParam;

  const CombustionRoarNode({
    this.roarLevel = 0.35,
    this.roarLevelParam,
    this.draftFlutter = 0.40,
    this.draftFlutterParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double level = (roarLevelParam != null ? ctx.getParam(roarLevelParam!, roarLevel) : roarLevel).clamp(0.0, 1.0);
    final double flutter = (draftFlutterParam != null ? ctx.getParam(draftFlutterParam!, draftFlutter) : draftFlutter).clamp(0.0, 1.0);

    if (level <= 0.001) {
      outBuffer.fillRange(0, outBuffer.length, 0.0);
      return;
    }

    final double sr = ctx.sampleRate;
    int rngState = 0x87654321 ^ (ctx.midiNote * 37);

    // Dual-band resonant bandpass filters for flame acoustic vortices (120Hz & 280Hz)
    final double w1 = 2.0 * math.pi * (120.0 / sr);
    final double a1 = math.sin(w1) / (2.0 * 2.2);
    final double cos1 = math.cos(w1);
    final double b0_1 = a1 / (1.0 + a1);
    final double b2_1 = -a1 / (1.0 + a1);
    final double a1_1 = (-2.0 * cos1) / (1.0 + a1);
    final double a2_1 = (1.0 - a1) / (1.0 + a1);

    final double w2 = 2.0 * math.pi * (280.0 / sr);
    final double a2 = math.sin(w2) / (2.0 * 1.8);
    final double cos2 = math.cos(w2);
    final double b0_2 = a2 / (1.0 + a2);
    final double b2_2 = -a2 / (1.0 + a2);
    final double a1_2 = (-2.0 * cos2) / (1.0 + a2);
    final double a2_2 = (1.0 - a2) / (1.0 + a2);

    double x1_1 = 0.0, x2_1 = 0.0, y1_1 = 0.0, y2_1 = 0.0;
    double x1_2 = 0.0, x2_2 = 0.0, y1_2 = 0.0, y2_2 = 0.0;
    double brownNoise = 0.0;

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;

      // Generate 1/f Brownian noise for turbulent thermal motion
      rngState ^= (rngState << 13) & 0xFFFFFFFF;
      rngState ^= (rngState >> 17) & 0xFFFFFFFF;
      rngState ^= (rngState << 5) & 0xFFFFFFFF;
      final double white = ((rngState & 0xFFFFFF) / 8388607.5) - 1.0;
      brownNoise = (brownNoise + (0.06 * white)) / 1.06;

      // Filter through resonant combustion cavities
      final double f1 = b0_1 * brownNoise + b2_1 * x2_1 - a1_1 * y1_1 - a2_1 * y2_1;
      x2_1 = x1_1;
      x1_1 = brownNoise;
      y2_1 = y1_1;
      y1_1 = f1;

      final double f2 = b0_2 * brownNoise + b2_2 * x2_2 - a1_2 * y1_2 - a2_2 * y2_2;
      x2_2 = x1_2;
      x1_2 = brownNoise;
      y2_2 = y1_2;
      y1_2 = f2;

      // Low-frequency convective thermal updraft flutter (3.5 Hz)
      final double draftMod = 0.70 + 0.30 * math.sin(2.0 * math.pi * 3.5 * t) * flutter;
      final double combined = (f1 * 1.6 + f2 * 1.2) * draftMod * level * 2.2;

      outBuffer[i] = combined.clamp(-1.0, 1.0);
    }
  }
}

/// Supercritical Wood Sap Pocket Explosions & Ember Crackle Matrix Node.
/// Synthesizes dual-stage Poisson stochastic micro-explosions:
/// 1. Low-frequency sap pocket steam bursts with damped wood cavity resonance (200Hz - 900Hz).
/// 2. High-frequency flying ember sizzle ticks (3.5kHz - 9.0kHz).
class SapExplosionCrackleNode extends GraphNode {
  final double sapDensity; // Resin pop density: 0.0 to 1.0
  final String? sapDensityParam;
  final double emberSizzle; // High ember spark density: 0.0 to 1.0
  final String? emberSizzleParam;

  const SapExplosionCrackleNode({
    this.sapDensity = 0.40,
    this.sapDensityParam,
    this.emberSizzle = 0.35,
    this.emberSizzleParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sap = (sapDensityParam != null ? ctx.getParam(sapDensityParam!, sapDensity) : sapDensity).clamp(0.0, 1.0);
    final double ember = (emberSizzleParam != null ? ctx.getParam(emberSizzleParam!, emberSizzle) : emberSizzle).clamp(0.0, 1.0);

    if (sap <= 0.001 && ember <= 0.001) {
      outBuffer.fillRange(0, outBuffer.length, 0.0);
      return;
    }

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;
    outBuffer.fillRange(0, len, 0.0);

    int rngState = 0xFEEDBEEF ^ (ctx.midiNote * 71);
    final double sapThreshold = (sap * 0.0015); // Sparse, explosive bursts
    final double emberThreshold = (ember * 0.045); // Dense, sizzling sparkles

    for (int i = 0; i < len; i++) {
      rngState ^= (rngState << 13) & 0xFFFFFFFF;
      rngState ^= (rngState >> 17) & 0xFFFFFFFF;
      rngState ^= (rngState << 5) & 0xFFFFFFFF;
      final double r0 = (rngState & 0xFFFFFF) / 16777215.0;

      // 1. Sap Pocket Steam Explosions (Damped 450Hz Cavity Resonant Pop)
      if (r0 < sapThreshold && (i + 350) < len) {
        rngState ^= (rngState << 13) & 0xFFFFFFFF;
        final double popAmp = 0.6 + 0.4 * ((rngState & 0xFFFF) / 65535.0);
        final int popSamples = (0.012 * sr).toInt();
        for (int p = 0; p < popSamples && (i + p) < len; p++) {
          final double tP = p / sr;
          final double popEnv = math.exp(-tP * 280.0);
          final double popTone = math.sin(2.0 * math.pi * 480.0 * tP) * popEnv;
          outBuffer[i + p] += popTone * popAmp * sap;
        }
      }

      // 2. High Ember Spark Sizzles (Fast 6.5kHz Micro-Impulses)
      if (r0 < emberThreshold) {
        rngState ^= (rngState << 13) & 0xFFFFFFFF;
        final double sparkAmp = ((rngState & 0xFFFFFF) / 8388607.5) - 1.0;
        outBuffer[i] += sparkAmp * ember * 0.35;
      }
    }

    // Clamp bounds
    for (int i = 0; i < len; i++) {
      outBuffer[i] = outBuffer[i].clamp(-1.0, 1.0);
    }
  }
}

/// Deflagration Flashover Ignition & Smoldering Ember Exciter Node.
/// Synthesizes the sudden low-frequency explosive air-intake rush (*"foomph/whoosh"*)
/// on Note-On (ignition) and trailing smoldering charcoal decay on Note-Off (extinction).
class DeflagrationExciterNode extends GraphNode {
  final double snapLevel; // Ignition whoosh intensity: 0.0 to 2.5
  final String? snapLevelParam;
  final double smolderDecay; // Extinction smolder time: 0.02 to 0.40s
  final String? smolderDecayParam;

  const DeflagrationExciterNode({
    this.snapLevel = 0.85,
    this.snapLevelParam,
    this.smolderDecay = 0.08,
    this.smolderDecayParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double snap = (snapLevelParam != null ? ctx.getParam(snapLevelParam!, snapLevel) : snapLevel).clamp(0.0, 3.0);
    final double smolder = (smolderDecayParam != null ? ctx.getParam(smolderDecayParam!, smolderDecay) : smolderDecay).clamp(0.01, 0.50);
    final double sr = ctx.sampleRate;
    final double vel = ctx.velocity.clamp(0.1, 1.0);

    outBuffer.fillRange(0, outBuffer.length, 0.0);

    // 1. Initial Ignition Deflagration Whoosh (35ms pitch drop from 160Hz to 45Hz)
    if (snap > 0.01) {
      final int flashSamples = (0.040 * sr).toInt().clamp(10, outBuffer.length ~/ 2);
      int rng = 0x31415926 ^ (ctx.midiNote * 61);
      for (int i = 0; i < flashSamples; i++) {
        final double tNorm = i / flashSamples;
        final double env = math.sin(tNorm * math.pi) * math.exp(-tNorm * 2.5);
        final double curPitch = 45.0 + 115.0 * math.exp(-tNorm * 8.0);
        final double phase = (i / sr) * 2.0 * math.pi * curPitch;
        rng ^= (rng << 13) & 0xFFFFFFFF;
        rng ^= (rng >> 17) & 0xFFFFFFFF;
        rng ^= (rng << 5) & 0xFFFFFFFF;
        final double noise = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;
        final double whoosh = (math.sin(phase) * 0.7 + noise * 0.3) * env;
        outBuffer[i] = (whoosh * snap * vel).clamp(-1.0, 1.0);
      }
    }

    // 2. Trailing Smoldering Charcoal Decay near end of duration
    final double gateEnd = ctx.durationSec * 0.85;
    final int gateSample = (gateEnd * sr).toInt();
    if (gateSample < outBuffer.length) {
      int rng = 0x27182818 ^ (ctx.midiNote * 79);
      final int smolderLen = (smolder * sr).toInt().clamp(10, outBuffer.length - gateSample);
      for (int i = 0; i < smolderLen; i++) {
        final double tNorm = i / smolderLen;
        final double env = math.exp(-tNorm * 4.5);
        rng ^= (rng << 13) & 0xFFFFFFFF;
        rng ^= (rng >> 17) & 0xFFFFFFFF;
        rng ^= (rng << 5) & 0xFFFFFFFF;
        final double n = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;
        outBuffer[gateSample + i] += (n * env * 0.30 * vel).clamp(-1.0, 1.0);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HYDRODYNAMIC FLUID & HYDRAULOPHONE WATER DSP PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

/// Hydraulophone & Minnaert Bubble Cavitation Oscillator Node.
/// Synthesizes fluid acoustic standing waves generated by a pressurized waterjet column
/// and entrained air bubble pinch-off dynamics (Minnaert bubble resonance).
/// Produces a liquid-glass fundamental with upward pinch-off frequency chirp,
/// surface-tension hydrodynamic waveshaping, and fluid current drift.
class HydraulophoneOscNode extends GraphNode {
  final GraphNode? freqSource;
  final double? staticFreq;
  final double bubbleChirp; // Minnaert bubble pinch-off chirp intensity: 0.0 to 1.0
  final String? bubbleChirpParam;
  final double viscosity; // Fluid viscosity & surface-tension damping: 0.0 to 1.0
  final String? viscosityParam;
  final double currentDrift; // Fluid current undulating pitch drift: 0.0 to 1.0
  final String? currentDriftParam;

  const HydraulophoneOscNode({
    this.freqSource,
    this.staticFreq,
    this.bubbleChirp = 0.45,
    this.bubbleChirpParam,
    this.viscosity = 0.40,
    this.viscosityParam,
    this.currentDrift = 0.35,
    this.currentDriftParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List? freqBuf = freqSource != null ? Float32List(len) : null;
    if (freqSource != null) freqSource!.process(ctx, freqBuf!);

    final double sr = ctx.sampleRate;
    final double defaultFreq = staticFreq ?? (ctx.freq > 0 ? ctx.freq : 261.63);
    final double chirp = (bubbleChirpParam != null ? ctx.getParam(bubbleChirpParam!, bubbleChirp) : bubbleChirp).clamp(0.0, 1.0);
    final double visc = (viscosityParam != null ? ctx.getParam(viscosityParam!, viscosity) : viscosity).clamp(0.0, 1.0);
    final double drift = (currentDriftParam != null ? ctx.getParam(currentDriftParam!, currentDrift) : currentDrift).clamp(0.0, 1.0);

    double phase = 0.0;
    double lfoPhase = 0.0;
    int rngState = 0x48796472 ^ (ctx.midiNote * 47); // "Hydr" seed

    for (int i = 0; i < len; i++) {
      final double curF = freqBuf != null ? freqBuf[i] : defaultFreq;

      // Hydrodynamic current undulating drift (2.4Hz water wave drift + micro-eddy wobble)
      rngState ^= (rngState << 13) & 0xFFFFFFFF;
      rngState ^= (rngState >> 17) & 0xFFFFFFFF;
      rngState ^= (rngState << 5) & 0xFFFFFFFF;
      final double ripple = ((rngState & 0xFFFFFF) / 8388607.5) - 1.0;
      final double waveDrift = math.sin(lfoPhase * 2.0 * math.pi) * 0.75 + ripple * 0.25;
      final double driftFactor = 1.0 + (waveDrift * drift * 0.012);

      // Minnaert bubble pinch-off frequency chirp (instantaneous frequency sweeps upward as bubble pinches off)
      final double chirpMod = 1.0 + (chirp * 0.18 * math.exp(-phase * 4.5));
      final double fInst = math.max(10.0, curF * driftFactor * chirpMod);

      // Surface-Tension Hydrodynamic Wave:
      // Rounded bell-like pressure pulse with smooth hydrodynamic return
      final double theta = phase * 2.0 * math.pi;
      final double sineWave = math.sin(theta);
      // Fluid viscosity rounds off high-frequency harmonics into a warm liquid tone
      final double dropletCusp = math.sin(theta + 0.3 * chirp * math.sin(theta));
      final double sample = dropletCusp * (1.0 - visc * 0.5) + sineWave * (visc * 0.5);

      outBuffer[i] = sample.clamp(-1.0, 1.0);

      phase += fInst / sr;
      if (phase >= 1.0) phase -= 1.0;

      lfoPhase += 2.4 / sr;
      if (lfoPhase >= 1.0) lfoPhase -= 1.0;
    }
  }
}

/// Hydrodynamic Vortex & Whirlpool Churn Node.
/// Synthesizes the deep, flowing acoustic roar of swirling water, submerged eddies,
/// and whirlpool turbulence (50Hz - 350Hz).
class HydrodynamicVortexNode extends GraphNode {
  final double vortexLevel; // Fluid churn volume: 0.0 to 1.0
  final String? vortexLevelParam;
  final double churnSpeed; // Flow velocity / wave modulation: 0.0 to 1.0
  final String? churnSpeedParam;

  const HydrodynamicVortexNode({
    this.vortexLevel = 0.35,
    this.vortexLevelParam,
    this.churnSpeed = 0.40,
    this.churnSpeedParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double level = (vortexLevelParam != null ? ctx.getParam(vortexLevelParam!, vortexLevel) : vortexLevel).clamp(0.0, 1.0);
    final double speed = (churnSpeedParam != null ? ctx.getParam(churnSpeedParam!, churnSpeed) : churnSpeed).clamp(0.0, 1.0);

    if (level <= 0.001) {
      outBuffer.fillRange(0, outBuffer.length, 0.0);
      return;
    }

    final double sr = ctx.sampleRate;
    int rngState = 0x90817263 ^ (ctx.midiNote * 31);

    // Dual-band submerged acoustic cavity filters (95Hz & 220Hz)
    final double w1 = 2.0 * math.pi * (95.0 / sr);
    final double a1 = math.sin(w1) / (2.0 * 2.5);
    final double cos1 = math.cos(w1);
    final double b0_1 = a1 / (1.0 + a1);
    final double b2_1 = -a1 / (1.0 + a1);
    final double a1_1 = (-2.0 * cos1) / (1.0 + a1);
    final double a2_1 = (1.0 - a1) / (1.0 + a1);

    final double w2 = 2.0 * math.pi * (220.0 / sr);
    final double a2 = math.sin(w2) / (2.0 * 2.0);
    final double cos2 = math.cos(w2);
    final double b0_2 = a2 / (1.0 + a2);
    final double b2_2 = -a2 / (1.0 + a2);
    final double a1_2 = (-2.0 * cos2) / (1.0 + a2);
    final double a2_2 = (1.0 - a2) / (1.0 + a2);

    double x1_1 = 0.0, x2_1 = 0.0, y1_1 = 0.0, y2_1 = 0.0;
    double x1_2 = 0.0, x2_2 = 0.0, y1_2 = 0.0, y2_2 = 0.0;
    double brownNoise = 0.0;

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;

      // Brownian noise integration for viscous fluid flow
      rngState ^= (rngState << 13) & 0xFFFFFFFF;
      rngState ^= (rngState >> 17) & 0xFFFFFFFF;
      rngState ^= (rngState << 5) & 0xFFFFFFFF;
      final double white = ((rngState & 0xFFFFFF) / 8388607.5) - 1.0;
      brownNoise = (brownNoise + (0.05 * white)) / 1.05;

      // Filter through resonant hydrodynamic cavities
      final double f1 = b0_1 * brownNoise + b2_1 * x2_1 - a1_1 * y1_1 - a2_1 * y2_1;
      x2_1 = x1_1;
      x1_1 = brownNoise;
      y2_1 = y1_1;
      y1_1 = f1;

      final double f2 = b0_2 * brownNoise + b2_2 * x2_2 - a1_2 * y1_2 - a2_2 * y2_2;
      x2_2 = x1_2;
      x1_2 = brownNoise;
      y2_2 = y1_2;
      y1_2 = f2;

      // 2.8Hz swirling whirlpool wave modulation
      final double whirlMod = 0.70 + 0.30 * math.sin(2.0 * math.pi * 2.8 * t) * speed;
      final double combined = (f1 * 1.7 + f2 * 1.3) * whirlMod * level * 2.4;

      outBuffer[i] = combined.clamp(-1.0, 1.0);
    }
  }
}

/// Droplet Splash & Cavitation Matrix Node.
/// Synthesizes dual-stage Poisson stochastic fluid events:
/// 1. Macro Droplets: Resonant Minnaert bubble plinks & bloops ($550\,\text{Hz} - 1.6\,\text{kHz}$) with upward pitch chirp.
/// 2. Micro Spray & Foam: High-frequency surface bubbling foam and water spray ($4.0\,\text{kHz} - 10\,\text{kHz}$).
class DropletSplashMatrixNode extends GraphNode {
  final double dropletRate; // Water drop plink burst density: 0.0 to 1.0
  final String? dropletRateParam;
  final double sprayHiss; // High spray & foam shimmer: 0.0 to 1.0
  final String? sprayHissParam;

  const DropletSplashMatrixNode({
    this.dropletRate = 0.40,
    this.dropletRateParam,
    this.sprayHiss = 0.35,
    this.sprayHissParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double drops = (dropletRateParam != null ? ctx.getParam(dropletRateParam!, dropletRate) : dropletRate).clamp(0.0, 1.0);
    final double spray = (sprayHissParam != null ? ctx.getParam(sprayHissParam!, sprayHiss) : sprayHiss).clamp(0.0, 1.0);

    if (drops <= 0.001 && spray <= 0.001) {
      outBuffer.fillRange(0, outBuffer.length, 0.0);
      return;
    }

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;
    outBuffer.fillRange(0, len, 0.0);

    int rngState = 0x1A2B3C4D ^ (ctx.midiNote * 67);
    final double dropThreshold = (drops * 0.0018); // Sparse, plinking liquid drops
    final double sprayThreshold = (spray * 0.050); // Shimmering fluid spray

    for (int i = 0; i < len; i++) {
      rngState ^= (rngState << 13) & 0xFFFFFFFF;
      rngState ^= (rngState >> 17) & 0xFFFFFFFF;
      rngState ^= (rngState << 5) & 0xFFFFFFFF;
      final double r0 = (rngState & 0xFFFFFF) / 16777215.0;

      // 1. Minnaert Bubble Plinks & Bloops (Sweeping pitch chirp from 550Hz to 950Hz)
      if (r0 < dropThreshold && (i + 450) < len) {
        rngState ^= (rngState << 13) & 0xFFFFFFFF;
        final double dropAmp = 0.5 + 0.5 * ((rngState & 0xFFFF) / 65535.0);
        final int dropSamples = (0.016 * sr).toInt();
        for (int p = 0; p < dropSamples && (i + p) < len; p++) {
          final double tP = p / sr;
          final double dropEnv = math.exp(-tP * 220.0);
          final double fP = 550.0 + 400.0 * (1.0 - math.exp(-tP * 180.0));
          final double dropTone = math.sin(2.0 * math.pi * fP * tP) * dropEnv;
          outBuffer[i + p] += dropTone * dropAmp * drops * 0.85;
        }
      }

      // 2. Micro Spray & Surface Foam Sizzle (Fast 5.5kHz fluid impulses)
      if (r0 < sprayThreshold) {
        rngState ^= (rngState << 13) & 0xFFFFFFFF;
        final double sprayAmp = ((rngState & 0xFFFFFF) / 8388607.5) - 1.0;
        outBuffer[i] += sprayAmp * spray * 0.28;
      }
    }

    // Clamp bounds
    for (int i = 0; i < len; i++) {
      outBuffer[i] = outBuffer[i].clamp(-1.0, 1.0);
    }
  }
}

/// Hydrodynamic Plunge Impact & Submerged Wake Exciter Node.
/// Synthesizes the sudden crown splash impact transient on Note-On (water displacement snap)
/// and trailing submerged wake bubbles on Note-Off.
class PlungeImpactExciterNode extends GraphNode {
  final double snapLevel; // Plunge impact snap intensity: 0.0 to 2.5
  final String? snapLevelParam;
  final double wakeDecay; // Submerged wake bubble decay time: 0.02 to 0.40s
  final String? wakeDecayParam;

  const PlungeImpactExciterNode({
    this.snapLevel = 0.85,
    this.snapLevelParam,
    this.wakeDecay = 0.09,
    this.wakeDecayParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double snap = (snapLevelParam != null ? ctx.getParam(snapLevelParam!, snapLevel) : snapLevel).clamp(0.0, 3.0);
    final double wake = (wakeDecayParam != null ? ctx.getParam(wakeDecayParam!, wakeDecay) : wakeDecay).clamp(0.01, 0.50);
    final double sr = ctx.sampleRate;
    final double vel = ctx.velocity.clamp(0.1, 1.0);

    outBuffer.fillRange(0, outBuffer.length, 0.0);

    // 1. Initial Crown Splash Plunge Transient (30ms hydrodynamic displacement pulse)
    if (snap > 0.01) {
      final int plungeSamples = (0.030 * sr).toInt().clamp(8, outBuffer.length ~/ 2);
      int rng = 0x504C554E ^ (ctx.midiNote * 59); // "PLUN" seed
      for (int i = 0; i < plungeSamples; i++) {
        final double tNorm = i / plungeSamples;
        final double env = math.sin(tNorm * math.pi) * math.exp(-tNorm * 3.0);
        final double curPitch = 120.0 + 380.0 * (1.0 - tNorm);
        final double phase = (i / sr) * 2.0 * math.pi * curPitch;
        rng ^= (rng << 13) & 0xFFFFFFFF;
        rng ^= (rng >> 17) & 0xFFFFFFFF;
        rng ^= (rng << 5) & 0xFFFFFFFF;
        final double noise = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;
        final double splash = (math.sin(phase) * 0.75 + noise * 0.25) * env;
        outBuffer[i] = (splash * snap * vel).clamp(-1.0, 1.0);
      }
    }

    // 2. Trailing Submerged Wake Bubbles near end of duration
    final double gateEnd = ctx.durationSec * 0.85;
    final int gateSample = (gateEnd * sr).toInt();
    if (gateSample < outBuffer.length) {
      int rng = 0x57414B45 ^ (ctx.midiNote * 73); // "WAKE" seed
      final int wakeLen = (wake * sr).toInt().clamp(10, outBuffer.length - gateSample);
      for (int i = 0; i < wakeLen; i++) {
        final double tNorm = i / wakeLen;
        final double env = math.exp(-tNorm * 4.0);
        rng ^= (rng << 13) & 0xFFFFFFFF;
        rng ^= (rng >> 17) & 0xFFFFFFFF;
        rng ^= (rng << 5) & 0xFFFFFFFF;
        final double n = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;
        outBuffer[gateSample + i] += (n * env * 0.25 * vel).clamp(-1.0, 1.0);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ANALOG-MODELED ALL-PASS PHASER & PHASE DISPERSION
// ─────────────────────────────────────────────────────────────────────────────

/// 4-Stage Analog-Modeled All-Pass Phaser Node.
/// Cascades 4 first-order allpass filters ($H(z) = \frac{a_1 + z^{-1}}{1 + a_1 z^{-1}}$) with an LFO
/// modulating the notch frequencies, resonant feedback, and dry/wet mixing.
/// Creates dynamic acoustic phase cancellations and moving comb notches that eliminate
/// static fundamental drone on low notes (e.g. C2) and impart organic physical motion.
class PhaserNode extends GraphNode {
  final GraphNode input;
  final double rate; // Modulation speed in Hz: 0.05 to 10.0
  final String? rateParam;
  final double depth; // Sweep depth / frequency span: 0.0 to 1.0
  final String? depthParam;
  final double feedback; // Resonant phase notch feedback: 0.0 to 0.85
  final String? feedbackParam;
  final double mix; // Wet/dry blend: 0.0 to 1.0 (0.5 = maximum notch cancellation)
  final String? mixParam;
  final double baseFreq; // Base center frequency in Hz (default 650.0)

  const PhaserNode({
    required this.input,
    this.rate = 0.5,
    this.rateParam,
    this.depth = 0.65,
    this.depthParam,
    this.feedback = 0.40,
    this.feedbackParam,
    this.mix = 0.50,
    this.mixParam,
    this.baseFreq = 650.0,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double curRate = (rateParam != null ? ctx.getParam(rateParam!, rate) : rate).clamp(0.02, 20.0);
    final double curDepth = (depthParam != null ? ctx.getParam(depthParam!, depth) : depth).clamp(0.0, 1.0);
    final double curFb = (feedbackParam != null ? ctx.getParam(feedbackParam!, feedback) : feedback).clamp(0.0, 0.90);
    final double curMix = (mixParam != null ? ctx.getParam(mixParam!, mix) : mix).clamp(0.0, 1.0);

    if (curMix <= 0.001) return; // Completely dry bypass

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;

    // 4 first-order allpass filter states: x1[k] and y1[k]
    double x1_0 = 0.0, y1_0 = 0.0;
    double x1_1 = 0.0, y1_1 = 0.0;
    double x1_2 = 0.0, y1_2 = 0.0;
    double x1_3 = 0.0, y1_3 = 0.0;
    double lastOut = 0.0;

    double lfoPhase = 0.0;

    const int kBlockSize = 16;
    double a1 = 0.0;
    double targetA1 = 0.0;
    double a1Inc = 0.0;

    for (int i = 0; i < len; i++) {
      final double dry = outBuffer[i];

      // Update modulation coefficients at sub-block control rate (every 16 samples = 0.36ms @ 44.1kHz)
      if ((i & (kBlockSize - 1)) == 0) {
        final double lfo = 0.5 + 0.5 * math.sin(lfoPhase * 2.0 * math.pi);
        final double fSweep = baseFreq * (0.35 + curDepth * 3.5 * lfo);
        final double fc = fSweep.clamp(40.0, sr * 0.45);
        final double w = math.tan(math.pi * fc / sr);
        targetA1 = (w - 1.0) / (w + 1.0);
        if (i == 0) {
          a1 = targetA1;
          a1Inc = 0.0;
        } else {
          a1Inc = (targetA1 - a1) / kBlockSize;
        }
      } else {
        a1 += a1Inc;
      }

      // Safety protection against feedback runaway or NaN
      if (lastOut.isNaN || lastOut.isInfinite) {
        lastOut = 0.0;
      } else if (lastOut > 4.0) {
        lastOut = 4.0;
      } else if (lastOut < -4.0) {
        lastOut = -4.0;
      }

      // Input with feedback loop
      final double inSample = dry + (lastOut * curFb);

      // Stage 1
      final double ap1 = a1 * inSample + x1_0 - a1 * y1_0;
      x1_0 = inSample;
      y1_0 = ap1;

      // Stage 2
      final double ap2 = a1 * ap1 + x1_1 - a1 * y1_1;
      x1_1 = ap1;
      y1_1 = ap2;

      // Stage 3
      final double ap3 = a1 * ap2 + x1_2 - a1 * y1_2;
      x1_2 = ap2;
      y1_2 = ap3;

      // Stage 4
      final double ap4 = a1 * ap3 + x1_3 - a1 * y1_3;
      x1_3 = ap3;
      y1_3 = ap4;

      lastOut = ap4;

      // Sum Dry and Wet (curMix = 0.5 creates deep notch cancellations)
      final double wetSample = (dry * (1.0 - curMix * 0.5)) + (ap4 * curMix * 0.7);
      outBuffer[i] = wetSample.clamp(-1.0, 1.0);

      lfoPhase += curRate / sr;
      if (lfoPhase >= 1.0) lfoPhase -= 1.0;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  YAMAHA DX7 6-OPERATOR FM SYNTHESIS NODE
// ─────────────────────────────────────────────────────────────────────────────

/// Complete 6-Operator FM Synthesis Graph Node wrapping the DX7 FM Engine.
/// Dynamically maps context parameters (Algorithm, Brightness, TineBell, Detune, Chorus, 12BitDAC).
class DX7VoiceNode extends GraphNode {
  final int algorithm;
  final String? algorithmParam;
  final int feedback;
  final String? feedbackParam;
  final String? patchParam;
  final double brightness;
  final String? brightnessParam;
  final double tineBell;
  final String? tineBellParam;
  final double bodyWarmth;
  final String? bodyWarmthParam;
  final double chorusMix;
  final String? chorusMixParam;
  final bool enable12BitDac;

  const DX7VoiceNode({
    this.algorithm = 5,
    this.algorithmParam,
    this.feedback = 6,
    this.feedbackParam,
    this.patchParam,
    this.brightness = 1.0,
    this.brightnessParam,
    this.tineBell = 0.85,
    this.tineBellParam,
    this.bodyWarmth = 1.0,
    this.bodyWarmthParam,
    this.chorusMix = 0.35,
    this.chorusMixParam,
    this.enable12BitDac = true,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int alg = (algorithmParam != null ? ctx.getParam(algorithmParam!, algorithm.toDouble()) : algorithm.toDouble()).round().clamp(1, 32);
    final int fb = (feedbackParam != null ? ctx.getParam(feedbackParam!, feedback.toDouble()) : feedback.toDouble()).round().clamp(0, 7);
    final double bright = (brightnessParam != null ? ctx.getParam(brightnessParam!, brightness) : brightness).clamp(0.0, 3.0);
    final double bell = (tineBellParam != null ? ctx.getParam(tineBellParam!, tineBell) : tineBell).clamp(0.0, 3.0);
    final double body = (bodyWarmthParam != null ? ctx.getParam(bodyWarmthParam!, bodyWarmth) : bodyWarmth).clamp(0.0, 3.0);
    final double chorus = (chorusMixParam != null ? ctx.getParam(chorusMixParam!, chorusMix) : chorusMix).clamp(0.0, 1.0);

    final voice = DX7FmVoice(algorithm: alg, feedback: fb);

    // Optional Patch selection (e.g. 0 = EPiano1, 1 = Bass1, 2 = TubBells, 3 = Strings1, 4 = SynLead5, 5 = Marimba)
    final patchVal = patchParam != null ? ctx.getParam(patchParam!, -1.0) : (ctx.params['Patch'] ?? -1.0);
    if (patchVal >= 0.0) {
      final pIdx = patchVal.round();
      switch (pIdx) {
        case 0: voice.loadPatch(DX7FactoryPatches.epiano1); break;
        case 1: voice.loadPatch(DX7FactoryPatches.bass1); break;
        case 2: voice.loadPatch(DX7FactoryPatches.tubBells); break;
        case 3: voice.loadPatch(DX7FactoryPatches.strings1); break;
        case 4: voice.loadPatch(DX7FactoryPatches.synLead5); break;
        case 5: voice.loadPatch(DX7FactoryPatches.marimba); break;
      }
    }

    // Apply algorithm/timbre overrides
    voice.algorithm = alg;
    voice.feedback = fb;
    voice.brightness = bright;
    voice.tineBell = bell;
    voice.bodyWarmth = body;
    voice.chorusMix = chorus;
    voice.enable12BitDac = enable12BitDac;

    // Direct register writes if provided
    for (final entry in ctx.params.entries) {
      if (entry.key.startsWith('reg_0x') || entry.key.startsWith('0x')) {
        final regHex = entry.key.replaceFirst('reg_', '');
        final regAddr = int.tryParse(regHex);
        if (regAddr != null) {
          voice.writeRegister(regAddr, entry.value.toInt());
        }
      }
    }

    voice.processBuffer(
      outBuffer: outBuffer,
      baseFreq: ctx.freq > 0 ? ctx.freq : 440.0,
      sampleRate: ctx.sampleRate,
      durationSec: ctx.durationSec,
      velocity: ctx.velocity,
      midiNote: ctx.midiNote,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMMODORE 64 SID (MOS 6581 / 8580) GRAPH NODE
// ─────────────────────────────────────────────────────────────────────────────

/// High-accuracy physical model of the MOS 6581 / 8580 SID Sound Interface Device.
class SIDVoiceNode extends GraphNode {
  final SIDWaveform waveform;
  final String? waveformParam;
  final SIDChipModel chipModel;
  final String? chipModelParam;
  final SIDFilterMode filterMode;
  final String? filterModeParam;
  final double cutoff;
  final String? cutoffParam;
  final double resonance;
  final String? resonanceParam;
  final double pulseWidth;
  final String? pulseWidthParam;
  final double pwmRate;
  final String? pwmRateParam;
  final double pwmDepth;
  final String? pwmDepthParam;
  final SIDArpMode arpMode;
  final String? arpModeParam;
  final double glideSpeed;
  final String? glideSpeedParam;
  final double overdrive;
  final String? overdriveParam;

  const SIDVoiceNode({
    this.waveform = SIDWaveform.pulse,
    this.waveformParam,
    this.chipModel = SIDChipModel.mos6581,
    this.chipModelParam,
    this.filterMode = SIDFilterMode.lowpass,
    this.filterModeParam,
    this.cutoff = 1200.0,
    this.cutoffParam,
    this.resonance = 8.0,
    this.resonanceParam,
    this.pulseWidth = 2048.0,
    this.pulseWidthParam,
    this.pwmRate = 1.6,
    this.pwmRateParam,
    this.pwmDepth = 0.45,
    this.pwmDepthParam,
    this.arpMode = SIDArpMode.off,
    this.arpModeParam,
    this.glideSpeed = 0.0,
    this.glideSpeedParam,
    this.overdrive = 1.0,
    this.overdriveParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    // 1. Resolve parameters
    final int waveIdx = (waveformParam != null ? ctx.getParam(waveformParam!, waveform.index.toDouble()) : waveform.index.toDouble()).round().clamp(0, SIDWaveform.values.length - 1);
    final SIDWaveform effWaveform = SIDWaveform.values[waveIdx];

    final int modelIdx = (chipModelParam != null ? ctx.getParam(chipModelParam!, chipModel.index.toDouble()) : chipModel.index.toDouble()).round().clamp(0, SIDChipModel.values.length - 1);
    final SIDChipModel effModel = SIDChipModel.values[modelIdx];

    final int fModeIdx = (filterModeParam != null ? ctx.getParam(filterModeParam!, filterMode.index.toDouble()) : filterMode.index.toDouble()).round().clamp(0, SIDFilterMode.values.length - 1);
    final SIDFilterMode effFilterMode = SIDFilterMode.values[fModeIdx];

    final double effCutoff = (cutoffParam != null ? ctx.getParam(cutoffParam!, cutoff) : cutoff).clamp(0.0, 2047.0);
    final double effReso = (resonanceParam != null ? ctx.getParam(resonanceParam!, resonance) : resonance).clamp(0.0, 15.0);
    final double effPw = (pulseWidthParam != null ? ctx.getParam(pulseWidthParam!, pulseWidth) : pulseWidth).clamp(0.0, 4095.0);
    final double effPwmRate = (pwmRateParam != null ? ctx.getParam(pwmRateParam!, pwmRate) : pwmRate).clamp(0.1, 20.0);
    final double effPwmDepth = (pwmDepthParam != null ? ctx.getParam(pwmDepthParam!, pwmDepth) : pwmDepth).clamp(0.0, 1.0);

    final int arpIdx = (arpModeParam != null ? ctx.getParam(arpModeParam!, arpMode.index.toDouble()) : arpMode.index.toDouble()).round().clamp(0, SIDArpMode.values.length - 1);
    final SIDArpMode effArpMode = SIDArpMode.values[arpIdx];

    final double effGlide = (glideSpeedParam != null ? ctx.getParam(glideSpeedParam!, glideSpeed) : glideSpeed).clamp(0.0, 1.0);
    final double effDrive = (overdriveParam != null ? ctx.getParam(overdriveParam!, overdrive) : overdrive).clamp(0.5, 3.0);

    // 2. Configure engine
    final engine = SIDSynthEngine(model: effModel);
    engine.filter.mode = effFilterMode;
    engine.filter.cutoffReg = effCutoff.round();
    engine.filter.resonanceReg = effReso.round();
    engine.overdrive = effDrive;

    // Apply voice 0 waveform & PWM
    engine.voices[0]
      ..waveform = effWaveform
      ..pulseWidth = effPw.round()
      ..pwmRateHz = effPwmRate
      ..pwmDepth = effPwmDepth
      ..arpMode = effArpMode
      ..glideSpeed = effGlide;

    // Envelope overrides if provided in params
    if (ctx.params.containsKey('Attack')) engine.voices[0].attackRate = ctx.params['Attack']!.round().clamp(0, 15);
    if (ctx.params.containsKey('Decay')) engine.voices[0].decayRate = ctx.params['Decay']!.round().clamp(0, 15);
    if (ctx.params.containsKey('Sustain')) engine.voices[0].sustainLevel = ctx.params['Sustain']!.round().clamp(0, 15);
    if (ctx.params.containsKey('Release')) engine.voices[0].releaseRate = ctx.params['Release']!.round().clamp(0, 15);

    // Direct C64 register pokes if present
    for (final entry in ctx.params.entries) {
      if (entry.key.startsWith('reg_0x') || entry.key.startsWith('0x')) {
        final regHex = entry.key.replaceFirst('reg_', '');
        final regAddr = int.tryParse(regHex);
        if (regAddr != null) {
          engine.writeRegister(regAddr, entry.value.toInt());
        }
      }
    }

    // 3. Process buffer
    engine.processBuffer(
      outBuffer: outBuffer,
      baseFreq: ctx.freq > 0 ? ctx.freq : 440.0,
      sampleRate: ctx.sampleRate,
      durationSec: ctx.durationSec,
      velocity: ctx.velocity,
      targetMidiNote: ctx.targetMidiNote,
      isSlide: ctx.isSlide,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HOHNER CLAVINET D6 PHYSICAL MODELING PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

/// Models the dual electromagnetic single-coil pickups and 4-rocker EQ filter bank of the Clavinet D6.
/// Features Neck/Bridge selection, out-of-phase comb-filtering cancellation ($A - B$ funk quack),
/// and the 4 discrete D6 tone switches (Brilliant, Treble, Medium, Soft).
class ClavinetPickupFilterNode extends GraphNode {
  final GraphNode input;
  final double pickupSelect; // 0.0 = Neck (A), 0.5 = Both (A+B), 1.0 = Bridge (B)
  final String? pickupSelectParam;
  final double phaseInvert; // 0.0 = In-Phase, 1.0 = Out-of-Phase (A-B Quack)
  final String? phaseInvertParam;
  final double brilliant; // 0.0 to 1.0 (Highpass / high-shelf bite)
  final String? brilliantParam;
  final double treble; // 0.0 to 1.0 (3.2kHz peaking bell)
  final String? trebleParam;
  final double medium; // 0.0 to 1.0 (1.1kHz mid peak/cut)
  final String? mediumParam;
  final double soft; // 0.0 to 1.0 (650Hz lowpass)
  final String? softParam;

  const ClavinetPickupFilterNode({
    required this.input,
    this.pickupSelect = 0.5,
    this.pickupSelectParam,
    this.phaseInvert = 0.0,
    this.phaseInvertParam,
    this.brilliant = 1.0,
    this.brilliantParam,
    this.treble = 0.8,
    this.trebleParam,
    this.medium = 0.5,
    this.mediumParam,
    this.soft = 0.0,
    this.softParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double pSelect = (pickupSelectParam != null ? ctx.getParam(pickupSelectParam!, pickupSelect) : pickupSelect).clamp(0.0, 1.0);
    final double pInvert = (phaseInvertParam != null ? ctx.getParam(phaseInvertParam!, phaseInvert) : phaseInvert).clamp(0.0, 1.0);
    final double sBrilliant = (brilliantParam != null ? ctx.getParam(brilliantParam!, brilliant) : brilliant).clamp(0.0, 1.0);
    final double sTreble = (trebleParam != null ? ctx.getParam(trebleParam!, treble) : treble).clamp(0.0, 1.0);
    final double sMedium = (mediumParam != null ? ctx.getParam(mediumParam!, medium) : medium).clamp(0.0, 1.0);
    final double sSoft = (softParam != null ? ctx.getParam(softParam!, soft) : soft).clamp(0.0, 1.0);

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;

    // Bridge pickup physical spacing delay (~12 samples / 0.27ms comb filter)
    final int delaySamples = (sr * 0.00035).toInt().clamp(2, 64);
    final Float32List neckBuf = Float32List.fromList(outBuffer);

    // 1. Dual-Pickup Position Comb Filtering & Phase Inversion
    for (int i = 0; i < len; i++) {
      final double neckSample = neckBuf[i];
      final double bridgeSample = (i >= delaySamples ? neckBuf[i - delaySamples] : 0.0);

      // Phase calculation:
      // In-phase: Neck * (1-pSelect) + Bridge * pSelect
      // Out-of-phase: Neck - Bridge * 1.2
      final double inPhase = neckSample * (1.0 - pSelect * 0.6) + bridgeSample * (0.4 + pSelect * 0.6);
      final double outOfPhase = (neckSample - bridgeSample * 1.05) * 1.6;

      outBuffer[i] = inPhase * (1.0 - pInvert) + outOfPhase * pInvert;
    }

    // 2. Clavinet D6 4-Rocker EQ Filter Matrix
    // Highpass (Brilliant switch: 220Hz 1-pole HPF)
    if (sBrilliant > 0.1) {
      double lastIn = 0.0, lastOut = 0.0;
      final double hpAlpha = 1.0 / (1.0 + (2.0 * math.pi * 220.0 / sr));
      for (int i = 0; i < len; i++) {
        final double inSample = outBuffer[i];
        final double hpOut = hpAlpha * (lastOut + inSample - lastIn);
        lastIn = inSample;
        lastOut = hpOut;
        outBuffer[i] = inSample * (1.0 - sBrilliant * 0.7) + hpOut * (sBrilliant * 1.4);
      }
    }

    // Lowpass (Soft switch: 750Hz 1-pole LPF)
    if (sSoft > 0.1) {
      double lpfState = 0.0;
      final double lpAlpha = (2.0 * math.pi * 750.0 / sr).clamp(0.01, 0.95);
      for (int i = 0; i < len; i++) {
        lpfState += lpAlpha * (outBuffer[i] - lpfState);
        outBuffer[i] = outBuffer[i] * (1.0 - sSoft) + lpfState * sSoft;
      }
    }

    // Peaking EQ (Treble 3.2kHz + Medium 1.2kHz boost)
    final double peakGain = 1.0 + sTreble * 0.4 + sMedium * 0.3;
    for (int i = 0; i < len; i++) {
      outBuffer[i] = (outBuffer[i] * peakGain).clamp(-1.0, 1.0);
    }
  }
}

/// Synthesizes the mechanical key-release yarn damper contact thump on the vibrating Clavinet string.
class YarnDamperThumpNode extends GraphNode {
  final double thumpLevel;
  final String? thumpLevelParam;

  const YarnDamperThumpNode({
    this.thumpLevel = 0.45,
    this.thumpLevelParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double level = (thumpLevelParam != null ? ctx.getParam(thumpLevelParam!, thumpLevel) : thumpLevel).clamp(0.0, 1.0);
    if (level <= 0.001) return;

    final double sr = ctx.sampleRate;
    final double gateEnd = ctx.durationSec * 0.88;
    final int gateSample = (gateEnd * sr).toInt();

    if (gateSample < outBuffer.length) {
      int rng = 0x434C4156 ^ (ctx.midiNote * 37); // "CLAV"
      final int thumpLen = (0.025 * sr).toInt().clamp(8, outBuffer.length - gateSample);
      for (int i = 0; i < thumpLen; i++) {
        final double tNorm = i / thumpLen;
        final double env = math.exp(-tNorm * 6.0);
        rng ^= (rng << 13) & 0xFFFFFFFF;
        rng ^= (rng >> 17) & 0xFFFFFFFF;
        rng ^= (rng << 5) & 0xFFFFFFFF;
        final double n = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;
        final double thumpSine = math.sin(2.0 * math.pi * 140.0 * (i / sr));
        outBuffer[gateSample + i] += (thumpSine * 0.6 + n * 0.4) * env * level * 0.4;
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HARPSICHORD (CEMBALO) PHYSICAL MODELING PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

/// Delrin/Crow Quill Plectrum Pluck Exciter Node for Harpsichord.
/// Synthesizes the sharp, high-harmonic step-pluck impulse and initial quill scrape.
class QuillPluckExciterNode extends GraphNode {
  final double pluckBite;
  final String? pluckBiteParam;
  final double scrapeLevel;
  final String? scrapeLevelParam;

  const QuillPluckExciterNode({
    this.pluckBite = 1.35,
    this.pluckBiteParam,
    this.scrapeLevel = 0.45,
    this.scrapeLevelParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double bite = (pluckBiteParam != null ? ctx.getParam(pluckBiteParam!, pluckBite) : pluckBite).clamp(0.1, 3.0);
    final double scrape = (scrapeLevelParam != null ? ctx.getParam(scrapeLevelParam!, scrapeLevel) : scrapeLevel).clamp(0.0, 2.0);

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;
    outBuffer.fillRange(0, len, 0.0);

    // Initial 4ms quill plectrum micro-scrape & release snap
    final int scrapeSamples = (0.004 * sr).toInt().clamp(6, len ~/ 4);
    int rng = 0x48415250 ^ (ctx.midiNote * 83); // "HARP"

    for (int i = 0; i < scrapeSamples; i++) {
      final double tNorm = i / scrapeSamples;
      final double env = math.sin(tNorm * math.pi);

      rng ^= (rng << 13) & 0xFFFFFFFF;
      rng ^= (rng >> 17) & 0xFFFFFFFF;
      rng ^= (rng << 5) & 0xFFFFFFFF;
      final double noise = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;

      // Sharp asymmetric step-impulse at snap release point
      final double snapImpulse = (i == scrapeSamples - 1) ? 1.0 : (1.0 - tNorm);
      outBuffer[i] = (snapImpulse * bite * 0.8 + noise * scrape * env * 0.35).clamp(-1.0, 1.0);
    }
  }
}

/// Harpsichord Key-Release Wooden Jack Fall & Damper Felt Rattle Node.
/// Synthesizes the authentic mechanical release noise when the wooden jack drops back onto the rail.
class HarpsichordJackReleaseNode extends GraphNode {
  final double releaseNoise;
  final String? releaseNoiseParam;

  const HarpsichordJackReleaseNode({
    this.releaseNoise = 0.35,
    this.releaseNoiseParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double noiseLevel = (releaseNoiseParam != null ? ctx.getParam(releaseNoiseParam!, releaseNoise) : releaseNoise).clamp(0.0, 1.0);
    if (noiseLevel <= 0.001) return;

    final double sr = ctx.sampleRate;
    final double gateEnd = ctx.durationSec * 0.86;
    final int gateSample = (gateEnd * sr).toInt();

    if (gateSample < outBuffer.length) {
      int rng = 0x4A41434B ^ (ctx.midiNote * 97); // "JACK"
      final int jackLen = (0.035 * sr).toInt().clamp(10, outBuffer.length - gateSample);

      for (int i = 0; i < jackLen; i++) {
        final double tNorm = i / jackLen;
        final double env = math.exp(-tNorm * 5.5);

        rng ^= (rng << 13) & 0xFFFFFFFF;
        rng ^= (rng >> 17) & 0xFFFFFFFF;
        rng ^= (rng << 5) & 0xFFFFFFFF;
        final double n = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;

        // Wood tap at 320Hz + Felt scrape
        final double woodTap = math.sin(2.0 * math.pi * 320.0 * (i / sr));
        outBuffer[gateSample + i] += (woodTap * 0.5 + n * 0.5) * env * noiseLevel * 0.30;
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BASS COLLECTION PHYSICAL MODELING PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

/// Soft Fingertip Flesh Pluck Exciter for Acoustic & Electric Bass.
/// Synthesizes the low-frequency fingertip mass displacement ($15\text{ms}$)
/// and subtle fingernail click transient.
class FleshPluckExciterNode extends GraphNode {
  final double pluckForce;
  final String? pluckForceParam;
  final double nailClick;
  final String? nailClickParam;

  const FleshPluckExciterNode({
    this.pluckForce = 1.25,
    this.pluckForceParam,
    this.nailClick = 0.35,
    this.nailClickParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double force = (pluckForceParam != null ? ctx.getParam(pluckForceParam!, pluckForce) : pluckForce).clamp(0.1, 3.0);
    final double click = (nailClickParam != null ? ctx.getParam(nailClickParam!, nailClick) : nailClick).clamp(0.0, 2.0);

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;
    outBuffer.fillRange(0, len, 0.0);

    final int pluckSamples = (0.015 * sr).toInt().clamp(8, len ~/ 4);
    int rng = 0x464C4553 ^ (ctx.midiNote * 43); // "FLES"

    for (int i = 0; i < pluckSamples; i++) {
      final double tNorm = i / pluckSamples;
      // Smooth raised-cosine fingertip displacement pulse
      final double fleshPulse = math.sin(tNorm * math.pi) * math.exp(-tNorm * 2.0);

      rng ^= (rng << 13) & 0xFFFFFFFF;
      rng ^= (rng >> 17) & 0xFFFFFFFF;
      rng ^= (rng << 5) & 0xFFFFFFFF;
      final double noise = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;

      final double nailTransient = (i < pluckSamples ~/ 3) ? noise * math.exp(-tNorm * 8.0) * click : 0.0;
      outBuffer[i] = (fleshPulse * force * ctx.velocity + nailTransient * 0.4).clamp(-1.0, 1.0);
    }
  }
}

/// Dynamic Fretless Fingerboard Boundary Collision & "Mwah" Blooming Node.
/// Models the string-to-wood fingerboard contact that dynamically blooms higher harmonic
/// buzz after the initial attack as the string amplitude settles.
class FretlessMwahNode extends GraphNode {
  final GraphNode input;
  final double mwahAmount;
  final String? mwahAmountParam;
  final double growl;
  final String? growlParam;

  const FretlessMwahNode({
    required this.input,
    this.mwahAmount = 0.70,
    this.mwahAmountParam,
    this.growl = 0.50,
    this.growlParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double mwah = (mwahAmountParam != null ? ctx.getParam(mwahAmountParam!, mwahAmount) : mwahAmount).clamp(0.0, 1.0);
    final double curGrowl = (growlParam != null ? ctx.getParam(growlParam!, growl) : growl).clamp(0.0, 1.0);

    if (mwah <= 0.001 && curGrowl <= 0.001) return;

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;

    double envelopeFollower = 0.0;
    final double envDecay = math.exp(-1.0 / (0.04 * sr));

    for (int i = 0; i < len; i++) {
      final double sample = outBuffer[i];
      envelopeFollower = math.max(sample.abs(), envelopeFollower * envDecay);

      final double normTime = len > 1 ? i / (len - 1) : 0.0;
      final double pressure = ctx.getPressureAt(normTime);
      final double timbre = ctx.getTimbreAt(normTime);

      final double time = i / sr;
      // "Mwah" blooming envelope: peaks around 60ms-180ms after attack
      final double bloomEnv = math.sin((time * 4.5).clamp(0.0, math.pi)) * math.exp(-time * 1.8);

      // Asymmetric boundary collision soft-clipping (fingerboard buzzing modulated by pressure)
      final double dynamicMwah = (mwah + pressure * 0.40).clamp(0.0, 1.5);
      final double dynamicGrowl = (curGrowl + (timbre - 0.5) * 0.40).clamp(0.0, 1.5);

      final double collision = sample > 0 ? DistortionNode._tanh(sample * (1.0 + dynamicMwah * bloomEnv * 2.5)) : sample;
      // Harmonic 2nd order growl
      final double growlHarmonic = (sample * sample - 0.25) * dynamicGrowl * 0.35 * bloomEnv;

      outBuffer[i] = (collision + growlHarmonic).clamp(-1.0, 1.0);
    }
  }
}

/// Upright Double Bass Heavy Finger Pull & Wood Slap Exciter Node.
/// Synthesizes the deep acoustic bass impulse and mechanical fingerboard slap on hard plucks.
class UprightPluckSlapExciterNode extends GraphNode {
  final double pluckMass;
  final String? pluckMassParam;
  final double slapClick;
  final String? slapClickParam;

  const UprightPluckSlapExciterNode({
    this.pluckMass = 2.0,
    this.pluckMassParam,
    this.slapClick = 0.0,
    this.slapClickParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double mass = (pluckMassParam != null ? ctx.getParam(pluckMassParam!, pluckMass) : pluckMass).clamp(0.5, 4.0);
    double slap = (slapClickParam != null ? ctx.getParam(slapClickParam!, slapClick) : slapClick).clamp(0.0, 2.0);

    final art = ctx.articulation?.toLowerCase();
    final bool isSlapArt = (art == 'slap' || art == 'pop');
    if (isSlapArt) {
      slap = math.max(slap, 1.0);
    } else if (art == 'pizzicato' || art == 'flesh' || art == 'open' || art == 'sustain') {
      slap = 0.0;
    }

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;
    outBuffer.fillRange(0, len, 0.0);

    // Warm, punchy side-finger flesh pull with 110Hz body thump (16ms impulse)
    final double pulseSec = 0.016;
    final int pluckSamples = (pulseSec * sr).toInt().clamp(16, len ~/ 2);

    for (int i = 0; i < pluckSamples; i++) {
      final double tNorm = i / pluckSamples;
      final double fleshPulse = math.sin(tNorm * math.pi) * math.exp(-tNorm * 1.8);
      final double woodThump = math.sin(2.0 * math.pi * 110.0 * (i / sr)) * math.exp(-tNorm * 4.0);
      outBuffer[i] = (fleshPulse * 0.75 + woodThump * 0.25) * mass * ctx.velocity * 1.35;
    }

    // Fingerboard wood slap transient (only if explicitly enabled via SlapClick or slap articulation)
    if (slap > 0.02) {
      final int slapLen = (0.010 * sr).toInt().clamp(5, pluckSamples);
      int rng = 0x44424153 ^ (ctx.midiNote * 67); // "DBAS"
      for (int i = 0; i < slapLen && i < outBuffer.length; i++) {
        final double tNorm = i / slapLen;
        rng ^= (rng << 13) & 0xFFFFFFFF;
        rng ^= (rng >> 17) & 0xFFFFFFFF;
        rng ^= (rng << 5) & 0xFFFFFFFF;
        final double noise = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;
        final double slapEnv = math.exp(-tNorm * 8.0) * (1.0 - tNorm);
        outBuffer[i] += noise * slapEnv * slap * 0.35 * ctx.velocity;
      }
    }
  }
}

/// 4-Pole 24dB/oct Virtual Analog Transistor Ladder Lowpass Filter.
/// Models the iconic Minimoog ladder topology with resonant feedback and tanh non-linear saturation.
class MoogLadderFilterNode extends GraphNode {
  final GraphNode input;
  final double cutoffHz;
  final String? cutoffParam;
  final double resonance; // 0.0 to 0.98
  final String? resonanceParam;
  final double envAmount;
  final String? envAmountParam;
  final double envDecaySec;
  final String? envDecayParam;

  const MoogLadderFilterNode({
    required this.input,
    this.cutoffHz = 400.0,
    this.cutoffParam,
    this.resonance = 0.65,
    this.resonanceParam,
    this.envAmount = 0.50,
    this.envAmountParam,
    this.envDecaySec = 0.45,
    this.envDecayParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double baseCutoff = (cutoffParam != null ? ctx.getParam(cutoffParam!, cutoffHz) : cutoffHz).clamp(20.0, 18000.0);
    final double res = (resonanceParam != null ? ctx.getParam(resonanceParam!, resonance) : resonance).clamp(0.0, 0.96);
    final double envMod = (envAmountParam != null ? ctx.getParam(envAmountParam!, envAmount) : envAmount).clamp(0.0, 1.0);
    final double decay = (envDecayParam != null ? ctx.getParam(envDecayParam!, envDecaySec) : envDecaySec).clamp(0.02, 4.0);

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;

    // 4 1-pole filter states
    double s0 = 0.0, s1 = 0.0, s2 = 0.0, s3 = 0.0;

    for (int i = 0; i < len; i++) {
      final double normTime = len > 1 ? i / (len - 1) : 0.0;
      final double timbre = ctx.getTimbreAt(normTime);
      final double pressure = ctx.getPressureAt(normTime);

      final double time = i / sr;
      final double env = math.exp(-time / decay);
      final double timbreOffset = (timbre - 0.5) * 4500.0;
      final double pressureOffset = pressure * 2800.0;
      final double curCutoff = (baseCutoff + envMod * env * 4500.0 + timbreOffset + pressureOffset).clamp(20.0, sr * 0.45);

      // Bilinear cutoff tuning coefficient
      final double g = 1.0 - math.exp(-2.0 * math.pi * curCutoff / sr);
      final double feedbackGain = res * 3.95;

      final double inSample = outBuffer[i];
      // Feedback with non-linear saturation
      final double u = DistortionNode._tanh(inSample - feedbackGain * s3);

      s0 += g * (DistortionNode._tanh(u) - s0);
      s1 += g * (s0 - s1);
      s2 += g * (s1 - s2);
      s3 += g * (s2 - s3);

      outBuffer[i] = s3.clamp(-1.0, 1.0);
    }
  }
}

/// Coupled Double-Course Digital Waveguide.
/// Synthesizes paired string physics (Lute, Baroque Guitar, Vihuela, 12-String Guitar, Mandolin)
/// with micro-detuning, octave pairing, and acoustic bridge energy exchange.
class CoupledWaveguideNode extends GraphNode {
  final GraphNode exciter;
  final double feedback;
  final String? feedbackParam;
  final double damping;
  final String? dampingParam;
  final double courseDetuneCents; // Inter-string detune (0.0 to 12.0 cents)
  final String? courseDetuneParam;
  final bool octavePair; // True if second string is 1 octave higher (Baroque guitar / Lute diapason)
  final String? octavePairParam;
  final double coupling; // Bridge coupling coefficient (0.0 to 0.25)
  final String? couplingParam;

  const CoupledWaveguideNode({
    required this.exciter,
    this.feedback = 0.994,
    this.feedbackParam,
    this.damping = 0.22,
    this.dampingParam,
    this.courseDetuneCents = 3.5,
    this.courseDetuneParam,
    this.octavePair = false,
    this.octavePairParam,
    this.coupling = 0.08,
    this.couplingParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    exciter.process(ctx, outBuffer);

    double baseFreq = ctx.freq > 10.0 ? ctx.freq : 440.0;
    final double sr = ctx.sampleRate;
    double fb = (feedbackParam != null ? ctx.getParam(feedbackParam!, feedback) : feedback).clamp(0.80, 0.9999);
    double damp = (dampingParam != null ? ctx.getParam(dampingParam!, damping) : damping).clamp(0.01, 0.95);
    final double detuneCents = (courseDetuneParam != null ? ctx.getParam(courseDetuneParam!, courseDetuneCents) : courseDetuneCents).clamp(0.0, 25.0);
    final double coup = (couplingParam != null ? ctx.getParam(couplingParam!, coupling) : coupling).clamp(0.0, 0.35);
    final bool isOctave = octavePairParam != null ? (ctx.getParam(octavePairParam!, octavePair ? 1.0 : 0.0) >= 0.5) : octavePair;

    final art = ctx.articulation?.toLowerCase();
    if (art == 'muted' || art == 'palm_mute' || art == 'chop') {
      damp = math.max(damp, 0.72);
      fb = math.min(fb, 0.94);
    } else if (art == 'harmonics' || art == 'flageolet') {
      baseFreq *= 2.0;
      fb = math.max(fb, 0.997);
      damp = math.min(damp, 0.12);
    }

    final double maxDelaySamples = sr / 20.0;
    final int bufSize = maxDelaySamples.toInt() + 32;
    final delay1 = Float32List(bufSize);
    final delay2 = Float32List(bufSize);
    int writeIdx1 = 0;
    int writeIdx2 = 0;
    double filter1 = 0.0;
    double filter2 = 0.0;

    final double detuneRatio1 = math.pow(2.0, -(detuneCents * 0.5) / 1200.0).toDouble();
    final double detuneRatio2 = isOctave
        ? 2.0 * math.pow(2.0, (detuneCents * 0.5) / 1200.0).toDouble()
        : math.pow(2.0, (detuneCents * 0.5) / 1200.0).toDouble();

    for (int i = 0; i < len; i++) {
      final double inSample = outBuffer[i];
      final double normTime = len > 1 ? i / (len - 1) : 0.0;
      final double bendSemitones = ctx.getPitchBendAt(normTime);
      final double bendMultiplier = math.pow(2.0, bendSemitones / 12.0).toDouble();

      final double f1 = (baseFreq * bendMultiplier * detuneRatio1).clamp(20.0, 20000.0);
      final double f2 = (baseFreq * bendMultiplier * detuneRatio2).clamp(20.0, 20000.0);

      final double d1Samples = (sr / f1).clamp(2.0, bufSize - 4.0);
      final double d2Samples = (sr / f2).clamp(2.0, bufSize - 4.0);

      // Interpolate Delay Line 1
      final double rPos1 = writeIdx1 - d1Samples;
      double rIdx1 = rPos1 >= 0 ? rPos1 : (rPos1 + bufSize);
      while (rIdx1 >= bufSize) rIdx1 -= bufSize;
      while (rIdx1 < 0) rIdx1 += bufSize;
      final int i0_1 = rIdx1.toInt() % bufSize;
      final int i1_1 = (i0_1 + 1) % bufSize;
      final double frac1 = d1Samples - d1Samples.floor();
      final double s1 = delay1[i0_1] + frac1 * (delay1[i1_1] - delay1[i0_1]);

      // Interpolate Delay Line 2
      final double rPos2 = writeIdx2 - d2Samples;
      double rIdx2 = rPos2 >= 0 ? rPos2 : (rPos2 + bufSize);
      while (rIdx2 >= bufSize) rIdx2 -= bufSize;
      while (rIdx2 < 0) rIdx2 += bufSize;
      final int i0_2 = rIdx2.toInt() % bufSize;
      final int i1_2 = (i0_2 + 1) % bufSize;
      final double frac2 = d2Samples - d2Samples.floor();
      final double s2 = delay2[i0_2] + frac2 * (delay2[i1_2] - delay2[i0_2]);

      // Lowpass damping
      filter1 = (1.0 - damp) * s1 + damp * filter1;
      filter2 = (1.0 - damp) * s2 + damp * filter2;

      // Bridge mutual energy coupling
      final double coupled1 = (filter1 * (1.0 - coup) + filter2 * coup) * fb;
      final double coupled2 = (filter2 * (1.0 - coup) + filter1 * coup) * fb;

      delay1[writeIdx1] = inSample + coupled1;
      delay2[writeIdx2] = (inSample * (isOctave ? 0.75 : 1.0)) + coupled2;

      writeIdx1 = (writeIdx1 + 1) % bufSize;
      writeIdx2 = (writeIdx2 + 1) % bufSize;

      outBuffer[i] = (coupled1 + (isOctave ? coupled2 * 0.8 : coupled2)) * 0.65 + inSample;
    }
  }
}

/// Advanced Acoustic Pluck & Rasgueado Exciter Node.
/// Models fingertip flesh (warm, wide) vs fingernail (crisp, narrow) attack dynamics,
/// multi-finger rasgueado strum fan rakes, gut string scrape transients, and soundboard golpe wood taps.
class AcousticPluckExciterNode extends GraphNode {
  final double fleshRatio; // 0.0 (crisp nail/plectrum) to 1.0 (warm soft fingertip flesh)
  final String? fleshRatioParam;
  final double scrapeNoise; // Gut/nylon string friction scrape amplitude
  final String? scrapeNoiseParam;
  final double strumSpreadMs; // Strum duration across strings (1.0 to 45.0 ms)
  final String? strumSpreadParam;
  final int numStrumTaps;
  final double golpeGain; // Soundboard wood tap transient gain
  final String? golpeGainParam;

  const AcousticPluckExciterNode({
    this.fleshRatio = 0.35,
    this.fleshRatioParam,
    this.scrapeNoise = 0.40,
    this.scrapeNoiseParam,
    this.strumSpreadMs = 6.0,
    this.strumSpreadParam,
    this.numStrumTaps = 1,
    this.golpeGain = 0.0,
    this.golpeGainParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double flesh = (fleshRatioParam != null ? ctx.getParam(fleshRatioParam!, fleshRatio) : fleshRatio).clamp(0.0, 1.0);
    final double scrape = (scrapeNoiseParam != null ? ctx.getParam(scrapeNoiseParam!, scrapeNoise) : scrapeNoise).clamp(0.0, 2.0);
    double spreadMs = (strumSpreadParam != null ? ctx.getParam(strumSpreadParam!, strumSpreadMs) : strumSpreadMs).clamp(1.0, 50.0);
    final double golpe = (golpeGainParam != null ? ctx.getParam(golpeGainParam!, golpeGain) : golpeGain).clamp(0.0, 2.0);
    final double vel = ctx.velocity.clamp(0.05, 1.0);
    final double sr = ctx.sampleRate;

    outBuffer.fillRange(0, outBuffer.length, 0.0);

    final art = ctx.articulation?.toLowerCase();
    int taps = numStrumTaps;
    double actualFlesh = flesh;

    if (art == 'rasgueado' || art == 'strum' || art == 'fan') {
      taps = math.max(taps, 5);
      spreadMs = math.max(spreadMs, 14.0);
    } else if (art == 'flesh' || art == 'tirando' || art == 'thumb') {
      actualFlesh = 1.0;
      taps = 1;
    } else if (art == 'nail' || art == 'apoyando' || art == 'rest_stroke') {
      actualFlesh = 0.05;
      taps = 1;
    }

    final double tapSpacingSec = taps > 1 ? (spreadMs / 1000.0) / (taps - 1) : 0.0;

    for (int t = 0; t < taps; t++) {
      final double tapTime = t * tapSpacingSec;
      final int startSample = (tapTime * sr).toInt();
      if (startSample >= outBuffer.length) break;

      // Pulse width: Soft flesh creates a wider, smoother hump (~2.5ms); hard nail creates a narrow, sharp spike (~0.4ms)
      final double pulseSec = 0.0004 + 0.0022 * actualFlesh;
      final int pulseLen = (pulseSec * sr).toInt().clamp(3, 140);
      final double tapGain = (0.75 + 0.25 * (t / (taps > 1 ? taps : 1))) * vel;

      for (int i = 0; i < pulseLen && (startSample + i) < outBuffer.length; i++) {
        final double phase = (i / pulseLen) * math.pi;
        final double pulse = math.sin(phase) * (1.0 - 0.3 * actualFlesh * math.sin(2.0 * phase));
        outBuffer[startSample + i] += pulse * tapGain;
      }

      // String friction scrape noise (gut / wound strings)
      if (scrape > 0.01) {
        int state = 0x5EEDCAFE ^ (ctx.midiNote * 43 + t * 107);
        final int scrapeLen = ((0.0035 * sr)).toInt();
        for (int i = 0; i < scrapeLen && (startSample + i) < outBuffer.length; i++) {
          state ^= (state << 13) & 0xFFFFFFFF;
          state ^= (state >> 17) & 0xFFFFFFFF;
          state ^= (state << 5) & 0xFFFFFFFF;
          final double noise = ((state & 0xFFFFFF) / 8388607.5) - 1.0;
          final double env = math.exp(-i / (sr * (0.0005 + 0.0010 * actualFlesh)));
          outBuffer[startSample + i] += noise * env * scrape * 0.30 * (1.1 - actualFlesh * 0.5) * vel;
        }
      }
    }

    // Soundboard Golpe (wood tap percussive strike)
    if (golpe > 0.01 || art == 'golpe') {
      final double gGain = (art == 'golpe' ? 1.0 : golpe) * vel;
      final int golpeLen = ((0.025 * sr)).toInt();
      int gState = 0xDEADC0DE ^ ctx.midiNote;
      for (int i = 0; i < golpeLen && i < outBuffer.length; i++) {
        gState ^= (gState << 13) & 0xFFFFFFFF;
        gState ^= (gState >> 17) & 0xFFFFFFFF;
        gState ^= (gState << 5) & 0xFFFFFFFF;
        final double noise = ((gState & 0xFFFFFF) / 8388607.5) - 1.0;
        final double thump = math.sin(2.0 * math.pi * 110.0 * (i / sr));
        final double env = math.exp(-i / (sr * 0.008));
        outBuffer[i] += (thump * 0.7 + noise * 0.3) * env * gGain * 0.65;
      }
    }
  }
}

/// Morphable Acoustic Guitar Body Resonator.
/// Smoothly morphs Helmholtz air cavity and soundboard/backplate modal peaks
/// across Parlor/000 (0.0), Dreadnought (0.5), and Jumbo (1.0) acoustic geometries.
class MorphableAcousticBodyNode extends GraphNode {
  final GraphNode input;
  final double bodyProfile; // 0.0 = Parlor/000, 0.5 = Dreadnought, 1.0 = Jumbo
  final String? bodyProfileParam;
  final double woodGain;
  final String? woodGainParam;

  const MorphableAcousticBodyNode({
    required this.input,
    this.bodyProfile = 0.5,
    this.bodyProfileParam,
    this.woodGain = 0.45,
    this.woodGainParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List inBuf = Float32List(len);
    input.process(ctx, inBuf);
    outBuffer.fillRange(0, len, 0.0);

    final double profile = (bodyProfileParam != null ? ctx.getParam(bodyProfileParam!, bodyProfile) : bodyProfile).clamp(0.0, 1.0);
    final double gain = (woodGainParam != null ? ctx.getParam(woodGainParam!, woodGain) : woodGain).clamp(0.0, 1.5);
    final double sr = ctx.sampleRate;

    // Interpolate Helmholtz Air Cavity & Top Plate Resonances:
    // Parlor: Air 120Hz, Top 220Hz, Back 270Hz
    // Dreadnought: Air 95Hz, Top 195Hz, Back 235Hz
    // Jumbo: Air 82Hz, Top 175Hz, Back 215Hz
    final double airFreq = 120.0 - profile * 38.0;
    final double topFreq = 220.0 - profile * 45.0;
    final double backFreq = 270.0 - profile * 55.0;
    final double bridgeFreq = 380.0 - profile * 60.0;

    final freqs = [airFreq, topFreq, backFreq, bridgeFreq];
    final gains = [0.55 * gain, 0.45 * gain, 0.30 * gain, 0.18 * gain];
    final qFactors = [16.0 + profile * 4.0, 20.0, 18.0, 26.0];

    for (int m = 0; m < freqs.length; m++) {
      final double f = freqs[m].clamp(20.0, sr * 0.48);
      final double g = gains[m];
      final double q = qFactors[m];

      final double w0 = 2.0 * math.pi * (f / sr);
      final double alpha = math.sin(w0) / (2.0 * q);

      final double b0 = alpha;
      final double b2 = -alpha;
      final double a0 = 1.0 + alpha;
      final double a1 = -2.0 * math.cos(w0);
      final double a2 = 1.0 - alpha;

      final double normB0 = (b0 / a0) * g;
      final double normB2 = (b2 / a0) * g;
      final double normA1 = a1 / a0;
      final double normA2 = a2 / a0;

      double z1 = 0.0;
      double z2 = 0.0;

      for (int i = 0; i < len; i++) {
        final double inSample = inBuf[i];
        final double outSample = normB0 * inSample + z1;
        z1 = -normA1 * outSample + z2;
        z2 = normB2 * inSample - normA2 * outSample;
        outBuffer[i] += outSample;
      }
    }
  }
}

/// Spun Aluminum Mechanical Resonator Cone Node (Dobro / Resonator Guitar).
/// Emulates the signature metallic nasal formants and mechanical cone coupling of spider/biscuit cones.
class AluminumConeResonatorNode extends GraphNode {
  final GraphNode input;
  final double coneType; // 0.0 = Spider Bridge (warm, singing), 1.0 = Biscuit Bridge (punchy, gritty blues)
  final String? coneTypeParam;
  final double metalBark;
  final String? metalBarkParam;

  const AluminumConeResonatorNode({
    required this.input,
    this.coneType = 0.35,
    this.coneTypeParam,
    this.metalBark = 0.50,
    this.metalBarkParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List inBuf = Float32List(len);
    input.process(ctx, inBuf);
    outBuffer.fillRange(0, len, 0.0);

    final double type = (coneTypeParam != null ? ctx.getParam(coneTypeParam!, coneType) : coneType).clamp(0.0, 1.0);
    final double bark = (metalBarkParam != null ? ctx.getParam(metalBarkParam!, metalBark) : metalBark).clamp(0.0, 2.0);
    final double sr = ctx.sampleRate;

    // Spun aluminum cone modal formants (strong nasal peaks in 650Hz - 2200Hz)
    final f1 = 720.0 + type * 140.0;
    final f2 = 1450.0 + type * 220.0;
    final f3 = 2150.0 + type * 350.0;

    final freqs = [f1, f2, f3];
    final gains = [0.60 * (1.0 + bark * 0.5), 0.48 * (1.0 + bark * 0.6), 0.32 * (1.0 + bark * 0.4)];
    final qFactors = [24.0, 32.0, 40.0];

    for (int m = 0; m < freqs.length; m++) {
      final double f = freqs[m].clamp(20.0, sr * 0.48);
      final double g = gains[m];
      final double q = qFactors[m];

      final double w0 = 2.0 * math.pi * (f / sr);
      final double alpha = math.sin(w0) / (2.0 * q);

      final double b0 = alpha;
      final double b2 = -alpha;
      final double a0 = 1.0 + alpha;
      final double a1 = -2.0 * math.cos(w0);
      final double a2 = 1.0 - alpha;

      final double normB0 = (b0 / a0) * g;
      final double normB2 = (b2 / a0) * g;
      final double normA1 = a1 / a0;
      final double normA2 = a2 / a0;

      double z1 = 0.0;
      double z2 = 0.0;

      for (int i = 0; i < len; i++) {
        final double inSample = inBuf[i];
        final double outSample = normB0 * inSample + z1;
        z1 = -normA1 * outSample + z2;
        z2 = normB2 * inSample - normA2 * outSample;
        // Mild metallic non-linear aluminum diaphragm rattle
        outBuffer[i] += outSample + 0.12 * DistortionNode._tanh(outSample * outSample * bark);
      }
    }
  }
}

/// 5-String Banjo Skin / Mylar Drumhead Membrane Exciter Node.
/// Models the ultra-fast transient impact, tight head tension, and metallic bridge contact snap.
class MembraneHeadExciterNode extends GraphNode {
  final double headTension; // 0.0 (loose calfskin, thumpy) to 1.0 (tight mylar, bright twang)
  final String? headTensionParam;
  final double twangSnap;
  final String? twangSnapParam;

  const MembraneHeadExciterNode({
    this.headTension = 0.75,
    this.headTensionParam,
    this.twangSnap = 1.2,
    this.twangSnapParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double tension = (headTensionParam != null ? ctx.getParam(headTensionParam!, headTension) : headTension).clamp(0.0, 1.0);
    final double snap = (twangSnapParam != null ? ctx.getParam(twangSnapParam!, twangSnap) : twangSnap).clamp(0.0, 3.0);
    final double vel = ctx.velocity.clamp(0.05, 1.0);
    final double sr = ctx.sampleRate;

    outBuffer.fillRange(0, outBuffer.length, 0.0);

    // Tight membrane head pulse: ultra-narrow (~0.3ms to 1.0ms)
    final double pulseSec = 0.0003 + (1.0 - tension) * 0.0009;
    final int pulseLen = (pulseSec * sr).toInt().clamp(3, 80);

    for (int i = 0; i < pulseLen && i < outBuffer.length; i++) {
      final double tNorm = i / pulseLen;
      // Asymmetric drumhead shockwave
      final double pulse = math.sin(tNorm * math.pi) * (1.0 - tNorm * 0.6);
      outBuffer[i] += pulse * vel * (0.8 + snap * 0.4);
    }

    // High-frequency brass tone-ring snap
    final int ringLen = (0.004 * sr).toInt();
    int rng = 0x42414E4A ^ ctx.midiNote; // "BANJ"
    for (int i = 0; i < ringLen && i < outBuffer.length; i++) {
      rng ^= (rng << 13) & 0xFFFFFFFF;
      rng ^= (rng >> 17) & 0xFFFFFFFF;
      rng ^= (rng << 5) & 0xFFFFFFFF;
      final double n = ((rng & 0xFFFFFF) / 8388607.5) - 1.0;
      final double env = math.exp(-i / (sr * (0.0004 + (1.0 - tension) * 0.0006)));
      outBuffer[i] += n * env * snap * 0.40 * vel;
    }
  }
}

/// Pedal Steel Volume Swell & Bar Vibrato Node.
/// Models the iconic volume pedal swell dynamics and singing bar glissando.
class VolumePedalSwellNode extends GraphNode {
  final GraphNode input;
  final double swellSec; // Volume swell time (0.0 = instantaneous pick, 0.4 = deep pedal swell)
  final String? swellSecParam;
  final double barVibrato;
  final String? barVibratoParam;

  const VolumePedalSwellNode({
    required this.input,
    this.swellSec = 0.12,
    this.swellSecParam,
    this.barVibrato = 0.35,
    this.barVibratoParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double swell = (swellSecParam != null ? ctx.getParam(swellSecParam!, swellSec) : swellSec).clamp(0.0, 1.2);
    final double vib = (barVibratoParam != null ? ctx.getParam(barVibratoParam!, barVibrato) : barVibrato).clamp(0.0, 1.0);
    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;

    for (int i = 0; i < len; i++) {
      final double time = i / sr;
      // Volume pedal curve: logarithmic fade in
      double gain = 1.0;
      if (swell > 0.005) {
        gain = (time / swell).clamp(0.05, 1.0);
        gain = gain * gain * (3.0 - 2.0 * gain); // Smoothstep curve
      }

      // Bar vibrato LFO (5.2 Hz gentle hand motion)
      final double vibMod = 1.0 + vib * 0.12 * math.sin(2.0 * math.pi * 5.2 * time);

      outBuffer[i] = (outBuffer[i] * gain * vibMod).clamp(-1.0, 1.0);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOWED STRING FAMILY PHYSICAL MODELING (Violin, Viola, Cello, Double Bass)
// ─────────────────────────────────────────────────────────────────────────────

/// Bowed String Friction & Multi-Articulation Exciter Node.
/// Models stick-slip bow hair friction (McIntyre-Schumacher-Woodhouse MSW curve),
/// rosin scratch noise, bowing position (sul ponticello vs sul tasto),
/// and per-note articulation switching (pizzicato, snap, spiccato, tremolo, col legno).
class BowedFrictionExciterNode extends GraphNode {
  final double bowPressure; // 0.1 to 2.5 (Normal ~ 1.0)
  final String? bowPressureParam;
  final double bowSpeed; // 0.1 to 3.0 (Normal ~ 1.0)
  final String? bowSpeedParam;
  final double bowPosition; // 0.0 (Sul Tasto) <-> 0.5 (Normale) <-> 1.0 (Sul Ponticello)
  final String? bowPositionParam;
  final double rosinGrit; // Rosin friction scrape amount (0.0 to 1.5)
  final String? rosinGritParam;
  final double tremoloSpeed; // Hz for tremolo articulation (8.0 to 18.0 Hz)
  final String? tremoloSpeedParam;

  const BowedFrictionExciterNode({
    this.bowPressure = 1.0,
    this.bowPressureParam,
    this.bowSpeed = 1.0,
    this.bowSpeedParam,
    this.bowPosition = 0.5,
    this.bowPositionParam,
    this.rosinGrit = 0.35,
    this.rosinGritParam,
    this.tremoloSpeed = 13.5,
    this.tremoloSpeedParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double pressure = (bowPressureParam != null ? ctx.getParam(bowPressureParam!, bowPressure) : bowPressure).clamp(0.05, 3.0);
    final double speed = (bowSpeedParam != null ? ctx.getParam(bowSpeedParam!, bowSpeed) : bowSpeed).clamp(0.05, 3.0);
    double pos = (bowPositionParam != null ? ctx.getParam(bowPositionParam!, bowPosition) : bowPosition).clamp(0.0, 1.0);
    final double rosin = (rosinGritParam != null ? ctx.getParam(rosinGritParam!, rosinGrit) : rosinGrit).clamp(0.0, 2.0);
    final double tremRate = (tremoloSpeedParam != null ? ctx.getParam(tremoloSpeedParam!, tremoloSpeed) : tremoloSpeed).clamp(4.0, 24.0);

    final double vel = ctx.velocity.clamp(0.05, 1.0);
    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;
    final art = ctx.articulation?.toLowerCase();

    outBuffer.fillRange(0, len, 0.0);

    // ─────────────────────────────────────────────────────────────────────────
    // 1. PLUCKED / PERCUSSIVE ARTICULATIONS (Pizzicato, Snap, Col Legno)
    // ─────────────────────────────────────────────────────────────────────────
    if (art == 'pizz' || art == 'pizzicato' || art == 'pluck') {
      // Fingertip flesh pluck: warm transient pulse ~1.8ms
      final double pulseSec = 0.0018;
      final int pulseLen = (pulseSec * sr).toInt().clamp(4, 120);
      for (int i = 0; i < pulseLen && i < len; i++) {
        final double phase = (i / pulseLen) * math.pi;
        outBuffer[i] = math.sin(phase) * (1.0 - 0.25 * math.sin(2.0 * phase)) * vel * 1.4;
      }
      // Finger release scrape
      int state = 0x50495A5A ^ ctx.midiNote; // "PIZZ"
      final int scrapeLen = (0.004 * sr).toInt();
      for (int i = 0; i < scrapeLen && i < len; i++) {
        state ^= (state << 13) & 0xFFFFFFFF;
        state ^= (state >> 17) & 0xFFFFFFFF;
        state ^= (state << 5) & 0xFFFFFFFF;
        final double noise = ((state & 0xFFFFFF) / 8388607.5) - 1.0;
        final double env = math.exp(-i / (sr * 0.0008));
        outBuffer[i] += noise * env * 0.22 * vel;
      }
      return;
    }

    if (art == 'snap' || art == 'bartok' || art == 'slap') {
      // Bartók snap pizzicato: string snaps back violently onto fingerboard wood
      final int snapLen = (0.015 * sr).toInt();
      int state = 0x534E4150 ^ ctx.midiNote; // "SNAP"
      for (int i = 0; i < snapLen && i < len; i++) {
        state ^= (state << 13) & 0xFFFFFFFF;
        state ^= (state >> 17) & 0xFFFFFFFF;
        state ^= (state << 5) & 0xFFFFFFFF;
        final double noise = ((state & 0xFFFFFF) / 8388607.5) - 1.0;
        final double woodThump = math.sin(2.0 * math.pi * 180.0 * (i / sr));
        final double env = math.exp(-i / (sr * 0.0025));
        outBuffer[i] = (woodThump * 0.6 + noise * 0.8) * env * vel * 1.8;
      }
      return;
    }

    if (art == 'col_legno' || art == 'battuto' || art == 'wood') {
      // Bow stick wood tapping string: ultra-short woody spike with fast damping
      final int woodLen = (0.006 * sr).toInt();
      int state = 0x434F4C4C ^ ctx.midiNote; // "COLL"
      for (int i = 0; i < woodLen && i < len; i++) {
        state ^= (state << 13) & 0xFFFFFFFF;
        state ^= (state >> 17) & 0xFFFFFFFF;
        state ^= (state << 5) & 0xFFFFFFFF;
        final double noise = ((state & 0xFFFFFF) / 8388607.5) - 1.0;
        final double stickClick = math.sin(2.0 * math.pi * 2200.0 * (i / sr));
        final double env = math.exp(-i / (sr * 0.0012));
        outBuffer[i] = (stickClick * 0.7 + noise * 0.5) * env * vel * 1.5;
      }
      return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. BOWED ARTICULATION MODIFIERS (Spiccato, Tremolo, Sul Ponticello, Sul Tasto)
    // ─────────────────────────────────────────────────────────────────────────
    double effectiveSpeed = speed;
    double effectivePressure = pressure;

    if (art == 'ponticello' || art == 'sul_ponticello') {
      pos = 0.92; // Very near the bridge: bright, overtone-rich, glassy
      effectivePressure *= 1.3;
    } else if (art == 'tasto' || art == 'sul_tasto' || art == 'flautando') {
      pos = 0.08; // Over fingerboard: soft, hollow, fundamental-heavy
      effectivePressure *= 0.6;
      effectiveSpeed *= 0.8;
    } else if (art == 'spiccato' || art == 'staccato' || art == 'sautille') {
      effectiveSpeed *= 1.6;
      effectivePressure *= 1.4;
    }

    // Pseudo-random state for rosin grain texture
    int rState = 0x524F5349 ^ (ctx.midiNote * 37); // "ROSI"

    final double baseFreq = ctx.freq > 10.0 ? ctx.freq : 440.0;

    for (int i = 0; i < len; i++) {
      final double t = i / sr;

      // Tremolo agitation LFO (rapid bow direction reversals)
      double tremMod = 1.0;
      if (art == 'tremolo') {
        tremMod = 0.55 + 0.45 * math.cos(2.0 * math.pi * tremRate * t);
      }

      // Attack Envelope: smooth bow catch for arco (~45ms); sharp burst for spiccato/staccato
      double attackEnv = (t / 0.045).clamp(0.0, 1.0);
      if (art == 'spiccato' || art == 'staccato') {
        // Fast impulsive bounce burst then short sustain
        attackEnv = math.exp(-t / 0.05);
      }

      // Stick-slip Helmholtz trigger excitation
      final double phase = (t * baseFreq) % 1.0;
      // Positional node reflection: bow position creates comb notch at harmonic (1 / pos)
      final double bridgeHarmonicMod = 1.0 + (pos - 0.5) * 0.9 * math.sin(math.pi * phase / math.max(0.04, pos));
      final double helmholtzSaw = (2.0 * phase - 1.0) * bridgeHarmonicMod;

      // Rosin grain friction noise
      rState ^= (rState << 13) & 0xFFFFFFFF;
      rState ^= (rState >> 17) & 0xFFFFFFFF;
      rState ^= (rState << 5) & 0xFFFFFFFF;
      final double noise = ((rState & 0xFFFFFF) / 8388607.5) - 1.0;

      // Rosin noise: dynamic scrape during stick-to-slip transition with persistent subtle bow hair friction
      final double slipTrigger = math.exp(-math.pow((phase - 0.5) * 5.0, 2));
      final double rosinScrape = noise * rosin * (0.06 + 0.40 * slipTrigger * math.exp(-t / 0.09));

      final double exciterSig = (helmholtzSaw * effectivePressure + rosinScrape) * effectiveSpeed * attackEnv * tremMod * vel;
      outBuffer[i] = exciterSig.clamp(-2.0, 2.0);
    }
  }
}

/// Specialized Acoustic Body Cavity Resonator for the Bowed String Family.
/// Models the Helmholtz Air Cavity ($f_{A0}$), Top Plate ($f_{T1}$), Back Plate ($f_{B1}$),
/// and Bridge Rocking resonances for Violin, Viola, Cello, and Double Bass.
/// Also models Con Sordino (mute) top-end dampening.
class ViolinFamilyBodyResonatorNode extends GraphNode {
  final GraphNode input;
  final int instrumentType; // 0 = Violin, 1 = Viola, 2 = Cello, 3 = Double Bass
  final String? instrumentTypeParam;
  final double woodWarmth; // 0.0 to 2.0 (Resonator gain)
  final String? woodWarmthParam;
  final double conSordino; // 0.0 (Unmuted) to 1.0 (Full mute damper)
  final String? conSordinoParam;

  const ViolinFamilyBodyResonatorNode({
    required this.input,
    this.instrumentType = 0,
    this.instrumentTypeParam,
    this.woodWarmth = 0.50,
    this.woodWarmthParam,
    this.conSordino = 0.0,
    this.conSordinoParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List inBuf = Float32List(len);
    input.process(ctx, inBuf);
    outBuffer.fillRange(0, len, 0.0);

    int type = instrumentType;
    if (instrumentTypeParam != null) {
      type = ctx.getParam(instrumentTypeParam!, instrumentType.toDouble()).toInt().clamp(0, 3);
    }

    final double warmth = (woodWarmthParam != null ? ctx.getParam(woodWarmthParam!, woodWarmth) : woodWarmth).clamp(0.0, 2.0);
    double mute = (conSordinoParam != null ? ctx.getParam(conSordinoParam!, conSordino) : conSordino).clamp(0.0, 1.0);
    final art = ctx.articulation?.toLowerCase();
    if (art == 'sordino' || art == 'con_sordino' || art == 'mute') {
      mute = 1.0;
    }

    final double sr = ctx.sampleRate;

    // Resonant modes (Air Cavity f_A0, Main Top f_T1, Backplate f_B1, Formant Peak, Bridge/Air)
    List<double> freqs;
    List<double> gains;
    List<double> qFactors;

    switch (type) {
      case 0: // Violin: Soprano brilliance, Stradivarius spruce & bridge bite
        freqs = [280.0, 480.0, 580.0, 3100.0, 5600.0];
        gains = [0.75 * warmth, 0.70 * warmth, 0.55 * warmth, (1.0 - mute * 0.8) * 0.50 * warmth, (1.0 - mute * 0.9) * 0.28 * warmth];
        qFactors = [14.0, 18.0, 16.0, 9.0, 6.0];
        break;
      case 1: // Viola: Signature undersized body, reedy nasal 1.45kHz resonance, warm dark wood
        freqs = [220.0, 360.0, 480.0, 1450.0, 2400.0];
        gains = [0.65 * warmth, 0.58 * warmth, 0.45 * warmth, 0.62 * warmth, (1.0 - mute * 0.8) * 0.22 * warmth];
        qFactors = [14.0, 18.0, 16.0, 8.5, 12.0];
        break;
      case 2: // Cello: Singing tenor/baritone, deep chest cavity 98Hz/180Hz/380Hz, singing 1.2kHz
        freqs = [98.0, 180.0, 280.0, 420.0, 1200.0];
        gains = [0.85 * warmth, 0.78 * warmth, 0.62 * warmth, 0.55 * warmth, (1.0 - mute * 0.8) * 0.38 * warmth];
        qFactors = [12.0, 15.0, 14.0, 10.0, 8.0];
        break;
      case 3: // Double Bass: Sub air 58Hz, wood plate 98Hz, woody body punch 160Hz/280Hz
      default:
        freqs = [58.0, 98.0, 160.0, 280.0, 850.0];
        gains = [0.80 * warmth, 0.75 * warmth, 0.60 * warmth, 0.48 * warmth, (1.0 - mute * 0.8) * 0.25 * warmth];
        qFactors = [10.0, 12.0, 11.0, 9.0, 6.0];
        break;
    }

    for (int m = 0; m < freqs.length; m++) {
      final double f = freqs[m].clamp(20.0, sr * 0.48);
      final double g = gains[m];
      final double q = qFactors[m];

      final double w0 = 2.0 * math.pi * (f / sr);
      final double alpha = math.sin(w0) / (2.0 * q);

      final double b0 = alpha;
      final double b2 = -alpha;
      final double a0 = 1.0 + alpha;
      final double a1 = -2.0 * math.cos(w0);
      final double a2 = 1.0 - alpha;

      final double normB0 = (b0 / a0) * g;
      final double normB2 = (b2 / a0) * g;
      final double normA1 = a1 / a0;
      final double normA2 = a2 / a0;

      double z1 = 0.0;
      double z2 = 0.0;

      for (int i = 0; i < len; i++) {
        final double inSample = inBuf[i];
        final double outSample = normB0 * inSample + z1;
        z1 = -normA1 * outSample + z2;
        z2 = normB2 * inSample - normA2 * outSample;
        outBuffer[i] += outSample;
      }
    }

    // Direct sound bleed: 10% direct string presence so 90% is physical body wood radiation
    final double directGain = 0.10;
    for (int i = 0; i < len; i++) {
      outBuffer[i] += inBuf[i] * directGain;
    }
  }
}

/// Advanced Bowed String Waveguide Node.
/// Models physical string displacement with non-linear McIntyre-Schumacher-Woodhouse (MSW)
/// friction loop interaction, pitch bend tracking, expressive delayed vibrato, and string damping.
class BowedStringWaveguideNode extends GraphNode {
  final GraphNode exciter;
  final double sustain;
  final String? sustainParam;
  final double stringDamping;
  final String? stringDampingParam;
  final double vibratoDepth; // Pitch modulation depth (0.0 to 1.0 semitone)
  final String? vibratoDepthParam;
  final double vibratoRate; // Hz (typically 4.8 - 6.5 Hz)
  final String? vibratoRateParam;
  final double vibratoDelaySec; // Delay before vibrato blossoms naturally (~0.12 - 0.25s)
  final String? vibratoDelayParam;

  const BowedStringWaveguideNode({
    required this.exciter,
    this.sustain = 0.996,
    this.sustainParam,
    this.stringDamping = 0.18,
    this.stringDampingParam,
    this.vibratoDepth = 0.28,
    this.vibratoDepthParam,
    this.vibratoRate = 5.4,
    this.vibratoRateParam,
    this.vibratoDelaySec = 0.16,
    this.vibratoDelayParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    exciter.process(ctx, outBuffer);

    double baseFreq = ctx.freq > 10.0 ? ctx.freq : 440.0;
    final double sr = ctx.sampleRate;
    double fb = (sustainParam != null ? ctx.getParam(sustainParam!, sustain) : sustain).clamp(0.85, 0.9998);
    double damp = (stringDampingParam != null ? ctx.getParam(stringDampingParam!, stringDamping) : stringDamping).clamp(0.01, 0.92);
    final double vibDepth = (vibratoDepthParam != null ? ctx.getParam(vibratoDepthParam!, vibratoDepth) : vibratoDepth).clamp(0.0, 2.0);
    final double vibRate = (vibratoRateParam != null ? ctx.getParam(vibratoRateParam!, vibratoRate) : vibratoRate).clamp(1.0, 10.0);
    final double vibDelay = (vibratoDelayParam != null ? ctx.getParam(vibratoDelayParam!, vibratoDelaySec) : vibratoDelaySec).clamp(0.0, 1.0);

    final art = ctx.articulation?.toLowerCase();
    if (art == 'pizz' || art == 'pizzicato' || art == 'pluck') {
      // Natural decay of plucked acoustic string
      fb = math.min(fb, 0.991);
      damp = math.max(damp, 0.28);
    } else if (art == 'snap' || art == 'bartok') {
      fb = math.min(fb, 0.988);
      damp = math.max(damp, 0.35);
    } else if (art == 'spiccato' || art == 'staccato') {
      fb = math.min(fb, 0.982);
      damp = math.max(damp, 0.30);
    } else if (art == 'harmonics' || art == 'flageolet') {
      baseFreq *= 2.0;
      fb = math.max(fb, 0.997);
      damp = math.min(damp, 0.08);
    } else if (art == 'sordino' || art == 'con_sordino' || art == 'mute') {
      damp = math.max(damp, 0.45);
    }

    final double maxDelaySamples = sr / 20.0;
    final int bufSize = maxDelaySamples.toInt() + 32;
    final delayLine = Float32List(bufSize);
    int writeIdx = 0;
    double filterState = 0.0;

    for (int i = 0; i < len; i++) {
      final double t = i / sr;
      final double inSample = outBuffer[i];
      final double normTime = len > 1 ? i / (len - 1) : 0.0;
      final double bendSemitones = ctx.getPitchBendAt(normTime);

      // Delayed natural vibrato onset curve
      double currentVib = 0.0;
      if (t > vibDelay && vibDepth > 0.001) {
        final double vibRamp = ((t - vibDelay) / 0.25).clamp(0.0, 1.0);
        currentVib = math.sin(2.0 * math.pi * vibRate * t) * vibDepth * vibRamp;
      }

      final double totalSemitoneShift = bendSemitones + currentVib;
      final double curFreq = (baseFreq * math.pow(2.0, totalSemitoneShift / 12.0)).clamp(20.0, 20000.0);
      final double delaySamples = (sr / curFreq).clamp(2.0, bufSize - 4.0);

      // Read from delay line with linear interpolation
      final double readPos = writeIdx - delaySamples;
      double readIdxD = readPos >= 0 ? readPos : (readPos + bufSize);
      while (readIdxD >= bufSize) readIdxD -= bufSize;
      while (readIdxD < 0) readIdxD += bufSize;

      final int i0 = readIdxD.toInt() % bufSize;
      final int i1 = (i0 + 1) % bufSize;
      final double frac = readIdxD - readIdxD.floor();

      final double delayedSample = delayLine[i0] * (1.0 - frac) + delayLine[i1] * frac;

      // 1-Pole Lowpass loop damping filter
      filterState = (1.0 - damp) * delayedSample + damp * filterState;

      // Non-linear bow-string friction interaction: tanh soft limiting on loop feedback
      final double feedbackSignal = DistortionNode._tanh(filterState * fb + inSample * 0.7);

      delayLine[writeIdx] = feedbackSignal;
      writeIdx = (writeIdx + 1) % bufSize;

      outBuffer[i] = feedbackSignal;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WOODWIND & PIPE PHYSICAL MODELING PRIMITIVES (STK / CCRMA / FAUST ACOUSTICS)
// ─────────────────────────────────────────────────────────────────────────────

/// High-fidelity Woodwind & Pipe Digital Waveguide Node.
/// Models:
/// - Jet-edge non-linearity (Perry Cook / STK Flute & Romain Michon Faust pm.flute)
/// - Embouchure vortex shedding and pink breath air turbulence
/// - Labium / Fipple / Utaguchi transient chiff burst on attack
/// - Bore delay line reflection (0: open-open pipe, 1: closed-open pipe [odd harmonics], 2: Helmholtz cavity)
/// - Continuous sustained ADSR breath pressure envelope
/// - Delayed natural lyrical vibrato
class AcousticWoodwindWaveguideNode extends GraphNode {
  final int pipeType; // 0: Open cylindrical, 1: Closed cylindrical (odd harmonics), 2: Helmholtz cavity
  final double defaultPressure;
  final String? pressureParam;
  final double defaultChiff;
  final String? chiffParam;
  final double defaultTurbulence;
  final String? turbulenceParam;
  final double defaultOverblow;
  final String? overblowParam;
  final double defaultDamping;
  final String? dampingParam;
  final double defaultVibDepth;
  final String? vibDepthParam;
  final double defaultVibRate;
  final String? vibRateParam;
  final double defaultVibDelay;
  final String? vibDelayParam;
  final double defaultAttack;
  final String? attackParam;
  final double defaultDecay;
  final String? decayParam;
  final double defaultSustain;
  final String? sustainParam;
  final double defaultRelease;
  final String? releaseParam;
  final double octaveOffset; // e.g. +1.0 for Piccolo (transposing octave up)
  final double jetGain;

  const AcousticWoodwindWaveguideNode({
    this.pipeType = 0,
    this.defaultPressure = 1.15,
    this.pressureParam,
    this.defaultChiff = 0.50,
    this.chiffParam,
    this.defaultTurbulence = 0.25,
    this.turbulenceParam,
    this.defaultOverblow = 0.0,
    this.overblowParam,
    this.defaultDamping = 0.22,
    this.dampingParam,
    this.defaultVibDepth = 0.28,
    this.vibDepthParam,
    this.defaultVibRate = 5.6,
    this.vibRateParam,
    this.defaultVibDelay = 0.18,
    this.vibDelayParam,
    this.defaultAttack = 0.035,
    this.attackParam,
    this.defaultDecay = 0.14,
    this.decayParam,
    this.defaultSustain = 0.85,
    this.sustainParam,
    this.defaultRelease = 0.25,
    this.releaseParam,
    this.octaveOffset = 0.0,
    this.jetGain = 1.35,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final double sr = ctx.sampleRate;

    // 1. Resolve Dynamic Parameters
    final double pressure = (pressureParam != null ? ctx.getParam(pressureParam!, defaultPressure) : defaultPressure).clamp(0.2, 3.0);
    final double chiff = (chiffParam != null ? ctx.getParam(chiffParam!, defaultChiff) : defaultChiff).clamp(0.0, 2.0);
    final double turbulence = (turbulenceParam != null ? ctx.getParam(turbulenceParam!, defaultTurbulence) : defaultTurbulence).clamp(0.0, 1.5);
    final double overblow = (overblowParam != null ? ctx.getParam(overblowParam!, defaultOverblow) : defaultOverblow).clamp(0.0, 1.0);
    final double damp = (dampingParam != null ? ctx.getParam(dampingParam!, defaultDamping) : defaultDamping).clamp(0.02, 0.95);
    final double vibDepth = (vibDepthParam != null ? ctx.getParam(vibDepthParam!, defaultVibDepth) : defaultVibDepth).clamp(0.0, 2.0);
    final double vibRate = (vibRateParam != null ? ctx.getParam(vibRateParam!, defaultVibRate) : defaultVibRate).clamp(1.0, 12.0);
    final double vibDelay = (vibDelayParam != null ? ctx.getParam(vibDelayParam!, defaultVibDelay) : defaultVibDelay).clamp(0.0, 1.0);

    final double attack = (attackParam != null ? ctx.getParam(attackParam!, defaultAttack) : defaultAttack).clamp(0.002, 1.0);
    final double decay = (decayParam != null ? ctx.getParam(decayParam!, defaultDecay) : defaultDecay).clamp(0.005, 1.5);
    final double sustain = (sustainParam != null ? ctx.getParam(sustainParam!, defaultSustain) : defaultSustain).clamp(0.1, 1.0);
    final double release = (releaseParam != null ? ctx.getParam(releaseParam!, defaultRelease) : defaultRelease).clamp(0.01, 2.0);

    // Fundamental Frequency with Octave Shift & Overblow Register Jump
    double baseFreq = (ctx.freq > 10.0 ? ctx.freq : 440.0) * math.pow(2.0, octaveOffset);
    if (overblow > 0.5) {
      baseFreq *= 2.0;
    }

    // Dynamic proportional ADSR scaling for short-duration note events (e.g. tracker steps)
    double effAttack = attack;
    double effDecay = decay;
    double effRelease = release;
    final double minEnvDur = effAttack + effDecay + effRelease;
    if (ctx.durationSec < minEnvDur) {
      final double scale = (ctx.durationSec / minEnvDur).clamp(0.05, 1.0);
      effAttack *= scale;
      effDecay *= scale;
      effRelease *= scale;
    }
    final double gateTime = math.max(effAttack + effDecay, ctx.durationSec - effRelease);

    // Delay line sizing
    final double maxDelaySamples = sr / 20.0;
    final int bufSize = maxDelaySamples.toInt() + 64;
    final delayLine = Float32List(bufSize);
    int writeIdx = 0;
    double filterState = 0.0;
    double dcBlockX = 0.0;
    double dcBlockY = 0.0;

    int prngState = 0x54321A79 ^ (ctx.midiNote * 197);

    for (int i = 0; i < len; i++) {
      final double t = i / sr;
      final double normTime = len > 1 ? i / (len - 1) : 0.0;
      final double bendSemitones = ctx.getPitchBendAt(normTime);

      // 2. Continuous ADSR Breath Pressure Envelope
      double env;
      if (t < effAttack) {
        env = (t / effAttack);
      } else if (t < (effAttack + effDecay)) {
        final double dProgress = (t - effAttack) / effDecay;
        env = 1.0 - dProgress * (1.0 - sustain);
      } else if (t < gateTime) {
        env = sustain;
      } else {
        final double relTime = t - gateTime;
        env = sustain * math.max(0.0, 1.0 - (relTime / effRelease));
      }

      // 3. Delayed Natural Vibrato
      double currentVib = 0.0;
      if (t > vibDelay && vibDepth > 0.001) {
        final double vibRamp = ((t - vibDelay) / 0.22).clamp(0.0, 1.0);
        currentVib = math.sin(2.0 * math.pi * vibRate * t) * (vibDepth * 0.015) * vibRamp;
      }

      final double totalSemitoneShift = bendSemitones;
      final double curFreq = (baseFreq * math.pow(2.0, totalSemitoneShift / 12.0) * (1.0 + currentVib)).clamp(20.0, 18000.0);

      // 4. Labium / Fipple Chiff Transient Burst (First 20-55ms)
      double chiffBurst = 0.0;
      if (t < 0.055 && chiff > 0.001) {
        final double chiffDecay = math.exp(-t * 85.0);
        chiffBurst = math.sin(2.0 * math.pi * (curFreq * 3.8) * t) * chiffDecay * chiff * 0.55;
      }

      // 5. Modulated Pink/Bandpass Air Jet Turbulence
      prngState ^= (prngState << 13) & 0xFFFFFFFF;
      prngState ^= (prngState >> 17) & 0xFFFFFFFF;
      prngState ^= (prngState << 5) & 0xFFFFFFFF;
      final double rawNoise = ((prngState & 0xFFFFFF) / 8388607.5) - 1.0;
      // Couple vortex shedding turbulence to fundamental oscillation
      final double vortexMod = 0.7 + 0.3 * math.sin(2.0 * math.pi * curFreq * t);
      final double breathNoise = rawNoise * turbulence * 0.18 * vortexMod * env;

      // Cylindrical & Cavity Waveguide Loop (0: Open Pipe / Cavity, 1: Closed Pipe)
      // For open pipe & cavity: L = sr / curFreq
      // For closed pipe (Pan Flute): quarter-wave odd harmonics (sr / 2f)
      final double delaySamples = (pipeType == 1
          ? (sr / (2.0 * curFreq))
          : (sr / curFreq)).clamp(2.0, bufSize - 4.0);

      final double readPos = writeIdx - delaySamples;
      double readIdxD = readPos >= 0 ? readPos : (readPos + bufSize);
      while (readIdxD >= bufSize) readIdxD -= bufSize;
      while (readIdxD < 0) readIdxD += bufSize;

      final int i0 = readIdxD.toInt() % bufSize;
      final int i1 = (i0 + 1) % bufSize;
      final double frac = readIdxD - readIdxD.floor();

      final double delayedSample = delayLine[i0] * (1.0 - frac) + delayLine[i1] * frac;

      // DC-Blocking Filter (prevents DC breath pressure from latching the nonlinear loop into saturation)
      final double dcBlocked = delayedSample - dcBlockX + 0.995 * dcBlockY;
      dcBlockX = delayedSample;
      dcBlockY = dcBlocked;

      // 1-Pole Lowpass loop damping filter
      filterState = (1.0 - damp) * dcBlocked + damp * filterState;

      // Non-linear air-jet splitting saturation (STK / Faust tanh non-linearity)
      final double jetInput = (breathNoise + chiffBurst + env * pressure * 0.35) - 0.54 * filterState;
      final double jetOutput = DistortionNode._tanh(jetInput * jetGain);

      // Reflection sign: -1.0 for open-open pipe and cavity mouth
      final double boreReflection = -filterState * 0.96;
      final double feedbackSignal = DistortionNode._tanh(jetOutput + boreReflection);

      delayLine[writeIdx] = feedbackSignal;
      writeIdx = (writeIdx + 1) % bufSize;

      outBuffer[i] = feedbackSignal * env * ctx.velocity;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PIANO & KEYBOARD PHYSICAL MODELING PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

/// Nonlinear Piano Felt Hammer Exciter.
/// Simulates felt compression dynamics where higher velocity produces a narrower,
/// sharper strike pulse with increased high-frequency harmonic energy, blended
/// with wooden hammer core contact transient.
class PianoHammerExciterNode extends GraphNode {
  final double hammerHardness; // 0.0 Soft Felt <-> 1.0 Hard Lacquered Felt
  final String? hammerHardnessParam;
  final double feltSoftness;   // 0.0 Concert Hammer <-> 1.0 Muted Felt Blanket
  final String? feltSoftnessParam;
  final double strikeNoise;    // Wooden hammer knock transient level
  final String? strikeNoiseParam;

  const PianoHammerExciterNode({
    this.hammerHardness = 0.5,
    this.hammerHardnessParam,
    this.feltSoftness = 0.0,
    this.feltSoftnessParam,
    this.strikeNoise = 0.25,
    this.strikeNoiseParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double vel = ctx.velocity.clamp(0.01, 1.0);
    final double hardness = (hammerHardnessParam != null ? ctx.getParam(hammerHardnessParam!, hammerHardness) : hammerHardness).clamp(0.05, 2.0);
    final double softFelt = (feltSoftnessParam != null ? ctx.getParam(feltSoftnessParam!, feltSoftness) : feltSoftness).clamp(0.0, 1.0);
    final double knock = (strikeNoiseParam != null ? ctx.getParam(strikeNoiseParam!, strikeNoise) : strikeNoise).clamp(0.0, 1.0);

    // Pulse duration narrows with velocity & hammer hardness (nonlinear compliance F ~ y^p)
    final double basePulseMs = 3.8 * (1.0 + softFelt * 1.5) / (math.pow(vel, 0.45) * math.sqrt(hardness));
    final int pulseSamples = ((basePulseMs / 1000.0) * sr).round().clamp(3, (0.015 * sr).toInt());

    int seed = 0x51A07 + ctx.midiNote * 19;

    for (int i = 0; i < outBuffer.length; i++) {
      double sample = 0.0;
      if (i < pulseSamples) {
        final double phase = i / pulseSamples;
        // Non-linear half-cosine raised pulse
        final double shape = math.sin(phase * math.pi);
        // Exponent sharpens waveform on harder hits
        final double exponent = 1.0 + hardness * 1.2 * vel * (1.0 - softFelt * 0.7);
        sample = math.pow(shape, exponent).toDouble() * vel;

        // Wood hammer core strike knock (bandpass-shaped transient)
        if (knock > 0.001 && i < (pulseSamples ~/ 2 + 6)) {
          seed ^= (seed << 13) & 0xFFFFFFFF;
          seed ^= (seed >> 17) & 0xFFFFFFFF;
          seed ^= (seed << 5) & 0xFFFFFFFF;
          final double rand = ((seed & 0xFFFFFF) / 8388607.5) - 1.0;
          final double knockDecay = math.exp(-i / 6.0);
          sample += rand * knock * 0.35 * vel * knockDecay;
        }
      }
      outBuffer[i] = sample;
    }
  }
}

/// Acoustic Piano Spruce Soundboard Resonator.
/// Simulates 2D spruce soundboard plate modes, bridge impedance coupling,
/// and morphs between a compact Upright Piano cabinet and a 9-foot Concert Grand plate.
class PianoSoundboardNode extends GraphNode {
  final GraphNode input;
  final double soundboardProfile; // 0.0 Compact Upright <-> 1.0 9ft Concert Grand
  final String? soundboardProfileParam;
  final double bridgeCoupling;    // 0.0 Dry <-> 1.0 Rich modal resonance
  final String? bridgeCouplingParam;
  final double duplexSheen;       // High-frequency duplex scaling shimmer
  final String? duplexSheenParam;

  const PianoSoundboardNode({
    required this.input,
    this.soundboardProfile = 0.75,
    this.soundboardProfileParam,
    this.bridgeCoupling = 0.45,
    this.bridgeCouplingParam,
    this.duplexSheen = 0.35,
    this.duplexSheenParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    input.process(ctx, outBuffer);

    final double profile = (soundboardProfileParam != null ? ctx.getParam(soundboardProfileParam!, soundboardProfile) : soundboardProfile).clamp(0.0, 1.0);
    final double coupling = (bridgeCouplingParam != null ? ctx.getParam(bridgeCouplingParam!, bridgeCoupling) : bridgeCoupling).clamp(0.0, 1.5);
    final double sheen = (duplexSheenParam != null ? ctx.getParam(duplexSheenParam!, duplexSheen) : duplexSheen).clamp(0.0, 1.0);
    final double sr = ctx.sampleRate;

    // Resonant modal frequencies morph with cabinet/grand plate dimensions
    // Low air mode: 110Hz (Upright) -> 68Hz (Concert Grand)
    final double fAir = 110.0 - profile * 42.0;
    // Main spruce plate bending modes
    final double fMode1 = 220.0 - profile * 45.0;
    final double fMode2 = 380.0 - profile * 60.0;
    final double fMode3 = 680.0 + profile * 140.0;
    final double fDuplex = 4200.0 + profile * 800.0;

    // Bi-quad bandpass filter states for 4 soundboard modes + duplex scale
    double s1Air = 0.0, s2Air = 0.0;
    double s1M1 = 0.0, s2M1 = 0.0;
    double s1M2 = 0.0, s2M2 = 0.0;
    double s1M3 = 0.0, s2M3 = 0.0;
    double s1Dup = 0.0, s2Dup = 0.0;

    // Filter coefficients helper
    List<double> bpfCoeffs(double f0, double q) {
      final double omega = 2.0 * math.pi * f0 / sr;
      final double alpha = math.sin(omega) / (2.0 * q);
      final double b0 = alpha;
      final double b1 = 0.0;
      final double b2 = -alpha;
      final double a0 = 1.0 + alpha;
      final double a1 = -2.0 * math.cos(omega);
      final double a2 = 1.0 - alpha;
      return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0];
    }

    final cAir = bpfCoeffs(fAir, 3.2 + profile * 1.5);
    final cM1 = bpfCoeffs(fMode1, 4.0);
    final cM2 = bpfCoeffs(fMode2, 4.5);
    final cM3 = bpfCoeffs(fMode3, 5.0);
    final cDup = bpfCoeffs(fDuplex, 6.0);

    for (int i = 0; i < len; i++) {
      final double x = outBuffer[i];

      // Air mode
      final double yAir = cAir[0] * x - cAir[3] * s1Air - cAir[4] * s2Air;
      s2Air = s1Air;
      s1Air = yAir;

      // Mode 1
      final double yM1 = cM1[0] * x - cM1[3] * s1M1 - cM1[4] * s2M1;
      s2M1 = s1M1;
      s1M1 = yM1;

      // Mode 2
      final double yM2 = cM2[0] * x - cM2[3] * s1M2 - cM2[4] * s2M2;
      s2M2 = s1M2;
      s1M2 = yM2;

      // Mode 3
      final double yM3 = cM3[0] * x - cM3[3] * s1M3 - cM3[4] * s2M3;
      s2M3 = s1M3;
      s1M3 = yM3;

      // Duplex scale high shimmer
      final double yDup = cDup[0] * x - cDup[3] * s1Dup - cDup[4] * s2Dup;
      s2Dup = s1Dup;
      s1Dup = yDup;

      final double soundboardReso = (yAir * 0.45 + yM1 * 0.35 + yM2 * 0.30 + yM3 * 0.25 + yDup * (0.35 * sheen)) * coupling;
      outBuffer[i] = x + soundboardReso;
    }
  }
}

/// Tack Piano Hammer Exciter.
/// Simulates a metallic thumb-tack inserted into the hammer felt,
/// producing a razor-sharp metallic transient ping and punchy vintage bite.
class TackExciterNode extends GraphNode {
  final double tackBite;     // 0.0 Muted Tack <-> 1.0 Bright Steel Tack
  final String? tackBiteParam;
  final double hammerKnock;
  final String? hammerKnockParam;

  const TackExciterNode({
    this.tackBite = 0.70,
    this.tackBiteParam,
    this.hammerKnock = 0.40,
    this.hammerKnockParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double vel = ctx.velocity.clamp(0.01, 1.0);
    final double bite = (tackBiteParam != null ? ctx.getParam(tackBiteParam!, tackBite) : tackBite).clamp(0.0, 1.5);
    final double knock = (hammerKnockParam != null ? ctx.getParam(hammerKnockParam!, hammerKnock) : hammerKnock).clamp(0.0, 1.0);

    final double tackFreq = 4200.0 + ctx.midiNote * 35.0;
    final int pulseSamples = ((0.0035 / (math.pow(vel, 0.35))) * sr).round().clamp(2, (0.008 * sr).toInt());

    int seed = 0x7AC11 + ctx.midiNote * 23;

    for (int i = 0; i < outBuffer.length; i++) {
      double sample = 0.0;
      final double t = i / sr;

      // Felt impact baseline
      if (i < pulseSamples) {
        final double phase = i / pulseSamples;
        sample = math.sin(phase * math.pi) * vel;
      }

      // High-frequency metallic tack ping (decaying 4.2kHz sine ring)
      if (t < 0.025) {
        final double pingDecay = math.exp(-t * 220.0);
        final double ping = math.sin(2.0 * math.pi * tackFreq * t) * pingDecay * bite * vel;
        sample += ping;
      }

      // Wooden action clack
      if (knock > 0.001 && i < (pulseSamples + 12)) {
        seed ^= (seed << 13) & 0xFFFFFFFF;
        seed ^= (seed >> 17) & 0xFFFFFFFF;
        seed ^= (seed << 5) & 0xFFFFFFFF;
        final double rand = ((seed & 0xFFFFFF) / 8388607.5) - 1.0;
        final double knockDecay = math.exp(-i / 8.0);
        sample += rand * knock * 0.45 * vel * knockDecay;
      }

      outBuffer[i] = sample;
    }
  }
}

/// Physical Modal Bar Resonator for Toy Piano / Metallophone.
/// Simulates clamped metal tines/rods struck by plastic/wood hammers,
/// producing non-harmonic cantilever modal frequencies (1.0, 2.756, 5.404, 8.933),
/// realistic hammer micro-bounce flam (double-hit), keybed bottoming clack,
/// miniature wooden toy enclosure resonance, and gravity release drop thud.
class ToyPianoMetalRodNode extends GraphNode {
  final double clangRatio;   // Metallic clang / inharmonic overtone mix
  final String? clangRatioParam;
  final double tineDecay;    // Ring decay time
  final String? tineDecayParam;
  final double hammerClack;  // Plastic/wood strike transient
  final String? hammerClackParam;
  final double hammerBounce; // Micro-rebound flam (double-hit) intensity
  final String? hammerBounceParam;
  final double boxResonance; // Miniature wooden casing resonance
  final String? boxResonanceParam;
  final double releaseDrop;  // Gravity key/hammer return drop thud
  final String? releaseDropParam;

  const ToyPianoMetalRodNode({
    this.clangRatio = 0.65,
    this.clangRatioParam,
    this.tineDecay = 1.2,
    this.tineDecayParam,
    this.hammerClack = 0.50,
    this.hammerClackParam,
    this.hammerBounce = 0.45,
    this.hammerBounceParam,
    this.boxResonance = 0.40,
    this.boxResonanceParam,
    this.releaseDrop = 0.40,
    this.releaseDropParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double f0 = ctx.freq > 0 ? ctx.freq : 440.0;
    final double vel = ctx.velocity.clamp(0.01, 1.0);
    final double clang = (clangRatioParam != null ? ctx.getParam(clangRatioParam!, clangRatio) : clangRatio).clamp(0.0, 1.5);
    final double decay = (tineDecayParam != null ? ctx.getParam(tineDecayParam!, tineDecay) : tineDecay).clamp(0.1, 4.0);
    final double clack = (hammerClackParam != null ? ctx.getParam(hammerClackParam!, hammerClack) : hammerClack).clamp(0.0, 1.0);
    final double bounce = (hammerBounceParam != null ? ctx.getParam(hammerBounceParam!, hammerBounce) : hammerBounce).clamp(0.0, 1.0);
    final double boxReso = (boxResonanceParam != null ? ctx.getParam(boxResonanceParam!, boxResonance) : boxResonance).clamp(0.0, 1.0);
    final double relDrop = (releaseDropParam != null ? ctx.getParam(releaseDropParam!, releaseDrop) : releaseDrop).clamp(0.0, 1.0);

    // Cantilever clamped steel rod non-harmonic mode ratios
    final double fMode1 = f0;
    final double fMode2 = f0 * 2.7565;
    final double fMode3 = f0 * 5.404;
    final double fMode4 = math.min(18000.0, f0 * 8.933);

    // Damping rates per mode
    final double d1 = (1.8 / decay);
    final double d2 = (5.5 / decay) + (f0 / 300.0);
    final double d3 = (14.0 / decay) + (f0 / 150.0);
    final double d4 = (32.0 / decay) + (f0 / 80.0);

    // Toy piano acoustic mechanical action:
    // 1. Hammer micro-rebound flam: 16ms - 26ms after primary strike
    final double bounceDelaySec = 0.016 + (1.0 - vel) * 0.010;
    // 2. Keybed bottoming thud (~240Hz wooden knock)
    final double fKeybed = 240.0;
    // 3. Wooden toy body box formant (~340Hz cavity)
    final double fBox = 340.0;
    // 4. Release drop timing (towards end of note or release velocity)
    final double releaseTimeSec = math.max(0.05, ctx.durationSec - 0.045);
    final double relVel = ctx.releaseVelocity.clamp(0.1, 1.0);

    int seed = 0x33B10 + ctx.midiNote * 29;

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;

      // Mode 1: Fundamental ring
      final double y1 = math.sin(2.0 * math.pi * fMode1 * t) * math.exp(-t * d1);

      // Mode 2: Clang 1st overtone
      final double y2 = math.sin(2.0 * math.pi * fMode2 * t) * math.exp(-t * d2) * 0.65 * clang;

      // Mode 3: High chime
      final double y3 = math.sin(2.0 * math.pi * fMode3 * t) * math.exp(-t * d3) * 0.35 * clang;

      // Mode 4: Initial metallic strike shimmer
      final double y4 = math.sin(2.0 * math.pi * fMode4 * t) * math.exp(-t * d4) * 0.20 * clang;

      // Primary Plastic/wood strike clack + keybed bottoming thud
      double clackTransient = 0.0;
      if (clack > 0.001 && t < 0.02) {
        seed ^= (seed << 13) & 0xFFFFFFFF;
        seed ^= (seed >> 17) & 0xFFFFFFFF;
        seed ^= (seed << 5) & 0xFFFFFFFF;
        final double rand = ((seed & 0xFFFFFF) / 8388607.5) - 1.0;
        final double sharpClack = rand * math.exp(-t * 260.0) * clack * 0.4;
        final double keybedThud = math.sin(2.0 * math.pi * fKeybed * t) * math.exp(-t * 180.0) * clack * 0.3;
        clackTransient = sharpClack + keybedThud;
      }

      // Secondary Hammer Micro-Rebound Flam ("Double-Hit")
      double bounceTransient = 0.0;
      if (bounce > 0.001 && t >= bounceDelaySec) {
        final double tb = t - bounceDelaySec;
        if (tb < 0.03) {
          final double bMode1 = math.sin(2.0 * math.pi * fMode1 * tb) * math.exp(-tb * d1 * 1.5) * 0.35;
          final double bMode2 = math.sin(2.0 * math.pi * fMode2 * tb) * math.exp(-tb * d2 * 1.5) * 0.22 * clang;
          final double bClick = math.sin(2.0 * math.pi * 3100.0 * tb) * math.exp(-tb * 300.0) * 0.25;
          bounceTransient = (bMode1 + bMode2 + bClick) * bounce * (0.35 + 0.45 * vel);
        }
      }

      // Wooden housing cavity boom
      final double boxTransient = math.sin(2.0 * math.pi * fBox * t) * math.exp(-t * 45.0) * (0.25 * boxReso);

      // Key-Release Drop Thump & Return Clatter (gravity return to rest rail)
      double releaseTransient = 0.0;
      if (relDrop > 0.001 && t >= releaseTimeSec) {
        final double tr = t - releaseTimeSec;
        final double woodDrop = math.sin(2.0 * math.pi * 210.0 * tr) * math.exp(-tr * 75.0);
        final double feltTap = math.sin(2.0 * math.pi * 950.0 * tr) * math.exp(-tr * 180.0) * 0.4;
        releaseTransient = (woodDrop + feltTap) * (0.28 * relDrop * relVel);
      }

      final double raw = (y1 * 0.85 + y2 + y3 + y4 + clackTransient + bounceTransient + boxTransient + releaseTransient) * vel;
      outBuffer[i] = DistortionNode._tanh(raw * 1.15) * 0.95;
    }
  }
}

/// Physical Modal Bar Resonator for Glockenspiel (Orchestral Bells).
/// Free-free high-carbon rectangular steel bar with Euler-Bernoulli modes
/// (1.0, 2.7565, 5.404, 8.933), pristine high Q sustain (minimal internal damping),
/// and brass/phenolic hard point-contact mallet excitation.
class GlockenspielBarNode extends GraphNode {
  final double barDecay;
  final String? barDecayParam;
  final double bellShimmer;
  final String? bellShimmerParam;
  final double malletHardness;
  final String? malletHardnessParam;

  const GlockenspielBarNode({
    this.barDecay = 3.2,
    this.barDecayParam,
    this.bellShimmer = 0.70,
    this.bellShimmerParam,
    this.malletHardness = 0.75,
    this.malletHardnessParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double f0 = ctx.freq > 0 ? ctx.freq : 880.0;
    final double vel = ctx.velocity.clamp(0.01, 1.0);
    final double decay = (barDecayParam != null ? ctx.getParam(barDecayParam!, barDecay) : barDecay).clamp(0.3, 8.0);
    final double shimmer = (bellShimmerParam != null ? ctx.getParam(bellShimmerParam!, bellShimmer) : bellShimmer).clamp(0.0, 1.5);
    final double hardness = (malletHardnessParam != null ? ctx.getParam(malletHardnessParam!, malletHardness) : malletHardness).clamp(0.05, 1.2);

    // Free-free solid steel bar modal ratios
    final double f1 = f0;
    final double f2 = f0 * 2.7565;
    final double f3 = f0 * 5.404;
    final double f4 = math.min(19200.0, f0 * 8.933);

    // Steel has extremely low internal friction -> long crystalline ring
    final double d1 = 0.40 / decay;
    final double d2 = (1.6 / decay) + (f0 / 900.0);
    final double d3 = (4.8 / decay) + (f0 / 450.0);
    final double d4 = (12.0 / decay) + (f0 / 220.0);

    int seed = 0x77A12 ^ (ctx.midiNote * 43);

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;

      // Mode 1: Pristine singing fundamental
      final double y1 = math.sin(2.0 * math.pi * f1 * t) * math.exp(-t * d1);

      // Mode 2: Inharmonic bar shimmer
      final double y2 = math.sin(2.0 * math.pi * f2 * t) * math.exp(-t * d2) * (0.60 * shimmer);

      // Mode 3: High bell overtone
      final double y3 = math.sin(2.0 * math.pi * f3 * t) * math.exp(-t * d3) * (0.35 * shimmer);

      // Mode 4: Brilliant crystalline overtone
      final double y4 = math.sin(2.0 * math.pi * f4 * t) * math.exp(-t * d4) * (0.22 * shimmer);

      // Mallet point-contact strike transient (brass / phenolic click)
      double strikeTransient = 0.0;
      if (t < 0.012) {
        seed ^= (seed << 13) & 0xFFFFFFFF;
        seed ^= (seed >> 17) & 0xFFFFFFFF;
        seed ^= (seed << 5) & 0xFFFFFFFF;
        final double rand = ((seed & 0xFFFFFF) / 8388607.5) - 1.0;
        final double metallicClick = math.sin(2.0 * math.pi * 7800.0 * t) * math.exp(-t * 900.0) * 0.45;
        final double noiseImpulse = rand * math.exp(-t * 500.0) * 0.25;
        strikeTransient = (metallicClick + noiseImpulse) * hardness;
      }

      final double raw = (y1 * 0.90 + y2 + y3 + y4 + strikeTransient) * vel;
      outBuffer[i] = DistortionNode._tanh(raw * 1.10) * 0.90;
    }
  }
}

/// Physical Modal Resonator for Music Box Comb Tines.
/// Clamped-free cantilever steel lamellae with theoretical modal series
/// (1.0, 6.267, 17.55), Heaviside step displacement excitation (plucking by cylinder pin),
/// pre-release pin-scraping tick, and wooden box/tabletop soundboard resonance.
class MusicBoxTineNode extends GraphNode {
  final double tineDecay;
  final String? tineDecayParam;
  final double pinScrape;
  final String? pinScrapeParam;
  final double boxWarmth;
  final String? boxWarmthParam;
  final double highTineRing;
  final String? highTineRingParam;

  const MusicBoxTineNode({
    this.tineDecay = 2.0,
    this.tineDecayParam,
    this.pinScrape = 0.45,
    this.pinScrapeParam,
    this.boxWarmth = 0.50,
    this.boxWarmthParam,
    this.highTineRing = 0.50,
    this.highTineRingParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double f0 = ctx.freq > 0 ? ctx.freq : 523.25;
    final double vel = ctx.velocity.clamp(0.01, 1.0);
    final double decay = (tineDecayParam != null ? ctx.getParam(tineDecayParam!, tineDecay) : tineDecay).clamp(0.2, 5.0);
    final double scrape = (pinScrapeParam != null ? ctx.getParam(pinScrapeParam!, pinScrape) : pinScrape).clamp(0.0, 1.2);
    final double warmth = (boxWarmthParam != null ? ctx.getParam(boxWarmthParam!, boxWarmth) : boxWarmth).clamp(0.0, 1.2);
    final double highRing = (highTineRingParam != null ? ctx.getParam(highTineRingParam!, highTineRing) : highTineRing).clamp(0.0, 1.5);

    // Clamped cantilever beam modal ratios (plucked steel comb)
    final double f1 = f0;
    final double f2 = f0 * 6.267;
    final double f3 = math.min(18500.0, f0 * 17.55);

    final double d1 = 1.1 / decay;
    final double d2 = (5.8 / decay) + (f0 / 400.0);
    final double d3 = (22.0 / decay) + (f0 / 120.0);

    // Tabletop / wooden box coupling resonance (~560Hz)
    final double fSoundboard = 560.0;

    int seed = 0x5C91B ^ (ctx.midiNote * 53);

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;

      // Plucked Heaviside step displacement release: Cosine initial phase
      final double y1 = math.cos(2.0 * math.pi * f1 * t) * math.exp(-t * d1);
      final double y2 = math.cos(2.0 * math.pi * f2 * t) * math.exp(-t * d2) * (0.35 * highRing);
      final double y3 = math.cos(2.0 * math.pi * f3 * t) * math.exp(-t * d3) * (0.16 * highRing);

      // Pre-pluck pin friction scrape & slip tick (cylinder pin dragging against tine)
      double scrapeTransient = 0.0;
      if (t < 0.008 && scrape > 0.001) {
        seed ^= (seed << 13) & 0xFFFFFFFF;
        seed ^= (seed >> 17) & 0xFFFFFFFF;
        seed ^= (seed << 5) & 0xFFFFFFFF;
        final double rand = ((seed & 0xFFFFFF) / 8388607.5) - 1.0;
        final double pinRamp = (t / 0.008);
        scrapeTransient = (rand * 0.25 + math.sin(2.0 * math.pi * 4400.0 * t) * 0.4) * pinRamp * scrape * 0.45;
      }

      // Wooden casing / tabletop acoustic warmth
      final double soundboardRing = math.sin(2.0 * math.pi * fSoundboard * t) * math.exp(-t * 55.0) * (0.30 * warmth);

      final double raw = (y1 * 0.95 + y2 + y3 + scrapeTransient + soundboardRing) * vel;
      outBuffer[i] = DistortionNode._tanh(raw * 1.12) * 0.92;
    }
  }
}

/// Physical Modal Resonator for Xylophone (Honduran Rosewood Arched Bar).
/// Suspended rosewood bar with undercut arch carved to tune Mode 2 precisely
/// to the triple octave (3.0 * f0), high internal damping (dry woody pop),
/// and quarter-wave tuned air resonator tube burst.
class XylophoneBarNode extends GraphNode {
  final double woodDecay;
  final String? woodDecayParam;
  final double resonatorPop;
  final String? resonatorPopParam;
  final double malletHardness;
  final String? malletHardnessParam;
  final double tripleOctave;
  final String? tripleOctaveParam;

  const XylophoneBarNode({
    this.woodDecay = 0.32,
    this.woodDecayParam,
    this.resonatorPop = 0.65,
    this.resonatorPopParam,
    this.malletHardness = 0.70,
    this.malletHardnessParam,
    this.tripleOctave = 0.55,
    this.tripleOctaveParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double f0 = ctx.freq > 0 ? ctx.freq : 440.0;
    final double vel = ctx.velocity.clamp(0.01, 1.0);
    final double decay = (woodDecayParam != null ? ctx.getParam(woodDecayParam!, woodDecay) : woodDecay).clamp(0.06, 1.5);
    final double pop = (resonatorPopParam != null ? ctx.getParam(resonatorPopParam!, resonatorPop) : resonatorPop).clamp(0.0, 1.5);
    final double hardness = (malletHardnessParam != null ? ctx.getParam(malletHardnessParam!, malletHardness) : malletHardness).clamp(0.1, 1.2);
    final double overtone3x = (tripleOctaveParam != null ? ctx.getParam(tripleOctaveParam!, tripleOctave) : tripleOctave).clamp(0.0, 1.2);

    // Undercut arched rosewood bar modes:
    // Mode 1: Fundamental
    // Mode 2: Tuned triple-octave harmonic (3.0 * f0)
    // Mode 3: High inharmonic mode (~6.52 * f0)
    final double f1 = f0;
    final double f2 = f0 * 3.00;
    final double f3 = math.min(18000.0, f0 * 6.52);

    // Rosewood has high internal damping -> dry, woody, punchy staccato
    final double d1 = 6.2 / decay;
    final double d2 = (16.0 / decay) + (f0 / 250.0);
    final double d3 = (42.0 / decay) + (f0 / 100.0);

    int seed = 0x24B91 ^ (ctx.midiNote * 67);

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;

      // Mode 1: Woody fundamental
      final double y1 = math.sin(2.0 * math.pi * f1 * t) * math.exp(-t * d1);

      // Mode 2: Tuned triple octave
      final double y2 = math.sin(2.0 * math.pi * f2 * t) * math.exp(-t * d2) * (0.60 * overtone3x);

      // Mode 3: Transient inharmonic click
      final double y3 = math.sin(2.0 * math.pi * f3 * t) * math.exp(-t * d3) * (0.28 * overtone3x);

      // Tuned quarter-wave resonator tube air column pop burst
      final double tubeResonator = math.sin(2.0 * math.pi * f1 * t) * math.exp(-t * 90.0) * (0.50 * pop);

      // Hard wood / rubber mallet contact knock
      double malletTransient = 0.0;
      if (t < 0.010) {
        seed ^= (seed << 13) & 0xFFFFFFFF;
        seed ^= (seed >> 17) & 0xFFFFFFFF;
        seed ^= (seed << 5) & 0xFFFFFFFF;
        final double rand = ((seed & 0xFFFFFF) / 8388607.5) - 1.0;
        final double woodCrack = rand * math.exp(-t * 450.0) * 0.35;
        final double sharpClick = math.sin(2.0 * math.pi * 3800.0 * t) * math.exp(-t * 600.0) * 0.40;
        malletTransient = (woodCrack + sharpClick) * hardness;
      }

      final double raw = (y1 * 0.88 + y2 + y3 + tubeResonator + malletTransient) * vel;
      outBuffer[i] = DistortionNode._tanh(raw * 1.20) * 0.95;
    }
  }
}

/// Physical Modal Resonator for Vibraphone (Aluminum Alloy Arched Bar with Motor Tremolo).
/// Suspended aluminum bar with undercut arch carved to tune Mode 2 to the
/// double octave (4.0 * f0), long singing sustain, soft yarn mallet attack,
/// and motor-driven rotating butterfly valve resonator tube modulation.
class VibraphoneBarNode extends GraphNode {
  final double barDecay;
  final String? barDecayParam;
  final double motorSpeed;
  final String? motorSpeedParam;
  final double tremoloDepth;
  final String? tremoloDepthParam;
  final double doubleOctave;
  final String? doubleOctaveParam;
  final double yarnSoftness;
  final String? yarnSoftnessParam;

  const VibraphoneBarNode({
    this.barDecay = 4.5,
    this.barDecayParam,
    this.motorSpeed = 4.2,
    this.motorSpeedParam,
    this.tremoloDepth = 0.60,
    this.tremoloDepthParam,
    this.doubleOctave = 0.40,
    this.doubleOctaveParam,
    this.yarnSoftness = 0.50,
    this.yarnSoftnessParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double f0 = ctx.freq > 0 ? ctx.freq : 440.0;
    final double vel = ctx.velocity.clamp(0.01, 1.0);
    final double decay = (barDecayParam != null ? ctx.getParam(barDecayParam!, barDecay) : barDecay).clamp(0.5, 9.0);
    final double mSpeed = (motorSpeedParam != null ? ctx.getParam(motorSpeedParam!, motorSpeed) : motorSpeed).clamp(0.2, 10.0);
    final double tDepth = (tremoloDepthParam != null ? ctx.getParam(tremoloDepthParam!, tremoloDepth) : tremoloDepth).clamp(0.0, 1.0);
    final double overtone4x = (doubleOctaveParam != null ? ctx.getParam(doubleOctaveParam!, doubleOctave) : doubleOctave).clamp(0.0, 1.2);
    final double softness = (yarnSoftnessParam != null ? ctx.getParam(yarnSoftnessParam!, yarnSoftness) : yarnSoftness).clamp(0.0, 1.0);

    // Aluminum bar with undercut arch:
    // Mode 1: Fundamental
    // Mode 2: Tuned double-octave harmonic (4.0 * f0)
    // Mode 3: High inharmonic mode (~9.20 * f0)
    final double f1 = f0;
    final double f2 = f0 * 4.00;
    final double f3 = math.min(18500.0, f0 * 9.20);

    // Aluminum has very low internal friction -> long, mellow, singing sustain
    final double d1 = 0.35 / decay;
    final double d2 = (1.5 / decay) + (f0 / 1200.0);
    final double d3 = (7.5 / decay) + (f0 / 350.0);

    // Motor butterfly valve rotates at mSpeed.
    // The valve passes open position twice per revolution -> 2 * mSpeed modulation
    final double valveOmega = 2.0 * math.pi * (2.0 * mSpeed);

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;

      // Rotating butterfly valve creates AM tremolo + subtle tube phase modulation
      final double valveExposure = 0.5 + 0.5 * math.cos(valveOmega * t);
      final double tremoloMod = 1.0 - (tDepth * (1.0 - valveExposure));

      // Mode 1: Pure fundamental
      final double y1 = math.sin(2.0 * math.pi * f1 * t) * math.exp(-t * d1);

      // Mode 2: Tuned double-octave
      final double y2 = math.sin(2.0 * math.pi * f2 * t) * math.exp(-t * d2) * (0.50 * overtone4x);

      // Mode 3: High overtone (softened by yarn mallet)
      final double y3 = math.sin(2.0 * math.pi * f3 * t) * math.exp(-t * d3) * (0.20 * overtone4x * (1.0 - 0.5 * softness));

      // Soft yarn mallet impact (filtered low-mid contact thud)
      double yarnThud = 0.0;
      if (t < 0.015) {
        final double thudFreq = 300.0 + (1.0 - softness) * 500.0;
        yarnThud = math.sin(2.0 * math.pi * thudFreq * t) * math.exp(-t * 220.0) * (0.35 * (1.2 - 0.4 * softness));
      }

      final double acousticBar = (y1 * 0.92 + y2 + y3 + yarnThud) * vel;
      final double outWithTremolo = acousticBar * tremoloMod;

      outBuffer[i] = DistortionNode._tanh(outWithTremolo * 1.10) * 0.90;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CCRMA / BANK-BENSA COMMUTED WAVEGUIDE PIANO ENGINE
// ─────────────────────────────────────────────────────────────────────────────

/// Commuted Soundboard Exciter based on Stanford CCRMA / Bank-Bensa physical model.
/// Synthesizes dual dry-tap and sympathetic sustain-pedal noise bursts shaped by
/// empirical T60 time constants per MIDI note.
class CommutedSoundboardExciterNode extends GraphNode {
  final double hammerHardness;
  final String? hammerHardnessParam;
  final double pedalResonance;
  final String? pedalResonanceParam;
  final double soundboardGain;
  final String? soundboardGainParam;

  const CommutedSoundboardExciterNode({
    this.hammerHardness = 0.5,
    this.hammerHardnessParam,
    this.pedalResonance = 0.5,
    this.pedalResonanceParam,
    this.soundboardGain = 1.0,
    this.soundboardGainParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double sr = ctx.sampleRate;
    final double note = ctx.midiNote.toDouble();
    final double vel = ctx.velocity.clamp(0.01, 1.0);
    final double hardness = (hammerHardnessParam != null ? ctx.getParam(hammerHardnessParam!, hammerHardness) : hammerHardness).clamp(0.05, 2.0);
    final double pReso = (pedalResonanceParam != null ? ctx.getParam(pedalResonanceParam!, pedalResonance) : pedalResonance).clamp(0.0, 2.0);
    final double sbGain = (soundboardGainParam != null ? ctx.getParam(soundboardGainParam!, soundboardGain) : soundboardGain).clamp(0.0, 2.0);

    final double noteCutoffT60 = PianoPhysicalTables.dryTapAmpT60.lookup(note) * (0.8 + 0.4 * vel);
    final double pedalEnvValue = PianoPhysicalTables.sustainPedalLevel.lookup(note) * 0.2 * pReso;
    final double pedalCutoffT60 = 1.4;

    final double attDurSec = math.max(0.0005, (0.015 / hardness));
    final double factorNote = math.exp(-7.0 / (noteCutoffT60 * sr));
    final double factorPedal = math.exp(-7.0 / (pedalCutoffT60 * sr));

    double envDry = 0.85 * vel;
    double envPedal = pedalEnvValue * vel * 2.0;
    int seed = 0x1A2B3C ^ (ctx.midiNote * 37);

    for (int i = 0; i < outBuffer.length; i++) {
      final double t = i / sr;
      seed ^= (seed << 13) & 0xFFFFFFFF;
      seed ^= (seed >> 17) & 0xFFFFFFFF;
      seed ^= (seed << 5) & 0xFFFFFFFF;
      final double noise = ((seed & 0xFFFFFF) / 8388607.5) - 1.0;

      double curEnvDry;
      if (t < attDurSec) {
        curEnvDry = (t / attDurSec) * envDry;
      } else {
        curEnvDry = envDry;
        envDry *= factorNote;
      }

      final double curEnvPedal = envPedal;
      envPedal *= factorPedal;

      outBuffer[i] = (noise * curEnvDry + noise * curEnvPedal) * sbGain;
    }
  }
}

/// 4-Stage 1-Pole Non-Linear Hammer Filter Cascade.
/// Models dynamic felt compression where velocity and brightness shift the filter
/// poles and gains according to Bank-Bensa empirical measurements.
class CommutedHammerFilterCascadeNode extends GraphNode {
  final GraphNode input;
  final double brightnessFactor;
  final String? brightnessFactorParam;
  final double hardnessScale;
  final String? hardnessScaleParam;

  const CommutedHammerFilterCascadeNode({
    required this.input,
    this.brightnessFactor = 0.5,
    this.brightnessFactorParam,
    this.hardnessScale = 1.0,
    this.hardnessScaleParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double note = ctx.midiNote.toDouble();
    final double vel = ctx.velocity.clamp(0.01, 1.0);
    final double bright = (brightnessFactorParam != null ? ctx.getParam(brightnessFactorParam!, brightnessFactor) : brightnessFactor).clamp(0.0, 1.0);
    final double hScale = (hardnessScaleParam != null ? ctx.getParam(hardnessScaleParam!, hardnessScale) : hardnessScale).clamp(0.1, 3.0);

    final double baseLoudP = PianoPhysicalTables.loudPole.lookup(note);
    final double baseSoftP = PianoPhysicalTables.softPole.lookup(note);
    final double hardOffset = (hScale - 1.0) * 0.08;
    final double brightOffset = (bright - 0.5) * 0.10;

    final double loudP = (baseLoudP - hardOffset - brightOffset).clamp(0.40, 0.92);
    final double softP = (baseSoftP - hardOffset * 0.5).clamp(0.70, 0.98);

    final double baseLoudG = PianoPhysicalTables.loudGain.lookup(note);
    final double baseSoftG = PianoPhysicalTables.softGain.lookup(note);
    final double gainScale = math.sqrt(hScale).clamp(0.70, 2.0);

    final double loudG = baseLoudG * gainScale;
    final double softG = baseSoftG * math.sqrt(gainScale);

    final double normVel = math.pow(vel, 0.65).toDouble().clamp(0.0, 1.0);
    final double hammerPole = (softP + (loudP - softP) * normVel).clamp(0.40, 0.985);
    final double hammerGain = (softG + (loudG - softG) * normVel).clamp(0.40, 5.0);

    // 4-pole cascade with 6x input scaling matching Faust STK
    final double b0 = (1.0 - hammerPole) * hammerGain;
    final double a1 = -hammerPole;

    final s = Float64List(4);

    for (int i = 0; i < outBuffer.length; i++) {
      double x = outBuffer[i] * 6.0;
      for (int stage = 0; stage < 4; stage++) {
        final double y = b0 * x - a1 * s[stage];
        s[stage] = y;
        x = y;
      }
      outBuffer[i] = x;
    }
  }
}

/// Strike Position Comb Filter EQ.
/// Models the notch transfer function at the physical hammer strike position along the string.
class CommutedStrikeCombNode extends GraphNode {
  final GraphNode input;

  const CommutedStrikeCombNode({required this.input});

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    input.process(ctx, outBuffer);

    final double sr = ctx.sampleRate;
    final double note = ctx.midiNote.toDouble();
    final double f0 = ctx.freq > 0 ? ctx.freq : 440.0;

    final double strikePos = PianoPhysicalTables.strikePosition.lookup(note).clamp(0.02, 0.5);
    final double bwFactor = PianoPhysicalTables.eqBandwidthFactor.lookup(note);
    final double eqG = PianoPhysicalTables.eqGain.lookup(note);

    final double eqTuning = (f0 / strikePos).clamp(20.0, sr * 0.45);
    final double eqBw = (bwFactor * f0).clamp(10.0, sr * 0.45);

    final double a2 = math.pow(eqBw / sr, 2.0).toDouble().clamp(0.0, 0.999);
    final double a1 = -2.0 * (eqBw / sr) * math.cos(2.0 * math.pi * eqTuning / sr);
    final double b0 = (0.5 - 0.5 * a2) * eqG;
    final double b1 = 0.0;
    final double b2 = -b0;

    double s1 = 0.0, s2 = 0.0;

    for (int i = 0; i < outBuffer.length; i++) {
      final double x = outBuffer[i];
      final double y = b0 * x + b1 * s1 + b2 * s2 - a1 * s1 - a2 * s2;
      s2 = s1;
      s1 = y;
      outBuffer[i] = x + y * 0.5;
    }
  }
}

/// Commuted Piano Coupled Waveguide with All-Pass Inharmonic Dispersion.
/// Features dual parallel delay lines, 3-stage allpass string stiffness dispersion,
/// bridge coupling matrix (double decay / singing tail), and note-off release damping.
class CommutedPianoWaveguideNode extends GraphNode {
  final GraphNode exciter;
  final double stiffnessFactor;
  final String? stiffnessFactorParam;
  final double detuningFactor;
  final String? detuningFactorParam;
  final double sustainScale;
  final String? sustainScaleParam;

  const CommutedPianoWaveguideNode({
    required this.exciter,
    this.stiffnessFactor = 1.0,
    this.stiffnessFactorParam,
    this.detuningFactor = 1.0,
    this.detuningFactorParam,
    this.sustainScale = 1.0,
    this.sustainScaleParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    exciter.process(ctx, outBuffer);

    final double sr = ctx.sampleRate;
    final double note = ctx.midiNote.toDouble();
    final double f0 = ctx.freq > 0 ? ctx.freq : 440.0;
    final double stiffMult = (stiffnessFactorParam != null ? ctx.getParam(stiffnessFactorParam!, stiffnessFactor) : stiffnessFactor).clamp(0.0, 4.0);
    final double detuneMult = (detuningFactorParam != null ? ctx.getParam(detuningFactorParam!, detuningFactor) : detuningFactor).clamp(0.0, 5.0);
    final double susMult = (sustainScaleParam != null ? ctx.getParam(sustainScaleParam!, sustainScale) : sustainScale).clamp(0.5, 1.2);

    // Single-string decay & bridge coupling filter parameters
    final double singleDecay = PianoPhysicalTables.singleStringDecayRate.lookup(note);
    final double gAtt = math.pow(10.0, (singleDecay / f0) / 20.0).toDouble().clamp(0.90, 0.9999);
    final double bCoupl = PianoPhysicalTables.singleStringZero.lookup(note);
    final double aCoupl = PianoPhysicalTables.singleStringPole.lookup(note);

    final double tempD = 3.0 * (1.0 - bCoupl) - gAtt * (1.0 - aCoupl);
    final double b0C = (tempD.abs() > 0.0001) ? (2.0 * (gAtt * (1.0 - aCoupl) - (1.0 - bCoupl)) / tempD) : 0.0;
    final double b1C = (tempD.abs() > 0.0001) ? (2.0 * (aCoupl * (1.0 - bCoupl) - gAtt * (1.0 - aCoupl) * bCoupl) / tempD) : 0.0;
    final double a1C = (tempD.abs() > 0.0001) ? ((gAtt * (1.0 - aCoupl) * bCoupl - 3.0 * aCoupl * (1.0 - bCoupl)) / tempD) : 0.0;

    // String stiffness coefficient for all-pass dispersion
    final double stiffness = (stiffMult * PianoPhysicalTables.stiffnessCoefficient.lookup(note)).clamp(-0.95, 0.95);

    // Detuning for 2 coupled string courses
    final double hzDetune = PianoPhysicalTables.detuningHz.lookup(note) * detuneMult;
    final double freq1 = math.max(20.0, f0 + 0.5 * hzDetune);
    final double freq2 = math.max(20.0, f0 - 0.5 * hzDetune);

    // Delay lengths with exact all-pass and pole-zero group delay compensation (Faust STK)
    double calcDelayLength(double f) {
      final double wT = (f * 2.0 * math.pi / sr).clamp(0.001, math.pi * 0.95);
      final double sinWT = math.sin(wT);
      final double cosWT = math.cos(wT);

      // All-pass dispersion phase
      final double numAp = (stiffness * stiffness - 1.0) * sinWT;
      final double denAp = 2.0 * stiffness + (stiffness * stiffness + 1.0) * cosWT;
      final double apPhase = math.atan2(numAp, denAp);

      // Bridge coupling pole-zero phase: poleZeroPhase(1 + 2*b0C, a1C + 2*b1C, a1C, wT)
      final double b0P = 1.0 + 2.0 * b0C;
      final double b1P = a1C + 2.0 * b1C;
      final double a1P = a1C;

      final double numPz = -b1P * sinWT * (1.0 + a1P * cosWT) + a1P * sinWT * (b0P + b1P * cosWT);
      final double denPz = (b0P + b1P * cosWT) * (1.0 + a1P * cosWT) + b1P * sinWT * a1P * sinWT;
      final double pzPhase = math.atan2(numPz, denPz);

      final double dLen = (2.0 * math.pi + 3.0 * apPhase + pzPhase) / wT;
      return dLen.clamp(2.0, (sr / 18.0));
    }

    final double dLen1 = calcDelayLength(freq1);
    final double dLen2 = calcDelayLength(freq2);

    final int bufSize = (sr / 18.0).toInt() + 64;
    final delayLine1 = Float64List(bufSize);
    final delayLine2 = Float64List(bufSize);
    int writeIdx = 0;

    // Allpass dispersion filter state (3 stages per string)
    final ap1_x = Float64List(3);
    final ap1_y = Float64List(3);
    final ap2_x = Float64List(3);
    final ap2_y = Float64List(3);

    // Bridge coupling filter state
    double cFilter_x = 0.0;
    double cFilter_y = 0.0;

    final double loopGain = (0.9996 * susMult).clamp(0.90, 0.9999);

    double bridgeFeedback1 = 0.0;
    double bridgeFeedback2 = 0.0;

    for (int i = 0; i < len; i++) {
      final double exc = outBuffer[i];

      // String 1 input
      double in1 = (exc + bridgeFeedback1) * loopGain;
      // String 2 input
      double in2 = (exc + bridgeFeedback2) * loopGain;

      // 3-stage allpass dispersion filter on String 1
      for (int s = 0; s < 3; s++) {
        final double y = stiffness * in1 + ap1_x[s] - stiffness * ap1_y[s];
        ap1_x[s] = in1;
        ap1_y[s] = y;
        in1 = y;
      }

      // 3-stage allpass dispersion filter on String 2
      for (int s = 0; s < 3; s++) {
        final double y = stiffness * in2 + ap2_x[s] - stiffness * ap2_y[s];
        ap2_x[s] = in2;
        ap2_y[s] = y;
        in2 = y;
      }

      // Write to delay lines
      delayLine1[writeIdx] = in1;
      delayLine2[writeIdx] = in2;

      // Read from delay line 1 with linear interpolation
      final double rPos1 = (writeIdx - dLen1 + bufSize) % bufSize;
      final int i1_0 = rPos1.toInt() % bufSize;
      final int i1_1 = (i1_0 + 1) % bufSize;
      final double frac1 = rPos1 - rPos1.floor();
      final double out1 = delayLine1[i1_0] * (1.0 - frac1) + delayLine1[i1_1] * frac1;

      // Read from delay line 2 with linear interpolation
      final double rPos2 = (writeIdx - dLen2 + bufSize) % bufSize;
      final int i2_0 = rPos2.toInt() % bufSize;
      final int i2_1 = (i2_0 + 1) % bufSize;
      final double frac2 = rPos2 - rPos2.floor();
      final double out2 = delayLine2[i2_0] * (1.0 - frac2) + delayLine2[i2_1] * frac2;

      // Bridge coupling: coupling filter on sum of delayed outputs
      final double sumOut = out1 + out2;
      final double bridgeCoupled = b0C * sumOut + b1C * cFilter_x - a1C * cFilter_y;
      cFilter_x = sumOut;
      cFilter_y = bridgeCoupled;

      bridgeFeedback1 = out1 + bridgeCoupled;
      bridgeFeedback2 = out2 + bridgeCoupled;

      writeIdx = (writeIdx + 1) % bufSize;

      outBuffer[i] = (out1 + out2) * 0.5;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACOUSTIC PHYSICAL MODELING: BRASS, REED & NON-LINEAR BOUNDARY WAVEGUIDES
// ─────────────────────────────────────────────────────────────────────────────

/// Physical Lip-Reed Acoustic Brass Waveguide.
/// Models the outward-striking lip oscillator (Adachi & Sato / Fletcher),
/// bore propagation with non-linear shock wave steepening, bell reflection/radiation,
/// and Harmon/cup mute acoustics for Trumpet, Trombone, Tuba, and French Horn.
class AcousticBrassWaveguideNode extends GraphNode {
  /// 0: Trumpet (GM 56), 1: Trombone (GM 57), 2: Tuba (GM 58),
  /// 3: French Horn (GM 60), 4: Muted Trumpet (GM 59), 5: Brass Section (GM 61)
  final int brassType;
  final double defaultPressure;
  final String? pressureParam;
  final double defaultLipTension;
  final String? lipTensionParam;
  final double defaultBellFlare;
  final String? bellFlareParam;
  final double defaultMuteAmount;
  final String? muteAmountParam;
  final double defaultDamping;
  final String? dampingParam;
  final double defaultGrowl;
  final String? growlParam;
  final double defaultVibDepth;
  final String? vibDepthParam;
  final double defaultVibRate;
  final String? vibRateParam;
  final double defaultVibDelay;
  final String? vibDelayParam;
  final double defaultAttack;
  final String? attackParam;
  final double defaultDecay;
  final String? decayParam;
  final double defaultSustain;
  final String? sustainParam;
  final double defaultRelease;
  final String? releaseParam;

  const AcousticBrassWaveguideNode({
    this.brassType = 0,
    this.defaultPressure = 1.20,
    this.pressureParam,
    this.defaultLipTension = 1.0,
    this.lipTensionParam,
    this.defaultBellFlare = 0.65,
    this.bellFlareParam,
    this.defaultMuteAmount = 0.0,
    this.muteAmountParam,
    this.defaultDamping = 0.18,
    this.dampingParam,
    this.defaultGrowl = 0.0,
    this.growlParam,
    this.defaultVibDepth = 0.22,
    this.vibDepthParam,
    this.defaultVibRate = 5.2,
    this.vibRateParam,
    this.defaultVibDelay = 0.25,
    this.vibDelayParam,
    this.defaultAttack = 0.045,
    this.attackParam,
    this.defaultDecay = 0.12,
    this.decayParam,
    this.defaultSustain = 0.88,
    this.sustainParam,
    this.defaultRelease = 0.22,
    this.releaseParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final double sr = ctx.sampleRate;

    final double pressure = (pressureParam != null ? ctx.getParam(pressureParam!, defaultPressure) : defaultPressure).clamp(0.2, 3.0);
    final double lipTension = (lipTensionParam != null ? ctx.getParam(lipTensionParam!, defaultLipTension) : defaultLipTension).clamp(0.5, 2.0);
    final double bellFlare = (bellFlareParam != null ? ctx.getParam(bellFlareParam!, defaultBellFlare) : defaultBellFlare).clamp(0.1, 2.0);
    final double muteAmt = (muteAmountParam != null ? ctx.getParam(muteAmountParam!, defaultMuteAmount) : defaultMuteAmount).clamp(0.0, 1.0);
    final double damp = (dampingParam != null ? ctx.getParam(dampingParam!, defaultDamping) : defaultDamping).clamp(0.02, 0.95);
    final double growl = (growlParam != null ? ctx.getParam(growlParam!, defaultGrowl) : defaultGrowl).clamp(0.0, 1.0);
    final double vibDepth = (vibDepthParam != null ? ctx.getParam(vibDepthParam!, defaultVibDepth) : defaultVibDepth).clamp(0.0, 2.0);
    final double vibRate = (vibRateParam != null ? ctx.getParam(vibRateParam!, defaultVibRate) : defaultVibRate).clamp(1.0, 12.0);
    final double vibDelay = (vibDelayParam != null ? ctx.getParam(vibDelayParam!, defaultVibDelay) : defaultVibDelay).clamp(0.0, 1.0);

    final double attack = (attackParam != null ? ctx.getParam(attackParam!, defaultAttack) : defaultAttack).clamp(0.005, 1.0);
    final double decay = (decayParam != null ? ctx.getParam(decayParam!, defaultDecay) : defaultDecay).clamp(0.01, 1.5);
    final double sustain = (sustainParam != null ? ctx.getParam(sustainParam!, defaultSustain) : defaultSustain).clamp(0.1, 1.0);
    final double release = (releaseParam != null ? ctx.getParam(releaseParam!, defaultRelease) : defaultRelease).clamp(0.01, 2.0);

    final double baseFreq = ctx.freq > 10.0 ? ctx.freq : 440.0;

    // Dynamic proportional ADSR scaling for short-duration note events (e.g. tracker steps)
    double effAttack = attack;
    double effDecay = decay;
    double effRelease = release;
    final double minEnvDur = effAttack + effDecay + effRelease;
    if (ctx.durationSec < minEnvDur) {
      final double scale = (ctx.durationSec / minEnvDur).clamp(0.05, 1.0);
      effAttack *= scale;
      effDecay *= scale;
      effRelease *= scale;
    }
    final double gateTime = math.max(effAttack + effDecay, ctx.durationSec - effRelease);

    final double maxDelaySamples = sr / 20.0;
    final int bufSize = maxDelaySamples.toInt() + 64;
    final delayLine = Float32List(bufSize);
    int writeIdx = 0;

    double lipY1 = 0.0, lipY2 = 0.0;
    double deltaDcX = 0.0, deltaDcY = 0.0;
    double loopDcX = 0.0, loopDcY = 0.0;
    double wallLossState = 0.0;
    double radPrevX = 0.0;
    double radPrevY = 0.0;
    double muteS1 = 0.0;
    double muteS2 = 0.0;
    double dcX = 0.0;
    double dcY = 0.0;

    int prng = 0x1A2B3C4D ^ (ctx.midiNote * 313);

    for (int i = 0; i < len; i++) {
      final double t = i / sr;
      final double normTime = len > 1 ? i / (len - 1) : 0.0;
      final double bendSemitones = ctx.getPitchBendAt(normTime);

      double env;
      if (t < effAttack) {
        final double p = t / effAttack;
        env = p * p * (3.0 - 2.0 * p);
      } else if (t < gateTime) {
        final double decT = (t - effAttack) / math.max(0.001, effDecay);
        env = 1.0 - (1.0 - sustain) * math.min(1.0, decT);
      } else {
        final double relT = (t - gateTime) / math.max(0.001, effRelease);
        env = sustain * math.max(0.0, 1.0 - relT);
      }

      double vib = 0.0;
      if (vibDepth > 0.001 && t > vibDelay) {
        final double vibRamp = math.min(1.0, (t - vibDelay) / 0.35);
        vib = math.sin(2.0 * math.pi * vibRate * t) * (vibDepth * 0.40) * vibRamp;
      }

      double growlMod = 1.0;
      if (growl > 0.001) {
        growlMod = 1.0 + growl * 0.35 * math.sin(2.0 * math.pi * 32.0 * t);
      }

      final double instantaneousFreq = math.max(20.0, baseFreq * math.pow(2.0, (bendSemitones + vib) / 12.0));

      final double targetDelay = (sr / instantaneousFreq) * 0.5;
      final double delaySamples = targetDelay.clamp(2.0, maxDelaySamples - 2.0);

      final double rPos = writeIdx - delaySamples;
      final double wrappedRPos = (rPos % bufSize + bufSize) % bufSize;
      final int i1 = wrappedRPos.toInt();
      final int i0 = (i1 - 1 + bufSize) % bufSize;
      final int i2 = (i1 + 1) % bufSize;
      final int i3 = (i1 + 2) % bufSize;
      final double frac = wrappedRPos - i1;

      final double p0 = delayLine[i0];
      final double p1 = delayLine[i1];
      final double p2 = delayLine[i2];
      final double p3 = delayLine[i3];

      final double c0 = p1;
      final double c1 = 0.5 * (p2 - p0);
      final double c2 = p0 - 2.5 * p1 + 2.0 * p2 - 0.5 * p3;
      final double c3 = 0.5 * (p3 - p0) + 1.5 * (p1 - p2);
      final double boreFeedback = ((c3 * frac + c2) * frac + c1) * frac + c0;

      prng ^= (prng << 13) & 0xFFFFFFFF;
      prng ^= (prng >> 17) & 0xFFFFFFFF;
      prng ^= (prng << 5) & 0xFFFFFFFF;
      final double breathNoise = (((prng & 0xFFFFFF) / 8388607.5) - 1.0) * 0.03;

      final double pMouth = (env * pressure * 1.1 * ctx.velocity + breathNoise * env) * growlMod;
      final double deltaP = pMouth - boreFeedback;

      // Sub-audio DC blocker to decouple mouth bias from dynamic oscillation
      final double deltaPac = deltaP - deltaDcX + 0.9992 * deltaDcY;
      deltaDcX = deltaP;
      deltaDcY = deltaPac;

      // Normalized 2-pole resonant lip oscillator with soft-limiting saturation
      final double lipOmega = 2.0 * math.pi * instantaneousFreq * lipTension / sr;
      const double rLip = 0.992;
      final double a1Lip = -2.0 * rLip * math.cos(lipOmega);
      final double a2Lip = rLip * rLip;
      final double bNorm = (1.0 - a2Lip) * 0.45;

      final double lipIn = deltaPac * bNorm * 2.0;
      final double lipRaw = lipIn - a1Lip * lipY1 - a2Lip * lipY2;
      final double lipOut = lipRaw.clamp(-1.8, 1.8);
      lipY2 = lipY1;
      lipY1 = lipOut;

      // Smooth physical lip aperture
      final double lipAperture = (0.26 + lipOut * 0.42).clamp(0.0, 1.0);
      final double flow = deltaP * lipAperture;

      double injectedBorePressure = flow * 0.85;

      if (brassType != 3) {
        final double steep = (pressure * ctx.velocity * 0.12).clamp(0.0, 0.30);
        injectedBorePressure += injectedBorePressure * injectedBorePressure * (injectedBorePressure >= 0.0 ? 1.0 : -1.0) * steep;
      }

      final double loopDamp = (0.35 + damp * 0.35).clamp(0.1, 0.85);
      final double waveToBore = injectedBorePressure + boreFeedback * (1.0 - lipAperture * 0.7);
      wallLossState = (1.0 - loopDamp) * waveToBore + loopDamp * wallLossState;

      // DC-block the bore feedback loop to prevent mouth pressure from latching into saturation
      final double loopDcOut = wallLossState - loopDcX + 0.995 * loopDcY;
      loopDcX = wallLossState;
      loopDcY = loopDcOut;

      delayLine[writeIdx] = -loopDcOut;
      writeIdx = (writeIdx + 1) % bufSize;

      final double radIn = waveToBore - boreFeedback;
      final double radCut = (0.75 - bellFlare * 0.20).clamp(0.2, 0.90);
      final double radOut = (radIn - radPrevX) + radCut * radPrevY;
      radPrevX = radIn;
      radPrevY = radOut;

      double finalSound = radOut;

      if (brassType == 4 || muteAmt > 0.01) {
        final double mGain = brassType == 4 ? 1.0 : muteAmt;
        final double wMute = 2.0 * math.pi * 2200.0 / sr;
        final double alpha = math.sin(wMute) / (2.0 * 3.5);
        final double a0 = 1.0 + alpha;
        final double b0 = alpha / a0;
        final double b2 = -b0;
        final double a1 = (-2.0 * math.cos(wMute)) / a0;
        final double a2 = (1.0 - alpha) / a0;

        final double muteY = b0 * finalSound + b2 * muteS2 - a1 * muteS1 - a2 * muteS2;
        muteS2 = muteS1;
        muteS1 = muteY;
        finalSound = (1.0 - mGain * 0.75) * finalSound + (mGain * 0.85) * muteY;
      }

      final double dcOut = finalSound - dcX + 0.995 * dcY;
      dcX = finalSound;
      dcY = dcOut;

      outBuffer[i] = (dcOut * 1.25).clamp(-1.0, 1.0);
    }
  }
}

/// Physical Acoustic Woodwind Reed Waveguide.
/// Models inward-striking non-linear pressure-difference reed valve (McIntyre-Schumacher-Woodhouse / Faust STK),
/// supporting Cylindrical bore (Clarinet: odd harmonics only) and Conical bore (Saxophones, Oboe, Bassoon: full harmonic spectrum),
/// breath turbulence, embouchure compliance, and register key overblow.
class AcousticReedWaveguideNode extends GraphNode {
  /// 0: Clarinet (cylindrical bore, odd harmonics)
  /// 1: Alto Sax (conical bore, all harmonics)
  /// 2: Tenor Sax (conical bore, warm smoky low end)
  /// 3: Baritone Sax (conical bore, heavy brassy reed)
  /// 4: Oboe (conical narrow bore, double reed nasal formant)
  /// 5: English Horn (conical bore, mellow cor anglais)
  /// 6: Bassoon (conical double reed, deep woody resonance)
  /// 7: Soprano Sax (conical bore, agile singing reed)
  final int reedType;
  final double defaultPressure;
  final String? pressureParam;
  final double defaultStiffness;
  final String? stiffnessParam;
  final double defaultTurbulence;
  final String? turbulenceParam;
  final double defaultDamping;
  final String? dampingParam;
  final double defaultEmbouchure;
  final String? embouchureParam;
  final double defaultVibDepth;
  final String? vibDepthParam;
  final double defaultVibRate;
  final String? vibRateParam;
  final double defaultVibDelay;
  final String? vibDelayParam;
  final double defaultAttack;
  final String? attackParam;
  final double defaultDecay;
  final String? decayParam;
  final double defaultSustain;
  final String? sustainParam;
  final double defaultRelease;
  final String? releaseParam;

  const AcousticReedWaveguideNode({
    this.reedType = 1,
    this.defaultPressure = 1.15,
    this.pressureParam,
    this.defaultStiffness = 0.55,
    this.stiffnessParam,
    this.defaultTurbulence = 0.22,
    this.turbulenceParam,
    this.defaultDamping = 0.20,
    this.dampingParam,
    this.defaultEmbouchure = 0.65,
    this.embouchureParam,
    this.defaultVibDepth = 0.28,
    this.vibDepthParam,
    this.defaultVibRate = 5.4,
    this.vibRateParam,
    this.defaultVibDelay = 0.18,
    this.vibDelayParam,
    this.defaultAttack = 0.035,
    this.attackParam,
    this.defaultDecay = 0.14,
    this.decayParam,
    this.defaultSustain = 0.85,
    this.sustainParam,
    this.defaultRelease = 0.24,
    this.releaseParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final double sr = ctx.sampleRate;

    final double pressure = (pressureParam != null ? ctx.getParam(pressureParam!, defaultPressure) : defaultPressure).clamp(0.2, 3.0);
    final double stiffness = (stiffnessParam != null ? ctx.getParam(stiffnessParam!, defaultStiffness) : defaultStiffness).clamp(0.1, 2.0);
    final double turbulence = (turbulenceParam != null ? ctx.getParam(turbulenceParam!, defaultTurbulence) : defaultTurbulence).clamp(0.0, 1.5);
    final double damp = (dampingParam != null ? ctx.getParam(dampingParam!, defaultDamping) : defaultDamping).clamp(0.02, 0.95);
    final double embouchure = (embouchureParam != null ? ctx.getParam(embouchureParam!, defaultEmbouchure) : defaultEmbouchure).clamp(0.1, 2.0);
    final double vibDepth = (vibDepthParam != null ? ctx.getParam(vibDepthParam!, defaultVibDepth) : defaultVibDepth).clamp(0.0, 2.0);
    final double vibRate = (vibRateParam != null ? ctx.getParam(vibRateParam!, defaultVibRate) : defaultVibRate).clamp(1.0, 12.0);
    final double vibDelay = (vibDelayParam != null ? ctx.getParam(vibDelayParam!, defaultVibDelay) : defaultVibDelay).clamp(0.0, 1.0);

    final double attack = (attackParam != null ? ctx.getParam(attackParam!, defaultAttack) : defaultAttack).clamp(0.005, 1.0);
    final double decay = (decayParam != null ? ctx.getParam(decayParam!, defaultDecay) : defaultDecay).clamp(0.01, 1.5);
    final double sustain = (sustainParam != null ? ctx.getParam(sustainParam!, defaultSustain) : defaultSustain).clamp(0.1, 1.0);
    final double release = (releaseParam != null ? ctx.getParam(releaseParam!, defaultRelease) : defaultRelease).clamp(0.01, 2.0);

    final double baseFreq = ctx.freq > 10.0 ? ctx.freq : 440.0;

    // Dynamic proportional ADSR scaling for short-duration note events (e.g. tracker steps)
    double effAttack = attack;
    double effDecay = decay;
    double effRelease = release;
    final double minEnvDur = effAttack + effDecay + effRelease;
    if (ctx.durationSec < minEnvDur) {
      final double scale = (ctx.durationSec / minEnvDur).clamp(0.05, 1.0);
      effAttack *= scale;
      effDecay *= scale;
      effRelease *= scale;
    }
    final double gateTime = math.max(effAttack + effDecay, ctx.durationSec - effRelease);

    final double maxDelaySamples = sr / 20.0;
    final int bufSize = maxDelaySamples.toInt() + 64;
    final delayLine = Float32List(bufSize);
    int writeIdx = 0;

    double coneAllpassX = 0.0;
    double coneAllpassY = 0.0;
    double toneHoleState = 0.0;
    double dcX = 0.0;
    double dcY = 0.0;

    int prng = 0x6B7C8D9E ^ (ctx.midiNote * 257);
    final bool isCylindrical = (reedType == 0);

    for (int i = 0; i < len; i++) {
      final double t = i / sr;
      final double normTime = len > 1 ? i / (len - 1) : 0.0;
      final double bendSemitones = ctx.getPitchBendAt(normTime);

      double env;
      if (t < effAttack) {
        final double p = t / effAttack;
        env = p * (2.0 - p);
      } else if (t < gateTime) {
        final double decT = (t - effAttack) / math.max(0.001, effDecay);
        env = 1.0 - (1.0 - sustain) * math.min(1.0, decT);
      } else {
        final double relT = (t - gateTime) / math.max(0.001, effRelease);
        env = sustain * math.max(0.0, 1.0 - relT);
      }

      double vib = 0.0;
      if (vibDepth > 0.001 && t > vibDelay) {
        final double vibRamp = math.min(1.0, (t - vibDelay) / 0.30);
        vib = math.sin(2.0 * math.pi * vibRate * t) * (vibDepth * 0.35) * vibRamp;
      }

      final double instantaneousFreq = math.max(20.0, baseFreq * math.pow(2.0, (bendSemitones + vib) / 12.0));

      final double targetDelay = isCylindrical ? (sr / (2.0 * instantaneousFreq)) : (sr / instantaneousFreq);
      final double delaySamples = targetDelay.clamp(2.0, maxDelaySamples - 2.0);

      final double rPos = writeIdx - delaySamples;
      final double wrappedRPos = (rPos % bufSize + bufSize) % bufSize;
      final int i1 = wrappedRPos.toInt();
      final int i0 = (i1 - 1 + bufSize) % bufSize;
      final int i2 = (i1 + 1) % bufSize;
      final int i3 = (i1 + 2) % bufSize;
      final double frac = wrappedRPos - i1;

      final double p0 = delayLine[i0];
      final double p1 = delayLine[i1];
      final double p2 = delayLine[i2];
      final double p3 = delayLine[i3];

      final double c0 = p1;
      final double c1 = 0.5 * (p2 - p0);
      final double c2 = p0 - 2.5 * p1 + 2.0 * p2 - 0.5 * p3;
      final double c3 = 0.5 * (p3 - p0) + 1.5 * (p1 - p2);
      double boreFeedback = ((c3 * frac + c2) * frac + c1) * frac + c0;

      if (!isCylindrical) {
        final double coneCoeff = -0.55;
        final double apOut = coneCoeff * boreFeedback + coneAllpassX - coneCoeff * coneAllpassY;
        coneAllpassX = boreFeedback;
        coneAllpassY = apOut;
        boreFeedback = apOut;
      }

      prng ^= (prng << 13) & 0xFFFFFFFF;
      prng ^= (prng >> 17) & 0xFFFFFFFF;
      prng ^= (prng << 5) & 0xFFFFFFFF;
      final double breathNoise = (((prng & 0xFFFFFF) / 8388607.5) - 1.0) * turbulence * 0.08;

      final double pMouth = (env * pressure * 0.85 * ctx.velocity) + breathNoise * env;
      final double deltaP = pMouth - boreFeedback;

      final double reedSlope = 0.45 * stiffness * embouchure;
      final double reedOpening = (1.0 - reedSlope * deltaP).clamp(0.0, 1.0);
      final double flow = deltaP * reedOpening;

      final double loopDamp = (0.25 + damp * 0.35).clamp(0.08, 0.85);
      final double injectedWave = flow - (isCylindrical ? boreFeedback : boreFeedback * 0.35);
      toneHoleState = (1.0 - loopDamp) * injectedWave + loopDamp * toneHoleState;

      // Inverting acoustic reflection at open bell for both cylindrical and conical geometries
      delayLine[writeIdx] = -toneHoleState;
      writeIdx = (writeIdx + 1) % bufSize;

      final double rawOut = toneHoleState;
      final double dcOut = rawOut - dcX + 0.995 * dcY;
      dcX = rawOut;
      dcY = dcOut;

      outBuffer[i] = (dcOut * 2.1).clamp(-1.0, 1.0);
    }
  }
}

/// Sitar Non-Linear Curved Bridge Waveguide (Jawari / Jiwari Effect).
/// Simulates the dynamic contact of the vibrating string against a wide, flat curved bone bridge.
/// High vibration amplitudes trigger dynamic string shortening and micro-impact buzzing harmonics,
/// accompanied by a bank of sympathetic drone strings (*taraf*).
class JawariCurvedBridgeStringNode extends GraphNode {
  final double defaultJawariBuzz;
  final String? jawariBuzzParam;
  final double defaultSympathetic;
  final String? sympatheticParam;
  final double defaultPluckHardness;
  final String? pluckHardnessParam;
  final double defaultSustain;
  final String? sustainParam;

  const JawariCurvedBridgeStringNode({
    this.defaultJawariBuzz = 0.70,
    this.jawariBuzzParam,
    this.defaultSympathetic = 0.45,
    this.sympatheticParam,
    this.defaultPluckHardness = 0.75,
    this.pluckHardnessParam,
    this.defaultSustain = 0.992,
    this.sustainParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final double sr = ctx.sampleRate;

    final double jawari = (jawariBuzzParam != null ? ctx.getParam(jawariBuzzParam!, defaultJawariBuzz) : defaultJawariBuzz).clamp(0.0, 1.0);
    final double sympathetic = (sympatheticParam != null ? ctx.getParam(sympatheticParam!, defaultSympathetic) : defaultSympathetic).clamp(0.0, 1.0);
    final double hardness = (pluckHardnessParam != null ? ctx.getParam(pluckHardnessParam!, defaultPluckHardness) : defaultPluckHardness).clamp(0.1, 2.0);
    final double susMult = (sustainParam != null ? ctx.getParam(sustainParam!, defaultSustain) : defaultSustain).clamp(0.90, 0.999);

    final double f0 = ctx.freq > 10.0 ? ctx.freq : 146.83; // Default D3
    final double maxDelaySamples = sr / 20.0;
    final int bufSize = maxDelaySamples.toInt() + 64;
    final delayLine = Float32List(bufSize);
    int writeIdx = 0;

    double filterState = 0.0;

    final int pluckLen = ((sr / f0) * 0.45 / hardness).toInt().clamp(4, (0.015 * sr).toInt());
    int prng = 0x98765432 ^ (ctx.midiNote * 431);

    final double symF1 = f0 * 1.0;
    final double symF2 = f0 * 1.5;   // Perfect fifth (Pa)
    final double symF3 = f0 * 1.333; // Perfect fourth (Ma)
    final double symF4 = f0 * 1.875; // Major seventh (Ni)

    double s1A = 0.0, s1B = 0.0;
    double s2A = 0.0, s2B = 0.0;
    double s3A = 0.0, s3B = 0.0;
    double s4A = 0.0, s4B = 0.0;
    double bridgeDcX = 0.0, bridgeDcY = 0.0;

    final double w1 = 2.0 * math.pi * symF1 / sr;
    final double w2 = 2.0 * math.pi * symF2 / sr;
    final double w3 = 2.0 * math.pi * symF3 / sr;
    final double w4 = 2.0 * math.pi * symF4 / sr;

    final double symQ = 0.9982;

    for (int i = 0; i < len; i++) {
      double exc = 0.0;
      if (i < pluckLen) {
        prng ^= (prng << 13) & 0xFFFFFFFF;
        prng ^= (prng >> 17) & 0xFFFFFFFF;
        prng ^= (prng << 5) & 0xFFFFFFFF;
        final double noise = (((prng & 0xFFFFFF) / 8388607.5) - 1.0);
        final double env = math.sin(math.pi * i / pluckLen);
        exc = (env + noise * 0.35) * ctx.velocity;
      }

      final double targetDelay = (sr / f0).clamp(2.0, maxDelaySamples - 2.0);
      final double rPos = writeIdx - targetDelay;
      final double wrappedRPos = (rPos % bufSize + bufSize) % bufSize;
      final int i1 = wrappedRPos.toInt();
      final int i2 = (i1 + 1) % bufSize;
      final double frac = wrappedRPos - i1;
      final double stringSample = delayLine[i1] * (1.0 - frac) + delayLine[i2] * frac;

      // Passive asymmetric non-linear bridge impedance softening (Jawari effect)
      double jawariSample = stringSample;
      if (jawari > 0.001 && stringSample > 0.0) {
        final double soft = jawari * 0.45;
        jawariSample = stringSample / (1.0 + soft * stringSample);
      }

      filterState = filterState * 0.45 + (exc + jawariSample * susMult) * 0.55;
      // Inverting reflection at fixed bridge termination
      delayLine[writeIdx] = -filterState.clamp(-1.2, 1.2);
      writeIdx = (writeIdx + 1) % bufSize;

      final double rawBridgeDrive = jawariSample * 0.08 * sympathetic;
      final double bridgeDrive = rawBridgeDrive - bridgeDcX + 0.995 * bridgeDcY;
      bridgeDcX = rawBridgeDrive;
      bridgeDcY = bridgeDrive;

      final double y1 = bridgeDrive + 2.0 * symQ * math.cos(w1) * s1A - symQ * symQ * s1B;
      s1B = s1A; s1A = y1;

      final double y2 = bridgeDrive + 2.0 * symQ * math.cos(w2) * s2A - symQ * symQ * s2B;
      s2B = s2A; s2A = y2;

      final double y3 = bridgeDrive + 2.0 * symQ * math.cos(w3) * s3A - symQ * symQ * s3B;
      s3B = s3A; s3A = y3;

      final double y4 = bridgeDrive + 2.0 * symQ * math.cos(w4) * s4A - symQ * symQ * s4B;
      s4B = s4A; s4A = y4;

      final double symTotal = (y1 + y2 + y3 + y4) * 0.25;

      outBuffer[i] = (jawariSample * 0.85 + symTotal * 0.45).clamp(-1.0, 1.0);
    }
  }
}

// =============================================================================
// FUNDAMENTAL ENVIRONMENTAL ACOUSTIC PRIMITIVES
// =============================================================================

/// Spectral noise color profile.
enum NoiseColor { white, pink, brown, blue }

/// Fundamental Colored Noise Generator.
/// Generates White, Pink (1/f), Brown/Red (1/f²), and Blue (+3dB/oct) noise
/// for realistic aerodynamic, atmospheric, and fluid simulations.
class ColoredNoiseNode extends GraphNode {
  final NoiseColor color;
  final String? colorParam;
  final int seed;

  const ColoredNoiseNode({
    this.color = NoiseColor.pink,
    this.colorParam,
    this.seed = 0x5A17B9,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    int state = seed ^ (ctx.midiNote * 53);

    // Determine noise color (can be selected via parameter: 0=white, 1=pink, 2=brown, 3=blue)
    NoiseColor activeColor = color;
    if (colorParam != null) {
      final double pVal = ctx.getParam(colorParam!, color.index.toDouble());
      final int idx = pVal.round().clamp(0, 3);
      activeColor = NoiseColor.values[idx];
    }

    // Filter states for Paul Kellet's 3-pole pink noise generator
    double b0 = 0.0, b1 = 0.0, b2 = 0.0, b3 = 0.0, b4 = 0.0, b5 = 0.0, b6 = 0.0;
    // Leaky integrator state for brown noise
    double brownState = 0.0;
    // Differentiator state for blue noise
    double lastWhite = 0.0;

    for (int i = 0; i < len; i++) {
      state ^= (state << 13) & 0xFFFFFFFF;
      state ^= (state >> 17) & 0xFFFFFFFF;
      state ^= (state << 5) & 0xFFFFFFFF;
      final double white = ((state & 0xFFFFFF) / 8388607.5) - 1.0;

      switch (activeColor) {
        case NoiseColor.white:
          outBuffer[i] = white;
          break;

        case NoiseColor.pink:
          // Paul Kellet's accurate 1/f pinking filter approximation
          b0 = 0.99886 * b0 + white * 0.0555179;
          b1 = 0.99332 * b1 + white * 0.0750759;
          b2 = 0.96900 * b2 + white * 0.1538520;
          b3 = 0.86650 * b3 + white * 0.3104856;
          b4 = 0.55000 * b4 + white * 0.5329522;
          b5 = -0.7616 * b5 - white * 0.0168980;
          final double pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11;
          b6 = white * 0.115926;
          outBuffer[i] = pink.clamp(-1.0, 1.0);
          break;

        case NoiseColor.brown:
          // 1/f² leaky integration for deep seismic/combustion roar
          brownState = (brownState + (0.025 * white)) / 1.025;
          outBuffer[i] = (brownState * 3.6).clamp(-1.0, 1.0);
          break;

        case NoiseColor.blue:
          // +3dB/octave high-frequency air hiss differentiator
          final double blue = (white - lastWhite) * 0.65;
          lastWhite = white;
          outBuffer[i] = blue.clamp(-1.0, 1.0);
          break;
      }
    }
  }
}

/// Fundamental Chaotic Gust & Convection Modulator.
/// Produces non-periodic, multi-octave 1/f fractal aerodynamic drift (0.05Hz - 2Hz)
/// for realistic wind gusts, convective air drafts, and flame flicker.
class ChaoticGustLfoNode extends GraphNode {
  final double baseRate;
  final String? baseRateParam;
  final double gustiness;
  final String? gustinessParam;
  final double minLevel;
  final double maxLevel;
  final int seed;

  const ChaoticGustLfoNode({
    this.baseRate = 0.25,
    this.baseRateParam,
    this.gustiness = 0.55,
    this.gustinessParam,
    this.minLevel = 0.0,
    this.maxLevel = 1.0,
    this.seed = 0x82F41A,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double rate = (baseRateParam != null ? ctx.getParam(baseRateParam!, baseRate) : baseRate).clamp(0.01, 8.0);
    final double gust = (gustinessParam != null ? ctx.getParam(gustinessParam!, gustiness) : gustiness).clamp(0.0, 1.0);

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;
    int state = seed ^ (ctx.midiNote * 41);

    // Multi-octave fractional Brownian motion state
    double lagVal = 0.5;

    for (int i = 0; i < len; i++) {
      final double t = i / sr;
      // 3-octave quasi-fractal drift
      final double oct1 = math.sin(2.0 * math.pi * rate * t);
      final double oct2 = math.sin(2.0 * math.pi * (rate * 2.37) * t + 1.3) * 0.5;
      final double oct3 = math.sin(2.0 * math.pi * (rate * 5.11) * t + 2.7) * 0.25;

      state ^= (state << 13) & 0xFFFFFFFF;
      state ^= (state >> 17) & 0xFFFFFFFF;
      state ^= (state << 5) & 0xFFFFFFFF;
      final double jitter = (((state & 0xFFFFFF) / 16777215.0) - 0.5) * gust * 0.35;

      final double raw = (oct1 + oct2 + oct3) / 1.75 + jitter;
      // Exponential lag filter to model air inertia
      final double alpha = (0.003 * (1.0 + gust * 2.0)).clamp(0.0001, 0.05);
      lagVal += alpha * (raw - lagVal);

      final double normalized = (lagVal * 0.5 + 0.5).clamp(0.0, 1.0);
      outBuffer[i] = (minLevel + (maxLevel - minLevel) * normalized).clamp(-1.0, 1.0);
    }
  }
}

/// Stochastic grain trigger waveform type.
enum GrainType { dropletMinnaert, sapPinchRupture, emberSizzle, shockTransient }

/// Fundamental Stochastic Particle Grain Generator.
/// Emits Poisson-distributed micro-grains for rain droplets, wood sap pops,
/// flying ember sizzles, hail impacts, and lightning shock transients.
class PoissonImpulseGrainNode extends GraphNode {
  final GrainType grainType;
  final String? grainTypeParam;
  final double density;
  final String? densityParam;
  final double energy;
  final String? energyParam;
  final double pitchScale;
  final String? pitchScaleParam;
  final int seed;

  const PoissonImpulseGrainNode({
    this.grainType = GrainType.dropletMinnaert,
    this.grainTypeParam,
    this.density = 0.45,
    this.densityParam,
    this.energy = 0.75,
    this.energyParam,
    this.pitchScale = 1.0,
    this.pitchScaleParam,
    this.seed = 0x93C5D7,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final double dens = (densityParam != null ? ctx.getParam(densityParam!, density) : density).clamp(0.0, 1.0);
    final double energ = (energyParam != null ? ctx.getParam(energyParam!, energy) : energy).clamp(0.0, 1.5);
    final double pitch = (pitchScaleParam != null ? ctx.getParam(pitchScaleParam!, pitchScale) : pitchScale).clamp(0.2, 4.0);

    GrainType activeType = grainType;
    if (grainTypeParam != null) {
      final double pVal = ctx.getParam(grainTypeParam!, grainType.index.toDouble());
      final int idx = pVal.round().clamp(0, 3);
      activeType = GrainType.values[idx];
    }

    final double sr = ctx.sampleRate;
    final int len = outBuffer.length;
    outBuffer.fillRange(0, len, 0.0);

    if (dens <= 0.0005 || energ <= 0.0005) return;

    int rng = seed ^ (ctx.midiNote * 83);
    final double threshold = dens * 0.0028;

    for (int i = 0; i < len; i++) {
      rng ^= (rng << 13) & 0xFFFFFFFF;
      rng ^= (rng >> 17) & 0xFFFFFFFF;
      rng ^= (rng << 5) & 0xFFFFFFFF;
      final double r0 = (rng & 0xFFFFFF) / 16777215.0;

      if (r0 < threshold) {
        rng ^= (rng << 13) & 0xFFFFFFFF;
        final double rAmp = 0.5 + 0.5 * ((rng & 0xFFFF) / 65535.0);
        final double grainGain = rAmp * energ;

        switch (activeType) {
          case GrainType.dropletMinnaert:
            // Minnaert bubble plink: sweeping pitch chirp (550Hz to 1350Hz) with exponential decay
            final int dropSamples = (0.018 * sr).toInt();
            for (int p = 0; p < dropSamples && (i + p) < len; p++) {
              final double tP = p / sr;
              final double dropEnv = math.exp(-tP * 210.0);
              final double fP = (550.0 + 750.0 * (1.0 - math.exp(-tP * 160.0))) * pitch;
              outBuffer[i + p] += (math.sin(2.0 * math.pi * fP * tP) * dropEnv * grainGain * 0.6).clamp(-1.0, 1.0);
            }
            break;

          case GrainType.sapPinchRupture:
            // Supercritical steam rupture: sharp Dirac click + resonant wood hollow thump (280Hz - 420Hz)
            final int sapSamples = (0.024 * sr).toInt();
            outBuffer[i] += (grainGain * 0.85).clamp(-1.0, 1.0); // Dirac snap
            for (int p = 1; p < sapSamples && (i + p) < len; p++) {
              final double tP = p / sr;
              final double thumpEnv = math.exp(-tP * 110.0);
              final double fThump = (320.0 + 80.0 * math.sin(tP * 40.0)) * pitch;
              outBuffer[i + p] += (math.sin(2.0 * math.pi * fThump * tP) * thumpEnv * grainGain * 0.5).clamp(-1.0, 1.0);
            }
            break;

          case GrainType.emberSizzle:
            // High-frequency fractured ember sizzle (3.5kHz - 8.5kHz)
            final int sizzleSamples = (0.008 * sr).toInt();
            for (int p = 0; p < sizzleSamples && (i + p) < len; p++) {
              rng ^= (rng << 13) & 0xFFFFFFFF;
              final double sizzleNoise = (((rng & 0xFFFF) / 32767.5) - 1.0);
              final double sizzleEnv = math.exp(-(p / sr) * 450.0);
              outBuffer[i + p] += (sizzleNoise * sizzleEnv * grainGain * 0.45).clamp(-1.0, 1.0);
            }
            break;

          case GrainType.shockTransient:
            // Lightning / blast wave hypersonic shock transient
            final int shockSamples = (0.045 * sr).toInt();
            for (int p = 0; p < shockSamples && (i + p) < len; p++) {
              final double tP = p / sr;
              final double shockEnv = math.exp(-tP * 65.0);
              rng ^= (rng << 13) & 0xFFFFFFFF;
              final double blastNoise = (((rng & 0xFFFF) / 32767.5) - 1.0);
              final double subPunch = math.sin(2.0 * math.pi * 55.0 * tP);
              outBuffer[i + p] += ((blastNoise * 0.6 + subPunch * 0.4) * shockEnv * grainGain * 0.9).clamp(-1.0, 1.0);
            }
            break;
        }
      }
    }
  }
}

/// Surface cavity resonance profile.
enum CavitySurfaceType { puddle, tinRoof, foliage, hollowLog, chimneyHowl, chasm }

/// Fundamental Modal Cavity Bank Resonator.
/// Simulates physical surface impacts and acoustic cavity resonances:
/// Puddle (liquid splash), Tin Roof (metallic pinging), Foliage (soft absorption),
/// Hollow Log (campfire hearth), Chimney Howl (edge tones), Chasm (valley echoes).
class ModalCavityBankNode extends GraphNode {
  final GraphNode input;
  final CavitySurfaceType surfaceType;
  final String? surfaceTypeParam;
  final double resonance;
  final String? resonanceParam;
  final double brightness;
  final String? brightnessParam;

  const ModalCavityBankNode({
    required this.input,
    this.surfaceType = CavitySurfaceType.puddle,
    this.surfaceTypeParam,
    this.resonance = 0.65,
    this.resonanceParam,
    this.brightness = 0.50,
    this.brightnessParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List inBuf = Float32List(len);
    input.process(ctx, inBuf);

    final double reso = (resonanceParam != null ? ctx.getParam(resonanceParam!, resonance) : resonance).clamp(0.1, 0.98);
    final double bright = (brightnessParam != null ? ctx.getParam(brightnessParam!, brightness) : brightness).clamp(0.1, 2.0);

    CavitySurfaceType activeSurface = surfaceType;
    if (surfaceTypeParam != null) {
      final double pVal = ctx.getParam(surfaceTypeParam!, surfaceType.index.toDouble());
      final int idx = pVal.round().clamp(0, 5);
      activeSurface = CavitySurfaceType.values[idx];
    }

    // Modal frequencies and gains according to surface physics
    late final List<double> modalFreqs;
    late final List<double> modalGains;

    switch (activeSurface) {
      case CavitySurfaceType.puddle:
        modalFreqs = [520.0 * bright, 940.0 * bright, 1680.0 * bright, 2800.0 * bright];
        modalGains = [0.45, 0.35, 0.25, 0.15];
        break;
      case CavitySurfaceType.tinRoof:
        modalFreqs = [1250.0 * bright, 2480.0 * bright, 3950.0 * bright, 5800.0 * bright];
        modalGains = [0.30, 0.40, 0.35, 0.30];
        break;
      case CavitySurfaceType.foliage:
        modalFreqs = [720.0 * bright, 1450.0 * bright, 2200.0 * bright, 3400.0 * bright];
        modalGains = [0.50, 0.30, 0.15, 0.08];
        break;
      case CavitySurfaceType.hollowLog:
        modalFreqs = [240.0 * bright, 480.0 * bright, 960.0 * bright, 1850.0 * bright];
        modalGains = [0.55, 0.40, 0.25, 0.15];
        break;
      case CavitySurfaceType.chimneyHowl:
        modalFreqs = [185.0 * bright, 370.0 * bright, 740.0 * bright, 1480.0 * bright];
        modalGains = [0.60, 0.45, 0.30, 0.20];
        break;
      case CavitySurfaceType.chasm:
        modalFreqs = [65.0 * bright, 130.0 * bright, 260.0 * bright, 520.0 * bright];
        modalGains = [0.70, 0.50, 0.35, 0.20];
        break;
    }

    final double sr = ctx.sampleRate;
    final double twoPi = 2.0 * math.pi;

    // Filter states for 4 parallel 2-pole resonators
    double s1A = 0.0, s1B = 0.0;
    double s2A = 0.0, s2B = 0.0;
    double s3A = 0.0, s3B = 0.0;
    double s4A = 0.0, s4B = 0.0;

    final double w1 = (twoPi * modalFreqs[0] / sr).clamp(0.01, math.pi - 0.01);
    final double w2 = (twoPi * modalFreqs[1] / sr).clamp(0.01, math.pi - 0.01);
    final double w3 = (twoPi * modalFreqs[2] / sr).clamp(0.01, math.pi - 0.01);
    final double w4 = (twoPi * modalFreqs[3] / sr).clamp(0.01, math.pi - 0.01);

    final double r1 = reso.clamp(0.1, 0.995);
    final double r2 = (reso * 0.96).clamp(0.1, 0.995);
    final double r3 = (reso * 0.92).clamp(0.1, 0.995);
    final double r4 = (reso * 0.88).clamp(0.1, 0.995);

    for (int i = 0; i < len; i++) {
      final double x = inBuf[i];

      final double y1 = x + 2.0 * r1 * math.cos(w1) * s1A - r1 * r1 * s1B;
      s1B = s1A; s1A = y1;

      final double y2 = x + 2.0 * r2 * math.cos(w2) * s2A - r2 * r2 * s2B;
      s2B = s2A; s2A = y2;

      final double y3 = x + 2.0 * r3 * math.cos(w3) * s3A - r3 * r3 * s3B;
      s3B = s3A; s3A = y3;

      final double y4 = x + 2.0 * r4 * math.cos(w4) * s4A - r4 * r4 * s4B;
      s4B = s4A; s4A = y4;

      final double modalSum = y1 * modalGains[0] + y2 * modalGains[1] + y3 * modalGains[2] + y4 * modalGains[3];
      outBuffer[i] = (x * 0.35 + modalSum * 0.65).clamp(-1.0, 1.0);
    }
  }
}

/// Fundamental Acoustic Atmospheric Propagation Node.
/// Models distance-dependent high-frequency air absorption ($e^{-\alpha(f) \cdot d}$),
/// multi-path terrain reflections, and dispersive all-pass phase smearing
/// for thunder strikes, explosions, and distant environmental audio.
class AcousticPropagationNode extends GraphNode {
  final GraphNode input;
  final double distanceMeters;
  final String? distanceParam;
  final double dispersion;
  final String? dispersionParam;
  final double airAbsorption;
  final String? airAbsorptionParam;

  const AcousticPropagationNode({
    required this.input,
    this.distanceMeters = 350.0,
    this.distanceParam,
    this.dispersion = 0.50,
    this.dispersionParam,
    this.airAbsorption = 0.70,
    this.airAbsorptionParam,
  });

  @override
  void process(GraphContext ctx, Float32List outBuffer) {
    final int len = outBuffer.length;
    final Float32List inBuf = Float32List(len);
    input.process(ctx, inBuf);

    final double dist = (distanceParam != null ? ctx.getParam(distanceParam!, distanceMeters) : distanceMeters).clamp(10.0, 5000.0);
    final double disp = (dispersionParam != null ? ctx.getParam(dispersionParam!, dispersion) : dispersion).clamp(0.0, 1.0);
    final double absorp = (airAbsorptionParam != null ? ctx.getParam(airAbsorptionParam!, airAbsorption) : airAbsorption).clamp(0.0, 1.0);

    final double sr = ctx.sampleRate;

    // Distance-dependent air absorption lowpass cutoff (higher frequencies attenuate dramatically with distance)
    final double baseCutoff = 18000.0 / (1.0 + (dist / 220.0) * (1.0 + absorp * 1.5));
    final double fc = baseCutoff.clamp(120.0, 18000.0);
    final double w0 = 2.0 * math.pi * fc / sr;
    final double alpha = math.sin(w0) / (2.0 * 0.707);
    final double cosw0 = math.cos(w0);

    final double b0 = (1.0 - cosw0) / 2.0;
    final double b1 = 1.0 - cosw0;
    final double b2 = (1.0 - cosw0) / 2.0;
    final double a0 = 1.0 + alpha;
    final double a1 = -2.0 * cosw0;
    final double a2 = 1.0 - alpha;

    final double nb0 = b0 / a0, nb1 = b1 / a0, nb2 = b2 / a0;
    final double na1 = a1 / a0, na2 = a2 / a0;

    double x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    // 2-stage all-pass dispersion network state (phase delay smear)
    double ap1X = 0.0, ap1Y = 0.0;
    double ap2X = 0.0, ap2Y = 0.0;
    final double apCoeff = (0.35 * disp).clamp(0.0, 0.85);

    // Multi-path terrain reflection delay buffer (up to 40ms)
    final int delaySamples = ((dist * 0.0008).clamp(0.005, 0.040) * sr).toInt();
    final Float32List dBuf = Float32List(math.max(1, delaySamples));
    int dIdx = 0;

    for (int i = 0; i < len; i++) {
      final double inSample = inBuf[i];

      // 1. Air Absorption Lowpass
      final double lp = nb0 * inSample + nb1 * x1 + nb2 * x2 - na1 * y1 - na2 * y2;
      x2 = x1; x1 = inSample;
      y2 = y1; y1 = lp;

      // 2. Dispersive Allpass Phase Smear (Stage 1 & 2)
      final double ap1 = apCoeff * lp + ap1X - apCoeff * ap1Y;
      ap1X = lp; ap1Y = ap1;

      final double ap2 = apCoeff * ap1 + ap2X - apCoeff * ap2Y;
      ap2X = ap1; ap2Y = ap2;

      // 3. Multi-path Terrain Echo Reflection
      final double echo = dBuf[dIdx];
      dBuf[dIdx] = ap2;
      dIdx = (dIdx + 1) % dBuf.length;

      outBuffer[i] = (ap2 * 0.75 + echo * 0.35).clamp(-1.0, 1.0);
    }
  }
}













