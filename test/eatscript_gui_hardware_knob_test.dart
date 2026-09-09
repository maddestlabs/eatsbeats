import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/lua/lua_gui_model.dart';
import 'package:eatsbeats/lua/lua_gui_parser.dart';
import 'package:eatsbeats/lua/lua_gui_serializer.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/ui/hardware/eat_hardware_knob.dart';
import 'package:eatsbeats/ui/hardware/eat_hardware_knob_model.dart';
import 'package:eatsbeats/ui/hardware/eat_hardware_scale.dart';
import 'package:eatsbeats/ui/hardware/eat_hardware_button.dart';
import 'package:eatsbeats/ui/widgets/skeuomorphic_hardware_slider.dart';
import 'package:eatsbeats/eatscript/eat_script_engine.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/script_target_model.dart';
import 'package:eatsbeats/ui/gui_designer/gui_designer_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EatScript Hardware Knob Integration Tests', () {
    test('EatScriptEngine compiles Pythonic DSL with hardware knobs', () {
      const eatCode = '''
def gui():
    return {
        "panel": {
            "title": "EATS DRUM LAB",
            "style": "rack",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {
                            "type": "knob",
                            "param": "Pitch",
                            "label": "pitch",
                            "style": "cream_fluted",
                            "scale": ["low", "mid", "high"],
                        },
                        {
                            "type": "knob",
                            "param": "Body",
                            "label": "body",
                            "style": "vintage_bakelite",
                            "scale": "0_to_10",
                        },
                        {
                            "type": "knob",
                            "param": "Sustain",
                            "label": "sustain",
                            "style": "anodized_knurled",
                            "scale": "1_to_6",
                        },
                        {
                            "type": "knob",
                            "param": "Head",
                            "label": "head",
                            "style": "anodized_knurled",
                            "scale": "0_to_10",
                        },
                    ],
                },
            ],
        },
    }

def process(sample_rate):
    pass
''';

      EatScriptEngine.clearCache();
      final comp = EatScriptEngine.compile(eatCode);
      expect(comp.isSuccess, isTrue);
      expect(comp.guiLayout, isNotNull);
      expect(comp.guiLayout!.children.length, 1);

      final row = comp.guiLayout!.children.first;
      expect(row.children.length, 4);

      // 1. Pitch knob
      final pitchNode = row.children[0];
      expect(pitchNode.knobStyle, KnobStyle.hardwareKnob);
      expect(pitchNode.hardwareKnobStyle, isNotNull);
      expect(pitchNode.hardwareKnobStyle!.knurlStyle, EatKnurlStyle.fluted);
      expect(pitchNode.hardwareKnobStyle!.scale.labels, ['low', 'mid', 'high']);

      // 2. Body knob
      final bodyNode = row.children[1];
      expect(bodyNode.knobStyle, KnobStyle.hardwareKnob);
      expect(bodyNode.hardwareKnobStyle!.scale.labels.length, 11);

      // 3. Sustain knob
      final sustainNode = row.children[2];
      expect(sustainNode.knobStyle, KnobStyle.hardwareKnob);
      expect(sustainNode.hardwareKnobStyle!.scale.labels, ['1', '2', '3', '4', '5', '6']);

      // 4. Head knob
      final headNode = row.children[3];
      expect(headNode.knobStyle, KnobStyle.hardwareKnob);
      expect(headNode.hardwareKnobStyle!.scale.labels.length, 11);
    });

    test('LuaGuiSerializer preserves hardware knobs in EatScript serialization', () {
      final panel = LuaGuiPanelDef(
        title: 'KICK WORKBENCH',
        children: [
          LuaGuiNode(
            type: LuaGuiNodeType.knob,
            param: 'Body',
            label: 'body',
            knobStyle: KnobStyle.hardwareKnob,
            hardwareKnobStyle: EatHardwareKnobStyle.vintageBakelite(),
          ),
        ],
      );

      final serialized = LuaGuiSerializer.serialize(
        panel: panel,
        instrumentName: 'KickWorkbench',
      );

      expect(serialized, contains('def gui():'));
      expect(serialized, contains('"knobStyle": "hardware"'));

      // Roundtrip compile check
      final comp = EatScriptEngine.compile(serialized);
      expect(comp.isSuccess, isTrue);
      expect(comp.guiLayout, isNotNull);
      final knob = comp.guiLayout!.children.first;
      expect(knob.knobStyle, KnobStyle.hardwareKnob);
    });

    test('LuaGuiSerializer preserves custom capColor, bodyColor, indicatorColor, dialColor in EatScript', () {
      final panel = LuaGuiPanelDef(
        title: 'CUSTOM HARDWARE',
        children: [
          LuaGuiNode(
            type: LuaGuiNodeType.knob,
            param: 'CustomKnob',
            label: 'custom',
            knobStyle: KnobStyle.hardwareKnob,
            hardwareKnobStyle: EatHardwareKnobStyle.standardHardware(),
            capColor: const Color(0xFFE8E5DC),
            bodyColor: const Color(0xFF141416),
            indicatorColor: const Color(0xFFFF3D00),
            dialColor: const Color(0xFF00E5FF),
          ),
        ],
      );

      final serialized = LuaGuiSerializer.serialize(
        panel: panel,
        instrumentName: 'CustomColorTest',
      );

      expect(serialized, contains('"capColor": "#E8E5DC"'));
      expect(serialized, contains('"bodyColor": "#141416"'));
      expect(serialized, contains('"indicatorColor": "#FF3D00"'));
      expect(serialized, contains('"dialColor": "#00E5FF"'));

      final comp = EatScriptEngine.compile(serialized);
      expect(comp.isSuccess, isTrue);
      expect(comp.guiLayout, isNotNull);
      final knob = comp.guiLayout!.children.first;
      expect(knob.capColor, const Color(0xFFE8E5DC));
      expect(knob.bodyColor, const Color(0xFF141416));
      expect(knob.indicatorColor, const Color(0xFFFF3D00));
      expect(knob.dialColor, const Color(0xFF00E5FF));
      expect(knob.hardwareKnobStyle!.capColor, const Color(0xFFE8E5DC));
      expect(knob.hardwareKnobStyle!.bodyColor, const Color(0xFF141416));
      expect(knob.hardwareKnobStyle!.indicatorColor, const Color(0xFFFF3D00));
      expect(knob.hardwareKnobStyle!.scale.tickColor, const Color(0xFF00E5FF));
    });

    test('LuaGuiSerializer and parser support dynamic track color and anatomy sizing (capSize, bodySize, indicator)', () {
      final panel = LuaGuiPanelDef(
        title: 'DYNAMIC SIZING & TRACK',
        backgroundStyle: PanelBackgroundStyle.dark,
        children: [
          LuaGuiNode(
            type: LuaGuiNodeType.knob,
            param: 'TrackKnob',
            label: 'TRACK_KNOB',
            knobStyle: KnobStyle.hardwareKnob,
            hardwareKnobStyle: EatHardwareKnobStyle.standardHardware(),
            capColor: LuaGuiNode.trackColorSentinel,
            dialColor: LuaGuiNode.trackColorSentinel,
            capSize: 0.68,
            bodySize: 1.28,
            indicatorLength: 0.75,
            indicatorWidth: 3.5,
          ),
        ],
      );

      final serialized = LuaGuiSerializer.serialize(
        panel: panel,
        instrumentName: 'DynamicTrackTest',
      );

      expect(serialized, contains('"background": "dark"'));
      expect(serialized, contains('"capColor": "track"'));
      expect(serialized, contains('"dialColor": "track"'));
      expect(serialized, contains('"capSize": 0.68'));
      expect(serialized, contains('"bodySize": 1.28'));
      expect(serialized, contains('"indicatorLength": 0.75'));
      expect(serialized, contains('"indicatorWidth": 3.5'));

      final comp = EatScriptEngine.compile(serialized);
      expect(comp.isSuccess, isTrue);
      expect(comp.guiLayout, isNotNull);
      expect(comp.guiLayout!.backgroundStyle, PanelBackgroundStyle.dark);
      expect(comp.guiLayout!.backgroundColor, isNull);

      final knob = comp.guiLayout!.children.first;
      expect(LuaGuiNode.isTrackColor(knob.capColor), isTrue);
      expect(LuaGuiNode.isTrackColor(knob.dialColor), isTrue);
      expect(knob.capSize, 0.68);
      expect(knob.bodySize, 1.28);
      expect(knob.indicatorLength, 0.75);
      expect(knob.indicatorWidth, 3.5);

      expect(knob.hardwareKnobStyle!.capRadiusRatio, 0.68);
      expect(knob.hardwareKnobStyle!.skirtRadiusRatio, 1.28);
      expect(knob.hardwareKnobStyle!.indicatorLength, 0.75);
      expect(knob.hardwareKnobStyle!.indicatorWidth, 3.5);
    });

    test('LuaScriptLibrary Kick and Snare Channel Strips compile valid 6-zone hardware panels', () {
      final kickPreset = LuaScriptLibrary.getPresetById('kick_channel_strip');
      expect(kickPreset, isNotNull);
      final kickComp = EatScriptEngine.compile(kickPreset!.eatCode);
      expect(kickComp.isSuccess, isTrue);
      expect(kickComp.guiLayout, isNotNull);
      final kickRow = kickComp.guiLayout!.children.first;
      expect(kickRow.children.length, 6); // 4 knobs, 1 divider, 1 fader
      expect(kickRow.children[0].knobStyle, KnobStyle.hardwareKnob);
      expect(kickRow.children[5].type, LuaGuiNodeType.slider);
      expect(kickRow.children[5].hardwareScale, isNotNull);

      final snarePreset = LuaScriptLibrary.getPresetById('snare_channel_strip');
      expect(snarePreset, isNotNull);
      final snareComp = EatScriptEngine.compile(snarePreset!.eatCode);
      expect(snareComp.isSuccess, isTrue);
      expect(snareComp.guiLayout, isNotNull);
      final snareRow = snareComp.guiLayout!.children.first;
      expect(snareRow.children.length, 6);
      expect(snareRow.children[0].knobStyle, KnobStyle.hardwareKnob);
      expect(snareRow.children[5].type, LuaGuiNodeType.slider);
    });

    testWidgets('SkeuomorphicHardwareSlider renders with EatScaleGraduation', (tester) async {
      double sliderVal = 0.5;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 60,
                height: 140,
                child: SkeuomorphicHardwareSlider(
                  value: sliderVal,
                  defaultValue: 0.5,
                  orientation: Axis.vertical,
                  style: SliderStyle.console,
                  scaleGraduation: const EatScaleGraduation(
                    tickDivisions: 10,
                    labels: ['+6', '0', '-6', '-12', '-inf'],
                  ),
                  onChanged: (v) => sliderVal = v,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SkeuomorphicHardwareSlider), findsOneWidget);
    });

    testWidgets('GuiDesignerCanvasView in Design Mode accurately renders EatHardwareKnob', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final target = ScriptTarget(
        id: 'hardware_kick',
        trackId: 'track_kick',
        title: 'Hardware Kick',
        subtitle: 'Kick Channel Strip',
        trackName: 'Kick',
        trackColor: const Color(0xFFFF8C00),
        type: ScriptTargetType.trackDsp,
      );

      const scriptCode = '''
def gui():
    return {
        "panel": {
            "title": "KICK CHANNEL STRIP",
            "style": "rack",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {
                            "type": "knob",
                            "param": "Pitch",
                            "label": "pitch",
                            "style": "cream_fluted",
                        },
                        {
                            "type": "knob",
                            "param": "Head",
                            "label": "head",
                            "style": "anodized_knurled",
                        },
                        {
                            "type": "vslider",
                            "param": "Level",
                            "label": "level",
                            "style": "console",
                        },
                    ],
                },
            ],
        },
    }
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
                scriptCode: scriptCode,
                onScriptCodeChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that Design Mode renders EatHardwareKnob for the console dials
      expect(find.byType(EatHardwareKnob), findsNWidgets(2));

      // Verify that the console slider is rendered
      expect(find.byType(SkeuomorphicHardwareSlider), findsOneWidget);
    });

    testWidgets('TB-303 hardware buttons (EatStepKeyButton & EatTactileStudButton) render and interact', (tester) async {
      bool stepTapped = false;
      bool studTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                EatStepKeyButton(
                  label: 'C',
                  subLabel: '1',
                  isActive: true,
                  onTap: () => stepTapped = true,
                ),
                EatStepKeyButton(
                  label: 'C#',
                  isAccidental: true,
                  onTap: () {},
                ),
                EatTactileStudButton(
                  label: 'BAR',
                  isActive: false,
                  onTap: () => studTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(EatStepKeyButton), findsNWidgets(2));
      expect(find.byType(EatTactileStudButton), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('C#'), findsOneWidget);
      expect(find.text('BAR'), findsOneWidget);

      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      expect(stepTapped, isTrue);

      await tester.tap(find.text('BAR'));
      await tester.pumpAndSettle();
      expect(studTapped, isTrue);
    });

    test('EatScriptEngine parses and serializes TB-303 potentiometer and selector knobs', () {
      final panel = LuaGuiPanelDef(
        title: 'TB303 RACK',
        children: [
          LuaGuiNode(
            type: LuaGuiNodeType.knob,
            param: 'Cutoff',
            label: 'cutoff',
            knobStyle: KnobStyle.hardwareKnob,
            hardwareKnobStyle: EatHardwareKnobStyle.tb303Potentiometer(),
          ),
          LuaGuiNode(
            type: LuaGuiNodeType.knob,
            param: 'Mode',
            label: 'mode',
            knobStyle: KnobStyle.hardwareKnob,
            hardwareKnobStyle: EatHardwareKnobStyle.tb303Selector(),
          ),
        ],
      );

      final serialized = LuaGuiSerializer.serialize(
        panel: panel,
        instrumentName: 'TB303Demo',
      );

      expect(serialized, contains('"style": "tb303_potentiometer"'));
      expect(serialized, contains('"style": "tb303_selector"'));

      // Round-trip compile check through EatScriptEngine
      final comp = EatScriptEngine.compile(serialized);
      expect(comp.isSuccess, isTrue);
      expect(comp.guiLayout, isNotNull);
      expect(comp.guiLayout!.children.length, 2);

      final potNode = comp.guiLayout!.children[0];
      expect(potNode.hardwareKnobStyle!.knurlStyle, EatKnurlStyle.fineSawtooth);
      expect(potNode.hardwareKnobStyle!.ribCount, 48);
      expect(potNode.hardwareKnobStyle!.scale.hasBlockCenterDetent, isTrue);

      final selectorNode = comp.guiLayout!.children[1];
      expect(selectorNode.hardwareKnobStyle!.capStyle, EatCapStyle.diagonalBar);
    });
  });
}
