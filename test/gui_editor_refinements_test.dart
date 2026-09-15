import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/script_target_model.dart';
import 'package:eatsbeats/ui/gui_designer/gui_designer_view.dart';
import 'package:eatsbeats/eatscript/eats_gui_model.dart';
import 'package:eatsbeats/eatscript/eats_gui_serializer.dart';
import 'package:eatsbeats/eatscript/eats_gui_parser.dart';
import 'package:eatsbeats/ui/textures/daw_texture_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GUI Editor Refinements Tests', () {
    test('Carbon fiber texture paints seamless 2x2 twill without errors', () {
      final image = DawTextureEngine.instance.getTextureImage(DawTextureType.carbon);
      expect(image, isNotNull);
      expect(image.width, equals(256));
      expect(image.height, equals(256));
    });

    test('EatScriptGuiPanelDef copyWith clears sideCheeks on none or clearSideCheeks', () {
      var panel = EatScriptGuiPanelDef(
        title: 'TEST PANEL',
        sideCheeks: 'walnut',
        children: const [],
      );
      expect(panel.sideCheeks, equals('walnut'));

      // Changing to 'none' should clear to null
      var updated = panel.copyWith(sideCheeks: 'none');
      expect(updated.sideCheeks, isNull);

      // Explicit clearSideCheeks should clear to null
      panel = panel.copyWith(sideCheeks: 'mahogany');
      expect(panel.sideCheeks, equals('mahogany'));

      updated = panel.copyWith(sideCheeks: null, clearSideCheeks: true);
      expect(updated.sideCheeks, isNull);
    });

    test('EatScriptGuiNode copyWith clears backgroundStyle and backgroundColor', () {
      var row = EatScriptGuiNode(
        type: EatScriptGuiNodeType.row,
        backgroundStyle: PanelBackgroundStyle.carbon,
        backgroundColor: const Color(0xFF1E2430),
      );
      expect(row.backgroundStyle, equals(PanelBackgroundStyle.carbon));
      expect(row.backgroundColor, equals(const Color(0xFF1E2430)));

      // Clearing backgroundStyle
      var clearedStyle = row.copyWith(backgroundStyle: null, clearBackgroundStyle: true);
      expect(clearedStyle.backgroundStyle, isNull);
      expect(clearedStyle.backgroundColor, equals(const Color(0xFF1E2430)));

      // Clearing backgroundColor
      var clearedColor = row.copyWith(backgroundColor: null, clearBackgroundColor: true);
      expect(clearedColor.backgroundStyle, equals(PanelBackgroundStyle.carbon));
      expect(clearedColor.backgroundColor, isNull);
    });

    test('Row and Column serialize and parse backgroundStyle, rotation, color, and cornerRadius', () {
      final panel = EatScriptGuiPanelDef(
        title: 'SYNTH CHASSIS',
        backgroundStyle: PanelBackgroundStyle.carbon,
        children: [
          EatScriptGuiNode(
            type: EatScriptGuiNodeType.row,
            backgroundStyle: PanelBackgroundStyle.walnut,
            backgroundColor: const Color(0xFF2E1C14),
            textureRotation: 90.0,
            cornerRadius: 12.0,
            children: [
              EatScriptGuiNode(
                type: EatScriptGuiNodeType.column,
                backgroundStyle: PanelBackgroundStyle.carbon,
                backgroundColor: const Color(0xFF101216),
                textureRotation: 180.0,
                cornerRadius: 8.0,
                children: [
                  EatScriptGuiNode(
                    type: EatScriptGuiNodeType.knob,
                    param: 'cutoff',
                    label: 'Cutoff',
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final serialized = EatScriptGuiSerializer.serialize(panel: panel);
      expect(serialized.contains('walnut'), isTrue);
      expect(serialized.contains('carbon'), isTrue);

      final parsed = EatScriptGuiParser.parseFromCode(serialized);
      expect(parsed, isNotNull);
      expect(parsed!.children.isNotEmpty, isTrue);

      final parsedRow = parsed.children.first;
      expect(parsedRow.backgroundStyle, equals(PanelBackgroundStyle.walnut));
      expect(parsedRow.textureRotation, equals(90.0));
      expect(parsedRow.cornerRadius, equals(12.0));

      final parsedCol = parsedRow.children.first;
      expect(parsedCol.backgroundStyle, equals(PanelBackgroundStyle.carbon));
      expect(parsedCol.textureRotation, equals(180.0));
      expect(parsedCol.cornerRadius, equals(8.0));
    });

    testWidgets('Tapping on a knob in GUI designer selects it instantly without delay', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final target = ScriptTarget(
        id: 'test_lead',
        trackId: 'track_1',
        title: 'Lead Synth',
        subtitle: 'Lead Synth DSP',
        trackName: 'Track 1',
        trackColor: const Color(0xFF00E5FF),
        type: ScriptTargetType.trackDsp,
      );

      const script = '''-- @name: Lead Synth
local LeadSynth = {}
function LeadSynth.gui()
  return {
    panel = {
      title = "LEAD SYNTH",
      background = "dark",
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "Cutoff", label = "CUTOFF" },
            { type = "nixie", param = "Pitch", label = "PITCH" }
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
                scriptCode: script,
                onScriptCodeChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially PANEL PROPERTIES is shown in sidebar
      expect(find.text('PANEL PROPERTIES'), findsOneWidget);

      // Tap on CUTOFF knob
      final knobFinder = find.text('CUTOFF');
      expect(knobFinder, findsOneWidget);
      await tester.tap(knobFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Knob is instantly selected on single tap, switching sidebar to WIDGET PROPERTIES!
      expect(find.text('WIDGET PROPERTIES'), findsOneWidget);
      expect(find.text('KNOB PROPERTIES'), findsOneWidget);

      // Tap on PITCH nixie
      final nixieFinder = find.text('PITCH');
      expect(nixieFinder, findsOneWidget);
      await tester.tap(nixieFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Nixie is also selected instantly
      expect(find.text('WIDGET PROPERTIES'), findsOneWidget);
    });
  });
}
