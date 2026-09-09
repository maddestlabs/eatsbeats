import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/script_target_model.dart';
import 'package:eatsbeats/eatscript/eat_gui_model.dart';
import 'package:eatsbeats/eatscript/eat_gui_parser.dart';
import 'package:eatsbeats/eatscript/eat_gui_serializer.dart';
import 'package:eatsbeats/ui/gui_designer/gui_designer_view.dart';
import 'package:eatsbeats/ui/gui_designer/gui_widget_palette.dart';
import 'package:eatsbeats/ui/gui_designer/gui_inspector_sidebar.dart';
import 'package:eatsbeats/ui/eatscript_workbench_view.dart';
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

      final eatCode = LuaGuiSerializer.serialize(panel: panel, instrumentName: 'MyAcidSynth');
      expect(eatCode, contains('def gui():'));
      expect(eatCode, contains('"title": "MY ACID SYNTH"'));
      expect(eatCode, contains('"background": "silver"'));
      expect(eatCode, contains('"knobStyle": "chrome"'));
      expect(eatCode, contains('"type": "knob", "param": "Cutoff"'));
      expect(eatCode, contains('"type": "nixie", "param": "Accent"'));
      expect(eatCode, contains('"type": "hslider", "param": "Drive"'));
      expect(eatCode, contains('"type": "space_visualizer"'));

      // Roundtrip test with LuaGuiParser for EatScript
      final parsedEat = LuaGuiParser.parseFromCode(eatCode);
      expect(parsedEat, isNotNull);
      expect(parsedEat!.title, equals('MY ACID SYNTH'));
      expect(parsedEat.backgroundStyle, equals(PanelBackgroundStyle.silver));
      expect(parsedEat.defaultKnobStyle, equals(KnobStyle.chrome));
      expect(parsedEat.children.length, equals(3));
      expect(parsedEat.children[0].children.length, equals(3));
      expect(parsedEat.children[0].children[0].param, equals('Cutoff'));

      // Also verify backward compatible Lua serialization
      final luaCode = LuaGuiSerializer.serializeToLua(panel: panel, instrumentName: 'MyAcidSynth');
      expect(luaCode, contains('function MyAcidSynth.gui()'));
      expect(luaCode, contains('title = "MY ACID SYNTH"'));
      final parsedLua = LuaGuiParser.parseFromCode(luaCode);
      expect(parsedLua, isNotNull);
      expect(parsedLua!.title, equals('MY ACID SYNTH'));
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

      final eatCode = LuaGuiSerializer.serialize(panel: advancedPanel, instrumentName: 'ModularStack');
      expect(eatCode, contains('def gui():'));
      expect(eatCode, contains('"background": "#181A20"'));
      expect(eatCode, contains('"accent": "track"'));
      expect(eatCode, contains('"showLabel": False'));
      expect(eatCode, contains('"showValue": False'));
      expect(eatCode, contains('"type": "column"'));
      expect(eatCode, contains('"orientation": "vertical"'));
      expect(eatCode, contains('"type": "oscilloscope"'));
      expect(eatCode, contains('"type": "spectrum"'));

      // Test roundtrip parsing
      final parsed = LuaGuiParser.parseFromCode(eatCode);
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

      // Also verify legacy Lua roundtrip
      final luaCode = LuaGuiSerializer.serializeToLua(panel: advancedPanel, instrumentName: 'ModularStack');
      expect(luaCode, contains('function ModularStack.gui()'));
      final parsedLua = LuaGuiParser.parseFromCode(luaCode);
      expect(parsedLua, isNotNull);
      expect(parsedLua!.backgroundStyle, equals(PanelBackgroundStyle.custom));
    });

    test('LuaGuiSerializer and LuaGuiParser roundtrip backgroundSvgStrokeWidth, row opacity, borderWidth, and borderColor', () {
      const panel = LuaGuiPanelDef(
        title: 'TRANSPARENT VECTOR FACEPLATE',
        backgroundSvg: 'M 10 10 L 90 90 Z',
        backgroundSvgOpacity: 0.18,
        backgroundSvgStrokeWidth: 0.75,
        children: [
          LuaGuiNode(
            type: LuaGuiNodeType.row,
            opacity: 0.0,
            borderWidth: 0.0,
            children: [
              LuaGuiNode(type: LuaGuiNodeType.knob, param: 'Downpour', label: 'DOWNPOUR'),
              LuaGuiNode(type: LuaGuiNodeType.knob, param: 'Impact', label: 'DROP IMPACT'),
            ],
          ),
          LuaGuiNode(
            type: LuaGuiNodeType.group,
            label: 'RESONANCE MATRIX',
            opacity: 0.25,
            borderWidth: 1.5,
            borderColor: Color(0xFF00E5FF),
            children: [
              LuaGuiNode(
                type: LuaGuiNodeType.row,
                children: [
                  LuaGuiNode(type: LuaGuiNodeType.knob, param: 'Cavity', label: 'CAVITY RESO'),
                ],
              ),
            ],
          ),
        ],
      );

      final serialized = LuaGuiSerializer.serialize(panel: panel, instrumentName: 'TestInstrument');
      expect(serialized, contains('"backgroundSvgStrokeWidth": 0.75'));
      expect(serialized, contains('"opacity": 0.0'));
      expect(serialized, contains('"borderWidth": 0.0'));
      expect(serialized, contains('"opacity": 0.25'));
      expect(serialized, contains('"borderWidth": 1.5'));
      expect(serialized, contains('"borderColor": "#00E5FF"'));

      final parsed = LuaGuiParser.parseFromCode(serialized);
      expect(parsed, isNotNull);
      expect(parsed!.backgroundSvg, equals('M 10 10 L 90 90 Z'));
      expect(parsed.backgroundSvgOpacity, closeTo(0.18, 0.01));
      expect(parsed.backgroundSvgStrokeWidth, closeTo(0.75, 0.01));
      expect(parsed.children.length, equals(2));
      expect(parsed.children[0].opacity, closeTo(0.0, 0.01));

      // Also verify legacy Lua serializer
      final luaSerialized = LuaGuiSerializer.serializeToLua(panel: panel, instrumentName: 'TestInstrument');
      expect(luaSerialized, contains('backgroundSvgStrokeWidth = 0.75'));
      expect(luaSerialized, contains('opacity = 0.0'));
      expect(luaSerialized, contains('borderWidth = 0.0'));
      expect(luaSerialized, contains('opacity = 0.25'));
      expect(luaSerialized, contains('borderWidth = 1.5'));
      expect(luaSerialized, contains('borderColor = "#00E5FF"'));
      expect(parsed.children[0].borderWidth, closeTo(0.0, 0.01));
      expect(parsed.children[0].children.length, equals(2));
      expect(parsed.children[1].type, equals(LuaGuiNodeType.group));
      expect(parsed.children[1].opacity, closeTo(0.25, 0.01));
      expect(parsed.children[1].borderWidth, closeTo(1.5, 0.01));
      expect(parsed.children[1].borderColor?.value, equals(const Color(0xFF00E5FF).value));
    });

    test('LuaGuiSerializer and LuaGuiParser roundtrip backgroundGradient and backgroundSvgLayers', () {
      const panel = LuaGuiPanelDef(
        title: 'OPL3 PCB HARDWARE',
        backgroundStyle: PanelBackgroundStyle.pcbGreen,
        backgroundGradient: LuaGuiGradientDef(
          type: PanelGradientType.radial,
          colors: [Color(0xFF245D35), Color(0xFF143C1E), Color(0xFF0A2211)],
          radius: 1.15,
          stops: [0.0, 0.65, 1.0],
        ),
        backgroundSvgLayers: [
          SvgLayerDef(
            path: 'M 10 50 L 50 50 L 70 30 L 120 30',
            color: Color(0xFF2E7D32),
            strokeWidth: 1.5,
            style: SvgLayerStyle.stroke,
            opacity: 0.75,
          ),
          SvgLayerDef(
            path: 'M 60 20 L 80 20 L 80 40 L 60 40 Z',
            color: Color(0xFFD4AF37),
            style: SvgLayerStyle.fill,
            opacity: 0.90,
          ),
        ],
        children: [
          LuaGuiNode(
            type: LuaGuiNodeType.row,
            children: [
              LuaGuiNode(type: LuaGuiNodeType.nixie, param: 'Algorithm', label: 'ALGORITHM'),
              LuaGuiNode(type: LuaGuiNodeType.nixie, param: 'Feedback', label: 'FEEDBACK'),
            ],
          ),
        ],
      );

      final serialized = LuaGuiSerializer.serializeToEatScript(panel: panel, instrumentName: 'Opl3Hardware');
      expect(serialized, contains('"background": "pcb_green"'));
      expect(serialized, contains('"backgroundGradient"'));
      expect(serialized, contains('"type": "radial"'));
      expect(serialized, contains('"backgroundSvgLayers"'));
      expect(serialized, contains('"path": "M 10 50 L 50 50 L 70 30 L 120 30"'));
      expect(serialized, contains('"color": "#2E7D32"'));
      expect(serialized, contains('"strokeWidth": 1.5'));
      expect(serialized, contains('"style": "stroke"'));
      expect(serialized, contains('"style": "fill"'));

      final parsed = LuaGuiParser.parseFromCode(serialized);
      expect(parsed, isNotNull);
      expect(parsed!.backgroundStyle, equals(PanelBackgroundStyle.pcbGreen));
      expect(parsed.backgroundGradient, isNotNull);
      expect(parsed.backgroundGradient!.type, equals(PanelGradientType.radial));
      expect(parsed.backgroundGradient!.colors.length, equals(3));
      expect(parsed.backgroundGradient!.radius, closeTo(1.15, 0.01));
      expect(parsed.backgroundSvgLayers, isNotNull);
      expect(parsed.backgroundSvgLayers!.length, equals(2));
      expect(parsed.backgroundSvgLayers![0].path, equals('M 10 50 L 50 50 L 70 30 L 120 30'));
      expect(parsed.backgroundSvgLayers![0].strokeWidth, closeTo(1.5, 0.01));
      expect(parsed.backgroundSvgLayers![0].style, equals(SvgLayerStyle.stroke));
      expect(parsed.backgroundSvgLayers![1].style, equals(SvgLayerStyle.fill));
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

    testWidgets('EatscriptWorkbenchView switches between LIVE INTERACTION and DESIGN MODE in GUI tab', (tester) async {
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
              child: EatscriptWorkbenchView(
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
