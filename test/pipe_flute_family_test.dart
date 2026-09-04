import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/gm/gm_instrument_registry.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_gui_model.dart';
import 'package:eatsbeats/lua/lua_gui_parser.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/models/daw_state.dart';

Uint8List _createMidiFileWithTracks({
  required int bpm,
  required List<({String name, int? program, int channel, List<int> notes})> tracks,
  int ppqn = 480,
}) {
  final builder = BytesBuilder();

  // Header chunk (Format 1, N tracks, PPQN)
  builder.add([0x4D, 0x54, 0x68, 0x64]);
  builder.add([0x00, 0x00, 0x00, 0x06]);
  builder.add([0x00, 0x01]);
  builder.add([(tracks.length >> 8) & 0xFF, tracks.length & 0xFF]);
  builder.add([(ppqn >> 8) & 0xFF, ppqn & 0xFF]);

  for (int i = 0; i < tracks.length; i++) {
    final t = tracks[i];
    final trackBytes = BytesBuilder();

    // Track Name Meta Event
    final nameEncoded = utf8.encode(t.name);
    trackBytes.add([0x00, 0xFF, 0x03, nameEncoded.length]);
    trackBytes.add(nameEncoded);

    if (i == 0) {
      final usPerQuarter = (60000000 / bpm).round();
      trackBytes.add([
        0x00,
        0xFF,
        0x51,
        0x03,
        (usPerQuarter >> 16) & 0xFF,
        (usPerQuarter >> 8) & 0xFF,
        usPerQuarter & 0xFF,
      ]);
    }

    final ch = t.channel.clamp(0, 15);
    if (t.program != null) {
      trackBytes.add([0x00, 0xC0 | ch, t.program! & 0x7F]);
    }

    for (int n = 0; n < t.notes.length; n++) {
      final pitch = t.notes[n];
      trackBytes.add([0x00, 0x90 | ch, pitch, 100]);
      trackBytes.add([0x83, 0x60, 0x80 | ch, pitch, 64]);
    }

    trackBytes.add([0x00, 0xFF, 0x2F, 0x00]);

    final trackData = trackBytes.toBytes();
    builder.add([0x4D, 0x54, 0x72, 0x6B]);
    final len = trackData.length;
    builder.add([(len >> 24) & 0xFF, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF]);
    builder.add(trackData);
  }

  return builder.toBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pipeInstrumentIds = [
    'concert_piccolo',
    'concert_flute',
    'wooden_recorder',
    'pan_flute',
    'blown_bottle',
    'shakuhachi_bamboo',
    'tin_whistle',
    'sweet_ocarina',
  ];

  group('General MIDI Pipe Family Native Physical Models Tests', () {
    test('All 8 Pipe Family presets exist in LuaScriptLibrary with valid metadata & GUIs', () {
      for (final id in pipeInstrumentIds) {
        final preset = LuaScriptLibrary.getPresetById(id);
        expect(preset, isNotNull, reason: 'Preset $id should exist in LuaScriptLibrary');
        expect(preset!.category, equals(LuaPresetCategory.instrument));
        expect(preset.name.isNotEmpty, isTrue);
        expect(preset.description.isNotEmpty, isTrue);
        expect(preset.code.contains('function'), isTrue);
        expect(preset.code.contains('.init()'), isTrue);
        expect(preset.code.contains('.process('), isTrue);
        expect(preset.code.contains('.gui()'), isTrue);
      }
    });

    test('All 8 Pipe instruments have interactive hardware rack GUIs matching Renaissance Lute style', () {
      for (final id in pipeInstrumentIds) {
        final preset = LuaScriptLibrary.getPresetById(id)!;
        final panelDef = LuaGuiParser.parseFromCode(preset.code);
        expect(panelDef, isNotNull, reason: '$id GUI should parse into a valid LuaGuiPanelDef');
        expect(panelDef!.title.isNotEmpty, isTrue);
        expect(panelDef.subtitle?.isNotEmpty, isTrue);
        expect(panelDef.accentColor, isNotNull);
        expect(panelDef.sideCheeks, isNotNull, reason: '$id should have wooden side cheeks like Renaissance Lute');
        expect(panelDef.children.length, greaterThanOrEqualTo(2), reason: '$id should have multiple rows of controls');

        // Check that layout contains interactive knobs and sliders (not plain text)
        bool hasKnobs = false;
        bool hasSliders = false;
        for (final row in panelDef.children) {
          expect(row.type, equals(LuaGuiNodeType.row));
          for (final child in row.children) {
            if (child.type == LuaGuiNodeType.knob) hasKnobs = true;
            if (child.type == LuaGuiNodeType.slider) hasSliders = true;
          }
        }
        expect(hasKnobs, isTrue, reason: '$id GUI should contain interactive knobs');
        expect(hasSliders, isTrue, reason: '$id GUI should contain interactive capsule sliders');
      }
    });

    test('All 8 Pipe instruments define ADSR envelope parameters and sustain continuously', () {
      for (final id in pipeInstrumentIds) {
        final preset = LuaScriptLibrary.getPresetById(id)!;
        final compiled = LuaEngine.compile(preset.code);
        expect(compiled.isSuccess, isTrue);

        final paramNames = compiled.params.map((p) => p.name).toSet();
        expect(paramNames.contains('Attack'), isTrue, reason: '$id should have Attack parameter');
        expect(paramNames.contains('Decay'), isTrue, reason: '$id should have Decay parameter');
        expect(paramNames.contains('Sustain'), isTrue, reason: '$id should have Sustain parameter');
        expect(paramNames.contains('Release'), isTrue, reason: '$id should have Release parameter');

        final initialParams = <String, double>{};
        for (final p in compiled.params) {
          initialParams[p.name] = p.defaultValue;
        }

        // Synthesize a 1.0 second sustained note (44100 samples)
        final buffer = LuaEngine.synthesizeBuffer(
          code: preset.code,
          durationSec: 1.0,
          freq: 440.0,
          note: 69,
          params: initialParams,
          velocity: 0.85,
        );

        expect(buffer.length, equals(44100));

        // Inspect tone at t = 0.65s (sample ~28665), well past the old 0.4s premature cutoff
        final earlyRange = buffer.sublist(1000, 5000);
        final earlyMaxAbs = earlyRange.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
        final lateRange = buffer.sublist(28000, 32000);
        final lateMaxAbs = lateRange.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
        debugPrint('$id -> early: ${earlyMaxAbs.toStringAsFixed(3)}, late: ${lateMaxAbs.toStringAsFixed(3)}');
        expect(lateMaxAbs, greaterThan(0.05),
            reason: '$id should sustain audible tone past 0.6s rather than blipping out');
      }
    });

    test('All 8 Pipe instruments compile with parameters and synthesize non-empty audio buffers', () {
      for (final id in pipeInstrumentIds) {
        final preset = LuaScriptLibrary.getPresetById(id)!;
        final compiled = LuaEngine.compile(preset.code);
        expect(compiled.isSuccess, isTrue, reason: 'Preset $id should compile cleanly: ${compiled.errorMessage}');
        expect(compiled.params.isNotEmpty, isTrue, reason: 'Preset $id should have controls');

        final initialParams = <String, double>{};
        for (final p in compiled.params) {
          initialParams[p.name] = p.defaultValue;
        }

        // Synthesize a note (MIDI note 72 = C5)
        final buffer = LuaEngine.synthesizeBuffer(
          code: preset.code,
          durationSec: 0.15,
          freq: 523.25,
          note: 72,
          params: initialParams,
          velocity: 0.85,
        );

        expect(buffer.isNotEmpty, isTrue, reason: '$id buffer should not be empty');
        expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue, reason: '$id buffer must be finite');
        expect(buffer.any((s) => s.abs() > 0.02), isTrue, reason: '$id must produce audible signal');
      }
    });
  });

  group('General MIDI Registry Pipe Family Integration Tests', () {
    test('GM Programs 72 to 79 are all natively supported in GmInstrumentRegistry', () {
      for (int program = 72; program <= 79; program++) {
        final def = GmInstrumentRegistry.spec[program];
        expect(def.family, equals(GmFamily.pipe));
        expect(def.isNativeSupported, isTrue, reason: 'GM $program (${def.gmName}) should be native');
        expect(def.nativePresetId, isNotNull);
      }

      // Coverage should now be at least 52 instruments (40.6%)
      expect(GmInstrumentRegistry.nativeCount, equals(52));
      expect(GmInstrumentRegistry.nativeCoveragePercent, closeTo(40.625, 0.1));
      debugPrint('Updated Native GM Coverage: ${GmInstrumentRegistry.nativeCoveragePercent.toStringAsFixed(1)}% (${GmInstrumentRegistry.nativeCount}/128)');
    });

    test('Resolves explicit Program Change 72-79 to native presets', () {
      // 72 Piccolo
      final piccolo = GmInstrumentRegistry.resolve(programNumber: 72);
      expect(piccolo.isNative, isTrue);
      expect(piccolo.presetId, equals('concert_piccolo'));

      // 73 Flute
      final flute = GmInstrumentRegistry.resolve(programNumber: 73);
      expect(flute.isNative, isTrue);
      expect(flute.presetId, equals('concert_flute'));

      // 74 Recorder
      final recorder = GmInstrumentRegistry.resolve(programNumber: 74);
      expect(recorder.isNative, isTrue);
      expect(recorder.presetId, equals('wooden_recorder'));

      // 75 Pan Flute
      final panFlute = GmInstrumentRegistry.resolve(programNumber: 75);
      expect(panFlute.isNative, isTrue);
      expect(panFlute.presetId, equals('pan_flute'));

      // 76 Blown Bottle
      final bottle = GmInstrumentRegistry.resolve(programNumber: 76);
      expect(bottle.isNative, isTrue);
      expect(bottle.presetId, equals('blown_bottle'));

      // 77 Shakuhachi
      final shakuhachi = GmInstrumentRegistry.resolve(programNumber: 77);
      expect(shakuhachi.isNative, isTrue);
      expect(shakuhachi.presetId, equals('shakuhachi_bamboo'));

      // 78 Whistle
      final whistle = GmInstrumentRegistry.resolve(programNumber: 78);
      expect(whistle.isNative, isTrue);
      expect(whistle.presetId, equals('tin_whistle'));

      // 79 Ocarina
      final ocarina = GmInstrumentRegistry.resolve(programNumber: 79);
      expect(ocarina.isNative, isTrue);
      expect(ocarina.presetId, equals('sweet_ocarina'));
    });

    test('Resolves semantic track names for all 8 Pipe instruments when PC is absent or default 0', () {
      expect(GmInstrumentRegistry.resolve(programNumber: null, trackName: 'Concert Piccolo').presetId, equals('concert_piccolo'));
      expect(GmInstrumentRegistry.resolve(programNumber: 0, trackName: 'Solo Flute').presetId, equals('concert_flute'));
      expect(GmInstrumentRegistry.resolve(programNumber: null, trackName: 'Wooden Recorder').presetId, equals('wooden_recorder'));
      expect(GmInstrumentRegistry.resolve(programNumber: 0, trackName: 'Andean Pan Flute').presetId, equals('pan_flute'));
      expect(GmInstrumentRegistry.resolve(programNumber: null, trackName: 'Blown Glass Bottle').presetId, equals('blown_bottle'));
      expect(GmInstrumentRegistry.resolve(programNumber: 0, trackName: 'Bamboo Shakuhachi').presetId, equals('shakuhachi_bamboo'));
      expect(GmInstrumentRegistry.resolve(programNumber: null, trackName: 'Irish Tin Whistle').presetId, equals('tin_whistle'));
      expect(GmInstrumentRegistry.resolve(programNumber: 0, trackName: 'Ceramic Ocarina').presetId, equals('sweet_ocarina'));
    });
  });

  group('DawState End-to-End MIDI Import with Pipe Family', () {
    test('Imports MIDI file with Flute, Pan Flute, and Whistle into native Arranger tracks', () {
      final dawState = DawState();
      dawState.activePattern.tracks.clear();

      final midiBytes = _createMidiFileWithTracks(
        bpm: 120,
        tracks: [
          (name: 'Concert Flute', program: 73, channel: 0, notes: [72, 76, 79]),
          (name: 'Pan Flute', program: 75, channel: 1, notes: [60, 67]),
          (name: 'Irish Whistle', program: 78, channel: 2, notes: [84, 86]),
        ],
      );

      final success = dawState.importMidiFileBytes(midiBytes, fileName: 'Celtic_Woodwinds.mid');
      expect(success, isTrue);
      expect(dawState.activePattern.tracks.length, equals(3));

      final fluteTrack = dawState.activePattern.tracks[0];
      expect(fluteTrack.name, equals('Concert Flute'));
      expect(fluteTrack.luaScriptCode, contains('ConcertFlute'));

      final panTrack = dawState.activePattern.tracks[1];
      expect(panTrack.name, equals('Pan Flute'));
      expect(panTrack.luaScriptCode, contains('PanFlute'));

      final whistleTrack = dawState.activePattern.tracks[2];
      expect(whistleTrack.name, equals('Irish Whistle'));
      expect(whistleTrack.luaScriptCode, contains('TinWhistle'));
    });
  });
}
