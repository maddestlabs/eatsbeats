import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/lua_gui_model.dart';
import 'package:mobile_wren_daw/lua/lua_gui_parser.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';

void main() {
  group('Lua GUI Parser Tests', () {
    test('Parses JC-303 custom GUI layout correctly', () {
      final preset = LuaPresetLibrary.getPresetById('jc_303')!;
      final result = LuaEngine.compile(preset.code);

      expect(result.isSuccess, isTrue);
      expect(result.guiLayout, isNotNull);

      final layout = result.guiLayout!;
      expect(layout.title, contains('303'));
      expect(layout.backgroundStyle, equals(PanelBackgroundStyle.silver));
      expect(layout.defaultKnobStyle, equals(KnobStyle.chrome));
      expect(layout.children.length, greaterThanOrEqualTo(2));

      // First row should contain Waveform switch, divider, and Cutoff/Resonance knobs
      final row1 = layout.children[0];
      expect(row1.type, equals(LuaGuiNodeType.row));
      expect(row1.children.any((c) => c.type == LuaGuiNodeType.switchToggle && c.param == 'Waveform'), isTrue);
      expect(row1.children.any((c) => c.type == LuaGuiNodeType.knob && c.param == 'Cutoff'), isTrue);
      expect(row1.children.any((c) => c.type == LuaGuiNodeType.knob && c.param == 'Resonance'), isTrue);
    });

    test('Parses procedural drum GUI layouts correctly', () {
      final kickPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'fm_acoustic_kick');
      final kickResult = LuaEngine.compile(kickPreset.code);
      expect(kickResult.guiLayout, isNotNull);
      expect(kickResult.guiLayout!.title, contains('KICK'));

      final snarePreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'fm_acoustic_snare');
      final snareResult = LuaEngine.compile(snarePreset.code);
      expect(snareResult.guiLayout, isNotNull);
      expect(snareResult.guiLayout!.title, contains('SNARE'));
    });

    test('Gracefully returns null guiLayout for scripts without GUI definition', () {
      const scriptWithoutGui = '''
-- @name: Simple Synth
local Synth = {}
function Synth.init()
  Param.add("Cutoff", 100, 10000, 2000)
  Param.add("Resonance", 0, 10, 2)
end
function Synth.process(time, freq, note, params)
  return 0.0
end
return Synth
''';
      final result = LuaEngine.compile(scriptWithoutGui);
      expect(result.isSuccess, isTrue);
      expect(result.params.length, equals(2));
      expect(result.guiLayout, isNull);
    });
  });
}
