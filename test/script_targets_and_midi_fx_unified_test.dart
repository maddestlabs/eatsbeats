import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/script_target_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MIDI FX Lua Script Presets Tests', () {
    test('All MIDI FX presets in LuaPresetLibrary compile cleanly with valid params & GUIs', () {
      final midiPresets = LuaPresetLibrary.presets.where((p) => p.isMidiFx).toList();
      expect(midiPresets, isNotEmpty);

      for (final p in midiPresets) {
        final result = LuaEngine.compile(p.code);
        expect(result.isSuccess, isTrue, reason: 'Failed compiling ${p.name}: ${result.errorMessage}');
        expect(result.params, isNotEmpty, reason: 'Expected parameters in ${p.name}');
        expect(result.guiLayout, isNotNull, reason: 'Expected GUI layout in ${p.name}');
      }
    });
  });

  group('DawState Script Targets & MIDI FX Management Tests', () {
    test('getAllScriptTargets returns unique targets without duplicate MIDI FX entries', () {
      final dawState = DawState();
      final track = dawState.activeTrack;

      // Add 1 Audio FX and 1 MIDI FX
      final scopePreset = LuaPresetLibrary.getPresetById('eats_scope')!;
      dawState.addAudioFXFromPreset(track, scopePreset);

      final arpPreset = LuaPresetLibrary.getPresetById('arpeggiator_midi_fx')!;
      dawState.addMidiFXFromPreset(track, arpPreset);

      final targets = dawState.getAllScriptTargets();

      // Check unique IDs
      final targetIds = targets.map((t) => t.id).toList();
      final uniqueIds = targetIds.toSet();
      expect(targetIds.length, equals(uniqueIds.length), reason: 'Duplicate script target IDs detected!');

      // Check categories
      final dspTargets = targets.where((t) => t.type == ScriptTargetType.trackDsp).toList();
      final audioFxTargets = targets.where((t) => t.type == ScriptTargetType.audioFx).toList();
      final midiFxTargets = targets.where((t) => t.type == ScriptTargetType.midiFx).toList();

      expect(dspTargets, isNotEmpty);
      expect(audioFxTargets.any((t) => t.title.contains('Eats-Scope')), isTrue);
      expect(midiFxTargets.any((t) => t.title.contains('Arpeggiator FX')), isTrue);
      expect(midiFxTargets.length, equals(track.midiFXRack.length));
    });

    test('MIDI FX insert contains full Lua code and compiles with 0 syntax errors', () {
      final dawState = DawState();
      final track = dawState.activeTrack;
      final arpPreset = LuaPresetLibrary.getPresetById('arpeggiator_midi_fx')!;

      dawState.addMidiFXFromPreset(track, arpPreset);
      final mfx = track.midiFXRack.last;

      expect(mfx.luaScriptCode, contains('function ArpeggiatorMidiFX.init()'));
      expect(mfx.luaScriptCode, contains('function ArpeggiatorMidiFX.transform_notes'));

      final target = ScriptTarget(
        id: 'mfx_${track.id}_${mfx.id}',
        type: ScriptTargetType.midiFx,
        title: '${mfx.name} (${track.name})',
        subtitle: 'MIDI FX Insert Module',
        trackId: track.id,
        trackName: track.name,
        trackColor: track.color,
        secondaryId: mfx.id,
      );

      final code = dawState.getScriptCodeForTarget(target);
      expect(code, equals(mfx.luaScriptCode));

      dawState.compileScriptTarget(target, code);
      final result = dawState.compilationResult;
      expect(result.isSuccess, isTrue, reason: 'Expected clean compilation: ${result.errorMessage}');
      expect(result.params.any((p) => p.name == 'Rate'), isTrue);
      expect(result.params.any((p) => p.name == 'Octaves'), isTrue);
      expect(result.params.any((p) => p.name == 'Pattern'), isTrue);
    });

    test('Master Bus Audio FX appear in getAllScriptTargets', () {
      final dawState = DawState();
      final masterTrack = dawState.masterTrack;
      final filterPreset = LuaPresetLibrary.getPresetById('lowpass_filter')!;

      dawState.addAudioFXFromPreset(masterTrack, filterPreset);

      final targets = dawState.getAllScriptTargets();
      final masterFxTarget = targets.firstWhere((t) => t.trackId == masterTrack.id && t.type == ScriptTargetType.audioFx);

      expect(masterFxTarget, isNotNull);
      expect(masterFxTarget.title, contains('Master'));

      final code = dawState.getScriptCodeForTarget(masterFxTarget);
      expect(code, contains('Lowpass Filter'));
    });
  });
}
