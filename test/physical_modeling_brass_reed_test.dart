import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/audio/gm/gm_instrument_registry.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Physical Modeling Synthesis - Brass Family (GM 56-61)', () {
    test('Orchestral Trumpet synthesizes stable audio buffer with zero NaN/Inf', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildOrchestralTrumpet(),
        durationSec: 0.35,
        freq: 440.0,
        note: 69,
        params: {},
        velocity: 0.9,
      );

      expect(buffer.length, greaterThan(1000));
      double maxAbs = 0.0;
      for (final sample in buffer) {
        expect(sample.isNaN, isFalse, reason: 'Sample must not be NaN');
        expect(sample.isInfinite, isFalse, reason: 'Sample must not be Infinite');
        maxAbs = math.max(maxAbs, sample.abs());
      }
      expect(maxAbs, greaterThan(0.05), reason: 'Audio buffer must contain audible signal');
      expect(maxAbs, lessThanOrEqualTo(1.05), reason: 'Audio buffer should be clamped/normalized');
    });

    test('Tenor Trombone synthesizes low-register brass notes stably', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildTenorTrombone(),
        durationSec: 0.35,
        freq: 110.0, // A2
        note: 45,
        params: {},
        velocity: 0.85,
      );

      expect(buffer.length, greaterThan(1000));
      double maxAbs = 0.0;
      for (final sample in buffer) {
        expect(sample.isNaN, isFalse);
        expect(sample.isInfinite, isFalse);
        maxAbs = math.max(maxAbs, sample.abs());
      }
      expect(maxAbs, greaterThan(0.05));
    });

    test('Tuba synthesizes deep bass notes stably', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildTuba(),
        durationSec: 0.35,
        freq: 55.0, // A1
        note: 33,
        params: {},
        velocity: 0.95,
      );

      expect(buffer.length, greaterThan(1000));
      double maxAbs = 0.0;
      for (final sample in buffer) {
        expect(sample.isNaN, isFalse);
        expect(sample.isInfinite, isFalse);
        maxAbs = math.max(maxAbs, sample.abs());
      }
      expect(maxAbs, greaterThan(0.05));
    });

    test('Muted Trumpet synthesizes Harmon mute timbre stably', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildMutedTrumpet(),
        durationSec: 0.35,
        freq: 587.33, // D5
        note: 74,
        params: {},
        velocity: 0.85,
      );

      expect(buffer.length, greaterThan(1000));
      double maxAbs = 0.0;
      for (final sample in buffer) {
        expect(sample.isNaN, isFalse);
        expect(sample.isInfinite, isFalse);
        maxAbs = math.max(maxAbs, sample.abs());
      }
      expect(maxAbs, greaterThan(0.05));
    });

    test('French Horn and Brass Section synthesize rich resonance stably', () {
      for (final builder in [
        GraphEvaluator.buildFrenchHorn,
        GraphEvaluator.buildBrassSection,
      ]) {
        final buffer = GraphEvaluator.evaluate(
          root: builder(),
          durationSec: 0.35,
          freq: 349.23, // F4
          note: 65,
          params: {},
          velocity: 0.85,
        );

        expect(buffer.length, greaterThan(1000));
        double maxAbs = 0.0;
        for (final sample in buffer) {
          expect(sample.isNaN, isFalse);
          expect(sample.isInfinite, isFalse);
          maxAbs = math.max(maxAbs, sample.abs());
        }
        expect(maxAbs, greaterThan(0.05));
      }
    });
  });

  group('Physical Modeling Synthesis - Reed Family (GM 64-71)', () {
    test('Clarinet synthesizes odd-harmonic cylindrical bore stably', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildClarinet(),
        durationSec: 0.35,
        freq: 261.63, // Middle C (C4)
        note: 60,
        params: {},
        velocity: 0.85,
      );

      expect(buffer.length, greaterThan(1000));
      double maxAbs = 0.0;
      for (final sample in buffer) {
        expect(sample.isNaN, isFalse);
        expect(sample.isInfinite, isFalse);
        maxAbs = math.max(maxAbs, sample.abs());
      }
      expect(maxAbs, greaterThan(0.05));
    });

    test('Saxophones (Soprano, Alto, Tenor, Baritone) synthesize conical reed timbre stably', () {
      final saxBuilders = [
        GraphEvaluator.buildSopranoSax,
        GraphEvaluator.buildAltoSax,
        GraphEvaluator.buildTenorSax,
        GraphEvaluator.buildBaritoneSax,
      ];

      for (final builder in saxBuilders) {
        final buffer = GraphEvaluator.evaluate(
          root: builder(),
          durationSec: 0.30,
          freq: 329.63, // E4
          note: 64,
          params: {},
          velocity: 0.88,
        );

        expect(buffer.length, greaterThan(1000));
        double maxAbs = 0.0;
        for (final sample in buffer) {
          expect(sample.isNaN, isFalse);
          expect(sample.isInfinite, isFalse);
          maxAbs = math.max(maxAbs, sample.abs());
        }
        expect(maxAbs, greaterThan(0.05));
      }
    });

    test('Double Reeds (Oboe, English Horn, Bassoon) synthesize nasal formant stably', () {
      final doubleReedBuilders = [
        GraphEvaluator.buildOboe,
        GraphEvaluator.buildEnglishHorn,
        GraphEvaluator.buildBassoon,
      ];

      for (final builder in doubleReedBuilders) {
        final buffer = GraphEvaluator.evaluate(
          root: builder(),
          durationSec: 0.30,
          freq: 220.0, // A3
          note: 57,
          params: {},
          velocity: 0.85,
        );

        expect(buffer.length, greaterThan(1000));
        double maxAbs = 0.0;
        for (final sample in buffer) {
          expect(sample.isNaN, isFalse);
          expect(sample.isInfinite, isFalse);
          maxAbs = math.max(maxAbs, sample.abs());
        }
        expect(maxAbs, greaterThan(0.05));
      }
    });
  });

  group('Physical Modeling Synthesis - Sitar Jawari (GM 104)', () {
    test('Sitar synthesizes buzzing jawari non-linear bridge with sympathetic tarafs', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSitar(),
        durationSec: 0.40,
        freq: 146.83, // D3
        note: 50,
        params: {'JawariBuzz': 0.80, 'SympatheticTaraf': 0.65},
        velocity: 0.90,
      );

      expect(buffer.length, greaterThan(1000));
      double maxAbs = 0.0;
      for (final sample in buffer) {
        expect(sample.isNaN, isFalse);
        expect(sample.isInfinite, isFalse);
        maxAbs = math.max(maxAbs, sample.abs());
      }
      expect(maxAbs, greaterThan(0.05));
    });
  });

  group('General MIDI Registry Resolution for Physical Models', () {
    test('GM Brass instruments (56-61) resolve to native physical model presets', () {
      final brassPrograms = [56, 57, 58, 59, 60, 61];
      for (final prog in brassPrograms) {
        final def = GmInstrumentRegistry.spec[prog];
        expect(def.isNativeSupported, isTrue, reason: 'Program $prog (${def.gmName}) must be natively supported');
        expect(def.nativePresetId, isNotNull);

        final result = GmInstrumentRegistry.resolve(
          trackName: def.gmName,
          programNumber: prog,
        );
        expect(result.isNative, isTrue, reason: 'Track resolution for program $prog must be native');
        expect(result.presetId, equals(def.nativePresetId));
      }
    });

    test('GM Reed instruments (64-71) resolve to native physical model presets', () {
      final reedPrograms = [64, 65, 66, 67, 68, 69, 70, 71];
      for (final prog in reedPrograms) {
        final def = GmInstrumentRegistry.spec[prog];
        expect(def.isNativeSupported, isTrue, reason: 'Program $prog (${def.gmName}) must be natively supported');
        expect(def.nativePresetId, isNotNull);

        final result = GmInstrumentRegistry.resolve(
          trackName: def.gmName,
          programNumber: prog,
        );
        expect(result.isNative, isTrue, reason: 'Track resolution for program $prog must be native');
        expect(result.presetId, equals(def.nativePresetId));
      }
    });

    test('GM Sitar (104) resolves to sitar_jawari native preset', () {
      final def = GmInstrumentRegistry.spec[104];
      expect(def.isNativeSupported, isTrue);
      expect(def.nativePresetId, equals('sitar_jawari'));

      final result = GmInstrumentRegistry.resolve(
        trackName: 'Sitar Track',
        programNumber: 104,
      );
      expect(result.isNative, isTrue);
      expect(result.presetId, equals('sitar_jawari'));
    });

    test('LuaPresetLibrary contains all new physical model presets', () {
      final requiredPresets = [
        'orchestral_trumpet',
        'tenor_trombone',
        'tuba_brass',
        'muted_trumpet',
        'french_horn',
        'brass_section',
        'soprano_sax',
        'alto_sax',
        'tenor_sax',
        'baritone_sax',
        'oboe_woodwind',
        'english_horn',
        'bassoon_woodwind',
        'clarinet_woodwind',
        'sitar_jawari',
      ];

      for (final presetId in requiredPresets) {
        final preset = LuaPresetLibrary.getPresetById(presetId);
        expect(preset, isNotNull, reason: 'Preset $presetId must be registered in LuaPresetLibrary');
        expect(preset!.code, isNotEmpty);
      }
    });
  });
}
