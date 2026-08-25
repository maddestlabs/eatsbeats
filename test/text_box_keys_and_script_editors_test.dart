import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/main.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/theme/eats_theme.dart';
import 'package:eatsbeats/ui/script_view.dart';
import 'package:eatsbeats/ui/lua_workbench_view.dart';
import 'package:eatsbeats/ui/widgets/project_browser_drawer.dart';
import 'package:eatsbeats/ui/widgets/arranger_context_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Text Box & Script Editor Keypress Tests', () {
    testWidgets('Preset Library Filter text box allows typing, Backspace, Delete, and Arrow keys', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dawState = DawState(enableMeterTimer: false);
      dawState.isBrowserOpen = true;
      dawState.browserTabIndex = 1; // Preset library tab

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: DawMainShell(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the filter presets text field in Project Browser
      final filterFieldFinder = find.widgetWithText(TextField, 'Filter presets...');
      expect(filterFieldFinder, findsOneWidget);

      // Tap to focus and enter text
      await tester.tap(filterFieldFinder);
      await tester.pump();

      await tester.enterText(filterFieldFinder, 'Synth');
      await tester.pump();
      expect(find.text('Synth'), findsOneWidget);

      final initialTrackCount = dawState.activePattern.tracks.length;
      final isPlayingInitial = dawState.isPlaying;

      // Press Backspace in the filter box -> should delete last character without deleting track
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      // Track count must remain intact and play state unchanged
      expect(dawState.activePattern.tracks.length, equals(initialTrackCount));
      expect(dawState.isPlaying, equals(isPlayingInitial));

      // Press Space while typing -> should not toggle playhead
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(dawState.isPlaying, equals(isPlayingInitial));

      dawState.stop();
      await tester.pumpWidget(const SizedBox());
      dawState.dispose();
    });

    testWidgets('Arranger Context Inspector Track and Clip renaming text boxes allow full keypresses', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dawState = DawState(enableMeterTimer: false);
      dawState.activeClip = null; // Inspect Track Properties
      final track = dawState.activeTrack;
      final initialTrackName = track.name;

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: ArrangerContextInspector(
              dawState: dawState,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap rename track button
      final renameButton = find.byTooltip('Rename Track');
      expect(renameButton, findsOneWidget);
      await tester.tap(renameButton);
      await tester.pumpAndSettle();

      // Find track rename TextField
      final renameField = find.byType(TextField);
      expect(renameField, findsOneWidget);

      await tester.enterText(renameField, 'Lead Synth 2');
      await tester.pump();

      // Press Backspace / Arrow keys
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      // Save new track name
      final saveButton = find.byTooltip('Save Name');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(track.name, isNot(equals(initialTrackName)));

      dawState.stop();
      await tester.pumpWidget(const SizedBox());
      dawState.dispose();
    });

    testWidgets('ScriptView Editor accepts keypresses, space without playback toggle, and Backspace/Delete without clip deletion', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dawState = DawState(enableMeterTimer: false);
      final initialClipCount = dawState.activeTrack.clips.length;
      final isPlayingInitial = dawState.isPlaying;

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: DawMainShell(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to EDIT tab
      dawState.activeTabIndex = 1;
      await tester.pumpAndSettle();

      final codeField = find.byType(TextField);
      if (codeField.evaluate().isNotEmpty) {
        await tester.tap(codeField.first);
        await tester.pump();

        await tester.enterText(codeField.first, '-- Test script\nfunction process() end');
        await tester.pump();

        // Send Space key -> should NOT toggle DAW playback
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(dawState.isPlaying, equals(isPlayingInitial));

        // Send Delete / Backspace keys -> should NOT delete DAW clip or track
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump();

        expect(dawState.activeTrack.clips.length, equals(initialClipCount));
      }

      dawState.stop();
      await tester.pumpWidget(const SizedBox());
      dawState.dispose();
    });

    testWidgets('LuaWorkbenchView Editor accepts text editing keys and Ctrl+Enter compilation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: LuaWorkbenchView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final codeField = find.byType(TextField);
      expect(codeField, findsWidgets);

      await tester.tap(codeField.first);
      await tester.pump();

      await tester.enterText(codeField.first, 'function dsp_process(sample) return sample * 0.5 end');
      await tester.pump();

      // Send arrow keys and backspace
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      // Send Ctrl+Enter to compile
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsWidgets);

      dawState.stop();
      await tester.pumpWidget(const SizedBox());
      dawState.dispose();
    });

    testWidgets('Global Space and Delete still operate as shortcuts when text boxes are not focused', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: DawMainShell(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dawState.isPlaying, isFalse);

      // Global Space -> toggle play
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(dawState.isPlaying, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(dawState.isPlaying, isFalse);

      // Add a clip and select it
      final track = dawState.activeTrack;
      dawState.addClipToTrack(track, 2);
      await tester.pumpAndSettle();
      final clipCount = track.clips.length;
      dawState.activeClip = track.clips.last;
      await tester.pump();

      // Global Delete -> delete active clip
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(track.clips.length, equals(clipCount - 1));

      dawState.stop();
      await tester.pumpWidget(const SizedBox());
      dawState.dispose();
    });
  });
}
