import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/main.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/arranger_view.dart';
import 'package:eatsbeats/ui/widgets/arranger_context_inspector.dart';
import 'package:eatsbeats/ui/widgets/midi_fx_rack_widget.dart';
import 'package:eatsbeats/ui/widgets/modular_fx_rack_widget.dart';
import 'package:eatsbeats/utils/fullscreen_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Arranger Track Properties Vertical Pullout Drawer Tests', () {
    testWidgets('Renders vertical right pullout tab and toggles expand/collapse on tap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify collapsed pull tab has tooltip, but no text on tab
      final pullTab = find.byTooltip('Open Properties Panel');
      expect(pullTab, findsOneWidget);
      expect(find.byType(ArrangerContextInspector), findsNothing);

      // Tap on pull tab to expand
      await tester.tap(pullTab);
      await tester.pumpAndSettle();

      // Now drawer is expanded and ArrangerContextInspector is visible
      expect(find.byType(ArrangerContextInspector), findsOneWidget);

      // When clip is unselected, track properties show MIDI & Audio FX racks in single column
      dawState.selectClip(null);
      await tester.pumpAndSettle();
      expect(find.byType(MidiFxRackWidget), findsOneWidget);
      expect(find.byType(ModularFxRackWidget), findsOneWidget);

      // Verify pull tab collapses drawer
      final collapseBtn = find.byTooltip('Collapse Track Properties');
      expect(collapseBtn, findsOneWidget);
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ArrangerContextInspector), findsNothing);

      dawState.dispose();
    });

    testWidgets('Dragging leftward on pull tab expands and resizes drawer in single-column mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      dawState.selectClip(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag leftward by 300px to pull drawer far left
      final pullTab = find.byTooltip('Open Properties Panel');
      await tester.drag(pullTab, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Verify drawer expanded and remains single-column ListView with FX racks
      expect(find.byType(ArrangerContextInspector), findsOneWidget);
      expect(find.byType(MidiFxRackWidget), findsOneWidget);
      expect(find.byType(ModularFxRackWidget), findsOneWidget);

      dawState.dispose();
    });

    testWidgets('Secondary tap on track header auto-expands vertical pullout drawer', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ArrangerContextInspector), findsNothing);

      // Secondary tap (right-click) on track name in track strip
      final trackText = find.text(track.name).first;
      await tester.tap(trackText, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Verify pullout drawer opened to Track section
      expect(find.byType(ArrangerContextInspector), findsOneWidget);
      expect(find.text('SELECTED CLIP'), findsNothing);
      expect(find.text('TRACK PROPERTIES'), findsOneWidget);

      // Scroll inspector to reveal track cards
      final inspectorList = find.descendant(of: find.byType(ArrangerContextInspector), matching: find.byType(Scrollable));
      await tester.scrollUntilVisible(find.text('TRACK ACTIONS'), 100, scrollable: inspectorList);
      await tester.pumpAndSettle();

      expect(find.text('TRACK ACTIONS'), findsOneWidget);
      expect(find.text('TRACK COLOR'), findsOneWidget);
      expect(find.text('TRACK LYRICS'), findsOneWidget);
      expect(find.byIcon(Icons.palette), findsOneWidget);
      expect(find.byIcon(Icons.colorize), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);

      dawState.dispose();
    });

    testWidgets('Secondary tap on clip auto-expands pullout drawer in clip mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      final clip = track.clips.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ArrangerContextInspector), findsNothing);

      // Find clip widget in timeline and right click
      final clipText = find.text(clip.name).first;
      await tester.tap(clipText, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Verify pullout drawer opened in Clip mode
      expect(find.byType(ArrangerContextInspector), findsOneWidget);
      expect(find.text('SELECTED CLIP'), findsOneWidget);
      expect(find.text(clip.name), findsAtLeastNWidgets(1));
      expect(find.text('LOOP & LENGTH'), findsOneWidget);
      expect(find.text('OPEN IN EDIT TAB'), findsOneWidget);
      expect(find.text('SPLIT NOTES INTO TRACKS'), findsOneWidget);
      expect(find.text('CLIP LYRICS'), findsOneWidget);

      dawState.dispose();
    });
  });

  group('Fullscreen Shortcut Tests', () {
    testWidgets('FullscreenHelper toggles fullscreen state', (WidgetTester tester) async {
      final initial = FullscreenHelper.isFullscreen;
      await FullscreenHelper.toggleFullscreen();
      expect(FullscreenHelper.isFullscreen, !initial);
      await FullscreenHelper.setFullscreen(false);
      expect(FullscreenHelper.isFullscreen, isFalse);
    });
  });
}
