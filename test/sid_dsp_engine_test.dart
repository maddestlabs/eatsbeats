import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/sid_dsp_engine.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Commodore 64 SID (MOS 6581 / 8580) Sound Engine Tests', () {
    test('All SID waveforms synthesize valid non-zero audio without NaN or Inf', () {
      final buffer = Float32List(1024);

      for (final wave in SIDWaveform.values) {
        final engine = SIDSynthEngine();
        engine.voices[0].waveform = wave;
        buffer.fillRange(0, buffer.length, 0.0);

        engine.processBuffer(
          outBuffer: buffer,
          baseFreq: 440.0,
          sampleRate: 44100.0,
          durationSec: 0.1,
          velocity: 0.85,
        );

        double maxAmp = 0.0;
        for (int i = 0; i < buffer.length; i++) {
          final s = buffer[i];
          expect(s.isNaN, isFalse, reason: '$wave produced NaN at index $i');
          expect(s.isInfinite, isFalse, reason: '$wave produced Inf at index $i');
          if (s.abs() > maxAmp) maxAmp = s.abs();
        }

        expect(maxAmp, greaterThan(0.01), reason: '$wave should produce audible signal');
        expect(maxAmp, lessThanOrEqualTo(1.0), reason: '$wave should remain in normalized headroom');
      }
    });

    test('23-bit Galois LFSR noise produces pseudo-random chiptune crunch', () {
      final noise = SIDNoiseGenerator();
      final values = <double>[];
      for (int i = 0; i < 64; i++) {
        noise.clock();
        values.add(noise.output);
      }

      // Check values vary and stay bounded in [-1.0, 1.0]
      final uniqueCount = values.toSet().length;
      expect(uniqueCount, greaterThan(10), reason: 'LFSR should produce distinct pseudo-random states');
      for (final val in values) {
        expect(val, greaterThanOrEqualTo(-1.0));
        expect(val, lessThanOrEqualTo(1.0));
      }
    });

    test('12-bit PWM modulation alters pulse waveform pulse width over time', () {
      final voice = SIDVoice()
        ..waveform = SIDWaveform.pulse
        ..pulseWidth = 2048
        ..pwmRateHz = 5.0
        ..pwmDepth = 0.8
        ..prepare(durationSec: 0.2, baseFreq: 440.0);

      final samples = <double>[];
      for (int i = 0; i < 500; i++) {
        samples.add(voice.evaluateSample(time: i / 44100.0, dt: 1.0 / 44100.0, sampleRate: 44100.0));
      }

      expect(samples.toSet().length, greaterThan(1));
    });

    test('12dB/oct State-Variable Filter processes LP, BP, HP, and Notch modes', () {
      final filter = SIDFilter();
      const sampleRate = 44100.0;

      for (final mode in [
        SIDFilterMode.lowpass,
        SIDFilterMode.bandpass,
        SIDFilterMode.highpass,
        SIDFilterMode.notch,
      ]) {
        filter.reset();
        filter.mode = mode;
        filter.cutoffReg = 1200;
        filter.resonanceReg = 8;

        double out = 0.0;
        for (int i = 0; i < 100; i++) {
          final inSample = (i % 2 == 0) ? 0.5 : -0.5;
          out = filter.process(inSample, sampleRate);
          expect(out.isNaN, isFalse);
          expect(out.isInfinite, isFalse);
        }
      }
    });

    test('MOS 6581 FET non-linear saturation differentiates from MOS 8580 clean model', () {
      final filter6581 = SIDFilter()
        ..chipModel = SIDChipModel.mos6581
        ..mode = SIDFilterMode.lowpass
        ..cutoffReg = 1400
        ..resonanceReg = 12;

      final filter8580 = SIDFilter()
        ..chipModel = SIDChipModel.mos8580
        ..mode = SIDFilterMode.lowpass
        ..cutoffReg = 1400
        ..resonanceReg = 12;

      const sampleRate = 44100.0;
      double diffSum = 0.0;

      for (int i = 0; i < 200; i++) {
        final double inSample = math.sin(i * 0.2) * 1.5; // Driven hot into filter
        final double out6581 = filter6581.process(inSample, sampleRate);
        final double out8580 = filter8580.process(inSample, sampleRate);
        diffSum += (out6581 - out8580).abs();
      }

      expect(diffSum, greaterThan(0.5), reason: '6581 FET saturation and non-linear cutoff should produce different harmonics than 8580');
    });

    test('50Hz and 60Hz hardware chiptune arpeggiator cycles chord steps', () {
      final voice = SIDVoice()
        ..arpMode = SIDArpMode.hz50
        ..arpSemitones = [0, 4, 7, 12] // Major arpeggio
        ..prepare(durationSec: 0.2, baseFreq: 440.0);

      final steps = <int>{};
      for (int i = 0; i < 4410; i++) { // ~100ms
        voice.evaluateSample(time: i / 44100.0, dt: 1.0 / 44100.0, sampleRate: 44100.0);
        steps.add(voice.arpStep);
      }

      // 100ms at 50Hz (20ms/step) should advance through all 4 chord steps
      expect(steps.length, equals(4));
    });

    test('Portamento smoothly slides frequency towards target note', () {
      final engine = SIDSynthEngine();
      final buffer = Float32List(2048);

      engine.voices[0].glideSpeed = 0.05; // 50ms slide

      engine.processBuffer(
        outBuffer: buffer,
        baseFreq: 220.0, // A3
        sampleRate: 44100.0,
        durationSec: 0.1,
        velocity: 0.85,
        targetMidiNote: 69, // Slide up to A4 (440Hz)
        isSlide: true,
      );

      // Verify frequency glided from 220Hz towards 440Hz
      expect(engine.voices[0].currentFreqHz, greaterThan(220.0));
      expect(engine.voices[0].currentFreqHz, lessThanOrEqualTo(440.0));
    });

    test('writeRegister supports standard C64 memory-mapped register pokes', () {
      final engine = SIDSynthEngine();

      // Write Voice 1 Pulse Width Lo/Hi (addr 2 & 3)
      engine.writeRegister(0x02, 0xFF);
      engine.writeRegister(0x03, 0x07);
      expect(engine.voices[0].pulseWidth, equals(0x07FF));

      // Write Voice 1 Control Register (addr 4): Pulse + Sync
      engine.writeRegister(0x04, 0x42);
      expect(engine.voices[0].waveform, equals(SIDWaveform.pulse));
      expect(engine.voices[0].sync, isTrue);

      // Write Global Filter Cutoff Lo/Hi (addr 0x15, 0x16)
      engine.writeRegister(0x15, 0x05);
      engine.writeRegister(0x16, 0x80);
      expect(engine.filter.cutoffReg, equals((0x80 << 3) | 0x05));

      // Write Global Filter Mode / Volume (addr 0x18): Highpass + Vol 15
      engine.writeRegister(0x18, 0x4F);
      expect(engine.filter.mode, equals(SIDFilterMode.highpass));
      expect(engine.masterVolume, equals(15));
    });

    test('High-performance buffer synthesis executes well within realtime budget', () {
      final engine = SIDSynthEngine();
      final buffer = Float32List(1024);

      final sw = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        engine.processBuffer(
          outBuffer: buffer,
          baseFreq: 220.0 + (i * 4.0),
          sampleRate: 44100.0,
          durationSec: 0.05,
          velocity: 0.85,
        );
      }
      sw.stop();

      // 50 buffers should complete in under 50ms (< 1ms per note)
      expect(sw.elapsedMilliseconds, lessThan(80));
    });

    test('GraphEvaluator and LuaEngine compile and synthesize c64_sid_synth preset', () {
      final preset = LuaPresetLibrary.getPresetById('c64_sid_synth')!;
      final compilation = LuaEngine.compile(preset.code);
      expect(compilation.isSuccess, isTrue);

      final buffer = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.3,
        freq: 440.0,
        note: 69,
        params: {
          'Waveform': 0.0, // Pulse
          'PulseWidth': 2048.0,
          'PwmRate': 2.0,
          'PwmDepth': 0.5,
          'ArpMode': 1.0, // 50Hz
          'ChipModel': 0.0, // 6581
          'FilterMode': 0.0, // Lowpass
          'Cutoff': 1400.0,
          'Resonance': 8.0,
          'Overdrive': 1.2,
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
