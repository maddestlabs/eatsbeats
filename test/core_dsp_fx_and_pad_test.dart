import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/dsp/multi_mode_filter.dart';
import 'package:eatsbeats/audio/dsp/parametric_eq.dart';
import 'package:eatsbeats/audio/dsp/dynamics_processor.dart';
import 'package:eatsbeats/audio/dsp/modulated_delay.dart';
import 'package:eatsbeats/eatscript/eats_engine_registry.dart';
import 'package:eatsbeats/eatscript/eats_script_engine.dart';
import 'package:eatsbeats/eatscript/eats_dsp_synthesizer.dart';
import 'package:eatsbeats/eatscript/ambient_pad_preset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Core DSP FX & Dynamics Tests', () {
    test('MultiModeFilter lowpass attenuates high frequencies and preserves low frequencies', () {
      final filter = MultiModeFilter(
        type: MultiModeFilterType.lowpass,
        cutoff: 1000.0,
        q: 0.707,
        sampleRate: 44100.0,
      );

      // Low frequency (100 Hz) should be near 0 dB
      final lowMag = filter.getMagnitudeDbAt(100.0);
      expect(lowMag, closeTo(0.0, 0.5));

      // Cutoff (1000 Hz) should be near -3 dB
      final cutoffMag = filter.getMagnitudeDbAt(1000.0);
      expect(cutoffMag, closeTo(-3.0, 0.6));

      // High frequency (10000 Hz) should be heavily attenuated (< -20 dB)
      final highMag = filter.getMagnitudeDbAt(10000.0);
      expect(highMag < -20.0, isTrue);

      // In-place buffer test
      final buf = Float32List.fromList([0.5, -0.5, 0.5, -0.5]);
      filter.processBuffer(buf);
      for (final s in buf) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
      }
    });

    test('MultiModeFilter highpass attenuates low frequencies and preserves highs', () {
      final filter = MultiModeFilter(
        type: MultiModeFilterType.highpass,
        cutoff: 2000.0,
        q: 0.707,
        sampleRate: 44100.0,
      );

      final lowMag = filter.getMagnitudeDbAt(100.0);
      expect(lowMag < -20.0, isTrue);

      final highMag = filter.getMagnitudeDbAt(10000.0);
      expect(highMag, closeTo(0.0, 0.5));
    });

    test('MultiModeFilter peaking filter boosts target frequency by gainDb', () {
      final filter = MultiModeFilter(
        type: MultiModeFilterType.peaking,
        cutoff: 1000.0,
        q: 1.5,
        gainDb: 6.0,
        sampleRate: 44100.0,
      );

      final peakMag = filter.getMagnitudeDbAt(1000.0);
      expect(peakMag, closeTo(6.0, 0.5));

      // Frequencies far from center should be close to 0 dB
      final farMag = filter.getMagnitudeDbAt(10000.0);
      expect(farMag, closeTo(0.0, 0.5));
    });

    test('ParametricEq processes multi-band buffer and calculates composite magnitude', () {
      final eq = ParametricEq(sampleRate: 44100.0);
      eq.configureBand(2, gainDb: 4.0, frequency: 1000.0);

      final magAt1k = eq.getCompositeMagnitudeDbAt(1000.0);
      expect(magAt1k, closeTo(4.0, 0.8));

      final buf = Float32List(128)..fillRange(0, 128, 0.25);
      eq.processBuffer(buf);
      expect(buf.first.isNaN, isFalse);
    });

    test('EatCompressor reduces gain when signal exceeds threshold', () {
      final comp = EatCompressor(
        sampleRate: 44100.0,
        thresholdDb: -12.0, // 0.251 linear
        ratio: 4.0,
        attackMs: 1.0,
        releaseMs: 50.0,
        mix: 1.0,
      );

      // Loud signal (+0.95 peak = -0.45 dB, well above -12 dB threshold)
      final loudBuf = Float32List(1000)..fillRange(0, 1000, 0.95);
      comp.process(loudBuf);

      // Later samples should be compressed below 0.95
      final compressedSample = loudBuf.last;
      expect(compressedSample < 0.65, isTrue);
      expect(compressedSample > 0.1, isTrue);
    });

    test('EatCompressor ducks audio when external sidechain signal is present', () {
      final comp = EatCompressor(
        sampleRate: 44100.0,
        thresholdDb: -12.0,
        ratio: 8.0,
        attackMs: 0.5,
        releaseMs: 100.0,
        mix: 1.0,
      );

      // Quiet sustained bass note (0.2 peak, below -12 dB)
      final audioBuf = Float32List(1000)..fillRange(0, 1000, 0.2);
      // Loud external kick sidechain (0.95 peak, triggers compression)
      final kickSidechain = Float32List(1000)..fillRange(0, 1000, 0.95);

      comp.process(audioBuf, sidechainBuffer: kickSidechain);

      // Audio buffer should be ducked below its original 0.2 level!
      expect(audioBuf.last < 0.12, isTrue);
    });

    test('EatLimiter strictly enforces ceiling with zero overshoot', () {
      final limiter = EatLimiter(
        sampleRate: 44100.0,
        ceilingDb: -1.0, // approx 0.891 linear
        releaseMs: 20.0,
        lookaheadMs: 2.0,
      );

      final ceilingLinear = math.pow(10.0, -1.0 / 20.0).toDouble();

      // Huge clipping square wave (1.8 peak)
      final hotBuf = Float32List(2000)..fillRange(0, 2000, 1.8);
      limiter.process(hotBuf);

      // Verify no sample exceeds ceiling
      for (final sample in hotBuf) {
        expect(sample <= ceilingLinear + 1e-4, isTrue,
            reason: 'Sample $sample exceeded ceiling $ceilingLinear');
      }
    });

    test('EatChorus and EatTapeDelay process stereo signals without NaN', () {
      final chorus = EatChorus();
      final tape = EatTapeDelay();

      final left = Float32List(512)..fillRange(0, 512, 0.3);
      final right = Float32List(512)..fillRange(0, 512, -0.3);

      chorus.processStereo(left, right);
      tape.processStereo(left, right);

      for (int i = 0; i < 512; i++) {
        expect(left[i].isNaN, isFalse);
        expect(right[i].isNaN, isFalse);
      }
    });
  });

  group('Ambient Pad Instrument Engine Tests', () {
    test('ambient_pad is registered in EatEngineRegistry', () {
      expect(EatEngineRegistry.isRegistered('ambient_pad'), isTrue);
      expect(EatEngineRegistry.isRegistered('super_pad'), isTrue);
      expect(EatEngineRegistry.isRegistered('astral_pad'), isTrue);
    });

    test('AmbientPadPreset compiles cleanly with hardware GUI and zero warnings', () {
      final comp = EatScriptEngine.compile(AmbientPadPreset.preset.eatCode);
      expect(comp.isSuccess, isTrue);
      expect(comp.engineId, equals('ambient_pad'));
      expect(comp.guiLayout, isNotNull);
      expect(comp.warnings, isEmpty);
      expect(comp.params.length, greaterThanOrEqualTo(6));
    });

    test('EatDspSynthesizer synthesizes lush ambient pad buffer with custom parameters', () {
      final buffer = EatDspSynthesizer.synthesizeBuffer(
        code: AmbientPadPreset.preset.eatCode,
        durationSec: 0.25,
        freq: 220.0, // A3
        note: 57,
        params: {
          'Cutoff': 3000.0,
          'Resonance': 0.6,
          'Detune': 16.0,
          'Warmth': 0.7,
          'Attack': 0.1,
          'Release': 0.5,
        },
      );

      expect(buffer.length, equals((44100 * 0.25).toInt()));
      final hasAudio = buffer.any((s) => s.abs() > 0.01);
      expect(hasAudio, isTrue);

      for (final s in buffer) {
        expect(s >= -1.0 && s <= 1.0, isTrue);
        expect(s.isNaN, isFalse);
      }
    });
  });
}
