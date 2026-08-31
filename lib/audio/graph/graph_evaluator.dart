import 'dart:math' as math;
import 'dart:typed_data';

import 'graph_node.dart';
import 'graph_primitives.dart';
import 'tr909_rom_data.dart';

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
    String? articulation,
    double releaseVelocity = 0.5,
    List<List<double>>? pitchBendPoints,
    List<List<double>>? pressurePoints,
    List<List<double>>? timbrePoints,
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
      articulation: articulation,
      releaseVelocity: releaseVelocity,
      pitchBendPoints: pitchBendPoints,
      pressurePoints: pressurePoints,
      timbrePoints: timbrePoints,
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

  /// Authentic Eats-808 analog Bridged-T Bass Drum
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

  /// Authentic Eats-808 analog Snare Drum (Dual Resonant Body + Snappy Wires)
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

  /// Authentic Eats-808 analog 6-Oscillator Hi-Hat
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

  /// Authentic Eats-808 analog Dual-Square Cowbell
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

  /// Authentic Eats-808 analog Resonant Bridged-T Tom / Conga
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

  // ───────────────────────────────────────────────────────────────────────────
  //  AUTHENTIC ANALOG 909 SUITE GRAPH BUILDERS (André Michelle Physical / ROM Model)
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Eats-909 analog Bass Drum (André Michelle physical model)
  static GraphNode buildAnalog909Kick() {
    return const Tr909KickNode(
      tuneParam: 'Tune',
      decayParam: 'Decay',
      attackParam: 'Attack',
    );
  }

  /// Authentic Eats-909 analog Snare Drum (Dual Tonal Body + Snappy Noise Wires)
  static GraphNode buildAnalog909Snare() {
    return const Tr909SnareNode(
      tuneParam: 'Tune',
      toneParam: 'ToneDecay',
      snappyParam: 'Snappy',
    );
  }

  /// Authentic Eats-909 analog Closed Hi-Hat (6-bit PCM ROM + Analog VCA Decay)
  static GraphNode buildAnalog909ClosedHiHat() {
    return Tr909SampleVoiceNode(
      getBuffer: () => Tr909RomData.closed_hihat,
      tuneParam: 'Tune',
      decay: 0.025,
      decayParam: 'Decay',
    );
  }

  /// Authentic Eats-909 analog Open Hi-Hat (6-bit PCM ROM + Extended Analog Decay)
  static GraphNode buildAnalog909OpenHiHat() {
    return Tr909SampleVoiceNode(
      getBuffer: () => Tr909RomData.opened_hihat,
      tuneParam: 'Tune',
      decay: 0.080,
      decayParam: 'Decay',
    );
  }

  /// Authentic Eats-909 analog Handclap (Multi-Burst Trigger & Reverb Diffuse Tail)
  static GraphNode buildAnalog909Clap() {
    return Tr909SampleVoiceNode(
      getBuffer: () => Tr909RomData.clap,
      tuneParam: 'Tune',
      decay: 0.28,
      decayParam: 'Decay',
    );
  }

  /// Authentic Eats-909 analog Rimshot (High-Q Resonant Tank "Clack")
  static GraphNode buildAnalog909Rimshot() {
    return Tr909SampleVoiceNode(
      getBuffer: () => Tr909RomData.rim,
      tuneParam: 'Tune',
      decay: 0.075,
      decayParam: 'Decay',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  RHODES MARK I / SUITCASE E-PIANO PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Vintage Rhodes Mark I / Suitcase 73 E-Piano Physical Model
  /// Architecture:
  /// - Neoprene Hammer Exciter (velocity-scaled contact pulse + micro-click)
  /// - Tine Tone Generator:
  ///   - Fundamental carrier sine + 2nd harmonic sine
  ///   - Inharmonic tine bell bar resonance (ratios 1.0, 2.76, 5.40, 8.93)
  ///   - Exponential tine decay envelope with velocity brightness scaling
  /// - Asymmetric Magnetic Reluctance Pickup (quadratic 2nd-order bark saturation)
  /// - Vintage 2-Band Active Preamp Tone Stack (Bass Boost & Treble Bell Sparkle)
  /// - Optical Suitcase Tremolo / Auto-Pan Modulation
  /// - Tube / Preamp Overdrive Saturation
  static GraphNode buildRhodesEPiano() {
    // 1. Neoprene hammer strike transient
    const hammer = HammerExciterNode(
      hardness: 1.0,
      hardnessParam: 'HammerHardness',
      clickLevel: 0.8,
      clickLevelParam: 'TineClick',
    );

    // 2. Fundamental & harmonic sine carriers
    const fundamental = SineOscNode();
    const tineDecay = DecayEnvNode(
      decaySec: 2.2,
      decayParam: 'TineDecay',
    );

    const fundamentalVca = GainNode(
      input: fundamental,
      gainSource: tineDecay,
    );

    // 3. Inharmonic Tine Bell Mode Cluster (Bar Physics: 1.0, 2.76, 5.40, 8.93)
    const bellDecay = DecayEnvNode(
      decaySec: 0.55,
      decayParam: 'BellDecay',
    );

    const bellResonator = ModalResonatorBankNode(
      input: hammer,
      modeFreqRatios: [1.0, 2.756, 5.404, 8.933],
      modeGains: [0.6, 0.45, 0.25, 0.15],
      modeQFactors: [18.0, 35.0, 50.0, 60.0],
    );

    const bellVca = GainNode(
      input: bellResonator,
      gainSource: bellDecay,
      staticGain: 0.75,
      gainParam: 'TineBell',
    );

    // 4. Sum Hammer Strike + Fundamental + Inharmonic Bell
    const tineMixer = MixerNode(
      [fundamentalVca, bellVca, hammer],
      [0.85, 0.65, 0.20],
    );

    // 5. Asymmetric Magnetic Pickup Saturation (2nd harmonic warmth & dynamic bark)
    const pickup = PickupSaturationNode(
      input: tineMixer,
      distance: 1.0,
      distanceParam: 'PickupDistance',
      symmetry: 0.65,
      symmetryParam: 'BarkSymmetry',
    );

    // 6. 2-Band Active Preamp Tone Stack (Bass Boost & Treble Bell Sparkle)
    const bassEq = BiquadFilterNode(
      input: pickup,
      type: BiquadType.lowshelf,
      frequency: 140.0,
      gainDb: 2.0,
      gainDbParam: 'BassBoost',
    );

    const trebleEq = BiquadFilterNode(
      input: bassEq,
      type: BiquadType.highshelf,
      frequency: 4200.0,
      gainDb: 3.0,
      gainDbParam: 'TrebleSparkle',
    );

    // 7. Suitcase Optical Tremolo
    const tremolo = StereoTremoloNode(
      input: trebleEq,
      rateHz: 4.5,
      rateParam: 'TremoloSpeed',
      depth: 0.0,
      depthParam: 'TremoloDepth',
    );

    // 8. Preamp Drive / Warm Saturation
    return const DistortionNode(
      input: tremolo,
      drive: 1.05,
      driveParam: 'Drive',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  REGGAE SKANK & DUB CHOP GUITAR PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Reggae Skank & Dub Chop Guitar Physical Model
  /// Architecture:
  /// - Plectrum Multi-String Strum Exciter (2-25ms rake brush + pick bite)
  /// - Karplus-Strong Digital Waveguide with 1-Pole Loop Damping (Palm Mute control)
  /// - Dynamic Chop / Skank Gating Envelope (40ms tight chick to 400ms ringing skank)
  /// - Single-Coil / P90 Pickup Voicing (130Hz Sub-Bass Highpass + 3.2kHz Bite Peak)
  /// - Semi-Hollow / Solid Wood Body Modal Resonator
  /// - Vintage Tube Preamp Drive (Fender Twin Reverb clean bark)
  static GraphNode buildReggaeGuitar() {
    // 1. Plectrum Strum Exciter (rake across strings)
    const exciter = PlectrumStrumExciterNode(
      strumSpreadMs: 8.0,
      strumSpreadParam: 'StrumSpread',
      pickBite: 1.2,
      pickBiteParam: 'PickBite',
    );

    // 2. Waveguide String Physical Model with Palm Mute Loop Loss
    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.994,
      feedbackParam: 'Sustain',
      damping: 0.35,
      dampingParam: 'PalmDamp',
    );

    // 3. Guitar Body Resonance (Helmholtz air cavity + Top wood plate)
    const bodyResonator = ModalResonatorBankNode(
      input: waveguide,
      modeFreqRatios: [1.0, 1.95, 2.78],
      modeGains: [0.45, 0.25, 0.15],
      modeQFactors: [12.0, 18.0, 24.0],
    );

    const bodyMixer = MixerNode(
      [waveguide, bodyResonator],
      [0.85, 0.40],
    );

    // 4. Reggae Single-Coil Pickup Voicing & EQ Tone Stack
    // Low Cut @ 130 Hz: keeps offbeat chops crystal clear above heavy reggae sub-bass
    const lowCut = BiquadFilterNode(
      input: bodyMixer,
      type: BiquadType.highpass,
      frequency: 130.0,
    );

    // 3.2 kHz Pick Presence Bite
    const biteEq = BiquadFilterNode(
      input: lowCut,
      type: BiquadType.peaking,
      frequency: 3200.0,
      gainDb: 4.0,
      gainDbParam: 'BiteGain',
    );

    // Tone Knob (Treble Roll-off)
    const toneLp = BiquadFilterNode(
      input: biteEq,
      type: BiquadType.lowpass,
      frequency: 6500.0,
      freqParam: 'ToneCutoff',
      q: 0.707,
    );

    // 5. Preamp Clean Drive / Vintage Tube Warmth
    return const DistortionNode(
      input: toneLp,
      drive: 1.15,
      driveParam: 'Drive',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  HAWAIIAN ACOUSTIC UKULELE PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Hawaiian Acoustic Ukulele Physical Model
  /// Architecture:
  /// - 4-String Re-entrant Nylon/Fluorocarbon Strum Exciter
  /// - Karplus-Strong Waveguide with Acoustic Loss Damping & Open Sustain
  /// - Hawaiian Koa Soundboard & Air Cavity Modal Resonator Bank (330Hz, 590Hz, 1150Hz)
  /// - Acoustic 180Hz Sub Cut + 2.8kHz Island Brightness Voicing
  static GraphNode buildHawaiianUkulele() {
    // 1. Nylon Strum Exciter (fingertip / felt brush across strings)
    const exciter = PlectrumStrumExciterNode(
      strumSpreadMs: 6.5,
      strumSpreadParam: 'StrumSpread',
      pickBite: 1.1,
      pickBiteParam: 'PluckSnap',
    );

    // 2. Waveguide Nylon String Physical Model
    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.993,
      feedbackParam: 'Sustain',
      damping: 0.28,
      dampingParam: 'Damping',
    );

    // 3. Hawaiian Koa Wood Acoustic Cavity & Top Plate Resonator
    // Modal frequencies representing small acoustic concert/tenor body
    const bodyResonator = ModalResonatorBankNode(
      input: waveguide,
      modeFreqRatios: [1.0, 1.82, 3.45],
      modeGains: [0.55, 0.35, 0.20],
      modeQFactors: [14.0, 20.0, 28.0],
    );

    const acousticBodyMixer = MixerNode(
      [waveguide, bodyResonator],
      [0.80, 0.50],
    );

    // 4. Acoustic Low Cut @ 180 Hz (Acoustic Ukulele bottom fundamental)
    const lowCut = BiquadFilterNode(
      input: acousticBodyMixer,
      type: BiquadType.highpass,
      frequency: 180.0,
    );

    // 6. Island Presence & Koa Wood Air EQ
    const islandBrightness = BiquadFilterNode(
      input: lowCut,
      type: BiquadType.peaking,
      frequency: 2800.0,
      gainDb: 3.5,
      gainDbParam: 'Brightness',
    );

    // 7. Tone / Soundboard Warmth
    return const BiquadFilterNode(
      input: islandBrightness,
      type: BiquadType.lowpass,
      frequency: 7200.0,
      freqParam: 'Tone',
      q: 0.707,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  VOLTAIC HIGH-VOLTAGE PLASMA SYNTHESIZER (Electricity Physical Model)
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic High-Voltage Electricity & Singing Plasma Arc Physical Model.
  /// Architecture:
  /// - Tuned Plasma Arc Oscillator (asymmetric thermal expansion + cycle-to-cycle spark jitter)
  /// - Stochastic Corona Discharge & Ion Sizzle (Poisson micro-spark burst generator)
  /// - 50Hz/60Hz Substation Transformer Magnetostriction & Power Grid Bleed
  /// - Dielectric Breakdown Attack Snap & Plasma Extinguish Sputter Exciter
  /// - Spark Gap Acoustic Formant Cavity Resonators (1.8 kHz plasma core + 6.8 kHz air snap)
  /// - Ozone & Dielectric Non-Linear Saturation
  /// - Master Voltage & Gas Tone Filter
  static GraphNode buildVoltaicPlasmaSynth() {
    // 1. Tuned Plasma Arc Oscillator (The Singing Arc Core)
    const plasmaOsc = PlasmaArcOscNode(
      sparkWidth: 0.15,
      sparkWidthParam: 'SparkGap',
      jitter: 0.35,
      jitterParam: 'Jitter',
      subHarmonic: 0.0,
      subHarmonicParam: 'SubHarmonic',
    );

    const plasmaEnv = AdsrEnvNode(
      attack: 0.003,
      decay: 0.12,
      sustain: 0.88,
      release: 0.06,
    );

    const plasmaVca = GainNode(
      input: plasmaOsc,
      gainSource: plasmaEnv,
    );

    // 2. Stochastic Corona Discharge & Ion Wind Sizzle
    const coronaCrackle = PoissonCrackleNode(
      density: 0.35,
      densityParam: 'CrackleRate',
      sizzleBright: 0.75,
      sizzleBrightParam: 'SizzleBright',
    );

    const crackleVca = GainNode(
      input: coronaCrackle,
      gainSource: plasmaEnv,
      staticGain: 0.85,
    );

    // 3. 50Hz/60Hz Substation Transformer Magnetostriction Hum
    const substationHum = SubstationHumNode(
      humLevel: 0.30,
      humLevelParam: 'GridHum',
      mainsFreq: 60.0,
      mainsFreqParam: 'MainsFreq',
    );

    // 4. Dielectric Breakdown Snap (Attack) & Plasma Extinguish Sputter (Release)
    const breakdownSnap = BreakdownExciterNode(
      snapLevel: 0.90,
      snapLevelParam: 'SnapAttack',
      sputterDecay: 0.05,
      sputterDecayParam: 'SputterDecay',
    );

    // 5. Sum all 4 physical acoustic discharge layers
    const arcMixer = MixerNode(
      [plasmaVca, crackleVca, substationHum, breakdownSnap],
      [0.90, 0.50, 0.40, 0.75],
    );

    // 6. Spark Gap Acoustic Formant Cavity Resonators
    // Formant 1: 1.8 kHz Plasma Column Body Resonance
    const formantBody = BiquadFilterNode(
      input: arcMixer,
      type: BiquadType.peaking,
      frequency: 1850.0,
      q: 2.8,
      gainDb: 4.5,
    );

    // Formant 2: 6.8 kHz Air Ionization Snap
    const formantSnap = BiquadFilterNode(
      input: formantBody,
      type: BiquadType.peaking,
      frequency: 6800.0,
      q: 3.5,
      gainDb: 3.5,
    );

    // 7. Ozone & High-Voltage Dielectric Saturation
    const ozoneSaturation = OzoneSaturationNode(
      input: formantSnap,
      drive: 1.35,
      driveParam: 'OzoneDrive',
      bias: 0.10,
    );

    // 8. Plasma Vortex All-Pass Phaser (Comb notch dispersion & phase swirl)
    const plasmaPhaser = PhaserNode(
      input: ozoneSaturation,
      rate: 0.45,
      rateParam: 'PhaserRate',
      depth: 0.65,
      depthParam: 'PhaserDepth',
      feedback: 0.40,
      feedbackParam: 'PhaserFeedback',
      mix: 0.45,
      mixParam: 'PhaserMix',
      baseFreq: 750.0,
    );

    // 9. Master Tone & Gas Medium Voicing (Highpass Low-Cut + Lowpass High-Cut)
    const lowCutHp = BiquadFilterNode(
      input: plasmaPhaser,
      type: BiquadType.highpass,
      frequency: 30.0,
      freqParam: 'ToneHighpass',
      q: 0.707,
    );

    return const BiquadFilterNode(
      input: lowCutHp,
      type: BiquadType.lowpass,
      frequency: 8500.0,
      freqParam: 'Tone',
      q: 0.707,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  PYROPHONE THERMOACOUSTIC FLAME SYNTHESIZER (Fire Physical Model)
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Singing Flame & Thermoacoustic Combustion Physical Model.
  /// Architecture:
  /// - Kastner Rijke Singing Flame Oscillator (thermal expansion cusp + convection drift)
  /// - Turbulent Combustion Roar (1/f Brownian thermal vortex flutter)
  /// - Supercritical Wood Sap Pocket Explosions & Ember Sizzle Crackle Matrix
  /// - Flashover Deflagration Ignition Whoosh (Attack) & Charcoal Smolder (Release)
  /// - Glass & Brass Rijke Acoustic Draft Tube Formants (950Hz & 2.4kHz peaks)
  /// - Fuel Pressure Thermal Overdrive & Convection Wave Phaser
  /// - Chimney Tone Filtering (Highpass Low-Cut + Lowpass High-Cut)
  static GraphNode buildPyrophoneSynth() {
    // 1. Kastner Rijke Singing Flame Oscillator
    const flameOsc = ThermoacousticFlameOscNode(
      flameCusp: 0.45,
      flameCuspParam: 'FlameCusp',
      thermalDrift: 0.30,
      thermalDriftParam: 'ThermalDrift',
      tubeResonance: 0.50,
      tubeResonanceParam: 'TubeResonance',
    );

    const flameEnv = AdsrEnvNode(
      attack: 0.006,
      decay: 0.15,
      sustain: 0.85,
      release: 0.10,
    );

    const flameVca = GainNode(
      input: flameOsc,
      gainSource: flameEnv,
    );

    // 2. Turbulent Combustion Roar & Convective Draft
    const combustionRoar = CombustionRoarNode(
      roarLevel: 0.35,
      roarLevelParam: 'CombustionRoar',
      draftFlutter: 0.40,
      draftFlutterParam: 'OxygenDraft',
    );

    const roarVca = GainNode(
      input: combustionRoar,
      gainSource: flameEnv,
      staticGain: 0.75,
    );

    // 3. Supercritical Sap Explosions & Flying Ember Sizzle Matrix
    const sapCrackle = SapExplosionCrackleNode(
      sapDensity: 0.40,
      sapDensityParam: 'SapCrackle',
      emberSizzle: 0.35,
      emberSizzleParam: 'EmberSizzle',
    );

    // 4. Deflagration Flashover Ignition Whoosh (Attack) & Smoldering Tail (Release)
    const deflagrationSnap = DeflagrationExciterNode(
      snapLevel: 0.85,
      snapLevelParam: 'IgnitionSnap',
      smolderDecay: 0.08,
    );

    // 5. Sum all 4 physical acoustic combustion layers
    const fireMixer = MixerNode(
      [flameVca, roarVca, sapCrackle, deflagrationSnap],
      [0.75, 0.35, 0.30, 0.55],
    );

    // 6. Glass & Brass Rijke Draft Tube Formant Resonators
    // Formant 1: 950Hz Glass Cylinder Fundamental Peak
    const tubeFormant1 = BiquadFilterNode(
      input: fireMixer,
      type: BiquadType.peaking,
      frequency: 950.0,
      q: 3.2,
      gainDb: 4.0,
    );

    // Formant 2: 2.4kHz Air Intake Chimney Resonance
    const tubeFormant2 = BiquadFilterNode(
      input: tubeFormant1,
      type: BiquadType.peaking,
      frequency: 2400.0,
      q: 2.5,
      gainDb: 2.5,
    );

    // 7. Fuel Pressure Thermal Overdrive
    const fuelDrive = DistortionNode(
      input: tubeFormant2,
      drive: 1.15,
      driveParam: 'FuelPressure',
    );

    // 8. Thermal Chimney Convection Phaser (Acoustic vortex dispersion)
    const thermalPhaser = PhaserNode(
      input: fuelDrive,
      rate: 0.35,
      rateParam: 'PhaserRate',
      depth: 0.55,
      depthParam: 'PhaserDepth',
      feedback: 0.35,
      feedbackParam: 'PhaserFeedback',
      mix: 0.40,
      mixParam: 'PhaserMix',
      baseFreq: 600.0,
    );

    // 9. Chimney Draft Tone Highpass Low-Cut + Lowpass Filter
    const lowCutHp = BiquadFilterNode(
      input: thermalPhaser,
      type: BiquadType.highpass,
      frequency: 25.0,
      freqParam: 'ToneHighpass',
      q: 0.707,
    );

    const toneLp = BiquadFilterNode(
      input: lowCutHp,
      type: BiquadType.lowpass,
      frequency: 7500.0,
      freqParam: 'Tone',
      q: 0.707,
    );

    return const DistortionNode(
      input: toneLp,
      drive: 0.95,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  EATS WATER: HYDRAULOPHONE & FLUID PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Waterjet Hydraulophone & Fluid Cavitation Physical Model.
  /// Architecture:
  /// - Pressurized Waterjet & Minnaert Cavitation Oscillator (upward pinch chirp + fluid drift)
  /// - Hydrodynamic Vortex & Whirlpool Churn (submerged Brownian fluid eddies)
  /// - Droplet Splash & Surface Foam Matrix (Poisson bubble plinks & micro-spray)
  /// - Hydraulic Crown Plunge Impact (Attack) & Submerged Wake Sputter (Release)
  /// - Submerged Pool & Splash Acoustic Formants (650Hz & 2.1kHz peaks)
  /// - Fluid Flow Saturation & Hydrodynamic Whirlpool Phaser
  /// - Immersion Depth & Highpass Low-Cut Tone Filtering
  static GraphNode buildEatsWaterSynth() {
    // 1. Hydraulophone Waterjet & Minnaert Cavitation Oscillator
    const waterOsc = HydraulophoneOscNode(
      bubbleChirp: 0.45,
      bubbleChirpParam: 'BubblePinch',
      viscosity: 0.40,
      viscosityParam: 'Viscosity',
      currentDrift: 0.35,
      currentDriftParam: 'CurrentDrift',
    );

    const waterEnv = AdsrEnvNode(
      attack: 0.008,
      decay: 0.16,
      sustain: 0.88,
      release: 0.12,
    );

    const waterVca = GainNode(
      input: waterOsc,
      gainSource: waterEnv,
    );

    // 2. Hydrodynamic Vortex & Whirlpool Churn
    const vortexChurn = HydrodynamicVortexNode(
      vortexLevel: 0.35,
      vortexLevelParam: 'Turbulence',
      churnSpeed: 0.40,
      churnSpeedParam: 'WaterFlow',
    );

    const vortexVca = GainNode(
      input: vortexChurn,
      gainSource: waterEnv,
      staticGain: 0.75,
    );

    // 3. Droplet Splash & Surface Foam Matrix
    const dropletSplash = DropletSplashMatrixNode(
      dropletRate: 0.40,
      dropletRateParam: 'DropletRate',
      sprayHiss: 0.35,
      sprayHissParam: 'SprayHiss',
    );

    // 4. Hydraulic Crown Plunge Impact Transient
    const plungeImpact = PlungeImpactExciterNode(
      snapLevel: 0.85,
      snapLevelParam: 'PlungeImpact',
      wakeDecay: 0.09,
    );

    // 5. Sum all 4 physical acoustic fluid layers
    const fluidMixer = MixerNode(
      [waterVca, vortexVca, dropletSplash, plungeImpact],
      [0.75, 0.35, 0.35, 0.55],
    );

    // 6. Submerged Pool & Splash Cavity Acoustic Formants
    // Formant 1: 650Hz Submerged Pool Cavity Resonance
    const poolFormant1 = BiquadFilterNode(
      input: fluidMixer,
      type: BiquadType.peaking,
      frequency: 650.0,
      q: 2.8,
      gainDb: 4.0,
    );

    // Formant 2: 2.1kHz Splash Cavity Air Resonance
    const poolFormant2 = BiquadFilterNode(
      input: poolFormant1,
      type: BiquadType.peaking,
      frequency: 2100.0,
      q: 2.4,
      gainDb: 2.5,
    );

    // 7. Waterjet Flow Overdrive
    const flowDrive = DistortionNode(
      input: poolFormant2,
      drive: 1.12,
      driveParam: 'WaterFlow',
    );

    // 8. Hydrodynamic Whirlpool Phaser (Underwater Doppler wave refraction)
    const fluidPhaser = PhaserNode(
      input: flowDrive,
      rate: 0.28,
      rateParam: 'PhaserRate',
      depth: 0.60,
      depthParam: 'PhaserDepth',
      feedback: 0.45,
      feedbackParam: 'PhaserFeedback',
      mix: 0.45,
      mixParam: 'PhaserMix',
      baseFreq: 550.0,
    );

    // 9. Immersion Depth & Highpass Low-Cut Tone Filter
    const lowCutHp = BiquadFilterNode(
      input: fluidPhaser,
      type: BiquadType.highpass,
      frequency: 20.0,
      freqParam: 'ToneHighpass',
      q: 0.707,
    );

    const depthLp = BiquadFilterNode(
      input: lowCutHp,
      type: BiquadType.lowpass,
      frequency: 6500.0,
      freqParam: 'Depth',
      q: 0.707,
    );

    return const DistortionNode(
      input: depthLp,
      drive: 0.95,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  YAMAHA DX7 6-OPERATOR FM E-PIANO
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Yamaha DX7 6-Operator FM Electric Piano ("FullTines") Model
  /// Architecture:
  /// - 6-Operator FM Matrix with 32 routing algorithms (Default Alg 5: 3 independent 2-op stacks)
  /// - 4-stage Rate/Level exponential envelopes with velocity-to-modulation index scaling
  /// - Fundamental warm body stack + Glassy inharmonic bell tine stack (14:1 ratio) + Detuned air shimmer stack
  /// - Feedback loop on Operator 6
  /// - Vintage 12-bit DAC compander quantization emulation
  /// - Active 2-Band Preamp EQ (Bass Boost & Treble Bell Sparkle)
  /// - Stereo Shimmer Chorus
  static GraphNode buildDX7EPiano() {
    const dx7Core = DX7VoiceNode(
      algorithm: 5,
      algorithmParam: 'Algorithm',
      brightness: 1.0,
      brightnessParam: 'Brightness',
      tineBell: 0.85,
      tineBellParam: 'TineBell',
      bodyWarmth: 1.0,
      bodyWarmthParam: 'BodyWarmth',
      chorusMix: 0.35,
      chorusMixParam: 'ChorusMix',
      enable12BitDac: true,
    );

    const bassEq = BiquadFilterNode(
      input: dx7Core,
      type: BiquadType.lowshelf,
      frequency: 180.0,
      gainDb: 1.5,
      gainDbParam: 'BassBoost',
    );

    const trebleEq = BiquadFilterNode(
      input: bassEq,
      type: BiquadType.highshelf,
      frequency: 5000.0,
      gainDb: 2.5,
      gainDbParam: 'TrebleSparkle',
    );

    return const DistortionNode(
      input: trebleEq,
      drive: 1.0,
      driveParam: 'Drive',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  HOHNER CLAVINET D6 PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Hohner Clavinet D6 Electromechanical Physical Model
  /// Architecture:
  /// - Rubber-tipped hammer-on-metal anvil strike exciter
  /// - Taut steel string digital waveguide with rapid harmonic damping
  /// - Key-off yarn damper contact impulse thump
  /// - Dual single-coil electromagnetic pickups (Neck & Bridge) with comb filtering
  /// - Out-of-phase pickup selector ($A - B$) for hollow funk quack
  /// - Authentic 4-Rocker EQ Filter Matrix (Brilliant, Treble, Medium, Soft)
  /// - Vintage tube preamp overdrive / funk bite
  static GraphNode buildClavinetD6() {
    const hammer = HammerExciterNode(
      hardness: 1.4,
      hardnessParam: 'HammerHardness',
      clickLevel: 0.9,
      clickLevelParam: 'HammerSnap',
    );

    const stringWaveguide = WaveguideNode(
      exciter: hammer,
      feedback: 0.993,
      feedbackParam: 'Sustain',
      damping: 0.30,
      dampingParam: 'Damping',
    );

    const stringDecay = DecayEnvNode(
      decaySec: 0.95,
      decayParam: 'StringDecay',
    );

    const stringVca = GainNode(
      input: stringWaveguide,
      gainSource: stringDecay,
    );

    const damperThump = YarnDamperThumpNode(
      thumpLevel: 0.45,
      thumpLevelParam: 'DamperThump',
    );

    const clavMixer = MixerNode(
      [stringVca, hammer, damperThump],
      [0.90, 0.25, 0.30],
    );

    const pickupFilter = ClavinetPickupFilterNode(
      input: clavMixer,
      pickupSelect: 0.5,
      pickupSelectParam: 'PickupSelect',
      phaseInvert: 0.0,
      phaseInvertParam: 'PhaseInvert',
      brilliant: 1.0,
      brilliantParam: 'Brilliant',
      treble: 0.8,
      trebleParam: 'Treble',
      medium: 0.5,
      mediumParam: 'Medium',
      soft: 0.0,
      softParam: 'Soft',
    );

    return const DistortionNode(
      input: pickupFilter,
      drive: 1.08,
      driveParam: 'Drive',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  HARPSICHORD / CEMBALO PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Baroque Harpsichord (Cembalo) Physical Model
  /// Architecture:
  /// - Delrin/Crow Quill Plectrum Pluck Exciter (sharp step-impulse with micro-scrape)
  /// - Coupled Dual Waveguides for 8' Principal and 4' Octave / 8' Detuned registers
  /// - Velocity-invariance of amplitude with touch-sensitive pluck scratch dynamics
  /// - Spruce soundboard and Flemish/Italian wooden case modal cavity resonance bank
  /// - Buff / Lute felt damping stop
  /// - Key-release wooden jack fall and damper felt rattle transient
  static GraphNode buildHarpsichord() {
    const quillPluck = QuillPluckExciterNode(
      pluckBite: 1.45,
      pluckBiteParam: 'PluckBite',
      scrapeLevel: 0.40,
      scrapeLevelParam: 'ScrapeLevel',
    );

    // 8' Principal Register Waveguide
    const waveguide8 = WaveguideNode(
      exciter: quillPluck,
      feedback: 0.995,
      feedbackParam: 'Sustain',
      damping: 0.18,
      dampingParam: 'BuffStop',
    );

    // 4' Octave Register (Harmonic Sine layer driven by pluck)
    const octaveOsc = SawOscNode();
    const octaveDecay = DecayEnvNode(
      decaySec: 0.85,
      decayParam: 'OctaveDecay',
    );
    const octaveVca = GainNode(
      input: octaveOsc,
      gainSource: octaveDecay,
      staticGain: 0.35,
      gainParam: 'Stop4Octave',
    );

    // Soundboard Modal Resonator Bank (Baroque spruce cavity formants)
    const soundboardResonator = ModalResonatorBankNode(
      input: waveguide8,
      modeFreqRatios: [1.0, 1.84, 3.12, 4.88, 7.60],
      modeGains: [0.55, 0.40, 0.25, 0.18, 0.10],
      modeQFactors: [12.0, 22.0, 35.0, 45.0, 55.0],
    );

    const jackRelease = HarpsichordJackReleaseNode(
      releaseNoise: 0.35,
      releaseNoiseParam: 'JackRelease',
    );

    const harpsichordMixer = MixerNode(
      [waveguide8, soundboardResonator, octaveVca, jackRelease],
      [0.65, 0.45, 0.30, 0.25],
    );

    const highAir = BiquadFilterNode(
      input: harpsichordMixer,
      type: BiquadType.highshelf,
      frequency: 6000.0,
      gainDb: 2.0,
      gainDbParam: 'AirSparkle',
    );

    return const DistortionNode(
      input: highAir,
      drive: 0.98,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  ACOUSTIC BASS GUITAR PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Acoustic Bronze-Wound Bass Guitar Physical Model
  /// Architecture:
  /// - Soft fingertip flesh pluck exciter with subtle nail click
  /// - Heavy core bronze string waveguide ($E_1-G_2$ fundamental)
  /// - Dreadnought acoustic hollow body modal cavity resonator
  /// - Piezo under-saddle pickup & body mic blend tone stack
  static GraphNode buildAcousticBass() {
    const exciter = FleshPluckExciterNode(
      pluckForce: 1.30,
      pluckForceParam: 'PluckForce',
      nailClick: 0.35,
      nailClickParam: 'NailClick',
    );

    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.995,
      feedbackParam: 'Sustain',
      damping: 0.28,
      dampingParam: 'Damping',
    );

    const bodyResonator = ModalResonatorBankNode(
      input: waveguide,
      modeFreqRatios: [1.0, 1.62, 2.45, 3.80],
      modeGains: [0.60, 0.40, 0.25, 0.15],
      modeQFactors: [10.0, 18.0, 28.0, 40.0],
    );

    const mixer = MixerNode(
      [waveguide, bodyResonator, exciter],
      [0.75, 0.45, 0.20],
    );

    const toneEq = BiquadFilterNode(
      input: mixer,
      type: BiquadType.highshelf,
      frequency: 3800.0,
      gainDb: 1.5,
      gainDbParam: 'AcousticAir',
    );

    return const DistortionNode(
      input: toneEq,
      drive: 1.02,
      driveParam: 'Drive',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  FRETLESS ELECTRIC J-BASS PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Fretless Electric Bass Physical Model (Jaco "Mwah" & Bridge Bark)
  /// Architecture:
  /// - Fingertip pluck with smooth string boundary contact
  /// - Fretless "Mwah" blooming dynamic collision shaper + 2nd order growl
  /// - J-Bass dual single-coil magnetic pickup reluctance saturation
  /// - Active 1.6kHz peaking mid-boost bark & 2-band preamp EQ
  static GraphNode buildFretlessBass() {
    const exciter = FleshPluckExciterNode(
      pluckForce: 1.35,
      pluckForceParam: 'PluckAttack',
      nailClick: 0.20,
      nailClickParam: 'FingerFriction',
    );

    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.996,
      feedbackParam: 'Sustain',
      damping: 0.22,
      dampingParam: 'FingerDamping',
    );

    const mwah = FretlessMwahNode(
      input: waveguide,
      mwahAmount: 0.75,
      mwahAmountParam: 'MwahAmount',
      growl: 0.60,
      growlParam: 'Growl',
    );

    const pickup = PickupSaturationNode(
      input: mwah,
      distance: 0.90,
      distanceParam: 'BridgePickup',
      symmetry: 0.70,
      symmetryParam: 'PickupBark',
    );

    const midBark = BiquadFilterNode(
      input: pickup,
      type: BiquadType.peaking,
      frequency: 1600.0,
      gainDb: 3.5,
      gainDbParam: 'MidBark',
      q: 1.4,
    );

    return const DistortionNode(
      input: midBark,
      drive: 1.10,
      driveParam: 'Drive',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  UPRIGHT / DOUBLE BASS PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic 3/4 Acoustic Upright Double Bass Model (Jazz Pizzicato, Warm Gut String & Ebony Slap)
  /// Architecture:
  /// - Heavy gut string side-finger flesh displacement exciter + tactile fingerboard wood slap
  /// - Acoustic string waveguide with frequency-dependent gut damping (damping = 0.26)
  /// - 3/4 Double Bass carved spruce & maple modal body cavity resonator (58Hz air / 98Hz wood)
  /// - Natural body punch (+3.0 dB @ 160 Hz) & smooth woody treble softening
  static GraphNode buildUprightBass() {
    const exciter = UprightPluckSlapExciterNode(
      pluckMass: 2.2,
      pluckMassParam: 'FingerMass',
      slapClick: 0.35,
      slapClickParam: 'SlapClick',
    );

    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.9945,
      feedbackParam: 'Sustain',
      damping: 0.26, // Warm gut string damping that sustains 80-600Hz body resonance
      dampingParam: 'StringDamp',
    );

    const bodyResonator = ViolinFamilyBodyResonatorNode(
      input: waveguide,
      instrumentType: 3, // Double Bass body cavity (58Hz air, 98Hz wood top)
      instrumentTypeParam: 'BodyType',
      woodWarmth: 0.70,
      woodWarmthParam: 'BodyWarmth',
      conSordino: 0.0,
      conSordinoParam: 'ConSordino',
    );

    // Direct tactile exciter blend for natural acoustic fingerboard snap contact
    const mixer = MixerNode(
      [bodyResonator, exciter],
      [0.90, 0.25],
    );

    // Acoustic Wood Body Punch (+3.0 dB @ 160 Hz)
    const bodyPunch = BiquadFilterNode(
      input: mixer,
      type: BiquadType.peaking,
      frequency: 160.0,
      gainDb: 3.0,
      gainDbParam: 'BodyPunch',
      q: 1.2,
    );

    // Balanced Low-End Warmth (+1.5 dB @ 75 Hz, clean acoustic foundation without muddy sub-boom)
    const subWarmth = BiquadFilterNode(
      input: bodyPunch,
      type: BiquadType.lowshelf,
      frequency: 75.0,
      gainDb: 1.5,
      gainDbParam: 'SubWarmth',
    );

    // Smooth Woody Treble Softening (-3.5 dB @ 3.5 kHz)
    const woodTone = BiquadFilterNode(
      input: subWarmth,
      type: BiquadType.highshelf,
      frequency: 3500.0,
      gainDb: -3.5,
      gainDbParam: 'WoodTone',
    );

    return woodTone;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  MODEL D / ANALOG SUB SYNTH BASS
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic 4-Pole 24dB/oct Transistor Ladder Analog Sub Synth Bass
  /// Architecture:
  /// - Dual detuned Saw & Pulse oscillators + 1-octave down Sub-Oscillator
  /// - 4-Pole 24dB/oct Moog ladder lowpass filter with resonant feedback
  /// - Exponential filter contour envelope & saturation drive
  static GraphNode buildMoogSynthBass() {
    const saw = SawOscNode();
    const pulse = SquareOscNode(pulseWidth: 0.45);
    const subOsc = SquareOscNode(pulseWidth: 0.50);

    const oscMixer = MixerNode(
      [saw, pulse, subOsc],
      [0.65, 0.45, 0.55],
    );

    const ladder = MoogLadderFilterNode(
      input: oscMixer,
      cutoffHz: 350.0,
      cutoffParam: 'Cutoff',
      resonance: 0.65,
      resonanceParam: 'Resonance',
      envAmount: 0.65,
      envAmountParam: 'FilterEnv',
      envDecaySec: 0.40,
      envDecayParam: 'Decay',
    );

    const vcaEnv = DecayEnvNode(
      decaySec: 0.85,
      decayParam: 'AmpDecay',
    );

    const vca = GainNode(
      input: ladder,
      gainSource: vcaEnv,
    );

    return const DistortionNode(
      input: vca,
      drive: 1.25,
      driveParam: 'Drive',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  SPANISH / CLASSICAL NYLON GUITAR PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Spanish Concert Classical Guitar Physical Model
  /// Architecture:
  /// - Pluck Exciter with Flesh/Nail blend, scrape noise, and micro-strum
  /// - Nylon string digital waveguide with frequency-dependent loop damping
  /// - Spanish fan-braced acoustic body resonator (Helmholtz air 98Hz + Soundboard plate 196Hz)
  /// - Cedar / Spruce tone shaping filter stack
  static GraphNode buildSpanishGuitar() {
    const exciter = AcousticPluckExciterNode(
      fleshRatio: 0.40,
      fleshRatioParam: 'FleshNail',
      scrapeNoise: 0.35,
      scrapeNoiseParam: 'Scrape',
      strumSpreadMs: 4.0,
      strumSpreadParam: 'StrumSpread',
    );

    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.9955,
      feedbackParam: 'Sustain',
      damping: 0.24,
      dampingParam: 'BodyDamp',
    );

    // Fan-braced solid wood body modal resonances (Torres style)
    const bodyResonator = ModalResonatorBankNode(
      input: waveguide,
      modeFreqRatios: [1.0, 1.96, 2.45, 3.12], // Air cavity (~98Hz), Main Top (196Hz), Backplate (240Hz), Bridge rocking
      modeGains: [0.50, 0.38, 0.22, 0.14],
      modeQFactors: [16.0, 20.0, 18.0, 26.0],
    );

    const bodyMixer = MixerNode(
      [waveguide, bodyResonator],
      [0.80, 0.45],
    );

    // Warmth & Cedar / Spruce Body Tone Filter
    const woodTone = BiquadFilterNode(
      input: bodyMixer,
      type: BiquadType.peaking,
      frequency: 2200.0,
      gainDb: 1.5,
      gainDbParam: 'WoodTone',
      q: 1.2,
    );

    const airEq = BiquadFilterNode(
      input: woodTone,
      type: BiquadType.lowshelf,
      frequency: 110.0,
      gainDb: 2.0,
      gainDbParam: 'AirResonance',
    );

    return airEq;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  RENAISSANCE & BAROQUE LUTE PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Double-Course Gut Lute Physical Model
  /// Architecture:
  /// - Soft gut pluck exciter with delicate contact transient and light friction scrape
  /// - Coupled double-course twin waveguides with 3.5-cent micro-beating chorus and bridge coupling
  /// - Multi-ribbed vaulted bowl modal resonator (dense, airy mid-frequency distribution 300-1200Hz)
  /// - High string tension / gut decay curve
  static GraphNode buildRenaissanceLute() {
    const exciter = AcousticPluckExciterNode(
      fleshRatio: 0.70,
      fleshRatioParam: 'FleshRatio',
      scrapeNoise: 0.25,
      scrapeNoiseParam: 'GutScrape',
      strumSpreadMs: 5.0,
      strumSpreadParam: 'CourseSpread',
    );

    const coupledWaveguide = CoupledWaveguideNode(
      exciter: exciter,
      feedback: 0.993,
      feedbackParam: 'Sustain',
      damping: 0.20,
      dampingParam: 'GutDamp',
      courseDetuneCents: 3.8,
      courseDetuneParam: 'CourseDetune',
      coupling: 0.09,
      couplingParam: 'BridgeCoupling',
    );

    // Vaulted sycamore/yew rib bowl modal resonator
    const bowlResonator = ModalResonatorBankNode(
      input: coupledWaveguide,
      modeFreqRatios: [1.0, 1.62, 2.15, 2.80, 3.65, 4.35], // Diffuse, delicate bowl reflection modes
      modeGains: [0.32, 0.42, 0.36, 0.25, 0.18, 0.10],
      modeQFactors: [10.0, 14.0, 16.0, 18.0, 22.0, 25.0],
    );

    const luteMixer = MixerNode(
      [coupledWaveguide, bowlResonator],
      [0.82, 0.40],
    );

    // Delicate airy shimmer high-shelf
    const airShimmer = BiquadFilterNode(
      input: luteMixer,
      type: BiquadType.highshelf,
      frequency: 4500.0,
      gainDb: 1.8,
      gainDbParam: 'AirShimmer',
    );

    // Renaissance body warmth
    const bodyWarmth = BiquadFilterNode(
      input: airShimmer,
      type: BiquadType.peaking,
      frequency: 480.0,
      gainDb: 2.2,
      gainDbParam: 'BowlWarmth',
      q: 1.4,
    );

    return bodyWarmth;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  BAROQUE GUITAR (5-COURSE RE-ENTRANT) PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic 5-Course Re-Entrant Baroque Guitar Physical Model
  /// Architecture:
  /// - Rapid multi-finger rasgueado rake fan exciter with up/down stroke dynamics
  /// - Coupled double-course gut waveguides with octave bass pairing and micro-detuning
  /// - Shallow body modal resonator with ornate parchment rose soundhole aperture damping
  /// - Bright bell-like re-entrant chime filter stack
  static GraphNode buildBaroqueGuitar() {
    const exciter = AcousticPluckExciterNode(
      fleshRatio: 0.30,
      fleshRatioParam: 'NailPluck',
      scrapeNoise: 0.45,
      scrapeNoiseParam: 'GutScrape',
      strumSpreadMs: 12.0,
      strumSpreadParam: 'RasgueadoSpeed',
      numStrumTaps: 5,
    );

    const coupledWaveguide = CoupledWaveguideNode(
      exciter: exciter,
      feedback: 0.9935,
      feedbackParam: 'Sustain',
      damping: 0.18,
      dampingParam: 'StringDamp',
      courseDetuneCents: 4.5,
      courseDetuneParam: 'CourseDetune',
      octavePair: true, // Octave paired courses for authentic high chime
      octavePairParam: 'OctaveCourses',
      coupling: 0.10,
    );

    // Shallow waist body with parchment rosette resonance
    const bodyResonator = ModalResonatorBankNode(
      input: coupledWaveguide,
      modeFreqRatios: [1.0, 1.82, 2.65, 3.40],
      modeGains: [0.45, 0.40, 0.25, 0.16],
      modeQFactors: [14.0, 18.0, 20.0, 22.0],
    );

    const bodyMixer = MixerNode(
      [coupledWaveguide, bodyResonator],
      [0.85, 0.38],
    );

    // Parchment Rose Rosette Acoustic Damping
    const roseFilter = BiquadFilterNode(
      input: bodyMixer,
      type: BiquadType.peaking,
      frequency: 3200.0,
      gainDb: 3.0,
      gainDbParam: 'RoseBite',
      q: 1.5,
    );

    const chimeHighpass = BiquadFilterNode(
      input: roseFilter,
      type: BiquadType.highpass,
      frequency: 120.0, // Re-entrant tuning reduces heavy low fundamentals
    );

    return chimeHighpass;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  FLAMENCO GUITAR (GUITARRA FLAMENCA BLANCA / GOLPE) PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Flamenco Guitar Physical Model
  /// Architecture:
  /// - High-velocity nail attack exciter + Golpe soundboard tap generator
  /// - Snappy nylon/carbon waveguide with low-action string buzz & fast decay
  /// - Spanish cypress shallow body resonator (snappy, dry, percussive)
  /// - Explosive rasgueado response & aggressive upper bite
  static GraphNode buildFlamencoGuitar() {
    const exciter = AcousticPluckExciterNode(
      fleshRatio: 0.10, // Dominant fingernail bite
      fleshRatioParam: 'NailBite',
      scrapeNoise: 0.50,
      scrapeNoiseParam: 'Scrape',
      strumSpreadMs: 14.0,
      strumSpreadParam: 'RasgueadoSpeed',
      numStrumTaps: 5,
      golpeGain: 0.40,
      golpeGainParam: 'GolpeTap',
    );

    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.991, // Faster percussive decay
      feedbackParam: 'Sustain',
      damping: 0.28,
      dampingParam: 'SnapDamp',
    );

    // Cypress wood body (dry, fast response, low sustain, high percussive projection)
    const cypressBody = ModalResonatorBankNode(
      input: waveguide,
      modeFreqRatios: [1.0, 2.05, 2.70, 3.55],
      modeGains: [0.55, 0.42, 0.28, 0.15],
      modeQFactors: [12.0, 15.0, 18.0, 20.0], // Lower Q for fast percussive punch
    );

    const bodyMixer = MixerNode(
      [waveguide, cypressBody],
      [0.88, 0.42],
    );

    // Flamenco attack bite (3.8 kHz fingernail click)
    const biteEq = BiquadFilterNode(
      input: bodyMixer,
      type: BiquadType.peaking,
      frequency: 3800.0,
      gainDb: 3.5,
      gainDbParam: 'Bite',
      q: 1.8,
    );

    return biteEq;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  STEEL-STRING ACOUSTIC GUITAR (PARLOR / DREADNOUGHT / JUMBO)
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Steel-String Acoustic Guitar Physical Model
  /// Architecture:
  /// - Phosphor bronze & steel core waveguide with flatpick vs fingerpick attack
  /// - Morphable acoustic body resonator (0.0 Parlor <-> 0.5 Dreadnought <-> 1.0 Jumbo)
  /// - Acoustic soundboard X-bracing & dynamic air cavity boost
  static GraphNode buildSteelAcousticGuitar() {
    const exciter = AcousticPluckExciterNode(
      fleshRatio: 0.30,
      fleshRatioParam: 'PickStyle', // 0.0 Flatpick, 1.0 Fingerpick
      scrapeNoise: 0.40,
      scrapeNoiseParam: 'WoundScrape',
      strumSpreadMs: 5.0,
      strumSpreadParam: 'StrumSpread',
    );

    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.996,
      feedbackParam: 'Sustain',
      damping: 0.22,
      dampingParam: 'Damping',
    );

    const morphBody = MorphableAcousticBodyNode(
      input: waveguide,
      bodyProfile: 0.50, // Default to Dreadnought
      bodyProfileParam: 'BodyProfile',
      woodGain: 0.50,
      woodGainParam: 'BodyWood',
    );

    const bodyMixer = MixerNode(
      [waveguide, morphBody],
      [0.82, 0.48],
    );

    // Phosphor Bronze Presence & Top Air
    const airEq = BiquadFilterNode(
      input: bodyMixer,
      type: BiquadType.highshelf,
      frequency: 4200.0,
      gainDb: 2.0,
      gainDbParam: 'BronzeSparkle',
    );

    return airEq;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  12-STRING ACOUSTIC GUITAR PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic 12-String Acoustic Folk-Rock Guitar Physical Model
  /// Architecture:
  /// - Coupled double-course waveguides with high-octave pairing on courses 3-6
  /// - Organic 4.2-cent chorus micro-detuning & wide plectrum brush rake
  /// - Large dreadnought body modal cavity resonator
  static GraphNode buildTwelveStringGuitar() {
    const exciter = AcousticPluckExciterNode(
      fleshRatio: 0.15, // Crisp flatpick
      fleshRatioParam: 'PickBite',
      scrapeNoise: 0.45,
      scrapeNoiseParam: 'StringScrape',
      strumSpreadMs: 14.0,
      strumSpreadParam: 'StrumSpread',
      numStrumTaps: 6,
    );

    const coupledWaveguide = CoupledWaveguideNode(
      exciter: exciter,
      feedback: 0.995,
      feedbackParam: 'Sustain',
      damping: 0.20,
      dampingParam: 'Damping',
      courseDetuneCents: 4.2,
      courseDetuneParam: 'ChorusDetune',
      octavePair: true, // Octave paired courses for authentic 12-string chime
      octavePairParam: 'OctavePairing',
      coupling: 0.08,
    );

    const bodyResonator = ModalResonatorBankNode(
      input: coupledWaveguide,
      modeFreqRatios: [1.0, 1.92, 2.55, 3.25],
      modeGains: [0.55, 0.40, 0.25, 0.15],
      modeQFactors: [16.0, 20.0, 22.0, 26.0],
    );

    const mixer = MixerNode(
      [coupledWaveguide, bodyResonator],
      [0.85, 0.42],
    );

    const chimeEq = BiquadFilterNode(
      input: mixer,
      type: BiquadType.highshelf,
      frequency: 5000.0,
      gainDb: 3.0,
      gainDbParam: 'Chime',
    );

    return chimeEq;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  DOBRO / RESONATOR GUITAR PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Resonator / Dobro Guitar Physical Model
  /// Architecture:
  /// - Spun aluminum spider/biscuit mechanical cone resonator
  /// - Steel string waveguide with slide glissando & metallic bite
  /// - Strong nasal resonator formants (720Hz, 1450Hz, 2150Hz)
  static GraphNode buildDobroResonator() {
    const exciter = AcousticPluckExciterNode(
      fleshRatio: 0.10, // Hard thumbpick & metal fingerpicks
      fleshRatioParam: 'ThumbPick',
      scrapeNoise: 0.60,
      scrapeNoiseParam: 'SlideFriction',
      strumSpreadMs: 6.0,
      strumSpreadParam: 'StrumSpread',
    );

    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.994,
      feedbackParam: 'Sustain',
      damping: 0.18,
      dampingParam: 'Damping',
    );

    const aluminumCone = AluminumConeResonatorNode(
      input: waveguide,
      coneType: 0.35, // Spider bridge
      coneTypeParam: 'ConeType',
      metalBark: 0.60,
      metalBarkParam: 'MetalBark',
    );

    const mixer = MixerNode(
      [waveguide, aluminumCone],
      [0.65, 0.70],
    );

    const slideTone = BiquadFilterNode(
      input: mixer,
      type: BiquadType.peaking,
      frequency: 1800.0,
      gainDb: 3.5,
      gainDbParam: 'SlideTone',
      q: 1.5,
    );

    return slideTone;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  PEDAL STEEL & LAP STEEL GUITAR PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Pedal Steel & Lap Steel Guitar Physical Model
  /// Architecture:
  /// - Continuous microtonal glide tracking + volume swell pedal dynamics
  /// - Single-coil magnetic pickup reluctance saturation + warm tube preamp
  /// - Long singing sustain with 5.2Hz bar vibrato
  static GraphNode buildPedalSteelGuitar() {
    const exciter = AcousticPluckExciterNode(
      fleshRatio: 0.15,
      scrapeNoise: 0.20,
      strumSpreadMs: 4.0,
    );

    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.9975, // Long singing sustain
      feedbackParam: 'Sustain',
      damping: 0.14,
      dampingParam: 'StringDamp',
    );

    const pickup = PickupSaturationNode(
      input: waveguide,
      distance: 0.85,
      distanceParam: 'PickupBark',
      symmetry: 0.55,
    );

    const swellNode = VolumePedalSwellNode(
      input: pickup,
      swellSec: 0.14,
      swellSecParam: 'VolumeSwell',
      barVibrato: 0.40,
      barVibratoParam: 'BarVibrato',
    );

    const ampTone = BiquadFilterNode(
      input: swellNode,
      type: BiquadType.peaking,
      frequency: 2400.0,
      gainDb: 2.5,
      gainDbParam: 'AmpPresence',
      q: 1.2,
    );

    return DistortionNode(
      input: ampTone,
      drive: 1.08,
      driveParam: 'Drive',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  HARP GUITAR (SUB-BASS DRONES + FRETTED NECK) PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Acoustic Harp Guitar Physical Model
  /// Architecture:
  /// - Standard 6-string fretboard coupled with floating sub-bass diapasons
  /// - Extra-large acoustic body modal cavity with sympathetic cross-string ring
  static GraphNode buildHarpGuitar() {
    const exciter = AcousticPluckExciterNode(
      fleshRatio: 0.35,
      fleshRatioParam: 'PickStyle',
      scrapeNoise: 0.35,
      strumSpreadMs: 5.0,
    );

    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.9965,
      feedbackParam: 'Sustain',
      damping: 0.20,
      dampingParam: 'Damping',
    );

    // Large chamber modal resonator (deep sub-bass extension)
    const bodyResonator = ModalResonatorBankNode(
      input: waveguide,
      modeFreqRatios: [0.65, 1.0, 1.75, 2.60], // Sub-drone coupling at 0.65x
      modeGains: [0.60, 0.45, 0.30, 0.18],
      modeQFactors: [18.0, 22.0, 25.0, 30.0],
    );

    const mixer = MixerNode(
      [waveguide, bodyResonator],
      [0.80, 0.50],
    );

    const subDroneEq = BiquadFilterNode(
      input: mixer,
      type: BiquadType.lowshelf,
      frequency: 75.0,
      gainDb: 3.5,
      gainDbParam: 'SubDroneGain',
    );

    return subDroneEq;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  5-STRING BLUEGRASS BANJO PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic 5-String Bluegrass Banjo Physical Model
  /// Architecture:
  /// - Mylar/calfskin membrane drumhead impulse exciter with tight tension snap
  /// - Fast percussive decay steel string waveguide with brass tone ring bite
  /// - Resonator back chamber acoustic punch (1.8 kHz - 3.5 kHz twang)
  static GraphNode buildBluegrassBanjo() {
    const exciter = MembraneHeadExciterNode(
      headTension: 0.80,
      headTensionParam: 'HeadTension',
      twangSnap: 1.3,
      twangSnapParam: 'TwangSnap',
    );

    const waveguide = WaveguideNode(
      exciter: exciter,
      feedback: 0.988, // Characteristic rapid banjo decay
      feedbackParam: 'Sustain',
      damping: 0.35,
      dampingParam: 'ToneRingDamp',
    );

    const toneRing = ModalResonatorBankNode(
      input: waveguide,
      modeFreqRatios: [1.0, 2.15, 3.30],
      modeGains: [0.60, 0.45, 0.28],
      modeQFactors: [14.0, 20.0, 28.0],
    );

    const mixer = MixerNode(
      [waveguide, toneRing],
      [0.85, 0.45],
    );

    const twangEq = BiquadFilterNode(
      input: mixer,
      type: BiquadType.peaking,
      frequency: 2800.0,
      gainDb: 4.5,
      gainDbParam: 'TwangBite',
      q: 1.8,
    );

    return twangEq;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  FOLK MANDOLIN (DOUBLE-COURSE STEEL) PHYSICAL MODEL
  // ───────────────────────────────────────────────────────────────────────────

  /// Authentic Double-Course Folk Mandolin Physical Model
  /// Architecture:
  /// - 8 steel strings in 4 paired double courses with 3.2-cent micro-chorus
  /// - Carved arched spruce soundboard with f-hole projection
  /// - Rapid alternate-picking / tremolo transient response
  static GraphNode buildFolkMandolin() {
    const exciter = AcousticPluckExciterNode(
      fleshRatio: 0.05, // Stiff heavy plectrum
      fleshRatioParam: 'PickBite',
      scrapeNoise: 0.30,
      strumSpreadMs: 4.0,
      strumSpreadParam: 'TremoloSpeed',
    );

    const coupledWaveguide = CoupledWaveguideNode(
      exciter: exciter,
      feedback: 0.993,
      feedbackParam: 'Sustain',
      damping: 0.22,
      dampingParam: 'Damping',
      courseDetuneCents: 3.2,
      courseDetuneParam: 'CourseDetune',
      coupling: 0.10,
    );

    const archedTop = ModalResonatorBankNode(
      input: coupledWaveguide,
      modeFreqRatios: [1.0, 1.88, 2.85],
      modeGains: [0.55, 0.38, 0.22],
      modeQFactors: [16.0, 22.0, 30.0],
    );

    const mixer = MixerNode(
      [coupledWaveguide, archedTop],
      [0.85, 0.42],
    );

    const presenceEq = BiquadFilterNode(
      input: mixer,
      type: BiquadType.peaking,
      frequency: 3500.0,
      gainDb: 3.0,
      gainDbParam: 'MandolinBite',
      q: 1.4,
    );

    return presenceEq;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  BOWED STRING FAMILY PHYSICAL MODELS (Violin, Viola, Cello, Bass, Ensemble)
  // ───────────────────────────────────────────────────────────────────────────

  /// Virtuoso Solo Violin Physical Model
  /// Architecture:
  /// - Bow friction exciter with smooth stick-slip MSW dynamics
  /// - Bowed string waveguide with calibrated gut/steel damping (damping = 0.20) & delayed vibrato (5.4Hz)
  /// - Stradivarius modal soundboard resonator (woodWarmth = 0.68)
  /// - 3-Stage Luthier EQ: 480Hz acoustic wood core + 2.8kHz singing bridge presence + 6.0kHz soprano air sheen
  static GraphNode buildSoloViolin() {
    const exciter = BowedFrictionExciterNode(
      bowPressure: 1.05,
      bowPressureParam: 'BowPressure',
      bowSpeed: 0.98,
      bowSpeedParam: 'BowSpeed',
      bowPosition: 0.50,
      bowPositionParam: 'BowPos',
      rosinGrit: 0.32,
      rosinGritParam: 'RosinGrit',
      tremoloSpeed: 13.0,
      tremoloSpeedParam: 'TremoloSpeed',
    );

    const waveguide = BowedStringWaveguideNode(
      exciter: exciter,
      sustain: 0.9962,
      sustainParam: 'Sustain',
      stringDamping: 0.20, // Organic gut/steel internal loss (shares viola warmth, avoids digital buzz)
      stringDampingParam: 'Damping',
      vibratoDepth: 0.30,
      vibratoDepthParam: 'VibratoDepth',
      vibratoRate: 5.4,
      vibratoRateParam: 'VibratoRate',
      vibratoDelaySec: 0.15,
      vibratoDelayParam: 'VibratoDelay',
    );

    const bodyResonator = ViolinFamilyBodyResonatorNode(
      input: waveguide,
      instrumentType: 0, // Violin modal plates (280Hz air, 480Hz top, 580Hz ring, 3.1kHz bridge hill)
      instrumentTypeParam: 'BodyType',
      woodWarmth: 0.68,
      woodWarmthParam: 'WoodWarmth',
      conSordino: 0.0,
      conSordinoParam: 'ConSordino',
    );

    // Stage 1: Warm Wood Core (+2.5 dB @ 480 Hz) - preserves acoustic wood body
    const bodyCore = BiquadFilterNode(
      input: bodyResonator,
      type: BiquadType.peaking,
      frequency: 480.0,
      gainDb: 2.5,
      gainDbParam: 'ViolinCore',
      q: 1.2,
    );

    // Stage 2: Singing Soprano Bridge Presence (+3.0 dB @ 2.8 kHz) - gives singing lead projection
    const bridgeHill = BiquadFilterNode(
      input: bodyCore,
      type: BiquadType.peaking,
      frequency: 2800.0,
      gainDb: 3.0,
      gainDbParam: 'BridgeHill',
      q: 1.3,
    );

    // Stage 3: Soprano Air Sheen (+1.8 dB @ 6.0 kHz) - high-end shimmer in contrast to Viola's treble cut
    const airSheen = BiquadFilterNode(
      input: bridgeHill,
      type: BiquadType.highshelf,
      frequency: 6000.0,
      gainDb: 1.8,
      gainDbParam: 'AirSheen',
      q: 0.7,
    );

    return airSheen;
  }

  /// Warm Solo Viola Physical Model
  /// Architecture:
  /// - Bow friction exciter tailored to heavier gut/steel C3-A6 strings
  /// - Resonator configured for slightly undersized viola acoustic cavity (signature melancholic nasal warmth)
  /// - 1.45kHz reedy nasal formant peak + 220Hz air resonance + upper treble darkening
  static GraphNode buildSoloViola() {
    const exciter = BowedFrictionExciterNode(
      bowPressure: 1.05,
      bowPressureParam: 'BowPressure',
      bowSpeed: 0.95,
      bowSpeedParam: 'BowSpeed',
      bowPosition: 0.48,
      bowPositionParam: 'BowPos',
      rosinGrit: 0.35,
      rosinGritParam: 'RosinGrit',
      tremoloSpeed: 12.5,
      tremoloSpeedParam: 'TremoloSpeed',
    );

    const waveguide = BowedStringWaveguideNode(
      exciter: exciter,
      sustain: 0.9960,
      sustainParam: 'Sustain',
      stringDamping: 0.22,
      stringDampingParam: 'Damping',
      vibratoDepth: 0.28,
      vibratoDepthParam: 'VibratoDepth',
      vibratoRate: 5.1,
      vibratoRateParam: 'VibratoRate',
      vibratoDelaySec: 0.16,
      vibratoDelayParam: 'VibratoDelay',
    );

    const bodyResonator = ViolinFamilyBodyResonatorNode(
      input: waveguide,
      instrumentType: 1, // Viola (1.45kHz reedy nasal formant peak)
      instrumentTypeParam: 'BodyType',
      woodWarmth: 0.65,
      woodWarmthParam: 'WoodWarmth',
      conSordino: 0.0,
      conSordinoParam: 'ConSordino',
    );

    // Viola Signature 1.45kHz Reedy/Nasal Formant Boost
    const nasalEq = BiquadFilterNode(
      input: bodyResonator,
      type: BiquadType.peaking,
      frequency: 1450.0,
      gainDb: 3.8,
      gainDbParam: 'ViolaNasal',
      q: 1.5,
    );

    // Darker Wood Treble Softening (-3.0 dB @ 4.5 kHz)
    const violaTone = BiquadFilterNode(
      input: nasalEq,
      type: BiquadType.highshelf,
      frequency: 4500.0,
      gainDb: -3.0,
      gainDbParam: 'ViolaWood',
      q: 0.8,
    );

    return violaTone;
  }

  /// Deep Solo Cello (Violoncello) Physical Model
  /// Architecture:
  /// - Heavy string bow friction exciter with C2-C6 fundamental response
  /// - Massive air cavity (98Hz), deep chest bloom (220Hz), and singing tenor formant (1.2kHz)
  /// - Singing tenor range and C-string sub-growl
  static GraphNode buildSoloCello() {
    const exciter = BowedFrictionExciterNode(
      bowPressure: 1.20,
      bowPressureParam: 'BowPressure',
      bowSpeed: 0.90,
      bowSpeedParam: 'BowSpeed',
      bowPosition: 0.45,
      bowPositionParam: 'BowPos',
      rosinGrit: 0.42,
      rosinGritParam: 'RosinGrit',
      tremoloSpeed: 11.5,
      tremoloSpeedParam: 'TremoloSpeed',
    );

    const waveguide = BowedStringWaveguideNode(
      exciter: exciter,
      sustain: 0.9970,
      sustainParam: 'Sustain',
      stringDamping: 0.26,
      stringDampingParam: 'Damping',
      vibratoDepth: 0.32,
      vibratoDepthParam: 'VibratoDepth',
      vibratoRate: 4.8,
      vibratoRateParam: 'VibratoRate',
      vibratoDelaySec: 0.18,
      vibratoDelayParam: 'VibratoDelay',
    );

    const bodyResonator = ViolinFamilyBodyResonatorNode(
      input: waveguide,
      instrumentType: 2, // Cello (98Hz/180Hz/280Hz/420Hz/1200Hz)
      instrumentTypeParam: 'BodyType',
      woodWarmth: 0.72,
      woodWarmthParam: 'WoodWarmth',
      conSordino: 0.0,
      conSordinoParam: 'ConSordino',
    );

    // Cello Chest Resonance Bloom (+3.5 dB @ 220 Hz)
    const chestBloom = BiquadFilterNode(
      input: bodyResonator,
      type: BiquadType.peaking,
      frequency: 220.0,
      gainDb: 3.5,
      gainDbParam: 'ChestBloom',
      q: 1.1,
    );

    // Singing Cello Tenor Presence (+2.8 dB @ 1.2 kHz)
    const tenorSinging = BiquadFilterNode(
      input: chestBloom,
      type: BiquadType.peaking,
      frequency: 1200.0,
      gainDb: 2.8,
      gainDbParam: 'TenorSinging',
      q: 1.3,
    );

    return tenorSinging;
  }

  /// Orchestral Double Bass (Contrabass) Physical Model
  /// Architecture:
  /// - Giant wound steel string bow friction with heavy rosin bite
  /// - Sub-bass acoustic cavity (58Hz) and huge soundboard plate (98Hz)
  /// - Tight low-end punch (+1.5 dB @ 75Hz) without muddy sub-boom
  static GraphNode buildDoubleBass() {
    const exciter = BowedFrictionExciterNode(
      bowPressure: 1.40,
      bowPressureParam: 'BowPressure',
      bowSpeed: 0.82,
      bowSpeedParam: 'BowSpeed',
      bowPosition: 0.40,
      bowPositionParam: 'BowPos',
      rosinGrit: 0.55,
      rosinGritParam: 'RosinGrit',
      tremoloSpeed: 9.5,
      tremoloSpeedParam: 'TremoloSpeed',
    );

    const waveguide = BowedStringWaveguideNode(
      exciter: exciter,
      sustain: 0.9976,
      sustainParam: 'Sustain',
      stringDamping: 0.28,
      stringDampingParam: 'Damping',
      vibratoDepth: 0.22,
      vibratoDepthParam: 'VibratoDepth',
      vibratoRate: 4.2,
      vibratoRateParam: 'VibratoRate',
      vibratoDelaySec: 0.22,
      vibratoDelayParam: 'VibratoDelay',
    );

    const bodyResonator = ViolinFamilyBodyResonatorNode(
      input: waveguide,
      instrumentType: 3, // Double Bass (58Hz/98Hz/160Hz/280Hz)
      instrumentTypeParam: 'BodyType',
      woodWarmth: 0.75,
      woodWarmthParam: 'WoodWarmth',
      conSordino: 0.0,
      conSordinoParam: 'ConSordino',
    );

    // Natural Acoustic Low-End Foundation (+1.5 dB @ 75 Hz)
    const subBassPunch = BiquadFilterNode(
      input: bodyResonator,
      type: BiquadType.lowshelf,
      frequency: 75.0,
      gainDb: 1.5,
      gainDbParam: 'SubPunch',
      q: 0.8,
    );

    // Woody Body Punch (+3.0 dB @ 160 Hz)
    const woodPunch = BiquadFilterNode(
      input: subBassPunch,
      type: BiquadType.peaking,
      frequency: 160.0,
      gainDb: 3.0,
      gainDbParam: 'WoodPunch',
      q: 1.2,
    );

    return woodPunch;
  }

  /// Symphonic String Ensemble (Chamber / Tutti Strings) Physical Model
  /// Architecture:
  /// - Multi-string coupled waveguide cluster with organic micro-detuning & spatial chorusing
  /// - Full orchestral soundboard resonance & lush unison shimmer
  /// - Calibrated master gain (0.42) for level parity with solo instruments & headroom for chords
  static GraphNode buildStringEnsemble() {
    const exciter = BowedFrictionExciterNode(
      bowPressure: 1.05,
      bowPressureParam: 'BowPressure',
      bowSpeed: 1.0,
      bowSpeedParam: 'BowSpeed',
      bowPosition: 0.50,
      bowPositionParam: 'BowPos',
      rosinGrit: 0.30,
      rosinGritParam: 'RosinGrit',
      tremoloSpeed: 13.0,
      tremoloSpeedParam: 'TremoloSpeed',
    );

    const coupledEnsemble = CoupledWaveguideNode(
      exciter: exciter,
      feedback: 0.9968,
      feedbackParam: 'Sustain',
      damping: 0.16,
      dampingParam: 'Damping',
      courseDetuneCents: 4.2,
      courseDetuneParam: 'EnsembleChorus',
      coupling: 0.12,
    );

    const bodyResonator = ViolinFamilyBodyResonatorNode(
      input: coupledEnsemble,
      instrumentType: 0, // Master String Section Body
      instrumentTypeParam: 'BodyType',
      woodWarmth: 0.65,
      woodWarmthParam: 'WoodWarmth',
      conSordino: 0.0,
      conSordinoParam: 'ConSordino',
    );

    const airPresence = BiquadFilterNode(
      input: bodyResonator,
      type: BiquadType.highshelf,
      frequency: 6000.0,
      gainDb: 2.0,
      gainDbParam: 'AirSheen',
      q: 0.7,
    );

    // Calibrate ensemble output level to match solo instruments and prevent mixer peaking on chords
    const ensembleGain = GainNode(
      input: airPresence,
      staticGain: 0.18,
      gainParam: 'EnsembleGain',
    );

    return ensembleGain;
  }
}












