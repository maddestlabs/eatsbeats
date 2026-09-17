import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/eatscript/eats_synth_type.dart';
import 'package:eatsbeats/eatscript/eats_engine_registry.dart';
import 'package:eatsbeats/eatscript/eats_dsp_synthesizer.dart';
import 'package:eatsbeats/eatscript/eats_builtin_presets.g.dart';
import 'package:eatsbeats/eatscript/eats_script_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Poly Synth & Sub Bass Engine Tests', () {
    test('Engine registry recognizes poly_synth and poly_lead', () {
      expect(EatEngineRegistry.isRegistered('poly_synth'), isTrue);
      expect(EatEngineRegistry.isRegistered('poly_lead'), isTrue);
      expect(EatEngineRegistry.specializedSynthTypes['poly_synth'], equals(EatSynthType.polySynth));
      expect(EatEngineRegistry.specializedSynthTypes['poly_lead'], equals(EatSynthType.polySynth));
    });

    test('EatDspSynthesizer resolves poly_synth, poly_lead, and sub_bass_synth to EatSynthType.polySynth', () {
      const code1 = '# @engine: poly_synth\ndef init():\n    pass';
      expect(EatDspSynthesizer.resolveSynthType(code1), equals(EatSynthType.polySynth));

      const code2 = '# @engine: poly_lead\ndef init():\n    pass';
      expect(EatDspSynthesizer.resolveSynthType(code2), equals(EatSynthType.polySynth));

      const code3 = 'PolyLeadSynth = True';
      expect(EatDspSynthesizer.resolveSynthType(code3), equals(EatSynthType.polySynth));

      const code4 = 'SubBassSynth = True';
      expect(EatDspSynthesizer.resolveSynthType(code4), equals(EatSynthType.polySynth));
    });

    test('Synthesizes pure Sine wave with clean fundamental (Waveform = 1.0)', () {
      final buffer = EatDspSynthesizer.synthesizeBuffer(
        code: '# @engine: poly_synth',
        durationSec: 0.1,
        freq: 100.0,
        note: 45, // A1
        params: {
          'Waveform': 1.0, // Sine
          'Cutoff': 15000.0,
          'Resonance': 0.7,
          'Attack': 0.001,
          'Decay': 0.1,
          'Sustain': 1.0,
          'Release': 0.05,
          'Drive': 0.0,
          'SubLevel': 0.0,
        },
      );

      expect(buffer.length, equals(4410));
      // Buffer should be non-empty and non-silent
      double maxAmp = 0.0;
      for (final s in buffer) {
        maxAmp = math.max(maxAmp, s.abs());
      }
      expect(maxAmp, greaterThan(0.5));
      expect(maxAmp, lessThanOrEqualTo(1.0));
    });

    test('Synthesizes Square wave (Waveform = 2.0) and Triangle (Waveform = 3.0)', () {
      final sqrBuf = EatDspSynthesizer.synthesizeBuffer(
        code: '# @engine: poly_synth',
        durationSec: 0.05,
        freq: 220.0,
        note: 57, // A3
        params: {
          'Waveform': 2.0, // Square
          'Cutoff': 18000.0,
          'Resonance': 0.5,
          'Attack': 0.001,
          'Decay': 0.05,
          'Sustain': 1.0,
          'Release': 0.05,
        },
      );
      expect(sqrBuf.length, equals(2205));

      final triBuf = EatDspSynthesizer.synthesizeBuffer(
        code: '# @engine: poly_synth',
        durationSec: 0.05,
        freq: 220.0,
        note: 57,
        params: {
          'Waveform': 3.0, // Triangle
          'Cutoff': 18000.0,
          'Resonance': 0.5,
          'Attack': 0.001,
          'Decay': 0.05,
          'Sustain': 1.0,
          'Release': 0.05,
        },
      );
      expect(triBuf.length, equals(2205));

      // Both should have audio energy
      double maxSqr = 0.0, maxTri = 0.0;
      for (int i = 0; i < 2205; i++) {
        maxSqr = math.max(maxSqr, sqrBuf[i].abs());
        maxTri = math.max(maxTri, triBuf[i].abs());
      }
      expect(maxSqr, greaterThan(0.5));
      expect(maxTri, greaterThan(0.3));
    });

    test('Sub-Oscillator adds sub-harmonic low frequency body', () {
      final noSub = EatDspSynthesizer.synthesizeBuffer(
        code: '# @engine: poly_synth',
        durationSec: 0.1,
        freq: 110.0,
        note: 45,
        params: {
          'Waveform': 0.0, // Saw
          'SubLevel': 0.0,
          'Cutoff': 10000.0,
          'Attack': 0.001,
          'Decay': 0.1,
          'Sustain': 1.0,
          'Release': 0.05,
        },
      );

      final withSub = EatDspSynthesizer.synthesizeBuffer(
        code: '# @engine: poly_synth',
        durationSec: 0.1,
        freq: 110.0,
        note: 45,
        params: {
          'Waveform': 0.0,
          'SubLevel': 0.8,
          'Cutoff': 10000.0,
          'Attack': 0.001,
          'Decay': 0.1,
          'Sustain': 1.0,
          'Release': 0.05,
        },
      );

      // Outputs should differ due to sub-oscillator presence
      bool differs = false;
      for (int i = 100; i < 2000; i++) {
        if ((noSub[i] - withSub[i]).abs() > 0.05) {
          differs = true;
          break;
        }
      }
      expect(differs, isTrue);
    });

    test('SVF Filter modes: Lowpass (0), Bandpass (1), Highpass (2)', () {
      for (int mode = 0; mode <= 2; mode++) {
        final buf = EatDspSynthesizer.synthesizeBuffer(
          code: '# @engine: poly_synth',
          durationSec: 0.05,
          freq: 220.0,
          note: 57,
          params: {
            'Waveform': 0.0, // Saw
            'FilterMode': mode.toDouble(),
            'Cutoff': 1200.0,
            'Resonance': 2.0,
            'Attack': 0.001,
            'Decay': 0.05,
            'Sustain': 1.0,
            'Release': 0.05,
          },
        );
        expect(buf.length, equals(2205));
        double maxA = 0.0;
        for (final s in buf) {
          maxA = math.max(maxA, s.abs());
        }
        expect(maxA, greaterThan(0.1));
      }
    });

    test('ADSR envelope sculpts attack, decay, and sustain', () {
      // Snappy bass pluck with 0 sustain
      final pluckBuf = EatDspSynthesizer.synthesizeBuffer(
        code: '# @engine: poly_synth',
        durationSec: 0.3,
        freq: 100.0,
        note: 45,
        params: {
          'Waveform': 1.0, // Sine
          'Attack': 0.001,
          'Decay': 0.05,
          'Sustain': 0.0,
          'Release': 0.01,
        },
      );

      // Peak amplitude should happen early (around sample 50-200)
      // and late amplitude (at 0.2s = sample 8820) should be near zero
      double earlyAmp = 0.0;
      for (int i = 50; i < 200; i++) {
        earlyAmp = math.max(earlyAmp, pluckBuf[i].abs());
      }
      double lateAmp = 0.0;
      for (int i = 8000; i < 10000; i++) {
        lateAmp = math.max(lateAmp, pluckBuf[i].abs());
      }

      expect(earlyAmp, greaterThan(0.5));
      expect(lateAmp, lessThan(0.05));
    });

    test('Detune introduces stereo/unison phase interaction without crashing', () {
      final detunedBuf = EatDspSynthesizer.synthesizeBuffer(
        code: '# @engine: poly_synth',
        durationSec: 0.1,
        freq: 110.0,
        note: 45,
        params: {
          'Waveform': 0.0, // Saw
          'Detune': 12.0, // 12 cents detune
          'Osc2Mix': 0.5,
          'Cutoff': 12000.0,
          'Attack': 0.001,
          'Decay': 0.1,
          'Sustain': 1.0,
          'Release': 0.05,
        },
      );

      expect(detunedBuf.length, equals(4410));
      double maxAmp = 0.0;
      for (final s in detunedBuf) {
        maxAmp = math.max(maxAmp, s.abs());
      }
      expect(maxAmp, greaterThan(0.3));
    });

    test('Built-in presets poly_lead and sub_bass_synth compile and evaluate cleanly', () {
      final polyLeadDef = EatBuiltinPresets.getById('poly_lead');
      expect(polyLeadDef, isNotNull);
      final compiledLead = EatScriptEngine.compile(polyLeadDef!.code);
      expect(compiledLead.isSuccess, isTrue);
      expect(compiledLead.params.any((p) => p.name == 'Waveform'), isTrue);
      expect(compiledLead.params.any((p) => p.name == 'Cutoff'), isTrue);
      expect(compiledLead.params.any((p) => p.name == 'Attack'), isTrue);

      final subBassDef = EatBuiltinPresets.getById('sub_bass_synth');
      expect(subBassDef, isNotNull);
      final compiledSub = EatScriptEngine.compile(subBassDef!.code);
      expect(compiledSub.isSuccess, isTrue);
      expect(compiledSub.params.any((p) => p.name == 'SubLevel'), isTrue);

      // Synthesize both without errors
      final leadAudio = EatDspSynthesizer.synthesizeBuffer(
        code: polyLeadDef.code,
        durationSec: 0.1,
        freq: 440.0,
        note: 69,
        params: {for (final p in compiledLead.params) p.name: p.defaultValue},
      );
      expect(leadAudio.isNotEmpty, isTrue);

      final subAudio = EatDspSynthesizer.synthesizeBuffer(
        code: subBassDef.code,
        durationSec: 0.1,
        freq: 55.0, // A0 sub bass
        note: 33,
        params: {for (final p in compiledSub.params) p.name: p.defaultValue},
      );
      expect(subAudio.isNotEmpty, isTrue);
    });
  });
}
