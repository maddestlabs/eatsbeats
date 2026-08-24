import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_gui_model.dart';
import 'package:eatsbeats/lua/lua_gui_parser.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/widgets/dynamic_instrument_gui_widget.dart';
import 'package:eatsbeats/ui/widgets/hardware_listbox_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HardwareListBoxWidget & Lua GUI Parsing Tests', () {
    test('Parses listbox GUI node from Lua table definition', () {
      const luaScript = '''
local Synth = {}
function Synth.init()
  Param.choice("Preset", {"Lead", "Bass", "Pad", "Pluck"}, 1.0)
end
function Synth.gui()
  return {
    panel = {
      title = "TEST SYNTH",
      layout = {
        { type = "listbox", param = "Preset", label = "PRESET SOUND", width = 180, height = 95, accent = "#00E5FF" }
      }
    }
  }
end
return Synth
''';

      final res = LuaEngine.compile(luaScript);
      expect(res.isSuccess, isTrue);
      expect(res.guiLayout, isNotNull);
      expect(res.guiLayout!.children.length, equals(1));

      final node = res.guiLayout!.children.first;
      expect(node.type, equals(LuaGuiNodeType.listBox));
      expect(node.param, equals('Preset'));
      expect(node.label, equals('PRESET SOUND'));
      expect(node.width, equals(180.0));
      expect(node.height, equals(95.0));
      expect(node.accentColor, equals(const Color(0xFF00E5FF)));
    });

    testWidgets('Renders HardwareListBoxWidget and handles selection & stepping', (tester) async {
      final state = DawState();
      final track = state.activeTrack;
      track.luaParams['Waveform'] = 1.0;

      final options = ['Sine', 'Square', 'Sawtooth', 'Triangle', 'Noise'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HardwareListBoxWidget(
                dawState: state,
                track: track,
                paramName: 'Waveform',
                label: 'WAVETABLE SELECT',
                options: options,
                width: 200,
                height: 120,
                accentColor: const Color(0xFFFF8C00),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify label and initial options
      expect(find.text('WAVETABLE SELECT'), findsOneWidget);
      expect(find.text('Sine'), findsOneWidget);
      expect(find.text('Square'), findsOneWidget);
      expect(find.text('Sawtooth'), findsOneWidget);

      // Verify initial selection is index 1 ('Square') -> badge shows '02/05'
      expect(find.text('02/05'), findsOneWidget);

      // Tap 'Sawtooth' (index 2)
      await tester.tap(find.text('Sawtooth'));
      await tester.pumpAndSettle();

      expect(track.luaParams['Waveform'], equals(2.0));
      expect(find.text('03/05'), findsOneWidget);

      // Tap Down Stepper arrow
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();

      expect(track.luaParams['Waveform'], equals(3.0));
      expect(find.text('04/05'), findsOneWidget);

      // Tap Up Stepper arrow
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pumpAndSettle();

      expect(track.luaParams['Waveform'], equals(2.0));
      expect(find.text('03/05'), findsOneWidget);
    });

    testWidgets('DynamicInstrumentGuiWidget embeds HardwareListBoxWidget for SNES SFXR preset', (tester) async {
      final state = DawState();
      final track = state.activeTrack;
      final preset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'eats_sfxr');
      state.applyPreset(preset);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicInstrumentGuiWidget(
                dawState: state,
                track: track,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify listboxes are rendered for SFX Type and Wavetable
      expect(find.text('SFX TYPE'), findsOneWidget);
      expect(find.text('WAVETABLE'), findsOneWidget);
      expect(find.text('Laser'), findsOneWidget);
      expect(find.text('Square'), findsOneWidget);
      expect(find.byType(HardwareListBoxWidget), findsNWidgets(2));
    });
  });
}
