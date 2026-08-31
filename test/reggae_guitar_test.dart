import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/audio/graph/graph_node.dart';
import 'package:eatsbeats/audio/graph/graph_primitives.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reggae Skank & Dub Chop Guitar Physical Model', () {
    test('PlectrumStrumExciterNode generates multi-tap strum pulse with pick scrape', () {
      const node = PlectrumStrumExciterNode(strumSpreadMs: 10.0, pickBite: 1.5);
      final ctx = GraphContext(
        sampleRate: 44100,
        durationSec: 0.1,
        freq: 330.0,
        midiNote: 64,
        velocity: 0.9,
      );

      final fBuf = Float32List(ctx.totalSamples);
      node.process(ctx, fBuf);

      double maxVal = 0.0;
      for (final s in fBuf) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        if (s.abs() > maxVal) maxVal = s.abs();
      }
      expect(maxVal, greaterThan(0.2));
    });

    test('GraphEvaluator synthesizes clean Reggae Guitar chop buffer', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildReggaeGuitar(),
        durationSec: 0.3,
        freq: 330.0, // E4
        note: 64,
        params: {
          'StrumSpread': 8.0,
          'PickBite': 1.2,
          'PalmDamp': 0.40,
          'ChopDecay': 0.15,
          'Sustain': 0.994,
          'BiteGain': 4.0,
          'ToneCutoff': 6500.0,
          'Drive': 1.1,
        },
        velocity: 0.85,
      );

      expect(buffer, isNotEmpty);
      expect(buffer.length, equals((44100 * 0.3).toInt()));

      double peak = 0.0;
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        if (s.abs() > peak) peak = s.abs();
      }
      expect(peak, greaterThan(0.1));
      expect(peak, lessThanOrEqualTo(1.0));
    });

    test('LuaPresetLibrary contains Reggae Guitar with custom hardware GUI', () {
      final preset = LuaScriptLibrary.getPresetById('reggae_guitar');
      expect(preset, isNotNull);
      expect(preset!.name, equals('Dub Guitar'));
      expect(preset.category, equals(LuaPresetCategory.instrument));
      expect(preset.code.contains('PalmDamp'), isTrue);
      expect(preset.code.contains('StrumSpread'), isTrue);
      expect(preset.code.contains('ChopDecay'), isTrue);
      expect(preset.code.contains('DUB GUITAR'), isTrue);
    });

    test('LuaEngine compiles and synthesizes Reggae Guitar with chromatic pitch tracking', () {
      final preset = LuaScriptLibrary.getPresetById('reggae_guitar')!;

      // Note E3 (164.81 Hz)
      final bufE3 = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.2,
        freq: 164.81,
        note: 52,
        params: {'ChopDecay': 0.4},
      );

      // High note E5 (659.25 Hz)
      final bufE5 = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.2,
        freq: 659.25,
        note: 76,
        params: {'ChopDecay': 0.4},
      );

      expect(bufE3, isNotEmpty);
      expect(bufE5, isNotEmpty);

      // Count zero crossings during the pitched string sustain portion (after pick scrape)
      int zcE3 = 0;
      int zcE5 = 0;
      final int startIdx = (0.015 * 44100).toInt(); // 15ms onward
      for (int i = startIdx + 1; i < bufE3.length; i++) {
        if ((bufE3[i] >= 0 && bufE3[i - 1] < 0) || (bufE3[i] < 0 && bufE3[i - 1] >= 0)) {
          zcE3++;
        }
        if ((bufE5[i] >= 0 && bufE5[i - 1] < 0) || (bufE5[i] < 0 && bufE5[i - 1] >= 0)) {
          zcE5++;
        }
      }

      // E5 (659.25Hz) has higher pitch and frequency than E3 (164.81Hz)
      expect(zcE5, greaterThan(zcE3));
    });

    test('Dub Guitar sustains open notes and tightens on chop / palm mute articulations', () {
      final openBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildReggaeGuitar(),
        durationSec: 0.5,
        freq: 220.0, // A3
        note: 57,
        params: {'Sustain': 0.996, 'PalmDamp': 0.15},
        articulation: 'open',
      );

      final chopBuf = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildReggaeGuitar(),
        durationSec: 0.5,
        freq: 220.0, // A3
        note: 57,
        params: {'Sustain': 0.996, 'PalmDamp': 0.65},
        articulation: 'chop',
      );

      expect(openBuf, isNotEmpty);
      expect(chopBuf, isNotEmpty);

      // Measure RMS in the tail of the note (300ms to 450ms)
      final int startTail = (0.30 * 44100).toInt();
      final int endTail = (0.45 * 44100).toInt();
      double openEnergy = 0.0;
      double chopEnergy = 0.0;

      for (int i = startTail; i < endTail; i++) {
        openEnergy += openBuf[i] * openBuf[i];
        chopEnergy += chopBuf[i] * chopBuf[i];
      }

      // Open sustain should ring significantly longer than muted chop
      expect(openEnergy, greaterThan(chopEnergy));
    });
  });
}

