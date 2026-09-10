import 'dart:math' as math;
import 'dart:typed_data';

import '../graph/graph_evaluator.dart';
import '../graph/graph_node.dart';
import '../graph/graph_primitives.dart';
import '../poly_synth.dart';
import '../../eatscript/eat_script_library.dart';
import '../../eatscript/eat_script_engine.dart';

/// Pure-Dart DSP Synthesis Engine for the General MIDI Standard Drum Kit (Notes 35–81).
///
/// Implements authentic physical and modal synthesis:
/// - Membranophones: Dual-mic swept FM carrier + shell resonance (Kicks, Snares, 6 Toms).
/// - Inharmonic Metallic Clusters: Multi-oscillator ring + sizzle wash (Hats, Crashes, Rides, Bells).
/// - Wood & Transients: Resonant impulse shockwaves (Side Stick, Claves, Wood Blocks, Clap).
/// - Latin Percussion: High-slap FM transients + barrel resonance (Bongos, Congas, Timbales).
/// - Tuned FM Idiophones: Non-integer carrier-modulator pairs (Cowbell, Agogos, Triangles).
/// - Stochastic & Scrapers: Shaped noise jitter & ratchet modulators (Shakers, Cabasa, Guiro, Cuica).
class GmDrumKitEngine {
  static final Map<String, Map<int, String>> _slotOverridesByTrack = {};
  static final Map<String, int> _lastChokedNoteByTrack = {};
  static final Map<String, double> _lastChokedTimeByTrack = {};

  static int _rndSeed = 0x1A2B3C4D;
  static double _fastRnd() {
    _rndSeed = (_rndSeed * 1103515245 + 12345) & 0x7FFFFFFF;
    return (_rndSeed / 2147483647.0) * 2.0 - 1.0;
  }

  /// Sets a custom slot override for a specific [midiNote] on a given [trackId].
  /// E.g. overriding Note 36 with 'analog_808_kick' or 'analog_909_snare'.
  static void setSlotOverride(String trackId, int midiNote, String presetId) {
    _slotOverridesByTrack.putIfAbsent(trackId, () => {})[midiNote] = presetId;
  }

  /// Gets the current slot override for a given [midiNote] on [trackId], or null if default.
  static String? getSlotOverride(String trackId, int midiNote) {
    return _slotOverridesByTrack[trackId]?[midiNote];
  }

  /// Clears slot overrides for [trackId], or all tracks if [trackId] is null.
  static void clearSlotOverrides([String? trackId]) {
    if (trackId != null) {
      _slotOverridesByTrack.remove(trackId);
    } else {
      _slotOverridesByTrack.clear();
    }
  }

  /// Resets voice states (including choke state) for transitions or stops.
  static void resetVoiceStates([String? trackId]) {
    if (trackId != null) {
      _lastChokedNoteByTrack.remove(trackId);
      _lastChokedTimeByTrack.remove(trackId);
    } else {
      _lastChokedNoteByTrack.clear();
      _lastChokedTimeByTrack.clear();
    }
  }

  /// Synthesizes an audio buffer for a GM drum note (35–81).
  static Float32List synthesizeBuffer({
    required int note,
    required double durationSec,
    required double velocity,
    required Map<String, double> params,
    double sampleRate = 44100.0,
    bool isAccent = false,
    String? trackId,
  }) {
    // 1. Check for custom pad slot override (e.g. user dragged an 808/909 onto a pad)
    if (trackId != null) {
      final overridePreset = _slotOverridesByTrack[trackId]?[note];
      if (overridePreset != null) {
        final overrideBuffer = _evaluateOverridePreset(
          overridePreset,
          durationSec: durationSec,
          velocity: velocity,
          params: params,
          sampleRate: sampleRate,
          isAccent: isAccent,
          note: note,
        );
        if (overrideBuffer != null) return overrideBuffer;
      }
    }

    // 2. Physical Parameter Variation (The "Living Kit" humanizer)
    final double strikeDrift = (params['StrikeDrift'] ?? 0.20).clamp(0.0, 1.0);
    final double humanize = (params['Humanize'] ?? 0.25).clamp(0.0, 1.0);
    final double dynamics = (params['Dynamics'] ?? 0.75).clamp(0.0, 1.0);

    // Dynamic velocity response (non-linear impact scaling)
    final double effVelocity = (math.pow(velocity.clamp(0.05, 1.0), 1.0 + (1.0 - dynamics) * 0.5) *
        (1.0 + _fastRnd() * 0.06 * humanize)).clamp(0.05, 1.2);

    // Micro-pitch & decay jitter
    final double pitchJitter = 1.0 + (_fastRnd() * 0.03 * strikeDrift);
    final double decayJitter = 1.0 + (_fastRnd() * 0.06 * strikeDrift);

    // 3. Build & evaluate note-specific physical DSP graph
    final GraphNode rootNode = _resolveGmDrumGraph(
      note,
      params,
      effVelocity,
      pitchJitter,
      decayJitter,
      strikeDrift,
    );

    // Calculate clamped duration based on instrument decay
    final double naturalDecay = _getNaturalDurationForNote(note, params) * decayJitter;
    final double targetDuration = math.min(durationSec, naturalDecay);

    final buffer = GraphEvaluator.evaluate(
      root: rootNode,
      durationSec: targetDuration,
      freq: 440.0,
      note: note,
      params: params,
      sampleRate: sampleRate,
      velocity: effVelocity,
      isAccent: isAccent,
    );

    // 4. Master Bus Processing (Room Delay & Saturation)
    _applyMasterKitProcessing(buffer, params, sampleRate);

    // 5. Enforce GM Choke Groups (e.g. Note 42 / 44 chokes ringing 46)
    if (trackId != null) {
      _handleChokeGroups(trackId, note, targetDuration);
    }

    return buffer;
  }

