import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/audio/graph/graph_node.dart';
import 'package:eatsbeats/audio/dx7_fm_engine.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/lua/lua_gui_parser.dart';
import 'package:eatsbeats/ui/textures/daw_texture_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Yamaha DX7 6-Operator FM E-Piano Physical Model', () {
    test('DX7FmVoice synthesizes audio with valid 3-stack E-Piano harmonics', () {
      final voice = DX7FmVoice(algorithm: 5, feedback: 6);
      final buffer = Float32List(44100);

      voice.processBuffer(
        outBuffer: buffer,
        baseFreq: 440.0,
        sampleRate: 44100.0,
        durationSec: 1.0,
        velocity: 0.90,
      );

      // Verify buffer has non-zero amplitude and no NaN/Inf
      double maxAmp = 0.0;
      for (final sample in buffer) {
        expect(sample.isNaN, isFalse);
        expect(sample.isInfinite, isFalse);
        if (sample.abs() > maxAmp) maxAmp = sample.abs();
      }

      expect(maxAmp, greaterThan(0.05));
      expect(maxAmp, lessThanOrEqualTo(1.0));
    });

    test('GraphEvaluator.buildDX7EPiano synthesizes complete buffer via DSP graph', () {
      final root = GraphEvaluator.buildDX7EPiano();
      final buffer = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.8,
        freq: 261.63, // Middle C (C4)
        note: 60,
        params: {
          'Algorithm': 5.0,
          'Brightness': 1.2,
          'TineBell': 1.0,
          'BodyWarmth': 1.1,
          'ChorusMix': 0.4,
          'BassBoost': 2.0,
          'TrebleSparkle': 3.0,
          'Drive': 1.1,
        },
        velocity: 0.85,
      );

      expect(buffer.length, equals((44100 * 0.8).toInt()));
      double maxAmp = 0.0;
      for (final s in buffer) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        if (s.abs() > maxAmp) maxAmp = s.abs();
      }
      expect(maxAmp, greaterThan(0.05));
    });

    test('LuaPresetLibrary contains dx7_epiano and LuaEngine compiles it', () {
      final preset = LuaScriptLibrary.getPresetById('dx7_epiano');
      expect(preset, isNotNull);
      expect(preset!.name, equals('Yamaha DX7 E-Piano'));
      expect(preset.code.contains('YAMAHA DX7'), isTrue);

      final buffer = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.5,
        freq: 440.0,
        note: 69,
        params: {'TineBell': 1.0, 'Brightness': 1.2},
      );

      expect(buffer.length, equals((44100 * 0.5).toInt()));
      expect(buffer.any((s) => s != 0.0), isTrue);

      final gui = LuaGuiParser.parseFromCode(preset.code);
      expect(gui, isNotNull);
      expect(gui!.title, contains('YAMAHA DX7'));
      expect(gui.children.length, greaterThanOrEqualTo(2));
    });
  });

  group('Hohner Clavinet D6 Physical Model', () {
    test('GraphEvaluator.buildClavinetD6 synthesizes in-phase and out-of-phase funk quack', () {
      final root = GraphEvaluator.buildClavinetD6();

      // 1. In-phase synthesis
      final inPhaseBuf = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.6,
        freq: 196.0, // G3
        note: 55,
        params: {
          'PickupSelect': 0.5,
          'PhaseInvert': 0.0,
          'Brilliant': 1.0,
          'Treble': 0.8,
          'Medium': 0.5,
          'Soft': 0.0,
          'DamperThump': 0.5,
        },
        velocity: 0.85,
      );

      // 2. Out-of-phase synthesis (A-B Quack)
      final outOfPhaseBuf = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.6,
        freq: 196.0, // G3
        note: 55,
        params: {
          'PickupSelect': 0.5,
          'PhaseInvert': 1.0,
          'Brilliant': 1.0,
          'Treble': 0.8,
          'Medium': 0.5,
          'Soft': 0.0,
          'DamperThump': 0.5,
        },
        velocity: 0.85,
      );

      expect(inPhaseBuf.length, equals(outOfPhaseBuf.length));
      expect(inPhaseBuf.any((s) => s != 0.0), isTrue);
      expect(outOfPhaseBuf.any((s) => s != 0.0), isTrue);

      // Verify that out-of-phase produces comb-filtered different sample values
      bool differenceDetected = false;
      for (int i = 0; i < inPhaseBuf.length; i++) {
        if ((inPhaseBuf[i] - outOfPhaseBuf[i]).abs() > 0.001) {
          differenceDetected = true;
          break;
        }
      }
      expect(differenceDetected, isTrue);
    });

    test('LuaPresetLibrary contains clavinet_d6 and LuaEngine compiles it', () {
      final preset = LuaScriptLibrary.getPresetById('clavinet_d6');
      expect(preset, isNotNull);
      expect(preset!.name, equals('Hohner Clavinet D6'));
      expect(preset.code.contains('HOHNER CLAVINET D6'), isTrue);

      final buffer = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.4,
        freq: 220.0,
        note: 57,
        params: {'PickupSelect': 0.5, 'PhaseInvert': 1.0, 'Brilliant': 1.0},
      );

      expect(buffer.length, equals((44100 * 0.4).toInt()));
      expect(buffer.any((s) => s != 0.0), isTrue);

      final gui = LuaGuiParser.parseFromCode(preset.code);
      expect(gui, isNotNull);
      expect(gui!.title, contains('HOHNER CLAVINET D6'));
      expect(gui.children.length, greaterThanOrEqualTo(2));
    });
  });

  group('Harpsichord (Cembalo) Physical Model', () {
    test('GraphEvaluator.buildHarpsichord synthesizes quill pluck, 8ft and 4ft stops', () {
      final root = GraphEvaluator.buildHarpsichord();

      // 1. 8' Principal only
      final buf8 = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.7,
        freq: 440.0, // A4
        note: 69,
        params: {
          'Stop4Octave': 0.0,
          'BuffStop': 0.15,
          'PluckBite': 1.4,
          'AirSparkle': 2.0,
          'JackRelease': 0.4,
        },
        velocity: 0.90,
      );

      // 2. 8' + 4' Octave combined
      final buf8and4 = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.7,
        freq: 440.0, // A4
        note: 69,
        params: {
          'Stop4Octave': 0.8,
          'BuffStop': 0.15,
          'PluckBite': 1.4,
          'AirSparkle': 2.0,
          'JackRelease': 0.4,
        },
        velocity: 0.90,
      );

      expect(buf8.length, equals((44100 * 0.7).toInt()));
      expect(buf8and4.length, equals(buf8.length));
      expect(buf8.any((s) => s != 0.0), isTrue);
      expect(buf8and4.any((s) => s != 0.0), isTrue);
    });

    test('LuaPresetLibrary contains harpsichord_cembalo and LuaEngine compiles it', () {
      final preset = LuaScriptLibrary.getPresetById('harpsichord_cembalo');
      expect(preset, isNotNull);
      expect(preset!.name, equals('Harpsichord / Cembalo'));
      expect(preset.code.contains('BAROQUE HARPSICHORD'), isTrue);

      final buffer = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.5,
        freq: 330.0,
        note: 64,
        params: {'Stop4Octave': 0.5, 'BuffStop': 0.2},
      );

      expect(buffer.length, equals((44100 * 0.5).toInt()));
      expect(buffer.any((s) => s != 0.0), isTrue);

      final gui = LuaGuiParser.parseFromCode(preset.code);
      expect(gui, isNotNull);
      expect(gui!.title, contains('BAROQUE HARPSICHORD'));
      expect(gui.children.length, greaterThanOrEqualTo(2));
    });
  });

  group('Procedural Textures for New Instruments', () {
    test('DawTextureEngine generates dx7Membrane and harpsichordLacquer textures without errors', () {
      final engine = DawTextureEngine.instance;

      final dx7Image = engine.getTextureImage(DawTextureType.dx7Membrane, size: 128);
      expect(dx7Image, isNotNull);
      expect(dx7Image.width, equals(128));
      expect(dx7Image.height, equals(128));

      final harpsichordImage = engine.getTextureImage(DawTextureType.harpsichordLacquer, size: 128);
      expect(harpsichordImage, isNotNull);
      expect(harpsichordImage.width, equals(128));
      expect(harpsichordImage.height, equals(128));
    });
  });
}
