import 'dart:math' as math;
import 'dart:typed_data';

import 'graph_node.dart';
import 'graph_primitives.dart';

/// Evaluator that executes modular audio graphs into high-performance Float32List PCM buffers.
class GraphEvaluator {
  /// Evaluates a [root] node into a rendered [Float32List] audio buffer.
  static Float32List evaluate({
    required GraphNode root,
    required double durationSec,
    required double freq,
    required int note,
    required Map<String, double> params,
    double sampleRate = 44100.0,
    double velocity = 1.0,
    bool isAccent = false,
    bool isSlide = false,
    int? targetMidiNote,
    bool applyEdgeFade = true,
  }) {
    final ctx = GraphContext(
      sampleRate: sampleRate,
      durationSec: durationSec,
      freq: freq,
      midiNote: note,
      velocity: velocity,
      isAccent: isAccent,
      isSlide: isSlide,
      targetMidiNote: targetMidiNote,
      params: params,
    );

    final buffer = Float32List(ctx.totalSamples);
    root.process(ctx, buffer);

    if (applyEdgeFade && ctx.totalSamples > 64) {
      final fadeSamples = (sampleRate * 0.03).toInt().clamp(32, ctx.totalSamples ~/ 4);
      for (int i = 0; i < fadeSamples; i++) {
        final double norm = i / fadeSamples;
        final double window = 0.5 * (1.0 - math.cos(math.pi * norm));
        final int endIdx = ctx.totalSamples - 1 - i;
        buffer[endIdx] *= window;
      }
    }

    return buffer;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  FACTORY PRESET GRAPH BUILDERS (Dual-Mic FM Physical Modeling & Synthesizers)
  // ───────────────────────────────────────────────────────────────────────────

  /// Dual-Mic FM Noise Acoustic Kick Drum Graph
  /// Architecture:
  /// - Nearfield (Kick In): White Noise -> FM Gain Env -> Carrier Sine (Pitch Sweep) -> Peaking Sub -> Mid Scoop -> High Shelf Click
  /// - Farfield (Kick Out / Room): White Noise -> Far FM Gain Env -> Far Carrier Sine -> Highpass -> Room Body Peaking -> Room Delay
  /// - Master: Summing Mixer -> Tanh Saturation
  static GraphNode buildDualMicFmAcousticKick() {
    const noise = NoiseNode();

    // 1. Nearfield (Batter Head Impact)
    const nearPitchSweep = PitchSweepNode(
      startFreq: 180.0,
      endFreq: 52.0,
      decaySec: 0.07,
      startParam: 'NearPitchStart',
      endParam: 'NearPitchEnd',
      decayParam: 'NearPitchDecay',
    );

    const nearFmEnv = DecayEnvNode(decaySec: 0.008, decayParam: 'NearFmDecay');
    const nearFmMod = GainNode(
      input: noise,
      gainSource: nearFmEnv,
      staticGain: 600.0,
      gainParam: 'NearFmDepth',
    );

    const nearCarrier = SineOscNode(
      freqSource: nearPitchSweep,
      fmModSource: nearFmMod,
    );

    const nearAmpEnv = DecayEnvNode(decaySec: 0.28, decayParam: 'NearAmpDecay');
    const nearVca = GainNode(input: nearCarrier, gainSource: nearAmpEnv);

    // 3-Band Parametric EQ
    const nearSubBoost = BiquadFilterNode(
      input: nearVca,
      type: BiquadType.peaking,
      frequency: 60.0,
      freqParam: 'SubResoFreq',
      q: 3.5,
      qParam: 'SubResoQ',
      gainDb: 4.0,
      gainDbParam: 'SubResoGain',
    );

    const nearMidScoop = BiquadFilterNode(
      input: nearSubBoost,
      type: BiquadType.peaking,
      frequency: 350.0,
      q: 1.8,
      gainDb: -8.0,
    );

    const nearClickEq = BiquadFilterNode(
      input: nearMidScoop,
      type: BiquadType.highshelf,
      frequency: 3500.0,
      gainDb: 6.0,
    );

    // 2. Farfield (Room / Mic Out)
    const farPitchSweep = PitchSweepNode(
      startFreq: 130.0,
      endFreq: 95.0,
      decaySec: 0.15,
      startParam: 'FarPitchStart',
      endParam: 'FarPitchEnd',
      decayParam: 'FarPitchDecay',
    );

    const farFmEnv = DecayEnvNode(decaySec: 0.045, decayParam: 'FarFmDecay');
    const farFmMod = GainNode(
      input: noise,
      gainSource: farFmEnv,
      staticGain: 250.0,
      gainParam: 'FarFmDepth',
    );

    const farCarrier = SineOscNode(
      freqSource: farPitchSweep,
      fmModSource: farFmMod,
    );

    const farAmpEnv = DecayEnvNode(decaySec: 0.22, decayParam: 'FarAmpDecay');
    const farVca = GainNode(
      input: farCarrier,
      gainSource: farAmpEnv,
      staticGain: 0.35,
      gainParam: 'FarLevel',
    );

    const farHp = BiquadFilterNode(
      input: farVca,
      type: BiquadType.highpass,
      frequency: 85.0,
      q: 0.707,
    );

    const farRoomPeak = BiquadFilterNode(
      input: farHp,
      type: BiquadType.peaking,
      frequency: 160.0,
      q: 2.0,
      gainDb: 3.0,
    );

    const farDelayed = DelayNode(
      input: farRoomPeak,
      delaySec: 0.008,
      delayParam: 'RoomDelaySec',
    );

    // 3. Summing & Soft Saturation
    const masterMix = MixerNode([nearClickEq, farDelayed], [1.0, 1.0]);
    return const DistortionNode(input: masterMix, drive: 1.15);
  }

  /// Dual-Mic FM Acoustic Snare Drum Graph
  /// Architecture:
  /// - Dual-body swept fundamental carrier (185Hz -> 130Hz)
  /// - Noise-modulated snare wires (Highpass + Highshelf)
  /// - Beater click transient
  /// - Room acoustic reflection
  static GraphNode buildDualMicFmAcousticSnare() {
    const noise = NoiseNode(seed: 0x98765432);

    // Body Tone
    const bodySweep = PitchSweepNode(
      startFreq: 220.0,
      endFreq: 175.0,
      decaySec: 0.08,
      startParam: 'BodyPitchStart',
      endParam: 'ToneFreq',
    );

    const bodyOsc = SineOscNode(freqSource: bodySweep);
    const bodyEnv = DecayEnvNode(decaySec: 0.16, decayParam: 'ToneDecay');
    const bodyVca = GainNode(input: bodyOsc, gainSource: bodyEnv);

    // Snare Wires (Filtered Noise)
    const wireHp = BiquadFilterNode(
      input: noise,
      type: BiquadType.highpass,
      frequency: 1800.0,
      freqParam: 'WireCutoff',
      q: 1.2,
    );

    const wireEnv = DecayEnvNode(decaySec: 0.22, decayParam: 'Decay');
    const wireVca = GainNode(
      input: wireHp,
      gainSource: wireEnv,
      staticGain: 0.65,
      gainParam: 'Snappy',
    );

    // Summing & Saturation
    const masterMix = MixerNode([bodyVca, wireVca], [0.85, 1.2]);
    return const DistortionNode(input: masterMix, drive: 1.2);
  }

  /// Dual-Mic FM Acoustic Tom (Floor, Mid, & Rack)
  static GraphNode buildDualMicFmAcousticTom() {
    const noise = NoiseNode(seed: 0x55AA1122);

    // Batter Head Pitch Sweep
    const batterSweep = PitchSweepNode(
      startFreq: 160.0,
      endFreq: 90.0,
      decaySec: 0.12,
      startParam: 'TomPitchStart',
      endParam: 'ToneFreq',
      decayParam: 'PitchDecay',
    );

    // Noise FM Stick Impact
    const fmEnv = DecayEnvNode(decaySec: 0.012, decayParam: 'StickDecay');
    const fmMod = GainNode(
      input: noise,
      gainSource: fmEnv,
      staticGain: 350.0,
      gainParam: 'StickFmDepth',
    );

    const batterOsc = SineOscNode(
      freqSource: batterSweep,
      fmModSource: fmMod,
    );

    const ampEnv = DecayEnvNode(decaySec: 0.45, decayParam: 'Decay');
    const batterVca = GainNode(input: batterOsc, gainSource: ampEnv);

    // Shell & Room Resonance
    const shellReso = BiquadFilterNode(
      input: batterVca,
      type: BiquadType.peaking,
      frequency: 140.0,
      freqParam: 'ShellFreq',
      q: 3.0,
      gainDb: 4.0,
    );

    const roomDelayed = DelayNode(
      input: shellReso,
      delaySec: 0.010,
      delayParam: 'RoomDelaySec',
    );

    const masterMix = MixerNode([shellReso, roomDelayed], [1.0, 0.4]);
    return const DistortionNode(input: masterMix, drive: 1.1);
  }

  /// Dual-Mic FM Acoustic Hi-Hat (Closed & Open)
  static GraphNode buildDualMicFmAcousticHiHat() {
    const metalCluster = MetallicClusterNode();
    const noise = NoiseNode(seed: 0x33445566);

    // Stick Click Transient
    const stickEnv = DecayEnvNode(decaySec: 0.005);
    const stickVca = GainNode(input: noise, gainSource: stickEnv, staticGain: 0.3);

    // Mixed Metallic & Noise Core
    const mixCore = MixerNode([metalCluster, noise], [0.7, 0.3]);
    const decayEnv = DecayEnvNode(decaySec: 0.08, decayParam: 'Decay');
    const gatedCore = GainNode(input: mixCore, gainSource: decayEnv);

    // Highpass & Highshelf EQ
    const hpf = BiquadFilterNode(
      input: gatedCore,
      type: BiquadType.highpass,
      frequency: 7000.0,
      freqParam: 'Cutoff',
      q: 1.4,
    );

    const highShelf = BiquadFilterNode(
      input: hpf,
      type: BiquadType.highshelf,
      frequency: 10000.0,
      gainDb: 4.0,
    );

    const masterMix = MixerNode([highShelf, stickVca], [1.0, 1.0]);
    return const DistortionNode(input: masterMix, drive: 1.05);
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  AUTHENTIC ANALOG 808 SUITE GRAPH BUILDERS
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Roland TR-808 Bridged-T Bass Drum
  static GraphNode buildAnalog808Kick() {
    const pitchSweep = PitchSweepNode(
      startFreq: 140.0,
      endFreq: 46.0,
      decaySec: 0.045,
      startParam: 'StartFreq',
      endParam: 'Tune',
      decayParam: 'PitchDecay',
    );

    const sineOsc = SineOscNode(freqSource: pitchSweep);
    const ampEnv = DecayEnvNode(decaySec: 0.85, decayParam: 'Decay');
    const vca = GainNode(input: sineOsc, gainSource: ampEnv);

    // Tone Lowpass Filter
    const toneFilter = BiquadFilterNode(
      input: vca,
      type: BiquadType.lowpass,
      frequency: 220.0,
      freqParam: 'Tone',
      q: 0.707,
    );

    // Click transient
    const noise = NoiseNode();
    const clickEnv = DecayEnvNode(decaySec: 0.004);
    const clickVca = GainNode(
      input: noise,
      gainSource: clickEnv,
      staticGain: 0.15,
      gainParam: 'Click',
    );

    const masterMix = MixerNode([toneFilter, clickVca], [1.0, 1.0]);
    return const DistortionNode(input: masterMix, drive: 1.25, driveParam: 'Overdrive');
  }

  /// Authentic Roland TR-808 Snare Drum (Dual Resonant Body + Snappy Wires)
  static GraphNode buildAnalog808Snare() {
    // Body Tone 1 (180Hz) & Tone 2 (330Hz)
    const body1 = SineOscNode(staticFreq: 180.0);
    const body2 = SineOscNode(staticFreq: 330.0);
    const bodyMix = MixerNode([body1, body2], [0.6, 0.4]);
    const bodyEnv = DecayEnvNode(decaySec: 0.12, decayParam: 'ToneDecay');
    const bodyVca = GainNode(input: bodyMix, gainSource: bodyEnv);

    // Snappy Highpass Noise
    const noise = NoiseNode();
    const noiseHp = BiquadFilterNode(
      input: noise,
      type: BiquadType.highpass,
      frequency: 2000.0,
      q: 1.5,
    );
    const snappyEnv = DecayEnvNode(decaySec: 0.20, decayParam: 'Decay');
    const snappyVca = GainNode(
      input: noiseHp,
      gainSource: snappyEnv,
      staticGain: 0.7,
      gainParam: 'Snappy',
    );

    const masterMix = MixerNode([bodyVca, snappyVca], [0.85, 1.15]);
    return const DistortionNode(input: masterMix, drive: 1.15);
  }

  /// Authentic Roland TR-808 6-Oscillator Hi-Hat
  static GraphNode buildAnalog808HiHat() {
    const metalCluster = MetallicClusterNode(pitchParam: 'Tune');
    const decayEnv = DecayEnvNode(decaySec: 0.08, decayParam: 'Decay');
    const vca = GainNode(input: metalCluster, gainSource: decayEnv);

    // Resonant Bandpass Filter (~7.5kHz)
    const bpf = BiquadFilterNode(
      input: vca,
      type: BiquadType.bandpass,
      frequency: 7500.0,
      freqParam: 'Cutoff',
      q: 3.2,
    );

    return const DistortionNode(input: bpf, drive: 1.1);
  }

  /// Authentic Roland TR-808 Dual-Square Cowbell
  static GraphNode buildAnalog808Cowbell() {
    const osc1 = SquareOscNode(staticFreq: 540.0);
    const osc2 = SquareOscNode(staticFreq: 800.0);
    const oscMix = MixerNode([osc1, osc2], [0.5, 0.5]);

    const decayEnv = DecayEnvNode(decaySec: 0.32, decayParam: 'Decay');
    const vca = GainNode(input: oscMix, gainSource: decayEnv);

    const bpf = BiquadFilterNode(
      input: vca,
      type: BiquadType.bandpass,
      frequency: 800.0,
      freqParam: 'Tune',
      q: 2.2,
    );

    return const DistortionNode(input: bpf, drive: 1.2);
  }

  /// Authentic Roland TR-808 Resonant Bridged-T Tom / Conga
  static GraphNode buildAnalog808Tom() {
    const pitchSweep = PitchSweepNode(
      startFreq: 160.0,
      endFreq: 100.0,
      decaySec: 0.08,
      startParam: 'StartFreq',
      endParam: 'Tune',
      decayParam: 'PitchDecay',
    );

    const sineOsc = SineOscNode(freqSource: pitchSweep);
    const decayEnv = DecayEnvNode(decaySec: 0.40, decayParam: 'Decay');
    const vca = GainNode(input: sineOsc, gainSource: decayEnv);

    const shellFilter = BiquadFilterNode(
      input: vca,
      type: BiquadType.peaking,
      frequency: 120.0,
      q: 2.5,
      gainDb: 3.0,
    );

    return const DistortionNode(input: shellFilter, drive: 1.1);
  }
}