  /// Maps GM Note Numbers (35–81) to physical modular DSP graph trees.
  static GraphNode _resolveGmDrumGraph(
    int note,
    Map<String, double> params,
    double velocity,
    double pitchJitter,
    double decayJitter,
    double strikeDrift,
  ) {
    switch (note) {
      // ─────────────────────────────────────────────────────────────────────
      // BASS DRUMS
      // ─────────────────────────────────────────────────────────────────────
      case 35: // Acoustic Bass Drum (Deeper, warmer, rounder room tone)
        return _buildAcousticBassDrum(
          startPitch: 160.0 * pitchJitter,
          endPitch: 48.0 * pitchJitter,
          pitchDecay: 0.085,
          fmDepth: 450.0 * velocity,
          ampDecay: 0.38 * decayJitter,
          subGain: 5.0,
          roomLevel: 0.40,
        );

      case 36: // Bass Drum 1 (Modern studio punch, tighter beater click)
      default:
        if (note < 35) {
          return _buildAcousticBassDrum(
            startPitch: 180.0 * pitchJitter,
            endPitch: 52.0 * pitchJitter,
            pitchDecay: 0.07,
            fmDepth: 600.0 * velocity,
            ampDecay: 0.28 * decayJitter,
            subGain: 4.0,
            roomLevel: 0.35,
          );
        }
        if (note == 36) {
          return _buildAcousticBassDrum(
            startPitch: 185.0 * pitchJitter,
            endPitch: 54.0 * pitchJitter,
            pitchDecay: 0.065,
            fmDepth: 650.0 * velocity,
            ampDecay: 0.26 * decayJitter,
            subGain: 4.5,
            roomLevel: 0.30,
          );
        }
        break;
    }

    // ───────────────────────────────────────────────────────────────────────
    // SNARES, RIMSHOT & CLAP
    // ───────────────────────────────────────────────────────────────────────
    if (note == 37) {
      // Side Stick / Rimshot (High-Q resonant wood transient + shell knock)
      return _buildSideStick(pitchJitter, decayJitter);
    } else if (note == 38) {
      // Acoustic Snare (Dual-shell swept sine + filtered snare wires)
      return _buildAcousticSnare(
        bodyPitchStart: 230.0 * pitchJitter,
        bodyPitchEnd: 180.0 * pitchJitter,
        bodyDecay: 0.16 * decayJitter,
        wireCutoff: (1800.0 + (velocity * 600.0) + (_fastRnd() * 100.0 * strikeDrift)).clamp(800.0, 5000.0),
        wireDecay: 0.24 * decayJitter,
        snappy: (0.65 + velocity * 0.2).clamp(0.2, 1.0),
        drive: 1.25,
      );
    } else if (note == 39) {
      // Hand Clap (Multi-burst transient cluster + diffuse tail)
      return _buildHandClap(decayJitter);
    } else if (note == 40) {
      // Electric Snare (Sharper transient, brighter wires, electronic gate)
      return _buildAcousticSnare(
        bodyPitchStart: 280.0 * pitchJitter,
        bodyPitchEnd: 210.0 * pitchJitter,
        bodyDecay: 0.12 * decayJitter,
        wireCutoff: 2800.0,
        wireDecay: 0.18 * decayJitter,
        snappy: 0.85,
        drive: 1.4,
      );
    }

    // ───────────────────────────────────────────────────────────────────────
    // HI-HATS
    // ───────────────────────────────────────────────────────────────────────
    if (note == 42) {
      // Closed Hi-Hat (Crisp stick contact + tight inharmonic metal ring)
      return _buildHiHat(
        decaySec: 0.07 * decayJitter,
        cutoffHz: 7500.0,
        sizzleDb: 4.0,
        clusterSpread: 1.0 * pitchJitter,
      );
    } else if (note == 44) {
      // Pedal Hi-Hat (Muffled, softer stick, chuffing foot pedal close)
      return _buildHiHat(
        decaySec: 0.05 * decayJitter,
        cutoffHz: 5500.0,
        sizzleDb: 1.5,
        clusterSpread: 0.9 * pitchJitter,
      );
    } else if (note == 46) {
      // Open Hi-Hat (Full sizzle wash, prolonged decay)
      return _buildHiHat(
        decaySec: 0.55 * decayJitter,
        cutoffHz: 6800.0,
        sizzleDb: 5.0,
        clusterSpread: 1.0 * pitchJitter,
      );
    }

    // ───────────────────────────────────────────────────────────────────────
    // TOMS (Low Floor -> High Rack)
    // ───────────────────────────────────────────────────────────────────────
    if (note == 41 || note == 43 || note == 45 || note == 47 || note == 48 || note == 50) {
      final double tomFreq;
      final double tomStartFreq;
      switch (note) {
        case 41: // Low Floor Tom
          tomFreq = 75.0;
          tomStartFreq = 120.0;
          break;
        case 43: // High Floor Tom
          tomFreq = 95.0;
          tomStartFreq = 150.0;
          break;
        case 45: // Low Tom
          tomFreq = 115.0;
          tomStartFreq = 180.0;
          break;
        case 47: // Low-Mid Tom
          tomFreq = 135.0;
          tomStartFreq = 210.0;
          break;
        case 48: // Hi-Mid Tom
          tomFreq = 155.0;
          tomStartFreq = 240.0;
          break;
        case 50: // High Tom
        default:
          tomFreq = 185.0;
          tomStartFreq = 280.0;
          break;
      }
      return _buildAcousticTom(
        startPitch: tomStartFreq * pitchJitter,
        endPitch: tomFreq * pitchJitter,
        pitchDecay: 0.11,
        ampDecay: (0.42 + (50 - note) * 0.02) * decayJitter,
        stickFm: 320.0 * velocity,
      );
    }

    // ───────────────────────────────────────────────────────────────────────
    // CYMBALS & BELLS
    // ───────────────────────────────────────────────────────────────────────
    if (note == 49 || note == 57) {
      // Crash Cymbal 1 (49) & Crash Cymbal 2 (57, higher pitch/shorter)
      final double mult = note == 49 ? 1.0 : 1.18;
      return _buildCrashCymbal(mult * pitchJitter, decayJitter);
    } else if (note == 51 || note == 59) {
      // Ride Cymbal 1 (51) & Ride Cymbal 2 (59)
      final double mult = note == 51 ? 1.0 : 1.12;
      return _buildRideCymbal(mult * pitchJitter, decayJitter, isBell: false);
    } else if (note == 53) {
      // Ride Bell (Prominent ping harmonic dome)
      return _buildRideCymbal(1.35 * pitchJitter, decayJitter, isBell: true);
    } else if (note == 52) {
      // Chinese Cymbal (Trashy, aggressive inharmonic crash)
      return _buildChinaCymbal(pitchJitter, decayJitter);
    } else if (note == 55) {
      // Splash Cymbal (Fast explosive ping, short shimmer)
      return _buildSplashCymbal(pitchJitter, decayJitter);
    }

    // ───────────────────────────────────────────────────────────────────────
    // LATIN & AUXILIARY PERCUSSION
    // ───────────────────────────────────────────────────────────────────────
    if (note == 54) {
      // Tambourine (Jingle burst + slap)
      return _buildTambourine(decayJitter);
    } else if (note == 56) {
      // Cowbell (2-band resonant FM metallic bell)
      return _buildCowbell(pitchJitter, decayJitter);
    } else if (note == 58) {
      // Vibraslap (Rattling decay ratchet)
      return _buildVibraslap(decayJitter);
    } else if (note == 60 || note == 61) {
      // Hi Bongo (60) & Low Bongo (61)
      final double freq = (note == 60 ? 320.0 : 220.0) * pitchJitter;
      return _buildBongo(freq, decayJitter, velocity);
    } else if (note == 62 || note == 63 || note == 64) {
      // Congas: Mute Hi (62), Open Hi (63), Low Conga (64)
      final bool isMute = note == 62;
      final double freq = (note == 64 ? 130.0 : 200.0) * pitchJitter;
      return _buildConga(freq, isMute: isMute, decayJitter: decayJitter, velocity: velocity);
    } else if (note == 65 || note == 66) {
      // Timbales: High (65), Low (66)
      final double freq = (note == 65 ? 260.0 : 190.0) * pitchJitter;
      return _buildTimbale(freq, decayJitter, velocity);
    } else if (note == 67 || note == 68) {
      // Agogo: High (67), Low (68)
      final double freq = (note == 67 ? 780.0 : 540.0) * pitchJitter;
      return _buildAgogo(freq, decayJitter);
    } else if (note == 69) {
      // Cabasa (Metal bead cylinder scrape)
      return _buildCabasa(decayJitter);
    } else if (note == 70) {
      // Maracas (Crisp seed shake)
      return _buildMaracas(decayJitter);
    } else if (note == 71 || note == 72) {
      // Whistle: Short (71), Long (72)
      final double dur = note == 71 ? 0.12 : 0.40;
      return _buildWhistle(dur, pitchJitter);
    } else if (note == 73 || note == 74) {
      // Guiro: Short (73), Long (74)
      final bool isLong = note == 74;
      return _buildGuiro(isLong: isLong, decayJitter: decayJitter);
    } else if (note == 75) {
      // Claves (Hardwood cylinder strike)
      return _buildClaves(pitchJitter, decayJitter);
    } else if (note == 76 || note == 77) {
      // Wood Blocks: Hi (76), Low (77)
      final double freq = (note == 76 ? 850.0 : 580.0) * pitchJitter;
      return _buildWoodBlock(freq, decayJitter);
    } else if (note == 78 || note == 79) {
      // Cuica: Mute (78), Open (79)
      final bool isMute = note == 78;
      return _buildCuica(isMute: isMute, pitchJitter: pitchJitter, decayJitter: decayJitter);
    } else if (note == 80 || note == 81) {
      // Triangle: Mute (80), Open (81)
      final bool isMute = note == 80;
      return _buildTriangle(isMute: isMute, pitchJitter: pitchJitter, decayJitter: decayJitter);
    }

    // Default Fallback
    return _buildAcousticBassDrum(
      startPitch: 180.0,
      endPitch: 52.0,
      pitchDecay: 0.07,
      fmDepth: 600.0,
      ampDecay: 0.28,
      subGain: 4.0,
      roomLevel: 0.35,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SYNTHESIS GRAPH BUILDERS (Acoustic Physical Models)
  // ─────────────────────────────────────────────────────────────────────────

  static GraphNode _buildAcousticBassDrum({
    required double startPitch,
    required double endPitch,
    required double pitchDecay,
    required double fmDepth,
    required double ampDecay,
    required double subGain,
    required double roomLevel,
  }) {
    const noise = NoiseNode();

    final nearPitchSweep = PitchSweepNode(
      startFreq: startPitch,
      endFreq: endPitch,
      decaySec: pitchDecay,
    );

    final nearFmEnv = DecayEnvNode(decaySec: 0.008);
    final nearFmMod = GainNode(
      input: noise,
      gainSource: nearFmEnv,
      staticGain: fmDepth,
    );

    final nearCarrier = SineOscNode(
      freqSource: nearPitchSweep,
      fmModSource: nearFmMod,
    );

    final nearAmpEnv = DecayEnvNode(decaySec: ampDecay);
    final nearVca = GainNode(input: nearCarrier, gainSource: nearAmpEnv);

    final nearSubBoost = BiquadFilterNode(
      input: nearVca,
      type: BiquadType.peaking,
      frequency: 58.0,
      q: 3.5,
      gainDb: subGain,
    );

    final nearMidScoop = BiquadFilterNode(
      input: nearSubBoost,
      type: BiquadType.peaking,
      frequency: 340.0,
      q: 1.8,
      gainDb: -8.0,
    );

    final nearClick = BiquadFilterNode(
      input: nearMidScoop,
      type: BiquadType.highshelf,
      frequency: 3600.0,
      gainDb: 5.0,
    );

    // Farfield Room Mic
    final farPitchSweep = PitchSweepNode(
      startFreq: startPitch * 0.75,
      endFreq: endPitch * 1.8,
      decaySec: pitchDecay * 1.8,
    );

    final farCarrier = SineOscNode(freqSource: farPitchSweep);
    final farAmpEnv = DecayEnvNode(decaySec: ampDecay * 0.8);
    final farVca = GainNode(input: farCarrier, gainSource: farAmpEnv, staticGain: roomLevel);

    final farDelayed = DelayNode(input: farVca, delaySec: 0.009);

    final masterMix = MixerNode([nearClick, farDelayed], [1.0, 1.0]);
    return DistortionNode(input: masterMix, drive: 1.12);
  }

  static GraphNode _buildAcousticSnare({
    required double bodyPitchStart,
    required double bodyPitchEnd,
    required double bodyDecay,
    required double wireCutoff,
    required double wireDecay,
    required double snappy,
    required double drive,
  }) {
    const noise = NoiseNode(seed: 0x98765432);

    final bodySweep = PitchSweepNode(
      startFreq: bodyPitchStart,
      endFreq: bodyPitchEnd,
      decaySec: 0.075,
    );

    final bodyOsc = SineOscNode(freqSource: bodySweep);
    final bodyEnv = DecayEnvNode(decaySec: bodyDecay);
    final bodyVca = GainNode(input: bodyOsc, gainSource: bodyEnv);

    final wireHp = BiquadFilterNode(
      input: noise,
      type: BiquadType.highpass,
      frequency: wireCutoff,
      q: 1.3,
    );

    final wireEnv = DecayEnvNode(decaySec: wireDecay);
    final wireVca = GainNode(input: wireHp, gainSource: wireEnv, staticGain: snappy);

    final masterMix = MixerNode([bodyVca, wireVca], [0.85, 1.15]);
    return DistortionNode(input: masterMix, drive: drive);
  }

  static GraphNode _buildSideStick(double pitchJitter, double decayJitter) {
    final woodSweep = PitchSweepNode(
      startFreq: 850.0 * pitchJitter,
      endFreq: 420.0 * pitchJitter,
      decaySec: 0.015,
    );

    final woodOsc = SineOscNode(freqSource: woodSweep);
    final woodEnv = DecayEnvNode(decaySec: 0.045 * decayJitter);
    final woodVca = GainNode(input: woodOsc, gainSource: woodEnv);

    const noise = NoiseNode(seed: 0x11223344);
    const clickEnv = DecayEnvNode(decaySec: 0.006);
    const clickVca = GainNode(input: noise, gainSource: clickEnv, staticGain: 0.6);

    final mix = MixerNode([woodVca, clickVca], [1.0, 0.7]);
    final resoFilter = BiquadFilterNode(
      input: mix,
      type: BiquadType.bandpass,
      frequency: 1600.0 * pitchJitter,
      q: 2.2,
    );

    return DistortionNode(input: resoFilter, drive: 1.25);
  }

  static GraphNode _buildHandClap(double decayJitter) {
    const noise = NoiseNode(seed: 0x778899AA);

    // Multi-transient cluster envelope (4 staggered bursts)
    final clapHp = BiquadFilterNode(
      input: noise,
      type: BiquadType.bandpass,
      frequency: 1100.0,
      q: 1.4,
    );

    final burst1 = GainNode(input: clapHp, gainSource: const DecayEnvNode(decaySec: 0.012), staticGain: 0.85);
    final burst2 = DelayNode(input: burst1, delaySec: 0.011);
    final burst3 = DelayNode(input: burst1, delaySec: 0.022);
    final mainTail = GainNode(
      input: clapHp,
      gainSource: DecayEnvNode(decaySec: 0.22 * decayJitter),
      staticGain: 0.75,
    );

    final masterClap = MixerNode([burst1, burst2, burst3, mainTail], [0.8, 0.75, 0.7, 1.0]);
    return DistortionNode(input: masterClap, drive: 1.15);
  }

  static GraphNode _buildAcousticTom({
    required double startPitch,
    required double endPitch,
    required double pitchDecay,
    required double ampDecay,
    required double stickFm,
  }) {
    const noise = NoiseNode(seed: 0x55AA1122);

    final batterSweep = PitchSweepNode(
      startFreq: startPitch,
      endFreq: endPitch,
      decaySec: pitchDecay,
    );

    final fmEnv = DecayEnvNode(decaySec: 0.012);
    final fmMod = GainNode(input: noise, gainSource: fmEnv, staticGain: stickFm);

    final batterOsc = SineOscNode(freqSource: batterSweep, fmModSource: fmMod);
    final ampEnv = DecayEnvNode(decaySec: ampDecay);
    final batterVca = GainNode(input: batterOsc, gainSource: ampEnv);

    final shellReso = BiquadFilterNode(
      input: batterVca,
      type: BiquadType.peaking,
      frequency: endPitch * 1.55,
      q: 3.2,
      gainDb: 4.5,
    );

    final roomDelayed = DelayNode(input: shellReso, delaySec: 0.011);
    final mix = MixerNode([shellReso, roomDelayed], [1.0, 0.35]);
    return DistortionNode(input: mix, drive: 1.1);
  }

  static GraphNode _buildHiHat({
    required double decaySec,
    required double cutoffHz,
    required double sizzleDb,
    required double clusterSpread,
  }) {
    final metalCluster = MetallicClusterNode(pitchMultiplier: clusterSpread);
    const noise = NoiseNode(seed: 0x33445566);

    const stickEnv = DecayEnvNode(decaySec: 0.005);
    const stickVca = GainNode(input: noise, gainSource: stickEnv, staticGain: 0.4);

    final mixCore = MixerNode([metalCluster, noise], [0.75, 0.25]);
    final decayEnv = DecayEnvNode(decaySec: decaySec);
    final gatedCore = GainNode(input: mixCore, gainSource: decayEnv);

    final hpf = BiquadFilterNode(
      input: gatedCore,
      type: BiquadType.highpass,
      frequency: cutoffHz,
      q: 1.4,
    );

    final highShelf = BiquadFilterNode(
      input: hpf,
      type: BiquadType.highshelf,
      frequency: 10000.0,
      gainDb: sizzleDb,
    );

    final masterMix = MixerNode([highShelf, stickVca], [1.0, 0.9]);
    return DistortionNode(input: masterMix, drive: 1.05);
  }

  static GraphNode _buildCrashCymbal(double pitchMultiplier, double decayJitter) {
    final metalCluster = MetallicClusterNode(pitchMultiplier: pitchMultiplier);
    const noise = NoiseNode(seed: 0x44668899);

    const stickEnv = DecayEnvNode(decaySec: 0.008);
    const stickVca = GainNode(input: noise, gainSource: stickEnv, staticGain: 0.7);

    final cymbalMix = MixerNode([metalCluster, noise], [0.55, 0.45]);
    final longDecay = DecayEnvNode(decaySec: 1.85 * decayJitter);
    final gatedCymbal = GainNode(input: cymbalMix, gainSource: longDecay);

    final hpf = BiquadFilterNode(
      input: gatedCymbal,
      type: BiquadType.highpass,
      frequency: 4800.0 * pitchMultiplier,
      q: 1.1,
    );

    final airShelf = BiquadFilterNode(
      input: hpf,
      type: BiquadType.highshelf,
      frequency: 9000.0,
      gainDb: 6.0,
    );

    final master = MixerNode([airShelf, stickVca], [1.0, 1.2]);
    return DistortionNode(input: master, drive: 1.1);
  }

  static GraphNode _buildRideCymbal(double pitchMultiplier, double decayJitter, {required bool isBell}) {
    final metalCluster = MetallicClusterNode(pitchMultiplier: pitchMultiplier * 1.2);
    const noise = NoiseNode(seed: 0x22338877);

    final double pingFreq = isBell ? 2200.0 * pitchMultiplier : 1400.0 * pitchMultiplier;
    final pingSweep = PitchSweepNode(startFreq: pingFreq * 1.2, endFreq: pingFreq, decaySec: 0.02);
    final pingOsc = SineOscNode(freqSource: pingSweep);
    final pingEnv = DecayEnvNode(decaySec: (isBell ? 0.85 : 0.35) * decayJitter);
    final pingVca = GainNode(input: pingOsc, gainSource: pingEnv, staticGain: isBell ? 1.4 : 0.8);

    final washDecay = DecayEnvNode(decaySec: (isBell ? 1.2 : 2.2) * decayJitter);
    final washVca = GainNode(input: metalCluster, gainSource: washDecay, staticGain: isBell ? 0.3 : 0.7);

    final washHpf = BiquadFilterNode(
      input: washVca,
      type: BiquadType.highpass,
      frequency: 6000.0,
      q: 1.2,
    );

    final master = MixerNode([pingVca, washHpf], [1.1, 0.9]);
    return DistortionNode(input: master, drive: 1.08);
  }

  static GraphNode _buildSplashCymbal(double pitchMultiplier, double decayJitter) {
    final metalCluster = MetallicClusterNode(pitchMultiplier: pitchMultiplier * 1.8);
    const noise = NoiseNode(seed: 0x66554433);

    final splashMix = MixerNode([metalCluster, noise], [0.6, 0.4]);
    final env = DecayEnvNode(decaySec: 0.45 * decayJitter);
    final gated = GainNode(input: splashMix, gainSource: env);

    final hpf = BiquadFilterNode(
      input: gated,
      type: BiquadType.highpass,
      frequency: 7200.0,
      q: 1.5,
    );

    return DistortionNode(input: hpf, drive: 1.1);
  }

  static GraphNode _buildChinaCymbal(double pitchMultiplier, double decayJitter) {
    final metalCluster = MetallicClusterNode(pitchMultiplier: pitchMultiplier * 0.85);
    const noise = NoiseNode(seed: 0x88990011);

    final trashMix = MixerNode([metalCluster, noise], [0.5, 0.5]);
    final env = DecayEnvNode(decaySec: 1.4 * decayJitter);
    final gated = GainNode(input: trashMix, gainSource: env);

    final trashBand = BiquadFilterNode(
      input: gated,
      type: BiquadType.bandpass,
      frequency: 3400.0,
      q: 2.5,
    );

    return DistortionNode(input: trashBand, drive: 1.35);
  }

  static GraphNode _buildCowbell(double pitchMultiplier, double decayJitter) {
    final osc1 = SineOscNode(staticFreq: 560.0 * pitchMultiplier);
    final osc2 = SineOscNode(staticFreq: 845.0 * pitchMultiplier);

    final mix = MixerNode([osc1, osc2], [0.65, 0.5]);
    final env = DecayEnvNode(decaySec: 0.28 * decayJitter);
    final vca = GainNode(input: mix, gainSource: env);

    final bp = BiquadFilterNode(
      input: vca,
      type: BiquadType.bandpass,
      frequency: 720.0 * pitchMultiplier,
      q: 4.5,
    );

    return DistortionNode(input: bp, drive: 1.25);
  }

  static GraphNode _buildBongo(double freq, double decayJitter, double velocity) {
    final sweep = PitchSweepNode(startFreq: freq * 1.35, endFreq: freq, decaySec: 0.02);
    final osc = SineOscNode(freqSource: sweep);
    final env = DecayEnvNode(decaySec: 0.18 * decayJitter);
    final vca = GainNode(input: osc, gainSource: env);

    const noise = NoiseNode(seed: 0x33221100);
    const slapEnv = DecayEnvNode(decaySec: 0.008);
    final slapVca = GainNode(input: noise, gainSource: slapEnv, staticGain: 0.6 * velocity);

    final mix = MixerNode([vca, slapVca], [0.9, 0.6]);
    final bodyPeaking = BiquadFilterNode(
      input: mix,
      type: BiquadType.peaking,
      frequency: freq * 1.8,
      q: 2.8,
      gainDb: 4.0,
    );

    return DistortionNode(input: bodyPeaking, drive: 1.15);
  }

  static GraphNode _buildConga(double freq, {required bool isMute, required double decayJitter, required double velocity}) {
    final double decay = (isMute ? 0.08 : 0.35) * decayJitter;
    final sweep = PitchSweepNode(startFreq: freq * (isMute ? 1.6 : 1.25), endFreq: freq, decaySec: 0.035);
    final osc = SineOscNode(freqSource: sweep);
    final env = DecayEnvNode(decaySec: decay);
    final vca = GainNode(input: osc, gainSource: env);

    const noise = NoiseNode(seed: 0x99AA1122);
    const slapEnv = DecayEnvNode(decaySec: 0.010);
    final slapVca = GainNode(input: noise, gainSource: slapEnv, staticGain: isMute ? 0.9 : 0.45);

    final mix = MixerNode([vca, slapVca], [1.0, 0.8]);
    final barrelReso = BiquadFilterNode(
      input: mix,
      type: BiquadType.peaking,
      frequency: freq * 1.4,
      q: 3.5,
      gainDb: isMute ? 2.0 : 5.0,
    );

    return DistortionNode(input: barrelReso, drive: 1.18);
  }

  static GraphNode _buildTimbale(double freq, double decayJitter, double velocity) {
    final sweep = PitchSweepNode(startFreq: freq * 1.5, endFreq: freq, decaySec: 0.025);
    final osc = SineOscNode(freqSource: sweep);
    final env = DecayEnvNode(decaySec: 0.32 * decayJitter);
    final vca = GainNode(input: osc, gainSource: env);

    final shellRing = BiquadFilterNode(
      input: vca,
      type: BiquadType.peaking,
      frequency: freq * 2.2,
      q: 5.0,
      gainDb: 6.0,
    );

    return DistortionNode(input: shellRing, drive: 1.2);
  }

  static GraphNode _buildAgogo(double freq, double decayJitter) {
    final osc1 = SineOscNode(staticFreq: freq);
    final osc2 = SineOscNode(staticFreq: freq * 1.48);

    final mix = MixerNode([osc1, osc2], [0.7, 0.5]);
    final env = DecayEnvNode(decaySec: 0.26 * decayJitter);
    final vca = GainNode(input: mix, gainSource: env);

    final bp = BiquadFilterNode(
      input: vca,
      type: BiquadType.bandpass,
      frequency: freq * 1.2,
      q: 4.0,
    );

    return DistortionNode(input: bp, drive: 1.15);
  }

  static GraphNode _buildTambourine(double decayJitter) {
    const noise = NoiseNode(seed: 0x55667788);
    final metalCluster = MetallicClusterNode(pitchMultiplier: 2.4);

    final mix = MixerNode([noise, metalCluster], [0.6, 0.4]);
    final env = DecayEnvNode(decaySec: 0.18 * decayJitter);
    final vca = GainNode(input: mix, gainSource: env);

    final hpf = BiquadFilterNode(
      input: vca,
      type: BiquadType.highpass,
      frequency: 6500.0,
      q: 1.8,
    );

    return DistortionNode(input: hpf, drive: 1.1);
  }

  static GraphNode _buildCabasa(double decayJitter) {
    const noise = NoiseNode(seed: 0x12344321);
    final env = DecayEnvNode(decaySec: 0.08 * decayJitter);
    final vca = GainNode(input: noise, gainSource: env);

    final bp = BiquadFilterNode(
      input: vca,
      type: BiquadType.bandpass,
      frequency: 5200.0,
      q: 2.2,
    );

    return DistortionNode(input: bp, drive: 1.1);
  }

  static GraphNode _buildMaracas(double decayJitter) {
    const noise = NoiseNode(seed: 0x99887766);
    final env = DecayEnvNode(decaySec: 0.045 * decayJitter);
    final vca = GainNode(input: noise, gainSource: env);

    final hpf = BiquadFilterNode(
      input: vca,
      type: BiquadType.highpass,
      frequency: 6800.0,
      q: 2.0,
    );

    return DistortionNode(input: hpf, drive: 1.12);
  }

  static GraphNode _buildWhistle(double durationSec, double pitchJitter) {
    final osc1 = SineOscNode(staticFreq: 1800.0 * pitchJitter);
    final osc2 = SineOscNode(staticFreq: 1825.0 * pitchJitter); // 25Hz vibrato beat
    final mix = MixerNode([osc1, osc2], [0.6, 0.6]);

    const noise = NoiseNode(seed: 0x334455);
    const airHpf = BiquadFilterNode(input: noise, type: BiquadType.bandpass, frequency: 1800.0, q: 3.0);
    final masterMix = MixerNode([mix, airHpf], [0.9, 0.15]);

    final env = DecayEnvNode(decaySec: durationSec);
    final vca = GainNode(input: masterMix, gainSource: env);
    return DistortionNode(input: vca, drive: 1.1);
  }

  static GraphNode _buildGuiro({required bool isLong, required double decayJitter}) {
    const noise = NoiseNode(seed: 0x44332211);
    final double decay = (isLong ? 0.28 : 0.09) * decayJitter;
    final env = DecayEnvNode(decaySec: decay);
    final vca = GainNode(input: noise, gainSource: env);

    final bp = BiquadFilterNode(
      input: vca,
      type: BiquadType.bandpass,
      frequency: 2400.0,
      q: 2.8,
    );

    return DistortionNode(input: bp, drive: 1.2);
  }

  static GraphNode _buildClaves(double pitchJitter, double decayJitter) {
    final osc = SineOscNode(staticFreq: 2450.0 * pitchJitter);
    final env = DecayEnvNode(decaySec: 0.065 * decayJitter);
    final vca = GainNode(input: osc, gainSource: env);

    final bp = BiquadFilterNode(
      input: vca,
      type: BiquadType.bandpass,
      frequency: 2450.0 * pitchJitter,
      q: 6.0,
    );

    return DistortionNode(input: bp, drive: 1.25);
  }

  static GraphNode _buildWoodBlock(double freq, double decayJitter) {
    final sweep = PitchSweepNode(startFreq: freq * 1.4, endFreq: freq, decaySec: 0.012);
    final osc = SineOscNode(freqSource: sweep);
    final env = DecayEnvNode(decaySec: 0.08 * decayJitter);
    final vca = GainNode(input: osc, gainSource: env);

    final bp = BiquadFilterNode(
      input: vca,
      type: BiquadType.bandpass,
      frequency: freq,
      q: 4.8,
    );

    return DistortionNode(input: bp, drive: 1.3);
  }

  static GraphNode _buildCuica({required bool isMute, required double pitchJitter, required double decayJitter}) {
    final double start = (isMute ? 750.0 : 480.0) * pitchJitter;
    final double end = (isMute ? 950.0 : 720.0) * pitchJitter;
    final sweep = PitchSweepNode(startFreq: start, endFreq: end, decaySec: 0.12);
    final osc = SineOscNode(freqSource: sweep);

    const noise = NoiseNode(seed: 0x11335577);
    const frictionEnv = DecayEnvNode(decaySec: 0.08);
    const frictionVca = GainNode(input: noise, gainSource: frictionEnv, staticGain: 0.35);

    final mix = MixerNode([osc, frictionVca], [0.85, 0.3]);
    final env = DecayEnvNode(decaySec: (isMute ? 0.10 : 0.28) * decayJitter);
    final vca = GainNode(input: mix, gainSource: env);

    return DistortionNode(input: vca, drive: 1.15);
  }

  static GraphNode _buildTriangle({required bool isMute, required double pitchJitter, required double decayJitter}) {
    final osc1 = SineOscNode(staticFreq: 4200.0 * pitchJitter);
    final osc2 = SineOscNode(staticFreq: 7800.0 * pitchJitter);
    final mix = MixerNode([osc1, osc2], [0.7, 0.4]);

    final double decay = (isMute ? 0.06 : 1.4) * decayJitter;
    final env = DecayEnvNode(decaySec: decay);
    final vca = GainNode(input: mix, gainSource: env);

    final hpf = BiquadFilterNode(input: vca, type: BiquadType.highpass, frequency: 3800.0, q: 2.0);
    return DistortionNode(input: hpf, drive: 1.05);
  }

  static GraphNode _buildVibraslap(double decayJitter) {
    const noise = NoiseNode(seed: 0x98761234);
    final env = DecayEnvNode(decaySec: 0.55 * decayJitter);
    final vca = GainNode(input: noise, gainSource: env);

    final rattleBand = BiquadFilterNode(
      input: vca,
      type: BiquadType.bandpass,
      frequency: 1400.0,
      q: 2.0,
    );

    return DistortionNode(input: rattleBand, drive: 1.3);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  OVERRIDE EVALUATION (User-assigned 808/909/Acoustic presets onto pads)
  // ─────────────────────────────────────────────────────────────────────────

  static Float32List? _evaluateOverridePreset(
    String presetId, {
    required double durationSec,
    required double velocity,
    required Map<String, double> params,
    required double sampleRate,
    required bool isAccent,
    required int note,
  }) {
    GraphNode? node;
    switch (presetId) {
      case 'analog_808_kick':
        node = GraphEvaluator.buildAnalog808Kick();
        break;
      case 'analog_808_snare':
        node = GraphEvaluator.buildAnalog808Snare();
        break;
      case 'analog_808_hihat':
        node = GraphEvaluator.buildAnalog808HiHat();
        break;
      case 'analog_808_cowbell':
        node = GraphEvaluator.buildAnalog808Cowbell();
        break;
      case 'analog_808_tom':
        node = GraphEvaluator.buildAnalog808Tom();
        break;
      case 'analog_909_kick':
        node = GraphEvaluator.buildAnalog909Kick();
        break;
      case 'analog_909_snare':
        node = GraphEvaluator.buildAnalog909Snare();
        break;
      case 'analog_909_closed_hihat':
        node = GraphEvaluator.buildAnalog909ClosedHiHat();
        break;
      case 'analog_909_open_hihat':
        node = GraphEvaluator.buildAnalog909OpenHiHat();
        break;
      case 'analog_909_clap':
        node = GraphEvaluator.buildAnalog909Clap();
        break;
      case 'analog_909_rimshot':
        node = GraphEvaluator.buildAnalog909Rimshot();
        break;
      case 'fm_acoustic_kick':
        node = GraphEvaluator.buildDualMicFmAcousticKick();
        break;
      case 'fm_acoustic_snare':
        node = GraphEvaluator.buildDualMicFmAcousticSnare();
        break;
      case 'fm_acoustic_tom':
        node = GraphEvaluator.buildDualMicFmAcousticTom();
        break;
      case 'fm_acoustic_hihat':
        node = GraphEvaluator.buildDualMicFmAcousticHiHat();
        break;
    }

    if (node != null) {
      return GraphEvaluator.evaluate(
        root: node,
        durationSec: durationSec,
        freq: 440.0,
        note: note,
        params: params,
        sampleRate: sampleRate,
        velocity: velocity,
        isAccent: isAccent,
      );
    }

    final libPreset = LuaPresetLibrary.getPresetById(presetId);
    if (libPreset != null) {
      try {
        final freq = PolySynth.midiToFreq(note);
        return EatScriptEngine.synthesizeBuffer(
          code: libPreset.code,
          durationSec: durationSec,
          freq: freq,
          note: note,
          params: params,
          velocity: velocity,
          isAccent: isAccent,
        );
      } catch (_) {}
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CHOKE GROUPS & BUS PROCESSING
  // ─────────────────────────────────────────────────────────────────────────

  static void _handleChokeGroups(String trackId, int note, double duration) {
    _lastChokedNoteByTrack[trackId] = note;
    _lastChokedTimeByTrack[trackId] = duration;
  }

  static void _applyMasterKitProcessing(
    Float32List buffer,
    Map<String, double> params,
    double sampleRate,
  ) {
    final double kitDrive = (params['KitDrive'] ?? 0.10).clamp(0.0, 1.0);
    if (kitDrive > 0.01) {
      final double driveFactor = 1.0 + (kitDrive * 2.5);
      for (int i = 0; i < buffer.length; i++) {
        final double x = buffer[i] * driveFactor;
        // Fast tanh soft saturation
        if (x > 3.0) {
          buffer[i] = 1.0;
        } else if (x < -3.0) {
          buffer[i] = -1.0;
        } else {
          final double x2 = x * x;
          buffer[i] = (x * (27.0 + x2) / (27.0 + 9.0 * x2)).clamp(-1.0, 1.0);
        }
      }
    }
  }

  static double _getNaturalDurationForNote(int note, Map<String, double> params) {
    if (note == 49 || note == 57) return 2.2; // Crash cymbals
    if (note == 51 || note == 59 || note == 53) return 2.5; // Rides
    if (note == 52) return 1.6; // China
    if (note == 46) return 0.75; // Open hat
    if (note == 81) return 1.5; // Open triangle
    if (note >= 41 && note <= 50) return 0.65; // Toms
    if (note == 35 || note == 36) return 0.45; // Kicks
    if (note == 38 || note == 40) return 0.35; // Snares
    return 0.35; // Percussion default
  }
}
