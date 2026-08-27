import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/script_target_model.dart';
import 'package:eatsbeats/lua/lua_gui_model.dart';
import 'package:eatsbeats/lua/lua_gui_parser.dart';
import 'package:eatsbeats/lua/lua_gui_serializer.dart';
import 'package:eatsbeats/ui/gui_designer/gui_designer_view.dart';
import 'package:eatsbeats/ui/gui_designer/gui_widget_palette.dart';
import 'package:eatsbeats/ui/gui_designer/gui_inspector_sidebar.dart';
import 'package:eatsbeats/ui/lua_workbench_view.dart';
import 'package:eatsbeats/ui/widgets/live_track_visualizer_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lua GUI Serializer & Roundtrip Tests', () {
    test('LuaGuiSerializer serializes complete panel with knobs, sliders, nixies, and canvases', () {
      const panel = LuaGuiPanelDef(
        title: 'MY ACID SYNTH',
        subtitle: '18dB Diode Bassline Machine',
        backgroundStyle: PanelBackgroundStyle.silver,
        accentColor: Color(0xFFFF8C00),
        defaultKnobStyle: KnobStyle.chrome,
        children: [
          LuaGuiNode(
            type: LuaGuiNodeType.row,
            children: [
              LuaGuiNode(type: LuaGuiNodeType.knob, param: 'Cutoff', label: 'CUTOFF', unit: 'Hz', size: 56, knobStyle: KnobStyle.chrome),
              LuaGuiNode(type: LuaGuiNodeType.knob, param: 'Resonance', label: 'RESO', size: 48),
              LuaGuiNode(type: LuaGuiNodeType.nixie, param: 'Accent', label: 'ACCENT', unit: '%', width: 100),
            ],
          ),
          LuaGuiNode(
            type: LuaGuiNodeType.row,
            children: [
              LuaGuiNode(type: LuaGuiNodeType.slider, param: 'Drive', label: 'OVERDRIVE', orientation: 'horizontal', width: 440, sliderStyle: SliderStyle.console),
            ],
          ),
          LuaGuiNode(
            type: LuaGuiNodeType.row,
            children: [
              LuaGuiNode(type: LuaGuiNodeType.spaceVisualizer, height: 140),
            ],
          ),
        ],
      );

      final luaCode = LuaGuiSerializer.serialize(panel: panel, instrumentName: 'MyAcidSynth');
      expect(luaCode, contains('function MyAcidSynth.gui()'));
      expect(luaCode, contains('title = "MY ACID SYNTH"'));
      expect(luaCode, contains('background = "silver"'));
      expect(luaCode, contains('knobStyle = "chrome"'));
      expect(luaCode, contains('type = "knob", param = "Cutoff"'));
      expect(luaCode, contains('type = "nixie", param = "Accent"'));
      expect(luaCode, contains('type = "hslider", param = "Drive"'));
      expect(luaCode, contains('type = "space_visualizer"'));

      // Roundtrip test with LuaGuiParser
      final parsed = LuaGuiParser.parseFromCode(luaCode);
      expect(parsed, isNotNull);
      expect(parsed!.title, equals('MY ACID SYNTH'));
      expect(parsed.backgroundStyle, equals(PanelBackgroundStyle.silver));
      expect(parsed.defaultKnobStyle, equals(KnobStyle.chrome));
      expect(parsed.children.length, equals(3));
      expect(parsed.children[0].children.length, equals(3));
      expect(parsed.children[0].children[0].param, equals('Cutoff'));
    });

    test('LuaGuiSerializer handles nested columns, custom hex background, track accent, and label/value visibility', () {
      const advancedPanel = LuaGuiPanelDef(
        title: 'CUSTOM MODULAR STACK',
        backgroundStyle: PanelBackgroundStyle.custom,
        backgroundColor: Color(0xFF181A20),
        accentColor: null, // Track Color ("track")
        defaultKnobStyle: KnobStyle.vintage,
        children: [
          LuaGuiNode(
            type: LuaGuiNodeType.row,
            children: [
              LuaGuiNode(type: LuaGuiNodeType.knob, param: 'Cutoff', label: 'CUTOFF', showLabel: false, showValue: false),
              LuaGuiNode(
                type: LuaGuiNodeType.column,
                children: [
                  LuaGuiNode(type: LuaGuiNodeType.slider, param: 'Attack', label: 'ATTACK', orientation: 'horizontal', width: 120),
                  LuaGuiNode(type: LuaGuiNodeType.slider, param: 'Decay', label: 'DECAY', orientation: 'horizontal', width: 120),
                  LuaGuiNode(type: LuaGuiNodeType.switchToggle, param: 'Mute', orientation: 'vertical', showLabel: false),
                ],
              ),
              LuaGuiNode(type: LuaGuiNodeType.nixie, param: 'Freq', showLabel: false, unit: 'Hz'),
              LuaGuiNode(type: LuaGuiNodeType.oscilloscope, width: 280, height: 120),
              LuaGuiNode(type: LuaGuiNodeType.spectrum, width: 280, height: 120),
            ],
          ),
        ],
      );

      final luaCode = LuaGuiSerializer.serialize(panel: advancedPanel, instrumentName: 'ModularStack');
      expect(luaCode, contains('function ModularStack.gui()'));
      expect(luaCode, contains('background = "#181A20"'));
      expect(luaCode, contains('accent = "track"'));
      expect(luaCode, contains('showLabel = false'));
      expect(luaCode, contains('showValue = false'));
      expect(luaCode, contains('type = "column"'));
      expect(luaCode, contains('orientation = "vertical"'));
      expect(luaCode, contains('type = "oscilloscope"'));
      expect(luaCode, contains('type = "spectrum"'));

      // Test roundtrip parsing
      final parsed = LuaGuiParser.parseFromCode(luaCode);
      expect(parsed, isNotNull);
      expect(parsed!.backgroundStyle, equals(PanelBackgroundStyle.custom));
      expect(parsed.backgroundColor?.value, equals(const Color(0xFF181A20).value));
      expect(parsed.accentColor, isNull); // "track" parses to null (track-inheriting)
      expect(parsed.children.length, equals(1));
      expect(parsed.children[0].type, equals(LuaGuiNodeType.row));
      expect(parsed.children[0].children[0].showLabel, isFalse);
      expect(parsed.children[0].children[0].showValue, isFalse);
      expect(parsed.children[0].children[1].type, equals(LuaGuiNodeType.column));
      expect(parsed.children[0].children[1].children.length, equals(3));
      expect(parsed.children[0].children[1].children[2].orientation, equals('vertical'));
      expect(parsed.children[0].children[3].type, equals(LuaGuiNodeType.oscilloscope));
      expect(parsed.children[0].children[4].type, equals(LuaGuiNodeType.spectrum));
    });

    test('LuaGuiSerializer.ensureGuiBlock injects .gui() block into scripts without one', () {
      const rawCode = '''-- @name: Simple Tone
local SimpleTone = {}

function SimpleTone.init()
  Param.add("Pitch", 20.0, 2000.0, 440.0)
  Param.add("Volume", 0.0, 1.0, 0.8)
end

function SimpleTone.process(time, freq, note, params)
  return 0.0
end

return SimpleTone
''';

      final codeWithGui = LuaGuiSerializer.ensureGuiBlock(rawCode, instrumentName: 'SimpleTone');
      expect(codeWithGui, contains('function SimpleTone.gui()'));
      expect(codeWithGui, contains('title = "SIMPLETONE"'));
      expect(codeWithGui, contains('type = "knob", param = "Pitch"'));
      expect(codeWithGui, contains('type = "knob", param = "Volume"'));
      expect(codeWithGui, contains('return SimpleTone'));
    });
  });

  group('GUI Designer Canvas & Workbench UI Tests', () {
    testWidgets('GuiDesignerCanvasView renders faceplate, rows, and allows adding widgets', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final target = ScriptTarget(
        id: 'test_synth',
        trackId: 'track_1',
        title: 'Lead Synth',
        subtitle: 'Lead Synth DSP',
        trackName: 'Track 1',
        trackColor: const Color(0xFF00E5FF),
        type: ScriptTargetType.trackDsp,
      );

      String currentScript = '''-- @name: Lead Synth
local LeadSynth = {}

function LeadSynth.init()
  Param.add("Cutoff", 100.0, 10000.0, 2000.0)
end

function LeadSynth.gui()
  return {
    panel = {
      title = "LEAD SYNTH",
      background = "dark",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Cutoff", label = "CUTOFF" }
          }
        }
      }
    }
  }
end

return LeadSynth
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 900,
              child: GuiDesignerCanvasView(
                dawState: dawState,
                target: target,
                scriptCode: currentScript,
                onScriptCodeChanged: (updated) {
                  currentScript = updated;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('VISUAL DESIGN STUDIO'), findsOneWidget);
      expect(find.text('LEAD SYNTH'), findsNWidgets(2));
      expect(find.text('WIDGET TOOLBOX'), findsOneWidget);
      expect(find.text('PANEL PROPERTIES'), findsOneWidget);

      // Click ADD ROW button
      final addRowBtn = find.text('ADD ROW');
      expect(addRowBtn, findsOneWidget);
      await tester.tap(addRowBtn);
      await tester.pumpAndSettle();

      expect(currentScript, contains('function LeadSynth.gui()'));
    });

    testWidgets('LuaWorkbenchView switches between LIVE INTERACTION and DESIGN MODE in GUI tab', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'tb_303',
        name: 'Acid 303',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00),
        luaScriptCode: '''-- @name: Acid 303
local Acid303 = {}

function Acid303.gui()
  return {
    panel = {
      title = "ACID 303 BASS",
      background = "silver",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Cutoff", label = "CUTOFF" }
          }
        }
      }
    }
  }
