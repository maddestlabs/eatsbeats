import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:eatsbeats/audio/gm/gm_instrument_registry.dart';
import 'package:eatsbeats/audio/graph/graph_node.dart';
import 'package:eatsbeats/audio/graph/graph_primitives.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';

void main() {
  group('Eatsbeats Graph (eatsbeats.graph) Core DSP Unit Tests', () {
    test('NoiseNode generates bounded random signal within [-1.0, 1.0]', () {
      const noise = NoiseNode(seed: 0x12345678);
      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 440.0,
        midiNote: 60,
      );
      final buffer = Float32List(ctx.totalSamples);
      noise.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      bool hasPositive = false;
      bool hasNegative = false;
      for (final s in buffer) {
        expect(s, inInclusiveRange(-1.0, 1.0));
        if (s > 0.1) hasPositive = true;
        if (s < -0.1) hasNegative = true;
      }
      expect(hasPositive, isTrue);
      expect(hasNegative, isTrue);
    });

    test('SineOscNode with audio-rate Noise FM produces modulated waveform', () {
      const noise = NoiseNode();
      const fmEnv = DecayEnvNode(decaySec: 0.01);
      const fmMod = GainNode(input: noise, gainSource: fmEnv, staticGain: 500.0);
      const carrier = SineOscNode(staticFreq: 100.0, fmModSource: fmMod);

      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 100.0,
        midiNote: 36,
      );
      final buffer = Float32List(ctx.totalSamples);
      carrier.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('BiquadFilterNode filters and preserves numerical stability', () {
      const noise = NoiseNode();
      const peaking = BiquadFilterNode(
        input: noise,
        type: BiquadType.peaking,
        frequency: 60.0,
        q: 3.5,
        gainDb: 6.0,
      );
      const highpass = BiquadFilterNode(
        input: peaking,
        type: BiquadType.highpass,
        frequency: 85.0,
      );

      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 440.0,
        midiNote: 60,
      );
      final buffer = Float32List(ctx.totalSamples);
      highpass.process(ctx, buffer);

      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
      }
    });

    test('DelayNode delays signal by specified time', () {
      const noise = NoiseNode();
      const delay = DelayNode(input: noise, delaySec: 0.005); // 5ms delay

      final ctx = GraphContext(
        durationSec: 0.02,
        freq: 440.0,
        midiNote: 60,
      );
      final buffer = Float32List(ctx.totalSamples);
      delay.process(ctx, buffer);

      final int delaySamples = (0.005 * 44100).toInt();
      // First `delaySamples` should be 0.0
      for (int i = 0; i < delaySamples; i++) {
        expect(buffer[i], equals(0.0));
      }
      // Subsequent samples should be non-zero
      bool hasAudio = false;
      for (int i = delaySamples; i < buffer.length; i++) {
        if (buffer[i] != 0.0) hasAudio = true;
      }
      expect(hasAudio, isTrue);
    });

    test('GraphEvaluator synthesizes complete Dual-Mic FM Acoustic Kick drum', () {
      final root = GraphEvaluator.buildDualMicFmAcousticKick();
      final pcm = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.35,
        freq: 55.0,
        note: 36,
        params: {
          'NearPitchStart': 180.0,
          'NearPitchEnd': 52.0,
          'NearPitchDecay': 0.07,
          'NearFmDepth': 600.0,
          'NearFmDecay': 0.008,
          'NearAmpDecay': 0.28,
          'SubResoGain': 4.0,
          'FarLevel': 0.35,
          'RoomDelaySec': 0.008,
        },
      );

      expect(pcm.length, equals((44100 * 0.35).toInt()));
      double peak = 0.0;
      for (final s in pcm) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        if (s.abs() > peak) peak = s.abs();
      }
      expect(peak, greaterThan(0.1));
      expect(peak, lessThanOrEqualTo(1.0));
    });

    test('GraphEvaluator synthesizes complete Dual-Mic FM Acoustic Snare drum', () {
      final root = GraphEvaluator.buildDualMicFmAcousticSnare();
      final pcm = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.25,
        freq: 185.0,
        note: 38,
        params: {
          'ToneFreq': 185.0,
          'Snappy': 0.65,
          'Decay': 0.22,
          'WireCutoff': 1800.0,
        },
      );

      expect(pcm.length, equals((44100 * 0.25).toInt()));
      double peak = 0.0;
      for (final s in pcm) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        if (s.abs() > peak) peak = s.abs();
      }
      expect(peak, greaterThan(0.1));
      expect(peak, lessThanOrEqualTo(1.0));
    });

    test('LuaPresetLibrary contains FM Acoustic Kick & Snare with custom Hardware GUI', () {
      final kickPreset = LuaPresetLibrary.getPresetById('fm_acoustic_kick');
      expect(kickPreset, isNotNull);
      expect(kickPreset!.name, equals('FM Acoustic Kick'));

      final kickCompilation = LuaEngine.compile(kickPreset.code);
      expect(kickCompilation.isSuccess, isTrue);
      expect(kickCompilation.params.length, greaterThanOrEqualTo(10));
      expect(kickCompilation.guiLayout, isNotNull);
      expect(kickCompilation.guiLayout!.title, contains('ACOUSTIC KICK'));

      final snarePreset = LuaPresetLibrary.getPresetById('fm_acoustic_snare');
      expect(snarePreset, isNotNull);
      expect(snarePreset!.name, equals('FM Acoustic Snare'));

      final snareCompilation = LuaEngine.compile(snarePreset.code);
      expect(snareCompilation.isSuccess, isTrue);
      expect(snareCompilation.guiLayout, isNotNull);
      expect(snareCompilation.guiLayout!.title, contains('ACOUSTIC SNARE'));
    });

    test('LuaEngine.synthesizeBuffer evaluates fm_acoustic_kick script seamlessly', () {
      final kickPreset = LuaPresetLibrary.getPresetById('fm_acoustic_kick')!;
      final buffer = LuaEngine.synthesizeBuffer(
        code: kickPreset.code,
        durationSec: 0.3,
        freq: 55.0,
        note: 36,
        params: {
          'NearPitchStart': 180.0,
          'NearPitchEnd': 52.0,
          'NearFmDepth': 600.0,
        },
      );

      expect(buffer.length, equals((44100 * 0.3).toInt()));
      expect(buffer.any((s) => s.abs() > 0.1), isTrue);
    });

    test('MetallicClusterNode generates 6-osc inharmonic metallic cluster', () {
      const cluster = MetallicClusterNode();
      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 440.0,
        midiNote: 60,
      );
      final buffer = Float32List(ctx.totalSamples);
      cluster.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      expect(buffer.any((s) => s.abs() > 0.1), isTrue);
    });

    test('GraphEvaluator synthesizes Acoustic Toms and Hi-Hat', () {
      // 1. Tom
      final tomRoot = GraphEvaluator.buildDualMicFmAcousticTom();
      final tomPcm = GraphEvaluator.evaluate(
        root: tomRoot,
        durationSec: 0.3,
        freq: 90.0,
        note: 45,
        params: {'ToneFreq': 90.0, 'StickFmDepth': 350.0},
      );
      expect(tomPcm.any((s) => s.abs() > 0.1), isTrue);

      // 2. Hi-Hat
      final hatRoot = GraphEvaluator.buildDualMicFmAcousticHiHat();
      final hatPcm = GraphEvaluator.evaluate(
        root: hatRoot,
        durationSec: 0.1,
        freq: 440.0,
        note: 42,
        params: {'Cutoff': 7000.0, 'Decay': 0.08},
      );
      expect(hatPcm.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Authentic Analog 808 Suite', () {
      // 1. 808 Kick
      final kick808 = GraphEvaluator.buildAnalog808Kick();
      final kickPcm = GraphEvaluator.evaluate(
        root: kick808,
        durationSec: 0.4,
        freq: 46.0,
        note: 36,
        params: {'Tune': 46.0, 'Decay': 0.85, 'Tone': 220.0},
      );
      expect(kickPcm.any((s) => s.abs() > 0.1), isTrue);

      // 2. 808 Snare
      final snare808 = GraphEvaluator.buildAnalog808Snare();
      final snarePcm = GraphEvaluator.evaluate(
        root: snare808,
        durationSec: 0.2,
        freq: 180.0,
        note: 38,
        params: {'Snappy': 0.7, 'Decay': 0.2},
      );
      expect(snarePcm.any((s) => s.abs() > 0.1), isTrue);

      // 3. 808 Hi-Hat
      final hat808 = GraphEvaluator.buildAnalog808HiHat();
      final hatPcm = GraphEvaluator.evaluate(
        root: hat808,
        durationSec: 0.1,
        freq: 440.0,
        note: 42,
        params: {'Cutoff': 7500.0, 'Decay': 0.08},
      );
      expect(hatPcm.any((s) => s.abs() > 0.05), isTrue);

      // 4. 808 Cowbell
      final cowbell808 = GraphEvaluator.buildAnalog808Cowbell();
      final cowbellPcm = GraphEvaluator.evaluate(
        root: cowbell808,
        durationSec: 0.2,
        freq: 800.0,
        note: 56,
        params: {'Tune': 800.0, 'Decay': 0.32},
      );
      expect(cowbellPcm.any((s) => s.abs() > 0.1), isTrue);

      // 5. 808 Tom
      final tom808 = GraphEvaluator.buildAnalog808Tom();
      final tomPcm = GraphEvaluator.evaluate(
        root: tom808,
        durationSec: 0.3,
        freq: 100.0,
        note: 45,
        params: {'Tune': 100.0, 'Decay': 0.4},
      );
      expect(tomPcm.any((s) => s.abs() > 0.1), isTrue);
    });

    test('GraphEvaluator synthesizes Authentic Analog 909 Suite', () {
      // 1. 909 Kick
      final kick909 = GraphEvaluator.buildAnalog909Kick();
      final kickPcm = GraphEvaluator.evaluate(
        root: kick909,
        durationSec: 0.4,
        freq: 54.0,
        note: 36,
        params: {'Tune': 0.018, 'Attack': 1.0, 'Decay': 0.050},
      );
      expect(kickPcm.any((s) => s.abs() > 0.1), isTrue);

      // 2. 909 Snare
      final snare909 = GraphEvaluator.buildAnalog909Snare();
      final snarePcm = GraphEvaluator.evaluate(
        root: snare909,
        durationSec: 0.25,
        freq: 195.0,
        note: 38,
        params: {'Tune': 0.0, 'Snappy': 1.0, 'ToneDecay': 0.12},
      );
      expect(snarePcm.any((s) => s.abs() > 0.1), isTrue);

      // 3. 909 Closed Hi-Hat
      final ch909 = GraphEvaluator.buildAnalog909ClosedHiHat();
      final chPcm = GraphEvaluator.evaluate(
        root: ch909,
        durationSec: 0.08,
        freq: 440.0,
        note: 42,
        params: {'Tune': 0.0, 'Decay': 0.025},
      );
      expect(chPcm.any((s) => s.abs() > 0.05), isTrue);

      // 4. 909 Open Hi-Hat
      final oh909 = GraphEvaluator.buildAnalog909OpenHiHat();
      final ohPcm = GraphEvaluator.evaluate(
        root: oh909,
        durationSec: 0.35,
        freq: 440.0,
        note: 46,
        params: {'Tune': 0.0, 'Decay': 0.080},
      );
      expect(ohPcm.any((s) => s.abs() > 0.05), isTrue);

      // 5. 909 Handclap
      final clap909 = GraphEvaluator.buildAnalog909Clap();
      final clapPcm = GraphEvaluator.evaluate(
        root: clap909,
        durationSec: 0.3,
        freq: 1150.0,
        note: 39,
        params: {'Tune': 0.0, 'Decay': 0.28},
      );
      expect(clapPcm.any((s) => s.abs() > 0.08), isTrue);

      // 6. 909 Rimshot
      final rim909 = GraphEvaluator.buildAnalog909Rimshot();
      final rimPcm = GraphEvaluator.evaluate(
        root: rim909,
        durationSec: 0.15,
        freq: 1850.0,
        note: 37,
        params: {'Tune': 0.0, 'Decay': 0.075},
      );
      expect(rimPcm.any((s) => s.abs() > 0.1), isTrue);
    });

    test('LuaPresetLibrary contains all new drum presets with compiled GUI layouts', () {
      final presetIds = [
        'fm_acoustic_tom',
        'fm_acoustic_hihat',
        'analog_808_kick',
        'analog_808_snare',
        'analog_808_hihat',
        'analog_808_cowbell',
        'analog_808_tom',
        'analog_909_kick',
        'analog_909_snare',
        'analog_909_closed_hihat',
        'analog_909_open_hihat',
        'analog_909_clap',
        'analog_909_rimshot',
      ];

      for (final id in presetIds) {
        final preset = LuaPresetLibrary.getPresetById(id);
        expect(preset, isNotNull, reason: 'Preset $id should exist');
        final comp = LuaEngine.compile(preset!.code);
        expect(comp.isSuccess, isTrue, reason: 'Preset $id should compile');
        expect(comp.guiLayout, isNotNull, reason: 'Preset $id should have GUI layout');

        final synthBuffer = LuaEngine.synthesizeBuffer(
          code: preset.code,
          durationSec: 0.1,
          freq: 100.0,
          note: 36,
          params: const {},
        );
        expect(synthBuffer.any((s) => s.abs() > 0.01), isTrue, reason: 'Preset $id should synthesize non-silent audio');
      }
    });

    test('PlasmaArcOscNode generates pitched, jittered pulses within [-1.0, 1.0]', () {
      const arcOsc = PlasmaArcOscNode(
        sparkWidth: 0.15,
        jitter: 0.40,
        subHarmonic: 0.20,
      );
      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 220.0,
        midiNote: 57,
      );
      final buffer = Float32List(ctx.totalSamples);
      arcOsc.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
      expect(buffer.any((s) => s.abs() > 0.1), isTrue);
    });

    test('PoissonCrackleNode generates stochastic corona impulses', () {
      const crackle = PoissonCrackleNode(density: 0.50, sizzleBright: 0.80);
      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 440.0,
        midiNote: 69,
      );
      final buffer = Float32List(ctx.totalSamples);
      crackle.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('SubstationHumNode generates 60Hz transformer hum', () {
      const hum = SubstationHumNode(humLevel: 0.40, mainsFreq: 60.0);
      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 60.0,
        midiNote: 24,
      );
      final buffer = Float32List(ctx.totalSamples);
      hum.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator.buildVoltaicPlasmaSynth renders across piano roll (C1 to C6)', () {
      final root = GraphEvaluator.buildVoltaicPlasmaSynth();
      for (final note in [24, 36, 48, 60, 72, 84]) {
        final freq = 440.0 * math.pow(2.0, (note - 69) / 12.0);
        final buffer = GraphEvaluator.evaluate(
          root: root,
          durationSec: 0.10,
          freq: freq,
          note: note,
          params: {
            'Voltage': 1.5,
            'SparkGap': 0.2,
            'Jitter': 0.3,
            'CrackleRate': 0.4,
            'GridHum': 0.25,
            'SnapAttack': 1.0,
            'OzoneDrive': 1.4,
            'Tone': 8000.0,
          },
        );

        expect(buffer.length, greaterThan(100));
        for (final s in buffer) {
          expect(s.isNaN, isFalse);
          expect(s.isInfinite, isFalse);
          expect(s, inInclusiveRange(-1.0, 1.0));
        }
        expect(buffer.any((s) => s.abs() > 0.05), isTrue);
      }
    });

    test('VOLTAIC preset compiles in LuaEngine with full GUI and valid synthesis', () {
      final preset = LuaPresetLibrary.getPresetById('voltaic_plasma_synth');
      expect(preset, isNotNull);
      final comp = LuaEngine.compile(preset!.code);
      expect(comp.isSuccess, isTrue, reason: comp.errorMessage);
      expect(comp.guiLayout, isNotNull);
      expect(comp.params.any((p) => p.name == 'Voltage'), isTrue);
      expect(comp.params.any((p) => p.name == 'SparkGap'), isTrue);

      final pcm = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.2,
        freq: 220.0,
        note: 57,
        params: {'Voltage': 1.25, 'SparkGap': 0.15},
      );
      expect(pcm.length, greaterThan(100));
      expect(pcm.any((s) => s.abs() > 0.05), isTrue);
    });

    test('ThermoacousticFlameOscNode generates pitched singing flame waveform within [-1.0, 1.0]', () {
      const flameOsc = ThermoacousticFlameOscNode(
        flameCusp: 0.45,
        thermalDrift: 0.30,
        tubeResonance: 0.50,
      );
      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 261.63, // C4
        midiNote: 60,
      );
      final buffer = Float32List(ctx.totalSamples);
      flameOsc.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
      expect(buffer.any((s) => s.abs() > 0.1), isTrue);
    });

    test('CombustionRoarNode generates low-frequency turbulent air roar', () {
      const roar = CombustionRoarNode(roarLevel: 0.40, draftFlutter: 0.50);
      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 100.0,
        midiNote: 36,
      );
      final buffer = Float32List(ctx.totalSamples);
      roar.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
      expect(buffer.any((s) => s.abs() > 0.01), isTrue);
    });

    test('SapExplosionCrackleNode generates dual-stage sap pops and ember sizzle', () {
      const crackle = SapExplosionCrackleNode(sapDensity: 0.60, emberSizzle: 0.50);
      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 440.0,
        midiNote: 69,
      );
      final buffer = Float32List(ctx.totalSamples);
      crackle.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('GraphEvaluator.buildPyrophoneSynth renders across piano roll (C1 to C6)', () {
      final root = GraphEvaluator.buildPyrophoneSynth();
      for (final note in [24, 36, 48, 60, 72, 84]) {
        final freq = 440.0 * math.pow(2.0, (note - 69) / 12.0);
        final buffer = GraphEvaluator.evaluate(
          root: root,
          durationSec: 0.10,
          freq: freq,
          note: note,
          params: {
            'FuelPressure': 1.4,
            'FlameCusp': 0.45,
            'TubeResonance': 0.5,
            'IgnitionSnap': 0.85,
            'CombustionRoar': 0.35,
            'OxygenDraft': 0.40,
            'SapCrackle': 0.40,
            'EmberSizzle': 0.35,
            'Tone': 7500.0,
          },
        );

        expect(buffer.length, greaterThan(100));
        for (final s in buffer) {
          expect(s.isNaN, isFalse);
          expect(s.isInfinite, isFalse);
          expect(s, inInclusiveRange(-1.0, 1.0));
        }
        expect(buffer.any((s) => s.abs() > 0.05), isTrue);
      }
    });

    test('PYROPHONE preset compiles in LuaEngine with full GUI and valid synthesis', () {
      final preset = LuaPresetLibrary.getPresetById('pyrophone_synth');
      expect(preset, isNotNull);
      final comp = LuaEngine.compile(preset!.code);
      expect(comp.isSuccess, isTrue, reason: comp.errorMessage);
      expect(comp.guiLayout, isNotNull);
      expect(comp.params.any((p) => p.name == 'FuelPressure'), isTrue);
      expect(comp.params.any((p) => p.name == 'FlameCusp'), isTrue);

      final pcm = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.2,
        freq: 261.63,
        note: 60,
        params: {'FuelPressure': 1.25, 'FlameCusp': 0.45},
      );
      expect(pcm.length, greaterThan(100));
      expect(pcm.any((s) => s.abs() > 0.05), isTrue);
    });

    test('HydraulophoneOscNode generates pitched, bounded bubble-chirped waveform', () {
      const waterOsc = HydraulophoneOscNode(
        bubbleChirp: 0.45,
        viscosity: 0.40,
        currentDrift: 0.35,
      );
      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 329.63, // E4
        midiNote: 64,
      );
      final buffer = Float32List(ctx.totalSamples);
      waterOsc.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
      expect(buffer.any((s) => s.abs() > 0.1), isTrue);
    });

    test('HydrodynamicVortexNode generates low-frequency fluid turbulence and whirlpool rumble', () {
      const vortex = HydrodynamicVortexNode(vortexLevel: 0.35, churnSpeed: 0.40);
      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 100.0,
        midiNote: 36,
      );
      final buffer = Float32List(ctx.totalSamples);
      vortex.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
      expect(buffer.any((s) => s.abs() > 0.01), isTrue);
    });

    test('DropletSplashMatrixNode generates droplet plinks and micro-spray sizzle', () {
      const droplet = DropletSplashMatrixNode(dropletRate: 0.50, sprayHiss: 0.40);
      final ctx = GraphContext(
        durationSec: 0.05,
        freq: 440.0,
        midiNote: 69,
      );
      final buffer = Float32List(ctx.totalSamples);
      droplet.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('GraphEvaluator.buildEatsWaterSynth renders across piano roll (C1 to C6)', () {
      final root = GraphEvaluator.buildEatsWaterSynth();
      for (final note in [24, 36, 48, 60, 72, 84]) {
        final freq = 440.0 * math.pow(2.0, (note - 69) / 12.0);
        final buffer = GraphEvaluator.evaluate(
          root: root,
          durationSec: 0.10,
          freq: freq,
          note: note,
          params: {
            'WaterFlow': 1.3,
            'BubblePinch': 0.45,
            'Viscosity': 0.40,
            'PlungeImpact': 0.85,
            'Turbulence': 0.35,
            'CurrentDrift': 0.35,
            'DropletRate': 0.40,
            'SprayHiss': 0.35,
            'Depth': 6500.0,
          },
        );

        expect(buffer.length, greaterThan(100));
        for (final s in buffer) {
          expect(s.isNaN, isFalse);
          expect(s.isInfinite, isFalse);
          expect(s, inInclusiveRange(-1.0, 1.0));
        }
        expect(buffer.any((s) => s.abs() > 0.05), isTrue);
      }
    });

    test('Eats Water, Eats Furnace, Eats Fire, and Eats Volts presets compile and synthesize seamlessly', () {
      final voltsPreset = LuaPresetLibrary.getPresetById('eats_volts');
      final furnacePreset = LuaPresetLibrary.getPresetById('eats_furnace');
      final firePreset = LuaPresetLibrary.getPresetById('eats_fire');
      final waterPreset = LuaPresetLibrary.getPresetById('eats_water');
      final rainPreset = LuaPresetLibrary.getPresetById('eats_rain');
      final windPreset = LuaPresetLibrary.getPresetById('eats_wind');
      final thunderPreset = LuaPresetLibrary.getPresetById('eats_thunder');

      expect(voltsPreset, isNotNull);
      expect(furnacePreset, isNotNull);
      expect(firePreset, isNotNull);
      expect(waterPreset, isNotNull);
      expect(rainPreset, isNotNull);
      expect(windPreset, isNotNull);
      expect(thunderPreset, isNotNull);

      // Verify compile & GUI
      for (final p in [voltsPreset!, furnacePreset!, firePreset!, waterPreset!, rainPreset!, windPreset!, thunderPreset!]) {
        final comp = LuaEngine.compile(p.code);
        expect(comp.isSuccess, isTrue, reason: '${p.name}: ${comp.errorMessage}');
        expect(comp.guiLayout, isNotNull, reason: '${p.name} missing GUI layout');
      }

      // Verify synthesis
      final pcmWater = LuaEngine.synthesizeBuffer(
        code: waterPreset!.code,
        durationSec: 0.2,
        freq: 261.63,
        note: 60,
        params: {'WaterFlow': 1.25, 'BubblePinch': 0.45},
      );
      expect(pcmWater.length, greaterThan(100));
      expect(pcmWater.any((s) => s.abs() > 0.05), isTrue);

      final pcmRain = LuaEngine.synthesizeBuffer(
        code: rainPreset!.code,
        durationSec: 0.2,
        freq: 440.0,
        note: 69,
        params: {'RainIntensity': 0.7, 'RainHiss': 0.5},
      );
      expect(pcmRain.length, greaterThan(100));
      expect(pcmRain.any((s) => s.abs() > 0.03), isTrue);
    });

    test('PhaserNode creates phase-shifted comb cancellations within [-1.0, 1.0]', () {
      const sine = SineOscNode(staticFreq: 220.0);
      const phaser = PhaserNode(
        input: sine,
        rate: 0.5,
        depth: 0.75,
        feedback: 0.40,
        mix: 0.50,
      );
      final ctx = GraphContext(
        durationSec: 0.1,
        freq: 220.0,
        midiNote: 57,
      );
      final buffer = Float32List(ctx.totalSamples);
      phaser.process(ctx, buffer);

      expect(buffer.length, greaterThan(100));
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('Elemental Trio renders bass notes (C2 = 65.4Hz) with active phaser modulation', () {
      final voltsRoot = GraphEvaluator.buildVoltaicPlasmaSynth();
      final fireRoot = GraphEvaluator.buildPyrophoneSynth();
      final waterRoot = GraphEvaluator.buildEatsWaterSynth();

      const c2Freq = 65.41; // C2 (MIDI 36)
      const c2Note = 36;

      for (final root in [voltsRoot, fireRoot, waterRoot]) {
        final buffer = GraphEvaluator.evaluate(
          root: root,
          durationSec: 0.25,
          freq: c2Freq,
          note: c2Note,
          params: {
            'PhaserRate': 0.65,
            'PhaserDepth': 0.75,
            'PhaserFeedback': 0.50,
            'PhaserMix': 0.60,
          },
        );

        expect(buffer.length, greaterThan(100));
        for (final s in buffer) {
          expect(s.isNaN, isFalse);
          expect(s.isInfinite, isFalse);
          expect(s, inInclusiveRange(-1.0, 1.0));
        }
        expect(buffer.any((s) => s.abs() > 0.05), isTrue);
      }
    });

    test('ColoredNoiseNode produces valid signals for White, Pink, Brown, and Blue noise colors', () {
      final ctx = GraphContext(durationSec: 0.1, freq: 440.0, midiNote: 69);
      final outBuf = Float32List(ctx.totalSamples);

      for (final col in NoiseColor.values) {
        ColoredNoiseNode(color: col).process(ctx, outBuf);
        expect(outBuf.any((s) => s != 0.0), isTrue);
        for (final s in outBuf) {
          expect(s.isNaN, isFalse);
          expect(s.isInfinite, isFalse);
          expect(s, inInclusiveRange(-1.0, 1.0));
        }
      }
    });

    test('ChaoticGustLfoNode generates bounded, continuous drift modulation', () {
      final ctx = GraphContext(durationSec: 0.2, freq: 440.0, midiNote: 60);
      final outBuf = Float32List(ctx.totalSamples);
      const gust = ChaoticGustLfoNode(baseRate: 0.5, gustiness: 0.7);

      gust.process(ctx, outBuf);
      for (final s in outBuf) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(0.0, 1.0));
      }
      expect(outBuf.any((s) => s > 0.1), isTrue);
    });

    test('PoissonImpulseGrainNode generates stochastic grains for all GrainTypes', () {
      final ctx = GraphContext(durationSec: 0.15, freq: 440.0, midiNote: 60);
      final outBuf = Float32List(ctx.totalSamples);

      for (final type in GrainType.values) {
        PoissonImpulseGrainNode(grainType: type, density: 0.8, energy: 0.9).process(ctx, outBuf);
        expect(outBuf.any((s) => s.abs() > 0.05), isTrue, reason: 'GrainType $type emitted no grains');
        for (final s in outBuf) {
          expect(s.isNaN, isFalse);
          expect(s.isInfinite, isFalse);
          expect(s, inInclusiveRange(-1.0, 1.0));
        }
      }
    });

    test('ModalCavityBankNode and AcousticPropagationNode process cleanly without artifacts', () {
      final ctx = GraphContext(durationSec: 0.1, freq: 440.0, midiNote: 60);
      const noise = ColoredNoiseNode(color: NoiseColor.pink);
      const cavity = ModalCavityBankNode(input: noise, surfaceType: CavitySurfaceType.tinRoof);
      const prop = AcousticPropagationNode(input: cavity, distanceMeters: 500.0, dispersion: 0.6);

      final outBuf = Float32List(ctx.totalSamples);
      prop.process(ctx, outBuf);

      expect(outBuf.any((s) => s.abs() > 0.01), isTrue);
      for (final s in outBuf) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('Environmental Synthesizer Suite renders valid PCM across all 5 instruments', () {
      final furnace = GraphEvaluator.buildEatsFurnaceSynth();
      final rain = GraphEvaluator.buildEatsRainSynth();
      final wind = GraphEvaluator.buildEatsWindSynth();
      final fire = GraphEvaluator.buildEatsFireSynth();
      final thunder = GraphEvaluator.buildEatsThunderSynth();

      for (final entry in {
        'Furnace': furnace,
        'Rain': rain,
        'Wind': wind,
        'Fire': fire,
        'Thunder': thunder,
      }.entries) {
        final pcm = GraphEvaluator.evaluate(
          root: entry.value,
          durationSec: 0.2,
          freq: 220.0,
          note: 57,
          params: const {},
        );

        expect(pcm.length, greaterThan(100));
        expect(pcm.any((s) => s.abs() > 0.02), isTrue, reason: '${entry.key} emitted silence');
        for (final s in pcm) {
          expect(s.isNaN, isFalse);
          expect(s.isInfinite, isFalse);
          expect(s, inInclusiveRange(-1.0, 1.0));
        }
      }
    });

    test('GM Instrument Registry resolves environmental tracks to native presets', () {
      final rainRes = GmInstrumentRegistry.resolve(trackName: 'Heavy Rain');
      expect(rainRes.isNative, isTrue);
      expect(rainRes.presetId, equals('eats_rain'));

      final windRes = GmInstrumentRegistry.resolve(trackName: 'Mountain Wind');
      expect(windRes.isNative, isTrue);
      expect(windRes.presetId, equals('eats_wind'));

      final fireRes = GmInstrumentRegistry.resolve(trackName: 'Campfire Hearth');
      expect(fireRes.isNative, isTrue);
      expect(fireRes.presetId, equals('eats_fire'));

      final thunderRes = GmInstrumentRegistry.resolve(trackName: 'Rolling Thunder');
      expect(thunderRes.isNative, isTrue);
      expect(thunderRes.presetId, equals('eats_thunder'));

      final furnaceRes = GmInstrumentRegistry.resolve(trackName: 'Blast Furnace');
      expect(furnaceRes.isNative, isTrue);
      expect(furnaceRes.presetId, equals('eats_furnace'));
    });
  });
}




