import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/ui/mixer_view.dart';
import 'package:eatsbeats/ui/widgets/arranger_context_inspector.dart';
import 'package:eatsbeats/ui/widgets/midi_fx_rack_widget.dart';
import 'package:eatsbeats/ui/widgets/modular_fx_rack_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mixer Track Properties Pullout Tests', () {
    testWidgets('Defaults to showing expanded Track Properties sidebar and toggles on pull tab tap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sidebar is expanded by default with inspector visible
      expect(find.byType(ArrangerContextInspector), findsOneWidget);
      expect(find.byType(MidiFxRackWidget), findsOneWidget);
      expect(find.byType(ModularFxRackWidget), findsOneWidget);

      // Verify pull tab has collapse tooltip
      final collapseBtn = find.byTooltip('Collapse Track Properties');
      expect(collapseBtn, findsOneWidget);

      // Tap pull tab to collapse
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ArrangerContextInspector), findsNothing);

      // Tap pull tab to expand again
      final expandBtn = find.byTooltip('Open Properties Panel');
      expect(expandBtn, findsOneWidget);
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ArrangerContextInspector), findsOneWidget);

      dawState.dispose();
    });

    testWidgets('Track strips no longer render redundant FX or gear buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify gear button is NOT present
      expect(find.byTooltip('Track Properties Inspector'), findsNothing);

      // Verify track strips don't have individual FX buttons
      final trackFxButtons = find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message?.contains('Track FX Rack') ?? false),
      );
      expect(trackFxButtons, findsNothing);

      // Verify track strips don't have individual EQ buttons
      final trackEqButtons = find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message?.contains('Channel EQ') ?? false),
      );
      expect(trackEqButtons, findsNothing);

      dawState.dispose();
    });

    testWidgets('Secondary tap on track strip opens inspector directly in mixer without changing tab', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      dawState.activeTabIndex = 3; // Mixer tab
      final secondTrack = dawState.activePattern.tracks[1];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Collapse sidebar first
      await tester.tap(find.byTooltip('Collapse Track Properties'));
      await tester.pumpAndSettle();
      expect(find.byType(ArrangerContextInspector), findsNothing);

      // Right-click on the second track strip
      final trackText = find.text(secondTrack.name.toUpperCase()).first;
      await tester.tap(trackText, buttons: kSecondaryMouseButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Drawer is open
      expect(find.byType(ArrangerContextInspector), findsOneWidget);
      // Active track is the second track
      expect(dawState.activeTrack.id, secondTrack.id);
      // Tab did NOT switch to Arranger (tab 0)
      expect(dawState.activeTabIndex, 3);

      dawState.dispose();
    });

    testWidgets('Tapping LCD screen on track strip keeps track properties open and changes active track', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      dawState.activeTabIndex = 3; // Mixer tab
      final firstTrack = dawState.activePattern.tracks.first;
      final secondTrack = dawState.activePattern.tracks[1];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts expanded with first track active
      expect(find.byType(ArrangerContextInspector), findsOneWidget);
      expect(dawState.activeTrack.id, firstTrack.id);

      final lcdTooltip1 = find.byTooltip('Configure ${firstTrack.name} Properties');
      expect(lcdTooltip1, findsOneWidget);

      // Tap LCD of first track again: must stay open (NEVER collapse)
      await tester.tap(lcdTooltip1);
      await tester.pumpAndSettle();
      expect(find.byType(ArrangerContextInspector), findsOneWidget);

      // Tap LCD of second track: stays open and switches active track
      final lcdTooltip2 = find.byTooltip('Configure ${secondTrack.name} Properties');
      expect(lcdTooltip2, findsOneWidget);
      await tester.tap(lcdTooltip2);
      await tester.pumpAndSettle();

      expect(find.byType(ArrangerContextInspector), findsOneWidget);
      expect(dawState.activeTrack.id, secondTrack.id);

      // Verify Channel EQ is rendered in Mixer tab
      expect(find.text('CHANNEL EQ'), findsOneWidget);
      expect(find.text('HPF'), findsOneWidget);
      expect(find.text('LOW'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('MID HZ'), findsOneWidget);

      // Verify Order buttons use < and > with Left / Right tooltips in Mixer tab
      expect(find.byTooltip('Move Track Left'), findsOneWidget);
      expect(find.byTooltip('Move Track Right'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);

      dawState.dispose();
    });

    testWidgets('Tapping Master strip selects Master Bus and opens Master Bus Console with Limiter controls in sidebar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Master strip no longer renders redundant EQ or AI buttons
      expect(find.byTooltip('Master Bus 4-Band EQ & True Peak Limiter'), findsNothing);
      expect(find.byTooltip('Gemini AI Auto-Mix & Master Assistant'), findsNothing);

      // Tap Master LCD
      final masterLcd = find.text('MASTER');
      expect(masterLcd, findsOneWidget);

      await tester.tap(masterLcd, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Master bus console is open in sidebar with AI Master, EQ, Limiter and FX
      expect(find.text('MASTER BUS'), findsOneWidget);
      expect(find.text('AI MASTER'), findsOneWidget);
      expect(find.text('4-BAND EQ & LIMITER'), findsOneWidget);
      expect(find.text('BRICKWALL LIMITER'), findsOneWidget);
      expect(find.text('CEIL'), findsOneWidget);
      expect(find.text('DRIVE'), findsOneWidget);
      expect(find.text('LUFS'), findsOneWidget);
      expect(find.byType(ModularFxRackWidget), findsOneWidget);
      expect(dawState.isMasterSelected, isTrue);
      expect(dawState.activeTrack.id, dawState.masterTrack.id);

      dawState.dispose();
    });
  });
}
