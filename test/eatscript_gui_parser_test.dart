import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/eatscript/eats_engine.dart';
import 'package:eatsbeats/eatscript/eats_gui_model.dart';
import 'package:eatsbeats/eatscript/eats_gui_parser.dart';
import 'package:eatsbeats/eatscript/eats_preset_library.dart';

void main() {
  group('Eatscript GUI Parser Tests', () {
    test('Parses JC-303 custom GUI layout correctly', () {
      final preset = EatScriptLibrary.getPresetById('jc_303')!;
      final result = EatEngine.compile(preset.code);

      expect(result.isSuccess, isTrue);
      expect(result.guiLayout, isNotNull);

      final layout = result.guiLayout!;
      expect(layout.title, contains('303'));
      expect(layout.backgroundStyle, equals(PanelBackgroundStyle.minimalWhite));
      expect(layout.defaultKnobStyle, equals(KnobStyle.chrome));
      expect(layout.children.length, greaterThanOrEqualTo(2));

      // First row should contain Waveform switch, divider, and Cutoff/Resonance knobs
      final row1 = layout.children[0];
      expect(row1.type, equals(EatScriptGuiNodeType.row));
      expect(row1.children.any((c) => (c.type == EatScriptGuiNodeType.knob || c.type == EatScriptGuiNodeType.switchToggle) && c.param == 'Waveform'), isTrue);
      expect(row1.children.any((c) => c.type == EatScriptGuiNodeType.knob && c.param == 'Cutoff'), isTrue);
      expect(row1.children.any((c) => c.type == EatScriptGuiNodeType.knob && c.param == 'Resonance'), isTrue);
    });

    test('Parses procedural drum GUI layouts correctly', () {
      final kickPreset = EatScriptLibrary.presets.firstWhere((p) => p.id == 'fm_acoustic_kick');
      final kickResult = EatEngine.compile(kickPreset.code);
      expect(kickResult.guiLayout, isNotNull);
      expect(kickResult.guiLayout!.title, contains('KICK'));

      final snarePreset = EatScriptLibrary.presets.firstWhere((p) => p.id == 'fm_acoustic_snare');
      final snareResult = EatEngine.compile(snarePreset.code);
      expect(snareResult.guiLayout, isNotNull);
      expect(snareResult.guiLayout!.title, contains('SNARE'));
    });

    test('Parses TTS Voice Synth minimalist ceramic GUI layout correctly', () {
      final preset = EatScriptLibrary.getPresetById('tts_voice_synth')!;
      final result = EatEngine.compile(preset.code);

      expect(result.isSuccess, isTrue);
      expect(result.guiLayout, isNotNull);

      final layout = result.guiLayout!;
      expect(layout.title, contains('TTS VOICE SYNTH'));
      expect(layout.backgroundStyle, equals(PanelBackgroundStyle.minimalWhite));
      expect(layout.defaultKnobStyle, equals(KnobStyle.minimalWhite));
      expect(layout.children.length, equals(1));

      final rootRow = layout.children[0];
      expect(rootRow.type, equals(EatScriptGuiNodeType.row));
      expect(rootRow.children.length, equals(2));

      // Card 1 (Vocal Engine & Formant Display)
      final col1 = rootRow.children[0];
      expect(col1.type, equals(EatScriptGuiNodeType.column));
      expect(col1.children.any((c) => c.type == EatScriptGuiNodeType.spectrum), isTrue);
      expect(col1.children.any((c) => c.type == EatScriptGuiNodeType.segmentedPill && c.param == 'voice_mode'), isTrue);
      expect(col1.children.any((c) => c.type == EatScriptGuiNodeType.segmentedPill && c.param == 'speech_speed'), isTrue);

      // Card 2 (Dynamics & Space)
      final col2 = rootRow.children[1];
      expect(col2.type, equals(EatScriptGuiNodeType.column));
      expect(col2.children.any((c) => c.type == EatScriptGuiNodeType.knob && c.param == 'volume' && c.knobStyle == KnobStyle.minimalWhite), isTrue);
      expect(col2.children.any((c) => c.type == EatScriptGuiNodeType.knob && c.param == 'space' && c.knobStyle == KnobStyle.minimalWhite), isTrue);
      expect(col2.children.any((c) => c.type == EatScriptGuiNodeType.knob && c.param == 'air' && c.knobStyle == KnobStyle.minimalWhite), isTrue);
    });

    test('Gracefully returns null guiLayout for scripts without GUI definition', () {
      const scriptWithoutGui = '''
# @name: Simple Synth
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
      final result = EatEngine.compile(scriptWithoutGui);
      expect(result.isSuccess, isTrue);
      expect(result.params.length, equals(2));
      expect(result.guiLayout, isNull);
    });
  });
}
