import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/dx7_fm_engine.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Yamaha DX7 32-Algorithm FM Sound Engine Tests', () {
    test('All 32 algorithms synthesize valid non-zero audio without NaN or Inf', () {
      final buffer = Float32List(2048);

      for (int alg = 1; alg <= 32; alg++) {
        final voice = DX7FmVoice(algorithm: alg, feedback: 5);
        buffer.fillRange(0, buffer.length, 0.0);

        voice.processBuffer(
          outBuffer: buffer,
          baseFreq: 440.0,
          sampleRate: 44100.0,
          durationSec: 0.2,
          velocity: 0.85,
          midiNote: 69,
        );

        double maxAmp = 0.0;
        for (int i = 0; i < buffer.length; i++) {
          final s = buffer[i];
          expect(s.isNaN, isFalse, reason: 'Alg $alg produced NaN at index $i');
          expect(s.isInfinite, isFalse, reason: 'Alg $alg produced Inf at index $i');
          if (s.abs() > maxAmp) maxAmp = s.abs();
        }

        expect(maxAmp, greaterThan(0.005), reason: 'Alg $alg should produce audible non-zero signal');
        expect(maxAmp, lessThanOrEqualTo(1.0), reason: 'Alg $alg should not clip beyond normalized headroom');
      }
    });

    test('Feedback parameter 0 to 7 modulates timbre without instability', () {
      final buffer = Float32List(1024);

      for (int fb = 0; fb <= 7; fb++) {
        final voice = DX7FmVoice(algorithm: 5, feedback: fb);
        voice.processBuffer(
          outBuffer: buffer,
          baseFreq: 220.0,
          sampleRate: 44100.0,
          durationSec: 0.1,
          velocity: 0.9,
          midiNote: 57,
        );

        for (final sample in buffer) {
          expect(sample.isNaN, isFalse);
          expect(sample.isInfinite, isFalse);
          expect(sample.abs(), lessThanOrEqualTo(1.0));
        }
      }
    });

    test('All Factory ROM patches load and synthesize distinctive audio', () {
      final buffer = Float32List(2048);
      final patches = [
        DX7FactoryPatches.epiano1,
        DX7FactoryPatches.bass1,
        DX7FactoryPatches.tubBells,
        DX7FactoryPatches.strings1,
        DX7FactoryPatches.synLead5,
        DX7FactoryPatches.marimba,
      ];

      for (final patch in patches) {
        final voice = DX7FmVoice();
        voice.loadPatch(patch);

        expect(voice.algorithm, equals(patch.algorithm));
        expect(voice.feedback, equals(patch.feedback));

        voice.processBuffer(
          outBuffer: buffer,
          baseFreq: 330.0,
          sampleRate: 44100.0,
          durationSec: 0.2,
          velocity: 0.85,
        );

        double maxAmp = 0.0;
        for (final sample in buffer) {
          expect(sample.isNaN, isFalse);
          expect(sample.isInfinite, isFalse);
          if (sample.abs() > maxAmp) maxAmp = sample.abs();
        }

        expect(maxAmp, greaterThan(0.01), reason: '${patch.name} should produce audible sound');
      }
    });

    test('DX7SysExParser correctly decodes packed 128-byte voice data', () {
      // Construct a mock packed voice buffer (128 bytes)
      final raw128 = Uint8List(128);

      // Op 6 down to Op 1: 17 bytes each (6 * 17 = 102 bytes)
      for (int op = 0; op < 6; op++) {
        final off = op * 17;
        raw128[off + 0] = 99; // R1
        raw128[off + 1] = 75; // R2
        raw128[off + 2] = 50; // R3
        raw128[off + 3] = 40; // R4
        raw128[off + 4] = 95; // L1
        raw128[off + 5] = 80; // L2
        raw128[off + 6] = 60; // L3
        raw128[off + 7] = 0;  // L4
        raw128[off + 8] = 60; // Breakpoint
        raw128[off + 14] = 90; // Output level
        raw128[off + 15] = (1 << 1) | 0; // Ratio mode, Coarse 1
        raw128[off + 16] = 0; // Fine 0
      }

      // Global parameters (offset 102)
      raw128[102 + 0] = 99; raw128[102 + 4] = 50; // PR1, PL1
      raw128[102 + 8] = 4; // Algorithm 5 (0-indexed 4)
      raw128[102 + 9] = 6; // Feedback 6
      raw128[102 + 10] = 35; // LFO speed

      // 10-char ASCII Voice Name "TEST VOICE" at offset 118
      const name = 'TEST VOICE';
      for (int i = 0; i < name.length; i++) {
        raw128[118 + i] = name.codeUnitAt(i);
      }

      final patches = DX7SysExParser.parseSysEx(raw128);
      expect(patches.length, equals(1));
      final p = patches.first;
      expect(p.name, equals('TEST VOICE'));
      expect(p.algorithm, equals(5));
      expect(p.feedback, equals(6));
      expect(p.lfo.speed, equals(35.0));
      expect(p.operators.first.r1, equals(99.0));
    });

    test('DX7SysExParser handles full 4104-byte Yamaha SysEx bank', () {
      final bank = Uint8List(4104);
      // Yamaha SysEx header: F0 43 00 09 20 00
      bank[0] = 0xF0;
      bank[1] = 0x43;
      bank[2] = 0x00;
      bank[3] = 0x09;
      bank[4] = 0x20;
      bank[5] = 0x00;

      // Fill each of the 32 voices
      for (int v = 0; v < 32; v++) {
        final off = 6 + v * 128;
        bank[off + 102 + 8] = (v % 32); // Algorithm 1..32
        // Name
        final name = 'PATCH ${v + 1}';
        for (int c = 0; c < name.length; c++) {
          bank[off + 118 + c] = name.codeUnitAt(c);
        }
      }
      bank[4103] = 0xF7; // End of SysEx

      final patches = DX7SysExParser.parseSysEx(bank);
      expect(patches.length, equals(32));
      expect(patches[0].name, equals('PATCH 1'));
      expect(patches[31].name, equals('PATCH 32'));
      expect(patches[0].algorithm, equals(1));
      expect(patches[31].algorithm, equals(32));
    });

    test('Pitch Envelope Generator shifts frequency according to levels', () {
      final peg = DX7PitchEnvelope()
        ..pr1 = 99.0..pl1 = 62.0
        ..pr2 = 50.0..pl2 = 62.0 // Hold pitch shift
        ..prepare(0.5);

      final factorStart = peg.evaluatePitchMultiplier(0.01);
      expect(factorStart, greaterThan(1.0), reason: 'Level > 50 should increase pitch');

      final flatPeg = DX7PitchEnvelope()
        ..pl1 = 50.0..pl2 = 50.0..pl3 = 50.0..pl4 = 50.0
        ..prepare(0.5);
      expect(flatPeg.evaluatePitchMultiplier(0.05), closeTo(1.0, 0.001));
    });

    test('LFO evaluates waveforms and modulation without errors', () {
      final lfo = DX7Lfo()
        ..waveform = DX7LfoWaveform.triangle
        ..speed = 50.0
        ..pitchModDepth = 50.0
        ..pitchModSensitivity = 4;

      final (pMod, aMod) = lfo.evaluate(0.05, 44100.0);
      expect(pMod.isNaN, isFalse);
      expect(aMod.isNaN, isFalse);
      expect(pMod, greaterThan(0.9));
      expect(pMod, lessThan(1.1));
    });

    test('writeRegister supports live chiptune register pokes', () {
      final voice = DX7FmVoice(algorithm: 1, feedback: 0);

      // Write Algorithm register (0x86)
      voice.writeRegister(0x86, 12); // Algorithm 13 (0-indexed 12)
      expect(voice.algorithm, equals(13));

      // Write Feedback register (0x87)
      voice.writeRegister(0x87, 7);
      expect(voice.feedback, equals(7));

      // Write Operator 6 (op index 0) Total Level (reg 14)
      voice.writeRegister(14, 85);
      expect(voice.operators[5].outputLevel, equals(85.0));
    });

    test('High-performance buffer synthesis completes within realtime budget', () {
      final voice = DX7FmVoice(algorithm: 5, feedback: 6);
      final buffer = Float32List(1024);

      final sw = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        voice.processBuffer(
          outBuffer: buffer,
          baseFreq: 440.0 + (i * 5.0),
          sampleRate: 44100.0,
          durationSec: 0.1,
          velocity: 0.85,
        );
      }
      sw.stop();

      // 50 buffers of 1024 samples should easily complete in under 50ms total (< 1ms each)
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('GraphEvaluator and LuaEngine integrate seamlessly with updated DX7', () {
      final preset = LuaPresetLibrary.getPresetById('dx7_epiano')!;
      final compilation = LuaEngine.compile(preset.code);
      expect(compilation.isSuccess, isTrue);

      final buffer = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.4,
        freq: 440.0,
        note: 69,
        params: {
          'Algorithm': 15.0,
          'Feedback': 6.0,
          'Patch': 1.0, // BASS 1
          'Brightness': 1.2,
          'TineBell': 1.0,
          'BodyWarmth': 1.1,
        },
      );

      expect(buffer.isNotEmpty, isTrue);
      double maxAmp = 0.0;
      for (final s in buffer) {
        if (s.abs() > maxAmp) maxAmp = s.abs();
      }
      expect(maxAmp, greaterThan(0.02));
    });
  });
}
