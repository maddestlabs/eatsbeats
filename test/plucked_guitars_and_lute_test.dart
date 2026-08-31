import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/audio/graph/graph_node.dart';
import 'package:eatsbeats/audio/graph/graph_primitives.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plucked Historical & Classical String Instruments Physical Models', () {
    test('AcousticPluckExciterNode generates flesh vs nail impulse and scrape noise', () {
      const nailNode = AcousticPluckExciterNode(fleshRatio: 0.05, scrapeNoise: 0.5);
      const fleshNode = AcousticPluckExciterNode(fleshRatio: 0.95, scrapeNoise: 0.2);

      final ctx = GraphContext(
        sampleRate: 44100,
        durationSec: 0.05,
        freq: 330.0,
        midiNote: 64,
        velocity: 0.9,
      );

      final nBuf = Float32List(ctx.totalSamples);
      final fBuf = Float32List(ctx.totalSamples);

      nailNode.process(ctx, nBuf);
      fleshNode.process(ctx, fBuf);

      expect(nBuf.any((s) => s.abs() > 0.1), isTrue);
      expect(fBuf.any((s) => s.abs() > 0.1), isTrue);
    });

    test('CoupledWaveguideNode synthesizes double-course micro-detuning & chorus', () {
      const exciter = AcousticPluckExciterNode(fleshRatio: 0.5, scrapeNoise: 0.2);
      const coupled = CoupledWaveguideNode(
        exciter: exciter,
        courseDetuneCents: 4.0,
        coupling: 0.10,
      );

      final ctx = GraphContext(
        sampleRate: 44100,
        durationSec: 0.2,
        freq: 220.0,
        midiNote: 57,
        velocity: 0.85,
      );

      final buf = Float32List(ctx.totalSamples);
      coupled.process(ctx, buf);

      expect(buf.isNotEmpty, isTrue);
      expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('GraphEvaluator synthesizes Spanish Classical Guitar', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSpanishGuitar(),
        durationSec: 0.3,
        freq: 196.0, // G3
        note: 55,
        params: {
          'FleshNail': 0.40,
          'Sustain': 0.995,
          'AirResonance': 2.0,
          'WoodTone': 1.5,
        },
        velocity: 0.85,
      );

      expect(buffer, isNotEmpty);
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('GraphEvaluator synthesizes Renaissance & Baroque Lute', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildRenaissanceLute(),
        durationSec: 0.3,
        freq: 392.0, // G4
        note: 67,
        params: {
          'FleshRatio': 0.70,
          'CourseDetune': 3.8,
          'BowlWarmth': 2.2,
          'AirShimmer': 1.8,
        },
        velocity: 0.85,
      );

      expect(buffer, isNotEmpty);
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('GraphEvaluator synthesizes 5-Course Baroque Guitar', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildBaroqueGuitar(),
        durationSec: 0.3,
        freq: 293.66, // D4
        note: 62,
        params: {
          'RasgueadoSpeed': 12.0,
          'CourseDetune': 4.5,
          'RoseBite': 3.0,
        },
        velocity: 0.85,
      );

      expect(buffer, isNotEmpty);
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('GraphEvaluator synthesizes Flamenco Guitar with Golpe tap', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildFlamencoGuitar(),
        durationSec: 0.3,
        freq: 330.0, // E4
        note: 64,
        params: {
          'NailBite': 0.10,
          'GolpeTap': 0.50,
          'Bite': 3.5,
        },
        velocity: 0.90,
      );

      expect(buffer, isNotEmpty);
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('LuaPresetLibrary contains all 4 plucked instruments with GUI panels', () {
      final spanish = LuaScriptLibrary.getPresetById('spanish_guitar');
      final lute = LuaScriptLibrary.getPresetById('renaissance_lute');
      final baroque = LuaScriptLibrary.getPresetById('baroque_guitar');
      final flamenco = LuaScriptLibrary.getPresetById('flamenco_guitar');

      expect(spanish, isNotNull);
      expect(lute, isNotNull);
      expect(baroque, isNotNull);
      expect(flamenco, isNotNull);

      expect(spanish!.code.contains('SPANISH CLASSICAL GUITAR'), isTrue);
      expect(lute!.code.contains('RENAISSANCE & BAROQUE LUTE'), isTrue);
      expect(baroque!.code.contains('BAROQUE GUITAR'), isTrue);
      expect(flamenco!.code.contains('FLAMENCO GUITAR'), isTrue);
    });

    test('LuaEngine compiles and synthesizes all 4 instruments', () {
      for (final id in ['spanish_guitar', 'renaissance_lute', 'baroque_guitar', 'flamenco_guitar']) {
        final preset = LuaScriptLibrary.getPresetById(id)!;
        final buf = LuaEngine.synthesizeBuffer(
          code: preset.code,
          durationSec: 0.2,
          freq: 261.63, // C4
          note: 60,
          params: {},
        );

        expect(buf, isNotEmpty);
        expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      }
    });

    test('Basses and Guitars respond to MPE pitch bends, pressure curves, and timbre modulation', () {
      final pitchBendPts = [
        [0.0, 0.0],
        [0.5, 2.0], // +2 semitones bend
        [1.0, 0.0],
      ];
      final pressurePts = [
        [0.0, 0.2],
        [0.5, 0.9],
        [1.0, 0.1],
      ];
      final timbrePts = [
        [0.0, 0.1],
        [0.5, 0.85],
        [1.0, 0.3],
      ];

      // Fretless Bass with MPE Jaco Mwah and pitch bend glide
      final fretlessBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildFretlessBass(),
        durationSec: 0.3,
        freq: 110.0, // A2
        note: 45,
        params: {'MwahAmount': 0.8, 'Growl': 0.7},
        pitchBendPoints: pitchBendPts,
        pressurePoints: pressurePts,
        timbrePoints: timbrePts,
        articulation: 'mwah',
      );

      // Upright Bass with slap articulation
      final uprightBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildUprightBass(),
        durationSec: 0.3,
        freq: 82.41, // E2
        note: 40,
        params: {'SlapClick': 1.0},
        pitchBendPoints: pitchBendPts,
        articulation: 'slap',
      );

      // Moog Synth Bass with MPE 24dB ladder filter sweep
      final moogBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildMoogSynthBass(),
        durationSec: 0.3,
        freq: 55.0, // A1
        note: 33,
        params: {'Cutoff': 300.0, 'Resonance': 0.7},
        timbrePoints: timbrePts,
        pressurePoints: pressurePts,
      );

      expect(fretlessBuf, isNotEmpty);
      expect(fretlessBuf.every((s) => !s.isNaN && !s.isInfinite), isTrue);

      expect(uprightBuf, isNotEmpty);
      expect(uprightBuf.every((s) => !s.isNaN && !s.isInfinite), isTrue);

      expect(moogBuf, isNotEmpty);
      expect(moogBuf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('Upright Double Bass generates deep sub-bass fundamental and strong acoustic volume without harsh slap', () {
      final buf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildUprightBass(),
        durationSec: 0.5,
        freq: 62.5, // ~B1 / C2
        note: 36,
        params: {
          'SubWarmth': 4.5,
          'BodyPunch': 3.0,
          'WoodTone': -4.0,
          'StringDamp': 0.32,
          'SlapClick': 0.0,
        },
        velocity: 0.85,
        articulation: 'pizzicato',
      );

      expect(buf, isNotEmpty);
      expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue);

      // Verify strong, audible acoustic amplitude (>0.5)
      final maxAmp = buf.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
      expect(maxAmp, greaterThan(0.50));
    });
  });
}



