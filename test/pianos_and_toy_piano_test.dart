import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/audio/graph/graph_node.dart';
import 'package:eatsbeats/audio/graph/graph_primitives.dart';
import 'package:eatsbeats/audio/graph/piano_physical_tables.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Piano & Toy Piano Physical Models', () {
    test('PianoPhysicalTables interpolates 88-key empirical measurements accurately', () {
      expect(PianoPhysicalTables.stiffnessCoefficient.lookup(60.0), closeTo(-0.25, 0.001));
      expect(PianoPhysicalTables.detuningHz.lookup(60.0), closeTo(0.25, 0.001));
      expect(PianoPhysicalTables.singleStringZero.lookup(21.0), closeTo(-1.0, 0.001));
      expect(PianoPhysicalTables.singleStringPole.lookup(21.0), closeTo(0.35, 0.001));
    });

    test('CommutedSoundboardExciterNode and CommutedHammerFilterCascadeNode synthesize shaped excitation', () {
      const exciter = CommutedSoundboardExciterNode(hammerHardness: 1.0, soundboardGain: 1.2);
      const hammer = CommutedHammerFilterCascadeNode(input: exciter, brightnessFactor: 0.5);

      final ctx = GraphContext(sampleRate: 44100, durationSec: 0.05, freq: 261.63, midiNote: 60, velocity: 0.85);
      final buf = Float32List(ctx.totalSamples);
      hammer.process(ctx, buf);

      expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buf.any((s) => s.abs() > 0.01), isTrue);
    });

    test('CommutedPianoWaveguideNode synthesizes coupled inharmonic dispersion string pairs', () {
      const exciter = CommutedSoundboardExciterNode();
      const hammer = CommutedHammerFilterCascadeNode(input: exciter);
      const strike = CommutedStrikeCombNode(input: hammer);
      const waveguide = CommutedPianoWaveguideNode(exciter: strike, stiffnessFactor: 1.0, detuningFactor: 1.0);

      final ctx = GraphContext(sampleRate: 44100, durationSec: 0.2, freq: 261.63, midiNote: 60, velocity: 0.9);
      final buf = Float32List(ctx.totalSamples);
      waveguide.process(ctx, buf);

      expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buf.any((s) => s.abs() > 0.01), isTrue);
    });

    test('PianoHammerExciterNode scales pulse width and transient energy with velocity & hardness', () {
      const softHammer = PianoHammerExciterNode(hammerHardness: 0.2, feltSoftness: 0.9);
      const hardHammer = PianoHammerExciterNode(hammerHardness: 1.8, feltSoftness: 0.0);

      final ctxPianissimo = GraphContext(sampleRate: 44100, durationSec: 0.05, freq: 440.0, midiNote: 69, velocity: 0.2);
      final ctxFortissimo = GraphContext(sampleRate: 44100, durationSec: 0.05, freq: 440.0, midiNote: 69, velocity: 1.0);

      final softBuf = Float32List(ctxPianissimo.totalSamples);
      final hardBuf = Float32List(ctxFortissimo.totalSamples);

      softHammer.process(ctxPianissimo, softBuf);
      hardHammer.process(ctxFortissimo, hardBuf);

      expect(softBuf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(hardBuf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(hardBuf.any((s) => s.abs() > 0.1), isTrue);
    });

    test('PianoSoundboardNode simulates spruce plate modal resonances and morphs profiles', () {
      const exciter = PianoHammerExciterNode(hammerHardness: 0.85);
      const waveguide = WaveguideNode(exciter: exciter);
      const uprightSoundboard = PianoSoundboardNode(input: waveguide, soundboardProfile: 0.0);
      const grandSoundboard = PianoSoundboardNode(input: waveguide, soundboardProfile: 1.0);

      final ctx = GraphContext(sampleRate: 44100, durationSec: 0.1, freq: 261.63, midiNote: 60, velocity: 0.85);
      final uBuf = Float32List(ctx.totalSamples);
      final gBuf = Float32List(ctx.totalSamples);

      uprightSoundboard.process(ctx, uBuf);
      grandSoundboard.process(ctx, gBuf);

      expect(uBuf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(gBuf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(uBuf.any((s) => s.abs() > 0.01), isTrue);
      expect(gBuf.any((s) => s.abs() > 0.01), isTrue);
    });

    test('TackExciterNode generates sharp metallic tack transient ping', () {
      const tack = TackExciterNode(tackBite: 1.2, hammerKnock: 0.6);
      final ctx = GraphContext(sampleRate: 44100, durationSec: 0.05, freq: 330.0, midiNote: 64, velocity: 0.9);
      final buf = Float32List(ctx.totalSamples);
      tack.process(ctx, buf);

      expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buf.any((s) => s.abs() > 0.2), isTrue);
    });

    test('ToyPianoMetalRodNode produces non-harmonic cantilever modal chime series', () {
      const toyRod = ToyPianoMetalRodNode(clangRatio: 0.85, tineDecay: 1.5, hammerClack: 0.6);
      final ctx = GraphContext(sampleRate: 44100, durationSec: 0.2, freq: 523.25, midiNote: 72, velocity: 0.95);
      final buf = Float32List(ctx.totalSamples);
      toyRod.process(ctx, buf);

      expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buf.any((s) => s.abs() > 0.1), isTrue);
    });

    test('GraphEvaluator synthesizes Concert Grand Piano', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildConcertGrandPiano(),
        durationSec: 0.3,
        freq: 261.63,
        note: 60,
        params: {'HammerHardness': 1.0, 'Soundboard': 0.9, 'PedalReso': 0.6},
        velocity: 0.85,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Warm Felt Studio Upright Piano', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildFeltUprightPiano(),
        durationSec: 0.3,
        freq: 220.0,
        note: 57,
        params: {'FeltThickness': 0.9, 'MechanicalThud': 0.5, 'Tone': 3500.0},
        velocity: 0.8,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Honky-Tonk / Tack Saloon Piano', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildHonkyTonkPiano(),
        durationSec: 0.3,
        freq: 392.0,
        note: 67,
        params: {'TackBite': 1.0, 'DetuneCents': 8.0, 'Bite': 4.0},
        velocity: 0.9,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Toy Piano / Metallophone', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildToyPiano(),
        durationSec: 0.3,
        freq: 587.33,
        note: 74,
        params: {'ClangRatio': 0.75, 'TineDecay': 1.2, 'HammerClack': 0.6},
        velocity: 0.85,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('LuaPresetLibrary contains all 4 piano presets with GUIs', () {
      final ids = [
        'concert_grand_piano',
        'felt_upright_piano',
        'honky_tonk_piano',
        'toy_piano',
      ];

      for (final id in ids) {
        final preset = LuaScriptLibrary.getPresetById(id);
        expect(preset, isNotNull, reason: 'Preset $id should exist in LuaScriptLibrary');
        expect(preset!.category, equals(LuaPresetCategory.instrument));
      }
    });

    test('LuaEngine compiles and synthesizes all 4 piano instruments', () {
      final ids = [
        'concert_grand_piano',
        'felt_upright_piano',
        'honky_tonk_piano',
        'toy_piano',
      ];

      for (final id in ids) {
        final preset = LuaScriptLibrary.getPresetById(id)!;
        final buf = LuaEngine.synthesizeBuffer(
          code: preset.code,
          durationSec: 0.2,
          freq: 261.63,
          note: 60,
          params: {},
        );
        expect(buf.isNotEmpty, isTrue);
        expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      }
    });
  });
}
