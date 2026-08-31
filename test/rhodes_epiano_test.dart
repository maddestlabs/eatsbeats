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

  group('Physical Modeling DSP Primitives', () {
    test('HammerExciterNode generates velocity-scaled contact pulse and micro-transient', () {
      const node = HammerExciterNode(hardness: 1.2, clickLevel: 1.0);
      final ctx = GraphContext(
        sampleRate: 44100,
        durationSec: 0.1,
        freq: 440.0,
        midiNote: 69,
        velocity: 0.9,
      );

      final fBuf = Float32List(ctx.totalSamples);
      node.process(ctx, fBuf);

      // Verify peak transient exists at the start
      double maxVal = 0.0;
      for (int i = 0; i < fBuf.length; i++) {
        if (fBuf[i].abs() > maxVal) maxVal = fBuf[i].abs();
        expect(fBuf[i].isNaN, isFalse);
        expect(fBuf[i].isInfinite, isFalse);
      }
      expect(maxVal, greaterThan(0.2));
      // Energy decays quickly (within ~10ms)
      final sampleAt20ms = fBuf[(0.020 * 44100).toInt()];
      expect(sampleAt20ms.abs(), lessThan(0.05));
    });

    test('PickupSaturationNode adds asymmetric quadratic 2nd harmonic saturation', () {
      const sine = SineOscNode(staticFreq: 220.0);
      const pickup = PickupSaturationNode(
        input: sine,
        distance: 0.5, // Close pickup = heavy bark
        symmetry: 0.8,
      );

      final ctx = GraphContext(
        sampleRate: 44100,
        durationSec: 0.1,
        freq: 220.0,
        midiNote: 57,
        velocity: 1.0,
      );

      final fBuf = Float32List(ctx.totalSamples);
      pickup.process(ctx, fBuf);

      for (int i = 0; i < fBuf.length; i++) {
        expect(fBuf[i].isNaN, isFalse);
        expect(fBuf[i].isInfinite, isFalse);
        expect(fBuf[i].abs(), lessThanOrEqualTo(1.5));
      }
    });

    test('ModalResonatorBankNode resonates at inharmonic modal ratios', () {
      const hammer = HammerExciterNode();
      const modalBank = ModalResonatorBankNode(
        input: hammer,
        modeFreqRatios: [1.0, 2.756, 5.404],
        modeGains: [0.7, 0.4, 0.2],
        modeQFactors: [20.0, 30.0, 40.0],
      );

      final ctx = GraphContext(
        sampleRate: 44100,
        durationSec: 0.2,
        freq: 440.0,
        midiNote: 69,
        velocity: 0.8,
      );

      final fBuf = Float32List(ctx.totalSamples);
      modalBank.process(ctx, fBuf);

      double energy = 0.0;
      for (final s in fBuf) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        energy += s * s;
      }
      expect(energy, greaterThan(0.01));
    });

    test('WaveguideNode synthesizes resonant string decay with loop damping', () {
      const hammer = HammerExciterNode();
      const waveguide = WaveguideNode(
        exciter: hammer,
        feedback: 0.992,
        damping: 0.20,
      );

      final ctx = GraphContext(
        sampleRate: 44100,
        durationSec: 0.3,
        freq: 330.0, // E4
        midiNote: 64,
        velocity: 0.85,
      );

      final fBuf = Float32List(ctx.totalSamples);
      waveguide.process(ctx, fBuf);

      double maxVal = 0.0;
      for (final s in fBuf) {
        if (s.abs() > maxVal) maxVal = s.abs();
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
      }
      expect(maxVal, greaterThan(0.1));
    });
  });

  group('Rhodes Mark I E-Piano Physical Model', () {
    test('GraphEvaluator synthesizes complete Rhodes E-Piano buffer', () {
      final buffer = GraphEvaluator.evaluate(
        root: GraphEvaluator.buildRhodesEPiano(),
        durationSec: 0.5,
        freq: 261.63, // Middle C
        note: 60,
        params: {
          'TineBell': 0.9,
          'TineDecay': 2.4,
          'PickupDistance': 0.8,
          'BarkSymmetry': 0.7,
          'BassBoost': 3.0,
          'TrebleSparkle': 2.5,
          'TremoloSpeed': 4.5,
          'TremoloDepth': 0.6,
          'Drive': 1.1,
        },
        velocity: 0.85,
      );

      expect(buffer, isNotEmpty);
      expect(buffer.length, equals((44100 * 0.5).toInt()));

      double peak = 0.0;
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        if (s.abs() > peak) peak = s.abs();
      }
      expect(peak, greaterThan(0.15));
      expect(peak, lessThanOrEqualTo(1.0));
    });

    test('LuaPresetLibrary contains Rhodes Mark I E-Piano with custom hardware GUI', () {
      final preset = LuaScriptLibrary.getPresetById('rhodes_epiano');
      expect(preset, isNotNull);
      expect(preset!.name, equals('Rhodes Mark I E-Piano'));
      expect(preset.category, equals(LuaPresetCategory.instrument));
      expect(preset.code.contains('TineBell'), isTrue);
      expect(preset.code.contains('PickupDistance'), isTrue);
      expect(preset.code.contains('TremoloSpeed'), isTrue);
      expect(preset.code.contains('RHODES MARK I'), isTrue);
    });

    test('LuaEngine compiles and synthesizes Rhodes E-Piano buffer', () {
      final preset = LuaScriptLibrary.getPresetById('rhodes_epiano')!;
      final buffer = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.4,
        freq: 440.0,
        note: 69,
        params: {
          'TineBell': 1.0,
          'TineDecay': 3.0,
          'PickupDistance': 0.9,
        },
      );

      expect(buffer, isNotEmpty);
      expect(buffer.length, equals((44100 * 0.4).toInt()));
      expect(buffer.any((s) => s.abs() > 0.1), isTrue);
    });

    test('Rhodes E-Piano pitch-tracks chromatically across different keyboard notes', () {
      final preset = LuaScriptLibrary.getPresetById('rhodes_epiano')!;

      // Low note C3 (130.81 Hz)
      final bufC3 = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.2,
        freq: 130.81,
        note: 48,
        params: {'TineBell': 0.0}, // fundamental only for clean zero crossings
      );

      // High note C5 (523.25 Hz)
      final bufC5 = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.2,
        freq: 523.25,
        note: 72,
        params: {'TineBell': 0.0},
      );

      // Count zero crossings
      int zcC3 = 0;
      int zcC5 = 0;
      for (int i = 1; i < bufC3.length; i++) {
        if ((bufC3[i] >= 0 && bufC3[i - 1] < 0) || (bufC3[i] < 0 && bufC3[i - 1] >= 0)) {
          zcC3++;
        }
        if ((bufC5[i] >= 0 && bufC5[i - 1] < 0) || (bufC5[i] < 0 && bufC5[i - 1] >= 0)) {
          zcC5++;
        }
      }

      // C5 is 2 octaves (4x frequency) higher than C3 -> should have ~4x more zero crossings
      expect(zcC5, greaterThan(zcC3 * 3));
    });
  });
}
