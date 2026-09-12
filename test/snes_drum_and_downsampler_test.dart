import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:eatsbeats/audio/snes_dsp_engine.dart';
import 'package:eatsbeats/audio/offline_dsp_fx_processor.dart';
import 'package:eatsbeats/eatscript/eat_dsp_synthesizer.dart';
import 'package:eatsbeats/eatscript/eat_script_library.dart';
import 'package:eatsbeats/eatscript/eat_builtin_presets.g.dart';
import 'package:eatsbeats/models/track_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SNESDrumKitEngine Tests', () {
    test('Synthesizes valid non-empty, non-clipping audio buffers for core GM drum notes', () {
      final drumNotes = [
        35, // Acoustic Kick
        36, // Standard Electric Kick
        37, // Side Stick
        38, // Acoustic Snare
        39, // Hand Clap
        40, // Electric Snare
        41, // Low Floor Tom
        42, // Closed Hi-Hat
        44, // Pedal Hi-Hat
        45, // Low Tom
        46, // Open Hi-Hat
        49, // Crash Cymbal 1
        50, // High Tom
        51, // Ride Cymbal 1
        54, // Tambourine
        56, // Cowbell
        75, // Claves
        80, // Open Triangle
      ];

      for (final note in drumNotes) {
        final buffer = SNESDrumKitEngine.synthesizeBuffer(
          note: note,
          durationSec: 0.3,
          velocity: 0.9,
        );

        expect(buffer.isNotEmpty, isTrue, reason: 'Drum note $note should produce samples');
        double maxAbs = 0.0;
        for (final s in buffer) {
          expect(s.isNaN, isFalse, reason: 'Drum note $note produced NaN sample');
          expect(s.isInfinite, isFalse, reason: 'Drum note $note produced infinite sample');
          expect(s, inInclusiveRange(-1.0, 1.0), reason: 'Drum note $note exceeded [-1, 1]');
          if (s.abs() > maxAbs) maxAbs = s.abs();
        }
        expect(maxAbs, greaterThan(0.05), reason: 'Drum note $note should have non-silent audible energy');
      }
    });

    test('MasterTune shifts pitch of synthesized kick and snare', () {
      final baseKick = SNESDrumKitEngine.synthesizeBuffer(
        note: 36,
        durationSec: 0.2,
        params: {'MasterTune': 0.0},
      );
      final tunedKick = SNESDrumKitEngine.synthesizeBuffer(
        note: 36,
        durationSec: 0.2,
        params: {'MasterTune': 7.0},
      );

      bool differs = false;
      for (int i = 0; i < baseKick.length && i < tunedKick.length; i++) {
        if ((baseKick[i] - tunedKick[i]).abs() > 0.01) {
          differs = true;
          break;
        }
      }
      expect(differs, isTrue, reason: 'Tuning should alter the drum waveform');
    });

    test('SnareNoise parameter alters noise ratio on snare notes', () {
      final lowNoiseSnare = SNESDrumKitEngine.synthesizeBuffer(
        note: 38,
        durationSec: 0.2,
        params: {'SnareNoise': 0.1},
      );
      final highNoiseSnare = SNESDrumKitEngine.synthesizeBuffer(
        note: 38,
        durationSec: 0.2,
        params: {'SnareNoise': 0.9},
      );

      bool differs = false;
      for (int i = 0; i < lowNoiseSnare.length; i++) {
        if ((lowNoiseSnare[i] - highNoiseSnare[i]).abs() > 0.05) {
          differs = true;
          break;
        }
      }
      expect(differs, isTrue);
    });

    test('GaussianWarmth applies 4-point smoothing kernel', () {
      final raw = SNESDrumKitEngine.synthesizeBuffer(
        note: 42,
        durationSec: 0.08,
        params: {'GaussianWarmth': 0.0},
      );
      final warmed = SNESDrumKitEngine.synthesizeBuffer(
        note: 42,
        durationSec: 0.08,
        params: {'GaussianWarmth': 1.0},
      );

      expect(raw.length, equals(warmed.length));
      bool differs = false;
      for (int i = 0; i < raw.length; i++) {
        if ((raw[i] - warmed[i]).abs() > 0.005) {
          differs = true;
          break;
        }
      }
      expect(differs, isTrue);
    });
  });

  group('SNESDownsamplerEngine Tests', () {
    test('Processes audio buffer across all 5 retro sample rate tiers', () {
      for (int rIdx = 0; rIdx < 5; rIdx++) {
        final buffer = Float32List(4410);
        for (int i = 0; i < buffer.length; i++) {
          buffer[i] = 0.5 * (i % 100 < 50 ? 1.0 : -1.0); // Square wave input
        }

        SNESDownsamplerEngine.processBuffer(
          buffer,
          rateIndex: rIdx,
          brrBits: 4.0,
          gaussianFilter: 0.85,
          drive: 1.0,
          mix: 1.0,
          hostSampleRate: 44100,
        );

        for (final s in buffer) {
          expect(s.isNaN, isFalse);
          expect(s, inInclusiveRange(-1.0, 1.0));
        }
      }
    });

    test('BRR bits controls amplitude quantization resolution', () {
      final bufLow = Float32List(1000);
      final bufHigh = Float32List(1000);
      for (int i = 0; i < 1000; i++) {
        final ramp = (i / 500.0) - 1.0;
        bufLow[i] = ramp;
        bufHigh[i] = ramp;
      }

      SNESDownsamplerEngine.processBuffer(
        bufLow,
        rateIndex: 0,
        brrBits: 2.0, // 4 discrete levels
        gaussianFilter: 0.0,
        mix: 1.0,
      );
      SNESDownsamplerEngine.processBuffer(
        bufHigh,
        rateIndex: 0,
        brrBits: 8.0, // 256 levels
        gaussianFilter: 0.0,
        mix: 1.0,
      );

      final uniqueLevelsLow = bufLow.map((v) => (v * 100).round()).toSet();
      final uniqueLevelsHigh = bufHigh.map((v) => (v * 100).round()).toSet();
      expect(uniqueLevelsLow.length, lessThan(uniqueLevelsHigh.length));
    });

    test('Real-time evaluateSample produces continuous valid signal', () {
      for (int i = 0; i < 100; i++) {
        final t = i / 44100.0;
        final inVal = (i % 40 < 20) ? 0.6 : -0.6;
        final outVal = SNESDownsamplerEngine.evaluateSample(
          inputSample: inVal,
          time: t,
          params: {
            'SampleRate': 2.0,
            'BRRBits': 4.0,
            'GaussianFilter': 0.85,
            'Drive': 1.0,
            'Mix': 1.0,
          },
        );
        expect(outVal.isNaN, isFalse);
        expect(outVal, inInclusiveRange(-1.0, 1.0));
      }
    });
  });

  group('Eatscript Preset Library Integration Tests', () {
    test('EatBuiltinPresets contains snes_drum_kit and snes_downsampler', () {
      final drumKit = EatBuiltinPresets.presets.firstWhere(
        (p) => p.id == 'snes_drum_kit',
        orElse: () => throw Exception('snes_drum_kit not found in EatBuiltinPresets'),
      );
      expect(drumKit.category, equals(EatScriptCategory.instrument));
      expect(drumKit.name, equals('SNES Drum Kit'));
      expect(drumKit.code, contains('def init():'));
      expect(drumKit.code, contains('def gui():'));
      expect(drumKit.code, contains('SNESDrumKit'));

      final downsampler = EatBuiltinPresets.presets.firstWhere(
        (p) => p.id == 'snes_downsampler',
        orElse: () => throw Exception('snes_downsampler not found in EatBuiltinPresets'),
      );
      expect(downsampler.category, equals(EatScriptCategory.audioFx));
      expect(downsampler.name, equals('SNES Downsampler'));
      expect(downsampler.code, contains('SampleRate'));
      expect(downsampler.code, contains('BRRBits'));
      expect(downsampler.code, contains('GaussianFilter'));
    });

    test('EatDspSynthesizer synthesizes drum buffer from snes_drum_kit code', () {
      final drumKit = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'snes_drum_kit');
      final buffer = EatDspSynthesizer.synthesizeBuffer(
        code: drumKit.code,
        freq: 60.0,
        durationSec: 0.25,
        note: 36, // Kick
        params: {'MasterTune': 0.0, 'KickPunch': 130.0},
      );

      expect(buffer.isNotEmpty, isTrue);
      expect(buffer.length, equals((44100 * 0.22).toInt()));
      expect(buffer[10], isNot(0.0));
    });

    test('OfflineDspFxProcessor applies snes_downsampler to track buffer', () {
      final downsampler = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'snes_downsampler');
      final buffer = Float32List(2000);
      for (int i = 0; i < buffer.length; i++) {
        buffer[i] = (i / 1000.0) - 1.0;
      }

      final fx = FXInsert(
        id: 'fx_snes_ds',
        name: 'SNES Downsampler',
        type: FXType.eatScriptFX,
        mix: 1.0,
        params: {},
        presetId: 'snes_downsampler',
        eatScriptCode: downsampler.code,
        eatScriptParams: {
          'SampleRate': 3.0, // 11.025 kHz
          'BRRBits': 4.0,
          'GaussianFilter': 0.85,
          'Drive': 1.0,
        },
      );

      OfflineDspFxProcessor.processTrackFx(
        buffer,
        fxRack: [fx],
        sampleRate: 44100,
      );

      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
    });
  });
}
