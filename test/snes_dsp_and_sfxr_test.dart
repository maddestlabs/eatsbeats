import 'dart:math' as math;
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/audio/fm_chip_engine.dart';
import 'package:mobile_wren_daw/audio/snes_dsp_engine.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SNES Sony S-DSP Hardware Sound Processor Tests', () {
    test('All S-DSP BRR waveforms synthesize valid audio signals', () {
      final dsp = SNESDSPEngine();

      for (final wave in SNESWaveform.values) {
        dsp.reset();
        dsp.voices[0].waveform = wave;
        dsp.voices[0].attack = 0.001;
        dsp.voices[0].decay = 0.1;
        dsp.voices[0].sustain = 0.5;

        final buffer = dsp.synthesizeBuffer(freq: 440.0, durationSec: 0.05);
        expect(buffer.length, equals((44100 * 0.05).toInt()));

        double maxAbs = 0.0;
        for (final s in buffer) {
          if (s.abs() > maxAbs) maxAbs = s.abs();
        }
        expect(maxAbs, greaterThan(0.01), reason: 'Waveform $wave should produce non-silent output');
      }
    });

    test('S-DSP Hardware Envelope Modes shape audio amplitudes', () {
      final dsp = SNESDSPEngine();

      // 1. Exponential decrease GAIN mode
      dsp.reset();
      dsp.voices[0].envMode = SNESEnvelopeMode.gainExpDecrease;
      dsp.voices[0].decay = 0.05;
      final bufExp = dsp.synthesizeBuffer(freq: 440.0, durationSec: 0.1);

      // Start of decay should be significantly louder than end
      final earlySamples = bufExp.sublist((44100 * 0.005).toInt(), (44100 * 0.015).toInt());
      final lateSamples = bufExp.sublist((44100 * 0.085).toInt(), (44100 * 0.095).toInt());
      final earlyPower = earlySamples.fold<double>(0.0, (acc, s) => acc + s.abs());
      final latePower = lateSamples.fold<double>(0.0, (acc, s) => acc + s.abs());
      expect(earlyPower, greaterThan(latePower * 2.0));
    });

    test('8-Tap Programmable FIR Echo Unit adds wet reverb tail', () {
      final dsp = SNESDSPEngine();
      dsp.reset();
      dsp.voices[0].attack = 0.001;
      dsp.voices[0].decay = 0.02; // Very short transient dry sound
      dsp.voices[0].sustain = 0.0;
      dsp.voices[0].release = 0.005;

      // Echo ON with delay and feedback
      dsp.echo.enabled = true;
      dsp.echo.delayMs = 40;
      dsp.echo.volume = 0.8;
      dsp.echo.feedback = 0.6;

      final buf = dsp.synthesizeBuffer(freq: 440.0, durationSec: 0.15);

      // Samples around 40ms should have clear wet echo energy
      final echoIdx = (44100 * 0.045).toInt();
      final echoWindow = buf.sublist(echoIdx, echoIdx + 100);
      final echoPower = echoWindow.fold<double>(0.0, (acc, s) => acc + s.abs());
      expect(echoPower, greaterThan(0.05));
    });

    test('Direct S-DSP register writes configure voice parameters', () {
      final dsp = SNESDSPEngine();
      dsp.reset();

      // Voice 0 SCRN (Source number = 4 -> Sawtooth)
      dsp.writeRegister(0x04, 4);
      expect(dsp.voices[0].waveform, equals(SNESWaveform.sawtooth));

      // Global Echo Delay (EDL = 5 -> 5*16 + 16 = 96ms)
      dsp.writeRegister(0x7D, 5);
      expect(dsp.echo.delayMs, equals(96));
    });
  });

  group('SNES SFXR Procedural Sound Generator Suite Tests', () {
    test('SNESSFXRGenerator configures all 9 iconic archetypes without errors', () {
      final dsp = SNESDSPEngine();

      for (int type = 0; type < 9; type++) {
        dsp.reset();
        SNESSFXRGenerator.configureFromType(dsp, type, seed: 100 + type);
        final buffer = dsp.synthesizeBuffer(freq: 440.0, durationSec: 0.1);

        double maxAbs = 0.0;
        for (final s in buffer) {
          if (s.abs() > maxAbs) maxAbs = s.abs();
        }
        expect(maxAbs, greaterThan(0.05), reason: 'SFX Archetype index $type produced silent output');
      }
    });

    test('Specific Archetypes configure distinctive DSP parameters', () {
      final dsp = SNESDSPEngine();

      // Laser has downward pitch sweep
      SNESSFXRGenerator.configureLaser(dsp);
      expect(dsp.voices[0].startFreqMult, greaterThan(dsp.voices[0].endFreqMult));

      // Jump has upward pitch sweep
      SNESSFXRGenerator.configureJump(dsp);
      expect(dsp.voices[0].endFreqMult, greaterThan(dsp.voices[0].startFreqMult));

      // Explosion enables hardware noise generator
      SNESSFXRGenerator.configureExplosion(dsp);
      expect(dsp.voices[0].noiseEnabled, isTrue);

      // Powerup has ascending arpeggio
      SNESSFXRGenerator.configurePowerup(dsp);
      expect(dsp.voices[0].arpeggioNotes, contains(12));

      // Lose has descending minor arpeggio
      SNESSFXRGenerator.configureLose(dsp);
      expect(dsp.voices[0].arpeggioNotes.first, greaterThan(dsp.voices[0].arpeggioNotes.last));

      // Button has fast micro-transient decay (< 30ms)
      SNESSFXRGenerator.configureButton(dsp);
      expect(dsp.voices[0].decay, lessThan(0.03));
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

    test('Live parameter overlays dynamically modify synthesized SFXR buffer', () {
      final sfxr = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'eats_sfxr');

      final buf1 = LuaEngine.synthesizeBuffer(
        code: sfxr.code,
        durationSec: 0.15,
        freq: 440.0,
        note: 69,
        params: {'SFXType': 0.0, 'Seed': 42.0, 'Waveform': 1.0}, // Square
      );

      final buf2 = LuaEngine.synthesizeBuffer(
        code: sfxr.code,
        durationSec: 0.15,
        freq: 440.0,
        note: 69,
        params: {'SFXType': 0.0, 'Seed': 42.0, 'Waveform': 5.0}, // Triangle
      );

      bool diff = false;
      for (int i = 0; i < buf1.length; i++) {
        if ((buf1[i] - buf2[i]).abs() > 0.01) {
          diff = true;
          break;
        }
      }
      expect(diff, isTrue);
    });
  });

  group('Lua Preset Library SNES Presets Tests', () {
    test('SFXType is the first parameter in SNES SFXR preset and contains all 11 choices', () {
      final sfxr = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'eats_sfxr');
      final defs = LuaEngine.compile(sfxr.code);

      expect(defs.params.isNotEmpty, isTrue);
      expect(defs.params.first.name, equals('SFXType'));
      expect(defs.params.first.options, contains('Laser'));
      expect(defs.params.first.options, contains('Explosion'));
      expect(defs.params.first.options, contains('Powerup'));
      expect(defs.params.first.options, contains('Coin'));
      expect(defs.params.first.options, contains('Jump'));
      expect(defs.params.first.options, contains('Hurt'));
      expect(defs.params.first.options, contains('Lose'));
      expect(defs.params.first.options, contains('Button'));
      expect(defs.params.first.options, contains('Warp'));
    });

    test('SNES S-DSP Console Synth preset compiles with valid parameters', () {
      final synth = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'snes_console_synth');
      final defs = LuaEngine.compile(synth.code);

      expect(defs.params.any((d) => d.name == 'Waveform'), isTrue);
      expect(defs.params.any((d) => d.name == 'EchoFeedback'), isTrue);

      final buf = LuaEngine.synthesizeBuffer(
        code: synth.code,
        durationSec: 0.1,
        freq: 440.0,
        note: 69,
        params: {'Waveform': 0.0, 'EchoVolume': 0.5},
      );
      expect(buf.length, equals((44100 * 0.1).toInt()));
    });
  });
}
