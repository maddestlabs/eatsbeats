import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/audio/graph/graph_primitives.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/lua/lua_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tuned Percussion & Revamped Toy Piano Physical Models', () {
    test('GraphEvaluator synthesizes Revamped Toy Piano with micro-bounce and release drop', () {
      final bufferWithBounce = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildToyPiano(),
        durationSec: 0.35,
        freq: 587.33,
        note: 74,
        params: {
          'ClangRatio': 0.75,
          'TineDecay': 1.2,
          'HammerClack': 0.6,
          'HammerBounce': 0.8,
          'ReleaseDrop': 0.5,
          'BoxResonance': 0.5,
        },
        velocity: 0.85,
        releaseVelocity: 0.7,
      );

      expect(bufferWithBounce.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(bufferWithBounce.any((s) => s.abs() > 0.05), isTrue);

      // Verify micro-bounce flam transient around 20-25ms
      final sampleRate = 44100.0;
      final flamSampleIdx = (0.022 * sampleRate).toInt();
      // Ensure buffer has dynamic activity after the bounce point
      double postBounceEnergy = 0.0;
      for (int i = flamSampleIdx; i < flamSampleIdx + 200; i++) {
        postBounceEnergy += bufferWithBounce[i].abs();
      }
      expect(postBounceEnergy, greaterThan(0.5));
    });

    test('GraphEvaluator synthesizes Orchestral Glockenspiel', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildGlockenspiel(),
        durationSec: 0.4,
        freq: 1046.50, // C6
        note: 84,
        params: {
          'BarDecay': 3.5,
          'BellShimmer': 0.8,
          'MalletHardness': 0.9,
          'AirSheen': 3.0,
        },
        velocity: 0.9,
      );

      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Antique Music Box', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildMusicBox(),
        durationSec: 0.4,
        freq: 523.25, // C5
        note: 72,
        params: {
          'TineDecay': 2.2,
          'PinScrape': 0.6,
          'BoxWarmth': 0.55,
          'HighTineRing': 0.6,
        },
        velocity: 0.8,
      );

      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Orchestral Xylophone (Rosewood triple-octave)', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildXylophone(),
        durationSec: 0.25,
        freq: 659.25, // E5
        note: 76,
        params: {
          'WoodDecay': 0.28,
          'ResonatorPop': 0.7,
          'MalletHardness': 0.8,
          'TripleOctave': 0.6,
        },
        velocity: 0.85,
      );

      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Orchestral Vibraphone (Double-octave + Motor Tremolo)', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildVibraphone(),
        durationSec: 0.5,
        freq: 440.0, // A4
        note: 69,
        params: {
          'BarDecay': 4.0,
          'MotorSpeed': 5.0,
          'TremoloDepth': 0.7,
          'DoubleOctave': 0.45,
          'YarnSoftness': 0.6,
        },
        velocity: 0.8,
      );

      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('LuaScriptLibrary contains all 5 instruments with metadata and valid GUIs', () {
      final ids = [
        'toy_piano',
        'glockenspiel',
        'music_box',
        'xylophone',
        'vibraphone',
      ];

      for (final id in ids) {
        final preset = LuaScriptLibrary.getPresetById(id);
        expect(preset, isNotNull, reason: 'Preset $id should exist in LuaScriptLibrary');
        expect(preset!.category, equals(LuaPresetCategory.instrument));
        expect(preset.code.isNotEmpty, isTrue);

        // Verify matching logic
        final matched = LuaScriptLibrary.findMatchingPreset(preset.code);
        expect(matched?.id, equals(id), reason: 'findMatchingPreset should find $id');
      }
    });

    test('LuaEngine compiles and synthesizes all 5 instruments through dispatch', () {
      final ids = [
        'toy_piano',
        'glockenspiel',
        'music_box',
        'xylophone',
        'vibraphone',
      ];

      for (final id in ids) {
        final preset = LuaScriptLibrary.getPresetById(id)!;
        final buf = LuaEngine.synthesizeBuffer(
          code: preset.code,
          durationSec: 0.25,
          freq: 440.0,
          note: 69,
          params: {},
          velocity: 0.8,
        );
        expect(buf.isNotEmpty, isTrue);
        expect(buf.every((s) => !s.isNaN && !s.isInfinite), isTrue,
            reason: '$id buffer should not contain NaN or infinity');
        expect(buf.any((s) => s.abs() > 0.01), isTrue,
            reason: '$id buffer should have non-zero signal amplitude');
      }
    });
  });
}
