import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/lua/lua_gui_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Acoustic Bass Guitar Physical Model', () {
    test('GraphEvaluator.buildAcousticBass synthesizes bronze-wound acoustic bass audio', () {
      final root = GraphEvaluator.buildAcousticBass();

      final buffer = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.6,
        freq: 82.41, // E2
        note: 40,
        params: {
          'PluckForce': 1.4,
          'NailClick': 0.4,
          'Sustain': 0.995,
          'Damping': 0.25,
          'AcousticAir': 2.0,
          'Drive': 1.05,
        },
        velocity: 0.85,
      );

      expect(buffer.length, equals((44100 * 0.6).toInt()));
      expect(buffer.any((s) => s != 0.0), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('LuaPresetLibrary contains acoustic_bass and compiles with GUI', () {
      final preset = LuaScriptLibrary.getPresetById('acoustic_bass');
      expect(preset, isNotNull);
      expect(preset!.name, equals('Acoustic Bass Guitar'));

      final buffer = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.4,
        freq: 55.0, // A1
        note: 33,
        params: {'PluckForce': 1.2, 'Sustain': 0.99},
      );

      expect(buffer.length, equals((44100 * 0.4).toInt()));
      expect(buffer.any((s) => s != 0.0), isTrue);

      final gui = LuaGuiParser.parseFromCode(preset.code);
      expect(gui, isNotNull);
      expect(gui!.title, contains('ACOUSTIC BASS'));
      expect(gui.children.length, greaterThanOrEqualTo(1));
    });
  });

  group('Fretless Electric J-Bass Physical Model', () {
    test('GraphEvaluator.buildFretlessBass synthesizes Jaco Mwah and bridge bark', () {
      final root = GraphEvaluator.buildFretlessBass();

      // Normal pluck
      final flatBuf = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.6,
        freq: 73.42, // D2
        note: 38,
        params: {
          'MwahAmount': 0.0,
          'Growl': 0.0,
          'BridgePickup': 0.5,
          'MidBark': 0.0,
        },
        velocity: 0.85,
      );

      // High Mwah bloom
      final mwahBuf = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.6,
        freq: 73.42, // D2
        note: 38,
        params: {
          'MwahAmount': 1.0,
          'Growl': 0.8,
          'BridgePickup': 0.95,
          'MidBark': 4.0,
        },
        velocity: 0.85,
      );

      expect(flatBuf.length, equals(mwahBuf.length));
      expect(flatBuf.any((s) => s != 0.0), isTrue);
      expect(mwahBuf.any((s) => s != 0.0), isTrue);

      // Verify that Mwah introduces dynamic harmonic difference
      bool differenceDetected = false;
      for (int i = 0; i < flatBuf.length; i++) {
        if ((flatBuf[i] - mwahBuf[i]).abs() > 0.005) {
          differenceDetected = true;
          break;
        }
      }
      expect(differenceDetected, isTrue);
    });

    test('LuaPresetLibrary contains fretless_bass and compiles with GUI', () {
      final preset = LuaScriptLibrary.getPresetById('fretless_bass');
      expect(preset, isNotNull);
      expect(preset!.name, equals('Fretless J-Bass'));

      final buffer = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.4,
        freq: 65.41, // C2
        note: 36,
        params: {'MwahAmount': 0.8, 'BridgePickup': 0.9},
      );

      expect(buffer.length, equals((44100 * 0.4).toInt()));
      expect(buffer.any((s) => s != 0.0), isTrue);

      final gui = LuaGuiParser.parseFromCode(preset.code);
      expect(gui, isNotNull);
      expect(gui!.title, contains('FRETLESS J-BASS'));
    });
  });

  group('Upright Double Bass Physical Model', () {
    test('GraphEvaluator.buildUprightBass synthesizes 3/4 double bass with wood slap', () {
      final root = GraphEvaluator.buildUprightBass();

      // Soft pluck (no slap)
      final softBuf = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.7,
        freq: 41.20, // Low E1
        note: 28,
        params: {'FingerMass': 1.2, 'SlapClick': 0.0, 'SubWarmth': 3.0},
        velocity: 0.40,
      );

      // Hard slap pluck
      final slapBuf = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.7,
        freq: 41.20, // Low E1
        note: 28,
        params: {'FingerMass': 2.0, 'SlapClick': 1.2, 'SubWarmth': 4.0},
        velocity: 0.95,
      );

      expect(softBuf.length, equals(slapBuf.length));
      expect(softBuf.any((s) => s != 0.0), isTrue);
      expect(slapBuf.any((s) => s != 0.0), isTrue);
    });

    test('LuaPresetLibrary contains upright_bass and compiles with GUI', () {
      final preset = LuaScriptLibrary.getPresetById('upright_bass');
      expect(preset, isNotNull);
      expect(preset!.name, equals('Upright Double Bass'));

      final buffer = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.5,
        freq: 49.00, // G1
        note: 31,
        params: {'FingerMass': 1.6, 'SlapClick': 0.8},
      );

      expect(buffer.length, equals((44100 * 0.5).toInt()));
      expect(buffer.any((s) => s != 0.0), isTrue);

      final gui = LuaGuiParser.parseFromCode(preset.code);
      expect(gui, isNotNull);
      expect(gui!.title, contains('UPRIGHT DOUBLE BASS'));
    });
  });

  group('Model D / Analog Sub Synth Bass', () {
    test('GraphEvaluator.buildMoogSynthBass synthesizes 4-pole Moog ladder sub bass', () {
      final root = GraphEvaluator.buildMoogSynthBass();

      final buffer = GraphEvaluator.evaluate(
        root: root,
        durationSec: 0.5,
        freq: 55.0, // A1
        note: 33,
        params: {
          'Cutoff': 450.0,
          'Resonance': 0.75,
          'FilterEnv': 0.80,
          'Decay': 0.35,
          'AmpDecay': 0.75,
          'Drive': 1.30,
        },
        velocity: 0.90,
      );

      expect(buffer.length, equals((44100 * 0.5).toInt()));
      expect(buffer.any((s) => s != 0.0), isTrue);
      expect(buffer.any((s) => s.abs() > 0.05), isTrue);
    });

    test('LuaPresetLibrary contains moog_synth_bass and compiles with GUI', () {
      final preset = LuaScriptLibrary.getPresetById('moog_synth_bass');
      expect(preset, isNotNull);
      expect(preset!.name, equals('Model D Sub Synth Bass'));

      final buffer = LuaEngine.synthesizeBuffer(
        code: preset.code,
        durationSec: 0.4,
        freq: 41.2, // E1
        note: 28,
        params: {'Cutoff': 500.0, 'Resonance': 0.6},
      );

      expect(buffer.length, equals((44100 * 0.4).toInt()));
      expect(buffer.any((s) => s != 0.0), isTrue);

      final gui = LuaGuiParser.parseFromCode(preset.code);
      expect(gui, isNotNull);
      expect(gui!.title, contains('MODEL D'));
    });
  });
}
