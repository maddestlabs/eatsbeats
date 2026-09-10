import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/audio_engine.dart';
import 'package:eatsbeats/audio/poly_synth.dart';
import 'package:eatsbeats/audio/graph/graph_node.dart';
import 'package:eatsbeats/eatscript/eat_api.dart';
import 'package:eatsbeats/eatscript/eat_dsp_synthesizer.dart';
import 'package:eatsbeats/eatscript/eat_engine.dart';
import 'package:eatsbeats/eatscript/eat_interpreter.dart';
import 'package:eatsbeats/eatscript/eat_param_model.dart';
import 'package:eatsbeats/eatscript/eat_script_library.dart';
import 'package:eatsbeats/models/track_model.dart';

void main() {
  group('EatParamDef Variance Exemption Rules', () {
    test('Continuous float parameters allow variance by default', () {
      final cutoff = EatParamDef(name: 'Cutoff', min: 20.0, max: 20000.0, defaultValue: 1000.0);
      final decay = EatParamDef(name: 'Decay', min: 0.05, max: 1.0, defaultValue: 0.25);
      final resonance = EatParamDef(name: 'Resonance', min: 0.1, max: 10.0, defaultValue: 1.0);

      expect(cutoff.allowVariance, isTrue);
      expect(decay.allowVariance, isTrue);
      expect(resonance.allowVariance, isTrue);
    });

    test('Discrete parameters automatically default to allowVariance = false', () {
      final octave = EatParamDef(name: 'Octave', min: -2.0, max: 2.0, defaultValue: 0.0, step: 1.0);
      final waveform = EatParamDef(name: 'Waveform', min: 0.0, max: 3.0, defaultValue: 0.0, step: 1.0);
      final preset = EatParamDef(name: 'Preset', min: 0.0, max: 127.0, defaultValue: 0.0);
      final bank = EatParamDef(name: 'Bank', min: 0.0, max: 10.0, defaultValue: 0.0);
      final algorithm = EatParamDef(name: 'Algorithm', min: 0.0, max: 7.0, defaultValue: 0.0);
      final choice = EatParamDef(name: 'FilterType', min: 0.0, max: 2.0, defaultValue: 0.0, options: ['LP', 'BP', 'HP']);

      expect(octave.allowVariance, isFalse);
      expect(waveform.allowVariance, isFalse);
      expect(preset.allowVariance, isFalse);
      expect(bank.allowVariance, isFalse);
      expect(algorithm.allowVariance, isFalse);
      expect(choice.allowVariance, isFalse);
    });

    test('Explicit allow_variance override is respected', () {
      final customExempt = EatParamDef(name: 'CustomPitch', min: 20.0, max: 2000.0, defaultValue: 440.0, allowVariance: false);
      final customForced = EatParamDef(name: 'SpecialOctave', min: -2.0, max: 2.0, defaultValue: 0.0, step: 1.0, allowVariance: true);

      expect(customExempt.allowVariance, isFalse);
      expect(customForced.allowVariance, isTrue);
    });
  });

  group('Eatscript Runtime API Variance Functions', () {
    test('eat.variance reads active track variance level', () {
      final interpreter = EatInterpreter();
      final context = EatScriptContext(paramValues: {'Variance': 0.35});
      EatHostApi.install(interpreter, context);

      final eat = interpreter.globals.get('eat', line: 1, column: 1) as Map<String, dynamic>;
      final varianceFn = eat['variance'] as EatNativeFunction;

      expect(varianceFn.fn([], {}), closeTo(0.35, 1e-4));
    });

    test('eat.vary perturbs values within bounds', () {
      final interpreter = EatInterpreter();
      final context = EatScriptContext();
      EatHostApi.install(interpreter, context);

      final eat = interpreter.globals.get('eat', line: 1, column: 1) as Map<String, dynamic>;
      final varyFn = eat['vary'] as EatNativeFunction;

      final varied = varyFn.fn([100.0, 0.2, 50.0, 150.0], {}) as double;
      expect(varied, inInclusiveRange(50.0, 150.0));
      expect(varied, isNot(100.0));
    });

    test('eat.vary_param respects allowVariance exemption', () {
      final interpreter = EatInterpreter();
      final context = EatScriptContext(
        params: [
          EatParamDef(name: 'Cutoff', min: 20.0, max: 20000.0, defaultValue: 1000.0, allowVariance: true),
          EatParamDef(name: 'Octave', min: -2.0, max: 2.0, defaultValue: 0.0, step: 1.0, allowVariance: false),
        ],
        paramValues: {
          'Cutoff': 1000.0,
          'Octave': 0.0,
          'Variance': 0.5,
        },
      );
      EatHostApi.install(interpreter, context);

      final eat = interpreter.globals.get('eat', line: 1, column: 1) as Map<String, dynamic>;
      final varyParamFn = eat['vary_param'] as EatNativeFunction;

      // Octave should never deviate because it is exempt
      final octaveVal = varyParamFn.fn(['Octave'], {});
      expect(octaveVal, equals(0.0));

      // Cutoff should deviate because allowVariance is true and Variance = 0.5
      final cutoffVal = varyParamFn.fn(['Cutoff'], {}) as double;
      expect(cutoffVal, isNot(1000.0));
      expect(cutoffVal, inInclusiveRange(20.0, 20000.0));
    });

    test('eat.ignore_variance dynamically exempts a parameter at runtime', () {
      final interpreter = EatInterpreter();
      final context = EatScriptContext(
        params: [
          EatParamDef(name: 'Cutoff', min: 20.0, max: 20000.0, defaultValue: 1000.0, allowVariance: true),
        ],
        paramValues: {
          'Cutoff': 1000.0,
          'Variance': 0.5,
        },
      );
      EatHostApi.install(interpreter, context);

      final eat = interpreter.globals.get('eat', line: 1, column: 1) as Map<String, dynamic>;
      final ignoreFn = eat['ignore_variance'] as EatNativeFunction;
      final isExemptFn = eat['is_variance_exempt'] as EatNativeFunction;
      final varyParamFn = eat['vary_param'] as EatNativeFunction;

      expect(isExemptFn.fn(['Cutoff'], {}), isFalse);

      // Now ignore Cutoff variance
      ignoreFn.fn(['Cutoff'], {});
      expect(isExemptFn.fn(['Cutoff'], {}), isTrue);

      final result = varyParamFn.fn(['Cutoff'], {});
      expect(result, equals(1000.0));
    });

    test('eat.apply_variance selectively perturbs non-exempt parameters in map', () {
      final interpreter = EatInterpreter();
      final context = EatScriptContext(
        params: [
          EatParamDef(name: 'NearPitchStart', min: 100.0, max: 300.0, defaultValue: 180.0, allowVariance: true),
          EatParamDef(name: 'Octave', min: -2.0, max: 0.0, defaultValue: 0.0, step: 1.0, allowVariance: false),
        ],
        paramValues: {
          'NearPitchStart': 180.0,
          'Octave': 0.0,
          'Variance': 0.3,
        },
      );
      EatHostApi.install(interpreter, context);

      final eat = interpreter.globals.get('eat', line: 1, column: 1) as Map<String, dynamic>;
      final applyFn = eat['apply_variance'] as EatNativeFunction;

      final variedMap = applyFn.fn([context.paramValues], {}) as Map;
      expect(variedMap['Octave'], equals(0.0)); // Strictly unchanged
      expect(variedMap['NearPitchStart'], isNot(180.0)); // Varied
    });
  });

  group('GraphContext Parameter Perturbation & Overrides', () {
    test('Exempt parameters are not perturbed even with maximum variance', () {
      final ctx = GraphContext(
        durationSec: 0.1,
        freq: 440.0,
        midiNote: 60,
        params: {
          'Variance': 1.0,
          'Octave': 0.0,
          'Waveform': 1.0,
          'Preset': 5.0,
          'Cutoff': 1000.0,
        },
      );

      expect(ctx.isParamVarianceExempt('Octave'), isTrue);
      expect(ctx.isParamVarianceExempt('Waveform'), isTrue);
      expect(ctx.isParamVarianceExempt('Preset'), isTrue);
      expect(ctx.isParamVarianceExempt('Cutoff'), isFalse);

      expect(ctx.getParam('Octave', 0.0), equals(0.0));
      expect(ctx.getParam('Waveform', 1.0), equals(1.0));
      expect(ctx.getParam('Preset', 5.0), equals(5.0));

      final variedCutoff = ctx.getParam('Cutoff', 1000.0);
      expect(variedCutoff, isNot(1000.0));
    });

    test('User explicit ignore_variance_Param flag exempts specific param', () {
      final ctx = GraphContext(
        durationSec: 0.1,
        freq: 440.0,
        midiNote: 60,
        params: {
          'Variance': 0.8,
          'Cutoff': 1500.0,
          'ignore_variance_Cutoff': 1.0,
        },
      );

      expect(ctx.isParamVarianceExempt('Cutoff'), isTrue);
      expect(ctx.getParam('Cutoff', 1500.0), equals(1500.0));
    });
  });

  group('AudioEngine PCM Cache Bypass & Acoustic Hit Uniqueness', () {
    test('Cache is bypassed when Variance > 0', () {
      final engine = AudioEngine();
      final track = TrackChannel(
        id: 'test_drum_track',
        name: 'Acoustic Snare',
        color: const Color(0xFF2196F3),
        type: TrackType.luaScript,
        sampleName: 'fm_acoustic_snare',
        luaScriptCode: LuaPresetLibrary.getPresetById('fm_acoustic_snare')!.code,
      );

      track.luaParams['Variance'] = 0.0;
      expect(engine.isBufferCached(track: track, midiNote: 38, durationSec: 0.5), isFalse);

      // Play note without variance (gets cached)
      engine.noteOn(track: track, midiNote: 38, velocity: 0.9, sustainDurationSec: 0.5, loop: false);
      expect(engine.isBufferCached(track: track, midiNote: 38, durationSec: 0.5), isTrue);

      // Now enable variance -> isBufferCached must report false so hits are not recycled
      track.luaParams['Variance'] = 0.25;
      expect(engine.isBufferCached(track: track, midiNote: 38, durationSec: 0.5), isFalse);
    });

    test('Acoustic drum hits produce distinct buffers when Variance > 0', () {
      final track = TrackChannel(
        id: 'kick_variance_test',
        name: 'Acoustic Kick',
        color: const Color(0xFF2196F3),
        type: TrackType.luaScript,
        sampleName: 'fm_acoustic_kick',
        luaScriptCode: LuaPresetLibrary.getPresetById('fm_acoustic_kick')!.code,
      );

      track.luaParams['Variance'] = 0.40;

      final buf1 = EatDspSynthesizer.synthesizeBuffer(
        code: track.luaScriptCode,
        durationSec: 0.2,
        freq: PolySynth.midiToFreq(36),
        note: 36,
        params: track.luaParams,
      );

      final buf2 = EatDspSynthesizer.synthesizeBuffer(
        code: track.luaScriptCode,
        durationSec: 0.2,
        freq: PolySynth.midiToFreq(36),
        note: 36,
        params: track.luaParams,
      );

      expect(buf1.length, equals(buf2.length));
      expect(buf1.length, greaterThan(0));

      // Buffers must not be identical across the entire signal (eliminates machine-gun effect)
      bool hasDifference = false;
      for (int i = 0; i < buf1.length; i++) {
        if ((buf1[i] - buf2[i]).abs() > 1e-6) {
          hasDifference = true;
          break;
        }
      }
      expect(hasDifference, isTrue);
    });
  });
}
