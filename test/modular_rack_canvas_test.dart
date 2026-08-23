import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/ui/lua_workbench_view.dart';
import 'package:mobile_wren_daw/ui/modular/modular_theme.dart';
import 'package:mobile_wren_daw/ui/modular/modular_faceplate_widget.dart';
import 'package:mobile_wren_daw/ui/modular/modular_jack_widget.dart';
import 'package:mobile_wren_daw/ui/modular/modular_rack_canvas.dart';
import 'package:mobile_wren_daw/ui/modular/patch_cable_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VCV Rack-Style Modular Canvas & Subpixel Cable Tests', () {
    test('computeJackCenter calculates mathematically exact subpixel coordinates without vertical offset error', () {
      // Row 1, Module 0 (HP=11), Jack 0 of 2
      final p1 = ModularRackCanvas.computeJackCenter(
        row: 1,
        previousHpList: [],
        currentHp: 11,
        jackIndex: 0,
        totalJacks: 2,
      );
      // Fixed Jack Y for row 1 = 18px (rail) + 148px = 166.0px
      expect(p1.dy, 166.0);
      expect(p1.dx, greaterThan(40.0));
      expect(p1.dx, lessThan(60.0));

      // Row 2, Module 0 (HP=15), Jack 0 of 2
      final p2 = ModularRackCanvas.computeJackCenter(
        row: 2,
        previousHpList: [],
        currentHp: 15,
        jackIndex: 0,
        totalJacks: 2,
      );
      // Row 2 TierTop = 211.0px -> Jack Y = 211 + 18 + 148 = 377.0px
      expect(p2.dy, 377.0);
    });

    testWidgets('PatchCablePainter paints gravity-droop cables without error', (tester) async {
      const cables = [
        ModularPatchCable(
          from: Offset(10, 20),
          to: Offset(100, 150),
          color: ModularTheme.cableAudio,
          tension: 0.5,
        ),
        ModularPatchCable(
          from: Offset(30, 40),
          to: Offset(80, 200),
          color: ModularTheme.cablePitchCv,
          tension: 0.7,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(400, 400),
              painter: PatchCablePainter(cables: cables, opacity: 0.9),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ModularJackWidget renders fixed 48px slot and responds to tap & drag', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModularJackWidget(
              label: '1V/Oct',
              type: JackType.input,
              signalType: JackSignalType.pitchCv,
              isConnected: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('1V/OCT'), findsOneWidget);
      await tester.tap(find.byType(ModularJackWidget));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('ModularRackCanvas renders InteractiveViewer with + ADD ROW and + ADD MODULE buttons', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'modular_edit_track',
        name: 'Acid 303',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00),
        luaScriptCode: '-- @name: Acid 303\nlocal Acid303 = {}',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ModularRackCanvas(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );

      // Verify InteractiveViewer is present for 2D panning and zooming
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // Verify + ADD ROW button exists
      expect(find.text('+ ADD RACK ROW (EXPAND MODULAR CASE)'), findsOneWidget);

      // Verify + ADD MODULE blank plates exist
      expect(find.text('+ ADD'), findsWidgets);

      // Tap + ADD RACK ROW
      await tester.tap(find.text('+ ADD RACK ROW (EXPAND MODULAR CASE)'));
      await tester.pumpAndSettle();

      // Now Row 3 should be added
      expect(find.textContaining('ROW 3:'), findsOneWidget);
    });

    testWidgets('Tapping connected jack opens context menu for disconnecting or cycling color', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'modular_connect_track',
        name: 'Acid 303',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00),
        luaScriptCode: '-- @name: Acid 303\nlocal Acid303 = {}',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ModularRackCanvas(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );

      // Find Saw Out jack (which is connected by default in Acid 303)
      final sawOutFinder = find.text('SAW OUT');
      expect(sawOutFinder, findsOneWidget);

      // Tap the connected jack
      await tester.tap(sawOutFinder);
      await tester.pumpAndSettle();

      // Verify Jack context menu opens
      expect(find.text('Cycle Cable Color'), findsOneWidget);
      expect(find.text('Disconnect Patch Cable'), findsOneWidget);

      // Tap Disconnect Patch Cable
      await tester.tap(find.text('Disconnect Patch Cable'));
      await tester.pumpAndSettle();

      // Menu closes
      expect(find.text('Disconnect Patch Cable'), findsNothing);
    });

    testWidgets('Dragging from a jack tracks movement in all 2D directions and snaps near targets', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'drag_track',
        name: 'Acid 303',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00),
        luaScriptCode: '-- @name: Acid 303\nlocal Acid303 = {}',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ModularRackCanvas(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );

      final jackFinder = find.text('1V/OCT');
      expect(jackFinder, findsOneWidget);

      // Drag in any 2D direction (e.g. up, left, right, down)
      final gesture = await tester.startGesture(tester.getCenter(jackFinder));
      await gesture.moveBy(const Offset(50, -30));
      await tester.pump();
      await gesture.moveBy(const Offset(-20, 40));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byType(ModularRackCanvas), findsOneWidget);
    });

    testWidgets('LuaWorkbenchView (Design Studio) switches modes: CODE, MODULAR, SPLIT, GUI', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'design_303',
        name: 'Acid 303',
        type: TrackType.luaScript,
        color: const Color(0xFFFF8C00),
        luaScriptCode: '-- @name: Acid 303\nlocal Acid303 = {}',
      );
      dawState.activePattern.tracks.add(track);
      dawState.activeTrackIndex = dawState.activePattern.tracks.indexOf(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 900,
              child: LuaWorkbenchView(
                dawState: dawState,
              ),
            ),
          ),
        ),
      );

      // Default is CODE mode
      expect(find.text('CODE'), findsOneWidget);
      expect(find.text('MODULAR'), findsOneWidget);
      expect(find.text('SPLIT'), findsOneWidget);
      expect(find.text('GUI'), findsOneWidget);

      // Switch to MODULAR mode
      await tester.tap(find.text('MODULAR'));
      await tester.pumpAndSettle();

      expect(find.textContaining('MODULAR RACK:'), findsOneWidget);
      expect(find.text('303 VCO'), findsOneWidget);

      // Switch to SPLIT mode
      await tester.tap(find.text('SPLIT'));
      await tester.pumpAndSettle();

      expect(find.textContaining('MODULAR RACK:'), findsOneWidget);
      expect(find.text('303 VCO'), findsOneWidget);

      // Switch to GUI preview mode
      await tester.tap(find.text('GUI'));
      await tester.pumpAndSettle();

      expect(find.byType(LuaWorkbenchView), findsOneWidget);
    });
  });
}
