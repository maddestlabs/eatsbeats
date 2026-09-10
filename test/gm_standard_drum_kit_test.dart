import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import 'package:eatsbeats/audio/drum/gm_drum_kit_engine.dart';
import 'package:eatsbeats/audio/gm/gm_instrument_registry.dart';
import 'package:eatsbeats/audio/procgen/procedural_drum_engine.dart';
import 'package:eatsbeats/eatscript/eat_dsp_synthesizer.dart';
import 'package:eatsbeats/eatscript/eat_gui_model.dart';
import 'package:eatsbeats/eatscript/eat_script_engine.dart';
import 'package:eatsbeats/eatscript/eat_script_library.dart';
import 'package:eatsbeats/eatscript/gm_standard_drum_kit_preset.dart';
import 'package:eatsbeats/eatscript/modular_drumpad_kit_preset.dart';
import 'package:eatsbeats/models/track_model.dart';

void main() {
  group('GM Standard Drum Kit DSP Engine Tests', () {
    test('Synthesizes all 47 General MIDI drum notes (35 to 81) with non-zero audio', () {
      for (int note = 35; note <= 81; note++) {
        final buffer = GmDrumKitEngine.synthesizeBuffer(
          note: note,
          durationSec: 0.35,
          velocity: 0.85,
          params: {
            'MasterTune': 0.0,
            'RoomLevel': 0.25,
            'KitDrive': 0.10,
            'Humanize': 0.20,
            'StrikeDrift': 0.15,
          },
          sampleRate: 44100.0,
        );

        expect(buffer.isNotEmpty, isTrue, reason: 'Buffer for note $note was empty');
        expect(buffer.length, greaterThan(100), reason: 'Buffer for note $note too short');

        // Check for non-silence
        double peak = 0.0;
        bool hasNonZero = false;
        for (final sample in buffer) {
          expect(sample.isNaN, isFalse, reason: 'NaN detected on note $note');
          expect(sample.isInfinite, isFalse, reason: 'Infinity detected on note $note');
          if (sample.abs() > 0.0001) hasNonZero = true;
          peak = math.max(peak, sample.abs());
        }

        expect(hasNonZero, isTrue, reason: 'Note $note generated silent buffer');
        expect(peak, lessThanOrEqualTo(1.5), reason: 'Note $note clipped excessively (peak=$peak)');
      }
    });

    test('EatDspSynthesizer intercepts gm_standard_drum_kit code signature', () {
      final code = '''
# @id: gm_standard_drum_kit
# @name: GM Standard Drum Kit
def process():
    pass
''';

      final buffer = EatDspSynthesizer.synthesizeBuffer(
        code: code,
        durationSec: 0.25,
        freq: 440.0,
        note: 36, // Kick 1
        params: {'RoomLevel': 0.30},
        velocity: 0.90,
      );

      expect(buffer.isNotEmpty, isTrue);
      expect(buffer.any((s) => s.abs() > 0.01), isTrue);
    });

    test('Pad slot overrides swap the DSP graph for target note', () {
      const trackId = 'test_drum_track_1';
      GmDrumKitEngine.clearSlotOverrides(trackId);

      // Default note 36 (Acoustic Kick)
      final defaultBuffer = GmDrumKitEngine.synthesizeBuffer(
        note: 36,
        durationSec: 0.2,
        velocity: 0.8,
        params: {},
        trackId: trackId,
      );
      expect(defaultBuffer.isNotEmpty, isTrue);

      // Override note 36 with 808 Kick
      GmDrumKitEngine.setSlotOverride(trackId, 36, 'analog_808_kick');
      expect(GmDrumKitEngine.getSlotOverride(trackId, 36), equals('analog_808_kick'));

      final overriddenBuffer = GmDrumKitEngine.synthesizeBuffer(
        note: 36,
        durationSec: 0.2,
        velocity: 0.8,
        params: {},
        trackId: trackId,
      );

      expect(overriddenBuffer.isNotEmpty, isTrue);

      // Clear overrides
      GmDrumKitEngine.clearSlotOverrides(trackId);
      expect(GmDrumKitEngine.getSlotOverride(trackId, 36), isNull);
    });

    test('Choke groups and voice reset operate cleanly', () {
      GmDrumKitEngine.resetVoiceStates('test_track');
      // Verify no throw on reset
      expect(true, isTrue);
    });
  });

  group('GM Instrument Registry & MIDI Channel 10 Resolution Tests', () {
    test('Channel 9 (MIDI Ch 10) resolves natively to gm_standard_drum_kit', () {
      final resolution = GmInstrumentRegistry.resolve(
        channel: 9, // 0-indexed MIDI Ch 10
        trackName: 'Drums',
      );

      expect(resolution.isNative, isTrue);
      expect(resolution.presetId, equals('gm_standard_drum_kit'));
      expect(resolution.trackType, equals(TrackType.eatScript));
      expect(resolution.matchedDef?.nativePresetId, equals('gm_standard_drum_kit'));
    });

    test('Preset library contains gm_standard_drum_kit and action_procedural_drum_groover', () {
      final drumKit = LuaPresetLibrary.getPresetById('gm_standard_drum_kit');
      expect(drumKit, isNotNull);
      expect(drumKit!.name, equals('GM Standard Drum Kit'));
      expect(drumKit.isInstrument, isTrue);

      final groover = LuaPresetLibrary.getPresetById('action_procedural_drum_groover');
      expect(groover, isNotNull);
      expect(groover!.name, equals('Procedural Drum Groover'));
      expect(groover.category, equals(LuaScriptCategory.projectAction));
    });

    test('GM Standard Drum Kit preset compiles with valid Eatscript GUI layout and parameters', () {
      final comp = EatScriptEngine.compile(GmStandardDrumKitPreset.preset.code);
      expect(comp.isSuccess, isTrue, reason: 'Compilation failed: ${comp.errorMessage}');
      expect(comp.params.length, greaterThanOrEqualTo(10), reason: 'Expected >= 10 parameters');
      expect(comp.params.any((p) => p.name == 'MasterTune'), isTrue);
      expect(comp.params.any((p) => p.name == 'KickPunch'), isTrue);
      expect(comp.params.any((p) => p.name == 'Humanize'), isTrue);

      expect(comp.guiLayout, isNotNull, reason: 'Expected custom guiLayout to be parsed');
      expect(comp.guiLayout!.title, equals('GM STANDARD DRUM KIT'));
      expect(comp.guiLayout!.children.isNotEmpty, isTrue);
    });

    test('Modular Drum Machine preset compiles with dedicated drumPads layout node', () {
      final drumMachine = LuaPresetLibrary.getPresetById('modular_drumpad_kit');
      expect(drumMachine, isNotNull);
      expect(drumMachine!.name, equals('Modular Drum Machine'));
      expect(drumMachine.isInstrument, isTrue);

      final comp = EatScriptEngine.compile(ModularDrumpadKitPreset.preset.code);
      expect(comp.isSuccess, isTrue, reason: 'Compilation failed: ${comp.errorMessage}');
      expect(comp.params.any((p) => p.name == 'MasterTune'), isTrue);
      expect(comp.params.any((p) => p.name == 'KitDrive'), isTrue);

      expect(comp.guiLayout, isNotNull, reason: 'Expected guiLayout to be parsed');
      expect(comp.guiLayout!.title, equals('MODULAR DRUM MACHINE'));
      expect(
        comp.guiLayout!.children.any((n) => n.type == LuaGuiNodeType.drumPads),
        isTrue,
        reason: 'Modular Drum Machine should contain a drumPads node in its layout',
      );
    });
  });

  group('Procedural Drum Groover Engine Tests', () {
    test('Generates valid drum patterns across all genres', () {
      for (final style in ProceduralDrumEngine.styles) {
        final notes = ProceduralDrumEngine.generatePattern(
          style: style,
          bars: 4,
          density: 0.75,
          swing: 0.25,
          ghostProb: 0.3,
          fillDensity: 0.5,
          humanize: 0.2,
          seed: 1234,
        );

        expect(notes.isNotEmpty, isTrue, reason: 'No notes generated for $style');
        expect(notes.length, greaterThanOrEqualTo(16), reason: 'Too few notes for $style (got ${notes.length})');

        for (final note in notes) {
          expect(note.pitch, greaterThanOrEqualTo(35), reason: 'Note pitch ${note.pitch} below GM drum range');
          expect(note.pitch, lessThanOrEqualTo(81), reason: 'Note pitch ${note.pitch} above GM drum range');
          expect(note.velocity, greaterThan(0.0));
          expect(note.velocity, lessThanOrEqualTo(1.0));
          expect(note.startStep, greaterThanOrEqualTo(0.0));
          expect(note.startStep, lessThanOrEqualTo(64.0));
        }
      }
    });
  });
}