end

return Acid303
''',
      );
      dawState.activePattern.tracks.add(track);
      dawState.activeTrackIndex = dawState.activePattern.tracks.indexOf(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 900,
              child: LuaWorkbenchView(
                dawState: dawState,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Click GUI tab button
      final guiTab = find.text('GUI');
      expect(guiTab, findsOneWidget);
      await tester.tap(guiTab);
      await tester.pumpAndSettle();

      expect(find.text('LIVE INTERACTION'), findsOneWidget);
      expect(find.text('DESIGN MODE'), findsOneWidget);

      // Tap DESIGN MODE
      await tester.tap(find.text('DESIGN MODE'));
      await tester.pumpAndSettle();

      expect(find.text('VISUAL DESIGN STUDIO'), findsOneWidget);
      expect(find.text('WIDGET TOOLBOX'), findsOneWidget);
    });

    testWidgets('LiveTrackVisualizerWidget renders track-specific oscilloscope and FFT spectrum', (tester) async {
      final dawState = DawState();
      final track = TrackChannel(
        id: 'synth_track_1',
        name: 'Lead Synth',
        type: TrackType.luaScript,
        color: const Color(0xFF00FF9D),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LiveTrackVisualizerWidget(
                  audioEngine: dawState.audioEngine,
                  track: track,
                  isSpectrum: false,
                  accentColor: const Color(0xFF00E5FF),
                ),
                LiveTrackVisualizerWidget(
                  audioEngine: dawState.audioEngine,
                  track: track,
                  isSpectrum: true,
                  accentColor: const Color(0xFF00FF9D),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('OSCILLOSCOPE • LEAD SYNTH'), findsOneWidget);
      expect(find.text('SPECTRUM FFT • LEAD SYNTH'), findsOneWidget);
    });
  });
}
