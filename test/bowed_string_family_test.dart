import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/lua/lua_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bowed String Family Physical Modeling & Presets Test', () {
    test('All 5 bowed string presets are registered in LuaScriptLibrary', () {
      final violin = LuaScriptLibrary.getPresetById('solo_violin');
      final viola = LuaScriptLibrary.getPresetById('solo_viola');
      final cello = LuaScriptLibrary.getPresetById('solo_cello');
      final bass = LuaScriptLibrary.getPresetById('double_bass');
      final ensemble = LuaScriptLibrary.getPresetById('string_ensemble');

      expect(violin, isNotNull);
      expect(viola, isNotNull);
      expect(cello, isNotNull);
      expect(bass, isNotNull);
      expect(ensemble, isNotNull);

      expect(violin!.name, contains('Solo Violin'));
      expect(viola!.name, contains('Solo Viola'));
      expect(cello!.name, contains('Solo Cello'));
      expect(bass!.name, contains('Double Bass'));
      expect(ensemble!.name, contains('String Ensemble'));
    });

    test('findMatchingPreset identifies bowed string signatures', () {
      expect(LuaScriptLibrary.findMatchingPreset('', fallbackName: 'Solo Violin')?.id, equals('solo_violin'));
      expect(LuaScriptLibrary.findMatchingPreset('', fallbackName: 'Solo Viola')?.id, equals('solo_viola'));
      expect(LuaScriptLibrary.findMatchingPreset('', fallbackName: 'Solo Cello')?.id, equals('solo_cello'));
      expect(LuaScriptLibrary.findMatchingPreset('', fallbackName: 'Orchestral Double Bass')?.id, equals('double_bass'));
      expect(LuaScriptLibrary.findMatchingPreset('', fallbackName: 'Symphonic String Ensemble')?.id, equals('string_ensemble'));
    });

    test('GraphEvaluator renders valid audio buffers for all bowed instruments', () {
      final violinBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSoloViolin(),
        durationSec: 0.5,
        freq: 440.0,
        note: 69,
        params: {'BowPressure': 1.0, 'BowSpeed': 1.0, 'BowPos': 0.5},
      );
      expect(violinBuf.length, greaterThan(0));
      expect(violinBuf.any((s) => s.abs() > 0.001), isTrue);

      final violaBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSoloViola(),
        durationSec: 0.5,
        freq: 220.0,
        note: 57,
        params: {'BowPressure': 1.1, 'ViolaWarmth': 2.0},
      );
      expect(violaBuf.length, greaterThan(0));
      expect(violaBuf.any((s) => s.abs() > 0.001), isTrue);

      final celloBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSoloCello(),
        durationSec: 0.5,
        freq: 110.0,
        note: 45,
        params: {'BowPressure': 1.25, 'ChestResonance': 3.5},
      );
      expect(celloBuf.length, greaterThan(0));
      expect(celloBuf.any((s) => s.abs() > 0.001), isTrue);

      final bassBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildDoubleBass(),
        durationSec: 0.5,
        freq: 55.0,
        note: 33,
        params: {'BowPressure': 1.45, 'SubPunch': 4.5},
      );
      expect(bassBuf.length, greaterThan(0));
      expect(bassBuf.any((s) => s.abs() > 0.001), isTrue);

      final ensembleBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildStringEnsemble(),
        durationSec: 0.5,
        freq: 330.0,
        note: 64,
        params: {'EnsembleChorus': 4.2, 'AirSheen': 2.0},
      );
      expect(ensembleBuf.length, greaterThan(0));
      expect(ensembleBuf.any((s) => s.abs() > 0.001), isTrue);
    });

    test('Per-note articulations generate distinct timbres in Solo Violin', () {
      final arcoBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSoloViolin(),
        durationSec: 0.3,
        freq: 440.0,
        note: 69,
        params: {},
        articulation: 'arco',
      );

      final pizzBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSoloViolin(),
        durationSec: 0.3,
        freq: 440.0,
        note: 69,
        params: {},
        articulation: 'pizz',
      );

      final snapBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSoloViolin(),
        durationSec: 0.3,
        freq: 440.0,
        note: 69,
        params: {},
        articulation: 'snap',
      );

      final ponticelloBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSoloViolin(),
        durationSec: 0.3,
        freq: 440.0,
        note: 69,
        params: {},
        articulation: 'ponticello',
      );

      final colLegnoBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSoloViolin(),
        durationSec: 0.3,
        freq: 440.0,
        note: 69,
        params: {},
        articulation: 'col_legno',
      );

      expect(arcoBuf, isNot(equals(pizzBuf)));
      expect(pizzBuf, isNot(equals(snapBuf)));
      expect(arcoBuf, isNot(equals(ponticelloBuf)));
      expect(arcoBuf, isNot(equals(colLegnoBuf)));
    });

    test('Viola and Cello produce distinctly different timbres at the same pitch', () {
      final violaBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSoloViola(),
        durationSec: 0.4,
        freq: 220.0,
        note: 57,
        params: {},
      );

      final celloBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildSoloCello(),
        durationSec: 0.4,
        freq: 220.0,
        note: 57,
        params: {},
      );

      // They must NOT be identical
      expect(violaBuf, isNot(equals(celloBuf)));

      // Measure sum of absolute differences to prove clear timbral divergence
      double diffSum = 0.0;
      for (int i = 0; i < violaBuf.length; i++) {
        diffSum += (violaBuf[i] - celloBuf[i]).abs();
      }
      expect(diffSum / violaBuf.length, greaterThan(0.015));
    });

    test('Upright Bass synthesizes with natural double bass body resonance and ebony slap', () {
      final normalPluck = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildUprightBass(),
        durationSec: 0.4,
        freq: 55.0,
        note: 33,
        params: {'SlapClick': 0.0},
        articulation: 'pizzicato',
      );

      final slapPluck = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildUprightBass(),
        durationSec: 0.4,
        freq: 55.0,
        note: 33,
        params: {'SlapClick': 1.0},
        articulation: 'slap',
      );

      expect(normalPluck.length, greaterThan(0));
      expect(normalPluck.any((s) => s.abs() > 0.001), isTrue);
      expect(slapPluck.length, greaterThan(0));
      expect(slapPluck, isNot(equals(normalPluck)));
    });

    test('LuaEngine processAudio synthesizes bowed string instruments via fast path', () {
      final violinPreset = LuaScriptLibrary.getPresetById('solo_violin')!;
      final buffer = LuaEngine.synthesizeBuffer(
        code: violinPreset.code,
        freq: 440.0,
        note: 69,
        params: {'BowPressure': 1.2, 'BowPos': 0.8},
        durationSec: 0.25,
        articulation: 'pizz',
      );

      expect(buffer.length, greaterThan(0));
      expect(buffer.any((s) => s.abs() > 0.001), isTrue);
    });
  });
}
