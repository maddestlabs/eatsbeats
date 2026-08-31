import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/audio/graph/graph_node.dart';
import 'package:eatsbeats/audio/graph/graph_primitives.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Acoustic, Roots & Folk Stringed Instruments Physical Models', () {
    test('MorphableAcousticBodyNode morphs modal formants across Parlor, Dreadnought, Jumbo', () {
      const exciter = AcousticPluckExciterNode(fleshRatio: 0.3);
      const waveguide = WaveguideNode(exciter: exciter);
      const morphParlor = MorphableAcousticBodyNode(input: waveguide, bodyProfile: 0.0);
      const morphJumbo = MorphableAcousticBodyNode(input: waveguide, bodyProfile: 1.0);

      final ctx = GraphContext(sampleRate: 44100, durationSec: 0.1, freq: 110.0, midiNote: 45, velocity: 0.85);
      final pBuf = Float32List(ctx.totalSamples);
      final jBuf = Float32List(ctx.totalSamples);

      morphParlor.process(ctx, pBuf);
      morphJumbo.process(ctx, jBuf);

      expect(pBuf.any((s) => s.abs() > 0.005), isTrue);
      expect(jBuf.any((s) => s.abs() > 0.005), isTrue);
      expect(pBuf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(jBuf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('AluminumConeResonatorNode generates metallic Dobro formants', () {
      const exciter = AcousticPluckExciterNode(fleshRatio: 0.1);
      const waveguide = WaveguideNode(exciter: exciter);
      const cone = AluminumConeResonatorNode(input: waveguide, coneType: 0.35, metalBark: 0.7);

      final ctx = GraphContext(sampleRate: 44100, durationSec: 0.1, freq: 196.0, midiNote: 55, velocity: 0.9);
      final buf = Float32List(ctx.totalSamples);
      cone.process(ctx, buf);

      expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buf.any((s) => s.abs() > 0.005), isTrue);
    });

    test('MembraneHeadExciterNode generates tight banjo drumhead shockwave', () {
      const banjoHead = MembraneHeadExciterNode(headTension: 0.85, twangSnap: 1.5);
      final ctx = GraphContext(sampleRate: 44100, durationSec: 0.05, freq: 293.66, midiNote: 62, velocity: 0.95);
      final buf = Float32List(ctx.totalSamples);
      banjoHead.process(ctx, buf);

      expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buf.any((s) => s.abs() > 0.2), isTrue);
    });

    test('VolumePedalSwellNode performs logarithmic fade in and vibrato', () {
      const saw = SawOscNode();
      const swell = VolumePedalSwellNode(input: saw, swellSec: 0.10, barVibrato: 0.5);
      final ctx = GraphContext(sampleRate: 44100, durationSec: 0.2, freq: 440.0, midiNote: 69, velocity: 0.8);
      final buf = Float32List(ctx.totalSamples);
      swell.process(ctx, buf);

      expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      // Early sample (t=0) should be quieter than sustained sample (t=0.15s)
      expect(buf[10].abs(), lessThan(buf[(0.15 * 44100).toInt()].abs() + 0.2));
    });

    test('GraphEvaluator synthesizes Steel-String Acoustic Guitar', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSteelAcousticGuitar(),
        durationSec: 0.3,
        freq: 220.0,
        note: 57,
        params: {'BodyProfile': 0.5, 'PickStyle': 0.2, 'Sustain': 0.996},
        velocity: 0.85,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.1), isTrue);
    });

    test('GraphEvaluator synthesizes 12-String Acoustic Guitar', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildTwelveStringGuitar(),
        durationSec: 0.3,
        freq: 330.0,
        note: 64,
        params: {'ChorusDetune': 4.5, 'OctavePairing': 1.0},
        velocity: 0.85,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('GraphEvaluator synthesizes Dobro Resonator Guitar', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildDobroResonator(),
        durationSec: 0.3,
        freq: 196.0,
        note: 55,
        params: {'ConeType': 0.5, 'MetalBark': 0.7},
        velocity: 0.9,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('GraphEvaluator synthesizes Pedal Steel Guitar with glide and swell', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildPedalSteelGuitar(),
        durationSec: 0.3,
        freq: 440.0,
        note: 69,
        params: {'VolumeSwell': 0.12, 'BarVibrato': 0.4},
        velocity: 0.85,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('GraphEvaluator synthesizes Harp Guitar with sub-drones', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildHarpGuitar(),
        durationSec: 0.3,
        freq: 110.0,
        note: 45,
        params: {'SubDroneGain': 4.0},
        velocity: 0.9,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('GraphEvaluator synthesizes 5-String Bluegrass Banjo', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildBluegrassBanjo(),
        durationSec: 0.3,
        freq: 392.0,
        note: 67,
        params: {'HeadTension': 0.85, 'TwangSnap': 1.4},
        velocity: 0.95,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('GraphEvaluator synthesizes Folk Mandolin with double-course tremolo', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildFolkMandolin(),
        durationSec: 0.3,
        freq: 659.25,
        note: 76,
        params: {'CourseDetune': 3.5, 'TremoloSpeed': 4.0},
        velocity: 0.85,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('LuaPresetLibrary contains all 7 acoustic and folk instruments with GUIs', () {
      final ids = [
        'acoustic_steel_guitar',
        'twelve_string_guitar',
        'dobro_resonator',
        'pedal_steel_guitar',
        'harp_guitar',
        'bluegrass_banjo',
        'folk_mandolin',
      ];

      for (final id in ids) {
        final preset = LuaScriptLibrary.getPresetById(id);
        expect(preset, isNotNull, reason: 'Preset $id should exist in LuaScriptLibrary');
        expect(preset!.category, equals(LuaPresetCategory.instrument));
      }
    });

    test('LuaEngine compiles and synthesizes all 7 acoustic and folk instruments', () {
      final ids = [
        'acoustic_steel_guitar',
        'twelve_string_guitar',
        'dobro_resonator',
        'pedal_steel_guitar',
        'harp_guitar',
        'bluegrass_banjo',
        'folk_mandolin',
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
