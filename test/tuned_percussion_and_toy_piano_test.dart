import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/audio/graph/graph_primitives.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/audio/gm/gm_instrument_registry.dart';

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

    test('GraphEvaluator synthesizes Suspended Tinkle Bell / Wind Chime', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildTinkleBell(),
        durationSec: 0.45,
        freq: 1046.50, // C6
        note: 84,
        params: {
          'ChimeDecay': 3.5,
          'BreezeFlutter': 0.7,
          'GlassAir': 0.8,
          'ClapperHardness': 0.75,
        },
        velocity: 0.85,
      );

      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);

      // Verify secondary breeze flutter activity around 28-35ms
      final sampleRate = 44100.0;
      final flutterSampleIdx = (0.028 * sampleRate).toInt();
      double flutterEnergy = 0.0;
      for (int i = flutterSampleIdx; i < flutterSampleIdx + 200; i++) {
        flutterEnergy += buffer[i].abs();
      }
      expect(flutterEnergy, greaterThan(0.5));
    });

    test('GraphEvaluator synthesizes Orchestral Woodblock (Slit Helmholtz cavity)', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildWoodblock(),
        durationSec: 0.20,
        freq: 800.0,
        note: 79,
        params: {
          'WoodDecay': 0.045,
          'CavityPop': 0.75,
          'WoodHardness': 0.80,
          'SlitTuning': 1.0,
        },
        velocity: 0.90,
      );

      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);

      // Verify dry staccato nature: tail after 80ms should be quiet (< 0.015)
      final sampleRate = 44100.0;
      final tailStartIdx = (0.080 * sampleRate).toInt();
      for (int i = tailStartIdx; i < buffer.length; i++) {
        expect(buffer[i].abs(), lessThan(0.015),
            reason: 'Woodblock should be dry and extinguish rapidly');
      }
    });

    test('GraphEvaluator synthesizes Agogo Bell (coupled plates)', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildAgogoBell(),
        durationSec: 0.35,
        freq: 587.33,
        note: 74,
        params: {'BellDecay': 0.75, 'ClangRatio': 0.65, 'StickHardness': 0.70},
        velocity: 0.85,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Steel Drums / Steelpan (harmonic quadrants)', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSteelDrums(),
        durationSec: 0.40,
        freq: 523.25,
        note: 72,
        params: {'PanDecay': 1.8, 'OctaveHarmonic': 0.6, 'BowlSympathy': 0.45},
        velocity: 0.85,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Taiko Drum (Bessel membrane & barrel boom)', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildTaikoDrum(),
        durationSec: 0.50,
        freq: 82.41,
        note: 40,
        params: {'DrumDecay': 1.6, 'PitchSag': 0.5, 'BachiImpact': 0.75, 'BarrelBoom': 0.65},
        velocity: 0.90,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Melodic Tom (dual-membrane shell)', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildMelodicTom(),
        durationSec: 0.35,
        freq: 164.81,
        note: 52,
        params: {'TomDecay': 0.85, 'HeadCoupling': 0.55, 'PitchBend': 0.40},
        velocity: 0.85,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Simmons SDS-V Synth Drum (pitch sweep & pad click)', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSimmonsSynthDrum(),
        durationSec: 0.40,
        freq: 130.81,
        note: 48,
        params: {'PitchDrop': 0.70, 'SweepTime': 0.14, 'ClickLevel': 0.65, 'ToneDecay': 0.80},
        velocity: 0.85,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('GraphEvaluator synthesizes Reverse Cymbal (inverted power-law crescendo)', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildReverseCymbal(),
        durationSec: 1.2,
        freq: 440.0,
        note: 69,
        params: {'SwellDuration': 0.8, 'CrescendoCurve': 2.2, 'ShimmerAir': 0.75, 'ChokeSnap': 0.60},
        velocity: 0.85,
      );
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);

      final sampleRate = 44100.0;
      final startSample = (0.10 * sampleRate).toInt();
      final peakSample = (0.75 * sampleRate).toInt();
      double earlyEnergy = 0.0;
      for (int i = startSample; i < startSample + 100; i++) earlyEnergy += buffer[i].abs();
      double peakEnergy = 0.0;
      for (int i = peakSample; i < peakSample + 100; i++) peakEnergy += buffer[i].abs();
      expect(peakEnergy, greaterThan(earlyEnergy));
    });

    test('LuaScriptLibrary contains all 13 percussion instruments with metadata and valid GUIs', () {
      final ids = [
        'toy_piano',
        'glockenspiel',
        'music_box',
        'xylophone',
        'vibraphone',
        'tinkle_bell',
        'agogo_bell',
        'steel_drums',
        'woodblock',
        'taiko_drum',
        'melodic_tom',
        'synth_drum',
        'reverse_cymbal',
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

    test('LuaEngine compiles and synthesizes all 13 percussion instruments through dispatch', () {
      final ids = [
        'toy_piano',
        'glockenspiel',
        'music_box',
        'xylophone',
        'vibraphone',
        'tinkle_bell',
        'agogo_bell',
        'steel_drums',
        'woodblock',
        'taiko_drum',
        'melodic_tom',
        'synth_drum',
        'reverse_cymbal',
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

    test('GmInstrumentRegistry resolves entire Percussive Family (GM 112 - 119) to native models', () {
      final expected = {
        112: 'tinkle_bell',
        113: 'agogo_bell',
        114: 'steel_drums',
        115: 'woodblock',
        116: 'taiko_drum',
        117: 'melodic_tom',
        118: 'synth_drum',
        119: 'reverse_cymbal',
      };

      for (final entry in expected.entries) {
        final result = GmInstrumentRegistry.resolve(programNumber: entry.key);
        expect(result.isNative, isTrue, reason: 'Program ${entry.key} should be native');
        expect(result.presetId, equals(entry.value), reason: 'Program ${entry.key} should map to ${entry.value}');
      }
    });
  });
}
