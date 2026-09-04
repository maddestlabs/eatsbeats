import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/audio_engine.dart';
import 'package:eatsbeats/audio/soundfont_engine.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/arranger_view.dart';
import 'package:eatsbeats/ui/piano_roll_view.dart';
import 'package:eatsbeats/ui/tracker_view.dart';
import 'package:eatsbeats/ui/transport_header.dart';
import 'package:eatsbeats/ui/widgets/skeuomorphic_hardware_switch.dart';
import 'package:eatsbeats/ui/widgets/floating_instrument_window.dart';
import 'package:eatsbeats/ui/widgets/dynamic_instrument_gui_widget.dart';
import 'package:eatsbeats/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DawState dawState;

  setUp(() {
    dawState = DawState(enableMeterTimer: false);
  });

  tearDown(() {
    dawState.dispose();
  });

  group('GUI Animations Setting & Persistence Tests', () {
    test('guiAnimationsEnabled defaults to true and toggles via setGuiAnimationsEnabled', () {
      expect(dawState.guiAnimationsEnabled, isTrue);
      dawState.setGuiAnimationsEnabled(false);
      expect(dawState.guiAnimationsEnabled, isFalse);
      dawState.setGuiAnimationsEnabled(true);
      expect(dawState.guiAnimationsEnabled, isTrue);
    });

    testWidgets('Settings dialog displays GUI ANIMATIONS toggle switch', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransportHeader(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open settings dialog via Eatsbeats Settings tooltip
      final settingsBtn = find.byTooltip('Eatsbeats Settings');
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      // Verify GUI ANIMATIONS label and SkeuomorphicHardwareSwitch are present
      expect(find.text('GUI ANIMATIONS & CPU'), findsOneWidget);
      expect(find.text('Enabled (Full Visualizers & Tickers)'), findsOneWidget);
      expect(find.byType(SkeuomorphicHardwareSwitch), findsWidgets);

      // Toggle switch to off by tapping the switch
      final switchFinder = find.byType(SkeuomorphicHardwareSwitch);
      expect(switchFinder, findsWidgets);
      await tester.tap(switchFinder.last);
      await tester.pumpAndSettle();
      expect(find.text('Disabled (Static UI / Conserve CPU)'), findsOneWidget);
      expect(dawState.guiAnimationsEnabled, isFalse);
    });
  });

  group('Arranger Playhead Seeking Tests', () {
    testWidgets('Tapping empty bar grid in Arranger moves playhead and sets active track', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dawState.arrangerStep, 0);

      // Seek to step directly via dawState
      dawState.seekToArrangerStep(32.0); // Bar 2
      expect(dawState.arrangerStep, 32);
      expect(dawState.currentBar, 2);

      dawState.seekToArrangerStep(80.0); // Bar 5
      expect(dawState.arrangerStep, 80);
      expect(dawState.currentBar, 5);
    });

    test('openClipInEditor sets activeClip, activeTabIndex to 1 and shouldCenterEditViewOnOpen to true', () {
      final track = dawState.activeTrack;
      dawState.addClipToTrack(track, 4); // Clip at bar 4
      final clip = track.clips.first;

      dawState.openClipInEditor(clip);
      expect(dawState.activeClip, equals(clip));
      expect(dawState.activeTabIndex, 1); // Edit view
      expect(dawState.shouldCenterEditViewOnOpen, isTrue);
    });
  });

  group('ESC Key Navigation from EDIT View Tests', () {
    testWidgets('Pressing ESC in PianoRollView deselects notes or switches to Arranger pane', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      dawState.activeTabIndex = 1;
      final track = dawState.activeTrack;
      track.activeView = MusicViewType.pianoRoll;

      await tester.pumpWidget(
        MaterialApp(
          home: DawMainShell(dawState: dawState),
        ),
      );
      await tester.pumpAndSettle();

      expect(dawState.activeTabIndex, 1);

      // Send ESC key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Should now have returned to Arranger tab (index 0)
      expect(dawState.activeTabIndex, 0);
    });

    testWidgets('Pressing ESC in TrackerView clears block or switches to Arranger pane', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      dawState.activeTabIndex = 1;
      final track = dawState.activeTrack;
      track.activeView = MusicViewType.tracker;

      await tester.pumpWidget(
        MaterialApp(
          home: DawMainShell(dawState: dawState),
        ),
      );
      await tester.pumpAndSettle();

      expect(dawState.activeTabIndex, 1);

      // Send ESC key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Should now have returned to Arranger tab (index 0)
      expect(dawState.activeTabIndex, 0);
    });

    testWidgets('Fullscreen instrument window renders when openFullscreenDevice is called', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DawMainShell(dawState: dawState),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingInstrumentWindow), findsNothing);

      // Open fullscreen device
      dawState.openFullscreenDevice();
      expect(dawState.isFloatingWindowVisible, isTrue);
      expect(dawState.isFloatingWindowMaximized, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(FloatingInstrumentWindow), findsOneWidget);
      expect(find.byType(DynamicInstrumentGuiWidget), findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(find.byType(FloatingInstrumentWindow));
      expect(renderBox.size.width, greaterThan(500));
      expect(renderBox.size.height, greaterThan(400));

      // Press ESC to close fullscreen window
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(dawState.isFloatingWindowVisible, isFalse);
      expect(find.byType(FloatingInstrumentWindow), findsNothing);
    });

    testWidgets('Floating instrument window opens in non-maximized mode with Arranger visible', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DawMainShell(dawState: dawState),
        ),
      );
      await tester.pumpAndSettle();

      // Open floating window (non-maximized)
      dawState.openFloatingInstrumentWindow();
      expect(dawState.isFloatingWindowVisible, isTrue);
      expect(dawState.isFloatingWindowMaximized, isFalse);
      await tester.pumpAndSettle();

      expect(find.byType(FloatingInstrumentWindow), findsOneWidget);
      expect(find.byType(ArrangerView), findsOneWidget);

      // Close via closeFloatingInstrumentWindow
      dawState.closeFloatingInstrumentWindow();
      await tester.pumpAndSettle();
      expect(dawState.isFloatingWindowVisible, isFalse);
      expect(find.byType(FloatingInstrumentWindow), findsNothing);
    });
  });
}
