import 'dart:math' as math;
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/easing.dart';
import 'package:eatsbeats/audio/fm_chip_engine.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/models/automation_model.dart';
import 'package:eatsbeats/models/track_model.dart';

void main() {
  group('FM Hardware Chip Voice & Algorithm Tests', () {
    test('All 8 FM algorithms evaluate non-silent audio samples', () {
      final voice = FMChipVoice();

      for (int alg = 0; alg < 8; alg++) {
        voice.algorithm = alg;
        voice.feedback = 4;
        voice.reset();

        // Enable all 4 operators
        for (final op in voice.operators) {
          op.totalLevel = 0.0;
          op.attack = 0.001;
          op.decay = 0.3;
          op.sustain = 0.5;
        }

        final s1 = voice.evaluateSample(time: 0.01, baseFreq: 440.0);
        final s2 = voice.evaluateSample(time: 0.05, baseFreq: 440.0);

        expect(s1.abs() > 0.0001 || s2.abs() > 0.0001, isTrue,
            reason: 'Algorithm $alg produced only silence');
        expect(s1.isFinite, isTrue);
        expect(s2.isFinite, isTrue);
      }
    });

    test('DeterministicPRNG produces identical sequences for same seed and varies for different seeds', () {
      final prngA1 = DeterministicPRNG(1234);
      final prngA2 = DeterministicPRNG(1234);
      final prngB = DeterministicPRNG(9999);

      final valA1 = [prngA1.nextDouble(), prngA1.nextDouble(), prngA1.nextInt(1, 100)];
      final valA2 = [prngA2.nextDouble(), prngA2.nextDouble(), prngA2.nextInt(1, 100)];
      final valB = [prngB.nextDouble(), prngB.nextDouble(), prngB.nextInt(1, 100)];

      expect(valA1, equals(valA2));
      expect(valA1, isNot(equals(valB)));
    });

    test('Operator waveforms shape harmonic content', () {
      final voice = FMChipVoice();
      voice.algorithm = 7; // Additive
      voice.operators[0].totalLevel = 0.0;

      voice.operators[0].waveform = FMWaveform.sine;
      final sineSample = voice.operators[0].evaluateWaveform(0.5 * 3.14159);
      expect(sineSample, closeTo(1.0, 0.01));

      voice.operators[0].waveform = FMWaveform.square;
      final squareSample = voice.operators[0].evaluateWaveform(0.5 * 3.14159);
      expect(squareSample, equals(1.0));

      voice.operators[0].waveform = FMWaveform.saw;
      final sawSample = voice.operators[0].evaluateWaveform(0.0);
      expect(sawSample, closeTo(-1.0, 0.01));
    });

    test('Direct register writes configure operator multipliers and envelopes', () {
      final voice = FMChipVoice();

      // Write DT/MULT to Op 1 (0x30): Multiplier = 3, Detune = 0
      voice.writeRegister(0, 0x30, 0x03);
      expect(voice.operators[0].multiplier, equals(3.0));

      // Write TL to Op 1 (0x40): Total Level = 24
      voice.writeRegister(0, 0x40, 24);
      expect(voice.operators[0].totalLevel, equals(24.0));

      // Write Feedback & Alg (0xB0): Feedback = 6, Algorithm = 2
      voice.writeRegister(0, 0xB0, 0x32);
      expect(voice.feedback, equals(6));
      expect(voice.algorithm, equals(2));
    });

    test('Synthesizes valid Float32List audio buffer for chromatic notes', () {
      final voice = FMChipVoice();
      final buf = voice.synthesizeBuffer(freq: 220.0, durationSec: 0.2);

      expect(buf.length, equals((44100 * 0.2).toInt()));
      final maxAmp = buf.fold<double>(0.0, (m, s) => s.abs() > m ? s.abs() : m);
      expect(maxAmp, greaterThan(0.01));
      expect(maxAmp, lessThanOrEqualTo(1.0));
    });
  });

  group('SFXR Procedural Sound Generator Tests', () {
    test('SFXRGenerator.configureFromType handles all presets with deterministic seeds', () {
      final voice1 = FMChipVoice();
      final voice2 = FMChipVoice();

      // Laser
      SFXRGenerator.configureFromType(voice1, 0, seed: 100);
      SFXRGenerator.configureFromType(voice2, 0, seed: 100);
      expect(voice1.startFreqMult, equals(voice2.startFreqMult));
      expect(voice1.sweepDuration, equals(voice2.sweepDuration));

      // Explosion
      SFXRGenerator.configureFromType(voice1, 1, seed: 42);
      expect(voice1.noiseMode, isTrue);
      expect(voice1.noiseMix, greaterThan(0.4));

      // Powerup
      SFXRGenerator.configureFromType(voice1, 2, seed: 42);
      expect(voice1.startFreqMult, lessThan(voice1.endFreqMult));

      // Coin
      SFXRGenerator.configureFromType(voice1, 3, seed: 42);
      expect(voice1.sweepDuration, lessThanOrEqualTo(0.08));

      // Jump
      SFXRGenerator.configureFromType(voice1, 4, seed: 42);
      expect(voice1.startFreqMult, lessThan(voice1.endFreqMult));

      // Hit
      SFXRGenerator.configureFromType(voice1, 5, seed: 42);
      expect(voice1.noiseMode, isTrue);
    });

    test('Live parameters directly modulate active SFXR synthesized buffer', () {
      final sfxr = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'eats_sfxr');

      // Base Laser
      final buf1 = LuaEngine.synthesizeBuffer(
        code: sfxr.code,
        durationSec: 0.15,
        freq: 440.0,
        note: 69,
        params: {'SFXType': 0.0, 'Seed': 42.0, 'PitchSweep': 0.0},
      );

      // Same Laser but modified PitchSweep
      final buf2 = LuaEngine.synthesizeBuffer(
        code: sfxr.code,
        durationSec: 0.15,
        freq: 440.0,
        note: 69,
        params: {'SFXType': 0.0, 'Seed': 42.0, 'PitchSweep': 1.5},
      );

      expect(buf1.length, equals(buf2.length));
      // Buffers must not be identical because live parameters altered the sound!
      bool isDifferent = false;
      for (int i = 0; i < buf1.length; i++) {
        if ((buf1[i] - buf2[i]).abs() > 0.01) {
          isDifferent = true;
          break;
        }
      }
      expect(isDifferent, isTrue, reason: 'Live parameter changes (PitchSweep) must alter the sound output');
    });

    test('Changing seed produces deterministic variation of sound effect', () {
      final sfxr = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'eats_sfxr');

      final bufSeedA1 = LuaEngine.synthesizeBuffer(
        code: sfxr.code,
        durationSec: 0.15,
        freq: 440.0,
        note: 69,
        params: {'SFXType': 0.0, 'Seed': 101.0},
      );

      final bufSeedA2 = LuaEngine.synthesizeBuffer(
        code: sfxr.code,
        durationSec: 0.15,
        freq: 440.0,
        note: 69,
        params: {'SFXType': 0.0, 'Seed': 101.0},
      );

      final bufSeedB = LuaEngine.synthesizeBuffer(
        code: sfxr.code,
        durationSec: 0.15,
        freq: 440.0,
        note: 69,
        params: {'SFXType': 0.0, 'Seed': 888.0},
      );

      // Exact match for same seed
      for (int i = 0; i < bufSeedA1.length; i++) {
        expect(bufSeedA1[i], equals(bufSeedA2[i]));
      }

      // Variation for different seed
      bool diff = false;
      for (int i = 0; i < bufSeedA1.length; i++) {
        if ((bufSeedA1[i] - bufSeedB[i]).abs() > 0.0001) {
          diff = true;
          break;
        }
      }
      expect(diff, isTrue);
    });
  });

  group('Lua Preset Library Integration Tests', () {
    test('SFXType is the first parameter in SFXR preset', () {
      final sfxr = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'eats_sfxr');
      final compiled = LuaEngine.compile(sfxr.code);

      expect(compiled.isSuccess, isTrue);
      expect(compiled.params.first.name, equals('SFXType'));
      expect(compiled.params[1].name, equals('Seed'));
      expect(compiled.params[2].name, equals('Waveform'));
    });
  });
}
